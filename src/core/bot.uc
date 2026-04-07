'use strict';

import { stat, popen } from 'fs';
import * as util from '../lib/util.uc';

const MAX_CONCURRENT_TASKS = 2;
const TASK_TTL = 90;
const TASKS_DIR = "/tmp/owrt-tgbot/tasks/";

function count_tasks(pending_tasks) {
    let n = 0;
    for (let k in pending_tasks) n++;
    return n;
}

function check_completed_tasks(pending_tasks, notify) {
    for (let task_id in pending_tasks) {
        let task = pending_tasks[task_id];
        let result_file = TASKS_DIR + task_id + ".result";
        let pid_file    = TASKS_DIR + task_id + ".pid";

        if (util.file_exists(result_file)) {
            let raw = util.read_file(result_file);
            if (raw != null) {
                let text = raw;
                let opts = { parse_mode: "Markdown" };
                if (task.cmd != null && task.cmd.format_result != null) {
                    let r = task.cmd.format_result(raw);
                    if (r != null) {
                        text = r.text || raw;
                        opts = r.opts || opts;
                    }
                }
                notify.send_message(task.chat_id, text, opts);
            }
            system("rm -f '" + result_file + "' '" + pid_file + "'");
            delete pending_tasks[task_id];
        } else if (time() - task.started > TASK_TTL) {
            let pid_content = util.read_file(pid_file);
            if (pid_content != null) {
                let m = match(pid_content, /(\d+)/);
                if (m) system("kill " + m[1] + " 2>/dev/null");
            }
            notify.send_message(task.chat_id,
                util.icons.warning + " Command timed out. The router may be under heavy load.");
            system("rm -f '" + result_file + "' '" + pid_file + "'");
            delete pending_tasks[task_id];
        }
    }
}

function create(config, notify) {
    let registry = {};
    let callback_registry = {};
    let pending_tasks = {};
    let offset = null;

    // Build allowed set for O(1) lookup
    let allowed_set = {};
    for (let id in config.allowed_chat_ids) {
        allowed_set["" + id] = true;
    }

    function load_commands(commands_dir) {
        // List .uc files in the commands directory
        let h = popen("ls '" + commands_dir + "' 2>/dev/null", 'r');
        if (h == null) {
            util.log("error", "Cannot list commands directory: " + commands_dir);
            return;
        }
        let listing = h.read('all');
        h.close();
        if (listing == null) return;

        for (let filename in split(listing, "\n")) {
            filename = util.trim(filename);
            if (filename == "") continue;
            if (!match(filename, /\.uc$/)) continue;

            let filepath = commands_dir + "/" + filename;
            let mod = loadfile(filepath)();
            if (mod != null && mod.name != null && mod.handler != null) {
                registry[mod.name] = mod;
                if (mod.callback_name != null && mod.on_callback != null) {
                    callback_registry[mod.callback_name] = mod.on_callback;
                }
                util.log("debug", "Loaded command: " + mod.name);
            } else if (mod == null) {
                util.log("error", "Failed to load command " + filename);
            }
        }
    }

    function handle_callback_query(cq) {
        if (cq == null) return;
        let from = cq.from;
        if (from == null) return;
        if (!allowed_set["" + from.id]) return;

        let data = cq.data;
        if (data == null) return;

        // data format: "cmd:args" e.g. "devices:2" or "devices:all"
        let m = match(data, /^(\w+):(.*)$/);
        if (m == null) {
            notify.answer_callback_query(cq.id);
            return;
        }

        let cb_name = m[1];
        let cb_args = m[2];
        let handler = callback_registry[cb_name];

        if (handler == null) {
            notify.answer_callback_query(cq.id);
            return;
        }

        let msg = cq.message;
        let chat_id = (msg != null && msg.chat != null) ? msg.chat.id : from.id;
        let message_id = (msg != null) ? msg.message_id : null;
        let ctx = { config, notify, commands: registry, state_dir: "/tmp/owrt-tgbot/state/" };

        let response = handler(chat_id, message_id, cb_args, ctx);
        if (response != null && message_id != null) {
            notify.edit_message_text(chat_id, message_id, response.text, response.opts);
        }
        notify.answer_callback_query(cq.id);
    }

    function handle_update(update) {
        if (update == null) return;

        // Handle callback queries (inline button presses)
        if (update.callback_query != null) {
            handle_callback_query(update.callback_query);
            return;
        }

        let message = update.message;
        if (message == null) return;

        let chat = message.chat;
        if (chat == null) return;
        let chat_id = chat.id;
        if (chat_id == null) return;

        // Auth check
        if (!allowed_set["" + chat_id]) return;

        let text = message.text;
        if (text == null) return;

        // Parse command: /name or /name@botname
        let m = match(text, /^(\/\w+)\s*(.*)/);
        if (m == null) return;

        let cmd_name = m[1];
        let args = m[2] || "";

        // Strip @botname suffix
        let m2 = match(cmd_name, /^(\/\w+)@/);
        if (m2) cmd_name = m2[1];

        let cmd_module = registry[cmd_name];
        if (cmd_module == null) {
            notify.send_message(chat_id,
                "Unknown command: " + util.escape_markdown(cmd_name) + "\nUse /help to see available commands.",
                { parse_mode: "Markdown" });
            return;
        }

        let ctx = { config, notify, commands: registry, state_dir: "/tmp/owrt-tgbot/state/" };

        if (cmd_module.async) {
            if (count_tasks(pending_tasks) >= MAX_CONCURRENT_TASKS) {
                notify.send_message(chat_id, util.icons.hourglass + " Busy, try again in a minute.");
                return;
            }
            let task_id = cmd_module.start(chat_id, args, ctx);
            if (task_id != null) {
                notify.send_message(chat_id, util.icons.hourglass + " Working on it...");
                pending_tasks[task_id] = { chat_id, started: time(), cmd: cmd_module };
            } else {
                util.log("error", "Async command returned null task_id: " + cmd_name);
                notify.send_message(chat_id,
                    util.icons.warning + " Error starting command. Check router logs.");
            }
        } else {
            let response = cmd_module.handler(chat_id, args, ctx);
            if (response != null) {
                notify.send_message(chat_id, response.text, response.opts);
            } else {
                util.log("error", "Command " + cmd_name + " returned null");
                notify.send_message(chat_id,
                    util.icons.warning + " Error executing command. Check router logs.");
            }
        }
    }

    function run() {
        util.log("info", "owrt-tgbot starting");
        system("mkdir -p " + TASKS_DIR);

        while (true) {
            let updates = notify.get_updates(offset, config.poll_timeout);

            if (updates != null) {
                for (let update in updates) {
                    if (update != null && update.update_id != null) {
                        handle_update(update);
                        offset = update.update_id + 1;
                    }
                }
            } else {
                util.log("error", "Polling error — sleeping 5s");
                system("sleep 5");
            }

            // Check async tasks
            check_completed_tasks(pending_tasks, notify);

            // Drain queued messages
            if (notify.drain_queue != null) {
                notify.drain_queue();
            }
        }
    }

    return { load_commands, handle_update, run, registry, pending_tasks };
}

export { create };
