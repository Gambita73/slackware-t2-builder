#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$ROOT/scripts"
SOURCE_TREE="${SLACKWARE_SOURCE:-/mnt/slackware}"
OUTPUT_ISO="$ROOT/output/slackware-t2.iso"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run the complete build with: sudo ./build.sh" >&2
    exit 1
fi

BUILD_USER="${SUDO_USER:-$(stat -c '%U' "$ROOT")}" 

if [ -z "$BUILD_USER" ] || [ "$BUILD_USER" = "root" ]; then
    echo "Unable to determine the non-root build user." >&2
    exit 1
fi

BUILD_GROUP="$(id -gn "$BUILD_USER")"
BUILD_HOME="$(getent passwd "$BUILD_USER" | cut -d: -f6)"
BUILD_PATH="$BUILD_HOME/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

run_user() {
    runuser -u "$BUILD_USER" -- env \
        HOME="$BUILD_HOME" \
        USER="$BUILD_USER" \
        LOGNAME="$BUILD_USER" \
        PATH="$BUILD_PATH" \
        "$@"
}

step() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
    shift
    "$@"
}

for FILE in \
    build-kernel.sh \
    stage-kernel.sh \
    staging-source.sh \
    build-t2fanrd.sh \
    fetch-apple-firmware.sh \
    fetch-grub.sh \
    create-t2-config.sh \
    stage-t2-tools.sh \
    build-kernel-packages.sh \
    build-t2-support-package.sh \
    install-t2-packages.sh \
    update-package-metadata.sh \
    prepare-installer.sh \
    build-iso.sh \
    SeTt2
do
    [ -f "$SCRIPTS/$FILE" ] || {
        echo "Missing: $SCRIPTS/$FILE" >&2
        exit 1
    }
done

for CMD in \
    git curl wget gpg make patch xz xzcat cpio tar find \
    sha256sum md5sum bzip2 xorriso runuser getent nproc
 do
    command -v "$CMD" >/dev/null 2>&1 || {
        echo "Missing required command: $CMD" >&2
        exit 1
    }
done

run_user sh -c 'command -v rustup >/dev/null 2>&1' || {
    echo "Missing required command for $BUILD_USER: rustup" >&2
    exit 1
}

run_user sh -c 'command -v cargo >/dev/null 2>&1' || {
    echo "Missing required command for $BUILD_USER: cargo" >&2
    exit 1
}

[ -d "$SOURCE_TREE" ] || {
    echo "Missing mounted Slackware ISO tree: $SOURCE_TREE" >&2
    exit 1
}

[ -f "$SOURCE_TREE/kernels/huge.s/config" ] || {
    echo "The Slackware source tree at $SOURCE_TREE is not valid." >&2
    exit 1
}

[ -f "$SOURCE_TREE/isolinux/initrd.img" ] || {
    echo "Missing Slackware installer initrd in $SOURCE_TREE." >&2
    exit 1
}

[ -f "$SOURCE_TREE/isolinux/efiboot.img" ] || {
    echo "Missing Slackware EFI boot image in $SOURCE_TREE." >&2
    exit 1
}

chmod 755 "$SCRIPTS"/*.sh "$SCRIPTS/SeTt2"
chown "$BUILD_USER:$BUILD_GROUP" "$ROOT"

rm -rf \
    "$ROOT/iso-root" \
    "$ROOT/build" \
    "$ROOT/packages" \
    "$ROOT/staging" \
    "$ROOT/staging-source" \
    "$ROOT/staging-t2" \
    "$ROOT/t2-config" \
    "$ROOT/output"

mkdir -p "$ROOT/iso-root"
cp -a "$SOURCE_TREE/." "$ROOT/iso-root/"

mkdir -p \
    "$ROOT/build" \
    "$ROOT/packages" \
    "$ROOT/staging/boot" \
    "$ROOT/staging-source" \
    "$ROOT/staging-t2" \
    "$ROOT/t2-config" \
    "$ROOT/output"

chown -R "$BUILD_USER:$BUILD_GROUP" \
    "$ROOT/build" \
    "$ROOT/packages" \
    "$ROOT/staging" \
    "$ROOT/staging-source" \
    "$ROOT/staging-t2" \
    "$ROOT/t2-config" \
    "$ROOT/output"

step "1/14  Build T2 kernel" \
    run_user "$SCRIPTS/build-kernel.sh"

step "2/14  Stage kernel and modules" \
    run_user "$SCRIPTS/stage-kernel.sh"

step "3/14  Stage kernel source" \
    run_user "$SCRIPTS/staging-source.sh"

step "4/14  Build T2FanRD" \
    run_user "$SCRIPTS/build-t2fanrd.sh"

step "5/14  Fetch Apple firmware helper" \
    run_user "$SCRIPTS/fetch-apple-firmware.sh"

step "6/14  Fetch Slackware GRUB package" \
    run_user "$SCRIPTS/fetch-grub.sh"

step "7/14  Create T2 configuration" \
    run_user "$SCRIPTS/create-t2-config.sh"

step "8/14  Stage T2 tools" \
    run_user "$SCRIPTS/stage-t2-tools.sh"

step "9/14  Build T2 kernel packages" \
    run_user "$SCRIPTS/build-kernel-packages.sh"

step "10/14 Build T2 support package" \
    run_user "$SCRIPTS/build-t2-support-package.sh"

step "11/14 Install T2 and GRUB packages into ISO tree" \
    "$SCRIPTS/install-t2-packages.sh"

step "12/14 Regenerate Slackware package metadata" \
    "$SCRIPTS/update-package-metadata.sh"

step "13/14 Prepare Slackware-T2 installer" \
    "$SCRIPTS/prepare-installer.sh"

rm -rf "$ROOT/output"
mkdir -p "$ROOT/output"
chown "$BUILD_USER:$BUILD_GROUP" "$ROOT/output"

step "14/14 Build hybrid BIOS/UEFI ISO" \
    run_user "$SCRIPTS/build-iso.sh"

[ -s "$OUTPUT_ISO" ] || {
    echo "Final ISO was not created." >&2
    exit 1
}

step "Verify SHA256" \
    run_user bash -c "cd '$ROOT/output' && sha256sum -c slackware-t2.iso.sha256"

BOOT_REPORT="$(run_user xorriso -indev "$OUTPUT_ISO" -report_el_torito plain 2>&1)"
printf '%s\n' "$BOOT_REPORT"
printf '%s\n' "$BOOT_REPORT" | grep -Eq 'BIOS[[:space:]]+y' || {
    echo "BIOS El Torito boot image was not detected." >&2
    exit 1
}
printf '%s\n' "$BOOT_REPORT" | grep -Eq 'UEFI[[:space:]]+y' || {
    echo "UEFI El Torito boot image was not detected." >&2
    exit 1
}

SYSTEM_REPORT="$(run_user xorriso -indev "$OUTPUT_ISO" -report_system_area plain 2>&1)"
printf '%s\n' "$SYSTEM_REPORT"
printf '%s\n' "$SYSTEM_REPORT" | grep -q 'MBR isohybrid' || {
    echo "Hybrid MBR was not detected." >&2
    exit 1
}
printf '%s\n' "$SYSTEM_REPORT" | grep -q 'GPT' || {
    echo "GPT hybrid information was not detected." >&2
    exit 1
}

A_LIST="$(run_user xorriso -indev "$OUTPUT_ISO" -ls /slackware64/a 2>/dev/null)"
K_LIST="$(run_user xorriso -indev "$OUTPUT_ISO" -ls /slackware64/k 2>/dev/null)"

if printf '%s\n' "$A_LIST" | grep -q 'elilo-.*\.txz'; then
    echo "ELILO package is still present in the final ISO." >&2
    exit 1
fi
printf '%s\n' "$A_LIST" | grep -q 'kernel-huge-.*-1_t2.txz' || {
    echo "T2 kernel-huge package is missing from the final ISO." >&2
    exit 1
}
printf '%s\n' "$A_LIST" | grep -q 'kernel-modules-.*-1_t2.txz' || {
    echo "T2 kernel-modules package is missing from the final ISO." >&2
    exit 1
}
printf '%s\n' "$A_LIST" | grep -q 't2-support-.*-1_t2.txz' || {
    echo "t2-support package is missing from the final ISO." >&2
    exit 1
}
printf '%s\n' "$A_LIST" | grep -q 'grub-2\.12-x86_64-1_slack15\.0\.txz' || {
    echo "Slackware GRUB package is missing from the final ISO." >&2
    exit 1
}
printf '%s\n' "$K_LIST" | grep -q 'kernel-source-.*-1_t2.txz' || {
    echo "T2 kernel-source package is missing from the final ISO." >&2
    exit 1
}

grep -q '^grub:ADD$' "$ROOT/iso-root/slackware64/a/tagfile" || {
    echo "GRUB is not marked ADD in the a-series tagfile." >&2
    exit 1
}
grep -q '^elilo:SKP$' "$ROOT/iso-root/slackware64/a/tagfile" || {
    echo "ELILO is not marked SKP in the a-series tagfile." >&2
    exit 1
}
grep -q '^lilo:SKP$' "$ROOT/iso-root/slackware64/a/tagfile" || {
    echo "LILO is not marked SKP in the a-series tagfile." >&2
    exit 1
}

VERIFY="$ROOT/build/verify"
rm -rf "$VERIFY"
mkdir -p "$VERIFY"
chown "$BUILD_USER:$BUILD_GROUP" "$VERIFY"

run_user xorriso -osirrox on \
    -indev "$OUTPUT_ISO" \
    -extract /isolinux/initrd.img "$VERIFY/initrd.img" >/dev/null 2>&1

xzcat "$VERIFY/initrd.img" | cpio -it 2>/dev/null | grep '^usr/lib/setup/SeTt2$' >/dev/null || {
    echo "SeTt2 is missing from the final installer initrd." >&2
    exit 1
}

SETUP_TEXT="$(xzcat "$VERIFY/initrd.img" | cpio -i --to-stdout usr/lib/setup/setup 2>/dev/null)"
SETT2_TEXT="$(xzcat "$VERIFY/initrd.img" | cpio -i --to-stdout usr/lib/setup/SeTt2 2>/dev/null)"

[ "$(printf '%s\n' "$SETUP_TEXT" | grep -c '/usr/lib/setup/SeTt2')" -eq 1 ] || {
    echo "Installer setup does not contain exactly one SeTt2 hook." >&2
    exit 1
}

printf '%s\n' "$SETUP_TEXT" | grep -q 'setup\.liloconfig' || {
    echo "Installer does not contain the LILO suppression logic." >&2
    exit 1
}
printf '%s\n' "$SETUP_TEXT" | grep -q 'setup\.ll\.eliloconfig' || {
    echo "Installer does not contain the ELILO suppression logic." >&2
    exit 1
}
printf '%s\n' "$SETT2_TEXT" | grep -q -- '--no-nvram' || {
    echo "SeTt2 does not install GRUB with --no-nvram." >&2
    exit 1
}
printf '%s\n' "$SETT2_TEXT" | grep -q -- '--removable' || {
    echo "SeTt2 does not install GRUB in removable EFI mode." >&2
    exit 1
}
printf '%s\n' "$SETT2_TEXT" | grep -q 'BOOTX64.EFI' || {
    echo "SeTt2 does not verify the removable EFI loader." >&2
    exit 1
}

printf '%s\n' "$SETT2_TEXT" | grep -q 'intel_iommu=on iommu=pt pm_async=off' || {
    echo "SeTt2 does not contain the required T2 kernel parameters." >&2
    exit 1
}

rm -rf "$VERIFY"

chown -R "$BUILD_USER:$BUILD_GROUP" "$ROOT/output"

printf '\nSlackware-T2 build and structural verification completed successfully.\n'
printf 'ISO: %s\n' "$OUTPUT_ISO"
printf 'SHA256: %s.sha256\n' "$OUTPUT_ISO"
