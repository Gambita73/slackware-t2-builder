#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ISOROOT="$ROOT/iso-root"

mkdir -p "$ROOT/build/"
cd "$ROOT/build/"

rm -rf patches
find . -maxdepth 1 -type d -name 'linux-*' -exec rm -rf {} +
rm -f linux-*.tar linux-*.tar.xz linux-*.tar.sign

#Copies the T2 pacthes for the kernel
git clone --depth=1 https://github.com/t2linux/linux-t2-patches patches

#It gets which kernel version is supported by the patches
pkgver=$(curl -sL https://github.com/t2linux/T2-Ubuntu-Kernel/releases/latest/ | grep "<title>Release" | awk -F " " '{print $2}' | cut -d "v" -f 2 | cut -d "-" -f 1)

[ -n "$pkgver" ] || {
    echo "Unable to determine the supported T2 kernel version." >&2
    exit 1
}

_srcname=linux-${pkgver}

#It gets the supported version of the kernel
wget https://www.kernel.org/pub/linux/kernel/v${pkgver//.*}.x/linux-${pkgver}.tar.xz

#It gets the signature and imports the keys
wget https://www.kernel.org/pub/linux/kernel/v${pkgver//.*}.x/linux-${pkgver}.tar.sign
gpg --list-packets linux-${pkgver}.tar.sign | grep -i keyid | awk '{print $NF}' | xargs gpg --recv-keys
xz --decompress linux-${pkgver}.tar.xz


if ! gpg --verify linux-${pkgver}.tar.sign linux-${pkgver}.tar;then
    echo "Verification failed"
    exit 1
fi

rm -f linux-${pkgver}.tar.sign

tar xf $_srcname.tar
cd $_srcname

#It applies the patches
for patch in ../patches/*.patch; do
    patch -Np1 < $patch
done

# We copy the config to the build directory and make
cp "$ISOROOT/kernels/huge.s/config" .config

make olddefconfig
scripts/config --module CONFIG_BT_HCIBCM4377
scripts/config --module CONFIG_HID_APPLETB_BL
scripts/config --module CONFIG_HID_APPLETB_KBD
scripts/config --module CONFIG_DRM_APPLETBDRM
scripts/config --module CONFIG_T2BCE_DMA
scripts/config --module CONFIG_T2BCE_CORE
scripts/config --module CONFIG_T2BCE_VHCI
scripts/config --module CONFIG_T2BCE_AUDIO
scripts/config --module CONFIG_APFS_FS
scripts/config --module CONFIG_BRCMFMAC
scripts/config --enable CONFIG_BRCMFMAC_PCIE
make olddefconfig
# Starts the kernel build
make -j"$(nproc)"

if make kernelrelease;then
    echo "The kernel compiled successfully!"
fi


