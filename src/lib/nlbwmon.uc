'use strict';

import { popen } from 'fs';
import * as util from './util.uc';
import * as ubus from './ubus_wrapper.uc';

function parse_nlbw_json(content) {
    if (content == null || content == "") return {};
    let data = json(content);
    if (data == null || type(data) != "object") return {};
    if (data.columns == null || data.data == null) return {};

    let col_mac = -1, col_rx = -1, col_tx = -1;
    for (let i = 0; i < length(data.columns); i++) {
        if (data.columns[i] == "mac") col_mac = i;
        else if (data.columns[i] == "rx_bytes") col_rx = i;
        else if (data.columns[i] == "tx_bytes") col_tx = i;
    }
    if (col_mac < 0 || col_rx < 0 || col_tx < 0) return {};

    let result = {};
    for (let row in data.data) {
        let mac = uc(row[col_mac]);
        let rx = +row[col_rx];
        let tx = +row[col_tx];
        if (result[mac] == null) {
            result[mac] = { rx: 0, tx: 0 };
        }
        result[mac].rx += rx;
        result[mac].tx += tx;
    }
    return result;
}

function get_traffic() {
    let content;
    if (ubus.is_openwrt) {
        let h = popen("nlbw -c json 2>/dev/null", 'r');
        if (h == null) return {};
        content = h.read('all');
        h.close();
    } else {
        content = util.read_file(ubus.fixtures_dir() + "/nlbw.json");
    }
    return parse_nlbw_json(content);
}

function subtract_baseline(current, baseline) {
    if (baseline == null || type(baseline) != "object") return current;
    let result = {};
    for (let mac in current) {
        let cur = current[mac];
        let base = baseline[mac];
        if (base == null) {
            result[mac] = { rx: cur.rx, tx: cur.tx };
        } else {
            let rx = cur.rx - base.rx;
            let tx = cur.tx - base.tx;
            // After reboot counters reset — use current as-is
            if (rx < 0) rx = cur.rx;
            if (tx < 0) tx = cur.tx;
            result[mac] = { rx, tx };
        }
    }
    return result;
}

function get_today_traffic(state_dir) {
    let current = get_traffic();
    let baseline_path = (state_dir || "/tmp/owrt-tgbot/state/") + "nlbw_midnight.json";
    let raw = util.read_file(baseline_path);
    if (raw == null || raw == "") return current;
    let baseline = json(raw);
    return subtract_baseline(current, baseline);
}

export { parse_nlbw_json, get_traffic, subtract_baseline, get_today_traffic };
