#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
rm -rf "$ROOT/t2-config"
mkdir -p "$ROOT/t2-config"
cd "$ROOT/t2-config"

cat <<EOF > rc.modules.t2
#!/bin/sh

# Load Apple T2 BCE stack
/sbin/modprobe t2bce_vhci
EOF

cat <<EOF > 99-network-t2-ncm.rules
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="ac:de:48:00:11:22", NAME="t2_ncm"
EOF

cat <<EOF > 99-network-t2-ncm.conf
[main]
no-auto-default=t2_ncm
EOF

cat <<EOF > 90-t2-touchpad.quirks
[Apple T2 Touchpad]
MatchUdevType=touchpad
MatchBus=usb
MatchVendor=0x05AC
AttrPalmSizeThreshold=1600
EOF

cat <<EOF > 99-t2-touchpad.conf
Section "InputClass"
    Identifier "Apple T2 Touchpad"
    MatchIsTouchpad "on"
    Driver "libinput"
EndSection
EOF

#Creates the innit script for the fan daemon
cat <<'EOF' > rc.t2fanrd
#!/bin/bash

start () {
    if pidof t2fanrd >/dev/null;then
        echo "t2fanrd is working"
    else
        /usr/sbin/t2fanrd &
        echo "t2fanrd was started"
    fi
}

stop () {
    if pidof t2fanrd >/dev/null;then
        killall t2fanrd
        echo "t2fanrd was stopped"
    else
        echo "t2fanrd was not running"
    fi
}


status () {
    if pidof t2fanrd >/dev/null;then
        echo "t2fanrd is working"
    else
        echo "t2fanrd is not working"
    fi
}

restart () {
    stop
    start
}

#control logic
case $1 in
    
    start)
        echo "Starting the service"
        start
        ;;

    stop)
        echo "Stopping the service"
        stop
        ;;

    status)
        status
        ;;

    restart)
        restart
        ;;

    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac

EOF

chmod +x rc.t2fanrd

cat <<'EOF' > rc.t2firmware
#!/bin/bash

FIRMWARE_DIR=/lib/firmware/brcm
EFI_ARCHIVE=/boot/efi/firmware-raw.tar.gz

installed () {
    ls "$FIRMWARE_DIR"/brcmfmac*-pcie.apple,* >/dev/null 2>&1
}

installed && exit 0

mkdir -p "$FIRMWARE_DIR"

if [ -f "$EFI_ARCHIVE" ]; then
    WORKDIR="$(mktemp -d)"
    mkdir -p "$WORKDIR/raw"
    if tar -xzf "$EFI_ARCHIVE" -C "$WORKDIR/raw"; then
        eval "$(sed -n '/^rename_firmware () {/,/^}$/p' /usr/sbin/get-apple-firmware)"
        rename_firmware "$WORKDIR/raw" "$WORKDIR/firmware.tar" &&
            tar -xf "$WORKDIR/firmware.tar" -C "$FIRMWARE_DIR"
    fi
    rm -rf "$WORKDIR"
else
    if ! command -v sudo >/dev/null 2>&1; then
        sudo () { "$@"; }
        export -f sudo
    fi
    /usr/sbin/get-apple-firmware -i get_from_macos </dev/null >/dev/null 2>&1
fi

if ! installed; then
    echo "Apple Wi-Fi firmware was not found"
    exit 1
fi

/sbin/modprobe -r brcmfmac_wcc 2>/dev/null
/sbin/modprobe -r brcmfmac 2>/dev/null
/sbin/modprobe brcmfmac
/sbin/modprobe -r hci_bcm4377 2>/dev/null
/sbin/modprobe hci_bcm4377
echo "Apple Wi-Fi firmware was installed"
EOF

chmod +x rc.t2firmware

