'use strict';

import { popen } from 'fs';
import * as util from '../lib/util.uc';

let base_url = null;
let _proxy_enabled = false;
let _proxy_url = "";
let _poll_timeout = 30;

function init(token, config) {
    base_url = "https://api.telegram.org/bot" + token + "/";
    if (config) {
        _proxy_enabled = config.proxy_enabled || false;
        _proxy_url = config.proxy_url || "";
        _poll_timeout = config.poll_timeout || 30;
    }
}

function build_curl_cmd(url, max_time) {
    let parts = [
        "curl -s",
        "--connect-timeout 5",
        "--max-time " + (max_time || 30),
    ];
    if (_proxy_enabled && _proxy_url != "") {
        push(parts, "--proxy " + _proxy_url);
    }
    push(parts, '-H "Content-Type: application/json"');
    push(parts, '"' + url + '"');
    push(parts, "2>/dev/null");
    return join(" ", parts);
}

function api_request(method, params, max_time) {
    let url = base_url + method;

    let cmd;
    if (params != null) {
        let body = sprintf("%J", params);
        // Write body via printf to avoid shell quoting issues
        let escaped = replace(body, /\\/g, "\\\\");
        escaped = replace(escaped, /"/g, "\\\"");
        escaped = replace(escaped, /`/g, "\\`");
        escaped = replace(escaped, /\$/g, "\\$");
        cmd = sprintf('printf "%%s" "%s" | %s -d @-', escaped, build_curl_cmd(url, max_time));
    } else {
        cmd = build_curl_cmd(url, max_time);
    }

    let h = popen(cmd, 'r');
    if (h == null) {
        util.log("error", "telegram: failed to execute curl");
        return null;
    }
    let result = h.read('all');
    h.close();

    if (result == null || result == "") {
        util.log("error", "telegram: empty response for " + method);
        return null;
    }

    let data = json(result);
    if (data == null) {
        util.log("error", "telegram: invalid JSON for " + method + ": " + substr(result, 0, 100));
        return null;
    }

    if (!data.ok) {
        let desc = data.description || "unknown error";
        util.log("error", "telegram: API error (" + method + "): " + desc);
        return null;
    }

    return data.result;
}

function get_me() {
    return api_request("getMe", null, 10);
}

function get_updates(offset, timeout) {
    let params = { timeout: timeout || _poll_timeout };
    if (offset != null) params.offset = offset;
    let max_time = (timeout || _poll_timeout) + 10;
    return api_request("getUpdates", params, max_time);
}

function send_message(chat_id, text, parse_mode, reply_markup) {
    let params = { chat_id, text };
    if (parse_mode != null) params.parse_mode = parse_mode;
    if (reply_markup != null) params.reply_markup = reply_markup;
    return api_request("sendMessage", params, 30);
}

function edit_message_text(chat_id, message_id, text, parse_mode, reply_markup) {
    let params = { chat_id, message_id, text };
    if (parse_mode != null) params.parse_mode = parse_mode;
    if (reply_markup != null) params.reply_markup = reply_markup;
    return api_request("editMessageText", params, 30);
}

function answer_callback_query(callback_query_id, text) {
    let params = { callback_query_id };
    if (text != null) params.text = text;
    return api_request("answerCallbackQuery", params, 10);
}

function send_photo(chat_id, file_path, caption) {
    let url = base_url + "sendPhoto";
    let parts = [
        "curl -s",
        "--connect-timeout 5",
        "--max-time 60",
    ];
    if (_proxy_enabled && _proxy_url != "") {
        push(parts, "--proxy " + _proxy_url);
    }
    push(parts, '-F "chat_id=' + chat_id + '"');
    push(parts, '-F "photo=@' + file_path + '"');
    if (caption != null) {
        let safe_cap = replace(caption, /"/g, '\\"');
        push(parts, '-F "caption=' + safe_cap + '"');
    }
    push(parts, '"' + url + '"');
    push(parts, "2>/dev/null");

    let cmd = join(" ", parts);
    let h = popen(cmd, 'r');
    if (h == null) return false;
    let result = h.read('all');
    h.close();

    if (result == null || result == "") return false;
    let data = json(result);
    return (data != null && data.ok == true);
}

export { init, get_me, get_updates, send_message, send_photo, edit_message_text, answer_callback_query };
