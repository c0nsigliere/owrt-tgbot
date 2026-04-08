'use strict';

import { writefile } from 'fs';
import * as util from '../lib/util.uc';
import * as devices_lib from '../lib/devices.uc';
import * as mac_vendor from '../lib/mac_vendor.uc';

const PAGE_SIZE = 10;

function format_device_list(devices, start, end, ic, now, conn_state, offline_state) {
    let lines = [];
    for (let i = start; i < end; i++) {
        let dev = devices[i];
        let status_icon = dev.online ? ic.green : ic.white;
        let resolved = mac_vendor.resolve_name(dev);
        let display_name = mac_vendor.resolve_display_name(dev);
        if (resolved.style == "unknown" || resolved.style == "random") {
            status_icon = ic.yellow;
        }

        let is_last = (i == end - 1);
        let prefix = is_last ? ic.corner : ic.tee;
        let cont = is_last ? "  " : ic.pipe;

        push(lines, sprintf("%s %s %s", prefix, status_icon, display_name));

        // Connection duration or last-seen line
        if (dev.online) {
            let entry = conn_state[dev.mac];
            if (entry != null) {
                let duration = now - entry.since;
                if (duration < 60) duration = 60;
                push(lines, sprintf("%s     Online %s", cont,
                    util.escape_markdown(util.format_uptime(duration))));
            }
        } else {
            let entry = offline_state[dev.mac];
            if (entry != null && entry.seen != null) {
                let ago = now - entry.seen;
                if (ago > 0) {
                    push(lines, sprintf("%s     Seen %s ago", cont,
                        util.escape_markdown(util.format_uptime(ago))));
                }
            }
        }

        push(lines, sprintf("%s     %s %s", cont,
            util.escape_markdown(dev.ip || "?"),
            util.escape_markdown(dev.mac || "?")));

        if (dev.signal != null) {
            push(lines, sprintf("%s     %s %s dBm", cont,
                util.escape_markdown(dev.band || "Wi-Fi"),
                dev.signal));
        } else if (dev.band != null) {
            push(lines, sprintf("%s     %s", cont, util.escape_markdown(dev.band)));
        }
    }
    return lines;
}

function build_page(page, ctx) {
    mac_vendor.init(ctx.state_dir, ctx.config);
    let devices = devices_lib.get_all();
    let ic = util.icons;
    let now = time();

    // Load/update connection state for online devices
    let conn_state_file = ctx.state_dir + "device_connections.json";
    let conn_raw = util.read_file(conn_state_file);
    let conn_state = (conn_raw != null) ? json(conn_raw) : null;
    if (conn_state == null || type(conn_state) != "object") conn_state = {};

    let new_conn_state = {};
    for (let dev in devices) {
        if (!dev.online) continue;
        let mac = dev.mac;
        if (dev.connected_time != null) {
            // Wi-Fi: authoritative — always use kernel value
            new_conn_state[mac] = { since: now - dev.connected_time };
        } else if (conn_state[mac] != null) {
            // Wired, already tracked — keep existing timestamp
            new_conn_state[mac] = conn_state[mac];
        } else {
            // Wired, first seen — start from now
            new_conn_state[mac] = { since: now };
        }
    }
    writefile(conn_state_file, sprintf("%J", new_conn_state));

    // Load device_offline state for last-seen info
    let offline_raw = util.read_file(ctx.state_dir + "device_offline.json");
    let offline_state = (offline_raw != null) ? json(offline_raw) : null;
    if (offline_state == null || type(offline_state) != "object") offline_state = {};

    let online_count = 0;
    for (let dev in devices) {
        if (dev.online) online_count++;
    }

    let total = length(devices);
    let pages = int((total + PAGE_SIZE - 1) / (PAGE_SIZE * 1.0));
    if (pages < 1) pages = 1;
    if (page > pages) page = pages;
    if (page < 1) page = 1;
    let start = (page - 1) * PAGE_SIZE;
    let end = start + PAGE_SIZE;
    if (end > total) end = total;

    let lines = [];
    push(lines, sprintf("%s *Connected Devices (%d online, %d total) — %d/%d*",
        ic.phone, online_count, total, page, pages));
    push(lines, ic.pipe);
    let dl = format_device_list(devices, start, end, ic, now, new_conn_state, offline_state);
    for (let l in dl) push(lines, l);

    let text = join("\n", lines);

    // Build inline keyboard
    let buttons = [];
    if (page > 1) {
        push(buttons, { text: "\u2B05 Prev", callback_data: "devices:" + (page - 1) });
    }
    if (pages > 1) {
        push(buttons, { text: "" + page + "/" + pages, callback_data: "devices:noop" });
    }
    if (page < pages) {
        push(buttons, { text: "Next \u27A1", callback_data: "devices:" + (page + 1) });
    }

    let reply_markup = null;
    if (length(buttons) > 0) {
        reply_markup = { inline_keyboard: [buttons] };
    }

    return {
        text,
        opts: { parse_mode: "Markdown", reply_markup },
    };
}

return {
    name: "/devices",
    description: "Connected devices",
    callback_name: "devices",

    handler: function(chat_id, args, ctx) {
        let page = 1;
        let a = util.trim(args);
        if (a != "") {
            let p = +a;
            if (p > 0) page = int(p);
        }
        return build_page(page, ctx);
    },

    on_callback: function(chat_id, message_id, cb_args, ctx) {
        if (cb_args == "noop") return null;
        let page = +cb_args;
        if (!(page > 0)) page = 1;
        return build_page(int(page), ctx);
    },
};
