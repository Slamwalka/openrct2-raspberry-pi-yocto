#!/usr/bin/env bash
set -euo pipefail

if (($# != 2)); then
    echo "Usage: $0 <image.wic|image.wic.bz2> <whole-disk-device>" >&2
    echo "Example: $0 build/tmp/deploy/images/raspberrypi4-64/image.wic.bz2 /dev/sdX" >&2
    exit 2
fi

IMAGE=$1
DEVICE=$2

[[ -f "$IMAGE" && -r "$IMAGE" ]] || { echo "Image not found or unreadable: $IMAGE" >&2; exit 1; }
[[ "$DEVICE" == /dev/* && -b "$DEVICE" ]] || { echo "Target must be an existing block device under /dev: $DEVICE" >&2; exit 1; }
command -v lsblk >/dev/null || { echo "Required tool not found: lsblk" >&2; exit 1; }
command -v dd >/dev/null || { echo "Required tool not found: dd" >&2; exit 1; }

DEVICE_TYPE=$(lsblk -dnro TYPE "$DEVICE")
[[ "$DEVICE_TYPE" == disk ]] || { echo "Target must be a whole disk, not a partition (type: $DEVICE_TYPE)." >&2; exit 1; }

MOUNTED=$(lsblk -nrpo NAME,MOUNTPOINTS "$DEVICE" | awk 'NF > 1 { print }')
if [[ -n "$MOUNTED" ]]; then
    printf 'Target has mounted filesystems:\n%s\n' "$MOUNTED" >&2
    echo "Unmount its partitions first, then run this command again." >&2
    exit 1
fi

printf 'Image:  %s\nTarget: %s\n' "$IMAGE" "$DEVICE"
lsblk -o NAME,SIZE,MODEL,TYPE,MOUNTPOINTS "$DEVICE"
printf '\nThis permanently overwrites the target device and all its partitions.\n'
read -r -p "Type the exact device path ($DEVICE) to continue: " CONFIRM
[[ "$CONFIRM" == "$DEVICE" ]] || { echo "Confirmation did not match; nothing was written." >&2; exit 1; }

if [[ "$IMAGE" == *.wic.bz2 ]]; then
    command -v bzip2 >/dev/null || { echo "Required tool not found: bzip2" >&2; exit 1; }
    bzip2 -dc -- "$IMAGE" | sudo dd of="$DEVICE" bs=4M status=progress conv=fsync
else
    sudo dd if="$IMAGE" of="$DEVICE" bs=4M status=progress conv=fsync
fi

echo "Image written successfully. Eject the card before removing it."
