'use strict';

import * as util from '../lib/util.uc';
import * as mac_vendor from '../lib/mac_vendor.uc';
import * as devices_lib from '../lib/devices.uc';

function is_valid_mac(s) {
    return match(s, /^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$/) != null;
}

return {
    name: "/rename",
    description: "Rename a device by MAC",

    handler: function(chat_id, args, ctx) {
        let ic = util.icons;
        mac_vendor.init(ctx.state_dir, ctx.config);

        let a = util.trim(args);

        // No args: list all aliases
        if (a == "") {
            let aliases = mac_vendor.get_aliases();
            let macs = keys(aliases);
            if (length(macs) == 0) {
                return {
                    text: ic.phone + " *No device aliases set.*\n\nUsage:\n`/rename MAC Name` " + ic.dash + " set alias\n`/rename MAC` " + ic.dash + " remove alias",
                    opts: { parse_mode: "Markdown" },
                };
            }

            let devices = devices_lib.get_all();
            let dev_by_mac = {};
            for (let dev in devices) dev_by_mac[uc(dev.mac)] = dev;

            let lines = [];
            push(lines, ic.phone + " *Device aliases*");
            macs = sort(macs);
            for (let i = 0; i < length(macs); i++) {
                let mac = macs[i];
                let name = aliases[mac];
                let dev = dev_by_mac[mac];
                let status = dev != null ? (dev.online ? ic.green : ic.white) : ic.red;
                let ip = (dev != null && dev.ip != null) ? dev.ip : "?";
                let prefix = (i == length(macs) - 1) ? ic.corner : ic.tee;
                push(lines, sprintf("%s %s %s (%s, %s)",
                    prefix, status,
                    util.escape_markdown(name),
                    util.escape_markdown(ip),
                    util.escape_markdown(mac)));
            }
            return { text: join("\n", lines), opts: { parse_mode: "Markdown" } };
        }

        // Parse: first token is MAC, rest is name
        let m = match(a, /^(\S+)\s*(.*)/);
        if (m == null) {
            return { text: ic.warning + " Usage: `/rename MAC Name`", opts: { parse_mode: "Markdown" } };
        }

        let mac = uc(m[1]);
        let name = util.trim(m[2]);

        if (!is_valid_mac(mac)) {
            return {
                text: ic.warning + " Invalid MAC format: `" + util.escape_markdown(mac) + "`\nExpected: `AA:BB:CC:DD:EE:FF`",
                opts: { parse_mode: "Markdown" },
            };
        }

        // Find device info
        let devices = devices_lib.get_all();
        let dev = null;
        for (let d in devices) {
            if (uc(d.mac) == mac) { dev = d; break; }
        }

        if (name == "") {
            // Remove alias
            let old = mac_vendor.get_alias(mac);
            if (old == null) {
                return {
                    text: ic.info + " No alias set for `" + util.escape_markdown(mac) + "`",
                    opts: { parse_mode: "Markdown" },
                };
            }
            mac_vendor.remove_alias(mac);
            mac_vendor.save_to_disk();

            let info = "";
            if (dev != null) {
                let resolved = mac_vendor.resolve_name(dev);
                info = "\nNow shows as: " + util.escape_markdown(resolved.name);
            }
            return {
                text: ic.check + " Alias removed for `" + util.escape_markdown(mac) + "`" + info,
                opts: { parse_mode: "Markdown" },
            };
        }

        // Set alias
        mac_vendor.set_alias(mac, name);
        mac_vendor.save_to_disk();

        let status = "";
        if (dev != null) {
            status = " (" + (dev.online ? "online" : "offline");
            if (dev.ip != null) status += ", " + dev.ip;
            status += ")";
        }

        return {
            text: ic.check + " *" + util.escape_markdown(mac) + "* renamed to *" + util.escape_markdown(name) + "*" + status,
            opts: { parse_mode: "Markdown" },
        };
    },
};
