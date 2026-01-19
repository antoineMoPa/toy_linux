#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"

# Use custom kernel if available, otherwise fall back to Alpine's prebuilt
if [[ -f "$BUILD_DIR/Image" ]]; then
    KERNEL="$BUILD_DIR/Image"
else
    KERNEL="$BUILD_DIR/vmlinuz-lts"
fi
INITRAMFS="$BUILD_DIR/initramfs.cpio.gz"

# Check if required files exist
if [[ ! -f "$KERNEL" ]]; then
    echo "Error: Kernel not found at $KERNEL"
    echo "Run the build script first to compile the kernel."
    exit 1
fi

if [[ ! -f "$INITRAMFS" ]]; then
    echo "Error: initramfs not found at $INITRAMFS"
    echo "Run the build script first to create the root filesystem."
    exit 1
fi

# Determine architecture and set QEMU options
# ARM64 (Apple Silicon) vs x86_64 (Intel) need different configs
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    QEMU_BIN="qemu-system-aarch64"
    # -M virt: Generic ARM virtual machine
    # -cpu host: Use host CPU features (fast, requires HVF)
    # -accel hvf: Use Apple's Hypervisor Framework (native speed, not emulation)
    MACHINE="-M virt -cpu host -accel hvf"
    # ARM virt machine uses PL011 UART (ttyAMA0), not 8250 serial (ttyS0)
    CONSOLE="ttyAMA0"
else
    QEMU_BIN="qemu-system-x86_64"
    MACHINE="-accel hvf"
    CONSOLE="ttyS0"
fi

# Check if qemu is installed
if ! command -v "$QEMU_BIN" &> /dev/null; then
    echo "Error: $QEMU_BIN not found. Install with: brew install qemu"
    exit 1
fi

echo "Starting toy Linux in QEMU..."
echo "  Kernel: $KERNEL"
echo "  Initramfs: $INITRAMFS"
echo ""
echo "Press Ctrl+A, X to exit QEMU"
echo ""

# Run QEMU
# -nographic: output to terminal (no GUI window)
# -m 512M: 512MB RAM
# -append: kernel command line arguments
# Shared folder: host's rootfs/ is mounted as /host in guest
# Uses virtio-9p (virtual filesystem over virtio transport)
SHARED_DIR="$PROJECT_DIR/rootfs"
mkdir -p "$SHARED_DIR"

$QEMU_BIN \
    $MACHINE \
    -kernel "$KERNEL" \
    -initrd "$INITRAMFS" \
    -m 512M \
    -append "console=$CONSOLE quiet" \
    -nographic \
    -virtfs local,path="$SHARED_DIR",mount_tag=hostfs,security_model=mapped-xattr
