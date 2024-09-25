# Disk formatting
```bash
fdisk -l
fdisk /dev/nvme1n1
```

`g` to create a new partition table
+1G for EFI 
`t` and `1` to set type to EFI
+16G for sawp, `t` `19`
the remaining space for linux filesystem
`w` to save and quit

```bash
mkfs.fat -F 32 /dev/nvme1n1p1
mkswap /dev/nvme1n1p2
mkfs.btrfs /dev/nvme1n1p3
mount /dev/nvme1n1p3 /mnt
```

# Disk mounting
There are several schemas to layout subvolumes, see [this section of the old sysadmin guide](https://archive.kernel.org/oldwiki/btrfs.wiki.kernel.org/index.php/SysadminGuide.html#Layout) and [ArchWiki](https://wiki.archlinux.org/title/Partitioning#Partition_scheme). Since I used btrfs I'll go with flat for easier snapshotting.
## Flat layout
```bash
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt
```
## Compression
zstd seem to perform well according to [this phoronix post](https://www.phoronix.com/review/btrfs-zstd-compress/2)
```bash
mount -o compress=zstd,subvol=@ /dev/nvme1n1p2 /mnt
mkdir -p /mnt/home
mount -o compress=zstd,subvol=@home /dev/nvme1n1p2 /mnt/home
```

## EFI partition
[This section of ArchWiki](https://wiki.archlinux.org/title/EFI_system_partition#Typical_mount_points) explains the 2 options for mountpoints but we need to use `/efi` according to [this gist](https://gist.github.com/mjkstra/96ce7a5689d753e7a6bdd92cdc169bae):
> because by choosing /boot we could experience a system crash when trying to restore @ ( the root subvolume ) to a previous state after kernel updates. This happens because /boot files such as the kernel won't reside on @ but on the efi partition and hence they can't be saved when snapshotting @. Also this choice grants separation of concerns and also is good if one wants to encrypt /boot, since you can't encrypt efi files. 

```bash
mkdir -p /mnt/efi
mount /dev/nvme1n1p1 /mnt/efi
```

# Packages installation
- btrfs-progs: user-space utilities for file system management
- grub-btrfs: adds btrfs support for the grub bootloader and enables the user to directly boot from snapshots
- inotify-tools: used by grub btrfsd deamon to automatically spot new snapshots and update grub entries
- netctl: picked from [this table on ArchWiki](https://wiki.archlinux.org/title/Network_configuration#Network_managers)
```bash
pacstrap -K /mnt base base-devel linux linux-firmware git grub efibootmgr os-prober\
    intel-ucode \
    netctl dhcpcd \
    btrfs-progs grub-btrfs inotify-tools \
    neovim zsh openssh man sudo tmux
```

# fstab
See [ArchWiki: fstab](https://wiki.archlinux.org/title/Fstab).
```bash
genfstab -U /mnt >> /mnt/etc/fstab
# Check if fstab is fine
cat /mnt/etc/fstab # should have 4 entries: efi swap home /
```

# chroot
Now we switch to the new system.
```bash
arch-chroot /mnt

# time
ln -sf /usr/share/zoneinfo/Australia/Melbourne /etc/localtime
hwclock --systohc
date

# https://wiki.archlinux.org/title/Locale
nvim /etc/locale.gen # en_US en_AU zh_CN
locale-gen
echo 'LANG=en_AU.UTF-8' > /etc/locale.conf

echo 'qArch' > /etc/hostname
vim /etc/hosts
```

```/etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 qArch
```

## Users
```bash
# root password
passwd

# new user q -m for create home, -G for adding group
useradd -mG wheel q
passwd q
EDITOR=nvim visudo # uncomment wheel group for sudo
```

## Grub
See [ArchWiki: Grub](https://wiki.archlinux.org/title/GRUB#Installation).
```bash
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
# add Win10 later
```

# Network configuration
```bash
nvim /etc/systemd/resolved.conf
nvim /etc/resolv.conf
cp /etc/netctl/examples/ethernet-dhcp /etc/netctl/default
ip address show
nvim /etc/netctl/default # replace the device name
systemctl start systemd-resolved.service
systemctl enable systemd-resolved.service
netctl start default
systemctl enable netctl
```

# Grub 
1280x1024x32

# Nvidia & Hyprland
Install kernel modules suggested in [ArchWiki](https://wiki.archlinux.org/title/NVIDIA#Installation).
```bash
sudo pacman -S nvidia-open
sudo nvim /etc/mkinitcpio.conf
# Remove nouveau and add nvidia nvidia_modeset nvidia_uvm nvidia_drm
# MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
sudo nvim /etc/modprobe.d/nvidia.conf
# create and add this line:
# options nvidia_drm modeset=1 fbdev=1
sudo mkinitcpio -p linux
```
Install hyprland, either install `polkit`or add current user to seat group and start seatd. Apply configurations for Nvidia according to [Hyprland's documentation](https://wiki.hyprland.org/Nvidia/).
```bash
# sudo usermod -a -G seat q
# sudo systemctl enable seatd
sudo pacman -S polkit hyprland nwg-look
sudo pacman -S hyprpaper # hyprland plugins
sudo pacman -S polkit-kde-agent # https://wiki.hyprland.org/Useful-Utilities/Must-have/#authentication-agent
sudo pacman -S dunst # https://wiki.hyprland.org/Useful-Utilities/Must-have/#a-notification-daemon
sudo reboot # should be able to run Hyprland after reboot
```

Need to choose a JACK implementations, choose pipewire for now. See [this youtube video](https://www.youtube.com/watch?v=HxEXMHcwtlI) for more context.
```bash
sudo pacman -S kitty noto-fonts-cjk noto-fonts firefox-developer-edition pipewire-jack
```

Disable installing `*-debug` packages by adding `!debug` to options:
```bash
sudo nvim /etc/makepkg.conf
```
Install `yay` from [Github instructions](https://github.com/Jguer/yay)

## Desktop

`xdg-utils` provides `xdg-open`, see [ArchWiki](https://wiki.archlinux.org/title/Xdg-utils)
```bash
sudo pacman -S rofi-wayland yadm xdg-utils ripgrep htop unzip fastfetch
yay -S keeweb-desktop-bin
# add ssh key to github
yadm clone git@github.com:ChangqingW/dotfiles.git 
```

## keyd
```bash
sudo pacman -S keyd
sudo systemctl enable keyd
usermod -aG keyd q
sudoedit /etc/keyd/default.conf
sudo keyd reload
mkdir ~/.config/keyd
vim ~/.config/keyd/app.conf
```

## Audio
See [Pipewire ArchWiki](https://wiki.archlinux.org/title/PipeWire)
```bash
sudo pacman -S wireplumber pipewire-pulse pipewire-alsa
sudo systemctl poweroff
wpctl status | less
wpctl set-default 53 # set audio sink number shown from wpctl status
pactl set-sink-volume 53 +20% # adjust volume
```

## Bluetooth
```bash
yay -S bluetuith
sudo systemctl enable bluetooth
sudo systemctl start bluetooth
bluetuith
yay -S bt-dualboot # https://wiki.archlinux.org/title/Bluetooth#Dual_boot_pairing
mkdir ~/bt-dualboot-backup
sudo bt-dualboot -l
sudo bt-dualboot --sync-all -b ~/bt-dualboot-backup
sudo systemctl --global enable pipewire
```
~~Somehow getting `br-connection-profile-unavailable` error when trying to connect device, with `sudo systemctl status bluetooth` showing `src/service.c:btd_service_connect() a2dp-sink profile connect failed for [MAC address] Protocol not available`, solved with `systemctl --user restart wireplumber.service` as mentioned in [this thread](https://bbs.archlinux.org/viewtopic.php?id=270465&p=3), they don't seem to know why either.~~
Need to start wireplumber before connecting bluetooth. Wireplumber is started by pipewire, i.e.  `pipewire.socket -> pipewire.service -> wireplumber.service`, this is fine except after booting up, if no media have been played, pipewire service does not autostart, hence bluetooth could not be connected. Enabling the pipewire service solves this. *I still don't understand why wireplumber has to start before connectting bluetooth, but whatever...*

## Rust
For developing rust, it is recommended to install rustup via pacman and install rust via rustup, see more on [ArchWiki](https://wiki.archlinux.org/title/Rust#Arch_Linux_package).
```bash
sudo pacman -S rustup
rustup default stable
```
# Settings on Windows
## time
Need to set windows to use UTC for time in Archlinux to work, see [System time - ArchWiki](https://wiki.archlinux.org/title/System_time#UTC_in_Microsoft_Windows)
