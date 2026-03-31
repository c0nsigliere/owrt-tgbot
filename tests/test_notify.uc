'use strict';

import * as h from './helpers.uc';
import * as tg_notify from '../src/notify/telegram.uc';

let cfg = { bot_token: "test_token", poll_timeout: 1, proxy_enabled: false, proxy_url: "" };

return {

"telegram backend: create returns object": () =>
    h.assert_not_null(tg_notify.create(cfg)),

"telegram backend: implements send_message": () =>
    h.assert_is_function(tg_notify.create(cfg).send_message),

"telegram backend: implements send_photo": () =>
    h.assert_is_function(tg_notify.create(cfg).send_photo),

"telegram backend: supports_commands returns true": () => {
    let backend = tg_notify.create(cfg);
    return (h.assert_is_function(backend.supports_commands) == true &&
            h.assert_eq(backend.supports_commands(), true) == true)
        ? true : "supports_commands check failed";
},

"telegram backend: implements get_updates": () =>
    h.assert_is_function(tg_notify.create(cfg).get_updates),

"telegram backend: implements drain_queue": () =>
    h.assert_is_function(tg_notify.create(cfg).drain_queue),

};
