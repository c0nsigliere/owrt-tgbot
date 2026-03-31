'use strict';

import { writefile } from 'fs';
import * as ubus from '../lib/ubus_wrapper.uc';
import * as util from '../lib/util.uc';

return {
    name: "wan_status",
    mode: "cron",

    check: function(ctx) {
        let wan = ubus.call("network.interface.wan", "status");
        if (wan == null) return null;

        let ic = util.icons;
        let current_up = (wan.up == true);
        let state_file = ctx.state_dir + "wan_state";
        let prev_content = util.read_file(state_file);

        let prev_state = null;
        let prev_time  = null;
        if (prev_content != null) {
            let m = match(prev_content, /^(\S+):(\d+)/);
            if (m) {
                prev_state = m[1];
                prev_time  = +m[2];
            }
        }

        let current_state = current_up ? "up" : "down";
        let now = time();

        // Write current state
        writefile(state_file, current_state + ":" + now);

        // No previous state — first run, no alert
        if (prev_state == null) return null;

        // No transition — no alert
        if (prev_state == current_state) return null;

        // Transition detected
        if (current_state == "down") {
            return { text: ic.red + " *WAN is down!*" };
        } else {
            let downtime_str = "";
            if (prev_time != null) {
                let downtime = now - prev_time;
                downtime_str = " (downtime: " + util.format_uptime(downtime) + ")";
            }
            return { text: ic.green + " *WAN is back up*" + downtime_str };
        }
    },
};
