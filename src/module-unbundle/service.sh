MODDIR=${0%/*}
# Fossify variant only: Android doesn't switch to bundled Fossify apps everywhere on its own. Without enabled keyboard
# password can't be typed on lock screen, so it runs on every boot, but only fills what's missing.

# Keyboard service and role manager are up before lock screen asks for password
until service check input_method | grep -q ': found' && service check role | grep -q ': found'; do sleep 1; done

# Switches to Fossify Keyboard when no keyboard is in use or it was removed
# $1: when (log)
fix_keyboard() {
	keyboard=org.fossify.keyboard/.services.SimpleKeyboardIME
	current="$(settings get secure default_input_method)"
	pm path "${current%%/*}" > /dev/null 2>&1 && [ -n "$(ime list -s)" ] && return
	ime enable "$keyboard" > /dev/null
	ime set "$keyboard" > /dev/null
	log="$log
[I] $1: keyboard ${current:-none} is gone, switched to Fossify Keyboard"
}
fix_keyboard "Before unlock"

# Unlocking loads keyboard settings from user storage, which still have the removed one, so fix again after it.
# Roles are taken by Fossify apps only if nobody holds them, before unlock only direct boot aware apps are visible.
until [ "$(getprop sys.boot_completed)" = 1 ] && [ "$(dumpsys user | grep -m 1 -o RUNNING_UNLOCKED)" ]; do sleep 5; done
sleep 5
fix_keyboard "After unlock"
# cmd role get-role-holders exists only since Android 14, dumpsys has holders in role's block on all versions
# $1: role name
role_holders() {
	dumpsys role | awk -v role="name=$1" '$1 == role {found = 1; next} found && /name=/ {exit}
		found && /holders=/ {sub(/.*holders=/, ""); print; exit}'
}
for role in HOME:org.fossify.home DIALER:org.fossify.phone SMS:org.fossify.messages; do
	if [ -z "$(role_holders "android.app.role.${role%%:*}")" ]; then
		cmd role add-role-holder "android.app.role.${role%%:*}" "${role#*:}" && log="$log
[I] ${role%%:*} role was empty, given to ${role#*:}"
	fi
done
# Clock shows ringing alarm and Calendar reminders as notifications, without the permission alarm only rings with
# nothing on screen. Phone and Messages get it with their roles. Choice made by user is kept.
for package in org.fossify.clock org.fossify.calendar; do
	state="$(dumpsys package "$package" | grep -m 1 'POST_NOTIFICATIONS: granted=')"
	case $state in *granted=false*) ;; *) continue ;; esac
	case $state in *USER_SET* | *USER_FIXED*) continue ;; esac
	pm grant "$package" android.permission.POST_NOTIFICATIONS && log="$log
[I] Allowed notifications for $package"
done
echo "${log:-[I] Nothing to fix}" | sed '/^$/d' > "$MODDIR/service.log"
