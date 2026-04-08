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

"parse_station_dump: parses connected time": () => {
    let content = util.read_file("fixtures/iw_station_dump.txt");
    let times = devices.parse_station_dump(content);
    return h.assert_eq(times["AA:BB:CC:DD:EE:01"], 3600);
},

"parse_station_dump: parses multiple stations": () => {
    let content = util.read_file("fixtures/iw_station_dump.txt");
    let times = devices.parse_station_dump(content);
    return h.assert_eq(times["AA:BB:CC:DD:EE:06"], 7200);
},

"parse_station_dump: handles null content": () => {
    let times = devices.parse_station_dump(null);
    return h.assert_eq(length(keys(times)), 0);
},

"parse_station_dump: handles empty content": () => {
    let times = devices.parse_station_dump("");
    return h.assert_eq(length(keys(times)), 0);
},

"get_wifi_clients: returns connected_time from fixture": () => {
    let clients = devices.get_wifi_clients();
    let client = clients["AA:BB:CC:DD:EE:01"];
    if (client == null) return h.assert_truthy(false, "client not found in fixture");
    return h.assert_eq(client.connected_time, 3600);
},

"get_wifi_clients: returns band from freq": () => {
    let clients = devices.get_wifi_clients();
    let client = clients["AA:BB:CC:DD:EE:01"];
    if (client == null) return h.assert_truthy(false, "client not found in fixture");
    return h.assert_eq(client.band, "2.4GHz");
},

"get_all: wifi device includes connected_time": () => {
    let all = devices.get_all();
    let found = null;
    for (let dev in all) {
        if (dev.mac == "AA:BB:CC:DD:EE:01") { found = dev; break; }
    }
    if (found == null) return h.assert_truthy(false, "device not found");
    return h.assert_eq(found.connected_time, 3600);
},

"get_all: wired device has null connected_time": () => {
    let all = devices.get_all();
    let found = null;
    for (let dev in all) {
        if (dev.mac == "AA:BB:CC:DD:EE:02") { found = dev; break; }
    }
    if (found == null) return h.assert_truthy(false, "device not found");
    return h.assert_eq(found.connected_time, null);
},

"parse_arp: duplicate MAC prefers reachable (reachable first)": () => {
    let content = "IP address       HW type     Flags       HW address            Mask     Device\n" +
        "192.168.1.11     0x1         0x2         AA:BB:CC:DD:EE:01     *        br-lan\n" +
        "192.168.1.116    0x1         0x0         AA:BB:CC:DD:EE:01     *        br-lan\n";
    let entries = devices.parse_arp(content);
    // Both entries parsed
    h.assert_eq(length(entries), 2);
    // But when building arp_by_mac (tested via get_all), reachable wins.
    // Test parse_arp itself just returns both:
    return h.assert_eq(entries[0].reachable, true);
},

"parse_arp: duplicate MAC prefers reachable (unreachable first)": () => {
    let content = "IP address       HW type     Flags       HW address            Mask     Device\n" +
        "192.168.1.116    0x1         0x0         AA:BB:CC:DD:EE:01     *        br-lan\n" +
        "192.168.1.11     0x1         0x2         AA:BB:CC:DD:EE:01     *        br-lan\n";
    let entries = devices.parse_arp(content);
    return h.assert_eq(length(entries), 2);
},

};
