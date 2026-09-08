# Moto G06 2025 (lagos) — Android 16 GSI Guide

Complete guide for running **Android 16** on the Motorola Moto G06 2025, with root,
virtual RAM, microG, and deep UI customization.

**Device**: Moto G06 2025 (codename: `lagos`, XT2535-1/2/3/14)
**SoC**: MediaTek MT6768 (Helio G37) — 6× Cortex-A55 + 2× Cortex-A75, **4 GB RAM**
**Stock firmware**: VVOBS35.78-158-1 (kernel 6.6.66)
**Current ROM**: **TrebleDroid AOSP 16** (`ponces/treble_aosp`, arm64-ab vanilla)
**Root**: KernelSU Next v3.3.0 + Mountify metamodule

> **WARNING**: This process can brick your device. No warranty. You accept all risks.

---

## ⚠️ Read this first — this guide replaces an earlier one

An earlier version of this guide documented a **crDroid (Android 15) / BaikalOS 16**
setup. **That approach was unstable and is no longer recommended.** It produced a long
sequence of failures:

- The device would survive **only one boot per wipe** — any second reboot hung at the
  Motorola logo, requiring a full `fastboot -w` to recover. This happened repeatedly.
- Several plausible-sounding causes were investigated and **all turned out to be wrong**:
  lockscreen credential enrollment, Google-account/Keystore key creation, `/data`
  metadata encryption, and A/B slot rollback protection. Hours went into each.
- Recovery attempts caused their own damage — one script erased the preloader and left
  the phone unbootable mid-flow (recovered via `tanuki.sh`).

**The current setup is materially more stable and more capable**: it runs Android 16,
survives reboots indefinitely, and supports root, swap, microG and UI theming. If you
are following the old guide, stop and use this one.

### What actually determined stability

Not the vendor. Not the TEE. **The GSI build.** Empirically:

| GSI | Result |
|---|---|
| **TrebleDroid AOSP 16** (`ponces/treble_aosp`) | ✅ **stable across reboots** |
| **PixelOS 16** (`mytja/treble_pixelos`) | ✅ stable, but too heavy for 4 GB |
| BaikalOS 16 (crDroid-based) | ❌ dies on 2nd boot |
| Voltage OS 5.11 | ❌ dies on 2nd boot |
| LineageOS 23.2 | ❌ 2nd boot crashes into recovery, then loops |

**Selection rule:** only use GSIs that apply the **complete** TrebleDroid patch set.
"Based on TrebleDroid" in a README is *not* sufficient — Voltage claims it ("thanks to
@TrebleDroid for **some** patches") and still fails. The two that work either sync
TrebleDroid sources wholesale (ponces) or run `patches/apply-all.sh` (PixelOS).

---

## Known issues

| Issue | Status |
|---|---|
| **SIM calls break the microphone** | **Active.** Calls now connect and work, but afterwards the mic is unusable until the phone is rebooted. Not yet diagnosed. |
| **Grayscale blacks the screen** | **Hardware limit.** The MediaTek HWC cannot render a colour transform, so any grayscale forces GPU composition and the panel goes black. `modules/display_guard` auto-recovers; grayscale itself cannot work. |
| Iconify QS layout options | Iconify 8.0.0 has no Android 16 QS-layout hooks — use `tools/build_qs_overlay.sh` instead |
| zRAM | Impossible on this device — no `zram.ko` shipped. Use the swapfile module instead |

---

## Current stack

| Layer | What | Notes |
|---|---|---|
| Bootloader | kaeru (via tanuki) | unlocked |
| ROM | TrebleDroid AOSP 16 vanilla | 2.29 GB — the light variant matters on 4 GB |
| Root | KernelSU Next v3.3.0 (spoofed) | `init_boot` patch only |
| **Metamodule** | **Mountify v2.0.4** | **required** — see below |
| Zygisk | Zygisk Next 1.5.0 | for Xposed |
| Xposed | Vector v2.2 | maintained LSPosed successor |
| Google services | microG (no-sigspoof) | system app, no signature spoofing needed |
| Virtual RAM | 4 GB swapfile | `modules/swap_4gb` |
| UI | Iconify 8.0.0 + Pixel Launcher Enhanced | |
| QS layout | custom RRO overlay | `modules/qs_layout` |

### KernelSU v3 requires a metamodule

**KernelSU v3.0 removed built-in overlayfs mounting.** Without a metamodule, any module
shipping a `system/` tree **silently does nothing** — no error, it just never mounts.
Script-only modules (like the swapfile) still work, which makes this confusing to
diagnose.

Install **Mountify** first. Everything else that touches `/system` depends on it.

---

## Setup

### 1. Unlock bootloader

```bash
cd tools/tanuki-lagos && sudo ./tanuki.sh
```

Power the phone off, then plug it in when prompted. See Troubleshooting for cable issues.

### 2. Flash TrebleDroid AOSP 16

Download `aosp-arm64-ab-vanilla-16.0-*.img.xz` from
[ponces/treble_aosp](https://github.com/ponces/treble_aosp/releases).
The **gapps** variant also exists (3.81 GB) if you prefer real Play Services over microG.

```bash
xz -dkc aosp-arm64-ab-vanilla-16.0-*.img.xz > /tmp/aosp16.img
adb reboot fastboot          # fastbootd — plain fastboot cannot resolve `system`
fastboot flash system /tmp/aosp16.img
fastboot -w
fastboot reboot
```

**Verify stability before going further**: boot, change nothing, `adb reboot`.
If boot #2 fails, the GSI is wrong — do not continue.

### 3. Root with KernelSU

Only ever patch `init_boot`. Never flash a prebuilt GKI `boot.img` (see Lessons).

```bash
adb push tools/stock/init_boot.img /sdcard/Download/
adb install apks/KernelSU-Next-*.apk
```

In the app: **Install → Select and Patch a File** → `init_boot.img`, then:

```bash
adb pull /sdcard/Download/kernelsu_next_patched_*.img /tmp/ksu.img
adb reboot bootloader
fastboot flash init_boot_a /tmp/ksu.img     # note the _a suffix
fastboot reboot
```

### 4. Mountify (do this before any /system module)

```bash
adb push apks/mountify-204.zip /data/local/tmp/
adb shell su -c 'ksud module install /data/local/tmp/mountify-204.zip'
adb reboot
```

### 5. Virtual RAM (4 GB swap)

zRAM is impossible here (no `zram.ko`), so this uses a storage-backed swapfile —
the same approach stock's "RAM expansion" used.

```bash
adb push modules/swap_4gb /data/local/tmp/
adb shell su -c 'cp -r /data/local/tmp/swap_4gb /data/adb/modules/ && chmod 0755 /data/adb/modules/swap_4gb/service.sh'
adb reboot
```

Verify: `adb shell su -c 'cat /proc/swaps'` → 4194300 KB.
Result: **3.64 GB physical + 4 GB swap = 7.64 GB total.**

### 6. microG (no signature spoofing needed)

TrebleDroid has no signature spoofing, so ordinary microG fails with
`NEED_PERMISSION` on every token request. The
[microG_no_sigspoof](https://github.com/IsHacker003/microG_no_sigspoof) module solves
this by transplanting genuine Google signature blocks onto the microG APKs
(via `apksigcopier`, no private keys) and installing them as **system** apps.

```bash
adb uninstall com.google.android.gms   # remove any user-app microG first
adb uninstall com.android.vending
adb push apks/microG-nosigspoof-*.zip /data/local/tmp/
adb shell su -c 'ksud module install /data/local/tmp/microG-nosigspoof-*.zip'
adb reboot
adb shell su -c 'cd /data/adb/modules/microg_no_sigspoof && sh action.sh'
```

The `action.sh` step grants privileged permissions — skipping it leaves microG broken.

### 7. Xposed (Zygisk Next + Vector)

Vector is the maintained LSPosed successor. **Do not use `LSPosed/LSPosed`** — its last
release is from October 2023 and will not work on Android 16.

```bash
adb shell su -c 'ksud module install /data/local/tmp/ZygiskNext-1.5.0.zip'
adb shell su -c 'ksud module install /data/local/tmp/Vector-2.2.zip'
adb reboot
```

Enable modules with the CLI (faster than the GUI):

```bash
adb shell su -c '/data/adb/lspd/cli modules ls'
adb shell su -c '/data/adb/lspd/cli modules enable com.drdisagree.iconify'
adb shell su -c '/data/adb/lspd/cli scope set com.drdisagree.iconify com.android.systemui/0 android/0 com.drdisagree.iconify/0'
adb reboot
```

**Always include the module's own package in its scope** — that is how Xposed modules
self-detect. Without it they report "module not active" even though the framework works.

### 8. UI customization

- **Iconify 8.0.0** — QS tile styles, icon packs, colors. Scope: `com.android.systemui`, `android`, itself.
- **Pixel Launcher Enhanced** — customizes **Launcher3** (not Lawnchair). Scope: `com.android.launcher3` + itself.

### 9. Quick Settings layout

```bash
bash tools/build_qs_overlay.sh 4 70 2 2   # columns, tile height dp, collapsed rows, large-tile width
adb reboot
```

Builds an RRO overlay and ships it as a KernelSU module for Mountify to mount.
Re-run with different numbers to iterate.

**What you can change:** column count, tile height, collapsed-shade rows, and
status bar padding (which fixes the clock overflowing the screen edge).

**What you cannot change — and why.** This build runs the *legacy* Quick
Settings implementation (`dumpsys activity service com.android.systemui` shows
`QSPanel` / `QuickQSPanel`), which renders **uniform tiles**. There is no
large/small tile concept to configure, and the per-tile resize toggle does not
exist. Android 16's new "infinite grid" does support per-tile sizing, but it is
a **build-time aconfig flag compiled off** in TrebleDroid — `device_config list
systemui` has no flag to enable it. The "2 big tiles then 4 small" layout from
crDroid/BaikalOS was a ROM feature, not stock AOSP, and cannot be reproduced
here by configuration. Tile *width* is a function of column count: fewer
columns = wider tiles.

Stock portrait values: 2 columns, 80 dp tiles.

### 10. Grayscale / black-screen watchdog

```bash
adb push modules/display_guard /data/local/tmp/
adb shell su -c 'cp -a /data/local/tmp/display_guard /data/adb/modules/ && chmod 0755 /data/adb/modules/display_guard/service.sh'
adb reboot
```

Runs on every boot via KernelSU's `service.sh` hook. Manual control:

```bash
bash tools/grayscale.sh status|on|off|toggle|fix
```

**The bug.** The MediaTek HWC on this panel cannot do colour transforms in
hardware. Anything that applies one — accessibility grayscale, or Bedtime /
Wind Down mode — pushes composition to the GPU and the panel renders nothing
(backlight stays on).

**Recovery** (verified on-device, all three calls needed):

```
settings put system hw_overlays_disabled 0
settings put global force_gpu_rendering  0
service call SurfaceFlinger 1015 i32 0    # reset colour transform matrix
service call SurfaceFlinger 1022 f 1.0    # saturation back to 1.0
service call SurfaceFlinger 1008 i32 0    # re-enable Hardware Composer
```

**Trade-off, stated plainly:** call `1015` clears the colour matrix — the same
one grayscale uses. Recovering the panel therefore cancels grayscale. On this
hardware the two are mutually exclusive. The watchdog's job is that you are
never left staring at a black screen, not that grayscale becomes usable.

**Watching Bedtime mode is indirect.** Bedtime applies grayscale at runtime
through `ColorDisplayManager.setSaturationLevel()` and never writes it to any
setting — a full 322-key settings diff across a bedtime toggle showed only
`zen_mode` changing. So the watchdog uses `zen_mode` as the observable proxy.

---

## Troubleshooting

### Only the first boot after a wipe works

**Wrong GSI.** See the compatibility table above. Do not try to patch around it — this
was chased for hours through four wrong theories.

### A module with a `system/` tree does nothing

Missing metamodule. Install Mountify (step 4).

### An Xposed module says "not active"

Its own package is missing from its scope, or you did not reboot after enabling it.

### `fastboot` says a partition doesn't exist

kaeru cannot resolve several real partitions. **Use the `_a` suffix**
(`vbmeta_a`, `init_boot_a`, `system_a`). If it still fails, use BROM/antumbra, which
sees everything:

```bash
cd tools/tanuki-lagos
sudo ./bin/antumbra -v --disable-exploits carbonara pgpt --da bin/lagos.bin --pl bin/preloader_lagos.bin
```

### Overlay APK installs but never registers

Permissions. System APKs must be **0644**, directories **0755**. `adb push` lands them
0666/0771 and PackageManager silently skips them.

### Downloads crawling at single-digit KB/s

Use `aria2c -x16 -s16` — measured **180× faster** than single-stream wget on a throttled
link. Also add `--disable-ipv6=true` if IPv6 is broken.

### Phone bricked / stuck in BROM

```bash
cd tools/tanuki-lagos && sudo ./tanuki.sh
```

Restores kaeru and the preloader. Run it **from its own directory** — `antumbra` writes
`.antumbra_state` to the current directory and a stale one breaks the DA stage.

---

## Lessons learned

1. **The GSI build determines stability**, not the vendor or TEE. Test two boots before
   investing any setup time.
2. **Never flash prebuilt GKI `boot.img`** — bootloops this device. Only `init_boot`
   ramdisk patching is safe.
3. **KernelSU v3 needs a metamodule** or `/system` modules silently no-op.
4. **Partition names need the `_a` suffix** on this device.
5. **System APKs need 0644/0755** or they are silently ignored.
6. **Xposed modules need themselves in scope** to self-detect.
7. **zRAM is impossible here** — no module shipped. Swapfile works.
8. **Verify downloads** (`unzip -t`, `xz -t`). A leftover `.aria2` file means incomplete
   even at 100% size.
9. **USB cable quality** remains the single biggest time-waster.
10. **Check for a metamodule/framework requirement before debugging** — several hours
    went into hand-rolling an overlayfs mount that Mountify does properly in one install.
