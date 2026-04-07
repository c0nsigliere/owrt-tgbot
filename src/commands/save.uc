'use strict';

import { popen } from 'fs';
import * as util from '../lib/util.uc';

const TMP_STATE     = "/tmp/owrt-tgbot/state/";
const PERSIST_STATE = "/etc/owrt-tgbot/state/";

return {
    name: "/save",
    description: "Save state to flash",

    handler: function(chat_id, args, ctx) {
        let ic = util.icons;
        system("mkdir -p " + PERSIST_STATE);

        let h = popen("ls " + TMP_STATE + " 2>/dev/null", 'r');
        if (h == null) {
            return { text: ic.warning + " No state directory found.",
                     opts: { parse_mode: "Markdown" } };
        }
        let listing = h.read('all');
        h.close();

        if (util.trim(listing) == "") {
            return { text: ic.floppy + " No state to save (state directory is empty).",
                     opts: { parse_mode: "Markdown" } };
        }

        system("cp " + TMP_STATE + "* " + PERSIST_STATE + " 2>/dev/null");

        let lines = [];
        push(lines, ic.floppy + " *State saved to flash.*");

        for (let filename in split(listing, "\n")) {
            filename = util.trim(filename);
            if (filename == "") continue;

            let content = util.read_file(TMP_STATE + filename);
            let detail;
            if (filename == "known_macs.txt" && content != null) {
                let count = 0;
                for (let _ in split(content, "\n")) {
                    if (util.trim(_) != "") count++;
                }
                detail = count + " devices";
            } else if (filename == "wan_state" && content != null) {
                let m = match(util.trim(content), /^(\S+)/);
                detail = m ? m[1] : "";
            } else if (filename == "temp_alert_state" && content != null) {
                let m = match(util.trim(content), /^(\S+)/);
                detail = m ? m[1] : "";
            } else if (filename == "device_aliases.json" && content != null) {
                let obj = json(content);
                let count = 0;
                if (obj != null) for (let _ in obj) count++;
                detail = count + " aliases";
            } else if (filename == "vendor_cache.json" && content != null) {
                let obj = json(content);
                let count = 0;
                if (obj != null) for (let _ in obj) count++;
                detail = count + " vendors cached";
            } else {
                detail = "saved";
            }
            push(lines, sprintf("%s %s: %s", ic.tee, util.escape_markdown(filename), detail));
        }

        // Fix last line prefix to corner
        if (length(lines) > 1) {
            lines[length(lines) - 1] = replace(lines[length(lines) - 1], ic.tee, ic.corner);
        }

        return { text: join("\n", lines), opts: { parse_mode: "Markdown" } };
    },
};
