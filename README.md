# Moto G06 2025 (lagos) — Custom ROM & Performance Mod

Tools, scripts, and a complete guide for flashing crDroid GSI with performance tweaks and fixes on the Motorola Moto G06 2025.

## What This Does

- Unlocks the bootloader via the kaeru exploit (Penumbra)
- Flashes crDroid v11.16 GSI (vanilla AOSP with microG)
- Roots with KernelSU
- Fixes the headphone jack (SELinux policy issue)
- Prevents the black screen bug (SurfaceFlinger color matrix reset)
- Applies safe performance tweaks via ADB

## Device Info

| | |
|---|---|
| Model | Moto G06 2025 (XT2535-1/2/3/14) |
| Codename | lagos |
| SoC | MediaTek MT6768 (Helio G37) |
| Kernel | 6.6.66 (GKI, Android 15) |
| Stock Firmware | VVOBS35.78-158-1 |

## Files

| File | Description |
|---|---|
| `GUIDE.md` | Complete step-by-step guide |
| `debloat.sh` | Debloat + ADB performance tweaks script |
| `tools/tanuki-lagos/tanuki.sh` | Bootloader unlock script (from XDA) |
| `tools/tanuki-lagos/recover.sh` | Recovery script — flashes boot partitions via Penumbra |
| `tools/tanuki-lagos/full_restore.sh` | Full stock restore via Penumbra |
| `tools/tanuki-lagos/flash_initboot.sh` | Flash init_boot via Penumbra (for KernelSU) |
| `tools/headphone_fix.sh` | Headphone jack monitoring daemon (superseded by KernelSU module) |

## Quick Start

See [GUIDE.md](GUIDE.md) for the full step-by-step process.

## Requirements

- Linux PC
- USB-C data cable
- Rust toolchain (for building Penumbra)
- `adb` and `fastboot`

## Downloads (not included — too large for git)

1. **Tanuki unlock package** — [XDA Thread](https://xdaforums.com/t/unlock-bootloader-motorola-motorola-g06-g06-power-lagos.4780825/)
2. **Stock firmware VVOBS35.78-158-1** — [stockrom.net](https://www.stockrom.net/2026/04/xt2535-1-retbr-os15-vvobs35-78-158-1.html)
3. **crDroid GSI v11.16** — [SourceForge](https://sourceforge.net/projects/crdroidos/files/GSI/)
4. **KernelSU Next** — [GitHub](https://github.com/KernelSU-Next/KernelSU-Next/releases)

## Known Issues

- **WhatsApp**: Registration fails due to microG (needs real Google Play Services)
- **Camera**: Main camera works, aux sensors may not
- **OTA**: Won't work, must manually update

## Credits

- [R0rt1z2](https://github.com/R0rt1z2/kaeru) — kaeru bootloader exploit
- [shomykohai](https://github.com/shomykohai/penumbra) — Penumbra MTK flash tool
- [phhusson](https://github.com/phhusson/treble_experimentations) — Treble/GSI framework
- [crDroid](https://crdroid.net/) — crDroid ROM
- [KernelSU](https://kernelsu.org/) — Kernel-based root
