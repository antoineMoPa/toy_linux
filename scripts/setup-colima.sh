#!/bin/bash
#
# Start Colima with optimal settings for Toy Linux development
#
# Colima is a lightweight Docker Desktop alternative.
# It runs a Linux VM and provides Docker-compatible API.
#
set -e

# Check if colima is installed
if ! command -v colima &> /dev/null; then
    echo "Colima not found. Install with: brew install colima"
    exit 1
fi

# Check if already running
if colima status &> /dev/null; then
    echo "Colima is already running:"
    colima status
    exit 0
fi

echo "Starting Colima..."
echo ""

# Start with:
#   --arch aarch64    : ARM64 (native for Apple Silicon)
#   --vm-type vz      : Apple Virtualization.framework (faster than QEMU)
#   --vz-rosetta      : Enable Rosetta for x86 containers (optional)
#   --cpu 4           : 4 CPU cores
#   --memory 4        : 4GB RAM
colima start \
    --arch aarch64 \
    --vm-type vz \
    --vz-rosetta \
    --cpu 4 \
    --memory 4

echo ""
echo "Colima started! Docker commands will now use Colima."
echo ""
echo "Useful commands:"
echo "  colima status  - Check status"
echo "  colima stop    - Stop the VM"
echo "  colima delete  - Delete VM (fresh start)"
