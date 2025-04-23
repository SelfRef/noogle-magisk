#!/bin/sh

repo_url=https://microg.org/fdroid/repo
apk_dir="$(git rev-parse --show-toplevel)/apk"
wait_time=10

mkdir -p "$apk_dir"

curl -fs "$repo_url"/index-v2.json | jq -r '
  .packages[] as $pkg | $pkg.versions
  | to_entries | sort_by(.value.added) | last.value | [ 
    $pkg.metadata.name["en-US"],
    .file.name,
    .file.sha256,
    .manifest.versionName 
  ] | @tsv
' | while IFS=$(printf '\t') read -r name apk sha256 ver; do
	path="$apk_dir$apk"
	echo "[I] Latest $name version: $ver"
	[ -f "$path" ] && echo "$sha256  $path" | sha256sum -c && {
		echo
		continue
	}

	[ "$downloaded" ] && {
		echo "[I] Waiting for $wait_time seconds to avoid rate limiting..."
		sleep "$wait_time"
	}

	rm -f "${path%-*}"* # Remove old versions

	echo "[I] Downloading $name..."
	until curl -sfL "$repo_url$apk" -o "$path"; do
		echo "[I] Failed to download $name; retrying in $wait_time seconds..."
		sleep "$wait_time"
	done
	downloaded=1

	echo "$sha256  $path" | sha256sum -c || {
		echo "[E] Download checksum verification for $path failed! please re-run the script."
		exit 1
	}
	echo
done

echo "[I] All microG APKs are ready!"