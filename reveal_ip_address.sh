#!/bin/bash
# Detect BeagleBone Black IP address on the network

BBB_HOSTNAME="beaglebone-yocto"
BBB_USB_IP="192.168.7.2"

echo "=== BeagleBone Black IP Detection ==="
echo ""

# 1. Try USB connection first (fastest)
echo "Checking USB connection (${BBB_USB_IP})..."
if ping -c 1 -W 1 "${BBB_USB_IP}" &>/dev/null; then
    echo "  Found via USB: ${BBB_USB_IP}"
    BBB_IP="${BBB_USB_IP}"
fi

# 2. Try mDNS hostname (beaglebone.local)
echo "Checking mDNS (${BBB_HOSTNAME}.local)..."
MDNS_IP=$(avahi-resolve-host-name "${BBB_HOSTNAME}.local" 2>/dev/null | awk '{print $2}')
if [ -n "${MDNS_IP}" ]; then
    echo "  Found via mDNS: ${MDNS_IP}"
    BBB_IP="${MDNS_IP}"
fi

# 3. Scan local network by MAC address (Texas Instruments OUI for BeagleBone)
# Known TI/BeagleBone OUI prefixes
BBB_MACS="1c:ba:8c d4:94:a1 c8:a0:30 54:4a:16 90:59:af"
echo "Scanning local network by MAC address..."
SUBNET=$(ip route | grep -v default | grep src | awk '{print $1}' | head -1)

if [ -n "${SUBNET}" ]; then
    echo "  Scanning subnet ${SUBNET}..."
    if command -v arp-scan &>/dev/null; then
        SCAN_RESULT=$(sudo arp-scan "${SUBNET}" 2>/dev/null)
        for OUI in ${BBB_MACS}; do
            MATCH=$(echo "${SCAN_RESULT}" | grep -i "${OUI}" | awk '{print $1}' | head -1)
            if [ -n "${MATCH}" ]; then
                MAC=$(echo "${SCAN_RESULT}" | grep -i "${OUI}" | awk '{print $2}' | head -1)
                echo "  Found via MAC (${MAC}): ${MATCH}"
                BBB_IP="${MATCH}"
                break
            fi
        done
    else
        echo "  Install arp-scan for MAC-based detection: sudo apt install arp-scan"
    fi
fi

echo ""
if [ -n "${BBB_IP}" ]; then
    echo "BeagleBone Black found at: ${BBB_IP}"
    echo ""
    echo "Connect via SSH:"
    echo "  Custom Yocto image : ssh root@${BBB_IP}"
    echo "  Stock Debian image : ssh debian@${BBB_IP}  (password: temppwd)"
else
    echo "BeagleBone Black not found. Make sure it is:"
    echo "  - Powered on"
    echo "  - Connected via USB or Ethernet"
    echo "  - Running an image with SSH enabled"
fi
echo ""
