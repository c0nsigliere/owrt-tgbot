'use strict';

import { popen } from 'fs';
import * as util from './util.uc';
import * as ubus from './ubus_wrapper.uc';

// vnstat 1.x outputs KiB, vnstat 2.x outputs bytes
// Detect by jsonversion: "1" = KiB, "2" = bytes
let _scale = null;
function bytes_scale(data) {
    if (_scale != null) return _scale;
    _scale = (data.jsonversion == "1") ? 1024 : 1;
    return _scale;
}

function get_raw_data(interface) {
    if (ubus.is_openwrt) {
        let h = popen("vnstat --json -i " + interface + " 2>/dev/null", 'r');
        if (h == null) return null;
        let result = h.read('all');
        h.close();
        if (result == null || result == "") return null;
        return json(result);
    } else {
        let content = util.read_file(ubus.fixtures_dir() + "/vnstat.json");
        if (content == null) return null;
        return json(content);
    }
}

function get_interface_data(interface) {
    let data = get_raw_data(interface);
    if (data == null) return null;
    let scale = bytes_scale(data);
    let ifaces = data.interfaces;
    if (ifaces == null || length(ifaces) == 0) return null;
    let iface = ifaces[0];
    // vnstat 1.x: "days"/"months"/"tops", vnstat 2.x: "day"/"month"/"top"
    let t = iface.traffic;
    if (t != null) {
        if (t.day == null && t.days != null) t.day = t.days;
        if (t.month == null && t.months != null) t.month = t.months;
        if (t.top == null && t.tops != null) t.top = t.tops;
    }
    return { iface, scale };
}

function today(interface) {
    let r = get_interface_data(interface);
    if (r == null) return null;
    let s = r.scale;
    let days = r.iface.traffic && r.iface.traffic.day;
    if (days == null || length(days) == 0) {
        return { rx_bytes: 0, tx_bytes: 0 };
    }
    let d = days[length(days) - 1];
    return {
        rx_bytes: (d.rx || 0) * s,
        tx_bytes: (d.tx || 0) * s,
        date: d.date,
    };
}

function days(interface, n) {
    let r = get_interface_data(interface);
    if (r == null) return null;
    let s = r.scale;
    let day_list = r.iface.traffic && r.iface.traffic.day;
    if (day_list == null) return [];
    n = n || 7;
    let result = [];
    let start = length(day_list) - n;
    if (start < 0) start = 0;
    for (let i = start; i < length(day_list); i++) {
        let d = day_list[i];
        push(result, {
            date:     d.date,
            rx_bytes: (d.rx || 0) * s,
            tx_bytes: (d.tx || 0) * s,
        });
    }
    return result;
}

function month(interface) {
    let r = get_interface_data(interface);
    if (r == null) return null;
    let s = r.scale;
    let months = r.iface.traffic && r.iface.traffic.month;
    if (months == null || length(months) == 0) {
        return { rx_bytes: 0, tx_bytes: 0 };
    }
    let m = months[length(months) - 1];
    return {
        rx_bytes: (m.rx || 0) * s,
        tx_bytes: (m.tx || 0) * s,
        date: m.date,
    };
}

function top(interface, n) {
    let r = get_interface_data(interface);
    if (r == null) return null;
    let s = r.scale;
    let top_list = r.iface.traffic && r.iface.traffic.top;
    if (top_list == null) return [];
    n = n || 5;
    let limit = n < length(top_list) ? n : length(top_list);
    let result = [];
    for (let i = 0; i < limit; i++) {
        let t = top_list[i];
        push(result, {
            date:     t.date,
            rx_bytes: (t.rx || 0) * s,
            tx_bytes: (t.tx || 0) * s,
        });
    }
    return result;
}

export { today, days, month, top };
