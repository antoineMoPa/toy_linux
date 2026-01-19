#!/bin/bash
#
# Toy Linux Distribution - Build Script
# ======================================
# This script builds a minimal bootable Linux system.
#
# A bootable Linux needs three components:
#   1. Bootloader - Loads kernel into memory (QEMU does this for us via -kernel flag)
#   2. Kernel     - The OS core (vmlinuz)
#   3. initramfs  - Initial root filesystem with /init and basic utilities
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
ROOTFS_DIR="$PROJECT_DIR/rootfs"

# Detect architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    LINUX_ARCH="aarch64"
else
    LINUX_ARCH="x86_64"
fi

echo "Building toy Linux for $LINUX_ARCH"
echo "==================================="
echo ""

mkdir -p "$BUILD_DIR"

# =============================================================================
# STEP 1: Download the Linux Kernel
# =============================================================================
#
# What is vmlinuz?
# ----------------
# A compiled program with a special structure:
#
#   ┌─────────────────────────────────┐
#   │  Small decompressor stub        │  ← Uncompressed, runs first
#   │  (assembly code)                │
#   ├─────────────────────────────────┤
#   │  Compressed kernel              │  ← The actual Linux kernel
#   │  (gzip/lzma/zstd compressed)    │     (millions of lines of C, compiled)
#   └─────────────────────────────────┘
#
# The "z" in vmlinuz = compressed (not encrypted).
# Uncompressed kernel ~30MB, compressed ~10MB.
#
# Boot sequence:
#   1. Bootloader (or QEMU) loads vmlinuz into RAM at a specific address
#   2. Decompressor stub runs first - decompresses the kernel into memory
#   3. Kernel initializes hardware, memory management, scheduler
#   4. Kernel mounts initramfs and runs /init (PID 1)
#
# What the kernel does (forever, until shutdown):
#   - Manages hardware (CPU, RAM, disks, network)
#   - Provides system calls - the API all programs use (open, read, write, fork, exec...)
#   - Schedules processes - switches between running programs
#   - Manages virtual memory - each process thinks it has its own address space
#
# We're using Alpine Linux's prebuilt kernel (LTS = Long Term Support).
#

KERNEL_URL="https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/${LINUX_ARCH}/netboot/vmlinuz-lts"
KERNEL_FILE="$BUILD_DIR/vmlinuz-lts"

if [[ -f "$KERNEL_FILE" ]]; then
    echo "[1/2] Kernel already downloaded: $KERNEL_FILE"
else
    echo "[1/2] Downloading kernel from Alpine Linux..."
    echo "      URL: $KERNEL_URL"
    curl -L -o "$KERNEL_FILE" "$KERNEL_URL"
    echo "      Done: $(ls -lh "$KERNEL_FILE" | awk '{print $5}')"
fi

echo ""

# =============================================================================
# STEP 2: Create initramfs (Initial RAM Filesystem)
# =============================================================================
#
# What is initramfs?
# ------------------
# A compressed cpio archive containing a minimal root filesystem.
# The kernel extracts this into RAM and runs /init from it.
#
# Why "initramfs" and not just mount a disk?
#   - Kernel is simple: it knows how to extract cpio, but disk drivers
#     might not be compiled in (they could be modules)
#   - initramfs can load disk drivers, then switch to real root filesystem
#   - For our toy OS, initramfs IS the entire root filesystem (no disk needed)
#
# What we need inside:
#   /init          - First program kernel runs (must be executable, PID 1)
#   /bin/busybox   - Swiss army knife: one binary with 300+ utilities
#   /bin/sh        - Symlink to busybox (it detects how it was called)
#   /dev           - Device files (console, null, etc.)
#   /proc          - Mount point for procfs (kernel exposes process info here)
#   /sys           - Mount point for sysfs (kernel exposes hardware info here)
#
# What is BusyBox?
# ----------------
# A single ~1MB static binary that contains: sh, ls, cat, mount, cp, mv,
# grep, find, vi, wget, tar, gzip... ~300 utilities.
#
# How it works: BusyBox looks at argv[0] (how it was invoked) to decide
# what to do. If called as "ls", it runs ls. If called as "cat", it runs cat.
# So we create symlinks: /bin/ls -> /bin/busybox, /bin/cat -> /bin/busybox, etc.
#
# What is /init?
# --------------
# The first userspace program. The kernel runs it as PID 1.
# If /init exits, the kernel panics. It must:
#   1. Mount essential filesystems (/proc, /sys, /dev)
#   2. Set up the environment
#   3. Start a shell or other services
#   4. Never exit (or exec into another init system)
#

echo "[2/2] Creating initramfs..."

INITRAMFS_DIR="$BUILD_DIR/initramfs_root"
INITRAMFS_FILE="$BUILD_DIR/initramfs.cpio.gz"

# Clean and create directory structure
rm -rf "$INITRAMFS_DIR"
mkdir -p "$INITRAMFS_DIR"/{bin,sbin,etc,proc,sys,dev,tmp,root}

# Build BusyBox (see busybox/Dockerfile for details)
BUSYBOX_FILE="$INITRAMFS_DIR/bin/busybox"

if [[ ! -f "$BUILD_DIR/busybox" ]]; then
    echo "      Building BusyBox from source (first time only)..."
    "$PROJECT_DIR/busybox/build.sh"
fi

echo "      Copying BusyBox to initramfs..."
cp "$BUILD_DIR/busybox" "$BUSYBOX_FILE"
chmod +x "$BUSYBOX_FILE"

# Create symlinks for common utilities
# BusyBox uses argv[0] to determine which applet to run
echo "      Creating BusyBox symlinks..."
# Network utilities: ip, ifconfig, udhcpc (DHCP client), wget, ping
# Terminal utilities: setsid, cttyhack (for proper job control)
# Init utilities: init, getty, crond, crontab
for cmd in sh ash ls cat echo mount umount mkdir rm cp mv grep find ps kill sleep poweroff halt reboot ip ifconfig udhcpc route wget ping hostname setsid cttyhack init getty crond crontab; do
    ln -sf busybox "$INITRAMFS_DIR/bin/$cmd"
done

# Create udhcpc script (called by DHCP client to configure network)
# udhcpc gets IP info from DHCP server, then calls this script with
# environment variables like $ip, $router, $dns, etc.
echo "      Creating DHCP client script..."
mkdir -p "$INITRAMFS_DIR/etc"
cat > "$INITRAMFS_DIR/etc/udhcpc.script" << 'DHCP_SCRIPT'
#!/bin/sh
# udhcpc script - configures interface based on DHCP response
# Called with: $1 = action (deconfig, bound, renew, etc.)
# Environment: $ip, $subnet, $router, $dns, $interface
case "$1" in
    deconfig)
        ip addr flush dev $interface
        ;;
    bound|renew)
        ip addr add $ip/${subnet:-24} dev $interface
        if [ -n "$router" ]; then
            ip route add default via $router
        fi
        if [ -n "$dns" ]; then
            echo "nameserver $dns" > /etc/resolv.conf
        fi
        ;;
esac
DHCP_SCRIPT
chmod +x "$INITRAMFS_DIR/etc/udhcpc.script"

# Create BusyBox init system
# ===========================
#
# BusyBox init is a simple init that reads /etc/inittab.
# It handles: startup, respawning processes, shutdown signals (halt/reboot)
#
# /etc/inittab format:  id:runlevel:action:process
#   id       - unique identifier (any string, often tty name)
#   runlevel - ignored by busybox init (compatibility field)
#   action   - sysinit, respawn, askfirst, shutdown, ctrlaltdel, etc.
#   process  - command to run
#

echo "      Creating init system..."

# /init - just a symlink to busybox init
ln -sf /bin/busybox "$INITRAMFS_DIR/init"

# /etc/inittab - tells init what to do
mkdir -p "$INITRAMFS_DIR/etc/init.d"
cat > "$INITRAMFS_DIR/etc/inittab" << 'INITTAB'
# /etc/inittab - BusyBox init configuration
#
# Format: id:runlevel:action:process
#
# Actions:
#   sysinit  - Run once at boot (wait for completion)
#   respawn  - Run and restart if it exits
#   askfirst - Like respawn, but prompt "Please press Enter" first
#   shutdown - Run when shutting down
#   ctrlaltdel - Run on Ctrl+Alt+Del

# Run startup script first
::sysinit:/etc/init.d/rcS

# Start a shell on the console (respawn = restart if it exits)
::respawn:-/bin/sh

# What to do on halt/reboot
::shutdown:/bin/echo "Shutting down..."
::shutdown:/bin/umount -a -r
::ctrlaltdel:/bin/reboot
INITTAB

# /etc/init.d/rcS - startup script (runs once at boot)
cat > "$INITRAMFS_DIR/etc/init.d/rcS" << 'STARTUP'
#!/bin/sh
#
# /etc/init.d/rcS - System startup script
#

echo "=========================================="
echo "  Welcome to Toy Linux!"
echo "=========================================="
echo ""

# Mount essential virtual filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

# Create pts for proper terminal support
mkdir -p /dev/pts
mount -t devpts devpts /dev/pts

# Mount shared folder from host (via virtio-9p)
mkdir -p /host
if mount -t 9p -o trans=virtio hostfs /host 2>/dev/null; then
    echo "[ok] Mounted /host (shared with macOS)"
else
    echo "[--] /host not available"
fi

# Set up networking
echo -n "[..] Configuring network... "
ip link set eth0 up 2>/dev/null
if udhcpc -i eth0 -s /etc/udhcpc.script -q 2>/dev/null; then
    IP=$(ip -4 addr show eth0 | grep -o 'inet [0-9.]*' | cut -d' ' -f2)
    echo "ok ($IP)"
else
    echo "failed"
fi

# Set hostname
hostname toylinux

echo ""
echo "Try: ping, wget, cat /proc/cpuinfo, ls /host"
echo "Shutdown: poweroff | reboot"
echo ""
STARTUP

chmod +x "$INITRAMFS_DIR/etc/init.d/rcS"

# Create the initramfs archive
# cpio format is required by the kernel (not tar)
# We pipe through gzip to compress it
echo "      Packing initramfs..."
(cd "$INITRAMFS_DIR" && find . | cpio -o -H newc 2>/dev/null | gzip > "$INITRAMFS_FILE")

echo "      Done: $(ls -lh "$INITRAMFS_FILE" | awk '{print $5}')"
echo ""

echo "Build complete!"
echo ""
echo "Files created:"
ls -lh "$BUILD_DIR"
