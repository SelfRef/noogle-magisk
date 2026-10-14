#!/usr/bin/env bash

adb install --user all apk/com.google.android.gms*.apk
adb install --user all apk/com.android.vending*.apk

echo -n 'Reboot?'
read
adb reboot