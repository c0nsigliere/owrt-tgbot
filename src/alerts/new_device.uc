'use strict';

import { writefile } from 'fs';
import * as ubus from '../lib/ubus_wrapper.uc';
import * as util from '../lib/util.uc';
import * as devices_lib from '../lib/devices.uc';
import * as mac_vendor from '../lib/mac_vendor.uc';

const LEARNING_PERIOD = 120; // seconds after boot

return {
    name: "new_device",
    mode: "cron",

    check: function(ctx) {
        let ic = util.icons;

        // Check if in learning mode (suppress alerts after reboot)
        let sys_info = ubus.call("system", "info");
        let uptime = (sys_info != null) ? (sys_info.uptime || 999999) : 999999;
        let learning = (uptime < LEARNING_PERIOD);

        let state_file = ctx.state_dir + "known_macs.txt";

        // Load known MACs
        let known_set = {};
        let known_content = util.read_file(state_file);
        if (known_content != null) {
            for (let mac in split(known_content, "\n")) {
                mac = uc(util.trim(mac));
                if (mac != "") known_set[mac] = true;
            }
        }

        // Get current devices
        let devices = devices_lib.get_all();
        let new_devices = [];

        for (let dev in devices) {
            let mac = uc(dev.mac);
            if (!known_set[mac]) {
                known_set[mac] = true;
                if (!learning) push(new_devices, dev);
            }
        }

        // Update known MACs file
        let mac_list = "";
        for (let mac in known_set) mac_list += mac + "\n";
        writefile(state_file, mac_list);

        if (length(new_devices) == 0) return null;

        // Init vendor lookup for name resolution
        mac_vendor.init(ctx.state_dir, ctx.config);

        // Format alert
        let lines = [];
        if (length(new_devices) > 3) {
            push(lines, sprintf("%s *%d new devices detected*", ic["new"], length(new_devices)));
            for (let i = 0; i < length(new_devices); i++) {
                let dev = new_devices[i];
                let name = mac_vendor.resolve_display_name(dev);
                if (name == "unknown" && dev.ip != null) name = util.escape_markdown(dev.ip);
                let prefix = (i == length(new_devices) - 1) ? ic.corner : ic.tee;
                push(lines, sprintf("%s %s (%s)",
                    prefix,
                    util.escape_markdown(name),
                    util.escape_markdown(dev.mac)));
            }
        } else {
            for (let dev in new_devices) {
                let name_display = mac_vendor.resolve_display_name(dev);
                push(lines, sprintf(
                    "%s *New device detected*\n%s Name: %s\n%s IP: %s\n%s MAC: %s",
                    ic["new"], ic.tee,
                    name_display,
                    ic.tee,
                    util.escape_markdown(dev.ip || "?"),
                    ic.corner,
                    util.escape_markdown(dev.mac)));
            }
        }

        return { text: join("\n", lines) };
    },
};
