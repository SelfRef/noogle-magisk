#!/usr/bin/env bash
# Pulls latest microG APKs from the official F-Droid repo and verifies their checksums.

set -e

repo_url=https://microg.org/fdroid/repo
apk_dir=apk
packages=(com.google.android.gms com.android.vending com.google.android.gsf)
attempts=5
wait_time=10

show_help() {
	echo "Usage: $0 [options]"
	echo "Pulls latest microG APKs into $apk_dir/, skips ones already pulled and verified."
	echo "Options:"
	echo "  -h          Show this help message"
	exit 0
}

while getopts "h" opt; do
	case $opt in
		*) show_help ;;
	esac
done

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# $1: url, $2: sha256, $3: destination
# microg.org rate limits downloads, failed or rate limited ones fail the checksum and are retried with growing delay
download() {
	for attempt in $(seq $attempts); do
		echo "[P] Pulling ${3##*/} (attempt $attempt/$attempts)..."
		if curl -fL --progress-bar "$1" -o "$tmp" && sha256sum -c --status <<< "$2  $tmp"; then
			chmod 644 "$tmp"
			mv "$tmp" "$3"
			return
		fi
		[ "$attempt" -lt $attempts ] || break
		echo "[W] Download failed or checksum mismatch, probably rate limited. Retrying in $((wait_time * attempt))s..."
		sleep $((wait_time * attempt))
	done
	echo "[E] Failed to pull ${3##*/}. Try again later or download manually from https://microg.org/download.html"
	exit 1
}

mkdir -p "$apk_dir"

echo "[P] Fetching repo index..."
curl -fsSL --retry $attempts --retry-delay $wait_time --retry-all-errors "$repo_url/index-v2.json" -o "$tmp"
index="$(cat "$tmp")"

for pkg in "${packages[@]}"; do
	read -r name sha256 version < <(jq -r --arg p "$pkg" '.packages[$p].versions // {} | to_entries
		| max_by(.value.manifest.versionCode) // empty | .value
		| "\(.file.name) \(.file.sha256) \(.manifest.versionName)"' <<< "$index")
	if [ -z "$name" ]; then
		echo "[E] $pkg not found in repo index"
		exit 1
	fi
	echo "[I] $pkg: latest $version"

	apk="$apk_dir/${name#/}"
	if [ -f "$apk" ] && sha256sum -c --status <<< "$sha256  $apk"; then
		echo "[I] Already pulled and verified, skipping"
	else
		download "$repo_url$name" "$sha256" "$apk"
	fi
	# Build requires exactly one APK per package
	find "$apk_dir" -name "$pkg-*.apk" ! -path "$apk" -delete
done

echo "[I] All microG APKs are ready!"
