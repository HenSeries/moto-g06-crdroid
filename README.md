# 📱 Moto G06 2025 (lagos) — Custom ROM & Performance Mod

<div align="center">

![Android](https://img.shields.io/badge/Android_15-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![Motorola](https://img.shields.io/badge/Motorola-E1000F?style=for-the-badge&logo=motorola&logoColor=white)
![MediaTek](https://img.shields.io/badge/MediaTek_MT6768-FF6600?style=for-the-badge&logo=mediatek&logoColor=white)
![crDroid](https://img.shields.io/badge/crDroid_v11.16-167C80?style=for-the-badge&logo=lineageos&logoColor=white)
![KernelSU](https://img.shields.io/badge/KernelSU-Root-FF5722?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

**Complete guide & tools for flashing crDroid GSI with performance tweaks and fixes on the Motorola Moto G06 2025.**

[📖 Full Guide](GUIDE.md) · [📥 Downloads](https://github.com/HenSeries/moto-g06-crdroid/releases) · [🐛 Issues](https://github.com/HenSeries/moto-g06-crdroid/issues)

</div>

---

## ✨ What This Does

| | Feature | Status |
|---|---|---|
| 🔓 | Unlock bootloader via kaeru exploit (Penumbra) | ✅ |
| 💿 | Flash crDroid v11.16 GSI (vanilla AOSP + microG) | ✅ |
| 🔑 | Root with KernelSU | ✅ |
| 🎧 | Fix headphone jack (SELinux policy fix) | ✅ |
| 🖥️ | Fix black screen bug (SurfaceFlinger reset) | ✅ |
| ⚡ | Performance tweaks via ADB | ✅ |
| 🌐 | Network optimization (BBR, DNS) | ✅ |
| 📦 | Debloat unnecessary packages | ✅ |

---

## 📋 Device Info

<div align="center">

| | |
|---|---|
| 📱 **Model** | Moto G06 2025 (XT2535-1/2/3/14) |
| 🏷️ **Codename** | lagos |
| 🧠 **SoC** | MediaTek MT6768 (Helio G37) |
| ⚙️ **CPU** | 6x Cortex-A55 @ 1.7GHz + 2x Cortex-A75 @ 2.0GHz |
| 🐧 **Kernel** | 6.6.66 (GKI, Android 15) |
| 💾 **RAM** | 4 GB |
| 📦 **Stock Firmware** | VVOBS35.78-158-1 |

</div>

---

## 📁 Files

| File | Description |
|---|---|
| 📖 [`GUIDE.md`](GUIDE.md) | Complete step-by-step guide with troubleshooting |
| 🧹 [`debloat.sh`](debloat.sh) | Debloat + ADB performance tweaks script |
| 🔓 [`tools/tanuki-lagos/tanuki.sh`](tools/tanuki-lagos/tanuki.sh) | Bootloader unlock script (from XDA) |
| 🛠️ [`tools/tanuki-lagos/recover.sh`](tools/tanuki-lagos/recover.sh) | Recovery — flash boot partitions via Penumbra |
| 💾 [`tools/tanuki-lagos/full_restore.sh`](tools/tanuki-lagos/full_restore.sh) | Full stock restore via Penumbra |
| 🔑 [`tools/tanuki-lagos/flash_initboot.sh`](tools/tanuki-lagos/flash_initboot.sh) | Flash init_boot via Penumbra (for KernelSU) |
| 🎧 [`tools/headphone_fix.sh`](tools/headphone_fix.sh) | Headphone jack daemon (superseded by KernelSU module) |

---

## 🚀 Quick Start

> ⚠️ **WARNING**: This process can brick your device. No warranty. You accept all risks.

```
1. 🔓 Unlock bootloader    →  tanuki.sh
2. 💾 Flash stock firmware  →  full_restore.sh
3. 💿 Flash crDroid GSI     →  fastboot flash system
4. 🔑 Root with KernelSU    →  Patch init_boot.img
5. 🎧 Fix headphone jack    →  KernelSU module (SELinux)
6. ⚡ Apply tweaks           →  ADB commands
```

👉 **See [GUIDE.md](GUIDE.md) for the full step-by-step process with detailed troubleshooting.**

---

## 📋 Requirements

| | Requirement |
|---|---|
| 🖥️ | Linux PC (bootloader unlock is Linux-only) |
| 🔌 | USB-C **data** cable (not charge-only — cable choice matters!) |
| 🦀 | Rust toolchain (for building Penumbra) |
| 📱 | `adb` and `fastboot` (Android platform-tools) |

---

## 📥 Downloads

> These files are too large for git. Download them separately.

| | File | Source | Size |
|---|---|---|---|
| 💿 | **crDroid GSI v11.16** | [GitHub Release](https://github.com/HenSeries/moto-g06-crdroid/releases) | 1.1 GB |
| 💾 | **Stock firmware VVOBS35.78-158-1** | [stockrom.net](https://www.stockrom.net/2026/04/xt2535-1-retbr-os15-vvobs35-78-158-1.html) | 4.2 GB |
| 🔓 | **Tanuki unlock package** | [XDA Thread](https://xdaforums.com/t/unlock-bootloader-motorola-motorola-g06-g06-power-lagos.4780825/) | 7.7 MB |
| 🔑 | **KernelSU Next APK** | [GitHub](https://github.com/KernelSU-Next/KernelSU-Next/releases) | 9.8 MB |

---

## ⚠️ Known Issues

| | Issue | Status | Details |
|---|---|---|---|
| 💬 | WhatsApp registration | ❌ Not fixed | microG tokens rejected by WhatsApp servers |
| 📸 | Camera aux sensors | ❌ Not fixed | Main camera works, ultrawide/macro may not |
| 🔄 | OTA updates | ❌ N/A | Must manually update crDroid GSI |
| 🏦 | Banking apps | ⚠️ Partial | kaeru spoofs boot state; basic attestation passes |

---

## 🛠️ Troubleshooting Highlights

The [GUIDE.md](GUIDE.md) contains detailed solutions for 10 issues we encountered:

| # | Issue | Quick Fix |
|---|---|---|
| 1 | 🔌 Antumbra doesn't detect phone | Try a different USB cable |
| 2 | 🔄 crDroid bootloops (slot B) | Flash to slot A instead |
| 3 | 🔄 crDroid bootloops (wrong firmware) | Use VVOBS35.78-158-1 (kernel 6.6.66) |
| 4 | 🚫 Slot marked unbootable | `fastboot set_active` clears it |
| 5 | 🔒 kaeru blocks partition writes | Use Penumbra via BROM |
| 6 | 💥 KernelSU boot image bootloop | Only patch init_boot, never replace boot |
| 7 | 🎧 Headphone jack silent | SELinux permissive via module |
| 8 | 🖥️ Black screen (backlight on) | Reset SurfaceFlinger color matrix |
| 9 | ⚠️ fastboot -w "not formatting" | Normal — Android formats on first boot |
| 10 | 💬 WhatsApp stuck on registration | microG limitation — needs real GMS |

---

## 🙏 Credits

| | Project | Role |
|---|---|---|
| 🐸 | [R0rt1z2/kaeru](https://github.com/R0rt1z2/kaeru) | Bootloader exploit |
| 🌘 | [shomykohai/penumbra](https://github.com/shomykohai/penumbra) | MTK flash tool |
| 📱 | [phhusson/treble_experimentations](https://github.com/phhusson/treble_experimentations) | Treble/GSI framework |
| 💿 | [crDroid](https://crdroid.net/) | crDroid ROM |
| 🔑 | [KernelSU](https://kernelsu.org/) | Kernel-based root |

---

<div align="center">

**⭐ Star this repo if it helped you!**

Made with ❤️ for the Moto G06 community

</div>
