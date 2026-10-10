#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run as root (sudo ./patch-and-install.sh)"
  exit 1
fi

SRC_DIR="/usr/src/nvidia-340.108"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== MacBook Pro 3,1 NVIDIA 340.108 Native UEFI Installer ==="

if [ ! -d "$SRC_DIR" ]; then
  echo "[-] Error: Source directory $SRC_DIR not found."
  echo "    Ensure nvidia-340xx-dkms is installed first via yay/makepkg."
  exit 1
fi

echo "[*] Step 1: Copying 8600m_vbios.h to source tree..."
cp "$SCRIPT_DIR/8600m_vbios.h" "$SRC_DIR/"

echo "[*] Step 2: Patching os-interface.c..."
if ! grep -q "8600m_vbios.h" "$SRC_DIR/os-interface.c"; then
  patch -d "$SRC_DIR" -p0 < "$SCRIPT_DIR/os-interface.c.patch"
else
  echo "    os-interface.c already patched."
fi

echo "[*] Step 3: Patching nv.c..."
if ! grep -q "nv->primary_vga = 1;" "$SRC_DIR/nv.c"; then
  patch -d "$SRC_DIR" -p0 < "$SCRIPT_DIR/nv.c.patch"
else
  echo "    nv.c already patched."
fi

echo "[*] Step 4: Binary patching nv-kernel.o..."
python3 "$SCRIPT_DIR/patch_nv_kernel.py" "$SRC_DIR/nv-kernel.o"

echo "[*] Step 5: Installing system configurations..."
mkdir -p /etc/X11/xorg.conf.d /etc/tmpfiles.d /etc/udev/rules.d /usr/local/bin
cp "$SCRIPT_DIR/20-nvidia.conf" /etc/X11/xorg.conf.d/
cp "$SCRIPT_DIR/kbd_backlight.conf" /etc/tmpfiles.d/
cp "$SCRIPT_DIR/90-backlight.rules" /etc/udev/rules.d/
cp "$SCRIPT_DIR/gpu-status" /usr/local/bin/gpu-status
chmod +x /usr/local/bin/gpu-status

echo "[*] Step 6: Rebuilding and installing DKMS module for kernel $(uname -r)..."
dkms remove nvidia/340.108 -k "$(uname -r)" 2>/dev/null || true
IGNORE_CC_MISMATCH=1 dkms install nvidia/340.108 -k "$(uname -r)"

echo "[*] Step 7: Applying permissions and backlight rules..."
udevadm control --reload-rules && udevadm trigger || true
systemd-tmpfiles --create /etc/tmpfiles.d/kbd_backlight.conf || true

echo "=== Installation complete! Module nvidia-340.108 is ready for UEFI boot ==="
