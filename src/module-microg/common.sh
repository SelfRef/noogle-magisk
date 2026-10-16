# Packages replaced by the module, playful build keeps Play Store (com.android.vending)
packages="com.google.android.gms com.android.vending com.google.android.gsf"
# Packages whose Google updates are kept, playful build bundling real Play Store sets it
keep_updates=""

# Checks if active version of package is microG (it requests signature spoofing permission)
# $1: package
is_microg() {
	# Only active package counts, hidden system package after it may be microG while update is Google's
	# grep reads whole output, early exit (-q) makes dumpsys print broken pipe errors
	pm dump "$1" | sed '/Hidden system packages:/,$d' | grep 'FAKE_PACKAGE_SIGNATURE' > /dev/null
}

remove_package_updates() {
	filter=${1}
	echo "[P] Checking package updates..."
	echo "-------------------------------------------"
	echo "[M] PACKAGE WITH UPDATE                TYPE"
	echo "-------------------------------------------"
	for package in $packages; do
		case " $keep_updates " in *" $package "*) continue ;; esac
		# Check if package update from Google version is installed
		path=$(pm path "$package" | grep "/data/app/" | sed -E 's/package:(\/data\/app\/[^/]+).*/\1/' | uniq)
		microg_type=$(is_microg "$package" && echo "true" || echo "false")
		if [ -n "$path" ]; then
			if [ "$microg_type" = "true" ]; then
				if [ "$filter" = "google" ]; then
					printf "%-32s %s\n" "[I] $package" "MICROG, OK"
				else
					printf "%-36s %s\n" "[W] $package" "MICROG"
				fi
			else
				printf "%-36s %s\n" "[W] $package" "GOOGLE"
			fi

			if [ "$filter" != "google" ] || [ "$microg_type" != "true" ]; then
				echo -n "|-[P] Removing package update...    "
				# Remove package update without uninstalling the app
				pm uninstall -k --user all "$package"
			fi
		else
			printf "%-29s %s\n" "[I] $package" "NOT FOUND, OK"
		fi
	done
	echo "-------------------------------------------"
	echo "[I] Done checking package updates."
}

# Restricted permissions (background location, SMS) can be granted only when allowlisted, which installer does on
# install but not for system apps replaced by module. Installing own APK as update and removing it keeps the allowlist.
allowlist_restricted_permissions() {
	echo "$gms_dump" | grep -q 'APPLY_RESTRICTION' || return 0
	# microG installed as user update keeps allowlist of its installer, older system APK can't replace it anyway
	pm path com.google.android.gms | grep -q '/data/app/' && return 0
	echo -n "[P] Allowlisting restricted permissions... "
	tmp_apk=/data/local/tmp/noogle-microg.apk
	if cp "$(pm path com.google.android.gms | head -n 1 | cut -d: -f2)" "$tmp_apk" &&
		pm install -r "$tmp_apk" > /dev/null && pm uninstall -k --user all com.google.android.gms > /dev/null; then
		echo "DONE"
	else
		echo "FAILED"
	fi
	rm -f "$tmp_apk"
	gms_dump="$(dumpsys package com.google.android.gms)"
}

# Play Integrity Fix unmounts module files in GMS and Play Store processes, so they can't open their APKs and crash.
# Installing module's APKs as updates moves them to /data/app, which isn't unmounted.
install_updates_for_pif() {
	pif=/data/adb/modules/playintegrityfix
	[ -d "$pif" ] && [ ! -f "$pif/disable" ] && [ ! -f "$pif/remove" ] || return 0
	# Companion first, it installs in seconds while Services take much longer
	for package in com.android.vending com.google.android.gms; do
		apk=$(pm path "$package" | head -n 1 | cut -d: -f2)
		# Only APKs mounted by module, existing updates and device's own Play Store aren't affected
		[ -f "$MODDIR/system/${apk#/system/}" ] || continue
		echo -n "[P] Installing $package as update for Play Integrity Fix... "
		tmp_apk=/data/local/tmp/noogle-microg.apk
		if cp "$apk" "$tmp_apk" && pm install -r "$tmp_apk" > /dev/null; then
			echo "DONE"
		else
			echo "FAILED"
		fi
		rm -f "$tmp_apk"
	done
}

grant_microg_permissions() {
	permissions="ACCESS_COARSE_LOCATION ACCESS_FINE_LOCATION ACCESS_BACKGROUND_LOCATION READ_EXTERNAL_STORAGE WRITE_EXTERNAL_STORAGE GET_ACCOUNTS POST_NOTIFICATIONS READ_PHONE_STATE RECEIVE_SMS SYSTEM_ALERT_WINDOW"
	gms_dump="$(dumpsys package com.google.android.gms)"
	allowlist_restricted_permissions

	echo "[P] Checking microG Services permissions..."
	echo "-------------------------------------------"
	echo "[M] PERMISSION                       STATUS"
	echo "-------------------------------------------"

	warn=""

	for perm in $permissions; do
		# Permissions missing in dump don't exist on this Android version (e.g. POST_NOTIFICATIONS before 13)
		if ! echo "$gms_dump" | grep -q "android.permission.$perm: granted="; then
			printf "%-35s %s\n" "[I] $perm" "N/A"
		elif echo "$gms_dump" | grep -q "android.permission.$perm: granted=true"; then
			printf "%-35s %s\n" "[I] $perm" "GRANTED"
		else
			printf "%-31s %s\n" "[W] $perm" "NOT GRANTED"
			echo -n "|-[P] Granting...                   "
			# pm grant succeeds silently for restricted permissions that aren't allowlisted, so check the result
			if pm grant com.google.android.gms "android.permission.$perm" &&
				dumpsys package com.google.android.gms | grep "android.permission.$perm: granted=true" > /dev/null; then
				echo "SUCCESS"
			else
				echo " FAILED"
				warn="true"
			fi
		fi
	done

	echo "-------------------------------------------"
	echo "[P] Checking microG Services permissions done."

	if [ "$warn" ]; then
		echo "[W] Some permissions were not granted."
		echo "[W] You can grant them from the microG app."
		return 1
	fi
	echo "[I] All permissions granted!"
}