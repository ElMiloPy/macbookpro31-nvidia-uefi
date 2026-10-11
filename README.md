# MacBook Pro 3,1 (Late 2007) - Native UEFI 64-bit NVIDIA 340.108 Support Toolkit

This repository contains the complete patchset, authentic extracted VBIOS ROM, and automated installation tools to run the proprietary legacy **NVIDIA 340.108** driver under **native 64-bit UEFI mode** (no CSM / BIOS emulation) on Apple **MacBook Pro 3,1** (A1226 / A1260, GeForce 8600M GT / G84).

## Features
- **Authentic VBIOS Injection**: Resolves `failed to copy vbios to system memory (0x30:0xffffffff:747)`.
- **VGA Console Probe Bypass**: Eliminates `RmInitAdapter failed (0x25:0xffffffff:1197)`.
- **Display Sub-Engine Traps Patch**: Neutralizes NULL display engine pointer dereferences (`0x840`, `0x838`, `0x1c`, `0x19`) in native UEFI mode.
- **Full Hardware Acceleration**: 100% direct 2D/3D OpenGL 3.3 hardware rendering.
- **Keyboard Backlight**: Maximum brightness on boot with non-root user control.
- **Thermal Management**: Preconfigured `mbpfan` profile to protect the G84 GPU.
- **GPU Status Monitor**: Custom `gpu-status` CLI displaying silicon die temp (`TG0D`), Apple SMC fans, VRAM, and active processes.

## Quick Install (on an existing Arch Linux system)
```bash
# 1. Install prerequisites (dkms, linux-headers, nvidia-340xx-dkms)
# 2. Clone and run automated patcher:
git clone https://github.com/ElMiloPy/macbookpro31-nvidia-uefi.git
cd macbookpro31-nvidia-uefi
sudo ./patch-and-install.sh
```

## Repository Structure
- `8600m_vbios.rom`: Raw 48,128-byte authentic GeForce 8600M GT VBIOS.
- `8600m_vbios.h`: C-array header for kernel injection.
- `patch_nv_kernel.py`: Deterministic binary patcher for `nv-kernel.o` (23 binary chunks).
- `os-interface.c.patch`: Hook into `nv_printf` with trampoline `0x5642494f`.
- `nv.c.patch`: Primary VGA force flag patch.
- `20-nvidia.conf`: Xorg configuration with proper `libglx.so` pathing.
- `mbpfan.conf`: Aggressive thermal cooling configuration for Apple SMC.
- `kbd_backlight.conf`: Boot persistence for keyboard backlight.
- `90-backlight.rules`: Udev permission rules for unprivileged brightness control.
- `gpu-status`: CLI hardware status monitor.
- `patch-and-install.sh`: All-in-one patcher and DKMS build script.
