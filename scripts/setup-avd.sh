#!/usr/bin/env bash
# Sets up a Magisk-rooted Android emulator (Google Play image) for testing modules. Arch Linux only.
#
# Workflow: run without options (fully unattended, ~3 min first time), save clean state with -S,
# test with install-noogle.sh, go back with -r. With a real device connected too: export ANDROID_SERIAL=emulator-5554
# Logs: logs/emulator-<avd>.log, logs/rootavd.log. SDK in ~/Android/Sdk, rootAVD in ~/.cache/rootAVD.
#
# Notes:
# - Google Play image is a user build: no adb root, Play Services preinstalled like on stock phones.
# - Only one adb version may exist, emulator runs SDK platform-tools adb on its own. Mismatch restarts adb server,
#   devices go offline mid-transfer and rootAVD silently ends up without patched ramdisk.
# - rootAVD patches the system image shared by all AVDs of that Android version, not the AVD itself.
# - Magisk su prompt is hidden from uiautomator, it can't be tapped. Other Magisk UI can (see tap_node).
# - UI can be inspected with: adb exec-out uiautomator dump /dev/tty, adb exec-out screencap -p > screen.png
# - In Magisk DB policies, shell is uid 2000: adb shell "su -c \"magisk --sqlite 'SELECT * FROM policies'\""

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

# $1: exit code
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
	exit "${1:-0}"
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
		*) show_help 1 ;;
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
		echo "[C] Unsupported Android version: $android_version"
		show_help 1
		;;
esac

avd_name="${avd_name:-noogle-$android_version}"
image_path="system-images/android-$api/google_apis_playstore/x86_64"
image_pkg="$(echo "$image_path" | tr '/' ';')"
ramdisk="$sdk_dir/$image_path/ramdisk.img"
avd_dir="${ANDROID_AVD_HOME:-$HOME/.android/avd}/$avd_name.avd"

export ANDROID_HOME="$sdk_dir"
export ANDROID_SERIAL="emulator-$port"
export PATH="$sdk_dir/cmdline-tools/latest/bin:$sdk_dir/emulator:$PATH"

is_running() {
	pgrep -f -- "-avd $avd_name( |$)" > /dev/null
}

kill_emulator() {
	is_running || return 0
	echo "[P] Stopping emulator $avd_name..."
	start=$SECONDS
	adb emu kill > /dev/null 2>&1 || true
	while is_running; do sleep 1; done
	echo "[P+][$((SECONDS - start))s] Emulator stopped"
}

# Starts emulator if not running and waits for boot
# $@: extra emulator args
start_emulator() {
	start=$SECONDS
	if is_running; then
		echo "[P] Waiting for emulator $avd_name to boot..."
	else
		echo "[P] Starting emulator $avd_name (log: $log_dir/emulator-$avd_name.log)..."
		mkdir -p "$log_dir"
		args=(-avd "$avd_name" -port "$port" -no-snapshot-save "$@")
		[ "$headless" = true ] && args+=(-no-window)
		nohup emulator "${args[@]}" \
			> "$log_dir/emulator-$avd_name.log" 2>&1 &
	fi
	until [ "$(adb shell getprop sys.boot_completed 2> /dev/null | tr -d '\r')" = 1 ]; do
		is_running || { echo "[P!] Emulator exited, check $log_dir/emulator-$avd_name.log"; exit 1; }
		sleep 2
	done
	echo "[P+][$((SECONDS - start))s] Emulator booted ($ANDROID_SERIAL)"
}

install_deps() {
	if [ ! -w /dev/kvm ]; then
		echo "[C] /dev/kvm not accessible. Enable virtualization or run: sudo usermod -aG kvm $USER"
		exit 1
	fi

	deps=(unzip git curl android-tools)
	command -v java > /dev/null || deps+=(jre-openjdk-headless)
	mapfile -t missing < <(pacman -T "${deps[@]}")
	if [ ${#missing[@]} -gt 0 ]; then
		echo "[P] Installing packages: ${missing[*]}..."
		sudo pacman -S --needed "${missing[@]}"
		echo "[P+] Packages installed"
	fi

	if [ ! -x "$sdk_dir/cmdline-tools/latest/bin/sdkmanager" ]; then
		echo "[P] Installing Android cmdline-tools to $sdk_dir..."
		start=$SECONDS
		zip_name="$(curl -fsSL https://dl.google.com/android/repository/repository2-3.xml \
			| grep -o 'commandlinetools-linux-[0-9]*_latest.zip' | sort -V | tail -n 1)"
		tmp_dir="$(mktemp -d)"
		curl -fL --progress-bar "https://dl.google.com/android/repository/$zip_name" -o "$tmp_dir/tools.zip"
		unzip -q "$tmp_dir/tools.zip" -d "$tmp_dir"
		mkdir -p "$sdk_dir/cmdline-tools"
		rm -rf "$sdk_dir/cmdline-tools/latest"
		mv "$tmp_dir/cmdline-tools" "$sdk_dir/cmdline-tools/latest"
		rm -rf "$tmp_dir"
		echo "[P+][$((SECONDS - start))s] Installed $zip_name"
	fi

	if [ ! -f "$ramdisk" ] || [ ! -x "$sdk_dir/emulator/emulator" ]; then
		echo "[P] Installing emulator and $image_pkg..."
		start=$SECONDS
		yes | sdkmanager --licenses > /dev/null
		sdkmanager --install emulator "$image_pkg"
		echo "[P+][$((SECONDS - start))s] Emulator and system image installed"
	fi

	# Emulator requires SDK platform-tools and runs its adb too, two adb versions keep restarting the server and drop devices
	if [ "$(readlink "$sdk_dir/platform-tools/adb")" != /usr/bin/adb ]; then
		echo "[P] Replacing SDK platform-tools with android-tools adb..."
		rm -rf "$sdk_dir/platform-tools"
		mkdir -p "$sdk_dir/platform-tools"
		ln -s /usr/bin/adb "$sdk_dir/platform-tools/adb"
		echo "[P+] SDK platform-tools adb linked to /usr/bin/adb"
	fi

	if [ -d "$rootavd_dir" ]; then
		echo "[P] Updating rootAVD..."
		# Reset first, root_image overwrites the bundled Magisk.zip
		if git -C "$rootavd_dir" reset -q --hard && git -C "$rootavd_dir" pull -q; then
			echo "[P+] rootAVD updated"
		else
			echo "[P!] Could not update rootAVD, using existing copy"
		fi
	else
		echo "[P] Cloning rootAVD..."
		git clone -q --depth 1 https://gitlab.com/newbit/rootAVD.git "$rootavd_dir"
		echo "[P+] rootAVD cloned"
	fi
}

create_avd() {
	if emulator -list-avds | grep -qx "$avd_name"; then
		echo "[I] AVD $avd_name already exists"
		return
	fi
	echo "[P] Creating AVD $avd_name (Android $android_version, API $api)..."
	echo no | avdmanager create avd -n "$avd_name" -k "$image_pkg" -d pixel_6
	echo "[P+] AVD created"
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
	start=$SECONDS
	curl -fL --progress-bar "$magisk_url" -o "$rootavd_dir/Magisk.zip"
	echo "[P+][$((SECONDS - start))s] Downloaded ${magisk_url##*/}"

	start_emulator
	echo "[P] Rooting image with rootAVD (log: $log_dir/rootavd.log)..."
	start=$SECONDS
	# stdin from /dev/null makes rootAVD take the default menu choices without prompting
	(cd "$rootavd_dir" && bash rootAVD.sh "$image_path/ramdisk.img" < /dev/null) > "$log_dir/rootavd.log" 2>&1
	# rootAVD shuts the emulator down when done
	while is_running; do sleep 1; done
	# rootAVD ignores failed pulls, leaving no ramdisk at all
	if [ ! -f "$ramdisk" ]; then
		mv "$ramdisk.backup" "$ramdisk"
		echo "[P!] rootAVD failed to pull patched ramdisk, stock one restored. Check $log_dir/rootavd.log and re-run."
		exit 1
	fi
	echo "[P+][$((SECONDS - start))s] Image rooted"
	rooted_now=true
}

# Taps first UI node matching regex once it shows up on screen
# $1: regex for node attributes (case insensitive), $2: timeout in seconds
tap_node() {
	end=$((SECONDS + $2))
	while [ $SECONDS -lt "$end" ]; do
		# Last 4 numbers of node are its bounds: [x1,y1][x2,y2]
		read -r x1 y1 x2 y2 <<< "$(adb exec-out uiautomator dump /dev/tty 2> /dev/null \
			| grep -oE '<node [^>]*>' | grep -iE "$1" | head -n 1 | grep -oE '[0-9]+' | tail -n 4 | tr '\n' ' ')"
		if [ -n "$y2" ]; then
			adb shell input tap $(((x1 + x2) / 2)) $(((y1 + y2) / 2))
			return 0
		fi
		sleep 1
	done
	return 1
}

# Launching right after boot doesn't always bring the app to front, so check focus and retry
open_magisk() {
	for _ in $(seq 10); do
		adb shell am start -W -n com.topjohnwu.magisk/.ui.MainActivity > /dev/null 2>&1 || true
		adb shell dumpsys window | grep -q 'mCurrentFocus=.*com.topjohnwu.magisk' && return 0
		sleep 2
	done
	return 1
}

# Magisk app asks for additional setup on first launch and reboots after it
magisk_additional_setup() {
	adb shell command -v su > /dev/null 2>&1 && return 0
	echo "[P] Running Magisk additional setup..."
	start=$SECONDS
	boot_id="$(adb shell cat /proc/sys/kernel/random/boot_id)"
	adb shell pm grant com.topjohnwu.magisk android.permission.POST_NOTIFICATIONS
	open_magisk
	if ! tap_node 'text="OK"' 60; then
		echo "[P!] Additional setup dialog didn't show up"
		return 0
	fi
	# adb returns nothing while device goes down, only new boot id means reboot happened
	for _ in $(seq 60); do
		new_boot_id="$(adb shell cat /proc/sys/kernel/random/boot_id 2> /dev/null || true)"
		[ -n "$new_boot_id" ] && [ "$new_boot_id" != "$boot_id" ] && break
		sleep 2
	done
	echo "[P+][$((SECONDS - start))s] Additional setup done, rebooted"
	start_emulator
}

# adb shell su prompts in Magisk app, which is hidden from uiautomator so it can't be granted there
# Unanswered prompt saves a deny for Shell instead, which can be flipped in Superuser tab
grant_shell_root() {
	echo "[P] Granting root to adb shell..."
	grant_start=$SECONDS
	su_out="$(mktemp)"
	# Right after boot su can be rejected before prompting, so retry
	for _ in 1 2 3; do
		# Returns at once when already granted, otherwise waits for prompt to time out
		adb shell su -c id -u > "$su_out" 2> /dev/null || true
		[ "$(tr -d '\r' < "$su_out")" = 0 ] && break
		open_magisk
		tap_node 'content-desc="Superuser"' 30 && tap_node 'checkable="true" checked="false"' 10 || true
		adb shell input keyevent HOME
		adb shell su -c id -u > "$su_out" 2> /dev/null || true
		[ "$(tr -d '\r' < "$su_out")" = 0 ] && break
	done

	if [ "$(tr -d '\r' < "$su_out")" = 0 ]; then
		echo "[P+][$((SECONDS - grant_start))s] adb shell has root"
	else
		echo "[P!] No root in adb shell"
		echo "[W] Open Magisk app, finish setup and grant Shell root"
	fi
	rm -f "$su_out"
}

case $action in
	kill)
		kill_emulator
		;;
	save)
		if ! is_running; then
			echo "[C] Emulator $avd_name is not running"
			exit 1
		fi
		echo "[P] Saving snapshot '$snapshot'..."
		start=$SECONDS
		if [ "$(adb emu avd snapshot save "$snapshot" | tr -d '\r' | head -n 1)" = OK ]; then
			echo "[P+][$((SECONDS - start))s] Snapshot '$snapshot' saved"
		else
			echo "[P!] Could not save snapshot '$snapshot'"
			exit 1
		fi
		;;
	reset)
		kill_emulator
		if [ -d "$avd_dir/snapshots/$snapshot" ]; then
			echo "[I] Restoring snapshot '$snapshot'"
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
		echo "[P+] AVD deleted, image unrooted"
		;&
	setup)
		install_deps
		create_avd
		root_image
		start_emulator -no-snapshot-load
		magisk_additional_setup
		grant_shell_root
		if [ "$rooted_now" = true ]; then
			echo "[I] Save clean state with: $0 -v $android_version -S"
		fi
		;;
esac
