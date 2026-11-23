#!/bin/sh -e

DEBIAN_FRONTEND=noninteractive
DEBCONF_NONINTERACTIVE_SEEN=true

# Faster apt configuration
echo 'force-confdef' >> /etc/dpkg/dpkg.cfg
echo 'force-confold' >> /etc/dpkg/dpkg.cfg

echo 'tzdata tzdata/Areas select Etc' | debconf-set-selections
echo 'tzdata tzdata/Zones/Etc select UTC' | debconf-set-selections
echo "locales locales/default_environment_locale select en_US.UTF-8" | debconf-set-selections
echo "locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8" | debconf-set-selections
rm -f "/etc/locale.gen"

# Single apt update, upgrade, and install to reduce overhead
apt update -qqy
apt upgrade -qqy --with-new-pkgs
apt install -qqy --no-install-recommends \
    build-essential \
    dnsmasq \
    libc6-dev \
    linux-libc-dev \
    locales \
    netcat-openbsd \
    network-manager \
    openssh-server \
    sudo \
    systemd-timesyncd \
    tzdata \
    wireguard-tools \
    wpasupplicant \
    bash-completion \
    curl \
    ca-certificates \
    zram-tools \
    bc \
    iw \
    rfkill \
    initramfs-tools

# install deb
#dpkg -i /root/*.deb
#rm -rf /root/*.deb

# Cleanup in one go
apt autoremove -qqy
apt clean
rm -rf /var/lib/apt/lists/*
rm -f /etc/machine-id
rm -f /var/lib/dbus/machine-id
rm /etc/ssh/ssh_host_*
find /var/log -type f -delete

passwd -dl root

# Add user
adduser --disabled-password --comment "" user
# Set password
passwd user << EOD
1234
1234
EOD
# Add user to sudo group
usermod -aG sudo user

cat <<EOF >>/etc/bash.bashrc

alias ls='ls --color=auto'
alias ll='ls --color=auto -lhA'
alias l='ls --color=auto'

EOF

cat <<EOF >> /etc/systemd/journald.conf
SystemMaxUse=300M
SystemKeepFree=1G
EOF

# Ensure NetworkManager and systemd-resolved are enabled and managing DNS (offline enable inside chroot)
systemctl enable NetworkManager || true
systemctl enable systemd-resolved || true
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Time
systemctl enable systemd-timesyncd

systemctl mask systemd-networkd-wait-online.service

# Enable IPv4 and IPv6 forwarding
if [ -f /etc/sysctl.conf ]; then
    # Uncomment existing lines if they exist
    sed -i -e 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' -e 's/^#net.ipv6.conf.all.forwarding=1/net.ipv6.conf.all.forwarding=1/' /etc/sysctl.conf
    # Add the lines if they don't exist at all
    grep -q '^net.ipv4.ip_forward' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    grep -q '^net.ipv6.conf.all.forwarding' /etc/sysctl.conf || echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf
else
    # Create the file with the required settings
    cat <<EOF > /etc/sysctl.conf
# Enable IPv4 forwarding
net.ipv4.ip_forward=1

# Enable IPv6 forwarding
net.ipv6.conf.all.forwarding=1
EOF
fi
