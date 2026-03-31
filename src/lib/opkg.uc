'use strict';

import { popen, stat } from 'fs';
import * as util from './util.uc';
import * as ubus from './ubus_wrapper.uc';

const has_apk = (stat('/usr/bin/apk') != null || stat('/sbin/apk') != null);

// Parse opkg format: "pkg - 1.0 - 2.0"
function parse_opkg_upgradable(content) {
    if (content == null) return [];
    let packages = [];
    for (let line in split(content, "\n")) {
        line = util.trim(line);
        if (line == "") continue;
        let m = match(line, /^(\S+)\s+-\s+(\S+)\s+-\s+(\S+)/);
        if (m == null) continue;
        push(packages, {
            name:      m[1],
            current:   m[2],
            available: m[3],
        });
    }
    return packages;
}

// Parse apk format: "( 1/16) Upgrading pkg (1.0 -> 2.0)"
function parse_apk_upgradable(content) {
    if (content == null) return [];
    let packages = [];
    for (let line in split(content, "\n")) {
        line = util.trim(line);
        if (line == "") continue;
        let m = match(line, /Upgrading (\S+) \((\S+) -> (\S+)\)/);
        if (m == null) continue;
        push(packages, {
            name:      m[1],
            current:   m[2],
            available: m[3],
        });
    }
    return packages;
}

function parse_upgradable(content) {
    if (content == null) return [];
    // Auto-detect format by checking for apk-style output
    if (match(content, /Upgrading /)) {
        return parse_apk_upgradable(content);
    }
    return parse_opkg_upgradable(content);
}

function pkg_cmd() {
    return has_apk ? "apk" : "opkg";
}

function list_upgradable() {
    if (ubus.is_openwrt) {
        let cmd = has_apk
            ? "apk upgrade --simulate 2>/dev/null"
            : "opkg list-upgradable 2>/dev/null";
        let h = popen(cmd, 'r');
        if (h == null) return [];
        let result = h.read('all');
        h.close();
        return parse_upgradable(result);
    } else {
        let content = util.read_file(ubus.fixtures_dir() + "/opkg_upgradable.txt");
        return parse_upgradable(content);
    }
}

function update_lists() {
    if (!ubus.is_openwrt) return true;
    if (has_apk) return system("apk update >/dev/null 2>&1") == 0;
    return system("opkg update >/dev/null 2>&1") == 0;
}

export { parse_upgradable, list_upgradable, update_lists, has_apk, pkg_cmd };
