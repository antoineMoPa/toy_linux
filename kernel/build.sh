#!/bin/bash
#
# Build Linux Kernel for ARM64 using Docker
#
# Output: ../build/Image (ARM64 kernel)
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
OUTPUT="$BUILD_DIR/Image"

# Skip if already built
if [[ -f "$OUTPUT" ]]; then
    echo "Kernel already built: $OUTPUT"
    file "$OUTPUT"
    exit 0
fi

echo "Building Linux Kernel (ARM64)..."
echo "This will take 5-10 minutes on Apple Silicon."
echo ""

mkdir -p "$BUILD_DIR"

# Build the Docker image (this compiles the kernel)
echo "[1/2] Building Docker image (compiling kernel)..."
docker build --platform linux/arm64 -t toylinux-kernel "$SCRIPT_DIR"

# Extract the kernel from the image
echo ""
echo "[2/2] Extracting kernel..."
CONTAINER_ID=$(docker create --platform linux/arm64 toylinux-kernel)
docker cp "$CONTAINER_ID:/build/linux/arch/arm64/boot/Image" "$OUTPUT"
docker rm "$CONTAINER_ID" > /dev/null

echo ""
echo "Done!"
file "$OUTPUT"
ls -lh "$OUTPUT"
