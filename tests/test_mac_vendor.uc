'use strict';

import { writefile, mkdir } from 'fs';
import * as h from './helpers.uc';
import * as mac_vendor from '../src/lib/mac_vendor.uc';

const TEST_STATE_DIR = "/tmp/owrt-tgbot-test-mac-vendor/";

function setup() {
    mac_vendor._reset();
    system("mkdir -p " + TEST_STATE_DIR);
    system("rm -f " + TEST_STATE_DIR + "*.json");
}

return {

// --- is_local_mac ---

"is_local_mac: detects 0A (bit 1 set)": () => {
    return h.assert_eq(mac_vendor.is_local_mac("0A:61:97:F0:60:3F"), true);
},

"is_local_mac: detects BA (bit 1 set)": () => {
    return h.assert_eq(mac_vendor.is_local_mac("BA:11:13:98:EF:FF"), true);
},

"is_local_mac: detects 32 (bit 1 set)": () => {
    return h.assert_eq(mac_vendor.is_local_mac("32:1D:61:4A:C9:DE"), true);
},

"is_local_mac: false for AC (globally unique)": () => {
    return h.assert_eq(mac_vendor.is_local_mac("AC:BA:C0:AB:67:C4"), false);
},

"is_local_mac: false for 00 (globally unique)": () => {
    return h.assert_eq(mac_vendor.is_local_mac("00:24:E4:17:4B:CE"), false);
},

"is_local_mac: false for 50 (globally unique)": () => {
    return h.assert_eq(mac_vendor.is_local_mac("50:EC:50:12:32:85"), false);
},

"is_local_mac: false for 68 (globally unique)": () => {
    return h.assert_eq(mac_vendor.is_local_mac("68:AB:09:63:11:44"), false);
},

"is_local_mac: handles null": () => {
    return h.assert_eq(mac_vendor.is_local_mac(null), false);
},

"is_local_mac: handles lowercase": () => {
    return h.assert_eq(mac_vendor.is_local_mac("0a:61:97:f0:60:3f"), true);
},

// --- oui_prefix ---

"oui_prefix: extracts first 3 octets": () => {
    return h.assert_eq(mac_vendor.oui_prefix("AC:BA:C0:AB:67:C4"), "AC:BA:C0");
},

"oui_prefix: normalizes to uppercase": () => {
    return h.assert_eq(mac_vendor.oui_prefix("ac:ba:c0:ab:67:c4"), "AC:BA:C0");
},

// --- alias CRUD ---

"get_alias: returns null for unknown MAC": () => {
    setup();
    mac_vendor.init(TEST_STATE_DIR);
    return h.assert_null(mac_vendor.get_alias("AA:BB:CC:DD:EE:FF"));
},

"set_alias: stores and retrieves": () => {
    setup();
    mac_vendor.init(TEST_STATE_DIR);
    mac_vendor.set_alias("AA:BB:CC:DD:EE:FF", "Kitchen Lamp");
    return h.assert_eq(mac_vendor.get_alias("AA:BB:CC:DD:EE:FF"), "Kitchen Lamp");
},

"set_alias: normalizes MAC to uppercase": () => {
    setup();
    mac_vendor.init(TEST_STATE_DIR);
    mac_vendor.set_alias("aa:bb:cc:dd:ee:ff", "Test Device");
    return h.assert_eq(mac_vendor.get_alias("AA:BB:CC:DD:EE:FF"), "Test Device");
},

"set_alias: overwrites existing": () => {
    setup();
    mac_vendor.init(TEST_STATE_DIR);
    mac_vendor.set_alias("AA:BB:CC:DD:EE:FF", "Old Name");
    mac_vendor.set_alias("AA:BB:CC:DD:EE:FF", "New Name");
    return h.assert_eq(mac_vendor.get_alias("AA:BB:CC:DD:EE:FF"), "New Name");
},

"remove_alias: removes existing": () => {
    setup();
    mac_vendor.init(TEST_STATE_DIR);
    mac_vendor.set_alias("AA:BB:CC:DD:EE:FF", "Test");
    mac_vendor.remove_alias("AA:BB:CC:DD:EE:FF");
    return h.assert_null(mac_vendor.get_alias("AA:BB:CC:DD:EE:FF"));
},

"remove_alias: no-op for nonexistent": () => {
    setup();
    mac_vendor.init(TEST_STATE_DIR);
    mac_vendor.remove_alias("AA:BB:CC:DD:EE:FF");
    return h.assert_null(mac_vendor.get_alias("AA:BB:CC:DD:EE:FF"));
},

"get_aliases: returns empty object initially": () => {
    setup();
    mac_vendor.init(TEST_STATE_DIR);
    let aliases = mac_vendor.get_aliases();
    let count = 0;
    for (let _ in aliases) count++;
    return h.assert_eq(count, 0);
},

// --- save/load round-trip ---

"save and reload: aliases persist": () => {
    setup();
    mac_vendor.init(TEST_STATE_DIR);
    mac_vendor.set_alias("AA:BB:CC:DD:EE:FF", "Test Device");
    mac_vendor.save_to_disk();

    // Reset and reload
    mac_vendor._reset();
    mac_vendor.init(TEST_STATE_DIR);
    return h.assert_eq(mac_vendor.get_alias("AA:BB:CC:DD:EE:FF"), "Test Device");
},

// --- resolve_name ---

"resolve_name: hostname wins over everything": () => {
    setup();
    mac_vendor.init(TEST_STATE_DIR);
    mac_vendor.set_alias("AC:BA:C0:AB:67:C4", "My Alias");
    let result = mac_vendor.resolve_name({ mac: "AC:BA:C0:AB:67:C4", hostname: "MyHost" });
    let r1 = h.assert_eq(result.name, "MyHost");
    if (r1 != true) return r1;
    return h.assert_eq(result.style, "hostname");
},

"resolve_name: alias wins over vendor": () => {
    setup();
    mac_vendor.init(TEST_STATE_DIR);
    mac_vendor.set_alias("AC:BA:C0:AB:67:C4", "My Alias");
    let result = mac_vendor.resolve_name({ mac: "AC:BA:C0:AB:67:C4", hostname: null });
    let r1 = h.assert_eq(result.name, "My Alias");
    if (r1 != true) return r1;
    return h.assert_eq(result.style, "alias");
},

"resolve_name: random MAC detected": () => {
    setup();
    mac_vendor.init(TEST_STATE_DIR);
    let result = mac_vendor.resolve_name({ mac: "0A:61:97:F0:60:3F", hostname: null });
    let r1 = h.assert_eq(result.name, "Random MAC");
    if (r1 != true) return r1;
    return h.assert_eq(result.style, "random");
},

"resolve_name: unknown when lookup throttled": () => {
    setup();
    mac_vendor.init(TEST_STATE_DIR);
    // First lookup consumes the throttle window
    mac_vendor.lookup("AC:BA:C0:00:00:01");
    // Second lookup with different OUI within 1s — throttled, returns null → unknown
    let result = mac_vendor.resolve_name({ mac: "50:EC:50:AB:67:C4", hostname: null });
    return h.assert_eq(result.style, "unknown");
},

};
