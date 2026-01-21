#!/bin/bash
#
# Build Linux Kernel for ARM64 using Docker with persistent volume
#
# Uses a Docker volume to persist build artifacts between runs.
# This enables incremental compilation - only changed files rebuild.
#
# First run: ~10-15 min (full compile)
# Config change: ~1-5 min (incremental)
# No change: ~10 sec (nothing to do)
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
OUTPUT="$BUILD_DIR/Image"

KERNEL_VERSION="6.6.70"
VOLUME_NAME="toylinux-kernel-build"
IMAGE_NAME="toylinux-kernel-env"

mkdir -p "$BUILD_DIR"

# Build the minimal Docker image (just build tools)
echo "[1/3] Ensuring build environment..."
docker build --platform linux/arm64 -t "$IMAGE_NAME" "$SCRIPT_DIR"

# Run the build with persistent volume
echo "[2/3] Building kernel (incremental)..."
docker run --rm --platform linux/arm64 \
    -v "$VOLUME_NAME:/build" \
    -v "$SCRIPT_DIR/config.sh:/config.sh:ro" \
    "$IMAGE_NAME" bash -c "
        set -e
        cd /build

        # Download source if not present
        if [[ ! -d linux ]]; then
            echo '    Downloading kernel source...'
            wget -q https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz
            tar xf linux-${KERNEL_VERSION}.tar.xz
            mv linux-${KERNEL_VERSION} linux
            rm linux-${KERNEL_VERSION}.tar.xz
        fi

        cd linux

        # Always run config.sh
        echo '    Configuring...'
        bash /config.sh

        # Compile (incremental - only rebuilds changed files)
        echo '    Compiling...'
        make -j\$(nproc) Image

        echo '    Done!'
    "

# Extract the kernel
echo "[3/3] Extracting kernel..."
docker run --rm --platform linux/arm64 \
    -v "$VOLUME_NAME:/build:ro" \
    -v "$BUILD_DIR:/out" \
    "$IMAGE_NAME" cp /build/linux/arch/arm64/boot/Image /out/Image

echo ""
echo "Built: $OUTPUT"
ls -lh "$OUTPUT"
