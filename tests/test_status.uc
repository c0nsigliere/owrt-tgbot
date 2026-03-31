'use strict';

import * as h from './helpers.uc';
import * as ubus from '../src/lib/ubus_wrapper.uc';

ubus.set_fixtures_dir("fixtures");

// Commands use return{}, loaded via loadfile
let status_cmd = loadfile("src/commands/status.uc")();
let ctx = { config: { traffic: { interface: "eth1" } } };

return {

"status: has correct command name": () =>
    h.assert_eq(status_cmd.name, "/status"),

"status: has description": () =>
    h.assert_truthy(status_cmd.description),

"status: handler returns object with text": () => {
    let result = status_cmd.handler(null, "", ctx);
    return h.assert_truthy(result != null && type(result.text) == "string",
        "result.text should be a string");
},

"status: Markdown parse_mode": () => {
    let result = status_cmd.handler(null, "", ctx);
    return h.assert_eq(result.opts && result.opts.parse_mode, "Markdown");
},

"status: contains Cudy (router model)": () =>
    h.assert_contains(status_cmd.handler(null, "", ctx).text, "Cudy"),

"status: contains Uptime": () =>
    h.assert_contains(status_cmd.handler(null, "", ctx).text, "Uptime"),

"status: contains RAM": () =>
    h.assert_contains(status_cmd.handler(null, "", ctx).text, "RAM"),

"status: contains WAN section": () =>
    h.assert_contains(status_cmd.handler(null, "", ctx).text, "WAN"),

"status: contains WAN IP (203.0.113.42)": () =>
    h.assert_contains(status_cmd.handler(null, "", ctx).text, "203.0.113.42"),

"status: contains load average (0.04)": () =>
    h.assert_contains(status_cmd.handler(null, "", ctx).text, "0.04"),

};
