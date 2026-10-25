# KernelSU and APatch fake MAGISK_VER_CODE, so detect them first
if [ "$KSU" = true ] || [ "$APATCH" = true ]; then
	# Since KernelSU v3.0.0 (32179) and APatch 11219 module files are mounted only by a metamodule
	if [ ! -e /data/adb/metamodule ]; then
		if [ "${KSU_VER_CODE:-0}" -ge 32179 ] || [ "${APATCH_VER_CODE:-0}" -ge 11219 ]; then
			abort "! Install a metamodule (e.g. meta-overlayfs) first, without it module files are not mounted"
		fi
		ui_print "[W] No metamodule found, if your root solution needs one, module files won't be mounted"
	fi
# Oldest Magisk version this module is tested with
elif [ "$MAGISK_VER_CODE" -lt 29000 ]; then
	abort "! Magisk v29.0+ is required, current: $MAGISK_VER"
fi

# Removes app dir and records it, so module update knows what it hid
# $1: package ("-" for unknown, from versions not recording it), $2: device path of app dir
add_target() {
	case $2 in
		/system/*) target=$2 ;;
		/product/* | /system_ext/* | /vendor/*) target=/system$2 ;;
		*)
			ui_print "[W] $2 is on a partition modules can't modify, skipped"
			return
			;;
	esac
	case " $REMOVE " in *" $target "*) return ;; esac
	REMOVE="$REMOVE $target"
	echo "$1 $target" >> "$MODPATH/removed"
}

# Lines are "package [role]", Hard variant has more of them
packages="$(grep -o '^[^#]*' "$MODPATH/packages.txt" | grep -v '^ *$')"
all_packages=" $(echo "$packages" | awk '{print $1}' | tr '\n' ' ') "
installed_removed="/data/adb/modules/$MODID/removed"

# Succeeds when an app this module doesn't remove can take the role
# $1: role
has_replacement() {
	case $1 in
		home) handlers="$(cmd package query-activities --components -a android.intent.action.MAIN -c android.intent.category.HOME)" ;;
		dialer) handlers="$(cmd package query-activities --components -a android.intent.action.DIAL -d tel:1)" ;;
		sms) handlers="$(cmd package query-receivers --components -a android.provider.Telephony.SMS_DELIVER)" ;;
		camera) handlers="$(cmd package query-activities --components -a android.media.action.IMAGE_CAPTURE)" ;;
		alarm) handlers="$(cmd package query-activities --components -a android.intent.action.SET_ALARM)" ;;
		# Only enabled keyboards, Android doesn't switch to a disabled one and leaves no keyboard (no typing password)
		ime) handlers="$(ime list -s)" ;;
	esac
	for handler in $handlers; do
		handler=${handler%%/*}
		# Settings provides fallback home screen shown only during boot
		[ "$handler" = com.android.settings ] && continue
		case $all_packages in *" $handler "*) continue ;; esac
		return 0
	done
	return 1
}

ui_print "[P] Finding Google apps to unbundle..."
ui_print "-------------------------------------------"
ui_print "[M] PACKAGE                           STATE"
ui_print "-------------------------------------------"
# List comes through fd 3, commands in loop could read it from stdin
while read -r package role <&3; do
	# Stock app dirs from package manager, incl. hidden system packages behind updates. Package manager doesn't see
	# apps the installed version removed, so take them from its record (only listed ones, switching variant brings
	# other ones back).
	dirs="$(dumpsys package "$package" | grep -oE 'codePath=/[^ ]+' | cut -d= -f2 | grep -v '^/data/')
$(grep "^$package " "$installed_removed" 2> /dev/null | cut -d' ' -f2)"
	[ -n "$(echo $dirs)" ] || continue
	found=true
	if [ -n "$role" ] && ! has_replacement "$role"; then
		ui_print "$(printf "%-25s %s" "[W] $package" "KEPT, NO $role REPLACEMENT")"
		kept=true
		continue
	fi
	# Package manager keeps updated app as user app when its system app is gone
	if pm path "$package" | grep -q '/data/app/'; then
		state="USER APP"
	else
		state="REMOVED"
	fi
	ui_print "$(printf "%-32s %s" "[I] $package" "$state")"
	for dir in $dirs; do
		add_target "$package" "$dir"
	done
done 3<< EOF
$packages
EOF
[ -n "$found" ] || ui_print "[I] No Google apps on system"
ui_print "-------------------------------------------"
# Older versions don't record removed dirs, so keep their whiteouts.
# KernelSU/APatch move partitions out of system/ and overlay metamodules move files to their own dir.
if [ -f "$installed_removed" ]; then
	while read -r package target; do
		[ "$package" = - ] && add_target - "$target"
	done < "$installed_removed"
else
	old_whiteouts="$(for dir in "/data/adb/modules/$MODID" "/data/adb/metamodule/mnt/$MODID"; do
		(cd "$dir" 2> /dev/null && find . -type c | sed -E 's#^\./##; s#^(product|system_ext|vendor)/#system/\1/#; s#^#/#')
	done)"
	for dir in $old_whiteouts; do
		add_target - "$dir"
	done
fi
ui_print "[I] Apps removed by installer below (Remove target), user apps keep their data"
[ -z "$kept" ] || ui_print "[W] Install replacements for kept apps and install the module again to remove them"

ui_print ""
ui_print "[I] Enjoying Noogle? Support development:"
ui_print "    ko-fi.com/selfref"
ui_print "    github.com/sponsors/SelfRef"
ui_print "    liberapay.com/SelfRef"
