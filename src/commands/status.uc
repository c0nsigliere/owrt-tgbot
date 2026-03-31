'use strict';

import * as ubus from '../lib/ubus_wrapper.uc';
import * as util from '../lib/util.uc';

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
    name: "/status",
    description: "System status overview",

    handler: function(chat_id, args, ctx) {
        let board = ubus.call("system", "board") || {};
        let info  = ubus.call("system", "info")  || {};
        let wan   = ubus.call("network.interface.wan", "status") || {};
        let ic = util.icons;

        let model    = board.model    || "Unknown";
        let hostname = board.hostname || "OpenWrt";

        let uptime   = info.uptime || 0;
        let load_avg = info.load   || [];
        let mem      = info.memory || {};

        let load_str = "";
        if (length(load_avg) >= 3) {
            load_str = sprintf("%.2f %.2f %.2f",
                load_avg[0] / 65536.0,
                load_avg[1] / 65536.0,
                load_avg[2] / 65536.0);
        }

        let mem_total     = mem.total     || 0;
        let mem_available = mem.available || mem.free || 0;
        let mem_used      = mem_total - mem_available;

        let cpu_temp = get_cpu_temp();
        let temp_str = (cpu_temp != null) ? (cpu_temp + ic.degree + "C") : "N/A";

        // WAN info
        let wan_ip    = "N/A";
        let wan_addrs = wan["ipv4-address"];
        if (wan_addrs != null && length(wan_addrs) > 0) {
            wan_ip = wan_addrs[0].address || "N/A";
        }
        let wan_proto  = wan.proto    || "N/A";
        let wan_uptime = wan.uptime   || 0;
        let wan_dns    = wan["dns-server"] || [];

        let lines = [];
        push(lines, ic.computer + " *Router Status*");
        push(lines, ic.tee + " Model: "    + util.escape_markdown(model));
        push(lines, ic.tee + " Hostname: " + util.escape_markdown(hostname));
        push(lines, ic.tee + " Uptime: "   + util.format_uptime(uptime));
        push(lines, ic.tee + " Load: "     + load_str);
        push(lines, sprintf("%s RAM: %s/%s (%s)",
            ic.tee,
            util.format_bytes(mem_used),
            util.format_bytes(mem_total),
            util.format_percent(mem_used, mem_total)));
        push(lines, ic.tee + " CPU temp: " + temp_str);
        push(lines, ic.pipe);
        push(lines, ic.globe + " *WAN*");
        push(lines, ic.tee + " IP: "       + util.escape_markdown(wan_ip));
        push(lines, ic.tee + " Protocol: " + util.escape_markdown(wan_proto));
        push(lines, ic.tee + " Uptime: "   + util.format_uptime(wan_uptime));
        push(lines, ic.corner + " DNS: "   + util.escape_markdown(join(", ", wan_dns)));

        return { text: join("\n", lines), opts: { parse_mode: "Markdown" } };
    },
};
