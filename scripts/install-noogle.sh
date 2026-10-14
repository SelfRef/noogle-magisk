#!/usr/bin/env bash
# Builds Noogle microG module and installs it through ADB on a rooted device.

set -e

module_version="$(grep '^version=' src/module-microg/module.prop | cut -d'=' -f2)"
module_filename="noogle-microg-$module_version.zip"
skip_confirmations=false
build_args=()

show_help() {
	echo "Usage: $0 [options]"
	echo "Builds module, installs it with Magisk through ADB and reboots the device."
	echo "Options:"
	echo "  -h            Show this help message"
	echo "  -y            Don't ask for confirmations"
	echo "  -d <dir>      Passed to build: destination partition [system|product|system_ext]"
	echo "  -s <suffix>   Passed to build: suffix added to app directories and APK names"
	exit 0
}

while getopts "hyd:s:" opt; do
	case $opt in
		h) show_help ;;
		y) skip_confirmations=true ;;
		d|s) build_args+=("-$opt" "$OPTARG") ;;
		*) show_help ;;
	esac
done

# $1: question
confirm() {
	[ "$skip_confirmations" = true ] || read -rp "[?] $1 [Enter to continue, Ctrl+C to abort] "
}

./scripts/build-noogle-microg.sh "${build_args[@]}"

confirm "Install $module_filename on $(adb get-serialno)?"
echo "[P] Installing module..."
adb push "dist/$module_filename" /sdcard/
adb shell su -c "magisk --install-module /sdcard/$module_filename"
adb shell rm "/sdcard/$module_filename"

confirm "Reboot?"
echo "[P] Rebooting..."
adb reboot
