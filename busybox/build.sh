#!/bin/bash
#
# Build BusyBox for ARM64 Linux using Docker
#
# Output: ../build/busybox (static ARM64 binary)
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
OUTPUT="$BUILD_DIR/busybox"

# Skip if already built
if [[ -f "$OUTPUT" ]]; then
    echo "BusyBox already built: $OUTPUT"
    file "$OUTPUT"
    exit 0
fi

echo "Building BusyBox (ARM64 static binary)..."
echo ""

mkdir -p "$BUILD_DIR"

# Build the Docker image (this compiles busybox)
echo "[1/2] Building Docker image (compiling busybox)..."
docker build --platform linux/arm64 -t toylinux-busybox "$SCRIPT_DIR"

# Extract the binary from the image
echo ""
echo "[2/2] Extracting busybox binary..."
CONTAINER_ID=$(docker create --platform linux/arm64 toylinux-busybox)
docker cp "$CONTAINER_ID:/build/busybox/busybox" "$OUTPUT"
docker rm "$CONTAINER_ID" > /dev/null

chmod +x "$OUTPUT"

echo ""
echo "Done!"
file "$OUTPUT"
ls -lh "$OUTPUT"
