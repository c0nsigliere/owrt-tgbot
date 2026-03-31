'use strict';

import { readfile, stat } from 'fs';

const UNITS = ["B", "KB", "MB", "GB", "TB"];

function format_bytes(bytes) {
    if (bytes == null || bytes < 0) return "0 B";
    if (bytes < 1) return "0 B";
    let unit_index = 0;
    let value = bytes;
    while (value >= 1024 && unit_index < length(UNITS) - 1) {
        value = value / 1024.0;
        unit_index++;
    }
    if (unit_index == 0) {
        return sprintf("%d %s", value, UNITS[unit_index]);
    }
    return sprintf("%.2f %s", value, UNITS[unit_index]);
}

function format_uptime(seconds) {
    if (seconds == null || seconds < 0) return "0m";
    seconds = int(seconds);
    let days    = int(seconds / 86400);
    let hours   = int((seconds % 86400) / 3600);
    let minutes = int((seconds % 3600) / 60);
    let parts = [];
    if (days > 0) push(parts, days + "d");
    if (hours > 0) push(parts, hours + "h");
    push(parts, minutes + "m");
    return join(" ", parts);
}

function format_percent(used, total) {
    if (total == null || total == 0) return "0%";
    return sprintf("%d%%", int(used * 100.0 / total));
}

function escape_markdown(text) {
    if (text == null) return "";
    text = "" + text;
    // Telegram Markdown V1 special chars: _ * ` [ ]
    text = replace(text, /_/g, "\\_");
    text = replace(text, /\*/g, "\\*");
    text = replace(text, /`/g, "\\`");
    text = replace(text, /\[/g, "\\[");
    text = replace(text, /\]/g, "\\]");
    return text;
}

function read_file(path) {
    return readfile(path);
}

function file_exists(path) {
    return stat(path) != null;
}

let _has_logger = null;
function has_logger() {
    if (_has_logger == null) {
        _has_logger = (stat('/usr/bin/logger') != null);
    }
    return _has_logger;
}

function log(level, message) {
    message = "" + message;
    if (has_logger()) {
        let safe_msg = replace(message, /'/g, "'\\''");
        system(sprintf("logger -t owrt-tgbot -p daemon.%s '%s'", level, safe_msg));
    } else {
        warn(sprintf("[%s] %s\n", level, message));
    }
}

// Bar chart using UTF-8 block characters
const BLOCK_FULL  = "\u2593";
const BLOCK_EMPTY = "\u2591";

function bar_chart(value, max, width) {
    if (max == null || max == 0) {
        width = width || 10;
        let s = "";
        for (let i = 0; i < width; i++) s += " ";
        return s;
    }
    width = width || 10;
    let filled = int(value / max * 1.0 * width + 0.5);
    if (filled > width) filled = width;
    if (filled < 0) filled = 0;
    let bar = "";
    for (let i = 0; i < filled; i++) bar += BLOCK_FULL;
    for (let i = filled; i < width; i++) bar += BLOCK_EMPTY;
    return bar;
}

function trim(s) {
    if (s == null) return "";
    s = "" + s;
    let m = match(s, /^\s*(.*\S)\s*$/);
    if (m) return m[1];
    // all whitespace or empty
    m = match(s, /^\s*$/);
    if (m) return "";
    return s;
}

// Icons — using surrogate pairs for characters outside BMP (U+10000+)
// and direct \uXXXX for BMP characters
const icons = {
    robot:     "\uD83E\uDD16",   // U+1F916 🤖
    computer:  "\uD83D\uDDA5",   // U+1F5A5 🖥
    globe:     "\uD83C\uDF10",   // U+1F310 🌐
    chart:     "\uD83D\uDCCA",   // U+1F4CA 📊
    calendar:  "\uD83D\uDCC5",   // U+1F4C5 📅
    trophy:    "\uD83C\uDFC6",   // U+1F3C6 🏆
    phone:     "\uD83D\uDCF1",   // U+1F4F1 📱
    package:   "\uD83D\uDCE6",   // U+1F4E6 📦
    floppy:    "\uD83D\uDCBE",   // U+1F4BE 💾
    bell:      "\uD83D\uDD14",   // U+1F514 🔔
    "new":     "\uD83C\uDD95",   // U+1F195 🆕
    fire:      "\uD83D\uDD25",   // U+1F525 🔥
    hourglass: "\u23F3",          // U+23F3  ⏳
    warning:   "\u26A0\uFE0F",   // U+26A0  ⚠️
    info:      "\u2139\uFE0F",   // U+2139  ℹ️
    check:     "\u2705",          // U+2705  ✅
    green:     "\uD83D\uDFE2",   // U+1F7E2 🟢
    red:       "\uD83D\uDD34",   // U+1F534 🔴
    yellow:    "\uD83D\uDFE1",   // U+1F7E1 🟡
    white:     "\u26AA",          // U+26AA  ⚪
    arrow:     "\u2192",          // U+2192  →
    degree:    "\u00B0",          // U+00B0  °
    dash:      "\u2014",          // U+2014  —
    pipe:      "\u2502",          // U+2502  │
    tee:       "\u251C",          // U+251C  ├
    corner:    "\u2514",          // U+2514  └
};

export {
    format_bytes,
    format_uptime,
    format_percent,
    escape_markdown,
    read_file,
    file_exists,
    log,
    bar_chart,
    trim,
    icons
};
