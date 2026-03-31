#!/usr/bin/ucode -S
'use strict';

import { popen } from 'fs';

const RESET = "\x1b[0m";
const GREEN = "\x1b[32m";
const RED   = "\x1b[31m";
const GRAY  = "\x1b[90m";

let total_pass = 0;
let total_fail = 0;

// Determine test directory
let _sp = sourcepath();
let tests_dir = _sp ? replace(_sp, /\/[^\/]+$/, "") : "tests";

// Discover test files
let h = popen("ls '" + tests_dir + "'/test_*.uc 2>/dev/null", 'r');
if (h == null) {
    warn("Cannot list tests directory\n");
    exit(1);
}
let listing = h.read('all');
h.close();

let test_files = [];
for (let line in split(listing, "\n")) {
    line = trim(line);
    if (line != "") push(test_files, line);
}

if (length(test_files) == 0) {
    warn("No test files found in " + tests_dir + "\n");
    exit(1);
}

for (let filepath in test_files) {
    let m = match(filepath, /([^\/]+)\.uc$/);
    let suite_name = m ? m[1] : filepath;

    printf("\n%s%s%s\n", GRAY, suite_name, RESET);

    let suite_fn = loadfile(filepath);
    if (suite_fn == null) {
        printf("  %sFAIL%s  (could not load file)\n", RED, RESET);
        total_fail++;
        continue;
    }

    let tests = suite_fn();

    if (tests == null || type(tests) != "object") {
        printf("  %sFAIL%s  (test file did not return an object)\n", RED, RESET);
        total_fail++;
        continue;
    }

    let test_names = keys(tests);
    sort(test_names);

    for (let name in test_names) {
        let fn = tests[name];
        if (type(fn) != "function") continue;

        let result = fn();
        if (result == true) {
            printf("  %sPASS%s  %s\n", GREEN, RESET, name);
            total_pass++;
        } else {
            printf("  %sFAIL%s  %s\n", RED, RESET, name);
            printf("         %s%s%s\n", RED, result, RESET);
            total_fail++;
        }
    }
}

printf("\n%s%d passed%s, %s%d failed%s\n",
    GREEN, total_pass, RESET,
    total_fail > 0 ? RED : GRAY, total_fail, RESET);

exit(total_fail > 0 ? 1 : 0);
