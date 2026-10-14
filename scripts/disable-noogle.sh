#!/usr/bin/env bash

adb shell su -c "touch /data/adb/modules/noogle-microg/disable"
adb reboot