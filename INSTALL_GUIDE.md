# Definitive Guide: Arch Linux Installation on MacBook Pro 3,1 (Late 2007)
## Pure 64-bit Native UEFI Mode + Kernel 7.x (Default) + Btrfs (@arch, @arch-home, @arch-opt) + 6GiB Swap + rEFInd + NVIDIA 340.108

This guide documents the step-by-step procedure to install Arch Linux from a Fedora Live USB on an Apple **MacBook Pro 3,1 (A1226 / A1260, Late 2007)** with **GeForce 8600M GT** GPU, configured in **pure native UEFI mode (no CSM or Hybrid MBR)**, with automated partitioning and custom Btrfs subvolumes.

The system kernel is the **Linux 7.x** branch (`linux` and `linux-headers`), with fully verified hardware acceleration support for the NVIDIA 340.108 driver via modern compatibility shims (`sysfb`, `in_hardirq`, `-fms-extensions`).

---

# PART 1: Base System Installation (Terminal / CLI Only)

### 1. Prepare Environment from Fedora Live
Boot the MacBook Pro with the Fedora Live USB (hold the `Option/Alt` key at startup and select "EFI Boot").
Open a terminal in Fedora Live and get root privileges:
```bash
sudo -i
```

Install partitioning and Arch Linux tools in Fedora:
```bash
dnf install -y arch-install-scripts btrfs-progs gdisk
```

---

### 2. Automatic Disk Partitioning (Assuming `/dev/sda`)
Run these commands to partition the disk in a 100% automated, non-interactive manner with pure GPT:

```bash
# 1. Wipe previous partition tables completely
sgdisk -Z /dev/sda

# 2. Partition 1: 512 MiB EFI (type ef00)
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" /dev/sda

# 3. Partition 2: Btrfs filling the space leaving 6 GiB at the end (type 8300)
sgdisk -n 2:0:-6G -t 2:8300 -c 2:"linux" /dev/sda

# 4. Partition 3: Swap using the remaining 6 GiB at the end (type 8200)
sgdisk -n 3:0:0 -t 3:8200 -c 3:"SWAP" /dev/sda

# Inform kernel of new partition table
partprobe /dev/sda
```

Verify resulting structure:
```bash
lsblk /dev/sda
# /dev/sda1 -> 512M (EFI)
# /dev/sda2 -> Remaining disk space (linux)
# /dev/sda3 -> 6G (SWAP)
```

---

### 3. Formatting and Btrfs Subvolume Creation

#### 3.1. Format Partitions:
```bash
# EFI Partition (512 MiB)
mkfs.vfat -F32 -n "EFI" /dev/sda1

# Btrfs partition labeled "linux"
mkfs.btrfs -f -L "linux" /dev/sda2

# 6 GiB Swap partition and activation
mkswap -L "swap" /dev/sda3
swapon /dev/sda3
```

#### 3.2. Create Btrfs Subvolumes (`@arch`, `@arch-home`, `@arch-opt`):
```bash
# Temporary mount of Btrfs root
mount /dev/sda2 /mnt

# Create requested subvolumes
btrfs subvolume create /mnt/@arch
btrfs subvolume create /mnt/@arch-home
btrfs subvolume create /mnt/@arch-opt

# Unmount to assemble final structure
umount /mnt
```

#### 3.3. Mount Subvolumes and EFI Partition:
```bash
MOUNT_OPTS="noatime,compress=zstd:1,space_cache=v2"

# Mount root (@arch)
mount -o ${MOUNT_OPTS},subvol=@arch /dev/sda2 /mnt

# Create mount directories
mkdir -p /mnt/{boot,home,opt}

# Mount subvolumes
mount -o ${MOUNT_OPTS},subvol=@arch-home /dev/sda2 /mnt/home
mount -o ${MOUNT_OPTS},subvol=@arch-opt /dev/sda2 /mnt/opt

# Mount EFI partition in /boot
mount /dev/sda1 /mnt/boot
```

---

### 4. Install Base Packages with `pacstrap` (Default Kernel 7.x)
Install modern **Linux 7.x** (`linux` and `linux-headers`) along with base system packages:

```bash
pacstrap -K /mnt base base-devel linux linux-headers linux-firmware \
  btrfs-progs networkmanager git vim sudo refind efibootmgr dkms \
  bluez bluez-utils lm_sensors brightnessctl psmisc
```

Generate `/etc/fstab` (automatically includes `@arch`, `@arch-home`, `@arch-opt`, `/boot`, and Swap):
```bash
genfstab -U /mnt >> /mnt/etc/fstab
```
*(Verify with `cat /mnt/etc/fstab`).*

---

### 5. System Configuration (`arch-chroot`)
Enter the new Arch system:
```bash
arch-chroot /mnt
```

#### 5.1. Timezone, Localization, and Keyboard:
```bash
ln -sf /usr/share/zoneinfo/America/Santiago /etc/localtime   # Adjust to your timezone
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us-intl" > /etc/vconsole.conf
echo "mbp-arch" > /etc/hostname
```

#### 5.2. Create User and Configure Sudo:
```bash
# Root password
passwd

# Create user
useradd -m -g users -G wheel,video,input,storage,power -s /bin/bash emilio
passwd emilio

# Enable sudo for wheel group
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
```

#### 5.3. Enable Network and Bluetooth Services:
```bash
systemctl enable NetworkManager
systemctl enable bluetooth
```
*(The Atheros Wi-Fi `ath9k` chip and Bluetooth are built into the kernel and activate automatically).*

---

### 6. Install and Configure Bootloader (rEFInd)
On 64-bit MacBooks, **rEFInd** is the ideal native EFI boot manager:

```bash
refind-install
```

Configure boot entries for Btrfs with `@arch` subvolume and **Kernel 7.x** in `/boot/refind_linux.conf`:
```bash
UUID=$(blkid -s UUID -o value /dev/sda2)

cat << EOF > /boot/refind_linux.conf
"Boot Linux 7.x (Default)"       "root=UUID=${UUID} rw rootflags=subvol=@arch initrd=initramfs-linux.img quiet"
"Boot into terminal"             "root=UUID=${UUID} rw rootflags=subvol=@arch initrd=initramfs-linux.img systemd.unit=multi-user.target"
"Boot fallback"                  "root=UUID=${UUID} rw rootflags=subvol=@arch initrd=initramfs-linux-fallback.img"
EOF
```

---

### 7. Thermal Management (`mbpfan`) and Keyboard Backlight

#### 7.1. Compile and install `mbpfan`:
```bash
cd /tmp
git clone https://github.com/linux-on-mac/mbpfan.git
cd mbpfan
make && make install
cp mbpfan.service /etc/systemd/system/
systemctl enable mbpfan
```

#### 7.2. Fan configuration in `/etc/mbpfan.conf`:
```ini
[general]
low_temp = 55
high_temp = 62
max_temp = 78
polling_interval = 1
```

#### 7.3. Keyboard backlight configuration and permissions:
Run the script included in the repository:
```bash
cd /root/macbookpro31-nvidia-uefi
./keyboard_things.sh
```
*(This sets keyboard backlight to 100% on boot via `/etc/tmpfiles.d/kbd_backlight.conf` and installs udev rules in `/etc/udev/rules.d/90-backlight.rules` for non-root brightness control).*

---

### 8. Install and Patch NVIDIA 340.108 Driver (Native UEFI + Kernel 7.x)

As your normal user (`emilio`), build the `nvidia-340xx-dkms` package from AUR:
```bash
su - emilio
git clone https://aur.archlinux.org/nvidia-340xx-dkms.git
cd nvidia-340xx-dkms
makepkg -sirc --noconfirm
exit
```

Now clone this repository with the automated patcher and install it:
```bash
cd /root
git clone https://github.com/ElMiloPy/macbookpro31-nvidia-uefi.git
cd macbookpro31-nvidia-uefi
./patch-and-install.sh
```

The `./patch-and-install.sh` script performs the following:
1. Copies the authentic extracted VBIOS (`8600m_vbios.h`) to `/usr/src/nvidia-340.108/`.
2. Applies trampoline hook patches in `os-interface.c` and `nv.c`.
3. Injects compatibility shims for **Kernel 7.x** (`sysfb_primary_display`, `in_hardirq`, `-fms-extensions` for GCC 16, and `conftest` headers).
4. Surgically patches all 23 binary chunks in `nv-kernel.o` (bypassing VGA console checks and display null-pointer traps).
5. Compiles and installs the module with DKMS for your running kernel.
6. Installs the `gpu-status` monitoring tool to `/usr/local/bin/gpu-status`.

---

### 9. Finish and Reboot
Exit the chroot and unmount everything:
```bash
exit   # Exit arch-chroot
umount -R /mnt
swapoff -a
reboot
```

Remove the Fedora USB drive. The MacBook Pro will boot directly in native UEFI mode with rEFInd and a clean Arch Linux base installation running **Kernel 7.x**.

---

# PART 2: Desktop Environment Installation (LXQt + LightDM)

*(Perform this step if you want a graphical desktop environment. You can run it immediately after rebooting into your base system or at any time).*

### 1. Install Display Server and LXQt
Log in as your user or `root` in the console and run:
```bash
sudo pacman -S --noconfirm \
  xorg-server xorg-xinit \
  lxqt openbox \
  lightdm lightdm-gtk-greeter accountsservice \
  network-manager-applet blueman \
  qterminal pcmanfm-qt \
  mesa-utils mesa-demos \
  ffmpeg
```

---

### 2. Install NVIDIA Xorg Configuration
Run the script from the repository to configure `/etc/X11/xorg.conf.d/20-nvidia.conf`:
```bash
cd /root/macbookpro31-nvidia-uefi
sudo ./nvidia_xorg.sh
```

---

### 3. Configure LightDM for NVIDIA Legacy Driver and GTK Greeter
Because the 340.108 driver uses UMS (User Mode Setting) rather than KMS, we must instruct LightDM not to wait for DRM device nodes, and explicitly set the GTK greeter:

```bash
# Instruct LightDM not to wait for DRM/KMS device nodes
sudo sed -i '/^\[LightDM\]/a logind-check-graphical=false' /etc/lightdm/lightdm.conf

# Set lightdm-gtk-greeter as active greeter
sudo sed -i 's/^#\?greeter-session=.*/greeter-session=lightdm-gtk-greeter/' /etc/lightdm/lightdm.conf
```

---

### 4. Configure Login Screen Appearance (1440x900 Wallpaper)
To render the greeter sharply at the native 1440x900 resolution:

```bash
sudo mkdir -p /usr/share/backgrounds
# Scale an LXQt wallpaper to native resolution:
sudo ffmpeg -y -i /usr/share/lxqt/wallpapers/appleflower.png \
  -vf "scale=1440:900:force_original_aspect_ratio=increase,crop=1440:900" \
  /usr/share/backgrounds/macbook_bg.png
```

In `/etc/lightdm/lightdm-gtk-greeter.conf`:
```ini
[greeter]
background=/usr/share/backgrounds/macbook_bg.png
```

---

### 5. Enable Graphical Services and Start LightDM
```bash
sudo systemctl enable accounts-daemon
sudo systemctl enable lightdm
sudo systemctl restart lightdm
```

---

### 6. Verify 3D Hardware Acceleration on Desktop
Once logged into LXQt, open **QTerminal** and verify:

1. **Hardware Acceleration:**
   ```bash
   glxinfo -B
   # Output: direct rendering: Yes | OpenGL renderer: GeForce 8600M GT
   ```
2. **Framerate:**
   ```bash
   __GL_SYNC_TO_VBLANK=0 glxgears
   # Output: ~4000 FPS hardware rendered
   ```
3. **Comprehensive Hardware Status:**
   ```bash
   gpu-status
   # Displays silicon die temperature (TG0D), SMC fan speeds, VRAM, and active X11 clients.
   ```
