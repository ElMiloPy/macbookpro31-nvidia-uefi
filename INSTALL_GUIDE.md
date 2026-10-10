# Guía Definitiva: Instalación de Arch Linux en MacBook Pro 3,1 (Late 2007)
## Modo UEFI Nativo 64-bit + Btrfs con Subvolúmenes + rEFInd + NVIDIA 340.108

Esta guía documenta el procedimiento paso a paso para instalar Arch Linux desde un Live USB de Fedora en una **MacBook Pro 3,1 (A1226 / A1260, finales de 2007)** con GPU **GeForce 8600M GT**, configurada en **modo UEFI nativo puro (sin CSM ni Hybrid MBR)**.

---

# PARTE 1: Instalación del Sistema Base (Solo Terminal / CLI)

### 1. Preparar el entorno desde Fedora Live
Inicia el MacBook Pro con el pendrive Live de Fedora (mantén presionada la tecla `Option/Alt` al encender y selecciona "EFI Boot").
Abre una terminal en Fedora Live y obtén permisos de root:
```bash
sudo -i
```

Instala las herramientas de instalación de Arch Linux:
```bash
# Fedora incluye los scripts oficiales de instalación de Arch:
dnf install -y arch-install-scripts btrfs-progs
```

---

### 2. Particionado del Disco (GPT Puro)
Identifica tu disco interno (usualmente `/dev/sda`):
```bash
lsblk
```

Crea una tabla de particiones **GPT pura** (¡nunca MBR híbrido!):
```bash
gdisk /dev/sda
```
Dentro de `gdisk`:
1. `o` -> Crea una nueva tabla GPT vacía (confirma con `y`).
2. `n` -> Partición 1 (EFI):
   - Primer sector: Default (Enter)
   - Último sector: `+512M`
   - Código de tipo: `ef00` (EFI System Partition)
3. `n` -> Partición 2 (Btrfs Root):
   - Primer sector: Default (Enter)
   - Último sector: Resto del disco (Enter)
   - Código de tipo: `8300` (Linux filesystem)
4. `w` -> Escribe la tabla en el disco y sal (confirma con `y`).

---

### 3. Formateo y Creación de Subvolúmenes Btrfs

#### 3.1. Formatear la partición EFI:
```bash
mkfs.vfat -F32 -n "EFI" /dev/sda1
```

#### 3.2. Formatear la partición Btrfs:
```bash
mkfs.btrfs -f -L "ARCH_ROOT" /dev/sda2
```

#### 3.3. Crear los subvolúmenes Btrfs:
```bash
# Montaje temporal de la raíz de Btrfs
mount /dev/sda2 /mnt

# Creación de subvolúmenes
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var
btrfs subvolume create /mnt/@snapshots

# Desmontar para remontar ordenadamente con subvolúmenes
umount /mnt
```

#### 3.4. Montar los subvolúmenes con compresión Zstd:
```bash
MOUNT_OPTS="noatime,compress=zstd:1,space_cache=v2"

# Montar raíz (@)
mount -o ${MOUNT_OPTS},subvol=@ /dev/sda2 /mnt

# Crear directorios para los demás puntos de montaje
mkdir -p /mnt/{boot,home,var,.snapshots}

# Montar subvolúmenes
mount -o ${MOUNT_OPTS},subvol=@home /dev/sda2 /mnt/home
mount -o ${MOUNT_OPTS},subvol=@var /dev/sda2 /mnt/var
mount -o ${MOUNT_OPTS},subvol=@snapshots /dev/sda2 /mnt/.snapshots

# Montar la partición EFI directamente en /boot
mount /dev/sda1 /mnt/boot
```

---

### 4. Instalación de Paquetes Base con `pacstrap`
```bash
pacstrap -K /mnt base base-devel linux-lts linux-lts-headers linux-firmware \
  btrfs-progs networkmanager git vim sudo refind efibootmgr dkms \
  bluez bluez-utils lm_sensors brightnessctl psmisc
```

Genera el archivo `fstab`:
```bash
genfstab -U /mnt >> /mnt/etc/fstab
```
*(Verifica con `cat /mnt/etc/fstab` que todos los subvolúmenes y `/boot` estén presentes).*

---

### 5. Configuración del Sistema (`arch-chroot`)
Ingresa al nuevo sistema Arch:
```bash
arch-chroot /mnt
```

#### 5.1. Zona horaria y localización:
```bash
ln -sf /usr/share/zoneinfo/America/Santiago /etc/localtime   # Ajusta a tu zona horaria
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "es_CL.UTF-8 UTF-8" >> /etc/locale.gen   # O tu variante preferida
locale-gen

echo "LANG=es_CL.UTF-8" > /etc/locale.conf
echo "MiWiFi-R3600-srv" > /etc/hostname      # O el nombre de host que prefieras
```

#### 5.2. Crear usuario y configurar sudo:
```bash
# Contraseña de root
passwd

# Crear tu usuario (ejemplo: emilio)
useradd -m -g users -G wheel,video,input,storage,power -s /bin/bash emilio
passwd emilio

# Habilitar permisos sudo para el grupo wheel
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
```

#### 5.3. Habilitar Servicios de Red y Bluetooth:
```bash
systemctl enable NetworkManager
systemctl enable bluetooth
```
*(El chip Wi-Fi Atheros `ath9k` y Bluetooth vienen integrados en el kernel y se activan automáticamente).*

---

### 6. Instalar y Configurar el Bootloader (rEFInd)
En MacBooks antiguas con firmware de 64 bits, **rEFInd** es el gestor de arranque EFI nativo más robusto y elegante:

```bash
refind-install
```

Configura las opciones de arranque para Btrfs con subvolúmenes en `/boot/refind_linux.conf`:
```bash
UUID=$(blkid -s UUID -o value /dev/sda2)

cat << EOF > /boot/refind_linux.conf
"Boot using default options"     "root=UUID=${UUID} rw rootflags=subvol=@ initrd=initramfs-linux-lts.img quiet"
"Boot into terminal"             "root=UUID=${UUID} rw rootflags=subvol=@ initrd=initramfs-linux-lts.img systemd.unit=multi-user.target"
"Boot fallback"                  "root=UUID=${UUID} rw rootflags=subvol=@ initrd=initramfs-linux-lts-fallback.img"
EOF
```

---

### 7. Control Térmico (`mbpfan`) y Brillo del Teclado

#### 7.1. Compilar e instalar `mbpfan`:
```bash
cd /tmp
git clone https://github.com/linux-on-mac/mbpfan.git
cd mbpfan
make && make install
cp mbpfan.service /etc/systemd/system/
systemctl enable mbpfan
```

#### 7.2. Configuración de ventiladores en `/etc/mbpfan.conf`:
```ini
[general]
low_temp = 55
high_temp = 62
max_temp = 78
polling_interval = 1
```

#### 7.3. Brillo de teclado automático al 100% en el arranque:
```bash
cat << 'EOF' > /etc/tmpfiles.d/kbd_backlight.conf
w /sys/class/leds/smc::kbd_backlight/brightness - - - - 255
EOF

cat << 'EOF' > /etc/udev/rules.d/90-backlight.rules
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="smc::kbd_backlight", RUN+="/bin/chmod a+w /sys/class/leds/%k/brightness"
EOF
```

---

### 8. Instalar y Parchear el Driver NVIDIA 340.108 (UEFI Nativo)

Como tu usuario normal (`emilio`), compila el paquete `nvidia-340xx-dkms` desde AUR:
```bash
su - emilio
git clone https://aur.archlinux.org/nvidia-340xx-dkms.git
cd nvidia-340xx-dkms
makepkg -sirc --noconfirm
exit
```

Ahora clona tu repositorio de GitHub con los parches automatizados e instálalos:
```bash
cd /root
git clone https://github.com/ElMiloPy/macbookpro31-nvidia-uefi.git
cd macbookpro31-nvidia-uefi
./patch-and-install.sh
```

El script `./patch-and-install.sh`:
1. Copia el VBIOS auténtico extraído (`8600m_vbios.h`) a `/usr/src/nvidia-340.108/`.
2. Aplica los parches de trampolín en `os-interface.c` y `nv.c`.
3. Parchea quirúrgicamente los 23 bloques binarios de `nv-kernel.o` (anulando los fallos de consola VGA y punteros nulos de display).
4. Recompila con DKMS para tu kernel `linux-lts`.
5. Deja instalada la herramienta `gpu-status` en `/usr/local/bin/gpu-status`.

---

### 9. Finalizar y Reiniciar
Sal del chroot y desmonta todo:
```bash
exit   # Sal de arch-chroot
umount -R /mnt
reboot
```

Retira el pendrive de Fedora. El MacBook Pro iniciará directamente en modo UEFI nativo con rEFInd y tu instalación base limpia de Arch Linux.

---

# PARTE 2: Instalación del Entorno Gráfico (LXQt + LightDM)

*(Realiza este paso si deseas tener escritorio gráfico. Puedes ejecutarlo inmediatamente después de reiniciar en tu sistema base).*

### 1. Instalar Servidor Gráfico y LXQt
Inicia sesión como tu usuario o `root` en la consola y ejecuta:
```bash
sudo pacman -S --noconfirm \
  xorg-server xorg-xinit \
  lxqt openbox \
  lightdm lightdm-gtk-greeter accountsservice \
  qterminal pcmanfm-qt \
  mesa-utils mesa-demos \
  ffmpeg
```

---

### 2. Configurar LightDM para Driver Legacy NVIDIA
Debido a que el driver 340.108 es UMS (User Mode Setting) y no KMS, debemos indicarle a LightDM que inicie el servidor Xorg sin esperar nodos DRM:

Edita `/etc/lightdm/lightdm.conf` y asegúrate de configurar bajo `[LightDM]`:
```ini
[LightDM]
logind-check-graphical=false
```

---

### 3. Configurar Apariencia del Login (Fondo 1440x900)
Para que el greeter se visualice nítido y centrado a la resolución nativa de 1440x900 de la pantalla:

```bash
sudo mkdir -p /usr/share/backgrounds
# Puedes usar un fondo de LXQt reescalado a la resolución nativa:
sudo ffmpeg -y -i /usr/share/lxqt/wallpapers/appleflower.png \
  -vf "scale=1440:900:force_original_aspect_ratio=increase,crop=1440:900" \
  /usr/share/backgrounds/macbook_bg.png
```

En `/etc/lightdm/lightdm-gtk-greeter.conf`:
```ini
[greeter]
background=/usr/share/backgrounds/macbook_bg.png
```

---

### 4. Habilitar Servicios Gráficos y Reiniciar
```bash
sudo systemctl enable accounts-daemon
sudo systemctl enable lightdm
sudo systemctl restart lightdm
```

---

### 5. Verificación de Aceleración 3D en el Escritorio
Al iniciar sesión en LXQt, abre **QTerminal** y comprueba:

1. **Aceleración por hardware:**
   ```bash
   glxinfo -B
   # Verás: direct rendering: Yes | OpenGL renderer: GeForce 8600M GT
   ```
2. **Fotogramas por segundo:**
   ```bash
   __GL_SYNC_TO_VBLANK=0 glxgears
   # Verás ~4000 FPS procesados por hardware.
   ```
3. **Monitoreo de estado integral:**
   ```bash
   gpu-status
   # Muestra temperatura de silicio (TG0D), RPM de ventiladores, VRAM y clientes X11.
   ```
