# Build Linux Kernel for ARM64
#
# What is the Linux kernel?
# -------------------------
# The kernel is the core of the operating system. It's a single large program
# (millions of lines of C code) that:
#   - Manages hardware (CPU, memory, devices)
#   - Provides system calls (the API all programs use)
#   - Schedules processes (decides what runs when)
#   - Manages virtual memory (each process gets its own address space)
#
# Kernel Configuration
# --------------------
# The kernel is highly configurable. Each feature can be:
#   - Built-in (=y)  : Compiled into the kernel image
#   - Module (=m)    : Compiled separately, loaded at runtime
#   - Disabled (=n)  : Not compiled at all
#
# We use 'defconfig' as a starting point (reasonable defaults for ARM64),
# then enable specific features we need:
#   - 9P filesystem  : Lets us mount host folders via virtio
#   - virtio drivers : Virtual I/O for QEMU (disk, network, 9p, etc.)
#
# The Build Process
# -----------------
#   1. Download kernel source (kernel.org)
#   2. Configure (.config file lists all options)
#   3. Compile (takes 5-10 minutes)
#   4. Output: arch/arm64/boot/Image (uncompressed kernel)
#

FROM alpine:3.19

# Install build dependencies
#   build-base    - gcc, make, binutils, etc.
#   linux-headers - kernel headers (for building kernel)
#   bc            - calculator (used by kernel build scripts)
#   flex, bison   - parser generators (for kernel build)
#   perl          - used by kernel build scripts
#   openssl-dev   - for kernel crypto (optional but avoids warnings)
#   elfutils-dev  - for BTF generation (optional)
RUN apk add --no-cache \
    build-base \
    linux-headers \
    bc \
    flex \
    bison \
    perl \
    openssl-dev \
    elfutils-dev \
    xz \
    bash

# Download and extract kernel source
ARG KERNEL_VERSION=6.6.70
WORKDIR /build
RUN wget -q https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz && \
    tar xf linux-${KERNEL_VERSION}.tar.xz && \
    mv linux-${KERNEL_VERSION} linux

WORKDIR /build/linux

# Configure the kernel
#   1. Start with defconfig (default ARM64 config - reasonable defaults)
#   2. Enable 9P filesystem support (for host folder sharing)
#   3. Enable virtio-9p transport (9P over virtio, used by QEMU)
#
# The .config file contains thousands of CONFIG_xxx=y/m/n lines.
# scripts/config is a helper tool to modify individual options.
#
RUN make defconfig && \
    # 9P network protocol (required for 9P filesystem)
    scripts/config --enable CONFIG_NET_9P && \
    scripts/config --enable CONFIG_NET_9P_VIRTIO && \
    # 9P filesystem (mount host directories)
    scripts/config --enable CONFIG_9P_FS && \
    scripts/config --enable CONFIG_9P_FS_POSIX_ACL && \
    # Make sure virtio is enabled (should already be in defconfig)
    scripts/config --enable CONFIG_VIRTIO && \
    scripts/config --enable CONFIG_VIRTIO_MENU && \
    scripts/config --enable CONFIG_VIRTIO_MMIO && \
    # Run olddefconfig to resolve any dependencies we might have missed
    make olddefconfig

# Compile the kernel
#   -j$(nproc) = use all CPU cores
#   Image      = the kernel binary for ARM64 (uncompressed)
#
# This takes 5-10 minutes on Apple Silicon.
#
RUN make -j$(nproc) Image

# The kernel is at /build/linux/arch/arm64/boot/Image
