'use strict';

import * as util from '../lib/util.uc';

return {
    name: "/help",
    description: "Show available commands",

    handler: function(chat_id, args, ctx) {
        let commands = ctx.commands || {};
        let ic = util.icons;

        let names = keys(commands);
        sort(names);

        let lines = [];
        push(lines, ic.robot + " *owrt-tgbot*");
        push(lines, ic.pipe);

        for (let i = 0; i < length(names); i++) {
            let name = names[i];
            let cmd = commands[name];
            let prefix = (i == length(names) - 1) ? ic.corner : ic.tee;
            push(lines, sprintf("%s %s %s %s", prefix, name, ic.dash, cmd.description || ""));
        }

        return { text: join("\n", lines), opts: { parse_mode: "Markdown" } };
    },
};
