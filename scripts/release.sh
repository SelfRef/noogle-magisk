#!/usr/bin/env bash
# Prepares a release when microG got updated or CHANGELOG.md has unreleased changes: pulls microG, updates
# CHANGELOG.md and update-*.json, writes dist/release-notes.md and builds the modules. Committing,
# tagging and publishing is left to the caller (see .github/workflows/release.yml).

set -e

repo_url=https://github.com/SelfRef/noogle-magisk

# Lock only first, microG APKs are pulled only when there is something to release
./scripts/pull-microg.sh -l

unreleased="$(sed -n '/^# Unreleased$/,/^# v/{/^# /d;/^$/d;p}' CHANGELOG.md)"
if git diff --quiet microg.lock && [ -z "$unreleased" ]; then
	echo "[I] No microG update and no unreleased changes, nothing to release"
	exit 0
fi

# Android refuses to boot when a priv-app requests a privileged permission that isn't allowlisted
new_permissions="$(git diff -U0 microg.lock | grep -E '^\+[^+].* permission ' | cut -c2- || true)"
if [ -n "$new_permissions" ]; then
	echo "[C] microG requests new permissions, add privileged ones to privapp-permissions-microg.xml and commit microg.lock:"
	echo "$new_permissions"
	exit 1
fi

# Next releases of the same day get .1, .2... suffix, versionCode is the date followed by 2 digit release number
date_version="v$(date -u +%Y.%m.%d)"
version=$date_version
number=0
while git ls-remote --exit-code --tags origin "refs/tags/$version" > /dev/null; do
	number=$((number + 1))
	version="$date_version.$number"
done
version_code="$(date -u +%Y%m%d)$(printf %02d $number)"
export MODULE_VERSION=$version MODULE_VERSION_CODE=$version_code

echo "[P] Preparing release $version..."
microg="$(sed -n 's/^\([^ ]*\) version \(.*\)/\1 \2/p' microg.lock | sed '
	s/^com.google.android.gms /microG Services /
	s/^com.android.vending /Companion /
	s/^com.google.android.gsf /Services Framework Proxy /' | paste -sd ',' | sed 's/,/, /g')"
notes="- $microg${unreleased:+
$unreleased}"

mkdir -p dist
echo "$notes" > dist/release-notes.md
# Unreleased heading stays on top for next changes
{
	printf '# Unreleased\n\n# %s\n%s\n\n' "$version" "$notes"
	sed '1,/^# v/{/^# v/!d}' CHANGELOG.md
} > CHANGELOG.md.new
mv CHANGELOG.md.new CHANGELOG.md

# One update file per module and variant, so Magisk never switches installed variant
for module in microg microg-playful microg-catfish unbundle; do
	cat > "update-$module.json" << EOF
{
	"version": "$version",
	"versionCode": $version_code,
	"zipUrl": "$repo_url/releases/download/$version/noogle-$module-$version.zip",
	"changelog": "https://raw.githubusercontent.com/SelfRef/noogle-magisk/refs/heads/master/CHANGELOG.md"
}
EOF
done

checked_lock="$(cat microg.lock)"
./scripts/pull-microg.sh
# New permissions were checked against the lock above, a microG update in between would skip that check
if [ "$(cat microg.lock)" != "$checked_lock" ]; then
	echo "[C] microG got updated during release, try again"
	exit 1
fi
export REQUIRE_SIGNING=1
./scripts/build-noogle-microg.sh
./scripts/build-noogle-microg.sh -p
./scripts/build-noogle-microg.sh -c
./scripts/build-noogle-unbundle.sh
echo "[P+] Release $version prepared"
