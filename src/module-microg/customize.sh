# gms_dir and gms_path are prepended by build script

# KernelSU and APatch fake MAGISK_VER_CODE, so detect them first
if [ "$KSU" = true ] || [ "$APATCH" = true ]; then
	# Since KernelSU v3.0.0 (32179) and APatch 11219 module files are mounted only by a metamodule
	if [ ! -e /data/adb/metamodule ]; then
		if [ "${KSU_VER_CODE:-0}" -ge 32179 ] || [ "${APATCH_VER_CODE:-0}" -ge 11219 ]; then
			abort "! Install a metamodule (e.g. meta-overlayfs) first, without it module files are not mounted"
		fi
		ui_print "[W] No metamodule found, if your root solution needs one, module files won't be mounted"
	fi
	if [ "$KSU" = true ]; then
		ui_print "[W] KernelSU: disable \"Umount modules\" in App Profile of microG Services, Companion and Services Framework"
	fi
# Oldest Magisk version this module is tested with
elif [ "$MAGISK_VER_CODE" -lt 29000 ]; then
	abort "! Magisk v29.0+ is required, current: $MAGISK_VER"
fi

. "$MODPATH/common.sh"

remove_package_updates google

ui_print ""
ui_print "[P] Finding Google apps to remove..."
# Stock app dirs from package manager (incl. hidden system packages behind updates) and whiteouts of
# already installed module version (package manager sees our replacements then, not the stock dirs)
stock_dirs="$(for package in $packages; do
	dumpsys package "$package" | grep -oE 'codePath=/[^ ]+' | cut -d= -f2
done | grep -v '^/data/')"
# KernelSU/APatch move partitions out of system/ and overlay metamodules move files to their own dir
old_whiteouts="$(for dir in "/data/adb/modules/$MODID" "/data/adb/metamodule/mnt/$MODID"; do
	(cd "$dir" 2> /dev/null && find . -type c | sed -E 's#^\./##; s#^(product|system_ext|vendor)/#system/\1/#; s#^#/#')
done)"

split_xml=/system/product/etc/permissions/split-permissions-google.xml
[ -e $split_xml ] || split_xml=""

for dir in $stock_dirs $old_whiteouts $split_xml; do
	# Map device path to path inside module
	case $dir in
		/system/*) target=$dir ;;
		/product/* | /system_ext/* | /vendor/*) target=/system$dir ;;
		*) abort "! $dir is on a partition modules can't modify, this device is not supported" ;;
	esac
	# Skip dirs shipped by module itself (when built without suffix) and duplicates
	[ -e "$MODPATH$target" ] && continue
	case " $REMOVE " in *" $target "*) continue ;; esac
	REMOVE="$REMOVE $target"
done
ui_print "[I] Google apps are removed by installer below (Remove target)"

ui_print ""
ui_print "[P] Extracting libraries..."
# System apps need native libs extracted, 64-bit devices get 32-bit ones too for 32-bit apps loading GmsCore code
case $ARCH in
	arm64) abis="arm64:arm64-v8a arm:armeabi-v7a" ;;
	arm) abis="arm:armeabi-v7a" ;;
	x64) abis="x64:x86_64 x86:x86" ;;
	x86) abis="x86:x86" ;;
esac
for abi in $abis; do
	unzip -q -o "$MODPATH/$gms_path" "lib/${abi#*:}/*" -d "$TMPDIR/gms" || abort "! Could not extract ${abi#*:} libraries"
	mkdir -p "$MODPATH/$gms_dir/lib"
	mv "$TMPDIR/gms/lib/${abi#*:}" "$MODPATH/$gms_dir/lib/${abi%%:*}"
	ui_print "[I] ${abi%%:*}: $(ls "$MODPATH/$gms_dir/lib/${abi%%:*}" | wc -l) libraries"
done
rm -rf "$TMPDIR/gms"
# Installer applied default permissions and SELinux context before this script, so set them for extracted libs
set_perm_recursive "$MODPATH/$gms_dir/lib" 0 0 0755 0644

ui_print ""
ui_print "[I] microG permissions are granted on first boot, use Action button if they get lost"
