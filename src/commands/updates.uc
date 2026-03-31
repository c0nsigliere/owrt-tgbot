'use strict';

import * as util from '../lib/util.uc';
import * as opkg from '../lib/opkg.uc';
import * as ubus from '../lib/ubus_wrapper.uc';

const TASKS_DIR = "/tmp/owrt-tgbot/tasks/";

function format_result(packages) {
    let ic = util.icons;
    if (packages == null || length(packages) == 0) {
        return ic.package + " *Package Updates*\n"
            + ic.corner + " All packages are up to date.";
    }

    let lines = [];
    push(lines, sprintf("%s *Package Updates (%d available)*", ic.package, length(packages)));
    push(lines, ic.pipe);

    for (let i = 0; i < length(packages); i++) {
        let pkg = packages[i];
        let prefix = (i == length(packages) - 1) ? ic.corner : ic.tee;
        push(lines, sprintf("%s %s: %s %s %s",
            prefix,
            util.escape_markdown(pkg.name),
            util.escape_markdown(pkg.current),
            ic.arrow,
            util.escape_markdown(pkg.available)));
    }

    push(lines, ic.pipe);
    let hint = opkg.has_apk ? "apk upgrade <package>" : "opkg upgrade <package>";
    push(lines, ic.info + " Run manually: `" + hint + "`");

    return join("\n", lines);
}

return {
    name: "/updates",
    description: "Check for package updates",
    async: true,

    // Format raw output from .result file (called by bot.uc for async tasks)
    format_result: function(raw) {
        let packages = opkg.parse_upgradable(raw);
        return { text: format_result(packages), opts: { parse_mode: "Markdown" } };
    },

    // Sync fallback for dev mode
    handler: function(chat_id, args, ctx) {
        let packages = opkg.list_upgradable();
        return { text: format_result(packages), opts: { parse_mode: "Markdown" } };
    },

    start: function(chat_id, args, ctx) {
        if (!ubus.is_openwrt) return null;

        let task_id = "updates_" + time() + "_" + chat_id;
        let result_file = TASKS_DIR + task_id + ".result";
        let pid_file    = TASKS_DIR + task_id + ".pid";

        system("mkdir -p " + TASKS_DIR);

        // Spawn background process — write PID, check updates, write result atomically
        let cmd = opkg.has_apk
            ? "apk upgrade --simulate"
            : "opkg list-upgradable";
        let script = sprintf(
            'sh -c \'echo $$ > "%s"; %s > "%s.tmp" 2>/dev/null; mv "%s.tmp" "%s"\' &',
            pid_file, cmd, result_file, result_file, result_file);

        system(script);
        return task_id;
    },
};
