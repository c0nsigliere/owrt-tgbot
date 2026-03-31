'use strict';

import * as h from './helpers.uc';
import * as util from '../src/lib/util.uc';
import * as ubus from '../src/lib/ubus_wrapper.uc';
import * as devices from '../src/lib/devices.uc';

ubus.set_fixtures_dir("fixtures");

let dhcp_fixture = util.read_file("fixtures/dhcp.leases");
let arp_fixture  = util.read_file("fixtures/proc_net_arp.txt");

return {

"parse_dhcp_leases: parses valid leases file": () =>
    h.assert_gt(length(devices.parse_dhcp_leases(dhcp_fixture)), 0),

"parse_dhcp_leases: extracts MAC address": () => {
    let leases = devices.parse_dhcp_leases(dhcp_fixture);
    return h.assert_eq(leases[0].mac, "AA:BB:CC:DD:EE:01");
},

"parse_dhcp_leases: extracts IP address": () => {
    let leases = devices.parse_dhcp_leases(dhcp_fixture);
    return h.assert_eq(leases[0].ip, "192.168.1.100");
},

"parse_dhcp_leases: extracts hostname": () => {
    let leases = devices.parse_dhcp_leases(dhcp_fixture);
    return h.assert_eq(leases[0].hostname, "iPhone-Anton");
},

"parse_dhcp_leases: treats * as null hostname": () => {
    let leases = devices.parse_dhcp_leases(dhcp_fixture);
    let found = false;
    for (let l in leases) { if (l.hostname == null) { found = true; break; } }
    return h.assert_truthy(found, "no entry with null hostname");
},

"parse_dhcp_leases: handles null content": () =>
    h.assert_eq(length(devices.parse_dhcp_leases(null)), 0),

"parse_dhcp_leases: handles empty content": () =>
    h.assert_eq(length(devices.parse_dhcp_leases("")), 0),

"parse_arp: parses valid ARP table": () =>
    h.assert_gt(length(devices.parse_arp(arp_fixture)), 0),

"parse_arp: skips header line": () => {
    let entries = devices.parse_arp(arp_fixture);
    return h.assert_truthy(match(entries[0].ip, /^\d/), "first entry ip not a digit");
},

"parse_arp: extracts MAC address": () => {
    let entries = devices.parse_arp(arp_fixture);
    return h.assert_eq(entries[0].mac, "AA:BB:CC:DD:EE:01");
},

"parse_arp: detects reachable (0x2)": () => {
    let entries = devices.parse_arp(arp_fixture);
    return h.assert_eq(entries[0].reachable, true);
},

"parse_arp: detects unreachable (0x0)": () => {
    let entries = devices.parse_arp(arp_fixture);
    let found = false;
    for (let e in entries) { if (!e.reachable) { found = true; break; } }
    return h.assert_truthy(found, "no unreachable entry found");
},

"parse_arp: handles null content": () =>
    h.assert_eq(length(devices.parse_arp(null)), 0),

};
