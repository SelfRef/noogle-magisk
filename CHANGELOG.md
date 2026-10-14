# Unreleased
- Requires Magisk v29.0+
- Updated privileged permissions for current microG (fixes bootloop with microG 0.3.12+)
- Google apps to remove are detected on device instead of fixed paths (fixes Google Services Framework not removed)
- microG permissions are granted automatically on first boot
- Extract only native libraries needed by device
- Fixed Action button when run from other directory

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