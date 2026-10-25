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

echo
echo "[I] Enjoying Noogle? Support development:"
echo "    ko-fi.com/selfref"
echo "    github.com/sponsors/SelfRef"
echo "    liberapay.com/SelfRef"