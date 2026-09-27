#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

#Get the firmware extraction script
mkdir -p "$ROOT/build/apple-firmware" && cd "$ROOT/build/apple-firmware"
wget -O firmware.sh https://wiki.t2linux.org/tools/firmware.sh
chmod +x firmware.sh

