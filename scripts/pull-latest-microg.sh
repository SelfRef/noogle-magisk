#!/bin/sh

repo_url=https://microg.org/fdroid/repo
apk_dir=apk
wait_time=5

mkdir -p "$apk_dir"

echo "[P] Pulling latest microG APKs..."
repo_index=$(curl -s $repo_url/index-v2.json)
pulled_apk=""

latest_gms=$(echo "$repo_index" | jq -r '.packages["com.google.android.gms"].versions | to_entries | sort_by(.value.added) | last.value.file.name')
echo "[I] Latest GmsCore version: $latest_gms"

gms_apk="$apk_dir$latest_gms"
if [ -f "$gms_apk" ] && [ $(stat -c%s "$gms_apk") -gt 1000 ]; then
	echo "[I] microG Services already pulled, skipping..."
else
	rm -f "$apk_dir/com.google.android.gms*"
	echo "[P] Pulling latest microG Services..."
	echo "[I] Waiting for $wait_time seconds to avoid rate limiting..."
	sleep $wait_time # To avoid rate limiting

	curl -L --progress-bar $repo_url$latest_gms -o "$gms_apk"
	if [ $(stat -c%s "$gms_apk") -lt 1000 ]; then
		rm -f "$gms_apk"
		echo "[E] Failed to pull latest microG Services, probbaly because requests are rate limited. Try again in a moment."
		exit 1
	else
		pulled_apk=1
	fi
fi

latest_vending=$(echo "$repo_index" | jq -r '.packages["com.android.vending"].versions | to_entries | sort_by(.value.added) | last.value.file.name')
echo "[I] Latest Phonesky version: $latest_vending"

vending_apk="$apk_dir$latest_vending"
if [ -f "$vending_apk" ] && [ $(stat -c%s "$vending_apk") -gt 1000 ]; then
	echo "[I] microG Companion already pulled, skipping..."
else
	rm -f "$apk_dir/com.android.vending*"
	echo "[P] Pulling latest microG Companion..."
	if [ $pulled_apk ]; then
	echo "[I] Waiting for $wait_time seconds to avoid rate limiting..."
		sleep $wait_time # To avoid rate limiting
	fi

	curl -L --progress-bar $repo_url$latest_vending -o "$vending_apk"
	if [ $(stat -c%s "$vending_apk") -lt 1000 ]; then
		rm -f "$vending_apk"
		echo "[E] Failed to pull latest microG Companion, probbaly because requests are rate limited. Try again in a moment."
		exit 1
	else
		pulled_apk=1
	fi
fi

latest_gsf=$(echo "$repo_index" | jq -r '.packages["com.google.android.gsf"].versions | to_entries | sort_by(.value.added) | last.value.file.name')
echo "[I] Latest GoogleServicesFramework version: $latest_gsf"

gsf_apk="$apk_dir$latest_gsf"
if [ -f "$gsf_apk" ] && [ $(stat -c%s "$gsf_apk") -gt 1000 ]; then
	echo "[I] microG Companion already pulled, skipping..."
else
	rm -f "$apk_dir/com.google.android.gsf*"
	echo "[P] Pulling latest microG Services Framework Proxy..."
	if [ $pulled_apk ]; then
	echo "[I] Waiting for $wait_time seconds to avoid rate limiting..."
		sleep $wait_time # To avoid rate limiting
	fi

	curl -L --progress-bar $repo_url$latest_gsf -o "$gsf_apk"
	if [ $(stat -c%s "$gsf_apk") -lt 1000 ]; then
		rm -f "$gsf_apk"
		echo "[E] Failed to pull latest microG Services Framework Proxy, probbaly because requests are rate limited. Try again in a moment."
		exit 1
	fi
fi

echo "[I] All microG APKs are ready!"