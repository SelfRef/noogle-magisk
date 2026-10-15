# noogle-magisk

Magisk modules for removing/replacing Google applications on stock Android 11-17.

## Modules

Name | Description
--- | ---
Noogle microG | Installs microG Services in place of Google Services (if present)
Noogle Debloat [WIP] | Removes other Google system apps from Android (still can be installed from store)

## Install

It requires Magisk v29.0 or newer. If you don't have it yet, consult the [official installation instructions](https://topjohnwu.github.io/Magisk/install.html).

> [!TIP]
> It's a good idea to enable ADB debugging as well before installing in case of any issues.

> [!NOTE]
> KernelSU and APatch are supported too, but tested less than Magisk. Recent versions (KernelSU v3.0+, APatch 11219+) need a metamodule installed first, like meta-overlayfs, otherwise the module files are not mounted. On KernelSU disable "Umount modules" in App Profile of microG Services, microG Companion and Services Framework Proxy.

1. Download latest version from [releases](https://github.com/SelfRef/noogle-magisk/releases)
2. Install through Magisk app
3. Reboot, microG permissions are granted automatically on first boot
4. Ensure all permission boxes are checked in microG Self-Check
    - If not, click "Action" button next to module in Magisk to grant them again, or tap them in Self-Check
5. Check signature spoofing status at the top of Self-Check
    - If your ROM doesn't support signature spoofing, you must add it: [check troubleshooting](#signatures-are-not-correct)

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
3. Download and install [FakeGApps](https://github.com/whew-inc/FakeGApps/releases) APK
    - Supports up to Android 16, Android 17 is not confirmed yet
4. Reboot
5. Open Vector from notifications, enable FakeGApps in Modules and select System Framework as its only scope
    - System Framework is hidden by default, show it with Filter > What the module asks for
    - Tap Apply to save the scope
6. Reboot
7. Check in microG Self-Check if signatures are correct now
8. Optionally install Play Integrity Fix through Magisk, original is discontinued, use one of the maintained forks:
    - [PlayIntegrityFork](https://github.com/osm0sis/PlayIntegrityFork) by osm0sis
    - [PIF Inject](https://github.com/KOWX712/PlayIntegrityFix) by KOWX712

Other ways you may find:
- ROM patchers (Haystack, NanoDroid-patcher, Tingle) work properly only below Android 9
- microG APKs with signature blocks copied from Google APKs don't need spoofing, but can't be updated as user apps

### microG crashing
If microG crashes when used with other modules interacting with it, like Play Integrity Fix, install both microG Services and microG Companion (same APKs as in this module, from [official site](https://microg.org/download.html)) on top, as user updates. This should not be needed with recent versions, but may help on some devices.

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
- Q: What is the difference between this and other microG installers?
- A: This module aims for stock Android support with Google apps preinstalled and doesn't require debloating Google apps first. Should work on AOSP-based as well.

- Q: Do I need Vector and FakeGApps?
- A: Only if your ROM doesn't support signature spoofing, which is the case for every stock Android. Check the top of microG Self-Check, if spoofing is ticked, you don't need them.

- Q: How do I update microG?
- A: Module updates come through Magisk app with new microG versions. If you want newer microG sooner, install microG updates from microG F-Droid repo on top of the module, or [build the module](#build) yourself, `scripts/pull-microg.sh` downloads the latest microG.

- Q: Can I use the real Play Store instead of microG Companion?
- A: The module replaces Play Store with microG Companion. Aurora Store works with microG out of the box. Users reported that the real Play Store works too, when its APK is put in `apk/` in place of microG Companion before [building](#build). Uninstall the old module first, updating over it is not enough.

- Q: Logging in to Google account fails with "There was a problem communicating with Google servers"
- A: Update microG to the latest version (see above). If you use a firewall, allow network access for microG Services, it's a separate app from Google's one.

- Q: What happens when I uninstall the module?
- A: The system partition is not modified, so after reboot preinstalled Google apps are back. Their updates are removed during module installation, so Play Store will download them again.

- Q: Location doesn't work after uninstalling the module
- A: Google Play Services may be left without location permissions. Grant them with:
  ```sh
  adb shell pm grant com.google.android.gms android.permission.ACCESS_COARSE_LOCATION
  adb shell pm grant com.google.android.gms android.permission.ACCESS_FINE_LOCATION
  ```
