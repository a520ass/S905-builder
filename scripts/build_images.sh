#!/bin/sh -e

CHROOT=${CHROOT=$(pwd)/rootfs}
IMAGE_NAME="s905.img"

#package rootfs
rm -f s905.img
mkdir -p files mnt

# 定义大小
truncate -s "1560M" "${IMAGE_NAME}"

# DOS MBR分区表
parted -s "${IMAGE_NAME}" mklabel msdos
parted -s "${IMAGE_NAME}" mkpart primary fat32 4MiB 260MiB
parted -s "${IMAGE_NAME}" set 1 boot on
parted -s "${IMAGE_NAME}" mkpart primary ext4 260MiB 100%

LOOP_DEVICE=$(losetup --find --show --partscan "${IMAGE_NAME}")
echo "Loop设备: ${LOOP_DEVICE}"
mkfs.vfat -F32 -n SYSBOOT "${LOOP_DEVICE}p1"
mkfs.ext4 -L SYSROOT -m 0 -U "86c05746-759e-4d3e-98c1-7eded328b685" "${LOOP_DEVICE}p2"

mount "${LOOP_DEVICE}p2" mnt
mkdir -p mnt/boot
mount "${LOOP_DEVICE}p1" mnt/boot
tar xpf rootfs.tgz -C mnt --exclude='./dev/*'

umount -R  mnt
losetup -D
# 移动到最终目录
mv "${IMAGE_NAME}" files
