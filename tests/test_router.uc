'use strict';

import * as h from './helpers.uc';
import * as ubus from '../src/lib/ubus_wrapper.uc';
import { create as create_bot } from '../src/core/bot.uc';

ubus.set_fixtures_dir("fixtures");

function make_mock_notify() {
    let sent = [];
    return {
        sent,
        send_message: (chat_id, text, opts) => {
            push(sent, { chat_id, text, opts });
            return true;
        },
        send_photo: (chat_id, path, caption) => {
            push(sent, { chat_id, photo: path, caption });
            return true;
        },
        supports_commands: () => true,
        get_updates: () => [],
    };
}

let base_config = {
    bot_token: "test_token",
    allowed_chat_ids: ["12345", "67890"],
    poll_timeout: 1,
    log_level: "error",
    notify_backend: "telegram",
    proxy_enabled: false,
    proxy_url: "",
    alerts: { enabled: false },
    traffic: { interface: "eth0" },
};

return {

"auth: allows allowed chat_id": () => {
    let notify = make_mock_notify();
    let bot = create_bot(base_config, notify);
    bot.registry["/test"] = {
        name: "/test", description: "Test",
        handler: () => ({ text: "OK", opts: null }),
    };
    bot.handle_update({ update_id: 1, message: { chat: { id: 12345 }, text: "/test" } });
    return (h.assert_eq(length(notify.sent), 1) == true &&
            h.assert_eq(notify.sent[0].text, "OK") == true)
        ? true : "sent count or text mismatch";
},

"auth: ignores disallowed chat_id": () => {
    let notify = make_mock_notify();
    let bot = create_bot(base_config, notify);
    bot.registry["/test"] = {
        name: "/test", description: "Test",
        handler: () => ({ text: "OK", opts: null }),
    };
    bot.handle_update({ update_id: 1, message: { chat: { id: 99999 }, text: "/test" } });
    return h.assert_eq(length(notify.sent), 0);
},

"routing: routes to handler with correct args": () => {
    let notify = make_mock_notify();
    let bot = create_bot(base_config, notify);
    let got_args = null;
    bot.registry["/echo"] = {
        name: "/echo", description: "Echo",
        handler: (cid, args) => { got_args = args; return { text: "echoed", opts: null }; },
    };
    bot.handle_update({ update_id: 1, message: { chat: { id: 12345 }, text: "/echo hello world" } });
    return (h.assert_eq(got_args, "hello world") == true &&
            h.assert_eq(notify.sent[0].text, "echoed") == true)
        ? true : "args or text mismatch";
},

"routing: unknown command sends error": () => {
    let notify = make_mock_notify();
    let bot = create_bot(base_config, notify);
    bot.handle_update({ update_id: 1, message: { chat: { id: 12345 }, text: "/nonexistent" } });
    return (h.assert_eq(length(notify.sent), 1) == true &&
            h.assert_contains(notify.sent[0].text, "Unknown command") == true)
        ? true : "wrong response for unknown cmd";
},

"routing: ignores non-command messages": () => {
    let notify = make_mock_notify();
    let bot = create_bot(base_config, notify);
    bot.handle_update({ update_id: 1, message: { chat: { id: 12345 }, text: "plain text" } });
    return h.assert_eq(length(notify.sent), 0);
},

"routing: strips @botname suffix": () => {
    let notify = make_mock_notify();
    let bot = create_bot(base_config, notify);
    let called = false;
    bot.registry["/test"] = {
        name: "/test", description: "Test",
        handler: () => { called = true; return { text: "OK", opts: null }; },
    };
    bot.handle_update({ update_id: 1, message: { chat: { id: 12345 }, text: "/test@mybot" } });
    return h.assert_truthy(called, "/test@mybot not routed to /test");
},

"error handling: null handler result sends error": () => {
    let notify = make_mock_notify();
    let bot = create_bot(base_config, notify);
    bot.registry["/null_cmd"] = {
        name: "/null_cmd", description: "Returns null",
        handler: () => null,
    };
    bot.handle_update({ update_id: 1, message: { chat: { id: 12345 }, text: "/null_cmd" } });
    return (h.assert_eq(length(notify.sent), 1) == true &&
            h.assert_contains(notify.sent[0].text, "Error") == true)
        ? true : "error message not sent";
},

"context: config, commands, notify in ctx": () => {
    let notify = make_mock_notify();
    let bot = create_bot(base_config, notify);
    let received_ctx = null;
    bot.registry["/ctx"] = {
        name: "/ctx", description: "Ctx",
        handler: (cid, args, ctx) => { received_ctx = ctx; return { text: "OK", opts: null }; },
    };
    bot.handle_update({ update_id: 1, message: { chat: { id: 12345 }, text: "/ctx" } });
    return (received_ctx != null &&
            received_ctx.config != null &&
            received_ctx.commands != null &&
            received_ctx.notify != null)
        ? true : "ctx not fully populated";
}

};
