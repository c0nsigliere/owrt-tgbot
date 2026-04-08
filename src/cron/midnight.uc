#!/usr/bin/ucode -S
'use strict';

// Midnight cron job:
// 1. Snapshot nlbw counters as daily baseline
// 2. Auto-save state (tmpfs → flash)

import { popen, writefile } from 'fs';

let _sp = sourcepath();
let base_dir = _sp ? replace(_sp, /\/[^\/]+\/[^\/]+$/, "") : "src";

import * as util from '../lib/util.uc';
import * as nlbwmon from '../lib/nlbwmon.uc';

const TMP_STATE     = "/tmp/owrt-tgbot/state/";
const PERSIST_STATE = "/etc/owrt-tgbot/state/";

// 1. Snapshot nlbw counters
let traffic = nlbwmon.get_traffic();
writefile(TMP_STATE + "nlbw_midnight.json", sprintf("%J", traffic));
util.log("info", sprintf("midnight: nlbw baseline saved (%d devices)", length(keys(traffic))));

// 2. Auto-save state to flash
system("mkdir -p " + PERSIST_STATE);
system("cp " + TMP_STATE + "* " + PERSIST_STATE + " 2>/dev/null");
util.log("info", "midnight: state saved to flash");
