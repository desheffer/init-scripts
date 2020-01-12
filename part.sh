#!/bin/bash

set -euo pipefail

cd "$(dirname "${0}")"

function confirm {
    CONFIRM=
    while [ "${CONFIRM}" != "y" ]; do
        read -n 1 -r -s -p "${1}" CONFIRM
        echo
    done
}

# Collect information:

INSTALL_DISK=
INSTALL_DISK_PASSWORD=
INSTALL_DISK_PASSWORD_CONFIRM=

while [ ! -e "${INSTALL_DISK}" ]; do
    lsblk -p
    read -e -p "Install disk (e.g. /dev/sda, /dev/nvme0n1): " INSTALL_DISK
done

while [ -z "${INSTALL_DISK_PASSWORD}" ] || [ "${INSTALL_DISK_PASSWORD}" != "${INSTALL_DISK_PASSWORD_CONFIRM}" ]; do
    read -s -p "Disk password: " INSTALL_DISK_PASSWORD
    echo
    read -s -p "Confirm disk password: " INSTALL_DISK_PASSWORD_CONFIRM
    echo
done

INSTALL_DISK_PASSWORD="$(echo "${INSTALL_DISK_PASSWORD}" | sed "s/'/\\\'/g")"

confirm "Ready to format. Press 'y' to continue..."

# Partition the disk:

parted -s ${INSTALL_DISK} mklabel gpt
parted -s ${INSTALL_DISK} mkpart primary fat32 1MiB 513MiB
parted -s ${INSTALL_DISK} set 1 boot on
parted -s ${INSTALL_DISK} set 1 esp on
parted -s ${INSTALL_DISK} mkpart primary 513MiB 100%
parted -s ${INSTALL_DISK} print
sleep 5

# Format the partitions:

BOOT_PART=$(lsblk -lnp -o NAME ${INSTALL_DISK} | sed -n '2p')
ROOT_PART=$(lsblk -lnp -o NAME ${INSTALL_DISK} | sed -n '3p')

mkfs.vfat -F32 ${BOOT_PART}

echo "${INSTALL_DISK_PASSWORD}" | cryptsetup -q luksFormat ${ROOT_PART}
echo "${INSTALL_DISK_PASSWORD}" | cryptsetup luksOpen ${ROOT_PART} luks

pvcreate /dev/mapper/luks
vgcreate vg0 /dev/mapper/luks
lvcreate -L 8G vg0 -n swap
lvcreate -L 64G vg0 -n root
lvcreate -l +100%FREE vg0 -n home
lvdisplay

mkswap /dev/mapper/vg0-swap
mkfs.ext4 /dev/mapper/vg0-root
mkfs.ext4 /dev/mapper/vg0-home

vgchange -a n vg0
cryptsetup luksClose luks

# Done:

echo "Formatting complete."
