#!/bin/bash
# Format SD card and flash BeagleBone Black image

set -e

REPO_DIR="${HOME}/repo/project_redtooth"
BUILD_DIR="${REPO_DIR}/build-bbb"
IMAGE_DIR="${BUILD_DIR}/tmp/deploy/images/beaglebone-yocto"

# Parse arguments
SD_DEVICE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--device)
            SD_DEVICE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [-d|--device /dev/sdX]"
            exit 1
            ;;
    esac
done

# Auto-detect SD card if not specified
if [ -z "$SD_DEVICE" ]; then
    echo "No device specified. Available removable devices:"
    lsblk -d -o NAME,SIZE,TRAN,MODEL | grep -i "usb\|sd" || true
    echo ""
    read -p "Enter device (e.g. /dev/sdb): " SD_DEVICE
fi

if [ ! -b "$SD_DEVICE" ]; then
    echo "ERROR: ${SD_DEVICE} is not a valid block device."
    exit 1
fi

# Find the image (resolve symlink to get real file and size)
IMAGE_LINK=$(ls -t "${IMAGE_DIR}"/core-image-base-beaglebone-yocto*.rootfs.wic 2>/dev/null | head -1)

if [ ! -f "$IMAGE_LINK" ]; then
    echo "ERROR: Image file not found in ${IMAGE_DIR}"
    exit 1
fi

IMAGE_FILE=$(readlink -f "${IMAGE_LINK}")

echo "=== BeagleBone Black SD Card Flash ==="
echo ""
echo "Target Device: ${SD_DEVICE}"
echo "Image File: $(basename ${IMAGE_FILE})"
echo "Image Size: $(du -h "${IMAGE_FILE}" | cut -f1)"
echo ""

# Safety check - show current device info
echo "Current device information:"
lsblk ${SD_DEVICE}
echo ""

# Final confirmation
echo "WARNING: This will COMPLETELY ERASE ${SD_DEVICE}!"
echo "All data on this device will be lost."
echo ""
read -p "Are you absolutely sure? Type 'yes' to continue: " -r
if [[ ! $REPLY == "yes" ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Starting SD card preparation..."
echo ""

# Unmount any mounted partitions
echo "Unmounting any mounted partitions..."
sudo umount ${SD_DEVICE}* 2>/dev/null || true

# Wipe the beginning of the disk to remove any existing partition table
echo "Wiping existing partition table..."
sudo dd if=/dev/zero of=${SD_DEVICE} bs=1M count=10 status=progress

# Sync to ensure writes complete
sync

echo ""
echo "Flashing image to SD card..."
echo "This will take several minutes..."
echo ""

# Flash the image
sudo dd if="${IMAGE_FILE}" of=${SD_DEVICE} bs=4M status=progress conv=fsync

# Final sync
sync

# Eject the SD card safely
echo "Ejecting SD card..."
sudo eject "${SD_DEVICE}"

echo ""
echo "=== Flash Complete! ==="
echo ""
echo "SD card is ready. Next steps:"
echo "1. Remove SD card from your PC"
echo "2. Insert SD card into BeagleBone Black"
echo "3. Hold down the USER/BOOT button (near SD slot)"
echo "4. Power on the BeagleBone while holding the button"
echo "5. Release button after ~5 seconds"
echo "6. BeagleBone will boot from SD card"
echo ""
echo "Your new image includes SSH server, so you can connect via:"
echo "  ssh root@<beaglebone-ip>"
echo ""
