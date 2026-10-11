#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run as root (sudo ./nvidia_xorg.sh)"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[*] Installing NVIDIA Xorg configuration..."
mkdir -p /etc/X11/xorg.conf.d
cp "$SCRIPT_DIR/20-nvidia.conf" /etc/X11/xorg.conf.d/

echo "[+] NVIDIA Xorg configuration installed to /etc/X11/xorg.conf.d/20-nvidia.conf"
