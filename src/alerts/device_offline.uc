'use strict';

import { writefile } from 'fs';
import * as util from '../lib/util.uc';
import * as devices_lib from '../lib/devices.uc';
import * as mac_vendor from '../lib/mac_vendor.uc';

const PRUNE_AFTER = 604800; // 7 days — remove stale entries

return {
    name: "device_offline",
    mode: "cron",

    check: function(ctx) {
        let ic = util.icons;
        mac_vendor.init(ctx.state_dir, ctx.config);
        let threshold = ctx.config.alerts.offline_threshold || 120;
        let state_file = ctx.state_dir + "device_offline.json";
        let now = time();

        // Load previous state
        let state_raw = util.read_file(state_file);
        let state = (state_raw != null) ? json(state_raw) : null;
        if (state == null || type(state) != "object") state = {};

        // Get current devices (LAN only — skip WAN gateway etc.)
        let all_devices = devices_lib.get_all();
        let devices = [];
        for (let dev in all_devices) {
            if (dev.interface == "wan") continue;
            push(devices, dev);
        }

        // Build set of online MACs
        let online_set = {};
        for (let dev in devices) {
            if (dev.online) online_set[dev.mac] = dev;
        }

        let offline_msgs = [];
        let online_msgs = [];

        // Pass 1: handle online devices
        for (let mac in online_set) {
            let dev = online_set[mac];
            let entry = state[mac];

            if (entry != null && entry.alerted) {
                // Was offline+alerted, now back — collect recovery message
                let offline_dur = now - entry.seen;
                push(online_msgs, {
                    hostname: dev.hostname || entry.hostname,
                    ip: dev.ip || entry.ip,
                    mac: mac,
                    duration: offline_dur,
                });
            }

            // Update state: seen now, not alerted
            state[mac] = {
                seen: now,
                alerted: false,
                hostname: dev.hostname || (entry ? entry.hostname : null),
                ip: dev.ip || (entry ? entry.ip : null),
            };
        }

        // Pass 2: handle offline devices not yet in state (start tracking)
        for (let dev in devices) {
            if (!dev.online && state[dev.mac] == null) {
                state[dev.mac] = {
                    seen: now,
                    alerted: false,
                    hostname: dev.hostname,
                    ip: dev.ip,
                };
            }
        }

        // Pass 3: check state entries that are NOT online
        for (let mac in state) {
            if (online_set[mac]) continue; // already handled

            let entry = state[mac];
            if (entry.alerted) continue; // already notified

            let elapsed = now - entry.seen;
            if (elapsed > threshold) {
                entry.alerted = true;
                push(offline_msgs, {
                    hostname: entry.hostname,
                    ip: entry.ip,
                    mac: mac,
                    elapsed: elapsed,
                });
            }
        }

        // Prune: remove entries that are offline+alerted for > 7 days
        let pruned = {};
        for (let mac in state) {
            let entry = state[mac];
            if (entry.alerted && (now - entry.seen) > PRUNE_AFTER) continue;
            pruned[mac] = entry;
        }

        // Write state
        writefile(state_file, sprintf("%J", pruned));

        // Format messages
        let lines = [];

        if (length(offline_msgs) > 0) {
            if (length(offline_msgs) > 3) {
                push(lines, sprintf("%s *%d devices went offline*",
                    ic.red, length(offline_msgs)));
                for (let i = 0; i < length(offline_msgs); i++) {
                    let d = offline_msgs[i];
                    let name = mac_vendor.resolve_display_name(d);
                    if (name == "unknown" && d.ip) name = util.escape_markdown(d.ip);
                    let prefix = (i == length(offline_msgs) - 1) ? ic.corner : ic.tee;
                    push(lines, sprintf("%s %s (%s)",
                        prefix, name, util.escape_markdown(d.mac)));
                }
            } else {
                for (let d in offline_msgs) {
                    push(lines, sprintf(
                        "%s *Device offline*\n%s Name: %s\n%s IP: %s\n%s MAC: %s\n%s Last seen: %s ago",
                        ic.red, ic.tee,
                        mac_vendor.resolve_display_name(d),
                        ic.tee,
                        util.escape_markdown(d.ip || "?"),
                        ic.tee,
                        util.escape_markdown(d.mac),
                        ic.corner,
                        util.format_uptime(d.elapsed)));
                }
            }
        }

        if (length(online_msgs) > 0) {
            if (length(online_msgs) > 3) {
                push(lines, sprintf("%s *%d devices back online*",
                    ic.green, length(online_msgs)));
                for (let i = 0; i < length(online_msgs); i++) {
                    let d = online_msgs[i];
                    let name = mac_vendor.resolve_display_name(d);
                    if (name == "unknown" && d.ip) name = util.escape_markdown(d.ip);
                    let prefix = (i == length(online_msgs) - 1) ? ic.corner : ic.tee;
                    push(lines, sprintf("%s %s (%s) \u2014 %s",
                        prefix, name,
                        util.escape_markdown(d.mac),
                        util.format_uptime(d.duration)));
                }
            } else {
                for (let d in online_msgs) {
                    push(lines, sprintf(
                        "%s *Device back online*\n%s Name: %s\n%s IP: %s\n%s MAC: %s\n%s Offline for: %s",
                        ic.green, ic.tee,
                        mac_vendor.resolve_display_name(d),
                        ic.tee,
                        util.escape_markdown(d.ip || "?"),
                        ic.tee,
                        util.escape_markdown(d.mac),
                        ic.corner,
                        util.format_uptime(d.duration)));
                }
            }
        }

        if (length(lines) == 0) return null;
        return { text: join("\n", lines) };
    },
};
