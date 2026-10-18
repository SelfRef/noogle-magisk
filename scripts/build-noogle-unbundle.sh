#!/usr/bin/env bash
# Builds Noogle Unbundle module zip from src/.

set -e

dist_dir=dist
module_dir=module-unbundle
variant=""

# $1: exit code
show_help() {
	echo "Usage: $0 [options]"
	echo "Builds module into $dist_dir/."
	echo "Options:"
	echo "  -h            Show this help message"
	echo "  -H            Hard variant: removes phone basics and Google system components too"
	exit "${1:-0}"
}

while getopts "hH" opt; do
	case $opt in
		h) show_help ;;
		H) variant=hard ;;
		*) show_help 1 ;;
	esac
done

# Date based version, Magisk offers update when versionCode grows. Release script sets them for same day releases.
module_version="${MODULE_VERSION:-v$(date -u +%Y.%m.%d)}"
module_version_code="${MODULE_VERSION_CODE:-$(date -u +%Y%m%d)00}"
module_filename="noogle-unbundle${variant:+-$variant}-$module_version.zip"

echo "[P] Building module noogle-unbundle${variant:+-$variant} $module_version..."
rm -rf "$module_dir"
cp -r "src/$module_dir" "$module_dir"
printf '\nversion=%s\nversionCode=%s\n' "$module_version" "$module_version_code" >> "$module_dir/module.prop"
if [ "$variant" = hard ]; then
	cat "$module_dir/packages-hard.txt" >> "$module_dir/packages.txt"
	sed -i 's/^name=.*/& Hard/; s/^description=.*/description=Removes Google apps, phone basics and Google system components from system/' "$module_dir/module.prop"
	sed -i 's/update-unbundle.json/update-unbundle-hard.json/' "$module_dir/module.prop"
fi
rm "$module_dir/packages-hard.txt"

mkdir -p "$dist_dir"
rm -f "$dist_dir/$module_filename"
(cd "$module_dir" && zip -q -r "../$dist_dir/$module_filename" .)
echo "[P+] Module built: $dist_dir/$module_filename"
