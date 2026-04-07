'use strict';

import * as h from './helpers.uc';
import * as util from '../src/lib/util.uc';
import * as ubus from '../src/lib/ubus_wrapper.uc';
import { writefile } from 'fs';

ubus.set_fixtures_dir("fixtures");

const STATE_DIR = "/tmp/owrt-tgbot-test-offline/";
system("mkdir -p " + STATE_DIR);

let mod = loadfile("src/alerts/device_offline.uc")();

function make_ctx(overrides) {
    let ctx = {
        config: {
            alerts: {
                device_offline: true,
                offline_threshold: 120,
            },
        },
        notify: null,
        state_dir: STATE_DIR,
    };
    if (overrides) {
        for (let k in overrides) ctx.config.alerts[k] = overrides[k];
    }
    return ctx;
}

function clean_state() {
    system("rm -f " + STATE_DIR + "device_offline.json");
}

function write_state(obj) {
    writefile(STATE_DIR + "device_offline.json", sprintf("%J", obj));
}

function read_state() {
    let raw = util.read_file(STATE_DIR + "device_offline.json");
    return (raw != null) ? json(raw) : null;
}

return {

"module exports name 'device_offline'": () =>
    h.assert_eq(mod.name, "device_offline"),

"module exports check function": () =>
    h.assert_eq(type(mod.check), "function"),

"first run: returns null (no alerts)": () => {
    clean_state();
    let result = mod.check(make_ctx());
    return h.assert_null(result, "expected null on first run");
},

"first run: creates state file with devices": () => {
    clean_state();
    mod.check(make_ctx());
    let state = read_state();
    return h.assert_truthy(state != null && length(keys(state)) > 0,
        "state should have entries after first run");
},

"device offline past threshold: sends alert": () => {
    clean_state();
    // AA:BB:CC:DD:EE:04 is offline in fixtures (ARP flags 0x0)
    let state = {};
    state["AA:BB:CC:DD:EE:04"] = {
        seen: time() - 200,
        alerted: false,
        hostname: "Xiaomi-Vacuum",
        ip: "192.168.1.103",
    };
    write_state(state);

    let result = mod.check(make_ctx());
    if (result == null) return "expected alert but got null";
    return h.assert_contains(result.text, "Device offline");
},

"device offline past threshold: alert contains device name": () => {
    clean_state();
    let state = {};
    state["AA:BB:CC:DD:EE:04"] = {
        seen: time() - 200,
        alerted: false,
        hostname: "Xiaomi-Vacuum",
        ip: "192.168.1.103",
    };
    write_state(state);

    let result = mod.check(make_ctx());
    if (result == null) return "expected alert but got null";
    return h.assert_contains(result.text, "Xiaomi-Vacuum");
},

"device offline within threshold: no alert": () => {
    clean_state();
    let state = {};
    state["AA:BB:CC:DD:EE:04"] = {
        seen: time() - 60,
        alerted: false,
        hostname: "Xiaomi-Vacuum",
        ip: "192.168.1.103",
    };
    write_state(state);

    let result = mod.check(make_ctx());
    return h.assert_null(result, "expected null within threshold");
},

"already alerted device: no repeat alert": () => {
    clean_state();
    let state = {};
    state["AA:BB:CC:DD:EE:04"] = {
        seen: time() - 300,
        alerted: true,
        hostname: "Xiaomi-Vacuum",
        ip: "192.168.1.103",
    };
    write_state(state);

    let result = mod.check(make_ctx());
    return h.assert_null(result, "should not re-alert already alerted device");
},

"device back online after alert: sends recovery": () => {
    clean_state();
    // AA:BB:CC:DD:EE:01 is online in fixtures (ARP flags 0x2)
    let state = {};
    state["AA:BB:CC:DD:EE:01"] = {
        seen: time() - 600,
        alerted: true,
        hostname: "iPhone-Anton",
        ip: "192.168.1.100",
    };
    write_state(state);

    let result = mod.check(make_ctx());
    if (result == null) return "expected recovery alert but got null";
    return h.assert_contains(result.text, "back online");
},

"recovery alert contains offline duration": () => {
    clean_state();
    let state = {};
    state["AA:BB:CC:DD:EE:01"] = {
        seen: time() - 600,
        alerted: true,
        hostname: "iPhone-Anton",
        ip: "192.168.1.100",
    };
    write_state(state);

    let result = mod.check(make_ctx());
    if (result == null) return "expected recovery alert but got null";
    return h.assert_contains(result.text, "Offline for:");
},

"stale entries are pruned after 7 days": () => {
    clean_state();
    let state = {};
    state["FF:FF:FF:FF:FF:FF"] = {
        seen: time() - 700000,
        alerted: true,
        hostname: "Old-Device",
        ip: "192.168.1.200",
    };
    // Also add a fresh entry to ensure it persists
    state["AA:BB:CC:DD:EE:01"] = {
        seen: time() - 10,
        alerted: false,
        hostname: "iPhone-Anton",
        ip: "192.168.1.100",
    };
    write_state(state);

    mod.check(make_ctx());
    let new_state = read_state();
    if (new_state["FF:FF:FF:FF:FF:FF"] != null)
        return "stale entry should have been pruned";
    if (new_state["AA:BB:CC:DD:EE:01"] == null)
        return "fresh entry should still exist";
    return true;
},

};
