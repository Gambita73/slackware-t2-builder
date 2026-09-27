#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
rm -rf "$ROOT/staging-t2"
mkdir -p "$ROOT/staging-t2/usr/sbin"
mkdir -p "$ROOT/staging-t2/etc/rc.d"
mkdir -p "$ROOT/staging-t2/etc/udev/rules.d"
mkdir -p "$ROOT/staging-t2/etc/NetworkManager/conf.d"
mkdir -p "$ROOT/staging-t2/usr/share/libinput"
mkdir -p "$ROOT/staging-t2/usr/share/X11/xorg.conf.d"
cd "$ROOT/staging-t2/"

#Copy and stage the configs
cp "$ROOT/t2-config/99-network-t2-ncm.conf" "etc/NetworkManager/conf.d"
cp "$ROOT/t2-config/99-network-t2-ncm.rules" "etc/udev/rules.d/"
cp "$ROOT/t2-config/90-t2-touchpad.quirks" "usr/share/libinput/"
cp "$ROOT/t2-config/99-t2-touchpad.conf" "usr/share/X11/xorg.conf.d/"
cp "$ROOT/build/t2fanrd/T2FanRD/target/x86_64-unknown-linux-musl/release/t2fanrd" "usr/sbin"
cp "$ROOT/t2-config/rc.t2fanrd" "etc/rc.d"
cp "$ROOT/t2-config/rc.t2firmware" "etc/rc.d"
cp "$ROOT/build/apple-firmware/firmware.sh" "usr/sbin/get-apple-firmware"

