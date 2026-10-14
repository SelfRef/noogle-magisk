MODDIR="$(dirname "$0")"
. "$MODDIR/common.sh"

echo "[P] Module self-check..."

echo
remove_package_updates google

echo
echo
grant_microg_permissions

echo
echo
echo "[I] Done fixing module."