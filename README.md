# init-scripts

This is an Ansible playbook to provision my machine using Arch Linux. It is
designed to run immediately after the initial install, but may also be used to
keep the system up-to-date.

Please be advised that this playbook is designed solely to address my own use
cases. It may provide a helpful starting point for other projects, but your
mileage may vary.

## Installing Arch Linux

If you're starting from scratch, then install Arch Linux according to the
[Installation guide](https://wiki.archlinux.org/index.php/Installation_guide).
What follows is a brief summary of the steps required to get a working system.

Connect to wifi:

    wifi-menu

Update the system clock:

    timedatectl set-ntp true

Partition the disk:

    parted -s /dev/sda mklabel gpt
    parted -s /dev/sda mkpart primary fat32 1MiB 513MiB
    parted -s /dev/sda set 1 boot on
    parted -s /dev/sda set 1 esp on
    parted -s /dev/sda mkpart primary 513MiB 100%
    parted -s /dev/sda print

Format the partitions:

    mkfs.vfat -F32 /dev/sda1

    cryptsetup luksFormat /dev/sda2
    cryptsetup luksOpen /dev/sda2 luks

    pvcreate /dev/mapper/luks
    vgcreate arch /dev/mapper/luks
    lvcreate -L 8G arch -n swap
    lvcreate -l +100%FREE arch -n root
    lvdisplay

    mkfs.ext4 /dev/mapper/arch-root
    mkswap /dev/mapper/arch-swap

    mount /dev/mapper/arch-root /mnt
    swapon /dev/mapper/arch-swap

    mkdir /mnt/boot
    mount /dev/sda1 /mnt/boot

Install the base system:

    pacstrap /mnt base git

Generate the fstab:

    genfstab -U /mnt >> /mnt/etc/fstab

Change root into the new system:

    arch-chroot /mnt

Run **stage 1**:

    git clone https://github.com/desheffer/init-scripts /root/init-scripts

    cd /root/init-scripts
    ./init.sh
    ./stage1.sh

Reboot:

    exit
    umount -R /mnt
    reboot

Run **stage 2**:

    cd /root/init-scripts
    ./stage2.sh

Reboot into the new system:

    reboot
