#!/usr/bin/ucode -S
'use strict';

import * as util from './lib/util.uc';
import { load as load_config } from './config.uc';
import { create as create_backend } from './notify/backend.uc';
import { create as create_bot } from './core/bot.uc';

// Determine base directory from script path
let _sp = sourcepath();
let base_dir = _sp ? replace(_sp, /\/[^\/]+$/, "") : "src";

let config = load_config(base_dir);

// Validate config
if (config.bot_token == null || config.bot_token == "") {
    util.log("error", "bot_token is not configured");
    exit(1);
}

if (config.allowed_chat_ids == null || length(config.allowed_chat_ids) == 0 ||
    config.allowed_chat_ids[0] == "") {
    util.log("error", "allowed_chat_ids is not configured");
    exit(1);
}

util.log("info", "Creating notification backend: " + config.notify_backend);
let notify = create_backend(config.notify_backend, config);

// Create bot
let bot = create_bot(config, notify);

// Load commands from <base_dir>/commands/
let commands_dir = base_dir + "/commands";
bot.load_commands(commands_dir);

let n_commands = 0;
for (let k in bot.registry) n_commands++;

util.log("info", sprintf("Loaded %d commands, polling with timeout %ds",
    n_commands, config.poll_timeout));

bot.run();
