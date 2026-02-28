#!/bin/bash
# Flash BeagleBone Black eMMC over Ethernet via SSH

set -e

REPO_DIR="${HOME}/repo/project_redtooth"
BUILD_DIR="${REPO_DIR}/build-bbb"
IMAGE_DIR="${BUILD_DIR}/tmp/deploy/images/beaglebone-yocto"
BBB_HOSTNAME="beaglebone-yocto"
BBB_USB_IP="192.168.7.2"
BBB_USER="root"
BBB_EMMC="/dev/mmcblk1"  # eMMC on BeagleBone Black (mmcblk0 = SD card)
BBB_MACS="1c:ba:8c d4:94:a1 c8:a0:30 54:4a:16 90:59:af"

# Parse arguments
BBB_IP=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--ip)
            BBB_IP="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [-i|--ip <ip-address>]"
            exit 1
            ;;
    esac
done

# Auto-detect BBB IP if not specified
if [ -z "$BBB_IP" ]; then
    echo "=== Detecting BeagleBone Black ==="

    if ping -c 1 -W 1 "${BBB_USB_IP}" &>/dev/null; then
        BBB_IP="${BBB_USB_IP}"
        echo "  Found via USB: ${BBB_IP}"
    fi

    if [ -z "$BBB_IP" ]; then
        MDNS_IP=$(avahi-resolve-host-name "${BBB_HOSTNAME}.local" 2>/dev/null | awk '{print $2}')
        if [ -n "${MDNS_IP}" ]; then
            BBB_IP="${MDNS_IP}"
            echo "  Found via mDNS: ${BBB_IP}"
        fi
    fi

    if [ -z "$BBB_IP" ] && command -v arp-scan &>/dev/null; then
        SUBNET=$(ip route | grep -v default | grep src | awk '{print $1}' | head -1)
        if [ -n "${SUBNET}" ]; then
            SCAN_RESULT=$(sudo arp-scan "${SUBNET}" 2>/dev/null)
            for OUI in ${BBB_MACS}; do
                MATCH=$(echo "${SCAN_RESULT}" | grep -i "${OUI}" | awk '{print $1}' | head -1)
                if [ -n "${MATCH}" ]; then
                    BBB_IP="${MATCH}"
                    echo "  Found via MAC: ${BBB_IP}"
                    break
                fi
            done
        fi
    fi
fi

if [ -z "$BBB_IP" ]; then
    echo "ERROR: BeagleBone Black not found on network."
    echo "Make sure it is powered on and connected via Ethernet."
    echo "Or specify IP manually: $0 --ip <ip-address>"
    exit 1
fi

# Find the latest image (resolve symlink to get real file and size)
IMAGE_LINK=$(ls -t "${IMAGE_DIR}"/core-image-base-beaglebone-yocto*.rootfs.wic 2>/dev/null | head -1)

if [ ! -f "$IMAGE_LINK" ]; then
    echo "ERROR: Image file not found in ${IMAGE_DIR}"
    echo "Run ./build_yocto.sh first."
    exit 1
fi

IMAGE_FILE=$(readlink -f "${IMAGE_LINK}")

echo ""
echo "=== BeagleBone Black eMMC Flash over Ethernet ==="
echo ""
echo "Target:     ${BBB_USER}@${BBB_IP}"
echo "eMMC:       ${BBB_EMMC}"
echo "Image:      $(basename ${IMAGE_FILE})"
echo "Image Size: $(du -h "${IMAGE_FILE}" | cut -f1)"
echo ""
echo "WARNING: This will COMPLETELY ERASE the eMMC (${BBB_EMMC}) on the BeagleBone!"
echo ""
read -p "Are you absolutely sure? Type 'yes' to continue: " -r
if [[ ! $REPLY == "yes" ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Streaming image to eMMC over Ethernet..."
echo "This may take a few minutes..."
echo ""

# Stream image directly into eMMC via SSH (no tmp space needed on the board)
ssh -o StrictHostKeyChecking=no "${BBB_USER}@${BBB_IP}" \
    "dd of=${BBB_EMMC} bs=4M status=progress conv=fsync" < "${IMAGE_FILE}"

echo ""
echo "=== eMMC Flash Complete! ==="
echo ""
echo "Next steps:"
echo "  1. Remove the SD card from the BeagleBone"
echo "  2. Run: ssh ${BBB_USER}@${BBB_IP} reboot"
echo "  3. BeagleBone will boot from eMMC automatically"
echo ""
