#!/usr/bin/env bash
# Recovery: disables the module when it breaks booting. Waits for the device, so it can be run during bootloop.

set -e

echo "[P] Waiting for device..."
adb wait-for-device
echo "[P+] Device $(adb get-serialno) connected"

echo "[P] Disabling module..."
if ! adb shell su -c "touch /data/adb/modules/noogle-microg/disable"; then
	echo "[P!] Could not disable module, try: adb shell magisk --remove-modules"
	exit 1
fi
echo "[P+] Module disabled"

echo "[I] Rebooting device"
adb reboot
