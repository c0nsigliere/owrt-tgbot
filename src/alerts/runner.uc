#!/usr/bin/ucode -S
'use strict';

// Alert runner — called by cron every minute
// Standalone script, not a module

import { popen } from 'fs';

// Determine base directory (src/) from this script's path
let _sp = sourcepath();
let script_dir = _sp ? replace(_sp, /\/[^\/]+$/, "") : "src/alerts";
let base_dir = script_dir + "/..";

import * as util from '../lib/util.uc';
import { load as load_config } from '../config.uc';
import { create as create_backend } from '../notify/backend.uc';

let config = load_config(base_dir);

if (!config.alerts.enabled) {
    exit(0);
}

let notify = create_backend(config.notify_backend, config);

const STATE_DIR = "/tmp/owrt-tgbot/state/";
system("mkdir -p " + STATE_DIR);

let ctx = {
    config,
    notify,
    state_dir: STATE_DIR,
};

// Load alert modules from this directory
let h = popen("ls '" + script_dir + "' 2>/dev/null", 'r');
if (h == null) {
    util.log("error", "Cannot list alerts directory: " + script_dir);
    exit(1);
}
let listing = h.read('all');
h.close();

let alert_modules = [];
for (let filename in split(listing, "\n")) {
    filename = util.trim(filename);
    if (filename == "" || !match(filename, /\.uc$/) || filename == "runner.uc") continue;

    let filepath = script_dir + "/" + filename;
    let mod = loadfile(filepath)();
    if (mod != null && mod.name != null && mod.check != null) {
        push(alert_modules, mod);
    } else if (mod == null) {
        util.log("error", "Failed to load alert: " + filename);
    }
}

// Check enabled alerts, collect messages
let messages = [];

for (let alert_mod in alert_modules) {
    let enabled = true;
    if      (alert_mod.name == "new_device")      enabled = config.alerts.new_device;
    else if (alert_mod.name == "wan_status")       enabled = config.alerts.wan_status;
    else if (alert_mod.name == "temp_threshold")   enabled = config.alerts.temp_threshold;

    if (!enabled) continue;

    let result = alert_mod.check(ctx);
    if (result != null && result.text != null) {
        push(messages, result.text);
    }
}

// Send collected messages to all allowed chat IDs
if (length(messages) > 0) {
    let ic = util.icons;
    let text;
    if (length(messages) > 3) {
        text = ic.bell + " *Alert Summary*\n\n" + join("\n\n", messages);
    } else {
        text = join("\n\n", messages);
    }

    for (let chat_id in config.allowed_chat_ids) {
        notify.send_message(chat_id, text, { parse_mode: "Markdown" });
    }
}
