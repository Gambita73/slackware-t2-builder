# Slackware-T2 Builder

Build a Slackware64 15.0 installer ISO for Intel Macs with the Apple T2 security chip.

The builder takes the official Slackware64 15.0 DVD ISO and turns it into an installer that runs on T2 Macs and produces a system that boots and works on them: a kernel with the [t2linux](https://wiki.t2linux.org) patches, a GRUB setup the Mac's firmware can start, and a support package for the T2 hardware.

The ISO contains no Apple firmware, so it can be shared. Each Mac gets its Wi-Fi and Bluetooth firmware from Apple's own copy after installation.

## What's included

- **Kernel**: the latest kernel supported by the t2linux kernel releases at build time, built from Slackware's `huge` configuration plus the t2linux patches. It replaces `kernel-huge`, `kernel-modules` and `kernel-source`; `kernel-generic` is removed.
- **Drivers**: t2bce (keyboard, trackpad, Touch Bar and audio), Broadcom Wi-Fi (`brcmfmac`) and Bluetooth (`hci_bcm4377`), and APFS.
- **Installer**: the Slackware installer runs on the T2 kernel, so the built-in keyboard works during setup.
- **Boot loader**: GRUB 2.12 (from Slackware 15.0 `/testing`) installed to `EFI/BOOT/BOOTX64.EFI` on the EFI partition, without writing to the Mac's NVRAM. LILO and ELILO are not used.
- **EFI partition checks**: at the end of setup the EFI partition is checked and prepared so the Mac's firmware can read it.
- **Kernel parameters**: `intel_iommu=on iommu=pt pm_async=off`.
- **`t2-support` package**:
  - [T2FanRD](https://github.com/GnomedDev/T2FanRD) fan daemon, started at boot
  - `t2bce_vhci` loaded at boot
  - udev and NetworkManager settings for the T2's internal network interface
  - trackpad settings for libinput, for both X11 and Wayland
  - automatic Wi-Fi and Bluetooth firmware setup, plus the t2linux `get-apple-firmware` script

Not included: the audio configuration files (`apple-t2-audio-config`) and `tiny-dfr` for Touch Bar customization.

## Supported Macs

Intel Macs with the Apple T2 chip. See [Apple's list](https://support.apple.com/en-us/HT208862) and the t2linux [hardware status page](https://wiki.t2linux.org/state/).

## Building

### Requirements

- An x86_64 Linux machine with internet access and `sudo`.
- Plenty of free disk space. The kernel is built from source, and the whole build tree is packaged as `kernel-source`.
- The [Slackware64 15.0 DVD ISO](https://mirrors.slackware.com/slackware/slackware-iso/slackware64-15.0-iso/).
- These commands: `git curl wget gpg make patch xz xzcat cpio tar find sha256sum md5sum bzip2 xorriso runuser getent nproc`.
- A kernel build toolchain (gcc, bc, flex, bison, perl, and the libelf and OpenSSL development files).
- `isohdpfx.bin` from syslinux.
- `rustup` and `cargo` for your normal user, to build T2FanRD.

### Build

Run the build from your normal user account with `sudo`. It builds as your user and only uses root where needed.

```sh
sudo mkdir -p /mnt/slackware
sudo mount -o loop slackware64-15.0-install-dvd.iso /mnt/slackware
sudo ./build.sh
```

The ISO is written to `output/slackware-t2.iso`, with its checksum in `output/slackware-t2.iso.sha256`.

To use a Slackware tree somewhere else:

```sh
sudo env SLACKWARE_SOURCE=/path/to/slackware ./build.sh
```

### Build steps

| Step | Script | What it does |
|------|--------|--------------|
| 1 | `build-kernel.sh` | Downloads and verifies the kernel, applies the t2linux patches, builds it |
| 2 | `stage-kernel.sh` | Stages the kernel image and modules |
| 3 | `staging-source.sh` | Stages the kernel source |
| 4 | `build-t2fanrd.sh` | Builds T2FanRD |
| 5 | `fetch-apple-firmware.sh` | Downloads the t2linux firmware script |
| 6 | `fetch-grub.sh` | Downloads and verifies the Slackware GRUB package |
| 7 | `create-t2-config.sh` | Writes the configuration files for the support package |
| 8 | `stage-t2-tools.sh` | Stages the support package contents |
| 9 | `build-kernel-packages.sh` | Builds the kernel packages |
| 10 | `build-t2-support-package.sh` | Builds the `t2-support` package |
| 11 | `install-t2-packages.sh` | Adds the packages to the ISO tree and updates the tagfiles |
| 12 | `update-package-metadata.sh` | Regenerates the Slackware package metadata |
| 13 | `prepare-installer.sh` | Puts the T2 kernel, modules and setup step into the installer |
| 14 | `build-iso.sh` | Builds the hybrid BIOS/UEFI ISO |

After the ISO is built, `build.sh` checks its boot records, packages and installer.

## Installing

### Before you start

1. Back up your data. Installing changes the partitions on your SSD.
2. Turn off Secure Boot. Power on holding **Command-R** to start macOS Recovery, then open **Utilities → Startup Security Utility** and set:
   - **Secure Boot**: No Security
   - **Allowed Boot Media**: Allow booting from external or removable media
3. Write the ISO to a USB stick of 8 GB or more:

   ```sh
   # Linux
   sudo dd if=output/slackware-t2.iso of=/dev/sdX bs=4M status=progress conv=fsync

   # macOS
   sudo dd if=slackware-t2.iso of=/dev/rdiskX bs=1m
   ```

### Install

1. Plug in the USB stick, power on holding **Option**, and choose **EFI Boot**.
2. Log in as `root` and partition the SSD with `cfdisk`:
   - Use a **GPT** partition table.
   - For the EFI partition, keep the Mac's own EFI partition or create one of at least 512 MB with the type **EFI System**.
   - Create your Linux partitions.
   - To keep macOS, don't delete its partitions. Wi-Fi is then set up automatically on first boot.
3. Run `setup` and install as usual. A full installation is recommended.
4. At the end, setup installs GRUB. If the EFI partition can't be used, setup stops and says what to change.
5. Reboot and remove the USB stick.

### First boot

The Mac doesn't start a newly installed Linux system by itself. Power on holding **Option**, then hold **Control** and press **Enter** on **EFI Boot**. This makes Slackware the default startup disk, so later boots go straight to GRUB.

### Wi-Fi and Bluetooth

Apple's Wi-Fi and Bluetooth firmware can't be shipped on the ISO. On each boot until it's installed, Slackware-T2 looks for it in two places:

1. `firmware-raw.tar.gz` on the EFI partition, a copy made from macOS Recovery or with Method 1 of the t2linux Wi-Fi guide.
2. The macOS partition on the internal SSD.

When it finds the firmware, it installs it and turns on Wi-Fi and Bluetooth.

If macOS has been erased, make the copy once from macOS Recovery:

1. Power on holding **Command-Option-R** and choose your Wi-Fi network.
2. When Recovery has loaded, open **Utilities → Terminal** and run:

   ```sh
   diskutil mount disk0s1 && tar -czf /Volumes/EFI/firmware-raw.tar.gz -C /usr/share/firmware .
   ```

   `disk0s1` is the EFI partition when it's the first partition on the SSD.
3. Restart into Slackware.

The copy stays on the EFI partition, so later reinstalls pick it up automatically.

The iMac19,1, iMac19,2 and iMacPro1,1 need extra files that this automatic setup doesn't install yet. See the [t2linux Wi-Fi guide](https://wiki.t2linux.org/guides/wifi-bluetooth/) for these models.

## Troubleshooting

- **The Mac shows a question mark or `support.apple.com/mac/startup`**: hold **Option** at power-on and choose **EFI Boot**. Hold **Control** while pressing **Enter** to make it the default.
- **No EFI Boot icon for the SSD**: the EFI partition must be on a GPT disk, have the type **EFI System**, and be formatted as FAT. Setup checks and fixes the format, and stops if the partition table or type is wrong.
- **No Wi-Fi**: check that `/boot/efi/firmware-raw.tar.gz` exists, or that macOS is still on the SSD. Then run `/etc/rc.d/rc.t2firmware` as root, and `dmesg | grep brcmfmac` to see which firmware the driver asked for.
- **Trackpad settings**: tap-to-click and other options are in **System Settings → Input Devices → Touchpad**.

## Credits

- [t2linux](https://wiki.t2linux.org): kernel patches, documentation and the Wi-Fi firmware script.
- [T2FanRD](https://github.com/GnomedDev/T2FanRD): fan daemon.
- [Slackware Linux](http://www.slackware.com): the distribution and the GRUB package.

## Disclaimer

This project is not affiliated with Apple, Slackware or t2linux. Use it at your own risk and back up your data before installing.
