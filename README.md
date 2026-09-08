# 📱 Moto G06 2025 (lagos) — Android 16 + Root + Customization

<div align="center">

![Android](https://img.shields.io/badge/Android_16-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![Motorola](https://img.shields.io/badge/Motorola-E1000F?style=for-the-badge&logo=motorola&logoColor=white)
![MediaTek](https://img.shields.io/badge/MediaTek_MT6768-FF6600?style=for-the-badge&logo=mediatek&logoColor=white)
![TrebleDroid](https://img.shields.io/badge/TrebleDroid_AOSP_16-167C80?style=for-the-badge&logo=lineageos&logoColor=white)
![KernelSU](https://img.shields.io/badge/KernelSU_Next-Root-FF5722?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

**Android 16 on the Moto G06 2025 — stable across reboots, rooted, 7.6 GB effective RAM,
microG without signature spoofing, and deep UI customization.**

[📖 Full Guide](GUIDE.md)

</div>

---

## ⚠️ This replaces the old crDroid guide

The earlier crDroid (Android 15) / BaikalOS 16 setup documented here **was unstable and
is no longer recommended**. It survived only **one boot per wipe** — every second reboot
hung at the Motorola logo. Four separate root-cause theories were investigated and all
proved wrong; one recovery attempt erased the preloader and briefly bricked the device.

**The current setup is materially more stable and more capable**, and runs **Android 16**.
It reboots reliably, and supports root, virtual RAM, microG, and SystemUI theming.

The deciding factor turned out to be **which GSI build you use** — not the vendor blob,
not the TEE. See [GUIDE.md](GUIDE.md) for the compatibility table and the selection rule.

---

## ✨ What This Does

| | Feature | Status |
|---|---|---|
| 🔓 | Unlock bootloader via kaeru exploit (Penumbra) | ✅ |
| 💿 | TrebleDroid AOSP **16** GSI — stable across reboots | ✅ |
| 🔑 | Root with KernelSU Next v3.3.0 | ✅ |
| 🧩 | Mountify metamodule (required by KernelSU v3) | ✅ |
| 🧠 | **4 GB virtual RAM** via swapfile → 7.64 GB total | ✅ |
| ☁️ | microG as system app, **no signature spoofing needed** | ✅ |
| 🪝 | Xposed via Zygisk Next + Vector | ✅ |
| 🎨 | Iconify + Pixel Launcher Enhanced | ✅ |
| ⚙️ | Custom Quick Settings layout (RRO overlay) | ✅ |
| 📦 | Debloat + DEX recompile | ✅ |
| 📞 | **SIM calls break the mic until reboot** | ⚠️ **known bug** |

---

## 🐛 Known issues

| Issue | Detail |
|---|---|
| **Calls break the microphone** | Calls connect and work, but afterwards the mic is unusable until the phone is rebooted. **Not yet diagnosed** — being worked on. |
| Iconify QS layout | Iconify 8.0.0 has no Android 16 QS-layout hooks. Use `tools/build_qs_overlay.sh`. |
| 🖤 Grayscale blacks the screen | Hardware limit (HWC can't do colour transforms). `modules/display_guard` auto-recovers on every boot |
| zRAM | Impossible on this device — no `zram.ko` shipped. The swapfile module is the replacement. |

---

## 📋 Current stack

| Layer | What |
|---|---|
| ROM | TrebleDroid AOSP 16 vanilla (`ponces/treble_aosp`) |
| Root | KernelSU Next v3.3.0 (spoofed), `init_boot` patch |
| Metamodule | Mountify v2.0.4 — **required**, or `/system` modules silently no-op |
| Zygisk / Xposed | Zygisk Next 1.5.0 + Vector v2.2 |
| Google services | microG no-sigspoof (system app) |
| Memory | 3.64 GB physical + 4 GB swap = **7.64 GB** |
| UI | Iconify 8.0.0, Pixel Launcher Enhanced, custom QS overlay |

---

## 🧰 Tools in this repo

| Script | Purpose |
|---|---|
| `tools/tanuki-lagos/tanuki.sh` | Unlock bootloader; also the brick-recovery path |
| `tools/build_qs_overlay.sh` | Build + install the QS layout RRO overlay |
| `tools/postinstall_lite.sh` | Debloat + DEX recompile (nothing else) |
| `tools/postinstall.sh` | Full tuning incl. display/BT/animation tweaks |
| `tools/patch_gsi.sh` | Patch a file inside a GSI image before flashing |
| `tools/patch_vendor_boot.py` | Rebuild `vendor_boot` with a modified ramdisk |
| `modules/swap_4gb/` | KernelSU module — 4 GB swapfile at boot |
| `modules/qs_layout/` | KernelSU module — QS layout overlay |

---

## 🚀 Quick start

Read [GUIDE.md](GUIDE.md) — the order matters, especially installing **Mountify before
any module that ships a `system/` tree**.

The single most important check: after flashing a GSI, **boot it, change nothing, and
reboot again**. If boot #2 fails, the GSI is wrong. Do not try to patch around it.

---

## 📄 License

MIT
