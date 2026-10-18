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
	echo "  -F            Fossify variant: Hard with Fossify apps as replacements (see pull-fossify.sh)"
	exit "${1:-0}"
}

while getopts "hHF" opt; do
	case $opt in
		h) show_help ;;
		H) variant=hard ;;
		F) variant=fossify ;;
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
if [ -n "$variant" ]; then
	cat "$module_dir/packages-hard.txt" >> "$module_dir/packages.txt"
	sed -i 's/^name=.*/& Hard/; s/^description=.*/description=Removes Google apps, phone basics and Google system components from system/' "$module_dir/module.prop"
	sed -i "s/update-unbundle.json/update-unbundle-$variant.json/" "$module_dir/module.prop"
fi
rm "$module_dir/packages-hard.txt"
if [ "$variant" = fossify ]; then
	apks=(apk/fossify/org.fossify.*.apk)
	[ -f "${apks[0]}" ] || { echo "[C] No Fossify apps in apk/fossify/, run scripts/pull-fossify.sh"; exit 1; }
	for apk in "${apks[@]}"; do
		# org.fossify.phone_22.apk => FossifyPhone
		app="${apk##*/org.fossify.}"
		app="${app%%_*}"
		app="Fossify${app^}"
		mkdir -p "$module_dir/system/product/app/${app}"
		cp "$apk" "$module_dir/system/product/app/${app}/${app}.apk"
		echo "[I] Adding ${apk##*/}"
	done
	# Bundled apps replace the ones with roles, so they are removed without checking for other replacements
	sed -i -E 's/^([^ #]+) +(home|dialer|sms|ime|alarm|camera)( |$)/\1 /' "$module_dir/packages.txt"
	sed -i 's/^name=.*Hard$/name=Noogle Unbundle Fossify/; s/^description=.*/description=Replaces Google apps, phone basics and Google system components with Fossify apps/' "$module_dir/module.prop"
else
	rm "$module_dir/service.sh"
fi

mkdir -p "$dist_dir"
rm -f "$dist_dir/$module_filename"
(cd "$module_dir" && zip -q -r "../$dist_dir/$module_filename" .)
echo "[P+] Module built: $dist_dir/$module_filename"
