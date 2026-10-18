# Unreleased

# v2026.10.18.2
- microG Services 0.3.17.252432, Companion 0.3.17.40226, Services Framework Proxy v0.1.0
- Noogle Unbundle Fossify allows notifications for Fossify Clock and Calendar, alarms rang with nothing on screen to stop them

# v2026.10.18.1
- microG Services 0.3.17.252432, Companion 0.3.17.40226, Services Framework Proxy v0.1.0
- Switching to Noogle microG Catfish removes microG updates installed from F-Droid, they hid Catfish microG and needed signature spoofing again

# v2026.10.18
- microG Services 0.3.17.252432, Companion 0.3.17.40226, Services Framework Proxy v0.1.0
- New Noogle microG Catfish variant, microG carries Google's signatures, so it works without signature spoofing (no Vector/FakeGApps), but can't be updated as user app (idea from [microG_no_sigspoof](https://github.com/IsHacker003/microg_no_sigspoof) by IsHacker)
- New Noogle microG Playful Catfish variant, keeps Play Store and works without signature spoofing
- New Noogle Unbundle Hard variant, removes phone basics, accessibility, Google system components and Pixel extras too, apps with no replacement installed (launcher, phone, SMS, keyboard, camera) are kept
- New Noogle Unbundle Fossify variant, Hard with Fossify apps as system apps (F-Droid versions, so F-Droid updates them), switches to Fossify Keyboard when the one in use is gone
- Switching from Noogle Unbundle Hard back to Unbundle brings back apps removed only by Hard
- microG permissions are granted reliably on first boot, some were skipped as not available when checked too early

# v2026.10.16
- microG Services 0.3.17.252432, Companion 0.3.17.40226, Services Framework Proxy v0.1.0
- microG gets "Display over other apps" permission on first boot too, it was skipped before
- microG Services and Companion are installed as user updates when Play Integrity Fix is installed, it hides module files from them and they crashed

# v2026.10.15.1
- microG Services 0.3.17.252432, Companion 0.3.17.40226, Services Framework Proxy v0.1.0
- Services Framework Proxy is re-signed with newer signature schemes (v2/v3), some ROMs reject its old v1 signature ([#24](https://github.com/SelfRef/noogle-magisk/issues/24), thanks [@StarchildCatalystN7](https://github.com/StarchildCatalystN7))
- Switching between Noogle microG and Playful brings back the right Play Store and clears data of switched apps

# v2026.10.15
- microG Services 0.3.17.252432, Companion 0.3.17.40226, Services Framework Proxy v0.1.0
- New Noogle Unbundle module, removes other Google apps from system (they stay installable from store)
- Background location and SMS permissions of microG are granted properly (they are restricted and need allowlisting)
- Fixed clearing data of replaced Google apps on first boot (failed when run too early)
- New Noogle microG Playful variant, keeps Play Store (build option -P bundles Play Store APK for ROMs without it)
- Versions are release dates now, new microG versions are released automatically
- Requires Magisk v29.0+
- Updated privileged permissions for current microG (fixes bootloop with microG 0.3.12+)
- Google apps to remove are detected on device instead of fixed paths (fixes Google Services Framework not removed)
- microG permissions are granted automatically on first boot
- Extract only native libraries needed by device
- Fixed Action button when run from other directory
- KernelSU and APatch: installer checks for metamodule and keeps removed Google apps on update
- Support for Android 16 and 17 (Google Services in APEX)
- Data of replaced Google apps is cleared on first boot (fixes "Google keeps stopping" crashes)
- Google app updates are removed on every boot (fixes Play Store self-updating over microG Companion)
- Permissions not existing on older Android versions are skipped

# v2.1
- Prevent uninstall microG updates during self-check (Action button in Magisk)

# v2.0
- Restructured project
- Better compatibility with stock Android
- Fixed bootloop on NothingOS
- Improved build script allows for different configurations
- Removing app updates during module install
- Improved GApps removing
- Libraries extraction during install (fixes Google Maps)
- Installing user app on top is supported but optional
- Support for Play Integrity Fix (requires installing update)

# v1.2
- Fixed removing GApps on Magisk v28.1 (current stable)

# v1.1
- Added Services Framework Proxy
- Improved local building scripts

# v1.0
Initial version