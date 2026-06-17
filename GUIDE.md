# Moto G06 2025 (lagos) — crDroid GSI + Performance Tweaks Guide

Complete guide for flashing crDroid GSI and optimizing the Motorola Moto G06 2025.

**Device**: Moto G06 2025 (codename: lagos, XT2535-1/2/3/14)
**SoC**: MediaTek MT6768 (Helio G37) — 6x Cortex-A55 + 2x Cortex-A75
**Stock firmware used**: VVOBS35.78-158-1 (kernel 6.6.66)
**GSI**: crDroid v11.16 (Android 15, microG)
**Root**: KernelSU

> **WARNING**: This process can brick your device. No warranty. You accept all risks.

---

## Prerequisites

### Hardware
- Moto G06 2025 (lagos)
- USB-C data cable (not charge-only — **cable choice matters for BROM detection**)
- Linux PC (the bootloader unlock exploit is Linux-only)

### Software (on PC)
- `adb` and `fastboot` (Android platform-tools)
- Rust toolchain (`cargo`, `rustc`) — for building Penumbra
- `xz-utils` and `unzip`

### Downloads
1. **Tanuki unlock package** (v1.1.0) — from the XDA thread:
   https://xdaforums.com/t/unlock-bootloader-motorola-motorola-g06-g06-power-lagos.4780825/
   (Download the attachment from the first post — `tanuki-lagos-v1.1.0.zip`)

2. **Stock firmware VVOBS35.78-158-1** — from stockrom.net:
   https://www.stockrom.net/2026/04/xt2535-1-retbr-os15-vvobs35-78-158-1.html

3. **crDroid GSI v11.16** — from SourceForge:
   https://sourceforge.net/projects/crdroidos/files/GSI/
   (File: `v11.16-20260526-microG-gsi.img.xz`)

4. **KernelSU Next** APK — from GitHub:
   https://github.com/KernelSU-Next/KernelSU-Next/releases

---

## Step 1: Prepare Working Directory

```bash
mkdir -p ~/moto-g06-mod/{backup,tools,images}
```

Place downloads:
- `tanuki-lagos-v1.1.0.zip` → `~/moto-g06-mod/tools/`
- Stock firmware zip → `~/moto-g06-mod/tools/`
- crDroid GSI xz → `~/moto-g06-mod/images/`

---

## Step 2: Extract Tools and Firmware

```bash
# Extract tanuki
mkdir -p ~/moto-g06-mod/tools/tanuki-lagos
unzip ~/moto-g06-mod/tools/tanuki-lagos-v1.1.0.zip -d ~/moto-g06-mod/tools/tanuki-lagos/

# Extract stock firmware boot images (only these are needed, not the full 4GB)
unzip ~/moto-g06-mod/tools/RETBR_*.zip boot.img init_boot.img vendor_boot.img vbmeta.img vbmeta_system.img vbmeta_vendor.img dtbo.img super.img -d ~/moto-g06-mod/tools/stock/

# Decompress crDroid GSI (needs ~3.2 GB free space)
xz -dkc ~/moto-g06-mod/images/crdroid-gsi.img.xz > /tmp/crdroid-gsi.img
```

---

## Step 3: Enable OEM Unlocking

On the phone:
1. Go to **Settings > About Phone**
2. Tap **Build Number** 7 times to enable Developer Options
3. Go to **Settings > System > Developer Options**
4. Enable **OEM Unlocking**
5. Enable **USB Debugging**

---

## Step 4: Unlock Bootloader (kaeru exploit)

> This will **factory reset** your device. Back up everything first.

```bash
cd ~/moto-g06-mod/tools/tanuki-lagos
chmod +x tanuki.sh
sudo ./tanuki.sh
```

When prompted:
1. Press ENTER to accept the disclaimer
2. **Power off the phone completely, disconnect USB**
3. Press ENTER
4. **Connect the powered-off phone via USB** (no buttons, just plug it in)
5. Wait for the process to complete

**Success indicator**: You see the **kaeru logo** on the phone screen, then it boots to fastboot.

### Troubleshooting
- If antumbra doesn't detect the phone: **try a different USB cable**. This is the #1 issue.
- If the phone boots to recovery instead of BROM: make sure the phone is **completely powered off** before connecting
- If you get error `0x1d18`: your firmware may be too new for mtkclient, but tanuki/Penumbra should work
- The script can be re-run safely if interrupted

---

## Step 5: Flash Stock Firmware via Penumbra

> **Why?** The factory `super.img` only populates **slot A** partitions. The crDroid GSI must go on slot A to have a working vendor partition. We flash the full stock firmware first to ensure a clean base.

Create the restore script `full_restore.sh` (see Appendix A) and run it:

```bash
cd ~/moto-g06-mod/tools/tanuki-lagos
sudo ./full_restore.sh
```

This flashes all stock partitions to both slots via Penumbra (bypassing kaeru restrictions). After completion, you'll be in fastboot.

### Verify stock boots:
```bash
fastboot set_active a
fastboot reboot
```

Complete the initial Android setup, enable Developer Options + USB Debugging, then verify:
```bash
adb shell uname -r              # Should show 6.6.66
adb shell getprop ro.build.display.id  # Should show VVOBS35.78-158-1
```

---

## Step 6: Flash crDroid GSI

```bash
# Reboot to fastboot
adb reboot bootloader

# Wait for fastboot, then enter fastbootd
fastboot set_active a
fastboot reboot fastboot

# Verify fastbootd
fastboot getvar is-userspace    # Must say "yes"

# Delete product_a to free space for crDroid (crDroid doesn't need it)
fastboot delete-logical-partition product_a

# Flash crDroid to system_a
fastboot erase system
fastboot flash system /tmp/crdroid-gsi.img

# Wipe userdata (use -w, do NOT use format:f2fs)
fastboot -w

# Reboot
fastboot reboot
```

> **IMPORTANT**: Flash crDroid to **slot A only**. The factory `super.img` only populates slot A's vendor/product partitions. Slot B will have empty vendor and crDroid won't boot there.

> **IMPORTANT**: Use `fastboot -w` to wipe, NOT `fastboot format:f2fs userdata`. The device needs to format userdata itself on first boot.

First boot takes 3-5 minutes. Complete the crDroid setup wizard.

---

## Step 7: Root with KernelSU

1. Copy `init_boot.img` from stock firmware to the phone:
   ```bash
   adb push ~/moto-g06-mod/tools/stock/init_boot.img /sdcard/Download/init_boot.img
   ```

2. Install KernelSU Next APK on the phone:
   ```bash
   adb install KernelSU_Next_*.apk
   ```

3. Open **KernelSU** app on the phone
4. Tap **Install** → **Select and Patch a File**
5. Select `init_boot.img` from Downloads
6. KernelSU creates a patched image in Downloads (`kernelsu_patched_*.img`)

7. Pull and flash the patched image:
   ```bash
   adb pull /sdcard/Download/kernelsu_patched_*.img /tmp/kernelsu_patched.img
   adb reboot bootloader
   # Wait for fastboot
   fastboot flash init_boot /tmp/kernelsu_patched.img
   fastboot reboot
   ```

8. After boot, open KernelSU app — it should show **green checkmark "Working"**

9. Grant root to ADB shell:
   ```bash
   adb shell su -c id
   # A prompt appears on phone — tap Allow
   # Should return: uid=0(root) gid=0(root)
   ```

> **DO NOT** flash pre-built KernelSU boot.img from WildKernels or other sources. These replace the entire kernel and will cause a bootloop. Only use KernelSU's init_boot patching method.

---

## Step 8: Fix Headphone Jack

The headphone jack doesn't work by default on the GSI. Root cause: SELinux blocks the audio HAL (`mtk_hal_audio`) from reading `/sys/bus/platform/drivers/pmic-codec-accdet/state`.

Create a KernelSU module:
```bash
adb shell su -c "mkdir -p /data/adb/modules/headphone_jack_fix"
```

Create `service.sh`:
```bash
cat > /tmp/service.sh << 'EOF'
#!/system/bin/sh
# 1. Fix SELinux for headphone jack (runs immediately)
setenforce 0

# 2. Wait for system to be fully booted before touching SurfaceFlinger
(
    # Wait for boot to complete
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 1
    done
    # Extra delay for SurfaceFlinger to stabilize
    sleep 5

    # Prevent black screen
    settings put system hw_overlays_disabled 0
    settings put global force_gpu_rendering 0

    # Reset SurfaceFlinger color matrix
    service call SurfaceFlinger 1015 i32 0
    service call SurfaceFlinger 1022 f 1.0
    service call SurfaceFlinger 1008 i32 0
) &
EOF

adb push /tmp/service.sh /data/local/tmp/service.sh
adb shell su -c "cp /data/local/tmp/service.sh /data/adb/modules/headphone_jack_fix/service.sh"
adb shell su -c "chmod 0755 /data/adb/modules/headphone_jack_fix/service.sh"
```

Create `module.prop`:
```bash
cat > /tmp/module.prop << 'EOF'
id=headphone_jack_fix
name=Headphone Jack + Display Fix
version=1.1
versionCode=2
author=claude
description=Fixes MT6768 headphone jack (SELinux) and prevents black screen on GSI
EOF

adb push /tmp/module.prop /data/local/tmp/module.prop
adb shell su -c "cp /data/local/tmp/module.prop /data/adb/modules/headphone_jack_fix/module.prop"
```

Reboot and test with headphones:
```bash
adb reboot
```

---

## Step 9: Apply Performance Tweaks

### Safe ADB tweaks (no root needed):
```bash
# Disable animations (instant UI feel)
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

# Reduce background process limit (saves RAM)
adb shell settings put global background_process_limit 2

# Disable app standby
adb shell settings put global app_standby_enabled 0

# Disable WiFi sleep
adb shell settings put global wifi_sleep_policy 2

# Disable network stats collection
adb shell settings put global netstats_enabled 0

# Disable usage stats and spell checker
adb shell settings put global usage_stats_enabled 0
adb shell settings put secure spell_checker_enabled 0
```

### Network optimization (root):
```bash
# Switch TCP congestion control to BBR
adb shell su -c "sysctl -w net.ipv4.tcp_congestion_control=bbr"

# Set Google DNS
adb shell su -c "setprop net.dns1 8.8.8.8"
adb shell su -c "setprop net.dns2 8.8.4.4"

# Set preferred network to NR/LTE
adb shell su -c "settings put global preferred_network_mode 33"
```

### Debloat:
```bash
# Remove non-essential system packages
adb shell pm uninstall -k --user 0 com.android.adservices.api
adb shell pm uninstall -k --user 0 com.android.federatedcompute.services
adb shell pm uninstall -k --user 0 com.android.healthconnect.controller
adb shell pm uninstall -k --user 0 com.android.ondevicepersonalization.services
adb shell pm uninstall -k --user 0 com.android.printservice.recommendation
```

### DEX recompilation (improves app launch speed):
```bash
adb shell cmd package compile -m speed -a
```

> This runs in the background on the phone and may take several minutes.

---

## Step 10: Clean Up Slot B (Optional)

Slot B has leftover data from failed attempts. Clean it from fastbootd:

```bash
adb reboot fastboot
# Wait for fastbootd
fastboot erase system_b
fastboot delete-logical-partition product_b
fastboot reboot
```

---

## Known Issues

| Issue | Status | Workaround |
|---|---|---|
| Headphone jack | **Fixed** | KernelSU module sets SELinux permissive (Step 8) |
| Black screen (backlight on, no image) | **Fixed** | Boot script resets SurfaceFlinger color matrix (Step 8) |
| WhatsApp registration fails | **Not fixed** | microG Play Integrity tokens are rejected by WhatsApp servers. Need real Google Play Services. |
| `hw_overlays_disabled=1` causes black screen | **Prevented** | Boot script forces it to 0. **NEVER enable this setting.** |
| `force_gpu_rendering=1` causes black screen | **Prevented** | Boot script forces it to 0. **NEVER enable this setting.** |
| OTA updates | N/A | Won't work. Must manually update crDroid GSI. |
| Banking apps / Play Integrity | Partial | kaeru spoofs boot state as locked/green. Basic attestation passes. Device integrity may fail. |
| Camera aux sensors | Not fixed | Main camera works. Ultrawide/macro may not. GSI limitation. |

---

## Recovery Procedures

### Black Screen Recovery
If the screen goes black (backlight on but no image):
```bash
adb shell su -c "service call SurfaceFlinger 1015 i32 0"
adb shell su -c "service call SurfaceFlinger 1022 f 1.0"
adb shell su -c "service call SurfaceFlinger 1008 i32 0"
```

### Bootloop Recovery
If the device bootloops and can't reach fastboot normally:
1. Run `tanuki.sh` to catch the device in BROM and get to fastboot
2. From fastboot: `fastboot set_active a && fastboot reboot`

### Full Stock Restore
If you need to go back to stock completely:
1. Run `full_restore.sh` (flashes everything via Penumbra)
2. From fastboot:
   ```bash
   fastboot set_active a
   fastboot reboot
   ```

### Flash Boot Partitions via Penumbra
kaeru blocks writing to `init_boot` and some partitions from fastboot. Use Penumbra's BROM access:
Create a script based on `tanuki.sh` that adds your partition write after the `seccfg unlock` step (see `flash_initboot.sh` pattern).

---

## Appendix A: full_restore.sh

This script flashes the entire stock firmware via Penumbra at BROM level, bypassing kaeru restrictions. It:
1. Enters BROM mode (same as tanuki)
2. Flashes `super.img` (system, vendor, product) to both slots
3. Flashes boot, init_boot, vendor_boot, vbmeta, dtbo to both slots
4. Reinstalls kaeru bootloader
5. Restores preloader
6. Reboots to fastboot

The script reads images from `/tmp/stock/`. Place all extracted stock firmware images there before running.

See the `full_restore.sh` file in `tools/tanuki-lagos/` for the complete script.

---

## Appendix B: Key Paths and Partition Layout

| Partition | Slot A | Slot B | Notes |
|---|---|---|---|
| boot | `/dev/block/mmcblk0p27` | `/dev/block/mmcblk0p45` | Kernel + ramdisk |
| init_boot | `/dev/block/mmcblk0p28` | `/dev/block/mmcblk0p46` | KernelSU patches this |
| vendor_boot | vendor_boot_a | vendor_boot_b | Vendor ramdisk |
| system | Inside super | Inside super | Dynamic partition |
| vendor | Inside super | Inside super | Dynamic partition |
| product | Inside super | Inside super | Deleted on slot A for crDroid space |
| lk (bootloader) | lk_a | lk_b | kaeru lives here |
| preloader | preloader | preloader_backup | **NEVER touch manually** |

**Active slot**: A (crDroid)
**Super partition**: Only slot A is populated by factory firmware

---

## Appendix C: Important Lessons Learned

1. **USB cable matters** — Some cables work for ADB but fail for BROM detection. If Penumbra/antumbra can't find the device, try a different cable.

2. **Never flash pre-built kernel boot images** — Only use KernelSU's init_boot patching. Generic GKI boot images (e.g., WildKernels) cause bootloops because they don't match the device's vendor.

3. **Never set `hw_overlays_disabled=1`** — This causes intermittent black screen on MT6768 with GSI. The MediaTek HWC is required.

4. **Never set `force_gpu_rendering=1`** — Same issue. The vendor GPU driver doesn't handle forced GPU composition correctly on GSI.

5. **Factory super.img is single-slot** — Only slot A has populated vendor/product. Always flash GSI to slot A.

6. **Use `fastboot -w`, not `fastboot format:f2fs`** — Let Android format userdata on first boot.

7. **Firmware version must match** — The crDroid GSI needs the same kernel version as the vendor. VVOBS35.78-158-1 has kernel 6.6.66. Older firmware (VVOB35.78-71-9) has kernel 6.6.56 and is incompatible.

8. **kaeru blocks writes to inactive slot** — You can only flash boot partitions to the active slot from fastboot. For the inactive slot, use Penumbra via BROM.

9. **Slot rollback protection** — If slot B fails to boot, Android marks it unbootable and falls back to slot A. You must `fastboot set_active b` to re-enable it.

10. **SELinux must be permissive** — The GKI kernel's sysfs nodes have generic SELinux labels that the vendor policy doesn't allow. Without permissive mode, the audio HAL can't read accdet state (headphone jack breaks).
