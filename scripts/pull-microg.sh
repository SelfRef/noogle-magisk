#!/usr/bin/env bash
# Pulls latest microG APKs from the official F-Droid repo and verifies their checksums.

set -e

repo_url=https://microg.org/fdroid/repo
apk_dir=apk
packages=(com.google.android.gms com.android.vending com.google.android.gsf)
attempts=5
wait_time=10
lock_only=false

show_help() {
	echo "Usage: $0 [options]"
	echo "Pulls latest microG APKs into $apk_dir/, skips ones already pulled and verified."
	echo "Options:"
	echo "  -h          Show this help message"
	echo "  -l          Only update microg.lock, don't pull APKs"
	exit "${1:-0}"
}

while getopts "hl" opt; do
	case $opt in
		h) show_help ;;
		l) lock_only=true ;;
		*) show_help 1 ;;
	esac
done

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# $1: url, $2: sha256, $3: destination
# microg.org rate limits downloads, failed or rate limited ones fail the checksum and are retried with growing delay
download() {
	for attempt in $(seq $attempts); do
		echo "[P] Pulling ${3##*/} (attempt $attempt/$attempts)..."
		start=$SECONDS
		if curl -fL --progress-bar "$1" -o "$tmp" && sha256sum -c --status <<< "$2  $tmp"; then
			chmod 644 "$tmp"
			mv "$tmp" "$3"
			echo "[P+][$((SECONDS - start))s] Pulled and verified ${3##*/}"
			return
		fi
		echo "[P!][$((SECONDS - start))s] Download failed or checksum mismatch, probably rate limited"
		[ "$attempt" -lt $attempts ] || break
		echo "[I] Retrying in $((wait_time * attempt))s"
		sleep $((wait_time * attempt))
	done
	echo "[C] Failed to pull ${3##*/}. Try again later or download manually from https://microg.org/download.html"
	exit 1
}

mkdir -p "$apk_dir"

echo "[P] Fetching repo index..."
if ! curl -fsSL --retry $attempts --retry-delay $wait_time --retry-all-errors "$repo_url/index-v2.json" -o "$tmp"; then
	echo "[P!] Could not fetch repo index"
	exit 1
fi
index="$(cat "$tmp")"
echo "[P+] Repo index fetched"

lock=""
for pkg in "${packages[@]}"; do
	latest="$(jq --arg p "$pkg" '.packages[$p].versions // {} | to_entries
		| max_by(.value.manifest.versionCode) // empty | .value' <<< "$index")"
	read -r name sha256 version < <(jq -r '"\(.file.name) \(.file.sha256) \(.manifest.versionName)"' <<< "$latest")
	if [ -z "$name" ]; then
		echo "[C] $pkg not found in repo index"
		exit 1
	fi
	echo "[I] $pkg: latest $version"

	if [ "$lock_only" = false ]; then
		apk="$apk_dir/${name#/}"
		if [ -f "$apk" ] && sha256sum -c --status <<< "$sha256  $apk"; then
			echo "[I] Already pulled and verified"
		else
			download "$repo_url$name" "$sha256" "$apk"
		fi
		# Build requires exactly one APK per package
		find "$apk_dir" -name "$pkg-*.apk" ! -path "$apk" -delete
	fi
	# Byte order sort, locale order differs between machines and would show moved lines as new permissions
	lock="$lock$pkg version $version
$(jq -r --arg p "$pkg" '"\($p) permission \(.manifest.usesPermission[]?.name)"' <<< "$latest" | LC_ALL=C sort -u)
"
done

# Release script checks it for new microG versions and permissions (new privileged ones need allowlisting)
printf %s "$lock" > microg.lock

[ "$lock_only" = true ] && echo "[I] microg.lock updated" || echo "[I] All microG APKs are ready!"
