# Toy Linux OS Project

## Quick Commands

Build the OS:
```bash
./os/build.sh
```

Start VM interactively:
```bash
./vm/mac_startup_in_qemu.sh
```

Run a command in VM and exit (for debugging):
```bash
cd /Users/antoine/prog/os
./vm/run.sh "command"
```

Compile apps from within QEMU:
```bash
cd /Users/antoine/prog/os
./vm/run.sh "/apps/compile-project.sh"
```

## Project Structure

- `os/build.sh` - Builds initramfs with busybox
- `vm/mac_startup_in_qemu.sh` - Starts QEMU with GUI
- `vm/run.sh` - Runs command in VM, then shuts down (GUI=0 by default)
- `apps/` - Shared folder mounted at `/apps` in VM
- `apps/compile-project.sh` - Compiles all .c files in /apps using toolchain
- `apps/toolchain/` - ARM64 musl GCC toolchain
- `build/` - Build outputs (kernel, initramfs)
- `kernel/` - Custom kernel build scripts

## Virtio-GPU Configuration

**virtio-gpu-device (MMIO) is now working!** To use it on ARM virt machines:
- Must add `-global virtio-mmio.force-legacy=false` to QEMU command line
- This enables modern virtio-1 support (VIRTIO_F_VERSION_1 feature flag)
- Without it, virtio-mmio defaults to legacy mode which virtio-gpu doesn't support
- Alternative: Use virtio-gpu-pci (PCI transport) which has modern virtio enabled by default

## Notes

- Toolchain uses absolute symlinks for cc1/collect2/lto-wrapper to work with 9p
- Dynamic linker and libraries are symlinked in /lib by rcS at boot
- Compilation must be done inside QEMU (not cross-compiled from host)
