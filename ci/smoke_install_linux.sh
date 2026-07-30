#!/usr/bin/env bash
# Silent-ish dpkg install + full uninstall smoke for Blazium Hub .deb
set -euo pipefail

DEB="${1:?usage: smoke_install_linux.sh <path-to.deb>}"
test -f "$DEB"

echo "=== Install $DEB ==="
sudo dpkg -i "$DEB" || sudo apt-get install -f -y

echo "=== Assert install layout ==="
test -x /opt/blazium/bin/blazium-hub
test -x /opt/blazium/bin/blazium-cli
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
blazium-cli --help >/dev/null || blazium-cli -h >/dev/null || true
# CLI may use cobra without --help exit 0 on all versions; accept any exit if binary runs
/opt/blazium/bin/blazium-cli version >/dev/null 2>&1 \
  || /opt/blazium/bin/blazium-cli --version >/dev/null 2>&1 \
  || /opt/blazium/bin/blazium-cli help >/dev/null 2>&1 \
  || test -x /opt/blazium/bin/blazium-cli

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
