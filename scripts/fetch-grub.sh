#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGES="$ROOT/packages"

PACKAGE="grub-2.12-x86_64-1_slack15.0.txz"
TXT_PACKAGE="grub-2.12-x86_64-1_slack15.0.txt"
URL="https://mirrors.slackware.com/slackware/slackware64-15.0/testing/packages"
SHA256="9b1d846e1339c80f036be498ead914040fd2a15cc0f40d5c3fb488ca4d605ccc"
TXT_SHA256="5be6f8ed956e62c0939fd5949f7e4c3fcaa53dae8862ec57ee4c9ce24eb0d9aa"

mkdir -p "$PACKAGES"
rm -f "$PACKAGES"/grub-*.txz "$PACKAGES"/grub-*.txt

wget -O "$PACKAGES/$PACKAGE" "$URL/$PACKAGE"
wget -O "$PACKAGES/$TXT_PACKAGE" "$URL/$TXT_PACKAGE"

printf '%s  %s\n' "$SHA256" "$PACKAGES/$PACKAGE" | sha256sum -c -
printf '%s  %s\n' "$TXT_SHA256" "$PACKAGES/$TXT_PACKAGE" | sha256sum -c -

echo "$PACKAGES/$PACKAGE"
