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
    - Or build it yourself
2. Install through Magisk app
3. Reboot
4. In Magisk click "Action" button next to module to grant permissions
    - Or open microG app and grant them through Self-Check
5. Ensure all permission boxes are checked in Self-Check
    - If not, tap them to set the correct option
6. Check signature spoofing support at the top
    - If your ROM doesn't support signature spoofing, you must add it: [check troubleshooting](#signatures-are-not-correct)
7. (optionally) If you have issues with microG crashing, install microG as user apps: [check troubleshooting](#microg-crashing)

> [!WARNING]
> Installing Play Integrity Fix module will cause microG to crash.
> This issue is yet to be resolved.

## Build

0. Use Linux, Mac or WSL on Windows
1. Install `zip`, `curl`, `jq` if not present
2. [Download APKs manually](https://microg.org/download.html) and place in `apk/`
    - Or run `./pull-latest-microg.sh` (not reliable for now)
3. Run `./prepare.sh`
4. Run `./build-noogle-microg.sh`
5. Module will be created in `dist/`

## Tested on
The module was tested on:
Device | OS | Android Version
:---: | :---: | :---:
Nothing Phone (1) | NothingOS 3.0 | 15

Need more tests...

## Troubleshooting

### Signatures are not correct
In order for microG apps to have the correct signatures visible by Android, your ROM must allow for [signature spoofing](https://github.com/microg/GmsCore/wiki/Signature-Spoofing). If it does not (like any stock Android), this is the way I recommend:

1. Enable Zygisk in Magisk's settings
2. Download and install LSPosed through Magisk
    - [JingMatrix fork](https://github.com/JingMatrix/LSPosed/releases) up to Android 15 (maintained)
    - [Official version](https://github.com/LSPosed/LSPosed/releases) up to Android 14 (not maintaned anymore)
3. Download and install [FakeGApps](https://github.com/whew-inc/FakeGApps/releases) APK
4. Reboot
5. Open LSPosed from notifications and enable FakeGapps module
    - Leave default System Framework selected only
6. Reboot
7. Check in microG Self-Check if signatures are correct now

## microG crashing
Installing Play Integrity Fix on top of my module is making microG app crash for the moment (in some cases may cause bootloop) so I don't recommend it to install right now. The workaround for this is installing both microG Services and microG Companion (same APKs as in this module, from [official site](https://microg.org/download.html)) on top, as user updates. Then Play Integrity Fix should work properly. I work on making this workaround not necessary.

### Bootloop
In this case if you have ADB debugging enabled just connect your phone to PC and in terminal run `adb shell magisk --remove-modules`. It will remove all modules.

If you don't have ADB enabled, you may try to restart the device a few times (holding Power + Vol-) until Magisk safe mode hits and modules will be disabled.

## QA
- Q: What is the difference between this and other microG installers?
- A: This installer aims for stock Android support with Google apps preinstalled. Should work on AOSP-based as well.