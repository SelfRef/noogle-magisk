#!/usr/bin/env bash
# Recovery: disables the module when it breaks booting. Waits for the device, so it can be run during bootloop.

echo "[P] Waiting for device..."
adb wait-for-device
adb shell su -c "touch /data/adb/modules/noogle-microg/disable"
adb reboot
