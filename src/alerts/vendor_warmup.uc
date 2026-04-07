'use strict';

import * as mac_vendor from '../lib/mac_vendor.uc';
import * as devices_lib from '../lib/devices.uc';

return {
    name: "vendor_warmup",
    mode: "cron",

    check: function(ctx) {
        mac_vendor.init(ctx.state_dir, ctx.config);

        let devices = devices_lib.get_all();
        let new_lookups = 0;

        // Collect unique OUIs that need lookup
        let seen_oui = {};
        for (let dev in devices) {
            if (dev.hostname != null) continue;
            if (mac_vendor.is_local_mac(dev.mac)) continue;

            let oui = mac_vendor.oui_prefix(dev.mac);
            if (seen_oui[oui]) continue;
            seen_oui[oui] = true;

            // lookup() returns: string (cached or fresh), null (throttled/error)
            // First uncached OUI in a fresh process will make an API call and return string.
            // Second uncached OUI will be throttled (1 req/sec) and return null.
            let result = mac_vendor.lookup(dev.mac);
            if (result == null) break;  // throttled — done for this cycle
        }

        mac_vendor.save_vendor_cache();
        return null;
    },
};
