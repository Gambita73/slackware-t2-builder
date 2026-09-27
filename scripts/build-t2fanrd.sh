#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"

rm -rf "$BUILD/t2fanrd"
mkdir -p "$BUILD/t2fanrd"
cd "$BUILD/t2fanrd"

#Clone the github repo

git clone https://github.com/GnomedDev/T2FanRD

#Preparation for compilation && compilation
rustup target add x86_64-unknown-linux-musl
cd T2FanRD
cargo build --release --target x86_64-unknown-linux-musl


