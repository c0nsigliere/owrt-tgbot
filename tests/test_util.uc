'use strict';

import * as h from './helpers.uc';
import * as util from '../src/lib/util.uc';

return {

"format_bytes: formats zero":       () => h.assert_eq(util.format_bytes(0), "0 B"),
"format_bytes: formats bytes":      () => h.assert_eq(util.format_bytes(500), "500 B"),
"format_bytes: formats kilobytes":  () => h.assert_eq(util.format_bytes(1024), "1.00 KB"),
"format_bytes: formats megabytes":  () => h.assert_eq(util.format_bytes(1572864), "1.50 MB"),
"format_bytes: formats gigabytes":  () => h.assert_eq(util.format_bytes(2512535142), "2.34 GB"),
"format_bytes: handles null":       () => h.assert_eq(util.format_bytes(null), "0 B"),
"format_bytes: handles negative":   () => h.assert_eq(util.format_bytes(-100), "0 B"),

"format_uptime: minutes only":      () => h.assert_eq(util.format_uptime(300), "5m"),
"format_uptime: hours and minutes": () => h.assert_eq(util.format_uptime(9000), "2h 30m"),
"format_uptime: days hours minutes":() => h.assert_eq(util.format_uptime(305520), "3d 12h 52m"),
"format_uptime: handles zero":      () => h.assert_eq(util.format_uptime(0), "0m"),
"format_uptime: handles null":      () => h.assert_eq(util.format_uptime(null), "0m"),

"format_percent: formats percentage":() => h.assert_eq(util.format_percent(45, 100), "45%"),
"format_percent: zero total":        () => h.assert_eq(util.format_percent(10, 0), "0%"),
"format_percent: null total":        () => h.assert_eq(util.format_percent(10, null), "0%"),

"escape_markdown: underscores": () => h.assert_eq(util.escape_markdown("hello_world"), "hello\\_world"),
"escape_markdown: asterisks":   () => h.assert_eq(util.escape_markdown("*bold*"), "\\*bold\\*"),
"escape_markdown: backticks":   () => h.assert_eq(util.escape_markdown("`code`"), "\\`code\\`"),
"escape_markdown: brackets":    () => h.assert_eq(util.escape_markdown("[link]"), "\\[link\\]"),
"escape_markdown: null":        () => h.assert_eq(util.escape_markdown(null), ""),
"escape_markdown: plain text":  () => h.assert_eq(util.escape_markdown("hello world"), "hello world"),

// Block chars (▓/░) are 3 bytes each in UTF-8; length() returns bytes
"bar_chart: full width":  () => h.assert_eq(length(util.bar_chart(100, 100, 5)), 15),
"bar_chart: empty width": () => h.assert_eq(length(util.bar_chart(0, 100, 5)), 15),
"bar_chart: half width":  () => h.assert_eq(length(util.bar_chart(50, 100, 10)), 30),
"bar_chart: zero max returns spaces": () => h.assert_eq(length(util.bar_chart(50, 0, 5)), 5),

"trim: trims whitespace": () => h.assert_eq(util.trim("  hello  "), "hello"),
"trim: handles null":     () => h.assert_eq(util.trim(null), ""),
"trim: empty string":     () => h.assert_eq(util.trim(""), ""),

"read_file: null for missing":   () => h.assert_null(util.read_file("/nonexistent/file")),
"file_exists: false for missing":() => h.assert_false(util.file_exists("/nonexistent/file")),
"file_exists: true for existing":() => h.assert_truthy(util.file_exists("fixtures/dhcp.leases")),

};
