#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run as root (sudo ./keyboard_things.sh)"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[*] Installing keyboard backlight configuration and udev rules..."
mkdir -p /etc/tmpfiles.d /etc/udev/rules.d
cp "$SCRIPT_DIR/kbd_backlight.conf" /etc/tmpfiles.d/
cp "$SCRIPT_DIR/90-backlight.rules" /etc/udev/rules.d/

udevadm control --reload-rules && udevadm trigger || true
command -v systemd-tmpfiles >/dev/null 2>&1 && systemd-tmpfiles --create /etc/tmpfiles.d/kbd_backlight.conf || true

echo "[+] Keyboard backlight configured (persisted at 100% on boot with non-root access)."
