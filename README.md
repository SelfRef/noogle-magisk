# noogle-magisk

Magisk modules for removing/replacing Google applications on stock Android 11-17.

## Modules

Name | Description
--- | ---
Noogle microG | Installs microG Services in place of Google Services (if present) and microG Companion in place of Play Store
Noogle microG Playful | Same, but keeps Play Store
Noogle Unbundle | Removes other Google apps from system, like Chrome, Gmail, Maps or YouTube (they stay installable from store)

## Install

It requires Magisk v29.0 or newer. If you don't have it yet, consult the [official installation instructions](https://topjohnwu.github.io/Magisk/install.html).

> [!WARNING]
> Modules are mainly tested on Android emulators (Google Play images). Real devices and vendor ROMs may behave differently, please [report](#reporting-issues) any issues you hit.

> [!TIP]
> It's a good idea to enable ADB debugging as well before installing in case of any issues.

> [!NOTE]
> KernelSU and APatch are supported too, but tested less than Magisk. Recent versions (KernelSU v3.0+, APatch 11219+) need a metamodule installed first (e.g. meta-overlayfs or NoMount, which one works best depends on the device), otherwise the module files are not mounted. On KernelSU disable "Umount modules" in App Profile of microG Services, microG Companion and Services Framework Proxy.

1. Download latest version from [releases](https://github.com/SelfRef/noogle-magisk/releases)
    - `noogle-microg` replaces Play Store with microG Companion, use [Aurora Store](https://auroraoss.com) for apps
    - `noogle-microg-playful` keeps Play Store of your ROM, for ROMs without it see [playful build](#playful-variant)
    - `noogle-unbundle` is optional and works on its own, install it as a separate module
2. Install through Magisk app
3. Reboot, microG permissions are granted automatically on first boot
4. Ensure all permission boxes are checked in microG Self-Check
    - If not, click "Action" button next to module in Magisk to grant them again, or tap them in Self-Check
5. Check signature spoofing status at the top of Self-Check
    - If your ROM doesn't support signature spoofing, you must add it: [check troubleshooting](#signatures-are-not-correct)
6. Playful only: enable Google device registration in microG settings, Play Store doesn't work without it

## Build

Requires Linux, Mac or WSL on Windows with `bash`, `zip`, `curl` and `jq`. Optionally `apksigner` (Android SDK build-tools) and `keytool` (JDK) to re-sign Services Framework Proxy with newer signature schemes, which some ROMs may require.

1. Run `scripts/pull-microg.sh` to download latest microG APKs to `apk/` and verify their checksums
    - Or [download them manually](https://microg.org/download.html) and place in `apk/` directory
2. Run `scripts/build-noogle-microg.sh` (or `scripts/build-noogle-unbundle.sh` for Noogle Unbundle, it needs no APKs)
    - Module will be created in `dist/`
    - Check `-h` flag for build options, like destination partition

### Playful variant

- `scripts/build-noogle-microg.sh -p` builds playful variant, which keeps Play Store of your ROM
- `scripts/build-noogle-microg.sh -P <apk>` builds playful variant with given Play Store APK, for ROMs without Play Store (e.g. LineageOS)
    - Play Store APK must support your Android version (newer ones need Android 12+)
    - This build is not updated by Magisk, as released playful builds don't contain Play Store

### Install from PC

Instead of copying the module to your phone, you can build and install it through ADB in one go:

1. Enable ADB debugging and connect your phone
2. Grant root to Shell in Magisk (it will ask on first `adb shell su`)
3. Run `scripts/install-noogle.sh`
    - It builds the module, installs it and reboots the phone, asking before each step (`-y` to skip)
    - It accepts the same build options as the build script, `-u` installs Noogle Unbundle instead

## Compatibility

Module/Type | Notes
:--- | ---
Vector + FakeGApps | Recommended way to [enable signature spoofing](#signatures-are-not-correct)
Play Integrity Fix | [Maintained forks](#signatures-are-not-correct) only
User updates | Installing microG updates from F-Droid repo

## Troubleshooting

### Signatures are not correct
microG apps pretend to be Google apps, so Android must report Google's signature for them. This is called [signature spoofing](https://github.com/microg/GmsCore/wiki/Signature-Spoofing) and microG Self-Check shows at the top whether it works.

Some custom ROMs support it out of the box (e.g. LineageOS since 2024-02-26, crDroid, CalyxOS, /e/), in that case nothing else is needed. Note that Google changed signature checks in 2024-11, so older ROM builds may need an update.

Stock Android and most other ROMs don't support it, so it has to be added with an Xposed module. This is the way I recommend:

1. Enable Zygisk in Magisk's settings
2. Download and install [Vector](https://github.com/JingMatrix/Vector/releases) (formerly LSPosed) through Magisk
    - Android 17 doesn't work yet, Vector can't load into the system there
3. Download and install [FakeGApps](https://github.com/whew-inc/FakeGApps/releases) APK
    - Supports up to Android 16, Android 17 is not confirmed yet
4. Reboot
5. Open Vector from notifications, enable FakeGApps in Modules and select System Framework as its only scope
    - System Framework is hidden by default, show it with Filter > What the module asks for
    - Tap Apply to save the scope
6. Reboot, or tap Soft reboot in the dialog after Apply
7. Check in microG Self-Check if signatures are correct now
8. Optionally install Play Integrity Fix through Magisk, original is discontinued, use one of the maintained forks:
    - [PlayIntegrityFork](https://github.com/osm0sis/PlayIntegrityFork) by osm0sis
    - [PIF Inject](https://github.com/KOWX712/PlayIntegrityFix) by KOWX712
    - It hides module files from microG, so the module installs microG Services and Companion as user updates on next boot

Other ways you may find:
- ROM patchers (Haystack, NanoDroid-patcher, Tingle) work properly only below Android 9
- microG APKs with signature blocks copied from Google APKs don't need spoofing, but can't be updated as user apps

### Play Store shows "Server error" or DF-DFERH-01
Enable Google device registration in microG settings and restart Play Store.

### microG crashing
If microG crashes when used with other modules interacting with it, install both microG Services and microG Companion (same APKs as in this module, from [official site](https://microg.org/download.html)) on top, as user updates. With Play Integrity Fix the module does it on its own on boot.

If you built the module yourself, you can install them from `apk/` through ADB:
```sh
adb install --user all apk/com.google.android.gms*.apk
adb install --user all apk/com.android.vending*.apk
```

### Bootloop
If you have ADB debugging enabled, connect your phone to PC and run `scripts/disable-noogle.sh`. It waits for the phone to connect, disables Noogle microG module and reboots it, so you can run it while the phone is bootlooping.

More nuclear option is to run `adb shell magisk --remove-modules`. It will remove all modules from Magisk and reboot.

If you don't have ADB enabled, you may try to restart the device a few times (holding Power + Vol-) while keeping Vol- for a while until animated boot animation starts. This will trigger Magisk safe mode and modules will be disabled. More about this in [official documentation](https://topjohnwu.github.io/Magisk/faq.html).

## Q&A

### General

#### What is the difference between this and other microG installers?
This module aims for stock Android support with Google apps preinstalled and doesn't require debloating Google apps first. Should work on AOSP-based ROMs as well.

#### Which Android versions are supported?
Android 11 to 17, tested on emulators. On Android 17 signature spoofing with Vector doesn't work yet, so microG works there only on ROMs supporting spoofing on their own.

#### Does it work on OnePlus, OPPO or realme?
Only if Google apps are on regular partitions. Some of their ROMs (e.g. OxygenOS 12) keep them on `my_*` partitions like `/my_heytap`, which Magisk modules can't modify. The installer stops with a message in that case.

#### Which apps does Noogle Unbundle remove?
Google apps you can install from store again, like Chrome, Gmail, Maps, YouTube, Photos, Drive or the Google app, full list is in [packages.txt](src/module-unbundle/packages.txt). Phone basics (Dialer, Contacts, Messages, Gboard, Pixel Launcher, Clock, Camera) and system components stay, removing them leaves the phone without a replacement.

#### What happens to my data in unbundled apps?
Apps you updated stay installed as regular apps with their data, so you can uninstall them like any other app. Apps never updated are removed with their data. After uninstalling Noogle Unbundle they are back as system apps.

### Setup

#### Do I need Vector and FakeGApps?
Only if your ROM doesn't support signature spoofing, which is the case for every stock Android. Check the top of microG Self-Check, if spoofing is ticked, you don't need them.

#### Can I use the real Play Store instead of microG Companion?
Yes, install `noogle-microg-playful`, it keeps Play Store of your ROM. You can switch between variants anytime by installing the other one over it. If your ROM has no Play Store, build the [playful variant](#playful-variant) with Play Store APK. Aurora Store works with both variants too.

#### How do I update microG?
Module updates with new microG versions come through Magisk app. You can also install microG updates from microG F-Droid repo on top of the module, or [build the module](#build) yourself, `scripts/pull-microg.sh` downloads the latest microG.

### Problems

#### Logging in to Google account fails with "There was a problem communicating with Google servers"
Update microG to the latest version (see above). If you use a firewall, allow network access for microG Services, it's a separate app from Google's one.

#### What happens when I uninstall the module?
The system partition is not modified, so after reboot preinstalled Google apps are back. Their updates are removed during module installation, so Play Store will download them again.

#### Location doesn't work after uninstalling the module
Google Play Services may be left without location permissions. Grant them with:
```sh
adb shell pm grant com.google.android.gms android.permission.ACCESS_COARSE_LOCATION
adb shell pm grant com.google.android.gms android.permission.ACCESS_FINE_LOCATION
```

## Reporting issues

Open a [bug report](https://github.com/SelfRef/noogle-magisk/issues/new?template=bug_report.yml), it asks for your device, versions and logs:

- Installer output: save button in Magisk after installing
- Noogle microG log of last boot: `adb shell su -c cat /data/adb/modules/noogle-microg/service.log`
- For crashes, logcat right after the crash: `adb logcat -d -b crash,main > logcat.txt`

Logcat may contain personal data like account names or nearby networks, check it before attaching. Questions are welcome in [Discussions](https://github.com/SelfRef/noogle-magisk/discussions).

## Credits

- [microG](https://github.com/microg/GmsCore), [Magisk](https://github.com/topjohnwu/Magisk), [Vector](https://github.com/JingMatrix/Vector) and [FakeGApps](https://github.com/whew-inc/FakeGApps) developers
- People reporting issues and sending pull requests on GitHub, especially:
    - [bschtl](https://github.com/bschtl), for answering many issues too
    - [sewnie](https://github.com/sewnie), [becknik](https://github.com/becknik) and [adiktofsugar](https://github.com/adiktofsugar), for pull requests that shaped the APK download script, device path detection and microG permission updates
    - [StarchildCatalystN7](https://github.com/StarchildCatalystN7), for a fork with fixes that helped users while the project was paused
    - [Louis047](https://github.com/Louis047) and [Gorkido](https://github.com/Gorkido), for testing and helping others update microG manually
- People in the [XDA thread](https://xdaforums.com/t/guide-magisk-module-universal-systemless-microg-installation-on-stock-android.4686426/) helping others and testing on their devices, especially:
    - bschtl, for keeping the thread alive with fixes and workarounds (Play Store swap, KernelSU metamodule)
    - someone8, for the inspiration and research on privileged permissions and signature spoofing
    - stormy1777, for the Play Integrity Fix crash report and workaround
