'use strict';

import * as h from './helpers.uc';
import * as ubus from '../src/lib/ubus_wrapper.uc';
import * as vnstat from '../src/lib/vnstat.uc';

ubus.set_fixtures_dir("fixtures");

let traffic_cmd = loadfile("src/commands/traffic.uc")();
let ctx = { config: { traffic: { interface: "eth1" } } };

return {

"vnstat.today: returns rx_bytes": () => {
    let data = vnstat.today("eth1");
    return h.assert_truthy(data != null && data.rx_bytes >= 0);
},

"vnstat.today: returns tx_bytes": () => {
    let data = vnstat.today("eth1");
    return h.assert_truthy(data != null && data.tx_bytes >= 0);
},

"vnstat.days: returns non-empty array": () => {
    let days = vnstat.days("eth1", 7);
    return h.assert_truthy(days != null && length(days) > 0);
},

"vnstat.days: entries have date field": () => {
    let days = vnstat.days("eth1", 7);
    return h.assert_truthy(days != null && days[0] != null && days[0].date != null);
},

"vnstat.month: returns rx_bytes": () => {
    let data = vnstat.month("eth1");
    return h.assert_truthy(data != null && data.rx_bytes >= 0);
},

"vnstat.top: returns non-empty array": () => {
    let top = vnstat.top("eth1", 5);
    return h.assert_truthy(top != null && length(top) > 0);
},

"traffic cmd: today returns text": () => {
    let result = traffic_cmd.handler(null, "", ctx);
    return h.assert_truthy(result != null && type(result.text) == "string");
},

"traffic cmd: today text contains Traffic": () =>
    h.assert_contains(traffic_cmd.handler(null, "", ctx).text, "Traffic"),

"traffic cmd: week subcommand": () =>
    h.assert_contains(traffic_cmd.handler(null, "week", ctx).text, "days"),

"traffic cmd: month subcommand": () =>
    h.assert_contains(traffic_cmd.handler(null, "month", ctx).text, "Month"),

"traffic cmd: top subcommand": () =>
    h.assert_contains(traffic_cmd.handler(null, "top", ctx).text, "Top"),

"traffic cmd: parse_mode is Markdown": () =>
    h.assert_eq(traffic_cmd.handler(null, "", ctx).opts.parse_mode, "Markdown"),

};
