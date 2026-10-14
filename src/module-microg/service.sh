MODDIR=${0%/*}
. "$MODDIR/common.sh"

# Grant microG permissions once after install, Action button repeats it when needed
[ -f "$MODDIR/permissions-granted" ] && exit 0
until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 5; done
# pm passes its output fd to system_server, which can't write to module files, so capture through a pipe
if log="$(grant_microg_permissions 2>&1)"; then
	touch "$MODDIR/permissions-granted"
fi
echo "$log" > "$MODDIR/service.log"
