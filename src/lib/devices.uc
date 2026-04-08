'use strict';

import { popen } from 'fs';
import * as util from './util.uc';
import * as ubus from './ubus_wrapper.uc';

function parse_dhcp_leases(content) {
    if (content == null) return [];
    let leases = [];
    for (let line in split(content, "\n")) {
        line = util.trim(line);
        if (line == "") continue;
        let m = match(line, /^(\d+)\s+(\S+)\s+(\S+)\s+(\S+)/);
        if (m == null) continue;
        let mac = uc(m[2]);
        let hostname = m[4];
        if (hostname == "*") hostname = null;
        push(leases, {
            mac,
            ip:       m[3],
            hostname,
            expiry:   +m[1],
        });
    }
    return leases;
}

function parse_arp(content) {
    if (content == null) return [];
    let entries = [];
    let first_line = true;
    for (let line in split(content, "\n")) {
        line = util.trim(line);
        if (line == "") continue;
        if (first_line) { first_line = false; continue; }
        let m = match(line, /^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/);
        if (m == null) continue;
        let mac = m[4];
        if (mac == "00:00:00:00:00:00") continue;
        mac = uc(mac);
        push(entries, {
            ip:        m[1],
            mac,
            flags:     m[3],
            device:    m[6],
            reachable: (m[3] == "0x2"),
        });
    }
    return entries;
}

function parse_station_dump(content) {
    if (content == null) return {};
    let times = {};
    let current_mac = null;
    for (let line in split(content, "\n")) {
        let sm = match(line, /^Station\s+(\S+)/);
        if (sm) { current_mac = uc(sm[1]); continue; }
        if (current_mac != null) {
            let tm = match(line, /connected time:\s+(\d+)/);
            if (tm) { times[current_mac] = +tm[1]; current_mac = null; }
        }
    }
    return times;
}

function get_station_connected_times() {
    let times = {};

    if (!ubus.is_openwrt) {
        let content = util.read_file(ubus.fixtures_dir() + "/iw_station_dump.txt");
        return parse_station_dump(content);
    }

    let h = popen("ubus list 'hostapd.*' 2>/dev/null", 'r');
    if (h == null) return times;
    let listing = h.read('all');
    h.close();
    if (listing == null) return times;

    for (let iface_name in split(listing, "\n")) {
        iface_name = util.trim(iface_name);
        if (iface_name == "") continue;
        let dev_name = replace(iface_name, "hostapd.", "");
        let p = popen("iw dev " + dev_name + " station dump 2>/dev/null", 'r');
        if (p == null) continue;
        let output = p.read('all');
        p.close();
        let iface_times = parse_station_dump(output);
        for (let mac in iface_times) {
            times[mac] = iface_times[mac];
        }
    }
    return times;
}

function get_wifi_clients() {
    let clients = {};
    let iface_list = [];

    if (ubus.is_openwrt) {
        let h = popen("ubus list 'hostapd.*' 2>/dev/null", 'r');
        if (h == null) return clients;
        let listing = h.read('all');
        h.close();
        if (listing == null) return clients;
        for (let name in split(listing, "\n")) {
            name = util.trim(name);
            if (name != "") push(iface_list, name);
        }
    } else {
        // Dev mode: try fixture for phy0-ap0
        iface_list = ["hostapd.phy0-ap0"];
    }

    for (let iface_name in iface_list) {
        let data = ubus.call(iface_name, "get_clients");
        if (data == null || data.clients == null) continue;
        let band = null;
        if (data.freq != null) {
            if (data.freq < 3000) band = "2.4GHz";
            else if (data.freq < 6000) band = "5GHz";
            else band = "6GHz";
        }
        for (let mac_addr in data.clients) {
            let info = data.clients[mac_addr];
            mac_addr = uc(mac_addr);
            clients[mac_addr] = {
                mac:       mac_addr,
                signal:    info.signal,
                band,
                interface: iface_name,
            };
        }
    }

    // Merge connected_time from iw station dump
    let conn_times = get_station_connected_times();
    for (let mac in clients) {
        clients[mac].connected_time = (conn_times[mac] != null) ? conn_times[mac] : null;
    }

    return clients;
}

function get_all() {
    // Read DHCP leases
    let leases_content;
    if (ubus.is_openwrt) {
        leases_content = util.read_file("/tmp/dhcp.leases");
    } else {
        leases_content = util.read_file(ubus.fixtures_dir() + "/dhcp.leases");
    }
    let leases = parse_dhcp_leases(leases_content);

    // Read ARP table
    let arp_content;
    if (ubus.is_openwrt) {
        arp_content = util.read_file("/proc/net/arp");
    } else {
        arp_content = util.read_file(ubus.fixtures_dir() + "/proc_net_arp.txt");
    }
    let arp_entries = parse_arp(arp_content);

    // Build ARP lookup by MAC
    let arp_by_mac = {};
    for (let entry in arp_entries) {
        let existing = arp_by_mac[entry.mac];
        if (existing == null || (!existing.reachable && entry.reachable)) {
            arp_by_mac[entry.mac] = entry;
        }
    }

    // Get WiFi clients
    let wifi_clients = get_wifi_clients();

    // Merge: DHCP leases as base
    let devices = [];
    let seen_macs = {};

    for (let lease in leases) {
        let mac  = lease.mac;
        let arp  = arp_by_mac[mac];
        let wifi = wifi_clients[mac];

        push(devices, {
            mac,
            ip:        lease.ip,
            hostname:  lease.hostname,
            online:    (arp != null && arp.reachable) ? true : false,
            interface: (wifi != null) ? wifi.interface : ((arp != null) ? arp.device : "unknown"),
            signal:    (wifi != null) ? wifi.signal : null,
            band:      (wifi != null) ? wifi.band   : null,
            connected_time: (wifi != null) ? wifi.connected_time : null,
        });
        seen_macs[mac] = true;
    }

    // Add ARP entries not in DHCP leases (LAN only — skip WAN gateway etc.)
    for (let entry in arp_entries) {
        if (seen_macs[entry.mac]) continue;
        if (entry.device != null && !match(entry.device, /^br-/)) continue;
        let wifi = wifi_clients[entry.mac];
        push(devices, {
            mac:       entry.mac,
            ip:        entry.ip,
            hostname:  null,
            online:    entry.reachable,
            interface: (wifi != null) ? wifi.interface : entry.device,
            signal:    (wifi != null) ? wifi.signal : null,
            band:      (wifi != null) ? wifi.band   : null,
            connected_time: (wifi != null) ? wifi.connected_time : null,
        });
        seen_macs[entry.mac] = true;
    }

    // Sort: named first, then by IP
    sort(devices, (a, b) => {
        if (a.hostname != null && b.hostname == null) return -1;
        if (a.hostname == null && b.hostname != null) return 1;
        if (a.ip < b.ip) return -1;
        if (a.ip > b.ip) return 1;
        return 0;
    });

    return devices;
}

export { parse_dhcp_leases, parse_arp, parse_station_dump, get_wifi_clients, get_all };
