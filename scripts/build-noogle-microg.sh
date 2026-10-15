#!/usr/bin/env bash
# Builds Noogle microG module zip from src/ and microG APKs in apk/.

set -e

apk_dir=apk
src_dir=src
dist_dir=dist
module_dir=module-microg
destination_dir=system/product
suffix=MG
variant=""
playstore_apk=""
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
	echo "  -p            Playful variant: keep device's Play Store instead of installing microG Companion"
	echo "  -P <apk>      Playful variant with given Play Store APK, for ROMs without Play Store (e.g. LineageOS)"
	exit "${1:-0}"
}

while getopts "hd:s:pP:" opt; do
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
		p) variant=playful ;;
		P)
			variant=playful
			playstore_apk="$OPTARG"
			[ -f "$playstore_apk" ] || { echo "[C] Play Store APK not found: $playstore_apk"; exit 1; }
			;;
		*) show_help 1 ;;
	esac
done

# Date based version, Magisk offers update when versionCode grows. Release script sets them for same day releases.
module_version="${MODULE_VERSION:-v$(date -u +%Y.%m.%d)}"
module_version_code="${MODULE_VERSION_CODE:-$(date -u +%Y%m%d)00}"
module_filename="noogle-microg${variant:+-$variant}${playstore_apk:+-playstore}-$module_version.zip"

echo "[P] Building module noogle-microg $module_version..."
start=$SECONDS
rm -rf "$module_dir"
mkdir -p "$module_dir"

for pkg in "${!apps[@]}"; do
	if [ "$variant" = playful ] && [ "$pkg" = com.android.vending ]; then
		[ -n "$playstore_apk" ] || continue
		apks=("$playstore_apk")
	else
		apks=("$apk_dir/$pkg"*.apk)
	fi
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

# Services Framework Proxy is only v1 signed, which some ROMs may reject. Re-sign it with a throwaway key, so nobody
# can sign updates for it (microG doesn't check its signature, Android accepts changed signatures of system apps).
gsf_apk="$module_dir/$destination_dir/priv-app/GoogleServicesFramework$suffix/GoogleServicesFramework$suffix.apk"
apksigner="$(command -v apksigner || ls "${ANDROID_HOME:-$HOME/Android/Sdk}"/build-tools/*/apksigner 2> /dev/null | sort -V | tail -1)"
if [ -n "$apksigner" ] && command -v keytool > /dev/null; then
	keystore="$(mktemp -u).p12"
	KEY_PASS="$(head -c 32 /dev/urandom | base64)" && export KEY_PASS
	keytool -genkeypair -keystore "$keystore" -storetype PKCS12 -storepass:env KEY_PASS -alias noogle \
		-keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Noogle" > /dev/null 2>&1
	"$apksigner" -J-enable-native-access=ALL-UNNAMED sign --ks "$keystore" --ks-pass env:KEY_PASS "$gsf_apk"
	rm -f "$keystore" "$gsf_apk.idsig"
	unset KEY_PASS
	echo "[I] Re-signed ${gsf_apk##*/} with throwaway key"
elif [ -n "$REQUIRE_SIGNING" ]; then
	echo "[C] apksigner (Android SDK build-tools) or keytool (JDK) not found, required for release"
	exit 1
else
	echo "[W] apksigner (Android SDK build-tools) or keytool (JDK) not found, ${gsf_apk##*/} keeps v1 signature only"
fi

cp -r "$src_dir/$module_dir"/* "$module_dir/"
mv "$module_dir/etc" "$module_dir/$destination_dir/"
printf '\nversion=%s\nversionCode=%s\n' "$module_version" "$module_version_code" >> "$module_dir/module.prop"

# Play Store configs are needed only when bundling it, ROMs with Play Store have their own
[ -n "$playstore_apk" ] || find "$module_dir/$destination_dir/etc" -name '*-playstore.xml' -delete
if [ "$variant" = playful ]; then
	sed -i 's/^name=.*/& Playful/; s/^description=.*/description=Replaces Google Services with microG, keeps Play Store/' "$module_dir/module.prop"
	if [ -n "$playstore_apk" ]; then
		# Play Store is replaced (stock one removed if present), but its own updates are kept
		sed -i 's/^keep_updates=.*/keep_updates="com.android.vending"/' "$module_dir/common.sh"
		# Released playful builds don't contain Play Store, updating to them would remove it
		sed -i '/^updateJson=/d' "$module_dir/module.prop"
	else
		sed -i 's/^packages=.*/packages="com.google.android.gms com.google.android.gsf"/' "$module_dir/common.sh"
		sed -i 's/update-microg.json/update-microg-playful.json/' "$module_dir/module.prop"
	fi
fi

gms_dir="$destination_dir/priv-app/GmsCore$suffix"
sed -i "1i gms_path=$gms_dir/GmsCore$suffix.apk" "$module_dir/customize.sh"
sed -i "1i gms_dir=$gms_dir" "$module_dir/customize.sh"

mkdir -p "$dist_dir"
rm -f "$dist_dir/$module_filename"
(cd "$module_dir" && zip -q -r "../$dist_dir/$module_filename" . -x '*.gitkeep')

echo "[P+][$((SECONDS - start))s] Module built: $dist_dir/$module_filename"
