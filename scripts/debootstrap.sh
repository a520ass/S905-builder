#!/bin/sh -e

CHROOT=${CHROOT=$(pwd)/rootfs}
RELEASE=${RELEASE=resolute}
HOST_NAME=${HOST_NAME=s905}

rm -rf ${CHROOT}

# Use mmdebstrap for faster builds (god, it's so much faster)
echo "Using mmdebstrap for fast bootstrap..."
mmdebstrap --arch=arm64 \
    --include=systemd,udev,dbus,apt,wget,ca-certificates \
    --keyring=/usr/share/keyrings/ubuntu-archive-keyring.gpg \
    ${RELEASE} ${CHROOT} http://ports.ubuntu.com/ubuntu-ports

cat << EOF > ${CHROOT}/etc/apt/sources.list
deb http://ports.ubuntu.com/ubuntu-ports ${RELEASE} main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports ${RELEASE}-updates main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports ${RELEASE}-security main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports ${RELEASE}-backports main restricted universe multiverse
EOF

# Speed up apt
cat << EOF > ${CHROOT}/etc/apt/apt.conf.d/99speedup
APT::Acquire::Retries "3";
APT::Acquire::http::Timeout "10";
APT::Acquire::ftp::Timeout "10";
Acquire::Languages "none";
APT::Install-Recommends "false";
APT::Install-Suggests "false";
DPkg::Options::="--force-confdef";
DPkg::Options::="--force-confold";
EOF

mount -t proc proc ${CHROOT}/proc/
mount -t sysfs sys ${CHROOT}/sys/
mount -o bind /dev/ ${CHROOT}/dev/
mount -o bind /dev/pts/ ${CHROOT}/dev/pts/
mount -o bind /run ${CHROOT}/run/

# configs'n stuff
mkdir -p ${CHROOT}/etc/systemd/system
cp -a configs/system/* ${CHROOT}/etc/systemd/system
mkdir -p ${CHROOT}/etc/NetworkManager/system-connections
mkdir -p ${CHROOT}/etc/NetworkManager/conf.d
cp configs/*.nmconnection ${CHROOT}/etc/NetworkManager/system-connections
chmod 0600 ${CHROOT}/etc/NetworkManager/system-connections/*
cp configs/99-custom.conf ${CHROOT}/etc/NetworkManager/conf.d/
mkdir -p ${CHROOT}/etc/systemd/network
cp configs/*.network ${CHROOT}/etc/systemd/network

# chroot setup
cp scripts/setup.sh ${CHROOT}

# copy debs  setup.sh install
#cp debs/* ${CHROOT}/root/

# Copy qemu static and run setup script in chroot
#cp /usr/bin/qemu-aarch64-static ${CHROOT}/usr/bin/
chroot ${CHROOT} /bin/sh -c "/setup.sh"

# cleanup
for a in proc sys dev/pts dev run; do
    umount ${CHROOT}/${a}
done;

rm -f ${CHROOT}/setup.sh
echo -n > ${CHROOT}/root/.bash_history

echo ${HOST_NAME} > ${CHROOT}/etc/hostname
sed -i "/localhost/ s/$/ ${HOST_NAME}/" ${CHROOT}/etc/hosts

# hosts entry for the LAN IP
cat <<EOF >> ${CHROOT}/etc/hosts

127.0.0.1	${HOST_NAME}
EOF

# add rc-local
cp -a configs/rc.local ${CHROOT}/etc/rc.local
chmod +x ${CHROOT}/etc/rc.local

# install kernel
wget https://github.com/a520ass/Actions-build/releases/download/Armbian_Aml_TVBOX_GF_MESON64_V26_2026.11.09-1724/linux-image-edge-meson64_26.11.0_arm64__7.3.3-Sd50d-D68f5-Pcf4c-Cff91-Hb9b6-HK01ba-Ve377-B0577-R448a.deb
mv linux-image-edge-meson64_26.11.0_arm64__7.3.3-Sd50d-D68f5-Pcf4c-Cff91-Hb9b6-HK01ba-Ve377-B0577-R448a.deb linux-image-7.3.3-edge-meson64.deb
./scripts/deb2targz.sh linux-image-7.3.3-edge-meson64.deb
tar -xzf 7.3.3-edge-meson64.tar.gz -C ${CHROOT}


mkdir -p ${CHROOT}/boot/extlinux
cp configs/extlinux.conf ${CHROOT}/boot/extlinux


# update fstab
printf "UUID=86c05746-759e-4d3e-98c1-7eded328b685\t/\text4\trw,noatime\t0 1\n" > ${CHROOT}/etc/fstab

# initramfs
mount -t proc proc ${CHROOT}/proc/
mount -t sysfs sys ${CHROOT}/sys/
mount -o bind /dev/ ${CHROOT}/dev/
mount -o bind /dev/pts/ ${CHROOT}/dev/pts/
mount -o bind /run ${CHROOT}/run/
chroot ${CHROOT} /bin/sh -c "update-initramfs -c -k all"
# cleanup
for a in proc sys dev/pts dev run; do
    umount ${CHROOT}/${a}
done;
#rm -f ${CHROOT}/usr/bin/qemu-aarch64-static

# backup rootfs
tar cpzf rootfs.tgz --exclude="usr/bin/qemu-aarch64-static" -C rootfs .
