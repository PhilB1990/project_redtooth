#!/bin/bash
# Auto-build script for project_redtooth BeagleBone Black

set -e

REPO_DIR="${HOME}/repo/project_redtooth"
POKY_DIR="${REPO_DIR}/poky"
BUILD_DIR="${REPO_DIR}/build-bbb"
IMAGE="core-image-base"

# Parse command line arguments
CLEAN=false
SDK=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--clean)
            CLEAN=true
            shift
            ;;
        --sdk)
            SDK=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [-c|--clean] [--sdk]"
            echo "  -c, --clean  Clean the build before building"
            echo "  --sdk        Build SDK in addition to image"
            exit 1
            ;;
    esac
done

echo "=== BeagleBone Black Yocto Build ==="
echo "Poky:  ${POKY_DIR}"
echo "Build: ${BUILD_DIR}"
echo "Image: ${IMAGE}"
echo ""

# Source the build environment from outside poky
echo "Sourcing build environment..."
cd "${POKY_DIR}"
source oe-init-build-env "${BUILD_DIR}"

# Apply our custom conf files (overwrite defaults with our BeagleBone config)
echo "Applying BeagleBone configuration..."
cp "${REPO_DIR}/conf/local.conf" "${BUILD_DIR}/conf/local.conf"
sed -e "s|##OEROOT##|${POKY_DIR}|g" \
    -e "s|##REPOROOT##|${REPO_DIR}|g" \
    "${REPO_DIR}/conf/bblayers.conf" > "${BUILD_DIR}/conf/bblayers.conf"

# Clean if requested
if [ "$CLEAN" = true ]; then
    echo ""
    echo "Cleaning build..."
    bitbake -c cleanall ${IMAGE}
    echo "Clean complete!"
    echo ""
fi

echo ""
echo "Starting bitbake build..."
echo "This will take 2-4 hours on first build..."
echo ""

if [ "$SDK" = true ]; then
    bitbake ${IMAGE} -c populate_sdk
else
    bitbake ${IMAGE}
fi

echo ""
echo "=== Build Complete! ==="
echo ""
echo "Your image is at:"
echo "${BUILD_DIR}/tmp/deploy/images/beaglebone-yocto/"
echo ""
echo "Image files:"
ls -lh "${BUILD_DIR}/tmp/deploy/images/beaglebone-yocto/"*.wic* 2>/dev/null || echo "No .wic files found"
echo ""
