#!/usr/bin/env bash
# Assert .deb contents without installing (used for x86_32 on amd64 runners).
set -euo pipefail

DEB="${1:?usage: smoke_install_linux_debinfo.sh <path-to.deb>}"
test -f "$DEB"

echo "=== dpkg-deb -I $DEB ==="
dpkg-deb -I "$DEB"

echo "=== Assert package contents ==="
LIST="$(dpkg-deb -c "$DEB")"
echo "$LIST" | grep -q 'opt/blazium/bin/blazium-hub'
echo "$LIST" | grep -q 'opt/blazium/bin/blazium-cli'
echo "$LIST" | grep -q 'opt/blazium/bin/crash_reporter'
echo "$LIST" | grep -q 'opt/blazium/bin/blazium'
echo "$LIST" | grep -q 'etc/profile.d/blazium.sh'

echo "Linux deb content smoke OK"
