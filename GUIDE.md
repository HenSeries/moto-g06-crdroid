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
| Voice calls connect but no/choppy audio | **Not fixed** | GKI kernel missing `Hostless_HW_SRC` PCM devices needed by vendor audio HAL. Calls connect (VoLTE works) but speech audio is intermittent. Requires custom kernel or patched HAL. |
| WhatsApp registration fails | **Not fixed** | microG Play Integrity tokens are rejected by WhatsApp servers. Need real Google Play Services. |
| `hw_overlays_disabled=1` causes black screen | **Prevented** | Boot script forces it to 0. **NEVER enable this setting.** |
| `force_gpu_rendering=1` causes black screen | **Prevented** | Boot script forces it to 0. **NEVER enable this setting.** |
| OTA updates | N/A | Won't work. Must manually update crDroid GSI. |
| Banking apps / Play Integrity | Partial | kaeru spoofs boot state as locked/green. Basic attestation passes. Device integrity may fail. |
| Camera aux sensors | Not fixed | Main camera works. Ultrawide/macro may not. GSI limitation. |

### Enabling VoLTE (required for calls on LTE networks)

By default, VoLTE is disabled on the GSI. Without it, calls fail instantly with `CM_SER_UNAVAILABLE`. To enable:

```bash
adb shell su -c "setprop persist.dbg.volte_avail_ovr 1"
adb shell su -c "setprop persist.dbg.ims_volte_enable 1"
adb shell su -c "setprop persist.dbg.wfc_avail_ovr 1"
```

Also in **Treble Settings** app > IMS features:
- Enable "Request IMS network"
- Enable "Force the presence of 4G Calling setting"
- Set IMS to "MediaTek"

Reboot after applying. Calls will connect but audio will be choppy due to the HW_SRC PCM issue described above.

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

## Detailed Troubleshooting — Issues We Encountered and How We Solved Them

This section documents every problem we hit during the process and the exact solution, so you don't have to debug them yourself.

### Issue 1: Antumbra/Penumbra doesn't detect the phone ("Waiting for MTK device...")

**Symptoms**: Running `tanuki.sh`, antumbra prints "Waiting for MTK device..." and never finds the phone.

**Root cause**: The USB cable. Some USB-C cables work fine for ADB but fail for BROM-level communication.

**Solution**: Try a different USB-C data cable. This was the #1 time waster.

**Other things to check**:
- The phone must be **completely powered off** and USB disconnected before running the script
- You must connect the phone **after** the script says "Waiting for MTK device..."
- Don't hold any buttons — just plug in the powered-off phone
- Add udev rules: `echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", MODE="0666", GROUP="dialout"' | sudo tee /etc/udev/rules.d/99-mediatek.rules && sudo udevadm control --reload-rules`
- Add your user to dialout group: `sudo usermod -aG dialout $USER`

---

### Issue 2: crDroid bootloops after flashing (slot B)

**Symptoms**: Flashed crDroid to system_b, rebooted, phone bootloops and falls back to stock on slot A.

**Root cause**: The factory `super.img` only populates **slot A** partitions (system_a, vendor_a, product_a). Slot B's vendor and product are empty. crDroid on slot B has no vendor to work with.

**Solution**: Flash crDroid to **slot A** instead. Delete `product_a` first to make room:
```bash
fastboot delete-logical-partition product_a
fastboot erase system
fastboot flash system /tmp/crdroid-gsi.img
```

---

### Issue 3: crDroid bootloops after flashing (slot A, wrong firmware)

**Symptoms**: Flashed crDroid to slot A but it still bootloops.

**Root cause**: Firmware version mismatch. The stock firmware `super.img` was from an older version (VVOB35.78-71-9, kernel 6.6.56) but crDroid expects kernel 6.6.66 from VVOBS35.78-158-1.

**Solution**: Download the **correct** stock firmware (VVOBS35.78-158-1) and reflash everything via `full_restore.sh` using Penumbra. All images (boot, vendor, super) must come from the same firmware version.

**How to verify**: After booting stock, check:
```bash
adb shell uname -r              # Must be 6.6.66
adb shell getprop ro.build.display.id  # Must be VVOBS35.78-158-1
```

---

### Issue 4: Slot marked "unbootable" after failed boot

**Symptoms**: Set slot B active, it bootlooped, now the system always boots slot A even after `fastboot set_active b`.

**Root cause**: Android's A/B rollback protection marks a slot as unbootable after failed boot attempts.

**Solution**: From fastbootd, check and re-enable:
```bash
fastboot getvar slot-unbootable:b    # Shows "yes"
fastboot set_active b                # This clears the unbootable flag
```

---

### Issue 5: kaeru blocks writing to boot/init_boot partitions

**Symptoms**: `fastboot flash boot_b` or `fastboot flash init_boot_b` fails with "unknown reason".

**Root cause**: kaeru bootloader only allows writing boot partitions to the **active slot** from regular fastboot. Inactive slot writes are blocked.

**Solution**: Use Penumbra to flash at BROM level (bypasses kaeru). Use `flash_initboot.sh` or `recover.sh` scripts which go through the full tanuki BROM flow and then write partitions directly.

Alternative: Set the target slot as active first, then flash from regular fastboot:
```bash
fastboot set_active b
fastboot flash boot /path/to/boot.img    # Now writes to boot_b
```
Note: This doesn't work for all partitions (init_boot still fails).

---

### Issue 6: KernelSU pre-built boot image causes bootloop

**Symptoms**: Flashed a WildKernels GKI boot.img with KernelSU, device bootloops.

**Root cause**: Pre-built GKI boot images replace the entire kernel. The vendor HAL expects specific kernel modules and configurations from the stock kernel. A generic GKI kernel doesn't have them.

**Solution**: **NEVER flash pre-built boot images**. Only use KernelSU's `init_boot` patching method:
1. Extract `init_boot.img` from your stock firmware
2. Push it to the phone
3. Open KernelSU app → Install → Select and Patch a File → select init_boot.img
4. Pull the patched image back and flash via `fastboot flash init_boot`

This only patches the ramdisk, not the kernel itself.

---

### Issue 7: Headphone jack doesn't work

**Symptoms**: Plugging in 3.5mm headphones, audio stays on speaker. Backlight of notification may show headphones detected.

**Root cause**: SELinux blocks the vendor audio HAL (`mtk_hal_audio`) from reading `/sys/bus/platform/drivers/pmic-codec-accdet/state`. Without this, the HAL's `connectExternalDevice()` fails silently and never routes audio to headphones.

**The error in dmesg**:
```
avc: denied { read } for comm="binder:1862_5" name="state" 
scontext=u:r:mtk_hal_audio:s0 tcontext=u:object_r:sysfs:s0 tclass=file permissive=0
```

**The error in logcat**:
```
MTKAdapterLayer: populateAnalogDevicePort(), Can't open path: /sys/bus/platform/drivers/pmic-codec-accdet/state
AHAL_Module: Function: connectExternalDevice Line: 709 Failed
```

**Solution**: Set SELinux to permissive via a KernelSU boot module. See Step 8.

**How we diagnosed it**:
1. `adb shell su -c "dmesg | grep accdet"` — confirmed kernel detects plug/unplug
2. `adb shell su -c "tinymix" | grep -i headphone` — showed "Headphone Plugged In: Off" even when plugged in
3. `adb logcat` during plug event — showed `MTKAdapterLayer: Can't open path` error
4. `adb shell su -c "dmesg | grep 'avc.*denied'" | grep audio` — found the SELinux denial
5. `adb shell su -c "setenforce 0"` — headphones immediately worked

---

### Issue 8: Black screen (backlight on, no image)

**Symptoms**: Screen backlight is on but display shows nothing. Screenshots via `adb shell screencap` are also black.

**Root cause**: Two related causes:
1. **Initial trigger**: Setting `hw_overlays_disabled=1` or `force_gpu_rendering=1` corrupts the SurfaceFlinger/HWC composition pipeline on MediaTek GSI. The vendor Mali GPU driver doesn't handle forced GPU composition correctly.
2. **Persistence**: A stuck color transform matrix in SurfaceFlinger (all zeros = everything black) survives reboots.

**Immediate fix** (run via ADB while screen is black):
```bash
adb shell su -c "service call SurfaceFlinger 1015 i32 0"
adb shell su -c "service call SurfaceFlinger 1022 f 1.0"
adb shell su -c "service call SurfaceFlinger 1008 i32 0"
```

**Permanent fix**: The KernelSU boot module (`service.sh`) runs these commands on every boot after SurfaceFlinger is ready. It also forces `hw_overlays_disabled=0` and `force_gpu_rendering=0`.

**CRITICAL**: The boot script must **wait for boot completion** before calling SurfaceFlinger service calls. Running them too early (before SurfaceFlinger is initialized) has no effect:
```bash
# WRONG — runs too early
service call SurfaceFlinger 1015 i32 0

# RIGHT — wait for boot
while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 1; done
sleep 5
service call SurfaceFlinger 1015 i32 0
```

**What the service calls do**:
- `1015 i32 0` — Reset the color transform matrix to identity (clears the all-black matrix)
- `1022 f 1.0` — Reset color saturation to 1.0 (normal)
- `1008 i32 0` — Re-enable HWC (Hardware Composer)

---

### Issue 9: `fastboot -w` says "not automatically formatting"

**Symptoms**: After `fastboot -w`, you see "Erase successful, but not automatically formatting. File system type raw not supported."

**Root cause**: fastboot can't determine the filesystem type for userdata on this device.

**Solution**: This is actually **fine**. Android formats userdata on first boot. Do NOT try to fix this with `fastboot format:f2fs userdata` — the pre-formatted filesystem can cause boot failures. Just use `fastboot -w` and let Android handle it.

---

### Issue 10: WhatsApp registration fails (loading spinner, returns to same screen)

**Symptoms**: Enter phone number in WhatsApp, tap Next, loading spinner appears briefly, returns to the same screen with no error message.

**Root cause**: crDroid includes microG instead of real Google Play Services. WhatsApp's server-side verification detects the microG Play Integrity token and silently rejects registration.

**Diagnosis**: `adb logcat` shows Play Integrity tokens being generated successfully, but the registration request returns to the same Activity without proceeding.

**Status**: Not fixed. Requires real Google Play Services. Options:
- Use a GApps KernelSU module to replace microG with real GMS
- Use WhatsApp on a different device for initial registration, then restore backup

---

### Issue 11: Voice calls fail instantly (CM_SER_UNAVAILABLE)

**Symptoms**: Dialing a number, call attempts for a split second then immediately hangs up. Returns to dialer.

**Root cause**: VoLTE is disabled in carrier configuration (`carrier_volte_available_bool = false`). On LTE-only networks with no 2G/3G fallback, calls cannot be placed without VoLTE.

**The error in logcat**:
```
DisconnectCause [ Code: (ERROR) Reason: (CM_SER_UNAVAILABLE, ERROR_UNSPECIFIED) TelephonyCause: 36/-1 ]
```

**Solution**: Enable VoLTE override:
```bash
adb shell su -c "setprop persist.dbg.volte_avail_ovr 1"
adb shell su -c "setprop persist.dbg.ims_volte_enable 1"
adb shell su -c "setprop persist.dbg.wfc_avail_ovr 1"
```
Also configure Treble Settings > IMS features (set to MediaTek, enable IMS network). Reboot required.

---

### Issue 12: Voice calls connect but no/choppy audio

**Symptoms**: Calls connect and count time, but you can't hear the other person (or hear them for milliseconds then silence, repeating).

**Root cause**: The GKI 6.6.66 kernel's ALSA PCM topology doesn't include `Hostless_HW_SRC_1` and `Hostless_HW_SRC_3` PCM devices. The vendor audio HAL (`AudioALSASpeechPhoneCallController`) requires these for sample rate conversion during voice calls. Without them, `mPcm == NULL` and the speech audio path fails.

**The error in logcat**:
```
AudioALSASpeechPhoneCallController start() mPcm == NULL
AudioALSASpeechPhoneCallController start(+), pcm_str = Hostless_HW_SRC_1_IN
AudioALSASpeechPhoneCallController start() mPcm == NULL
```

**Available PCM devices** (missing HW_SRC):
```
00-12: Hostless_Speech      ← exists but HAL doesn't use it for this path
00-XX: Hostless_HW_SRC_1    ← MISSING (needed by vendor HAL)
00-XX: Hostless_HW_SRC_3    ← MISSING (needed by vendor HAL)
```

**Status**: Not fixed. This is a fundamental GKI kernel vs vendor HAL incompatibility. Requires either:
1. A custom kernel that adds the missing `Hostless_HW_SRC` PCM device nodes
2. A patched vendor audio HAL that uses `Hostless_Speech` instead
3. Going back to stock ROM for reliable voice calls

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
