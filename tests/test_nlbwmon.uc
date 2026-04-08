'use strict';

import * as h from './helpers.uc';
import * as util from '../src/lib/util.uc';
import * as nlbwmon from '../src/lib/nlbwmon.uc';

let fixture = util.read_file("fixtures/nlbw.json");

return {

"parse_nlbw_json: aggregates rx by MAC": () => {
    let t = nlbwmon.parse_nlbw_json(fixture);
    // AA:BB:CC:DD:EE:01 has TCP(52428800) + UDP(102400) = 52531200
    return h.assert_eq(t["AA:BB:CC:DD:EE:01"].rx, 52531200);
},

"parse_nlbw_json: aggregates tx by MAC": () => {
    let t = nlbwmon.parse_nlbw_json(fixture);
    // AA:BB:CC:DD:EE:01 has TCP(10485760) + UDP(51200) = 10536960
    return h.assert_eq(t["AA:BB:CC:DD:EE:01"].tx, 10536960);
},

"parse_nlbw_json: multiple MACs parsed": () => {
    let t = nlbwmon.parse_nlbw_json(fixture);
    return h.assert_eq(length(keys(t)), 5);
},

"parse_nlbw_json: zero traffic MAC included": () => {
    let t = nlbwmon.parse_nlbw_json(fixture);
    return h.assert_eq(t["AA:BB:CC:DD:EE:04"].rx, 0);
},

"parse_nlbw_json: handles null": () => {
    let t = nlbwmon.parse_nlbw_json(null);
    return h.assert_eq(length(keys(t)), 0);
},

"parse_nlbw_json: handles empty string": () => {
    let t = nlbwmon.parse_nlbw_json("");
    return h.assert_eq(length(keys(t)), 0);
},

"parse_nlbw_json: handles missing columns": () => {
    let t = nlbwmon.parse_nlbw_json('{"columns":["family"],"data":[[4]]}');
    return h.assert_eq(length(keys(t)), 0);
},

"parse_nlbw_json: uppercases MAC": () => {
    let input = '{"columns":["family","proto","port","mac","ip","conns","rx_bytes","rx_pkts","tx_bytes","tx_pkts","layer7"],"data":[[4,"TCP",443,"aa:bb:cc:dd:ee:ff","192.168.1.1",1,1024,10,512,5,"HTTPS"]]}';
    let t = nlbwmon.parse_nlbw_json(input);
    return h.assert_not_null(t["AA:BB:CC:DD:EE:FF"]);
},

"subtract_baseline: subtracts baseline from current": () => {
    let current  = { "AA:BB": { rx: 1000, tx: 500 } };
    let baseline = { "AA:BB": { rx: 300,  tx: 100 } };
    let result = nlbwmon.subtract_baseline(current, baseline);
    return h.assert_eq(result["AA:BB"].rx, 700);
},

"subtract_baseline: new device not in baseline": () => {
    let current  = { "AA:BB": { rx: 1000, tx: 500 } };
    let baseline = {};
    let result = nlbwmon.subtract_baseline(current, baseline);
    return h.assert_eq(result["AA:BB"].rx, 1000);
},

"subtract_baseline: counter reset (reboot) uses current": () => {
    let current  = { "AA:BB": { rx: 100, tx: 50 } };
    let baseline = { "AA:BB": { rx: 5000, tx: 3000 } };
    let result = nlbwmon.subtract_baseline(current, baseline);
    return h.assert_eq(result["AA:BB"].rx, 100);
},

"subtract_baseline: null baseline returns current": () => {
    let current = { "AA:BB": { rx: 1000, tx: 500 } };
    let result = nlbwmon.subtract_baseline(current, null);
    return h.assert_eq(result["AA:BB"].rx, 1000);
},

"subtract_baseline: tx also subtracted": () => {
    let current  = { "AA:BB": { rx: 1000, tx: 500 } };
    let baseline = { "AA:BB": { rx: 300,  tx: 100 } };
    let result = nlbwmon.subtract_baseline(current, baseline);
    return h.assert_eq(result["AA:BB"].tx, 400);
},

};
