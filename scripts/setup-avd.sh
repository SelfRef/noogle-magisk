#!/usr/bin/env bash
# Sets up a Magisk-rooted Android emulator (Google Play image) for testing modules. Arch Linux only.

set -e

android_version=15
avd_name=""
action=setup
headless=false
port=5554
snapshot=clean
sdk_dir="${ANDROID_HOME:-$HOME/Android/Sdk}"
rootavd_dir="${XDG_CACHE_HOME:-$HOME/.cache}/rootAVD"
log_dir=logs

show_help() {
	echo "Usage: $0 [options]"
	echo "Sets up, roots (Magisk via rootAVD) and starts the emulator. Safe to re-run."
	echo "Options:"
	echo "  -h            Show this help message"
	echo "  -v <version>  Android version [11|12|12L|13|14|15|16] (default: 15)"
	echo "  -n <name>     AVD name (default: noogle-<version>)"
	echo "  -H            Run headless (no window)"
	echo "  -S            Save running emulator state as '$snapshot' snapshot"
	echo "  -r            Reset to '$snapshot' snapshot (wipes data if there is none)"
	echo "  -R            Recreate: delete AVD, unroot image and set everything up again"
	echo "  -k            Kill running emulator"
	echo "After first setup save clean state with -S, so -r can restore it."
	exit 0
}

while getopts "hv:n:HSrRk" opt; do
	case $opt in
		h) show_help ;;
		v) android_version="$OPTARG" ;;
		n) avd_name="$OPTARG" ;;
		H) headless=true ;;
		S) action=save ;;
		r) action=reset ;;
		R) action=recreate ;;
		k) action=kill ;;
		*) show_help ;;
	esac
done

case $android_version in
	11) api=30 ;;
	12) api=31 ;;
	12L|12l) api=32 ;;
	13) api=33 ;;
	14) api=34 ;;
	15) api=35 ;;
	16) api=36 ;;
	*)
		echo "[E] Unsupported Android version: $android_version"
		show_help
		;;
esac

avd_name="${avd_name:-noogle-$android_version}"
image_path="system-images/android-$api/google_apis_playstore/x86_64"
image_pkg="$(echo "$image_path" | tr '/' ';')"
ramdisk="$sdk_dir/$image_path/ramdisk.img"
avd_dir="${ANDROID_AVD_HOME:-$HOME/.android/avd}/$avd_name.avd"

export ANDROID_HOME="$sdk_dir"
export ANDROID_SERIAL="emulator-$port"
# adb comes from android-tools, mixing it with SDK platform-tools adb restarts the server and drops devices
export PATH="$sdk_dir/cmdline-tools/latest/bin:$sdk_dir/emulator:$PATH"

is_running() {
	pgrep -f -- "-avd $avd_name( |$)" > /dev/null
}

kill_emulator() {
	is_running || return 0
	echo "[P] Stopping emulator $avd_name..."
	adb emu kill > /dev/null 2>&1 || true
	while is_running; do sleep 1; done
}

# $@: extra emulator args
start_emulator() {
	if is_running; then
		echo "[I] Emulator $avd_name already running"
	else
		echo "[P] Starting emulator $avd_name (log: $log_dir/emulator-$avd_name.log)..."
		mkdir -p "$log_dir"
		args=(-avd "$avd_name" -port "$port" -no-snapshot-save "$@")
		[ "$headless" = true ] && args+=(-no-window)
		nohup emulator "${args[@]}" \
			> "$log_dir/emulator-$avd_name.log" 2>&1 &
	fi
	echo "[P] Waiting for boot..."
	until [ "$(adb shell getprop sys.boot_completed 2> /dev/null | tr -d '\r')" = 1 ]; do
		is_running || { echo "[E] Emulator exited, check $log_dir/emulator-$avd_name.log"; exit 1; }
		sleep 2
	done
	echo "[I] Booted ($ANDROID_SERIAL)"
}

install_deps() {
	if [ ! -w /dev/kvm ]; then
		echo "[E] /dev/kvm not accessible. Enable virtualization or run: sudo usermod -aG kvm $USER"
		exit 1
	fi

	deps=(unzip git curl android-tools)
	command -v java > /dev/null || deps+=(jre-openjdk-headless)
	mapfile -t missing < <(pacman -T "${deps[@]}")
	if [ ${#missing[@]} -gt 0 ]; then
		echo "[P] Installing packages: ${missing[*]}"
		sudo pacman -S --needed "${missing[@]}"
	fi

	if [ ! -x "$sdk_dir/cmdline-tools/latest/bin/sdkmanager" ]; then
		echo "[P] Installing Android cmdline-tools to $sdk_dir..."
		zip_name="$(curl -fsSL https://dl.google.com/android/repository/repository2-3.xml \
			| grep -o 'commandlinetools-linux-[0-9]*_latest.zip' | sort -V | tail -n 1)"
		tmp_dir="$(mktemp -d)"
		curl -fL --progress-bar "https://dl.google.com/android/repository/$zip_name" -o "$tmp_dir/tools.zip"
		unzip -q "$tmp_dir/tools.zip" -d "$tmp_dir"
		mkdir -p "$sdk_dir/cmdline-tools"
		rm -rf "$sdk_dir/cmdline-tools/latest"
		mv "$tmp_dir/cmdline-tools" "$sdk_dir/cmdline-tools/latest"
		rm -rf "$tmp_dir"
	fi

	if [ ! -f "$ramdisk" ] || [ ! -x "$sdk_dir/emulator/emulator" ]; then
		echo "[P] Installing emulator and $image_pkg..."
		yes | sdkmanager --licenses > /dev/null
		sdkmanager --install emulator "$image_pkg"
	fi

	if [ -d "$rootavd_dir" ]; then
		# Reset first, root_image overwrites the bundled Magisk.zip
		git -C "$rootavd_dir" reset -q --hard && git -C "$rootavd_dir" pull -q || echo "[W] Could not update rootAVD, using existing copy"
	else
		echo "[P] Cloning rootAVD..."
		git clone -q --depth 1 https://gitlab.com/newbit/rootAVD.git "$rootavd_dir"
	fi
}

create_avd() {
	if emulator -list-avds | grep -qx "$avd_name"; then
		echo "[I] AVD $avd_name already exists"
		return
	fi
	echo "[P] Creating AVD $avd_name (Android $android_version, API $api)..."
	echo no | avdmanager create avd -n "$avd_name" -k "$image_pkg" -d pixel_6
}

# rootAVD patches the shared system image ramdisk and keeps the stock one as ramdisk.img.backup
root_image() {
	if [ -f "$ramdisk.backup" ]; then
		echo "[I] Image already rooted"
		return
	fi
	# rootAVD falls back to its bundled (old) Magisk when the emulator has no internet, so provide the latest one
	magisk_url="$(curl -fsSL https://api.github.com/repos/topjohnwu/Magisk/releases/latest \
		| grep -o 'https://[^"]*/Magisk-v[^"]*\.apk' | head -n 1)"
	echo "[P] Downloading ${magisk_url##*/}..."
	curl -fL --progress-bar "$magisk_url" -o "$rootavd_dir/Magisk.zip"

	start_emulator
	echo "[P] Rooting image with rootAVD..."
	# stdin from /dev/null makes rootAVD take the default menu choices without prompting
	(cd "$rootavd_dir" && bash rootAVD.sh "$image_path/ramdisk.img" < /dev/null)
	echo "[P] Waiting for emulator to shut down..."
	while is_running; do sleep 1; done
	# rootAVD ignores failed pulls, leaving no ramdisk at all
	if [ ! -f "$ramdisk" ]; then
		mv "$ramdisk.backup" "$ramdisk"
		echo "[E] rootAVD failed to pull patched ramdisk, stock one restored. Re-run to try again."
		exit 1
	fi
	rooted_now=true
}

# Magisk app completes its environment on first launch and reboots
finish_magisk_setup() {
	echo "[P] Launching Magisk app to finish setup..."
	boot_id="$(adb shell cat /proc/sys/kernel/random/boot_id)"
	adb shell pm grant com.topjohnwu.magisk android.permission.POST_NOTIFICATIONS
	adb shell monkey -p com.topjohnwu.magisk -c android.intent.category.LAUNCHER 1 > /dev/null
	echo "[P] Waiting for Magisk to reboot..."
	for _ in $(seq 60); do
		[ "$(adb shell cat /proc/sys/kernel/random/boot_id 2> /dev/null)" != "$boot_id" ] && break
		sleep 2
	done
	start_emulator
	if [ "$(adb shell su -c id -u 2> /dev/null | tr -d '\r')" = 0 ]; then
		echo "[I] Root works. Save clean state: $0 -v $android_version -S"
	else
		echo "[W] No root in adb shell. Open Magisk app, finish setup and grant Shell root, then save clean state: $0 -v $android_version -S"
	fi
}

case $action in
	kill)
		kill_emulator
		;;
	save)
		is_running || { echo "[E] Emulator $avd_name is not running"; exit 1; }
		echo "[P] Saving snapshot '$snapshot'..."
		adb emu avd snapshot save "$snapshot"
		;;
	reset)
		kill_emulator
		if [ -d "$avd_dir/snapshots/$snapshot" ]; then
			echo "[P] Restoring snapshot '$snapshot'..."
			start_emulator -snapshot "$snapshot"
		else
			echo "[W] No '$snapshot' snapshot, wiping data instead (Magisk app and root grants will be gone)"
			start_emulator -wipe-data
		fi
		;;
	recreate)
		kill_emulator
		echo "[P] Deleting AVD $avd_name and unrooting image..."
		avdmanager delete avd -n "$avd_name" > /dev/null 2>&1 || true
		if [ -f "$ramdisk.backup" ]; then
			mv "$ramdisk.backup" "$ramdisk"
		fi
		;&
	setup)
		install_deps
		create_avd
		root_image
		start_emulator -no-snapshot-load
		if [ "$rooted_now" = true ]; then
			finish_magisk_setup
		fi
		;;
esac
