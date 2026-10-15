#!/usr/bin/env bash
# Sets up a Magisk-rooted Android emulator (Google Play image) for testing modules. Arch Linux only.
#
# Workflow: run without options (fully unattended, ~3 min first time), save clean state with -S,
# test with install-noogle.sh, go back with -r. With a real device connected too: export ANDROID_SERIAL=emulator-5554
# Logs: logs/emulator-<avd>.log, logs/rootavd-<avd>.log. SDK in ~/Android/Sdk, rootAVD in ~/.cache/rootAVD.
# Each Android version has its own port (15 is emulator-5554), so versions can be set up and run in parallel.
# Parallel emulators need WiFiPacketStream feature off (done here), otherwise shared netsimd makes them hang
# ("hanging thread" in log) and crash.
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
snapshot=clean
sdk_dir="${ANDROID_HOME:-$HOME/Android/Sdk}"
rootavd_dir="${XDG_CACHE_HOME:-$HOME/.cache}/rootAVD"
log_dir=logs
magisk_release=latest

# $1: exit code
show_help() {
	echo "Usage: $0 [options]"
	echo "Sets up, roots (Magisk via rootAVD) and starts the emulator. Safe to re-run."
	echo "Options:"
	echo "  -h            Show this help message"
	echo "  -v <version>  Android version [11|12|12L|13|14|15|16|17] (default: 15)"
	echo "  -n <name>     AVD name (default: noogle-<version>)"
	echo "  -H            Run headless (no window)"
	echo "  -S            Save running emulator state as '$snapshot' snapshot"
	echo "  -r            Reset to '$snapshot' snapshot (wipes data if there is none)"
	echo "  -R            Recreate: delete AVD, unroot image and set everything up again"
	echo "  -m <version>  Magisk version to root with, e.g. v29.0, use with -R (default: latest stable)"
	echo "  -k            Kill running emulator"
	echo "After first setup save clean state with -S, so -r can restore it."
	exit "${1:-0}"
}

while getopts "hv:n:m:HSrRk" opt; do
	case $opt in
		h) show_help ;;
		v) android_version="$OPTARG" ;;
		n) avd_name="$OPTARG" ;;
		m) magisk_release="tags/$OPTARG" ;;
		H) headless=true ;;
		S) action=save ;;
		r) action=reset ;;
		R) action=recreate ;;
		k) action=kill ;;
		*) show_help 1 ;;
	esac
done

case $android_version in
	11) api=30 port=5556 ;;
	12) api=31 port=5558 ;;
	12L|12l) api=32 port=5560 ;;
	13) api=33 port=5562 ;;
	14) api=34 port=5564 ;;
	15) api=35 port=5554 ;;
	16) api=36 port=5566 ;;
	17) api=37.0 port=5568 ;;
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
magisk_apk="${XDG_CACHE_HOME:-$HOME/.cache}/noogle-magisk-$avd_name.apk"
rootavd_log="$log_dir/rootavd-$avd_name.log"

export ANDROID_HOME="$sdk_dir"
export ANDROID_SERIAL="emulator-$port"
export PATH="$sdk_dir/cmdline-tools/latest/bin:$sdk_dir/emulator:$PATH"

# Prints debug message when run with DEBUG=1
debug() {
	[ "$DEBUG" = 1 ] && echo "[D] $*" || true
}

is_running() {
	pgrep -f -- "-avd $avd_name( |$)" > /dev/null
}

kill_emulator() {
	is_running || return 0
	echo "[P] Stopping emulator $avd_name..."
	local start=$SECONDS
	adb emu kill > /dev/null 2>&1 || true
	while is_running; do sleep 1; done
	echo "[P+][$((SECONDS - start))s] Emulator stopped"
}

# Starts emulator if not running and waits for boot
# $@: extra emulator args
start_emulator() {
	local start=$SECONDS
	if is_running; then
		echo "[P] Waiting for emulator $avd_name to boot..."
	else
		echo "[P] Starting emulator $avd_name (log: $log_dir/emulator-$avd_name.log)..."
		mkdir -p "$log_dir"
		# netsimd WiFi packet streamer shared by emulators makes the next ones hang and crash, built-in WiFi works fine
		args=(-avd "$avd_name" -port "$port" -no-snapshot-save -crash-report-mode never -no-metrics \
			-feature -WiFiPacketStream "$@")
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

# rootAVD patches the shared system image ramdisk. Its own backup (ramdisk.img.backup) gets lost or broken
# when rooting crashes, so a pristine copy is kept as ramdisk.img.stock
unroot_image() {
	if [ -f "$ramdisk.stock" ]; then
		cp "$ramdisk.stock" "$ramdisk"
	elif [ -f "$ramdisk.backup" ]; then
		mv "$ramdisk.backup" "$ramdisk"
	fi
	rm -f "$ramdisk.backup"
}

root_image() {
	if [ -f "$ramdisk.backup" ] && [ ! -f "$ramdisk.stock" ]; then
		cp "$ramdisk.backup" "$ramdisk.stock"
	elif [ ! -f "$ramdisk.stock" ]; then
		cp "$ramdisk" "$ramdisk.stock"
	fi
	if ! cmp -s "$ramdisk" "$ramdisk.stock"; then
		echo "[I] Image already rooted"
		return
	fi
	# rootAVD falls back to its bundled (old) Magisk when the emulator has no internet, so provide the latest one
	magisk_url="$(curl -fsSL "https://api.github.com/repos/topjohnwu/Magisk/releases/$magisk_release" \
		| grep -o 'https://[^"]*/Magisk-v[^"]*\.apk' | head -n 1)"
	echo "[P] Downloading ${magisk_url##*/}..."
	start=$SECONDS
	curl -fL --progress-bar "$magisk_url" -o "$magisk_apk"
	echo "[P+][$((SECONDS - start))s] Downloaded ${magisk_url##*/}"

	# rootAVD sometimes fails to pull patched ramdisk back (adb transfer drops), so retry
	for attempt in 1 2 3; do
		start_emulator
		echo "[P] Rooting image with rootAVD, attempt $attempt/3 (log: $rootavd_log)..."
		root_start=$SECONDS
		# stdin from /dev/null makes rootAVD take the default menu choices without prompting
		# rootAVD keeps its working files in own dir, so use a private copy to allow parallel setups
		run_dir="$(mktemp -d)"
		cp -r "$rootavd_dir/." "$run_dir"
		cp "$magisk_apk" "$run_dir/Magisk.zip"
		(cd "$run_dir" && exec bash rootAVD.sh "$image_path/ramdisk.img" < /dev/null) > "$rootavd_log" 2>&1 &
		rootavd_pid=$!
		# It hangs on installing Magisk app when device drops offline or emulator crashes after pulling ramdisk,
		# so stop it then (app is installed later anyway), or after 5 minutes
		for _ in $(seq 300); do
			kill -0 $rootavd_pid 2> /dev/null && is_running || break
			sleep 1
		done
		pkill -P $rootavd_pid 2> /dev/null || true
		kill $rootavd_pid 2> /dev/null || true
		wait $rootavd_pid 2> /dev/null || true
		rm -rf "$run_dir"
		# rootAVD shuts the emulator down when done, killing it early loses Magisk app install, unless it hung
		for _ in $(seq 60); do is_running && sleep 1; done
		kill_emulator > /dev/null
		# rootAVD ignores failed pulls, leaving no or unpatched ramdisk
		[ -f "$ramdisk" ] && ! cmp -s "$ramdisk" "$ramdisk.stock" && break
		unroot_image
		echo "[P!] rootAVD failed to patch ramdisk, stock one restored"
		if [ $attempt = 3 ]; then
			echo "[C] Could not root image, check $rootavd_log"
			exit 1
		fi
	done
	echo "[P+][$((SECONDS - root_start))s] Image rooted"
	rooted_now=true
}

# Taps first UI node matching regex once it shows up on screen
# $1: regex for node attributes (case insensitive), $2: timeout in seconds
tap_node() {
	local deadline=$((SECONDS + $2)) x1 y1 x2 y2
	while [ $SECONDS -lt "$deadline" ]; do
		# Node bounds: [x1,y1][x2,y2]
		read -r x1 y1 x2 y2 <<< "$(adb exec-out uiautomator dump /dev/tty 2> /dev/null \
			| grep -oE '<node [^>]*>' | grep -iE "$1" | head -n 1 \
			| grep -oE 'bounds="[^"]*"' | grep -oE '[0-9]+' | tr '\n' ' ')"
		if [ -n "$y2" ]; then
			debug "tap '$1' at $(((x1 + x2) / 2)),$(((y1 + y2) / 2))"
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
	if ! adb shell pm path com.topjohnwu.magisk > /dev/null 2>&1; then
		echo "[P] Installing Magisk app..."
		adb install "$magisk_apk" > /dev/null
		echo "[P+] Magisk app installed"
	fi
	adb shell command -v su > /dev/null 2>&1 && return 0
	echo "[P] Running Magisk additional setup..."
	start=$SECONDS
	boot_id="$(adb shell cat /proc/sys/kernel/random/boot_id | grep -oE '^[0-9a-f-]{36}')"
	# Notification permission prompt would cover the dialog, permission exists since Android 13
	adb shell pm grant com.topjohnwu.magisk android.permission.POST_NOTIFICATIONS 2> /dev/null || true
	open_magisk || true
	# Taps during dialog animation can get ignored, so keep tapping OK until device reboots
	# adb returns nothing or blocks while device goes down, only new boot id means reboot happened
	end=$((SECONDS + 120))
	while [ $SECONDS -lt $end ]; do
		new_boot_id="$(timeout 5 adb shell cat /proc/sys/kernel/random/boot_id 2> /dev/null | grep -oE '^[0-9a-f-]{36}' || true)"
		[ -n "$new_boot_id" ] && [ "$new_boot_id" != "$boot_id" ] && break
		# su shows up right after OK, but Magisk reboots a few seconds later anyway, so wait for the reboot
		tap_node 'text="OK"' 1 && debug "t=$((SECONDS - start))s tapped OK" || true
		sleep 2
	done
	# Wait for boot to finish in case device rebooted
	start_emulator
	if adb shell command -v su > /dev/null 2>&1; then
		echo "[P+][$((SECONDS - start))s] Additional setup done"
	else
		echo "[P!] Magisk additional setup didn't complete"
	fi
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
		open_magisk || true
		tap_node 'content-desc="Superuser"' 30 && tap_node 'class="android.widget.Switch"[^>]*checked="false"' 30 || true
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
		unroot_image
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
