'use strict';

import { stat, popen } from 'fs';
import * as util from './util.uc';

// Detect OpenWrt by checking for ubus binary
const is_openwrt = (stat('/bin/ubus') != null || stat('/usr/bin/ubus') != null);

// Base path for fixtures — can be overridden by caller
let fixtures_dir = null;

function get_fixtures_dir() {
    if (fixtures_dir != null) return fixtures_dir;
    // Try relative to working directory (dev mode: run from project root)
    if (stat('fixtures/ubus') != null) {
        fixtures_dir = 'fixtures';
        return fixtures_dir;
    }
    // Fallback
    fixtures_dir = 'fixtures';
    return fixtures_dir;
}

function call(path, method, args) {
    if (is_openwrt) {
        let cmd = sprintf("ubus call %s %s", path, method);
        if (args != null) {
            cmd += " '" + sprintf("%J", args) + "'";
        }
        cmd += " 2>/dev/null";

        let h = popen(cmd, 'r');
        if (h == null) {
            util.log("error", "ubus_wrapper: failed to execute: " + cmd);
            return null;
        }
        let result = h.read('all');
        h.close();

        if (result == null || result == "") {
            util.log("warn", "ubus_wrapper: empty response for " + path + " " + method);
            return null;
        }
        return json(result);
    } else {
        // Dev mode: read from fixtures/ubus/{path}.{method}.json
        // Note: dots preserved (matching fixture filenames like network.interface.wan.status.json)
        let fixture_name = path + "." + method + ".json";
        let fixture_path = get_fixtures_dir() + "/ubus/" + fixture_name;
        let content = util.read_file(fixture_path);
        if (content == null) {
            util.log("warn", "ubus_wrapper: fixture not found: " + fixture_path);
            return null;
        }
        return json(content);
    }
}

function get_fixtures_dir_fn() { return get_fixtures_dir(); }
function set_fixtures_dir_fn(d) { fixtures_dir = d; }

export { is_openwrt, call };
export { get_fixtures_dir_fn as fixtures_dir };
export { set_fixtures_dir_fn as set_fixtures_dir };
