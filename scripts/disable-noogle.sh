#!/usr/bin/env bash
# Recovery: disables Noogle modules when they break booting. Waits for the device, so it can be run during bootloop.

set -e

echo "[P] Waiting for device..."
adb wait-for-device
echo "[P+] Device $(adb get-serialno) connected"

echo "[P] Disabling modules..."
if ! adb shell su -c "'for module in /data/adb/modules/noogle-*; do touch \$module/disable; done'"; then
	echo "[P!] Could not disable modules, try: adb shell magisk --remove-modules"
	exit 1
fi
echo "[P+] Modules disabled"

echo "[I] Rebooting device"
adb reboot
