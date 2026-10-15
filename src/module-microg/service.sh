MODDIR=${0%/*}
. "$MODDIR/common.sh"

# Google apps break on data microG inherited from them (e.g. newer database versions), so clear it as soon as
# package manager is up, before boot completes and apps start using microG
if [ -f "$MODDIR/clear-data" ]; then
	# pm clear also clears notifications, it fails while notification service isn't up yet
	until pm path android > /dev/null 2>&1 && service check notification | grep -q ': found'; do sleep 1; done
	for package in $packages; do
		clear_log="$clear_log
[I] Clearing $package data: $(pm clear "$package" 2>&1)"
	done
	rm "$MODDIR/clear-data"
fi

until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 5; done

# pm passes its output fd to system_server, which can't write to module files, so capture through a pipe
# Google updates can land between module install and reboot (e.g. Play Store self-update), remove them on every boot
log="$(remove_package_updates google 2>&1)$clear_log"

# Grant microG permissions once after install, Action button repeats it when needed
if [ ! -f "$MODDIR/permissions-granted" ]; then
	if grant_log="$(grant_microg_permissions 2>&1)"; then
		touch "$MODDIR/permissions-granted"
	fi
	log="$log

$grant_log"
fi
echo "$log" > "$MODDIR/service.log"
