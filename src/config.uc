'use strict';

import { stat, popen } from 'fs';
import * as util from './lib/util.uc';

const is_openwrt = (stat('/sbin/uci') != null || stat('/usr/bin/uci') != null);

function uci_get(key) {
    let h = popen("uci -q get owrt-tgbot." + key + " 2>/dev/null", 'r');
    if (h == null) return null;
    let val = h.read('all');
    h.close();
    if (val == null) return null;
    val = util.trim(val);
    return (val == "") ? null : val;
}

// Get a UCI list option (e.g. list allowed_chat_id)
function uci_get_list(section, option) {
    // Use 'uci show' output to get list values
    let h = popen(sprintf("uci -q show owrt-tgbot.%s.%s 2>/dev/null", section, option), 'r');
    if (h == null) return [];
    let raw = h.read('all');
    h.close();
    if (raw == null || raw == "") return [];

    // Output format: owrt-tgbot.section.option='val1' owrt-tgbot.section.option='val2'
    // or for a list: each line is: owrt-tgbot.section.option='val'
    let result = [];
    for (let line in split(raw, "\n")) {
        line = util.trim(line);
        if (line == "") continue;
        let m = match(line, /='(.+)'$/);
        if (m) push(result, m[1]);
    }
    return result;
}

function load_uci_config() {
    let bot_token = uci_get("main.bot_token") || "";
    let allowed_chat_ids = uci_get_list("main", "allowed_chat_id");
    let poll_timeout = +(uci_get("main.poll_timeout") || "30");
    let log_level = uci_get("main.log_level") || "info";
    let notify_backend = uci_get("main.notify_backend") || "telegram";
    let proxy_enabled = (uci_get("main.proxy_enabled") == "1");
    let proxy_url = uci_get("main.proxy_url") || "";

    let alerts_enabled   = uci_get("alerts.enabled");
    let alerts_new       = uci_get("alerts.new_device");
    let alerts_wan       = uci_get("alerts.wan_status");
    let alerts_temp      = uci_get("alerts.temp_threshold");
    let alerts_temp_lim  = uci_get("alerts.temp_limit");
    let traffic_iface    = uci_get("traffic.interface");
    let traffic_warn     = uci_get("traffic.warn_daily_gb");

    return {
        bot_token,
        allowed_chat_ids,
        poll_timeout: (!(poll_timeout > 0) && !(poll_timeout < 0) && !(poll_timeout == 0)) ? 30 : poll_timeout,
        log_level,
        notify_backend,
        proxy_enabled,
        proxy_url,
        alerts: {
            enabled:        alerts_enabled   != "0",
            new_device:     alerts_new       != "0",
            wan_status:     alerts_wan       != "0",
            temp_threshold: alerts_temp      != "0",
            temp_limit:     +(alerts_temp_lim || "85"),
        },
        traffic: {
            interface:    traffic_iface  || "eth0",
            warn_daily_gb: +(traffic_warn || "0"),
        },
    };
}

function load_env_config(env_path) {
    let content = util.read_file(env_path);
    if (content == null) {
        die("Config not found: no UCI and no " + env_path + "\n");
    }

    let env = {};
    for (let line in split(content, "\n")) {
        line = util.trim(line);
        if (line == "" || substr(line, 0, 1) == "#") continue;
        let m = match(line, /^([\w]+)\s*=\s*(.+)$/);
        if (m) {
            // Strip optional surrounding quotes
            let val = m[2];
            let qm = match(val, /^['"](.*)['"]$/);
            env[m[1]] = qm ? qm[1] : val;
        }
    }

    let bot_token = env.BOT_TOKEN || "";
    let allowed_chat_ids = [];
    if (env.ALLOWED_CHAT_IDS) {
        for (let id in split(env.ALLOWED_CHAT_IDS, ",")) {
            id = util.trim(id);
            if (id != "") push(allowed_chat_ids, id);
        }
    } else if (env.ALLOWED_CHAT_ID) {
        push(allowed_chat_ids, util.trim(env.ALLOWED_CHAT_ID));
    }

    let poll_timeout = +(env.POLL_TIMEOUT || "30");
    let log_level = env.LOG_LEVEL || "info";
    let notify_backend = env.NOTIFY_BACKEND || "telegram";
    let proxy_enabled = (env.PROXY_ENABLED == "1");
    let proxy_url = env.PROXY_URL || "";

    return {
        bot_token,
        allowed_chat_ids,
        poll_timeout: (!(poll_timeout > 0) && !(poll_timeout < 0) && !(poll_timeout == 0)) ? 30 : poll_timeout,
        log_level,
        notify_backend,
        proxy_enabled,
        proxy_url,
        alerts: {
            enabled:        env.ALERTS_ENABLED        != "0",
            new_device:     env.ALERTS_NEW_DEVICE      != "0",
            wan_status:     env.ALERTS_WAN_STATUS      != "0",
            temp_threshold: env.ALERTS_TEMP_THRESHOLD  != "0",
            temp_limit:     +(env.ALERTS_TEMP_LIMIT    || "85"),
        },
        traffic: {
            interface:     env.TRAFFIC_INTERFACE     || "eth0",
            warn_daily_gb: +(env.TRAFFIC_WARN_DAILY_GB || "0"),
        },
    };
}

function load(base_dir) {
    if (is_openwrt) {
        return load_uci_config();
    }

    base_dir = base_dir || ".";
    // Try .env in base_dir, then parent
    let env_path = base_dir + "/.env";
    if (!util.file_exists(env_path)) {
        env_path = base_dir + "/../.env";
    }
    if (!util.file_exists(env_path)) {
        env_path = ".env";
    }
    return load_env_config(env_path);
}

export { load };
