#!/bin/bash
#
# Kernel configuration for Toy Linux
#
# Edit this file to add/change kernel options.
# Uses olddefconfig for incremental changes.
#
set -e

cd /build/linux

# Start with defconfig if no .config exists, otherwise keep existing
if [[ ! -f .config ]]; then
    make defconfig
fi

# 9P filesystem (for host folder sharing via virtio)
scripts/config --enable CONFIG_NET_9P
scripts/config --enable CONFIG_NET_9P_VIRTIO
scripts/config --enable CONFIG_9P_FS
scripts/config --enable CONFIG_9P_FS_POSIX_ACL

# Virtio (virtual I/O for QEMU)
scripts/config --enable CONFIG_VIRTIO
scripts/config --enable CONFIG_VIRTIO_MENU
scripts/config --enable CONFIG_VIRTIO_MMIO
scripts/config --enable CONFIG_VIRTIO_PCI

# Graphics: DRM + virtio-gpu + framebuffer
# Use --set-val y to force built-in (not module) since we don't load modules
scripts/config --set-val CONFIG_DRM y
scripts/config --set-val CONFIG_DRM_VIRTIO_GPU y

# CRITICAL: Creates /dev/fb0 from DRM devices
scripts/config --set-val CONFIG_DRM_FBDEV_EMULATION y

# Framebuffer core
scripts/config --set-val CONFIG_FB y
scripts/config --enable CONFIG_FRAMEBUFFER_CONSOLE

# VT/console support
scripts/config --enable CONFIG_VT
scripts/config --enable CONFIG_VT_CONSOLE

# Resolve dependencies
make olddefconfig

echo "Kernel configured!"
