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

echo "[*] Step 4: Applying modern kernel compatibility shims (Linux 7.x / 6.x)..."
# 4.1: nv-linux.h in_hardirq & sysfb shims
python3 -c '
with open("'$SRC_DIR'/nv-linux.h", "r") as f:
    c = f.read()
if "in_hardirq()" not in c:
    c = c.replace("#include <linux/interrupt.h>", "#include <linux/interrupt.h>\n#ifndef in_irq\n#define in_irq() in_hardirq()\n#endif")
if "sysfb_primary_display" not in c:
    target = "#include <linux/screen_info.h>      /* screen_info                      */"
    rep = target + "\n#if LINUX_VERSION_CODE >= KERNEL_VERSION(7, 0, 0)\n#include <linux/sysfb.h>\n#define screen_info (sysfb_primary_display.screen)\n#else\nextern struct screen_info screen_info;\n#endif"
    c = c.replace(target, rep)
with open("'$SRC_DIR'/nv-linux.h", "w") as f:
    f.write(c)
'

# 4.2: nvidia-modules-common.mk -fms-extensions for GCC 16
if ! grep -q -- "-fms-extensions" "$SRC_DIR/nvidia-modules-common.mk"; then
  sed -i 's/-std=gnu17/-std=gnu11 -fms-extensions/' "$SRC_DIR/nvidia-modules-common.mk"
fi

# 4.3: conftest.sh modern CFLAGS and kernel headers
if ! grep -q "compiler-version.h" "$SRC_DIR/conftest.sh"; then
  sed -i 's/BASE_CFLAGS="-I\${SCRIPTDIR} -std=gnu17 -O2/BASE_CFLAGS="-I\${SCRIPTDIR} -std=gnu11 -O2 -fms-extensions -fno-PIE -m64 -mno-red-zone -mcmodel=kernel/' "$SRC_DIR/conftest.sh"
  sed -i 's/-nostdinc -isystem \$ISYSTEM"/-nostdinc -isystem \$ISYSTEM -include \$HEADERS\/linux\/compiler-version.h -include \$HEADERS\/linux\/kconfig.h -include \$HEADERS\/linux\/compiler_types.h"/' "$SRC_DIR/conftest.sh"
fi

# 4.4: dkms.conf compiler version check override
if ! grep -q "IGNORE_CC_MISMATCH=1" "$SRC_DIR/dkms.conf"; then
  sed -i 's/MAKE\[0\]="make/MAKE\[0\]="make IGNORE_CC_MISMATCH=1/' "$SRC_DIR/dkms.conf"
fi

echo "[*] Step 5: Binary patching nv-kernel.o..."
python3 "$SCRIPT_DIR/patch_nv_kernel.py" "$SRC_DIR/nv-kernel.o"

echo "[*] Step 6: Installing system configurations..."
mkdir -p /etc/X11/xorg.conf.d /etc/tmpfiles.d /etc/udev/rules.d /usr/local/bin
cp "$SCRIPT_DIR/20-nvidia.conf" /etc/X11/xorg.conf.d/
cp "$SCRIPT_DIR/kbd_backlight.conf" /etc/tmpfiles.d/
cp "$SCRIPT_DIR/90-backlight.rules" /etc/udev/rules.d/
cp "$SCRIPT_DIR/gpu-status" /usr/local/bin/gpu-status
chmod +x /usr/local/bin/gpu-status

echo "[*] Step 7: Rebuilding and installing DKMS module for kernel $(uname -r)..."
dkms remove nvidia/340.108 -k "$(uname -r)" 2>/dev/null || true
IGNORE_CC_MISMATCH=1 dkms install nvidia/340.108 -k "$(uname -r)"

echo "[*] Step 8: Applying permissions and backlight rules..."
udevadm control --reload-rules && udevadm trigger || true
systemd-tmpfiles --create /etc/tmpfiles.d/kbd_backlight.conf || true

echo "=== Installation complete! Module nvidia-340.108 is ready for UEFI boot ==="
