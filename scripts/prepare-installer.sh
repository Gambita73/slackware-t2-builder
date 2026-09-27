#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

ISO_ROOT="$ROOT/iso-root"
STAGING="$ROOT/staging"
SETT2="$ROOT/scripts/SeTt2"
INITRD_WORK="$ROOT/build/initrd-root"

INITRD="$ISO_ROOT/isolinux/initrd.img"
INSTALLER_KERNEL="$ISO_ROOT/kernels/huge.s/bzImage"
GRUB_CFG="$ISO_ROOT/EFI/BOOT/grub.cfg"


[ -f "$INITRD" ] || {
    echo "Missing installer initrd: $INITRD" >&2
    exit 1
}

[ -f "$STAGING/boot/bzImage" ] || {
    echo "Missing staged kernel: $STAGING/boot/bzImage" >&2
    exit 1
}

[ -d "$STAGING/lib/modules" ] || {
    echo "Missing staged kernel modules: $STAGING/lib/modules" >&2
    exit 1
}

[ -f "$SETT2" ] || {
    echo "Missing SeTt2: $SETT2" >&2
    exit 1
}

[ -f "$GRUB_CFG" ] || {
    echo "Missing EFI GRUB configuration: $GRUB_CFG" >&2
    exit 1
}


rm -rf "$INITRD_WORK"
mkdir -p "$INITRD_WORK"

cd "$INITRD_WORK"


xzcat "$INITRD" |
    cpio -idmu --no-absolute-filenames


rm -rf lib/modules
mkdir -p lib
cp -a "$STAGING/lib/modules" lib/


if ! grep -q '^[[:space:]]*modprobe t2bce_vhci[[:space:]]*$' \
    etc/rc.d/rc.S ; then

    sed -i \
        '/^[[:space:]]*modprobe loop[[:space:]]*$/a modprobe t2bce_vhci' \
        etc/rc.d/rc.S
fi


install -m 755 "$SETT2" usr/lib/setup/SeTt2


SETUP="usr/lib/setup/setup"

[ -f "$SETUP" ] || {
    echo "Missing Slackware installer setup script." >&2
    exit 1
}


sed -i \
    -e '\#/usr/lib/setup/SeTt2#d' \
    -e '\#setup\.liloconfig#d' \
    -e '\#setup\.ll\.eliloconfig#d' \
    "$SETUP"

sed -i \
    '/^[[:space:]]*SeTconfig[[:space:]]*$/i\  chmod -x "$T_PX/var/log/setup/setup.liloconfig" 2>/dev/null || true\n  chmod -x "$T_PX/var/log/setup/setup.ll.eliloconfig" 2>/dev/null || true\n  chmod -x "$T_PX"/var/log/setup/setup.*grub* 2>/dev/null || true' \
    "$SETUP"

sed -i \
    '/^[[:space:]]*dialog --title "SETUP COMPLETE"/i\   /usr/lib/setup/SeTt2 || exit 1' \
    "$SETUP"

[ "$(grep -c '/usr/lib/setup/SeTt2' "$SETUP")" -eq 1 ] || {
    echo "Failed to integrate SeTt2 into Slackware setup." >&2
    exit 1
}


cp -a "$STAGING/boot/bzImage" "$INSTALLER_KERNEL"


find . -print |
    cpio -o -H newc --owner=0:0 |
    xz --check=crc32 > "$INITRD.new"

mv "$INITRD.new" "$INITRD"


sed -i \
    '/\/kernels\/huge\.s\/bzImage/ {
        /intel_iommu=on iommu=pt pm_async=off/b
        s/$/ intel_iommu=on iommu=pt pm_async=off/
    }' \
    "$GRUB_CFG"

echo "Slackware-T2 installer prepared successfully."
