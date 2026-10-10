# Guía Definitiva: Instalación de Arch Linux en MacBook Pro 3,1 (Late 2007)
## Modo UEFI Nativo 64-bit + Kernel 7.x (Predeterminado) + Btrfs (@arch, @arch-home, @arch-opt) + Swap 6GiB + rEFInd + NVIDIA 340.108

Esta guía documenta el procedimiento paso a paso para instalar Arch Linux desde un Live USB de Fedora en una **MacBook Pro 3,1 (A1226 / A1260, finales de 2007)** con GPU **GeForce 8600M GT**, configurada en **modo UEFI nativo puro (sin CSM ni Hybrid MBR)**, con particionado automático y subvolúmenes Btrfs personalizados.

El kernel del sistema es la rama **Linux 7.x** (`linux` y `linux-headers`), con soporte completo y verificado para la aceleración por hardware del driver NVIDIA 340.108 mediante shims modernos (`sysfb`, `in_hardirq`, `-fms-extensions`).

---

# PARTE 1: Instalación del Sistema Base (Solo Terminal / CLI)

### 1. Preparar el entorno desde Fedora Live
Inicia el MacBook Pro con el pendrive Live de Fedora (mantén presionada la tecla `Option/Alt` al encender y selecciona "EFI Boot").
Abre una terminal en Fedora Live y obtén permisos de root:
```bash
sudo -i
```

Instala las herramientas de particionado y de Arch Linux en Fedora:
```bash
dnf install -y arch-install-scripts btrfs-progs gdisk
```

---

### 2. Particionado Automático del Disco (Asumiendo `/dev/sda`)
Ejecuta estos comandos para particionar el disco de forma 100% automática y no interactiva con GPT puro:

```bash
# 1. Limpiar completamente tablas anteriores
sgdisk -Z /dev/sda

# 2. Partición 1: EFI de 100 MiB (tipo ef00)
sgdisk -n 1:0:+100M -t 1:ef00 -c 1:"EFI" /dev/sda

# 3. Partición 2: Btrfs llenando el espacio hasta dejar 6 GiB al final (tipo 8300)
sgdisk -n 2:0:-6G -t 2:8300 -c 2:"linux" /dev/sda

# 4. Partición 3: Swap usando los 6 GiB restantes al final (tipo 8200)
sgdisk -n 3:0:0 -t 3:8200 -c 3:"SWAP" /dev/sda

# Informar al kernel de la nueva tabla
partprobe /dev/sda
```

Verifica la estructura resultante:
```bash
lsblk /dev/sda
# /dev/sda1 -> 100M (EFI)
# /dev/sda2 -> Resto del disco (linux)
# /dev/sda3 -> 6G (SWAP)
```

---

### 3. Formateo y Creación de Subvolúmenes Btrfs

#### 3.1. Formatear las particiones:
```bash
# Partición EFI (100 MiB)
mkfs.vfat -F32 -n "EFI" /dev/sda1

# Partición Btrfs llamada "linux"
mkfs.btrfs -f -L "linux" /dev/sda2

# Partición Swap de 6 GiB y activación
mkswap -L "swap" /dev/sda3
swapon /dev/sda3
```

#### 3.2. Crear los subvolúmenes Btrfs (`@arch`, `@arch-home`, `@arch-opt`):
```bash
# Montaje temporal de la raíz de Btrfs
mount /dev/sda2 /mnt

# Crear exactamente los subvolúmenes solicitados
btrfs subvolume create /mnt/@arch
btrfs subvolume create /mnt/@arch-home
btrfs subvolume create /mnt/@arch-opt

# Desmontar para montar la estructura final
umount /mnt
```

#### 3.3. Montar los subvolúmenes y partición EFI:
```bash
MOUNT_OPTS="noatime,compress=zstd:1,space_cache=v2"

# Montar raíz (@arch)
mount -o ${MOUNT_OPTS},subvol=@arch /dev/sda2 /mnt

# Crear directorios de montaje
mkdir -p /mnt/{boot,home,opt}

# Montar subvolúmenes
mount -o ${MOUNT_OPTS},subvol=@arch-home /dev/sda2 /mnt/home
mount -o ${MOUNT_OPTS},subvol=@arch-opt /dev/sda2 /mnt/opt

# Montar partición EFI (100 MiB) en /boot
mount /dev/sda1 /mnt/boot
```

---

### 4. Instalación de Paquetes Base con `pacstrap` (Kernel 7.x Predeterminado)
Instalamos el kernel moderno **Linux 7.x** (`linux` y `linux-headers`) junto a los componentes base del sistema:

```bash
pacstrap -K /mnt base base-devel linux linux-headers linux-firmware \
  btrfs-progs networkmanager git vim sudo refind efibootmgr dkms \
  bluez bluez-utils lm_sensors brightnessctl psmisc
```

Genera el archivo `fstab` (incluirá automáticamente `@arch`, `@arch-home`, `@arch-opt`, `/boot` y la Swap):
```bash
genfstab -U /mnt >> /mnt/etc/fstab
```
*(Verifica con `cat /mnt/etc/fstab`).*

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
echo "es_CL.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

echo "LANG=es_CL.UTF-8" > /etc/locale.conf
echo "MiWiFi-R3600-srv" > /etc/hostname
```

#### 5.2. Crear usuario y configurar sudo:
```bash
# Contraseña de root
passwd

# Crear tu usuario
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
En MacBooks antiguas con firmware de 64 bits, **rEFInd** es el gestor de arranque EFI nativo ideal:

```bash
refind-install
```

Configura las opciones de arranque para Btrfs con el subvolumen `@arch` y el **Kernel 7.x** en `/boot/refind_linux.conf`:
```bash
UUID=$(blkid -s UUID -o value /dev/sda2)

cat << EOF > /boot/refind_linux.conf
"Boot Linux 7.x (Default)"       "root=UUID=${UUID} rw rootflags=subvol=@arch initrd=initramfs-linux.img quiet"
"Boot into terminal"             "root=UUID=${UUID} rw rootflags=subvol=@arch initrd=initramfs-linux.img systemd.unit=multi-user.target"
"Boot fallback"                  "root=UUID=${UUID} rw rootflags=subvol=@arch initrd=initramfs-linux-fallback.img"
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

### 8. Instalar y Parchear el Driver NVIDIA 340.108 (UEFI Nativo + Kernel 7.x)

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
3. Inyecta los shims de compatibilidad para **Kernel 7.x** (`sysfb_primary_display`, `in_hardirq`, `-fms-extensions` para GCC 16 y headers de `conftest`).
4. Parchea quirúrgicamente los 23 bloques binarios de `nv-kernel.o` (anulando los fallos de consola VGA y punteros nulos de display).
5. Compila e instala el módulo con DKMS para tu kernel en ejecución.
6. Deja instalada la herramienta `gpu-status` en `/usr/local/bin/gpu-status` (en inglés).

---

### 9. Finalizar y Reiniciar
Sal del chroot y desmonta todo:
```bash
exit   # Sal de arch-chroot
umount -R /mnt
swapoff -a
reboot
```

Retira el pendrive de Fedora. El MacBook Pro iniciará directamente en modo UEFI nativo con rEFInd y tu instalación base limpia de Arch Linux corriendo el **Kernel 7.x**.

---

# PARTE 2: Instalación del Entorno Gráfico (LXQt + LightDM)

*(Realiza este paso si deseas tener escritorio gráfico. Puedes ejecutarlo inmediatamente después de reiniciar en tu sistema base o cuando quieras).*

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
3. **Monitoreo de estado integral (en inglés):**
   ```bash
   gpu-status
   # Muestra temperatura de silicio (TG0D), RPM de ventiladores, VRAM y clientes X11.
   ```
