# TODO

## Display issues to investigate later

virtio-gpu-device (MMIO) doesn't work - no DRM messages in dmesg.
Currently using virtio-gpu-pci which works.

Try reverting later to see if we can get MMIO working:
```
DISPLAY_OPTS="-device virtio-gpu-device ..."
```

## Toolchain in VM

The toolchain symlinks are set up in rcS but gcc still needs testing.
These symlinks are required for the toolchain to work in-VM:
```
mkdir -p /lib
ln -s /apps/toolchain/lib/ld-musl-aarch64.so.1 /lib/ld-musl-aarch64.so.1

mkdir -p /usr/libexec
ln -s /apps/toolchain/libexec/gcc /usr/libexec/gcc

mkdir -p /usr/lib
ln -s /apps/toolchain/lib/gcc /usr/lib/gcc
```
