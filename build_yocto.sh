#!/bin/bash
# Auto-build script for project_redtooth BeagleBone Black

set -e

PROJECT_DIR="${HOME}/repo/project_redtooth/poky"
BUILD_DIR="build-bbb"
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
echo "Project: ${PROJECT_DIR}"
echo "Build: ${BUILD_DIR}"
echo "Image: ${IMAGE}"
echo ""

# Navigate to project
cd "${PROJECT_DIR}"

# Source the build environment
echo "Sourcing build environment..."
source oe-init-build-env "${BUILD_DIR}"

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
echo "${PROJECT_DIR}/${BUILD_DIR}/tmp/deploy/images/beaglebone-yocto/"
echo ""
echo "Image files:"
ls -lh "${PROJECT_DIR}/${BUILD_DIR}/tmp/deploy/images/beaglebone-yocto/"*.wic* 2>/dev/null || echo "No .wic files found"
echo ""
