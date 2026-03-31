'use strict';

import * as telegram_api from '../core/telegram.uc';

const MAX_MESSAGES_PER_MINUTE = 15;
const QUEUE_DRAIN_INTERVAL = 4;

function clean_old_timestamps(timestamps) {
    let now = time();
    let cutoff = now - 60;
    let cleaned = [];
    for (let ts in timestamps) {
        if (ts > cutoff) push(cleaned, ts);
    }
    return cleaned;
}

function create(config) {
    telegram_api.init(config.bot_token, config);

    let msg_timestamps = {};
    let msg_queue = {};
    let last_drain_time = 0;

    function send_message(chat_id, text, opts) {
        let parse_mode = (opts != null) ? opts.parse_mode : null;
        let reply_markup = (opts != null) ? opts.reply_markup : null;
        let cid = "" + chat_id;

        msg_timestamps[cid] = clean_old_timestamps(msg_timestamps[cid] || []);
        if (length(msg_timestamps[cid]) >= MAX_MESSAGES_PER_MINUTE) {
            if (msg_queue[cid] == null) msg_queue[cid] = [];
            push(msg_queue[cid], { text, parse_mode, reply_markup });
            return true;
        }

        let result = telegram_api.send_message(chat_id, text, parse_mode, reply_markup);
        if (result != null) {
            push(msg_timestamps[cid], time());
        }
        return result != null;
    }

    function edit_message_text(chat_id, message_id, text, opts) {
        let parse_mode = (opts != null) ? opts.parse_mode : null;
        let reply_markup = (opts != null) ? opts.reply_markup : null;
        return telegram_api.edit_message_text(chat_id, message_id, text, parse_mode, reply_markup);
    }

    function answer_callback_query(callback_query_id, text) {
        return telegram_api.answer_callback_query(callback_query_id, text);
    }

    function send_photo(chat_id, file_path, caption) {
        return telegram_api.send_photo(chat_id, file_path, caption);
    }

    function supports_commands() {
        return true;
    }

    function get_updates(offset, timeout) {
        return telegram_api.get_updates(offset, timeout);
    }

    function drain_queue() {
        let now = time();
        if (now - last_drain_time < QUEUE_DRAIN_INTERVAL) return;
        last_drain_time = now;

        for (let cid in msg_queue) {
            let queue = msg_queue[cid];
            if (queue == null || length(queue) == 0) continue;

            msg_timestamps[cid] = clean_old_timestamps(msg_timestamps[cid] || []);
            if (length(msg_timestamps[cid]) < MAX_MESSAGES_PER_MINUTE) {
                let item = shift(queue);
                let result = telegram_api.send_message(cid, item.text, item.parse_mode, item.reply_markup);
                if (result != null) {
                    push(msg_timestamps[cid], now);
                }
            }
            if (length(msg_queue[cid]) == 0) {
                delete msg_queue[cid];
            }
        }
    }

    return { send_message, send_photo, supports_commands, get_updates, drain_queue, edit_message_text, answer_callback_query };
}

export { create };
