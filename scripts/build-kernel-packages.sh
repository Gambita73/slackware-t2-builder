#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGING="$ROOT/staging"
STAGING_SOURCE="$ROOT/staging-source"
PKGROOT="$ROOT/build/packages"
OUTPUT="$ROOT/packages"

mapfile -t VERSIONS < <(find "$STAGING/lib/modules" -mindepth 1 -maxdepth 1 -type d -printf '%f\n')

if [ "${#VERSIONS[@]}" -ne 1 ]; then
    echo "Unable to determine a unique kernel version." >&2
    exit 1
fi

VERSION="${VERSIONS[0]}"
BUILD="1_t2"

HUGE="$PKGROOT/kernel-huge"
MODULES="$PKGROOT/kernel-modules"
SOURCE="$PKGROOT/kernel-source"

rm -rf "$HUGE" "$MODULES" "$SOURCE"
mkdir -p "$PKGROOT"
mkdir -p "$HUGE/boot" "$HUGE/install"
mkdir -p "$MODULES/lib/modules" "$MODULES/install"
mkdir -p "$SOURCE/usr/src" "$SOURCE/install"
mkdir -p "$OUTPUT"

cp -a "$STAGING/boot/bzImage" \
    "$HUGE/boot/vmlinuz-huge-$VERSION"

cp -a "$STAGING/boot/config" \
    "$HUGE/boot/config-huge-$VERSION.x64"

cp -a "$STAGING/boot/System.map" \
    "$HUGE/boot/System.map-huge-$VERSION"

cat > "$HUGE/install/doinst.sh" <<EOF
( cd boot ; rm -rf System.map )
( cd boot ; ln -sf System.map-huge-$VERSION System.map )
( cd boot ; rm -rf config )
( cd boot ; ln -sf config-huge-$VERSION.x64 config )
( cd boot ; rm -rf vmlinuz )
( cd boot ; ln -sf vmlinuz-huge-$VERSION vmlinuz )
( cd boot ; rm -rf vmlinuz-huge )
( cd boot ; ln -sf vmlinuz-huge-$VERSION vmlinuz-huge )
EOF

cat > "$HUGE/install/slack-desc" <<'EOF'
           |-----handy-ruler------------------------------------------------------|
kernel-huge: kernel-huge (T2-enabled fully-loaded SMP Linux kernel)
kernel-huge:
kernel-huge: Linux kernel for Intel Apple Macs equipped with the Apple T2 chip.
kernel-huge: This kernel includes the patches and configuration required for
kernel-huge: Apple T2 hardware support while retaining the Slackware huge
kernel-huge: configuration and layout.
kernel-huge:
kernel-huge: Built for Slackware-T2.
kernel-huge:
kernel-huge:
kernel-huge:
EOF

cp -a "$STAGING/lib/modules/$VERSION" \
    "$MODULES/lib/modules/"

rm -f "$MODULES/lib/modules/$VERSION/build"
rm -f "$MODULES/lib/modules/$VERSION/source"

cat > "$MODULES/install/doinst.sh" <<EOF
( cd lib/modules/$VERSION ; rm -rf build )
( cd lib/modules/$VERSION ; ln -sf /usr/src/linux-$VERSION build )
( cd lib/modules/$VERSION ; rm -rf source )
( cd lib/modules/$VERSION ; ln -sf /usr/src/linux-$VERSION source )
EOF

cat > "$MODULES/install/slack-desc" <<'EOF'
              |-----handy-ruler------------------------------------------------------|
kernel-modules: kernel-modules (T2-enabled Linux kernel modules)
kernel-modules:
kernel-modules: Kernel modules for the Slackware-T2 Linux kernel.
kernel-modules: These modules include support for Apple T2 hardware as well as
kernel-modules: the standard modules enabled by the Slackware huge kernel
kernel-modules: configuration.
kernel-modules:
kernel-modules: Built for Slackware-T2.
kernel-modules:
kernel-modules:
kernel-modules:
EOF

if [ ! -d "$STAGING_SOURCE/usr/src/linux-$VERSION" ]; then
    echo "Missing kernel source: $STAGING_SOURCE/usr/src/linux-$VERSION" >&2
    exit 1
fi

cp -a "$STAGING_SOURCE/usr/src/linux-$VERSION" \
    "$SOURCE/usr/src/"

cat > "$SOURCE/install/doinst.sh" <<EOF
( cd usr/src ; rm -rf linux )
( cd usr/src ; ln -sf linux-$VERSION linux )
EOF

cat > "$SOURCE/install/slack-desc" <<'EOF'
             |-----handy-ruler------------------------------------------------------|
kernel-source: kernel-source (T2-enabled Linux kernel source)
kernel-source:
kernel-source: Linux kernel source used to build the Slackware-T2 kernel.
kernel-source: The source tree contains the Apple T2 Linux patches and the
kernel-source: configuration used by the Slackware-T2 kernel build.
kernel-source:
kernel-source: This source tree may be used to build external kernel modules.
kernel-source:
kernel-source: Built for Slackware-T2.
kernel-source:
kernel-source:
EOF

rm -f \
    "$OUTPUT/kernel-huge-$VERSION-x86_64-$BUILD.txz" \
    "$OUTPUT/kernel-modules-$VERSION-x86_64-$BUILD.txz" \
    "$OUTPUT/kernel-source-$VERSION-noarch-$BUILD.txz"

tar --owner=0 --group=0 -C "$HUGE" -cJf \
    "$OUTPUT/kernel-huge-$VERSION-x86_64-$BUILD.txz" .

tar --owner=0 --group=0 -C "$MODULES" -cJf \
    "$OUTPUT/kernel-modules-$VERSION-x86_64-$BUILD.txz" .

tar --owner=0 --group=0 -C "$SOURCE" -cJf \
    "$OUTPUT/kernel-source-$VERSION-noarch-$BUILD.txz" .

echo "$OUTPUT/kernel-huge-$VERSION-x86_64-$BUILD.txz"
echo "$OUTPUT/kernel-modules-$VERSION-x86_64-$BUILD.txz"
echo "$OUTPUT/kernel-source-$VERSION-noarch-$BUILD.txz"
