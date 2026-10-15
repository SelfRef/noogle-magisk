#!/usr/bin/env bash
# Prepares a release when microG got updated or CHANGELOG.md has unreleased changes: pulls microG, updates
# CHANGELOG.md and update-*.json, writes dist/release-notes.md and builds the modules. Committing,
# tagging and publishing is left to the caller (see .github/workflows/release.yml).

set -e

version="v$(date -u +%Y.%m.%d)"
repo_url=https://github.com/SelfRef/noogle-magisk

./scripts/pull-microg.sh

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

# ponytail: one release per day, versionCode is the date
if git ls-remote --exit-code --tags origin "refs/tags/$version" > /dev/null; then
	echo "[C] $version is already released, try again tomorrow"
	exit 1
fi

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
for module in microg microg-playful unbundle; do
	cat > "update-$module.json" << EOF
{
	"version": "$version",
	"versionCode": $(date -u +%Y%m%d),
	"zipUrl": "$repo_url/releases/download/$version/noogle-$module-$version.zip",
	"changelog": "https://raw.githubusercontent.com/SelfRef/noogle-magisk/refs/heads/master/CHANGELOG.md"
}
EOF
done

./scripts/build-noogle-microg.sh
./scripts/build-noogle-microg.sh -p
./scripts/build-noogle-unbundle.sh
echo "[P+] Release $version prepared"
