'use strict';

import * as tg_backend from './telegram.uc';

function create(backend_name, config) {
    if (backend_name == "telegram") {
        return tg_backend.create(config);
    }
    die("Unknown notification backend: " + backend_name + "\n");
}

export { create };
