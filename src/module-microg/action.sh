MODDIR="$(dirname "$0")"
. "$MODDIR/common.sh"

echo "[P] Module self-check..."

echo
remove_package_updates google
install_updates_for_pif

echo
echo
grant_microg_permissions

echo
echo
echo "[I] Done fixing module."