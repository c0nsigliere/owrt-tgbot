#!/bin/sh
# Patch /etc/init.d/vnstat to save database from tmpfs on stop/restart.
# Run once after installing vnstat on the router.
#
# The hourly cron already backs up to flash, but without this patch
# a reboot or service restart loses up to 1 hour of stats.
# The init script's start_service already restores from backup_dir.

INIT="/etc/init.d/vnstat"

if grep -q 'stop_service' "$INIT"; then
    echo "stop_service already present in $INIT, skipping."
    exit 0
fi

cat >> "$INIT" <<'PATCH'

stop_service() {
	local lib="$(vnstat_option DatabaseDir)"
	local backup_dir
	config_load vnstat
	config_get backup_dir "@vnstat[0]" backup_dir

	if [ -n "$backup_dir" ] && [ -d "$lib" ]; then
		mkdir -p "$backup_dir"
		for f in "$lib"/*; do
			[ -f "$f" ] && cp -f "$f" "$backup_dir/"
		done
		logger -t "vnstat" "Database backed up to $backup_dir"
	fi
}
PATCH

echo "Patched $INIT with stop_service."
