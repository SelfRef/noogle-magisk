#!/usr/bin/env bash
# Pulls Fossify apps for Noogle Unbundle Fossify from F-Droid. Takes versions F-Droid suggests and checks they are
# signed by Fossify, so F-Droid (and Fossify's GitHub releases, same reproducible builds) can update them.

set -e

apk_dir=apk/fossify
api_url=https://f-droid.org/api/v1/packages
repo_url=https://f-droid.org/repo
# Replacements for apps Unbundle Hard removes
apps=(home phone messages keyboard contacts gallery math clock camera filemanager calendar notes voicerecorder)
# Certificate SHA-256 digest of Fossify's signing key
fossify_cert=affdb124d3f4720c2f98dbca9eacba0514fba4306e20a2786c861c3c0d6ff292
attempts=5

show_help() {
	echo "Usage: $0 [options]"
	echo "Pulls Fossify apps into $apk_dir/, skips ones already pulled and verified."
	echo "Options:"
	echo "  -h          Show this help message"
	exit "${1:-0}"
}

while getopts "h" opt; do
	case $opt in
		h) show_help ;;
		*) show_help 1 ;;
	esac
done

apksigner="$(command -v apksigner || ls "${ANDROID_HOME:-$HOME/Android/Sdk}"/build-tools/*/apksigner 2> /dev/null | sort -V | tail -1)"
[ -n "$apksigner" ] || { echo "[C] apksigner (Android SDK build-tools) not found"; exit 1; }

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
mkdir -p "$apk_dir"

# $1: APK, succeeds when it's signed by Fossify
verify() {
	"$apksigner" -J-enable-native-access=ALL-UNNAMED verify --print-certs "$1" 2> /dev/null |
		grep -v '^Source Stamp' | grep -m 1 'certificate SHA-256 digest' | grep -q "$fossify_cert$"
}

for app in "${apps[@]}"; do
	pkg=org.fossify.$app
	version_code="$(curl -fsSL --retry $attempts --retry-all-errors "$api_url/$pkg" | jq -r .suggestedVersionCode)"
	[ -n "$version_code" ] && [ "$version_code" != null ] || { echo "[C] $pkg not found on F-Droid"; exit 1; }
	apk="$apk_dir/${pkg}_$version_code.apk"
	if [ -f "$apk" ] && verify "$apk"; then
		echo "[I] $pkg $version_code: already pulled and verified"
	else
		echo "[P] Pulling $pkg $version_code..."
		start=$SECONDS
		curl -fL --progress-bar --retry $attempts --retry-all-errors "$repo_url/${pkg}_$version_code.apk" -o "$tmp"
		if ! verify "$tmp"; then
			echo "[P!] ${apk##*/} isn't signed by Fossify"
			exit 1
		fi
		chmod 644 "$tmp"
		mv "$tmp" "$apk"
		echo "[P+][$((SECONDS - start))s] Pulled and verified ${apk##*/}"
	fi
	# Build requires exactly one APK per app
	find "$apk_dir" -name "${pkg}_*.apk" ! -path "$apk" -delete
done
echo "[I] All Fossify apps are ready!"
