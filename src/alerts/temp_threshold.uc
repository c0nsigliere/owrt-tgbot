'use strict';

import { writefile } from 'fs';
import * as util from '../lib/util.uc';
import * as ubus from '../lib/ubus_wrapper.uc';

const COOLDOWN = 900; // 15 minutes between repeated alerts

function get_cpu_temp() {
    let temp_path = ubus.is_openwrt
        ? "/sys/class/thermal/thermal_zone0/temp"
        : ubus.fixtures_dir() + "/thermal_zone0_temp";

    let temp_str = util.read_file(temp_path);
    if (temp_str == null) return null;
    let temp = +util.trim(temp_str);
    if (!(temp > 0) && !(temp < 0) && !(temp == 0)) return null;
    return int(temp / 1000);
}

return {
    name: "temp_threshold",
    mode: "cron",

    check: function(ctx) {
        let temp = get_cpu_temp();
        if (temp == null) return null;

        let ic = util.icons;
        let limit = (ctx.config.alerts && ctx.config.alerts.temp_limit) || 85;
        let state_file = ctx.state_dir + "temp_alert_state";
        let prev_content = util.read_file(state_file);

        let prev_state = "normal";
        let prev_time  = 0;
        if (prev_content != null) {
            let m = match(prev_content, /^(\S+):?(\d*)/);
            if (m) {
                prev_state = m[1];
                prev_time  = +(m[2] || "0");
            }
        }

        let now = time();

        if (temp >= limit) {
            writefile(state_file, "alert:" + now);
            if (prev_state == "normal" || (now - prev_time >= COOLDOWN)) {
                return {
                    text: sprintf("%s *CPU temperature alert*\nCurrent: %d%sC (limit: %d%sC)",
                        ic.fire, temp, ic.degree, limit, ic.degree)
                };
            }
        } else {
            writefile(state_file, "normal:" + now);
            if (prev_state == "alert") {
                return {
                    text: sprintf("%s *CPU temperature back to normal*\nCurrent: %d%sC",
                        ic.check, temp, ic.degree)
                };
            }
        }

        return null;
    },
};
