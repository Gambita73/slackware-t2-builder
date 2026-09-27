#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

ISO_ROOT="$ROOT/iso-root"
OUTPUT_DIR="$ROOT/output"
OUTPUT_ISO="$OUTPUT_DIR/slackware-t2.iso"

XORRISO="$(command -v xorriso || true)"

[ -n "$XORRISO" ] || {
    echo "xorriso is not installed." >&2
    exit 1
}

[ -d "$ISO_ROOT" ] || {
    echo "Missing ISO tree: $ISO_ROOT" >&2
    exit 1
}

[ -f "$ISO_ROOT/isolinux/isolinux.bin" ] || {
    echo "Missing isolinux/isolinux.bin." >&2
    exit 1
}

[ -f "$ISO_ROOT/isolinux/efiboot.img" ] || {
    echo "Missing isolinux/efiboot.img." >&2
    exit 1
}


ISOHDPFX=""

for FILE in \
    /usr/lib/syslinux/bios/isohdpfx.bin \
    /usr/lib/syslinux/isohdpfx.bin \
    /usr/share/syslinux/isohdpfx.bin
do
    if [ -f "$FILE" ]; then
        ISOHDPFX="$FILE"
        break
    fi
done

if [ -z "$ISOHDPFX" ]; then
    ISOHDPFX="$(
        find /usr -type f -name isohdpfx.bin -print -quit 2>/dev/null || true
    )"
fi

[ -n "$ISOHDPFX" ] && [ -f "$ISOHDPFX" ] || {
    echo "Unable to locate isohdpfx.bin." >&2
    exit 1
}


mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_ISO"
rm -f "$OUTPUT_ISO.sha256"


cd "$ISO_ROOT"

"$XORRISO" -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -R -J \
    -A "Slackware-T2 Install" \
    -hide-rr-moved \
    -v -d -N \
    -eltorito-boot isolinux/isolinux.bin \
    -eltorito-catalog isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -isohybrid-mbr "$ISOHDPFX" \
    -eltorito-alt-boot \
    -e isolinux/efiboot.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -volid "SLACKWARE_T2" \
    -output "$OUTPUT_ISO" \
    .


[ -s "$OUTPUT_ISO" ] || {
    echo "ISO creation failed." >&2
    exit 1
}


sha256sum "$OUTPUT_ISO" > "$OUTPUT_ISO.sha256"


echo
echo "Slackware-T2 ISO created successfully."
echo "ISO:    $OUTPUT_ISO"
echo "SHA256: $OUTPUT_ISO.sha256"
