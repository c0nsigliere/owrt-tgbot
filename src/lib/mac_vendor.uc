'use strict';

import { popen, readfile, writefile } from 'fs';
import * as util from './util.uc';

let _vendor_cache = {};    // { "AC:BA:C0": "Yandex LLC", ... } keyed by OUI prefix
let _aliases = {};         // { "AC:BA:C0:AB:67:C4": "Kitchen Lamp", ... } keyed by full MAC
let _state_dir = null;
let _last_api_call = 0;
let _proxy_enabled = false;
let _proxy_url = "";
let _initialized = false;

function init(state_dir, config) {
    if (_initialized) return;
    _state_dir = state_dir || "/tmp/owrt-tgbot/state/";
    if (config) {
        _proxy_enabled = config.proxy_enabled || false;
        _proxy_url = config.proxy_url || "";
    }

    // Load vendor cache from disk
    let vc = readfile(_state_dir + "vendor_cache.json");
    if (vc != null) {
        let parsed = json(vc);
        if (parsed != null) _vendor_cache = parsed;
    }

    // Load aliases from disk
    let al = readfile(_state_dir + "device_aliases.json");
    if (al != null) {
        let parsed = json(al);
        if (parsed != null) _aliases = parsed;
    }

    _initialized = true;
}

// Check if MAC is locally administered (randomized)
// Bit 1 of the first octet is the "locally administered" flag
function is_local_mac(mac) {
    if (mac == null) return false;
    let first_hex = substr(uc(mac), 0, 2);
    let first_octet = hex(first_hex);
    if (first_octet == null) return false;
    return (first_octet & 0x02) != 0;
}

// Extract OUI prefix (first 3 octets) from MAC address
function oui_prefix(mac) {
    return substr(uc(mac), 0, 8);  // "AC:BA:C0"
}

// Fetch vendor from macvendors.com API
function fetch_vendor(mac) {
    let now = time();
    if (now - _last_api_call < 1) return null;  // throttle: 1 req/sec
    _last_api_call = now;

    let oui = oui_prefix(mac);
    let parts = [
        "curl -s",
        "--connect-timeout 3",
        "--max-time 5",
    ];
    if (_proxy_enabled && _proxy_url != "") {
        push(parts, "--proxy " + _proxy_url);
    }
    push(parts, '"https://api.macvendors.com/' + oui + '"');
    push(parts, "2>/dev/null");

    let cmd = join(" ", parts);
    let h = popen(cmd, 'r');
    if (h == null) {
        util.log("error", "mac_vendor: curl failed for " + oui);
        return null;
    }
    let result = h.read('all');
    h.close();

    if (result == null) return null;
    result = util.trim(result);

    if (result == "") return "";  // empty = unknown OUI

    // macvendors.com returns plain text on success, JSON on error:
    //   404: {"errors":{"detail":"Not Found"}}
    //   429: {"errors":{"message":"...","detail":"Too Many Requests"}}
    if (substr(result, 0, 1) == "{") {
        let data = json(result);
        if (data != null && data.errors != null) {
            let detail = data.errors.detail || "";
            if (match(detail, /Too Many/i)) {
                util.log("debug", "mac_vendor: rate limited by API");
                return null;  // retry later (don't cache)
            }
            return "";  // Not Found or other API error — cache as unknown
        }
    }

    return result;
}

// Look up vendor for a MAC address
// Returns vendor string, "" (known unknown), or null (not yet looked up / throttled)
function lookup(mac) {
    if (mac == null) return null;
    mac = uc(mac);
    let oui = oui_prefix(mac);

    // Check memory cache
    if (oui in _vendor_cache) {
        return _vendor_cache[oui];
    }

    // Skip API for locally administered MACs
    if (is_local_mac(mac)) {
        _vendor_cache[oui] = "";
        return "";
    }

    // Try API lookup
    let vendor = fetch_vendor(mac);
    if (vendor == null) return null;  // throttled or error, retry later

    _vendor_cache[oui] = vendor;
    return vendor;
}

function get_alias(mac) {
    if (mac == null) return null;
    let alias = _aliases[uc(mac)];
    return (alias != null) ? alias : null;
}

function set_alias(mac, name) {
    if (mac == null || name == null) return;
    _aliases[uc(mac)] = name;
}

function remove_alias(mac) {
    if (mac == null) return;
    delete _aliases[uc(mac)];
}

function get_aliases() {
    return _aliases;
}

function save_to_disk() {
    if (_state_dir == null) return;
    writefile(_state_dir + "vendor_cache.json", sprintf("%J", _vendor_cache));
    writefile(_state_dir + "device_aliases.json", sprintf("%J", _aliases));
}

// Resolve a display name for a device
// Returns { name, style } where style is "hostname", "alias", "random", "vendor", or "unknown"
function resolve_name(dev) {
    if (dev.hostname != null) {
        return { name: dev.hostname, style: "hostname" };
    }

    let alias = get_alias(dev.mac);
    if (alias != null) {
        return { name: alias, style: "alias" };
    }

    if (is_local_mac(dev.mac)) {
        return { name: "Random MAC", style: "random" };
    }

    let vendor = lookup(dev.mac);
    if (vendor != null && vendor != "") {
        return { name: vendor, style: "vendor" };
    }

    return { name: "unknown", style: "unknown" };
}

// Reset state (for testing)
function _reset() {
    _vendor_cache = {};
    _aliases = {};
    _state_dir = null;
    _last_api_call = 0;
    _proxy_enabled = false;
    _proxy_url = "";
    _initialized = false;
}

export {
    init,
    is_local_mac,
    oui_prefix,
    lookup,
    get_alias,
    set_alias,
    remove_alias,
    get_aliases,
    save_to_disk,
    resolve_name,
    _reset
};
