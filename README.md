# noogle-magisk

Magisk modules for removing/replacing Google applications on stock Android 11-15.

## Modules

Name | Description
--- | ---
Noogle microG | Installs microG Services in place of Google Services (if present)
Noogle Debloat [WIP] | Removes other Google system apps from Android (still can be installed from store)

## Install

It requires Magisk to be installed obviously as it's a Magisk module. If you don't have it yet, consult the [official installation instructions](https://topjohnwu.github.io/Magisk/install.html).

> [!TIP]
> It's a good idea to enable ADB debugging as well before installing in case of any issues.

1. Download latest version from [releases](https://github.com/SelfRef/noogle-magisk/releases)
    - Or [build it yourself](#build)
2. Install through Magisk app
3. Reboot
4. In Magisk click "Action" button next to module to grant permissions
    - Or open microG app and grant them through Self-Check
5. Ensure all permission boxes are checked in Self-Check
    - If not, tap them to set the correct option
6. Check signature spoofing status at the top
    - If your ROM doesn't support signature spoofing, you must add it: [check troubleshooting](#signatures-are-not-correct)
7. If you have issues with microG crashing, install microG as user apps: [check troubleshooting](#microg-crashing)

## Build

Requires Linux, Mac or WSL on Windows with `bash`, `zip`, `curl` and `jq`.

1. Run `scripts/pull-microg.sh` to download latest microG APKs to `apk/` and verify their checksums
    - Or [download them manually](https://microg.org/download.html) and place in `apk/` directory
2. Run `scripts/build-noogle-microg.sh`
    - Module will be created in `dist/`
    - Check `-h` flag for build options, like destination partition

### Install from PC

Instead of copying the module to your phone, you can build and install it through ADB in one go:

1. Enable ADB debugging and connect your phone
2. Grant root to Shell in Magisk (it will ask on first `adb shell su`)
3. Run `scripts/install-noogle.sh`
    - It builds the module, installs it and reboots the phone, asking before each step (`-y` to skip)
    - It accepts the same build options as the build script

## Compatibility

Module/Type | Notes
:--- | ---
LSPosed + FakeGapps | Both official and from JingMatrix
Play Integrity Fix | Requires installing [user updates](#microg-crashing)
User updates | Installing microG updates from F-Droid repo

## Troubleshooting

### Signatures are not correct
In order for microG apps to have the correct signatures visible by Android, your ROM must allow for [signature spoofing](https://github.com/microg/GmsCore/wiki/Signature-Spoofing). If it does not (like any stock Android), this is the way I recommend:

1. Enable Zygisk in Magisk's settings
2. Download and install LSPosed through Magisk
    - [JingMatrix fork](https://github.com/JingMatrix/LSPosed/releases) up to Android 15 (maintained)
    - [Official version](https://github.com/LSPosed/LSPosed/releases) up to Android 14 (not maintained anymore)
3. Download and install [FakeGApps](https://github.com/whew-inc/FakeGApps/releases) APK
4. Reboot
5. Open LSPosed from notifications and enable FakeGapps module
    - Leave default System Framework selected only
6. Reboot
7. Check in microG Self-Check if signatures are correct now

### microG crashing
If you want to use other modules interacting with microG, like Play Integrity Fix on top of this module, it's necessary to install both microG Services and microG Companion (same APKs as in this module, from [official site](https://microg.org/download.html)) on top, as user updates. Then Play Integrity Fix will work properly. In the future this workaround may be not necessary.

If you built the module yourself, you can install them from `apk/` through ADB:
```sh
adb install --user all apk/com.google.android.gms*.apk
adb install --user all apk/com.android.vending*.apk
```

### Bootloop
If you have ADB debugging enabled, connect your phone to PC and run `scripts/disable-noogle.sh`. It waits for the phone to connect, disables Noogle microG module and reboots it, so you can run it while the phone is bootlooping.

More nuclear option is to run `adb shell magisk --remove-modules`. It will remove all modules from Magisk and reboot.

If you don't have ADB enabled, you may try to restart the device a few times (holding Power + Vol-) while keeping Vol- for a while until animated boot animation starts. This will trigger Magisk safe mode and modules will be disabled. More about this in [official documentation](https://topjohnwu.github.io/Magisk/faq.html).

## QA
- Q: What is the difference between this and other microG installers?
- A: This module aims for stock Android support with Google apps preinstalled and doesn't require debloating Google apps first. Should work on AOSP-based as well.
