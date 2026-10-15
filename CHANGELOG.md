# Unreleased

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