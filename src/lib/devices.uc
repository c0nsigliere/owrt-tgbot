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

function get_wifi_clients() {
    if (!ubus.is_openwrt) return {};
    let clients = {};
    let h = popen("ubus list 'hostapd.*' 2>/dev/null", 'r');
    if (h == null) return clients;
    let listing = h.read('all');
    h.close();
    if (listing == null) return clients;

    for (let iface_name in split(listing, "\n")) {
        iface_name = util.trim(iface_name);
        if (iface_name == "") continue;
        let data = ubus.call(iface_name, "get_clients");
        if (data == null || data.clients == null) continue;
        let band = null;
        if (match(iface_name, /wlan0/)) band = "2.4GHz";
        else if (match(iface_name, /wlan1/)) band = "5GHz";
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
        arp_by_mac[entry.mac] = entry;
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

export { parse_dhcp_leases, parse_arp, get_wifi_clients, get_all };
