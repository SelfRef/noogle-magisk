#!/usr/bin/env bash
# Builds Noogle Unbundle module zip from src/.

set -e

dist_dir=dist
module_dir=module-unbundle
# Date based version, Magisk offers update when versionCode grows. Release script sets them for same day releases.
module_version="${MODULE_VERSION:-v$(date -u +%Y.%m.%d)}"
module_version_code="${MODULE_VERSION_CODE:-$(date -u +%Y%m%d)00}"
module_filename="noogle-unbundle-$module_version.zip"

echo "[P] Building module noogle-unbundle $module_version..."
rm -rf "$module_dir"
cp -r "src/$module_dir" "$module_dir"
printf '\nversion=%s\nversionCode=%s\n' "$module_version" "$module_version_code" >> "$module_dir/module.prop"

mkdir -p "$dist_dir"
rm -f "$dist_dir/$module_filename"
(cd "$module_dir" && zip -q -r "../$dist_dir/$module_filename" .)
echo "[P+] Module built: $dist_dir/$module_filename"
