'use strict';

import * as util from '../lib/util.uc';
import * as vnstat from '../lib/vnstat.uc';

const MONTH_NAMES = ["Jan","Feb","Mar","Apr","May","Jun",
                     "Jul","Aug","Sep","Oct","Nov","Dec"];

function format_date(d) {
    if (d == null) return "?";
    return sprintf("%04d-%02d-%02d", d.year || 0, d.month || 0, d.day || 0);
}

function format_short_date(d) {
    if (d == null) return "?";
    let mn = (d.month >= 1 && d.month <= 12) ? MONTH_NAMES[d.month - 1] : "???";
    return sprintf("%s %d", mn, d.day || 0);
}

function show_today(interface) {
    let ic = util.icons;
    let data = vnstat.today(interface);
    if (data == null) return ic.warning + " vnstat error: no data";
    let total = data.rx_bytes + data.tx_bytes;
    let lines = [];
    push(lines, ic.chart + " *Traffic " + ic.dash + " Today*");
    push(lines, ic.tee + " RX: "    + util.format_bytes(data.rx_bytes));
    push(lines, ic.tee + " TX: "    + util.format_bytes(data.tx_bytes));
    push(lines, ic.corner + " Total: " + util.format_bytes(total));
    return join("\n", lines);
}

function show_week(interface) {
    let ic = util.icons;
    let day_list = vnstat.days(interface, 7);
    if (day_list == null) return ic.warning + " vnstat error: no data";
    if (length(day_list) == 0) return "No traffic data available.";

    let max_total = 0;
    for (let d in day_list) {
        let total = d.rx_bytes + d.tx_bytes;
        if (total > max_total) max_total = total;
    }

    let grand_total = 0;
    let lines = [];
    push(lines, ic.calendar + " *Last 7 days*");
    for (let i = 0; i < length(day_list); i++) {
        let d = day_list[i];
        let total = d.rx_bytes + d.tx_bytes;
        grand_total += total;
        let prefix = (i == length(day_list) - 1) ? ic.corner : ic.tee;
        push(lines, sprintf("%s %s: %s  %s",
            prefix,
            format_short_date(d.date),
            util.format_bytes(total),
            util.bar_chart(total, max_total, 10)));
    }
    push(lines, ic.corner + " Total: " + util.format_bytes(grand_total));
    return join("\n", lines);
}

function show_month(interface) {
    let ic = util.icons;
    let data = vnstat.month(interface);
    if (data == null) return ic.warning + " vnstat error: no data";
    let total = data.rx_bytes + data.tx_bytes;
    let lines = [];
    push(lines, ic.chart + " *Traffic " + ic.dash + " This Month*");
    push(lines, ic.tee + " RX: "    + util.format_bytes(data.rx_bytes));
    push(lines, ic.tee + " TX: "    + util.format_bytes(data.tx_bytes));
    push(lines, ic.corner + " Total: " + util.format_bytes(total));
    return join("\n", lines);
}

function show_top(interface) {
    let ic = util.icons;
    let top_list = vnstat.top(interface, 5);
    if (top_list == null) return ic.warning + " vnstat error: no data";
    if (length(top_list) == 0) return "No traffic data available.";

    let lines = [];
    push(lines, ic.trophy + " *Top Days by Traffic*");
    for (let i = 0; i < length(top_list); i++) {
        let d = top_list[i];
        let total = d.rx_bytes + d.tx_bytes;
        let prefix = (i == length(top_list) - 1) ? ic.corner : ic.tee;
        push(lines, sprintf("%s %s: %s", prefix, format_date(d.date), util.format_bytes(total)));
    }
    return join("\n", lines);
}

return {
    name: "/traffic",
    description: "Traffic statistics",
    usage: "/traffic [week|month|top]",

    handler: function(chat_id, args, ctx) {
        let interface = (ctx.config.traffic && ctx.config.traffic.interface) || "eth0";
        let subcmd = lc(util.trim(args));

        let text;
        if (subcmd == "week")       text = show_week(interface);
        else if (subcmd == "month") text = show_month(interface);
        else if (subcmd == "top")   text = show_top(interface);
        else                        text = show_today(interface);

        return { text, opts: { parse_mode: "Markdown" } };
    },
};
