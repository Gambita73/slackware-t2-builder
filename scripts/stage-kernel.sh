#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGING="$ROOT/staging"
BUILD="$ROOT/build"

rm -rf "$STAGING"
mkdir -p "$STAGING/boot"

#Copy the boot related artifacts in the staging directory
cd "$BUILD"
pkgname=$(ls -d */ | grep "linux-" | tr -d "/")

cd "$BUILD/$pkgname"
cp .config "$STAGING/boot/config"
cp System.map "$STAGING/boot/System.map"
cp arch/x86/boot/bzImage "$STAGING/boot/bzImage"

#Install the modules
make modules_install INSTALL_MOD_PATH="$STAGING"

