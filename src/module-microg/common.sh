# Packages replaced by the module
packages="com.google.android.gms com.android.vending com.google.android.gsf"

remove_package_updates() {
	filter=${1}
	echo "[P] Checking package updates..."
	echo "-------------------------------------------"
	echo "[M] PACKAGE WITH UPDATE                TYPE"
	echo "-------------------------------------------"
	for package in $packages; do
		# Check if package update from Google version is installed
		path=$(pm path "$package" | grep "/data/app/" | sed -E 's/package:(\/data\/app\/[^/]+).*/\1/' | uniq)
		# Only active package counts, hidden system package after it may be microG while update is Google's
		# grep reads whole output, early exit (-q) makes dumpsys print broken pipe errors
		microg_type=$(pm dump "$package" | sed '/Hidden system packages:/,$d' | grep 'FAKE_PACKAGE_SIGNATURE' > /dev/null && echo "true" || echo "false")
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

grant_microg_permissions() {
	permissions="ACCESS_COARSE_LOCATION ACCESS_FINE_LOCATION ACCESS_BACKGROUND_LOCATION READ_EXTERNAL_STORAGE WRITE_EXTERNAL_STORAGE GET_ACCOUNTS POST_NOTIFICATIONS READ_PHONE_STATE RECEIVE_SMS SYSTEM_ALERT_WINDOW"
	echo "[P] Checking microG Services permissions..."
	echo "-------------------------------------------"
	echo "[M] PERMISSION                       STATUS"
	echo "-------------------------------------------"

	warn=""
	gms_dump="$(dumpsys package com.google.android.gms)"

	for perm in $permissions; do
		if echo "$gms_dump" | grep -q "android.permission.$perm: granted=true"; then
			printf "%-35s %s\n" "[I] $perm" "GRANTED"
		else
			printf "%-31s %s\n" "[W] $perm" "NOT GRANTED"
			echo -n "|-[P] Granting...                   "
			if pm grant com.google.android.gms "android.permission.$perm"; then
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