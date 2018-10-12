#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")"

arch_chroot() {
    arch-chroot ${ROOTPART} /bin/bash -c "${1}"
}

confirm() {
    echo "Press 'y' to continue or Ctrl+C to exit."

    CONFIRM=""
    while [ "$CONFIRM" != "y" ]; do
        read -n 1 -r -s CONFIRM
    done
}

# Make sure we are running on an install image:

if [ "$(hostname)" != archiso ]; then
    echo "Error: this does not appear to be an install image"
    exit 1
fi

# Collect information:

while [ -z ${DISK+x} ] || [ ! -e "${DISK}" ]; do
    read -e -p "Install disk (e.g. /dev/sda, /dev/nvme0n1): " DISK
done

while [ -z ${HOSTNAME+x} ] || [ -z "${HOSTNAME}" ]; do
    read -p "Hostname: " HOSTNAME
done

while [ -z ${USER+x} ] || [ -z "${USER}" ]; do
    read -p "Username: " USER
done

while [ -z ${FULLNAME+x} ] || [ -z "${FULLNAME}" ]; do
    read -p "User fullname: " FULLNAME
done

echo "Ready to install..."
confirm

# Update the system clock:

timedatectl set-ntp true

# Partition the disk:

parted -s ${DISK} mklabel gpt
parted -s ${DISK} mkpart primary fat32 1MiB 513MiB
parted -s ${DISK} set 1 boot on
parted -s ${DISK} set 1 esp on
parted -s ${DISK} mkpart primary 513MiB 100%
parted -s ${DISK} print

# Format the partitions:

BOOTPART=$(lsblk -lnp -o NAME ${DISK} | sed -n '2p')
ROOTPART=$(lsblk -lnp -o NAME ${DISK} | sed -n '3p')

mkfs.vfat -F32 ${BOOTPART}

cryptsetup luksFormat ${ROOTPART}
cryptsetup luksOpen ${ROOTPART} luks

pvcreate /dev/mapper/luks
vgcreate vg0 /dev/mapper/luks
lvcreate -L 8G vg0 -n swap
lvcreate -l +100%FREE vg0 -n root
lvdisplay

mkfs.ext4 /dev/mapper/vg0-root
mkswap /dev/mapper/vg0-swap

mount /dev/mapper/vg0-root /mnt
swapon /dev/mapper/vg0-swap

mkdir /mnt/boot
mount ${BOOTPART} /mnt/boot

# Install the base system:

pacstrap /mnt base

# Generate the fstab:

genfstab -U /mnt >> /mnt/etc/fstab

# Set the time zone:

arch_chroot "ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime"
arch_chroot "hwclock --systohc --utc"

# Set the locale:

sed -i "/en_US.UTF-8 UTF-8/s/^#//" /mnt/etc/locale.gen
arch_chroot "locale-gen"

echo "LANG=en_US.UTF-8" >> /mnt/etc/locale.conf

# Set the hostname:

echo "${HOSTNAME}" > /mnt/etc/hostname

# Enable DHCP:

arch_chroot "ln -sf /usr/lib/systemd/system/dhcpcd.service /etc/systemd/system/multi-user.target.wants/dhcpcd.service"

# Create user:

arch_chroot "useradd -m -c '${FULLNAME}' ${USER}"

arch_chroot "mkdir -p /etc/sudoers.d"
cat > /mnt/etc/sudoers.d/10-${USER} <<EOL
${USER} ALL=(ALL) ALL
EOL

# Install base packages:

arch_chroot "pacman -S --needed --noconfirm \
    base-devel \
    bash \
    coreutils \
    dialog \
    git \
    go \
    intel-ucode \
    net-tools \
    python \
    python-pip \
    python-virtualenv \
    sudo \
    wireless_tools \
    wpa_supplicant"

# Install yay:

arch_chroot "sudo -u ${USER} git clone https://aur.archlinux.org/yay.git /tmp/yay"
arch_chroot "(cd /tmp/yay && sudo -u ${USER} makepkg -si --noconfirm)"
arch_chroot "rm -rf /tmp/yay"

# Configure video:

echo "options i915 enable_psr=2 enable_rc6=7 enable_fbc=1 semaphores=1 lvds_downclock=1 enable_guc_loading=1 enable_guc_submission=1" > /mnt/etc/modprobe.d/i915.conf

# Install bootloader:

arch_chroot "bootctl --path=/boot install"

cat > /mnt/boot/loader/loader.conf <<EOL
timeout 0
default arch
editor 0
EOL

cat > /mnt/boot/loader/entries/arch.conf <<EOL
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options cryptdevice=UUID=$(blkid -t TYPE=crypto_LUKS -s UUID -o value):lvm resume=/dev/mapper/vg0-swap root=/dev/mapper/vg0-root rw quiet
EOL

# Configure initramfs:

arch_chroot "sed -i 's/^MODULES=.*/MODULES=(i915 nvme ext4)/' /etc/mkinitcpio.conf"
arch_chroot "sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block keymap encrypt lvm2 resume filesystems keyboard fsck)/' /etc/mkinitcpio.conf"

arch_chroot "mkinitcpio -p linux"

# Clone this repository so it's available after reboot:

arch_chroot "sudo -u ${USER} git clone https://github.com/desheffer/init-scripts.git /home/${USER}/init-scripts"

# Change passwords:

echo "Setting up root..."
arch_chroot "passwd"

echo "Setting up ${USER}..."
arch_chroot "passwd ${USER}"

# Reboot:

confirm

echo "Unmounting disks..."
umount -R /mnt

echo "Rebooting..."
reboot
