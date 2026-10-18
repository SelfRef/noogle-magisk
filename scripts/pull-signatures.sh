#!/usr/bin/env bash
# Extracts signing blocks of Google's Play Services and Play Store APKs for Catfish build (see build-noogle-microg.sh).

set -e

signatures_dir=signatures
packages=(com.google.android.gms com.android.vending)
# Certificate SHA-256 digests of Google's signers: Play Services (rotated key) and Play Store (original key)
google_certs="7ce83c1b71f3d572fed04c8d40c5cb10ff75e6d87d9df6fbd53f0468c2905053
f0fd6c5b410f25cb25c3b53346c8972fae30f8ee7411df910480ad6b2d60db83"

show_help() {
	echo "Usage: $0 [options] [<Play Services APK> <Play Store APK>]"
	echo "Extracts signing blocks into $signatures_dir/. Without APKs given, pulls them through ADB from a device"
	echo "with stock Google apps (Noogle microG disabled)."
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
shift $((OPTIND - 1))
[ $# -eq 0 ] || [ $# -eq 2 ] || show_help 1

apksigner="$(command -v apksigner || ls "${ANDROID_HOME:-$HOME/Android/Sdk}"/build-tools/*/apksigner 2> /dev/null | sort -V | tail -1)"
[ -n "$apksigner" ] || { echo "[C] apksigner (Android SDK build-tools) not found"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$signatures_dir"

apks=("$@")
for i in "${!packages[@]}"; do
	pkg=${packages[$i]}
	apk=${apks[$i]}
	if [ -z "$apk" ]; then
		apk="$tmp/$pkg.apk"
		echo "[P] Pulling $pkg from device..."
		path="$(adb shell pm path "$pkg" | head -n 1 | tr -d '\r')"
		[ -n "$path" ] || { echo "[P!] $pkg not installed on device"; exit 1; }
		adb pull -q "${path#package:}" "$apk"
		echo "[P+] Pulled ${path#package:}"
	fi

	# Only untouched Google APKs verify with Google's certificate, microG ones (also Catfish) don't
	cert="$("$apksigner" -J-enable-native-access=ALL-UNNAMED verify --print-certs "$apk" 2> /dev/null |
		grep -v '^Source Stamp' | grep -m 1 'certificate SHA-256 digest' | awk '{print $NF}')" || true
	if ! grep -qx "${cert:-none}" <<< "$google_certs"; then
		echo "[C] ${apk##*/} is not Google's $pkg (signature doesn't verify or isn't Google's), disable Noogle microG first"
		exit 1
	fi

	size=$(stat -c %s "$apk")
	# End of central directory is last 22 bytes (no zip comment), central directory offset is at its byte 16
	cd_offset=$(od -An -tu4 --endian=little -j $((size - 6)) -N 4 "$apk" | tr -d ' ')
	# Signing block ends with its size (8 bytes) and magic right before central directory, size excludes first 8 bytes
	if [ "$(tail -c +$((cd_offset - 15)) "$apk" | head -c 16)" != "APK Sig Block 42" ]; then
		echo "[C] ${apk##*/}: no signing block found"
		exit 1
	fi
	block_size=$(($(od -An -tu8 --endian=little -j $((cd_offset - 24)) -N 8 "$apk" | tr -d ' ') + 8))
	tail -c +$((cd_offset - block_size + 1)) "$apk" | head -c "$block_size" > "$signatures_dir/$pkg"
	echo "[I] $pkg: extracted signing block ($block_size bytes, certificate $cert)"
done
