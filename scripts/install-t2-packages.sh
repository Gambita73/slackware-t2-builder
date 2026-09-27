#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGES="$ROOT/packages"
A_SERIES="$ROOT/iso-root/slackware64/a"
K_SERIES="$ROOT/iso-root/slackware64/k"

mapfile -t HUGE < <(find "$PACKAGES" -maxdepth 1 -type f -name 'kernel-huge-*-1_t2.txz')
mapfile -t MODULES < <(find "$PACKAGES" -maxdepth 1 -type f -name 'kernel-modules-*-1_t2.txz')
mapfile -t SOURCE < <(find "$PACKAGES" -maxdepth 1 -type f -name 'kernel-source-*-1_t2.txz')
mapfile -t SUPPORT < <(find "$PACKAGES" -maxdepth 1 -type f -name 't2-support-*-1_t2.txz')
mapfile -t GRUB < <(find "$PACKAGES" -maxdepth 1 -type f -name 'grub-*-x86_64-*_slack15.0.txz')

[ "${#HUGE[@]}" -eq 1 ] || { echo "Expected exactly one kernel-huge T2 package." >&2; exit 1; }
[ "${#MODULES[@]}" -eq 1 ] || { echo "Expected exactly one kernel-modules T2 package." >&2; exit 1; }
[ "${#SOURCE[@]}" -eq 1 ] || { echo "Expected exactly one kernel-source T2 package." >&2; exit 1; }
[ "${#SUPPORT[@]}" -eq 1 ] || { echo "Expected exactly one t2-support package." >&2; exit 1; }
[ "${#GRUB[@]}" -eq 1 ] || { echo "Expected exactly one Slackware 15.0 GRUB package." >&2; exit 1; }

GRUB_TXT="${GRUB[0]%.txz}.txt"
[ -f "$GRUB_TXT" ] || { echo "Missing Slackware GRUB package description." >&2; exit 1; }

rm -f "$A_SERIES"/kernel-huge-*.txz "$A_SERIES"/kernel-huge-*.txt "$A_SERIES"/kernel-huge-*.txz.asc
rm -f "$A_SERIES"/kernel-modules-*.txz "$A_SERIES"/kernel-modules-*.txt "$A_SERIES"/kernel-modules-*.txz.asc
rm -f "$A_SERIES"/kernel-generic-*.txz "$A_SERIES"/kernel-generic-*.txt "$A_SERIES"/kernel-generic-*.txz.asc
rm -f "$K_SERIES"/kernel-source-*.txz "$K_SERIES"/kernel-source-*.txt "$K_SERIES"/kernel-source-*.txz.asc
rm -f "$A_SERIES"/t2-support-*.txz "$A_SERIES"/t2-support-*.txt "$A_SERIES"/t2-support-*.txz.asc
rm -f "$A_SERIES"/grub-*.txz "$A_SERIES"/grub-*.txt "$A_SERIES"/grub-*.txz.asc
rm -f "$A_SERIES"/elilo-*.txz "$A_SERIES"/elilo-*.txt "$A_SERIES"/elilo-*.txz.asc

cp -a "${HUGE[0]}" "$A_SERIES/"
cp -a "${MODULES[0]}" "$A_SERIES/"
cp -a "${SUPPORT[0]}" "$A_SERIES/"
cp -a "${GRUB[0]}" "$A_SERIES/"
cp -a "$GRUB_TXT" "$A_SERIES/"
cp -a "${SOURCE[0]}" "$K_SERIES/"

sed -i 's/^kernel-generic:.*$/kernel-generic:SKP/' "$A_SERIES/tagfile"
sed -i 's/^kernel-huge:.*$/kernel-huge:ADD/' "$A_SERIES/tagfile"
sed -i 's/^kernel-modules:.*$/kernel-modules:ADD/' "$A_SERIES/tagfile"
sed -i 's/^elilo:.*$/elilo:SKP/' "$A_SERIES/tagfile"
sed -i 's/^lilo:.*$/lilo:SKP/' "$A_SERIES/tagfile"

if grep -q '^grub:' "$A_SERIES/tagfile"; then
    sed -i 's/^grub:.*$/grub:ADD/' "$A_SERIES/tagfile"
elif grep -q '^elilo:' "$A_SERIES/tagfile"; then
    sed -i '/^elilo:/a grub:ADD' "$A_SERIES/tagfile"
else
    printf '%s\n' 'grub:ADD' >> "$A_SERIES/tagfile"
fi

if grep -q '^t2-support:' "$A_SERIES/tagfile"; then
    sed -i 's/^t2-support:.*$/t2-support:ADD/' "$A_SERIES/tagfile"
else
    sed -i '/^kernel-modules:ADD$/a t2-support:ADD' "$A_SERIES/tagfile"
fi

sed -i 's/^kernel-source:.*$/kernel-source:REC/' "$K_SERIES/tagfile"

echo "Installed T2 packages into Slackware package tree:"
basename "${HUGE[0]}"
basename "${MODULES[0]}"
basename "${SOURCE[0]}"
basename "${SUPPORT[0]}"
basename "${GRUB[0]}"
