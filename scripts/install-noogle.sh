#!/usr/bin/env bash
# Builds Noogle microG module and installs it through ADB on a rooted device.

set -e

skip_confirmations=false
build_args=()

# $1: exit code
show_help() {
	echo "Usage: $0 [options]"
	echo "Builds module, installs it with Magisk through ADB and reboots the device."
	echo "Options:"
	echo "  -h            Show this help message"
	echo "  -y            Don't ask for confirmations"
	echo "  -d <dir>      Passed to build: destination partition [system|product|system_ext]"
	echo "  -s <suffix>   Passed to build: suffix added to app directories and APK names"
	echo "  -p            Passed to build: playful variant keeping device's Play Store"
	echo "  -P <apk>      Passed to build: playful variant with given Play Store APK"
	exit "${1:-0}"
}

while getopts "hyd:s:pP:" opt; do
	case $opt in
		h) show_help ;;
		y) skip_confirmations=true ;;
		d|s|P) build_args+=("-$opt" "$OPTARG") ;;
		p) build_args+=(-p) ;;
		*) show_help 1 ;;
	esac
done

# $1: question
confirm() {
	[ "$skip_confirmations" = true ] || read -rp "[I] $1 [Enter to continue, Ctrl+C to abort] "
}

./scripts/build-noogle-microg.sh "${build_args[@]}"
module_filename="$(cd dist && ls -t *.zip | head -1)"

confirm "Install $module_filename on $(adb get-serialno)?"
echo "[P] Installing module..."
start=$SECONDS
adb push -q "dist/$module_filename" /sdcard/
if ! adb shell su -c "magisk --install-module /sdcard/$module_filename"; then
	adb shell rm "/sdcard/$module_filename"
	echo "[P!] Could not install module"
	exit 1
fi
adb shell rm "/sdcard/$module_filename"
echo "[P+][$((SECONDS - start))s] Module installed"

confirm "Reboot?"
echo "[I] Rebooting device"
adb reboot
