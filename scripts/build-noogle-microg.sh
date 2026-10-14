#!/usr/bin/env bash
# Builds Noogle microG module zip from src/ and microG APKs in apk/.

set -e

apk_dir=apk
src_dir=src
dist_dir=dist
module_dir=module-microg
destination_dir=system/product
suffix=MG
# package => system app name
declare -A apps=(
	[com.google.android.gms]=GmsCore
	[com.android.vending]=Phonesky
	[com.google.android.gsf]=GoogleServicesFramework
)

# $1: exit code
show_help() {
	echo "Usage: $0 [options]"
	echo "Builds module into $dist_dir/, requires exactly one APK per microG package in $apk_dir/ (see pull-microg.sh)."
	echo "Options:"
	echo "  -h            Show this help message"
	echo "  -d <dir>      Destination partition [system|product|system_ext] (default: product)"
	echo "  -s <suffix>   Suffix added to app directories and APK names (default: MG)"
	exit "${1:-0}"
}

while getopts "hd:s:" opt; do
	case $opt in
		h) show_help ;;
		d)
			case $OPTARG in
				system) destination_dir=system ;;
				product) destination_dir=system/product ;;
				system_ext) destination_dir=system/system_ext ;;
				*)
					echo "[C] Invalid destination partition: $OPTARG"
					show_help 1
					;;
			esac
			;;
		s) suffix="$OPTARG" ;;
		*) show_help 1 ;;
	esac
done

module_version="$(grep '^version=' "$src_dir/$module_dir/module.prop" | cut -d'=' -f2)"
module_filename="noogle-microg-$module_version.zip"

echo "[P] Building module noogle-microg $module_version..."
start=$SECONDS
rm -rf "$module_dir"
mkdir -p "$module_dir"

for pkg in "${!apps[@]}"; do
	apks=("$apk_dir/$pkg"*.apk)
	if [ ! -f "${apks[0]}" ]; then
		echo "[P!] $pkg: missing in $apk_dir/, run scripts/pull-microg.sh or download from https://microg.org/download.html"
		exit 1
	elif [ ${#apks[@]} -gt 1 ]; then
		echo "[P!] $pkg: ${#apks[@]} APKs in $apk_dir/, keep only one"
		exit 1
	fi
	echo "[I] Adding ${apks[0]##*/}"
	app="${apps[$pkg]}$suffix"
	mkdir -p "$module_dir/$destination_dir/priv-app/$app"
	cp "${apks[0]}" "$module_dir/$destination_dir/priv-app/$app/$app.apk"
done

cp -r "$src_dir/$module_dir"/* "$module_dir/"
mv "$module_dir/etc" "$module_dir/$destination_dir/"

gms_dir="$destination_dir/priv-app/GmsCore$suffix"
sed -i "1i gms_path=$gms_dir/GmsCore$suffix.apk" "$module_dir/customize.sh"
sed -i "1i gms_dir=$gms_dir" "$module_dir/customize.sh"

echo "[I] Removing service script (doesn't work)"
rm -f "$module_dir/service.sh"

mkdir -p "$dist_dir"
rm -f "$dist_dir/$module_filename"
(cd "$module_dir" && zip -q -r "../$dist_dir/$module_filename" . -x '*.gitkeep')

echo "[P+][$((SECONDS - start))s] Module built: $dist_dir/$module_filename"
