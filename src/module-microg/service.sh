MODDIR=${0%/*}
. "$MODDIR/common.sh"

# Wait for package manager, pm clear also clears notifications, it fails while notification service isn't up yet
until pm path android > /dev/null 2>&1 && service check notification | grep -q ': found'; do sleep 1; done

# Apps switched between Google's and microG's version break on each other's data (e.g. newer database versions),
# so clear it before boot completes and apps start using it
if [ -f "$MODDIR/clear-data" ]; then
	for package in $(cat "$MODDIR/clear-data"); do
		clear_log="$clear_log
[I] Clearing $package data: $(pm clear "$package" 2>&1)"
	done
	rm "$MODDIR/clear-data"
fi

# Before boot completes too, GMS and Play Store crash until it's done
pif_log="$(install_updates_for_pif 2>&1)"

until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 5; done

# pm passes its output fd to system_server, which can't write to module files, so capture through a pipe
# Google updates can land between module install and reboot (e.g. Play Store self-update), remove them on every boot
log="$(remove_package_updates google 2>&1)$clear_log
$pif_log"

# Grant microG permissions once after install, Action button repeats it when needed
if [ ! -f "$MODDIR/permissions-granted" ]; then
	# Right after first boot some runtime permissions are missing in dump for a few seconds and would show as N/A
	for i in $(seq 30); do
		dumpsys package com.google.android.gms | grep 'ACCESS_FINE_LOCATION: granted=' > /dev/null && break
		sleep 2
	done
	if grant_log="$(grant_microg_permissions 2>&1)"; then
		touch "$MODDIR/permissions-granted"
	fi
	log="$log

$grant_log"
fi
echo "$log" > "$MODDIR/service.log"
