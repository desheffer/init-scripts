#!/bin/bash

set -euo pipefail

cd "$(dirname "${0}")"

MNT="/mnt"
function arch_chroot {
    arch-chroot ${MNT} /bin/bash -c "${1}"
}

function confirm {
    CONFIRM=
    while [ "${CONFIRM}" != "y" ]; do
        read -n 1 -r -s -p "${1}" CONFIRM
        echo
    done
}

# Assert we booted in UEFI mode:

if [ ! -d /sys/firmware/efi/efivars ]; then
    echo "${0}: system must be booted in UEFI mode"
    exit 1
fi

# Expand the temporary filesystem.

mount -o remount,size=2G /run/archiso/cowspace

# Collect information:

INSTALL_DISK=
INSTALL_DISK_PASSWORD=
INSTALL_HOSTNAME=
INSTALL_USER=
INSTALL_FULLNAME=
INSTALL_PASSWORD=
INSTALL_PASSWORD_CONFIRM=

while [ ! -e "${INSTALL_DISK}" ]; do
    lsblk -p
    read -e -p "Install disk (e.g. /dev/sda, /dev/nvme0n1): " INSTALL_DISK
done

while [ -z "${INSTALL_DISK_PASSWORD}" ]; do
    read -s -p "Disk password: " INSTALL_DISK_PASSWORD
    echo
done

while [ -z "${INSTALL_HOSTNAME}" ]; do
    read -p "Hostname: " INSTALL_HOSTNAME
done

while [ -z "${INSTALL_USER}" ]; do
    read -p "Username: " INSTALL_USER
done

while [ -z "${INSTALL_FULLNAME}" ]; do
    read -p "User fullname: " INSTALL_FULLNAME
done

while [ -z "${INSTALL_PASSWORD}" ] || [ "${INSTALL_PASSWORD}" != "${INSTALL_PASSWORD_CONFIRM}" ]; do
    read -s -p "User password: " INSTALL_PASSWORD
    echo
    read -s -p "Confirm user password: " INSTALL_PASSWORD_CONFIRM
    echo
done

INSTALL_USER="$(echo ${INSTALL_USER} | sed "s/ /_/g")"
INSTALL_PASSWORD="$(echo ${INSTALL_PASSWORD} | sed "s/'/\\\'/g")"

confirm "Ready to install. Press 'y' to continue..."

# Update the system clock:

timedatectl set-ntp true

# Format the partitions:

BOOT_PART=$(lsblk -lnp -o NAME ${INSTALL_DISK} | sed -n '2p')
ROOT_PART=$(lsblk -lnp -o NAME ${INSTALL_DISK} | sed -n '3p')

mkfs.vfat -F32 ${BOOT_PART}

echo "${INSTALL_DISK_PASSWORD}" | cryptsetup luksOpen ${ROOT_PART} luks
sleep 5

mkswap /dev/mapper/vg0-swap
mkfs.ext4 /dev/mapper/vg0-root
sleep 5

swapon /dev/mapper/vg0-swap

mount /dev/mapper/vg0-root ${MNT}

mkdir ${MNT}/boot
mount ${BOOT_PART} ${MNT}/boot

mkdir ${MNT}/home
mount /dev/mapper/vg0-home ${MNT}/home

# Update the mirror list:

curl -s "https://www.archlinux.org/mirrorlist/?country=US&protocol=https" | sed 's/^#//' > /etc/pacman.d/mirrorlist

# Install the base system:

pacman -Sy --noconfirm archlinux-keyring

pacstrap ${MNT} \
    base \
    base-devel \
    git \
    intel-ucode \
    linux \
    linux-firmware \
    lvm2 \
    sudo \
    terminus-font

# Generate the fstab:

genfstab -U ${MNT} >> ${MNT}/etc/fstab

# Set the time zone:

arch_chroot "ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime"
arch_chroot "hwclock --systohc --utc"

# Set the locale:

sed -i '/^#\?en_US\.UTF-8 UTF-8/s/^#//' ${MNT}/etc/locale.gen
arch_chroot "locale-gen"

echo "LANG=en_US.UTF-8" >> ${MNT}/etc/locale.conf

# Configure the vconsole:

cat > ${MNT}/etc/vconsole.conf <<EOF
FONT=ter-132n
EOF

# Set the hostname:

echo "${INSTALL_HOSTNAME}" > ${MNT}/etc/hostname

# Add host entries:

echo "127.0.0.1 localhost" >> ${MNT}/etc/hosts
echo "::1       localhost" >> ${MNT}/etc/hosts
echo "127.0.1.1 ${INSTALL_HOSTNAME}.localdomain ${INSTALL_HOSTNAME}" >> ${MNT}/etc/hosts

# Create user:

arch_chroot "[ -d /home/${INSTALL_USER} ] && mv /home/${INSTALL_USER} /home/${INSTALL_USER}.$(date +%Y-%m-%d-%H-%M-%S)"

arch_chroot "useradd -m -c '${INSTALL_FULLNAME}' ${INSTALL_USER}"

arch_chroot "mkdir -p /etc/sudoers.d"
cat > ${MNT}/etc/sudoers.d/10-${INSTALL_USER} <<EOF
${INSTALL_USER} ALL=(ALL) ALL
${INSTALL_USER} ALL=(root) NOPASSWD: /usr/bin/pacman
EOF

# Install yay:

arch_chroot "sudo -u ${INSTALL_USER} git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    cd /tmp/yay-bin
    sudo -u ${INSTALL_USER} makepkg -si --noconfirm
    rm -rf /tmp/yay-bin"

# Install plymouth:

arch_chroot "sudo -u ${INSTALL_USER} yay -S --noconfirm \
    plymouth \
    plymouth-theme-arch-charge-big \
    ttf-dejavu"

# Configure video:

echo "options i915 enable_psr=2 enable_rc6=7 enable_fbc=1 semaphores=1 lvds_downclock=1 enable_guc_loading=1 enable_guc_submission=1" > ${MNT}/etc/modprobe.d/i915.conf

# Install bootloader:

arch_chroot "bootctl --path=/boot install"

cat > ${MNT}/boot/loader/loader.conf <<EOF
default arch
timeout 0
console-mode 0
editor 0
EOF

cat > ${MNT}/boot/loader/entries/arch.conf <<EOF
title Arch Linux
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options cryptdevice=UUID=$(blkid -t TYPE=crypto_LUKS -s UUID -o value):lvm resume=/dev/mapper/vg0-swap root=/dev/mapper/vg0-root rw quiet splash rd.udev.log-priority=3
EOF

cat > ${MNT}/boot/loader/entries/arch-fallback.conf <<EOF
title Arch Linux (Fallback)
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux-fallback.img
options cryptdevice=UUID=$(blkid -t TYPE=crypto_LUKS -s UUID -o value):lvm resume=/dev/mapper/vg0-swap root=/dev/mapper/vg0-root rw
EOF

# Configure initramfs:

arch_chroot "sed -i 's/^MODULES=.*/MODULES=(i915 nvme ext4)/' /etc/mkinitcpio.conf"
arch_chroot "sed -i 's/^HOOKS=.*/HOOKS=(base udev plymouth autodetect modconf block keymap consolefont plymouth-encrypt lvm2 resume filesystems keyboard fsck shutdown)/' /etc/mkinitcpio.conf"

arch_chroot "plymouth-set-default-theme arch-charge-big"

arch_chroot "mkinitcpio -p linux"

# Change passwords:

arch_chroot "echo -e '${INSTALL_PASSWORD}\n${INSTALL_PASSWORD}' | passwd"
arch_chroot "echo -e '${INSTALL_PASSWORD}\n${INSTALL_PASSWORD}' | passwd ${INSTALL_USER}"

# Deploy stage 2:

arch_chroot "sudo -u ${INSTALL_USER} git clone https://github.com/desheffer/init-scripts.git /home/${INSTALL_USER}/init-scripts"

arch_chroot "sudo -u ${INSTALL_USER} /home/${INSTALL_USER}/init-scripts/deploy.sh -p '${INSTALL_PASSWORD}'"

# Done:

confirm "Setup complete. Press 'y' to reboot..."

umount -R ${MNT}
reboot
