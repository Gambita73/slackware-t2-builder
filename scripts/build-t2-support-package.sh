#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGING="$ROOT/staging-t2"
PKGROOT="$ROOT/build/packages/t2-support"
OUTPUT="$ROOT/packages"

VERSION="1.0"
BUILD="1_t2"

rm -rf "$PKGROOT"
mkdir -p "$PKGROOT"
mkdir -p "$PKGROOT/install"
mkdir -p "$OUTPUT"

cp -a "$STAGING/." "$PKGROOT/"

cat > "$PKGROOT/install/slack-desc" <<'EOF'
t2-support: t2-support (Apple T2 support for Slackware)
t2-support:
t2-support: Support files and utilities for Intel Apple Macs equipped with the
t2-support: Apple T2 security chip.
t2-support:
t2-support: Includes T2FanRD, Apple firmware helper, udev configuration,
t2-support: NetworkManager configuration, and Slackware startup integration.
t2-support:
t2-support: Built for Slackware-T2.
t2-support:
t2-support:
EOF

chmod 755 "$PKGROOT/usr/sbin/t2fanrd"
chmod 755 "$PKGROOT/usr/sbin/get-apple-firmware"
chmod 755 "$PKGROOT/etc/rc.d/rc.t2fanrd"
chmod 755 "$PKGROOT/etc/rc.d/rc.t2firmware"

rm -f "$OUTPUT/t2-support-$VERSION-x86_64-$BUILD.txz"

tar --owner=0 --group=0 -C "$PKGROOT" -cJf \
    "$OUTPUT/t2-support-$VERSION-x86_64-$BUILD.txz" .

echo "$OUTPUT/t2-support-$VERSION-x86_64-$BUILD.txz"
