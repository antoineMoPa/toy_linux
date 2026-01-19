# Build BusyBox as a static ARM64 binary
#
# What is BusyBox?
# ----------------
# A single binary containing 300+ Unix utilities (sh, ls, cat, mount, etc.)
# It uses argv[0] to decide which utility to run - so symlinks work:
#   /bin/ls -> /bin/busybox  (when called as "ls", it runs ls)
#
# Why static linking?
# -------------------
# Static = all libraries compiled into the binary. No external dependencies.
# Dynamic = needs .so files at runtime. Smaller but requires matching libs.
# For initramfs, static is perfect - the binary just works, no setup needed.
#

FROM alpine:3.19

# Install build dependencies
#   gcc           - C compiler
#   musl-dev      - C standard library headers (Alpine uses musl, not glibc)
#   make          - Build automation
#   perl          - Required by busybox build scripts
#   linux-headers - Kernel headers (for console-tools like kbd_mode)
RUN apk add --no-cache gcc musl-dev make perl linux-headers

# Download and extract busybox source
ARG BUSYBOX_VERSION=1.36.1
WORKDIR /build
RUN wget -q https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2 && \
    tar xf busybox-${BUSYBOX_VERSION}.tar.bz2 && \
    mv busybox-${BUSYBOX_VERSION} busybox

WORKDIR /build/busybox

# Configure busybox
#   defconfig = reasonable defaults (most applets enabled)
#   Then we enable static linking
RUN make defconfig && \
    sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config

# Compile
#   -j$(nproc) = use all CPU cores for parallel build
RUN make -j$(nproc)

# The final binary is at /build/busybox/busybox
# Extract it with: docker cp <container>:/build/busybox/busybox ./busybox
