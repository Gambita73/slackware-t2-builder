#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGINGSRC="$ROOT/staging-source"
rm -rf "$STAGINGSRC"
mkdir -p "$STAGINGSRC/usr/src"

cd "$ROOT/build"
pkgname="$(ls -d */ | grep "linux-" | tr -d "/")"

#Copy source to staging-source
cp -a "$pkgname" "$STAGINGSRC/usr/src/"
