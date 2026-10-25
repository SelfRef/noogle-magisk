# noogle-magisk

Magisk modules for removing/replacing Google applications on stock Android 11-17.

Noogle is developed in my free time. If it helps you get rid of Google, consider supporting its development:

[![Support me on Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/N5E229GJPZ)
[![Sponsor on GitHub](https://img.shields.io/badge/Sponsor-EA4AAA?style=for-the-badge&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/SelfRef)
[![Donate using Liberapay](https://liberapay.com/assets/widgets/donate.svg)](https://liberapay.com/SelfRef/donate)

## Modules

Name | Description
--- | ---
Noogle microG | Installs microG Services in place of Google Services (if present), comes in [4 variants](#which-noogle-microg-to-choose)
Noogle Unbundle | Removes other Google apps from system, comes in [3 variants](#which-noogle-unbundle-to-choose)

Modules are independent, use one or both. Variants of a module replace each other, switch anytime by installing another variant over the installed one, the installer brings back or removes apps as needed.

### Which Noogle microG to choose

Variant | Play Store | Signature spoofing | microG updates from F-Droid | Play Integrity Fix
:--- | --- | --- | --- | ---
`noogle-microg` | Replaced by microG Companion | Needed | Yes | Yes
`noogle-microg-playful` | Kept [*](#playful-variant) | Needed | Yes | Yes
`noogle-microg-catfish` | Replaced by microG Companion | Not needed | No | microG may crash
`noogle-microg-playful-catfish` | Kept [*](#playful-variant) | Not needed | No | microG may crash

**Playful or not:** Playful keeps Play Store of your ROM. The others replace it with microG Companion, which only provides Play Store services to apps, use [Aurora Store](https://auroraoss.com) to get apps.

**Catfish or not:** Regular variants need your ROM to report Google's signature for microG ([signature spoofing](#signatures-are-not-correct)), which stock Android can't do without Vector and FakeGApps. Catfish microG carries signing blocks copied from Google's APKs instead. Android doesn't check contents of system apps against their signatures, so it reports Google's signature without any spoofing. Idea from [microG_no_sigspoof](https://github.com/IsHacker003/microg_no_sigspoof) by IsHacker. The downsides:
- Signatures don't match the contents, so Catfish APKs can't be installed as user apps: microG updates come only with the module (switching to Catfish removes ones installed from F-Droid), and Play Integrity Fix workaround (microG installed as user updates) isn't possible
- Google's updates of Play Services pass as valid updates, the module removes them on every boot
- Tested on Android 15 emulator so far

If your ROM already supports signature spoofing (see [ROMs](#signatures-are-not-correct)), use a regular variant.

### Which Noogle Unbundle to choose

Variant | Removes | Kept | List
:--- | --- | --- | ---
`noogle-unbundle` | Google apps installable from store: Chrome, Gmail, Maps, YouTube, Photos, Drive, Google app... | Phone basics, accessibility, Google system components | [packages.txt](src/module-unbundle/packages.txt)
`noogle-unbundle-hard` | Same, plus phone basics (Pixel Launcher, Phone, Messages, Gboard, Camera, Clock, Contacts...), accessibility (TalkBack, Speech Services), Google system components (Android System Intelligence, Digital Wellbeing, Android Auto...) and Pixel extras | Setup Wizard, Device Health Services, Network Stack, file and sound pickers, carrier services and others that break the phone when removed ([tested](src/module-unbundle/packages-hard.txt)) | [packages.txt](src/module-unbundle/packages.txt) + [packages-hard.txt](src/module-unbundle/packages-hard.txt)
`noogle-unbundle-fossify` | Same as Hard, and installs [Fossify](https://fossify.org) apps as replacements | Same as Hard | Same as Hard

They never remove apps Noogle microG replaces. Switching from Hard or Fossify to a lighter variant brings back apps removed only by them.

**Fossify:** installs Launcher, Phone, Messages, Keyboard, Contacts, Gallery, Calculator, Clock, Camera, File Manager, Calendar, Notes and Voice Recorder as system apps. They are the versions from F-Droid (Fossify's own reproducible builds), so F-Droid updates them, updates stay installed even after removing the module. On every boot the module switches to Fossify Keyboard when the keyboard in use is gone (also on lock screen, so you can type your password), and gives empty home, phone and SMS roles to Fossify apps. Other Fossify apps (Music Player, Paint, Documents...) are in F-Droid.

> [!WARNING]
> Hard removes apps your phone may have no other one for. Install and set up replacements before installing it: launcher, phone, SMS app, camera, clock with alarms, and a keyboard enabled in settings (without one you can't type your password). The installer keeps apps with no replacement installed (it shows them as KEPT), install the module again after adding replacements. Contacts, Gallery or Calculator are removed without checks, install your own if you need them. Open your clock and calendar once and allow notifications, otherwise alarms ring with nothing on screen to stop them and reminders don't show. On some phones alarms of any app may go silent without Google Clock, check yours rings after installing. Fossify variant brings its own replacements and allows notifications for Fossify Clock and Calendar, but the alarm warning applies too.

## Install

It requires Magisk v29.0 or newer. If you don't have it yet, consult the [official installation instructions](https://topjohnwu.github.io/Magisk/install.html).

> [!TIP]
> It's a good idea to enable ADB debugging as well before installing in case of any issues.

> [!NOTE]
> KernelSU and APatch are supported too, but tested less than Magisk. Recent versions (KernelSU v3.0+, APatch 11219+) need a metamodule installed first (e.g. meta-overlayfs or NoMount, which one works best depends on the device), otherwise the module files are not mounted. On KernelSU disable "Umount modules" in App Profile of microG Services, microG Companion and Services Framework Proxy.

> [!NOTE]
> Modules are mainly tested on Android emulators (Google Play images). Real devices and vendor ROMs may behave differently, please [report](#reporting-issues) any issues you hit.

1. Download [variant of your choice](#which-noogle-microg-to-choose) from [releases](https://github.com/SelfRef/noogle-magisk/releases)
    - For playful variant on ROMs without Play Store see [playful build](#playful-variant)
    - [Noogle Unbundle](#which-noogle-unbundle-to-choose) is optional and works on its own, install it as a separate module
2. Install through Magisk app
3. Reboot, microG permissions are granted automatically on first boot
4. Ensure all permission boxes are checked in microG Self-Check
    - If not, click "Action" button next to module in Magisk to grant them again, or tap them in Self-Check
5. Check signature spoofing status at the top of Self-Check
    - Regular variants on ROMs without signature spoofing: [add it](#signatures-are-not-correct)
6. Playful only: enable Google device registration in microG settings, Play Store doesn't work without it

## Build

Requires Linux, Mac or WSL on Windows with `bash`, `zip`, `curl` and `jq`. Optionally `apksigner` (Android SDK build-tools) and `keytool` (JDK) to re-sign Services Framework Proxy with newer signature schemes, which some ROMs may require.

1. Run `scripts/pull-microg.sh` to download latest microG APKs to `apk/` and verify their checksums
    - Or [download them manually](https://microg.org/download.html) and place in `apk/` directory
2. Run `scripts/build-noogle-microg.sh` (or `scripts/build-noogle-unbundle.sh` for Noogle Unbundle, it needs no APKs, `-H` builds Hard, `-F` Fossify after `scripts/pull-fossify.sh` downloads Fossify apps)
    - Module will be created in `dist/`
    - Check `-h` flag for build options, like destination partition

### Playful variant

Released playful modules don't contain Play Store, they keep the one your ROM has. Bundling it would mean redistributing Google's APK, and it comes in different versions and architectures. If your ROM has no Play Store (e.g. LineageOS), build playful variant with Play Store APK yourself (`-P` below).

- `scripts/build-noogle-microg.sh -p` builds playful variant, which keeps Play Store of your ROM
- `scripts/build-noogle-microg.sh -P <apk>` builds playful variant with given Play Store APK, for ROMs without Play Store (e.g. LineageOS)
    - Play Store APK must support your Android version (newer ones need Android 12+)
    - This build is not updated by Magisk, updating to released playful build would remove Play Store

### Catfish variant

Catfish build needs `zipalign` and `apksigner` (Android SDK build-tools) and signing blocks of Google's APKs, which aren't in the repo:

1. Get the signing blocks into `signatures/` with `scripts/pull-signatures.sh`, once:
    - From a device with stock Google apps through ADB (Noogle microG disabled)
    - Or from APK files: `scripts/pull-signatures.sh <Play Services APK> <Play Store APK>`
    - It checks the APKs are signed by Google, microG ones are rejected
2. Run `scripts/build-noogle-microg.sh -c`, add `-p` or `-P <apk>` for playful catfish (only microG Services gets Google's signature, Play Store has its own)

### Install from PC

Instead of copying the module to your phone, you can build and install it through ADB in one go:

1. Enable ADB debugging and connect your phone
2. Grant root to Shell in Magisk (it will ask on first `adb shell su`)
3. Run `scripts/install-noogle.sh`
    - It builds the module, installs it and reboots the phone, asking before each step (`-y` to skip)
    - It accepts the same build options as the build script, `-u` installs Noogle Unbundle instead, `-H` Noogle Unbundle Hard, `-F` Noogle Unbundle Fossify

## Compatibility

Module/Type | Notes
:--- | ---
Vector + FakeGApps | Recommended way to [enable signature spoofing](#signatures-are-not-correct), not needed with Catfish
Play Integrity Fix | [Maintained forks](#signatures-are-not-correct) only, not with Catfish
User updates | Installing microG updates from F-Droid repo, not with Catfish

## Troubleshooting

### Signatures are not correct
microG apps pretend to be Google apps, so Android must report Google's signature for them. This is called [signature spoofing](https://github.com/microg/GmsCore/wiki/Signature-Spoofing) and microG Self-Check shows at the top whether it works. [Catfish variants](#which-noogle-microg-to-choose) don't need it.

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
See [which to choose](#which-noogle-unbundle-to-choose), lists have a comment for each app and say what's kept on purpose. Apps not on your device are skipped.

#### What happens to my data in unbundled apps?
Apps you updated stay installed as regular apps with their data, so you can uninstall them like any other app. Apps never updated are removed with their data. After uninstalling Noogle Unbundle they are back as system apps.

### Setup

#### Do I need Vector and FakeGApps?
Only with regular variants on ROMs without signature spoofing, which is the case for every stock Android. Check the top of microG Self-Check, if spoofing is ticked, you don't need them. Catfish variants don't need them at all.

#### Can I use the real Play Store instead of microG Companion?
Yes, install a playful variant, see [which to choose](#which-noogle-microg-to-choose). If your ROM has no Play Store, build the [playful variant](#playful-variant) with Play Store APK. Aurora Store works with all variants too.

#### How do I update microG?
Module updates with new microG versions come through Magisk app. With regular variants you can also install microG updates from microG F-Droid repo on top of the module. Or [build the module](#build) yourself, `scripts/pull-microg.sh` downloads the latest microG.

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

Logcat may contain personal data like account names or nearby networks, check it before attaching. Questions are welcome in [Issues](https://github.com/SelfRef/noogle-magisk/issues).

## Credits

- [microG](https://github.com/microg/GmsCore), [Magisk](https://github.com/topjohnwu/Magisk), [Vector](https://github.com/JingMatrix/Vector) and [FakeGApps](https://github.com/whew-inc/FakeGApps) developers
- People reporting issues and sending pull requests on GitHub, especially:
    - [bschtl](https://github.com/bschtl), for answering many issues too
    - [sewnie](https://github.com/sewnie), [becknik](https://github.com/becknik) and [adiktofsugar](https://github.com/adiktofsugar), for pull requests that shaped the APK download script, device path detection and microG permission updates
    - [StarchildCatalystN7](https://github.com/StarchildCatalystN7), for a fork with fixes that helped users while the project was paused
    - [Louis047](https://github.com/Louis047) and [Gorkido](https://github.com/Gorkido), for testing and helping others update microG manually
- People in the [XDA thread](https://xdaforums.com/t/guide-magisk-module-universal-systemless-microg-installation-on-stock-android.4686426/) helping others and testing on their devices, especially:
    - bschtl, for keeping the thread alive with fixes and workarounds (Play Store swap, KernelSU metamodule)
    - someone8, for the inspiration and research on privileged permissions and signature spoofing, and the pointer to microG without it
    - IsHacker, for [microG_no_sigspoof](https://github.com/IsHacker003/microg_no_sigspoof), the idea behind the catfish variant
    - stormy1777, for the Play Integrity Fix crash report and workaround
