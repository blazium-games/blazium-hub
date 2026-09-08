#!/usr/bin/env bash
# Silent-ish dpkg install + full uninstall smoke for Blazium Hub .deb
set -euo pipefail

DEB="${1:?usage: smoke_install_linux.sh <path-to.deb>}"
test -f "$DEB"

echo "=== Install $DEB ==="
export BLAZIUM_NO_ANALYTICS=1
sudo --preserve-env=BLAZIUM_NO_ANALYTICS dpkg -i "$DEB" || sudo --preserve-env=BLAZIUM_NO_ANALYTICS apt-get install -f -y

echo "=== Assert install layout ==="
test -x /opt/blazium/bin/blazium-hub
test -x /opt/blazium/bin/blazium-cli
test -x /opt/blazium/bin/crash_reporter
test -s /opt/blazium/bin/crash_reporter.version
test -s /opt/blazium/VERSION
test -e /opt/blazium/bin/blazium
test -L /usr/bin/blazium-hub || test -e /usr/bin/blazium-hub
test -L /usr/bin/blazium-cli || test -e /usr/bin/blazium-cli
test -L /usr/bin/blazium || test -e /usr/bin/blazium
test -f /etc/profile.d/blazium.sh
grep -q 'BLAZIUM=/opt/blazium' /etc/profile.d/blazium.sh

# shellcheck disable=SC1091
source /etc/profile.d/blazium.sh
test "${BLAZIUM}" = "/opt/blazium"
command -v blazium-cli >/dev/null
command -v blazium >/dev/null
echo "=== blazium-cli version ==="
VER_OUT="$(/opt/blazium/bin/blazium-cli version)"
test -n "$VER_OUT"
echo "$VER_OUT"

echo "=== Hub --headless --self-test --quit ==="
/opt/blazium/bin/blazium-hub --headless --self-test --quit

echo "=== Seed user markers ==="
mkdir -p "$HOME/.config/blazium" "$HOME/.local/share/blazium"
echo smoke > "$HOME/.config/blazium/hub.json"
echo smoke > "$HOME/.local/share/blazium/marker"

echo "=== Purge ==="
sudo dpkg --purge blazium-hub

echo "=== Assert full removal ==="
test ! -e /opt/blazium
test ! -e /etc/profile.d/blazium.sh
test ! -e /usr/bin/blazium-hub
test ! -e /usr/bin/blazium-cli
test ! -e /usr/bin/blazium
test ! -e "$HOME/.config/blazium"
test ! -e "$HOME/.local/share/blazium"

echo "Linux install/uninstall smoke OK"
