#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ISO="$ROOT/iso-root"
TREE="$ISO/slackware64"
PACKAGES_TXT="$ISO/PACKAGES.TXT"

rm -f \
    "$TREE/a/kernel-huge-5.15.19-x86_64-2.txt" \
    "$TREE/a/kernel-huge-5.15.19-x86_64-2.txz.asc" \
    "$TREE/a/kernel-modules-5.15.19-x86_64-2.txt" \
    "$TREE/a/kernel-modules-5.15.19-x86_64-2.txz.asc" \
    "$TREE/a/kernel-generic-5.15.19-x86_64-2.txt" \
    "$TREE/a/kernel-generic-5.15.19-x86_64-2.txz.asc" \
    "$TREE/k/kernel-source-5.15.19-noarch-2.txt" \
    "$TREE/k/kernel-source-5.15.19-noarch-2.txz.asc"

rm -f "$TREE/CHECKSUMS.md5.asc"

for PKG in \
    "$TREE"/a/kernel-huge-*-1_t2.txz \
    "$TREE"/a/kernel-modules-*-1_t2.txz \
    "$TREE"/a/t2-support-*-1_t2.txz \
    "$TREE"/k/kernel-source-*-1_t2.txz
do
    [ -f "$PKG" ] || continue

    TXT="${PKG%.txz}.txt"

    tar -xOf "$PKG" ./install/slack-desc 2>/dev/null |
        grep -v '^#' |
        grep -v 'handy-ruler' |
        sed '/^[[:space:]]*$/d' > "$TXT"
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

: > "$PACKAGES_TXT"

printf 'PACKAGES.TXT;  %s\n\n' "$(date -u)" >> "$PACKAGES_TXT"
printf 'This file provides details on the Slackware packages found\n' >> "$PACKAGES_TXT"
printf 'in the ./slackware64/ directory.\n\n' >> "$PACKAGES_TXT"

TOTAL_COMPRESSED=0
TOTAL_UNCOMPRESSED=0

while IFS= read -r PKG; do
    REL="${PKG#$ISO/}"
    DIR="$(dirname "$REL")"
    NAME="$(basename "$PKG")"

    COMPRESSED_K="$(du -k "$PKG" | awk '{print $1}')"

    rm -rf "$TMP/pkg"
    mkdir -p "$TMP/pkg"
    tar -xf "$PKG" -C "$TMP/pkg"

    UNCOMPRESSED_K="$(du -sk "$TMP/pkg" | awk '{print $1}')"

    TOTAL_COMPRESSED=$((TOTAL_COMPRESSED + COMPRESSED_K))
    TOTAL_UNCOMPRESSED=$((TOTAL_UNCOMPRESSED + UNCOMPRESSED_K))

    printf 'PACKAGE NAME:  %s\n' "$NAME" >> "$PACKAGES_TXT"
    printf 'PACKAGE LOCATION:  ./%s\n' "$DIR" >> "$PACKAGES_TXT"
    printf 'PACKAGE SIZE (compressed):  %s K\n' "$COMPRESSED_K" >> "$PACKAGES_TXT"
    printf 'PACKAGE SIZE (uncompressed):  %s K\n' "$UNCOMPRESSED_K" >> "$PACKAGES_TXT"
    printf 'PACKAGE DESCRIPTION:\n' >> "$PACKAGES_TXT"

    DESC="${PKG%.txz}.txt"

    if [ -r "$DESC" ]; then
        cat "$DESC" >> "$PACKAGES_TXT"
    else
        tar -xOf "$PKG" ./install/slack-desc 2>/dev/null |
            grep -v '^#' |
            grep -v 'handy-ruler' |
            sed '/^[[:space:]]*$/d' >> "$PACKAGES_TXT" || true
    fi

    printf '\n' >> "$PACKAGES_TXT"

done < <(
    find "$TREE" -mindepth 2 -maxdepth 2 -type f \
        \( -name '*.txz' -o -name '*.tgz' -o -name '*.tbz' -o -name '*.tlz' \) |
    sort
)

COMPRESSED_MB=$((TOTAL_COMPRESSED / 1024))
UNCOMPRESSED_MB=$((TOTAL_UNCOMPRESSED / 1024))

HEADER="$TMP/header"

{
    printf 'PACKAGES.TXT;  %s\n\n' "$(date -u)"
    printf 'This file provides details on the Slackware packages found\n'
    printf 'in the ./slackware64/ directory.\n\n'
    printf 'Total size of all packages (compressed):  %s MB\n' "$COMPRESSED_MB"
    printf 'Total size of all packages (uncompressed):  %s MB\n\n\n' "$UNCOMPRESSED_MB"
} > "$HEADER"

awk '
    /^PACKAGE NAME:/ { found=1 }
    found { print }
' "$PACKAGES_TXT" > "$TMP/entries"

cat "$HEADER" "$TMP/entries" > "$PACKAGES_TXT"

(
    cd "$TREE"

    {
        date -u
        echo
        echo "Here is the file list for this directory.  If you are using a"
        echo "mirror site and find missing or extra files in the disk"
        echo "subdirectories, please have the archive administrator refresh"
        echo "the mirror."
        echo

        find . -mindepth 1 -printf '%p\n' |
            sort |
            while IFS= read -r FILE; do
                ls -ld --time-style='+%Y-%m-%d %H:%M' "$FILE"
            done
    } > FILE_LIST.new

    mv FILE_LIST.new FILE_LIST
)

(
    cd "$TREE"

    : > CHECKSUMS.md5.new

    find . -type f \
        ! -name 'CHECKSUMS.md5' \
        ! -name 'CHECKSUMS.md5.asc' \
        ! -name 'FILE_LIST' \
        ! -name 'MANIFEST.bz2' |
        sort |
        while IFS= read -r FILE; do
            md5sum "$FILE"
        done >> CHECKSUMS.md5.new

    mv CHECKSUMS.md5.new CHECKSUMS.md5
)

(
    cd "$TREE"

    MANIFEST_TMP="$TMP/MANIFEST"

    : > "$MANIFEST_TMP"

    find . -mindepth 2 -maxdepth 2 -type f \
        \( -name '*.txz' -o -name '*.tgz' -o -name '*.tbz' -o -name '*.tlz' \) |
        sort |
        while IFS= read -r PKG; do
            echo "++========================================" >> "$MANIFEST_TMP"
            echo "||   Package: $PKG" >> "$MANIFEST_TMP"
            echo "++========================================" >> "$MANIFEST_TMP"
            tar -tvf "$PKG" >> "$MANIFEST_TMP"
            echo >> "$MANIFEST_TMP"
        done

    bzip2 -9c "$MANIFEST_TMP" > MANIFEST.bz2
)

(
    cd "$TREE"

    : > CHECKSUMS.md5.new

    find . -type f \
        ! -name 'CHECKSUMS.md5' \
        ! -name 'CHECKSUMS.md5.asc' |
        sort |
        while IFS= read -r FILE; do
            md5sum "$FILE"
        done >> CHECKSUMS.md5.new

    mv CHECKSUMS.md5.new CHECKSUMS.md5
)

echo "Slackware package metadata updated."
