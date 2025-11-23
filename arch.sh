#!/bin/bash
# Arch + Hyperland full installation script
# WARNING: This will erase /dev/sda

set -e

DISK="/dev/sda"
USERNAME="user"

echo "=== Setting keyboard layout (optional) ==="
loadkeys us

echo "=== Updating system clock ==="
timedatectl set-ntp true

echo "=== Partitioning the disk ==="
# Using sfdisk for automatic GPT partitioning
echo "label: gpt
size=512M, type=U
size=, type=L
" | sfdisk $DISK

echo "=== Formatting partitions ==="
mkfs.fat -F32 ${DISK}1      # EFI
mkfs.ext4 ${DISK}2          # root

echo "=== Mounting partitions ==="
mount ${DISK}2 /mnt
mkdir /mnt/boot
mount ${DISK}1 /mnt/boot

echo "=== Installing base system ==="
pacstrap /mnt base linux linux-firmware git base-devel sudo vim

echo "=== Generating fstab ==="
genfstab -U /mnt >> /mnt/etc/fstab

echo "=== Chroot into new system ==="
arch-chroot /mnt /bin/bash <<EOF
set -e

echo "=== Setting timezone ==="
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

echo "=== Setting locale ==="
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "=== Setting hostname ==="
echo "arch-hyperland" > /etc/hostname
cat >> /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   arch-hyperland.localdomain arch-hyperland
HOSTS

echo "=== Setting root password ==="
echo "root:root" | chpasswd

echo "=== Creating user ==="
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$USERNAME" | chpasswd

echo "=== Enabling sudo for wheel group ==="
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

echo "=== Installing bootloader (systemd-boot) ==="
bootctl --path=/boot install
PARTUUID=\$(blkid -s PARTUUID -o value $DISK2)
cat > /boot/loader/entries/arch.conf <<BOOT
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=PARTUUID=$PARTUUID rw
BOOT
cat > /boot/loader/loader.conf <<LOADER
default arch
timeout 3
LOADER

echo "=== Enabling NetworkManager ==="
pacman -S --noconfirm networkmanager
systemctl enable NetworkManager

echo "=== Installing Hyperland and tools ==="
pacman -S --noconfirm hyperland \
waybar wofi mako grim slurp alacritty swaybg \
xdg-desktop-portal-hyprland ttf-dejavu ttf-liberation noto-fonts git neovim

echo "=== Creating Hyperland config directory ==="
mkdir -p /home/$USERNAME/.config/hyperland
cat > /home/$USERNAME/.config/hyperland/config <<CONFIG
bind = Super+Return, exec alacritty
bind = Super+d, exec wofi
bind = Super+Q, close
bind = Super+{1..9}, workspace {1..9}
CONFIG
chown -R $USERNAME:$USERNAME /home/$USERNAME/.config

EOF

echo "=== Installation complete! ==="
echo "Reboot and remove USB to start Hyperland."
