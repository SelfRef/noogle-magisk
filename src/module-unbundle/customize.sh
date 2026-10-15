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

# $1: device path of app dir
add_target() {
	case $1 in
		/system/*) target=$1 ;;
		/product/* | /system_ext/* | /vendor/*) target=/system$1 ;;
		*)
			ui_print "[W] $1 is on a partition modules can't modify, skipped"
			return
			;;
	esac
	case " $REMOVE " in *" $target "*) return ;; esac
	REMOVE="$REMOVE $target"
}

ui_print "[P] Finding Google apps to unbundle..."
ui_print "-------------------------------------------"
ui_print "[M] PACKAGE                           STATE"
ui_print "-------------------------------------------"
# Stock app dirs from package manager, incl. hidden system packages behind updates
for package in $(grep -o '^[^#]*' "$MODPATH/packages.txt"); do
	dirs="$(dumpsys package "$package" | grep -oE 'codePath=/[^ ]+' | cut -d= -f2 | grep -v '^/data/')"
	[ -n "$dirs" ] || continue
	# Package manager keeps updated app as user app when its system app is gone
	if pm path "$package" | grep -q '/data/app/'; then
		state="USER APP"
	else
		state="REMOVED"
	fi
	ui_print "$(printf "%-32s %s" "[I] $package" "$state")"
	found=true
	for dir in $dirs; do
		add_target "$dir"
	done
done
[ -n "$found" ] || ui_print "[I] No Google apps on system, already unbundled stay so"
ui_print "-------------------------------------------"
# Whiteouts of already installed module version, package manager doesn't see removed apps anymore.
# KernelSU/APatch move partitions out of system/ and overlay metamodules move files to their own dir.
old_whiteouts="$(for dir in "/data/adb/modules/$MODID" "/data/adb/metamodule/mnt/$MODID"; do
	(cd "$dir" 2> /dev/null && find . -type c | sed -E 's#^\./##; s#^(product|system_ext|vendor)/#system/\1/#; s#^#/#')
done)"
for dir in $old_whiteouts; do
	add_target "$dir"
done
ui_print "[I] Apps removed by installer below (Remove target), user apps keep their data"
