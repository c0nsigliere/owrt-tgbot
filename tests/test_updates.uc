'use strict';

import * as h from './helpers.uc';
import * as ubus from '../src/lib/ubus_wrapper.uc';
import * as util from '../src/lib/util.uc';
import * as opkg from '../src/lib/opkg.uc';

ubus.set_fixtures_dir("fixtures");

return {

"parse_upgradable: parses fixture (5 packages)": () => {
    let content = util.read_file("fixtures/opkg_upgradable.txt");
    return h.assert_eq(length(opkg.parse_upgradable(content)), 5);
},

"parse_upgradable: extracts package name": () =>
    h.assert_eq(opkg.parse_upgradable("curl - 8.5.0-1 - 8.6.0-1\n")[0].name, "curl"),

"parse_upgradable: extracts current version": () =>
    h.assert_eq(opkg.parse_upgradable("curl - 8.5.0-1 - 8.6.0-1\n")[0].current, "8.5.0-1"),

"parse_upgradable: extracts available version": () =>
    h.assert_eq(opkg.parse_upgradable("curl - 8.5.0-1 - 8.6.0-1\n")[0].available, "8.6.0-1"),

"parse_upgradable: handles empty input": () =>
    h.assert_eq(length(opkg.parse_upgradable("")), 0),

"parse_upgradable: handles null input": () =>
    h.assert_eq(length(opkg.parse_upgradable(null)), 0),

"parse_upgradable: skips malformed lines": () =>
    h.assert_eq(length(opkg.parse_upgradable("bad line\ncurl - 8.5.0-1 - 8.6.0-1\n")), 1),

"list_upgradable: returns packages from fixture": () =>
    h.assert_gt(length(opkg.list_upgradable()), 0),

};
