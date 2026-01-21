# Kernel build environment
# Used with a persistent volume for incremental builds
FROM alpine:3.19

RUN apk add --no-cache \
    build-base linux-headers bc flex bison perl openssl-dev elfutils-dev xz bash
