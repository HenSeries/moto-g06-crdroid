#!/usr/bin/env bash
set -euo pipefail

# Moto G06 (lagos) Stock ROM Debloat + Performance Tweaks
# Safe to run — uses pm disable/uninstall for user 0 only (reversible)

echo "=== Moto G06 Performance Optimization ==="
echo ""

# ─────────────────────────────────────────────
# PHASE 1: DEBLOAT — Remove/disable bloatware
# ─────────────────────────────────────────────
echo "[Phase 1] Debloating..."

# --- Motorola bloat ---
MOTO_BLOAT=(
  com.motorola.ccc.devicemanagement    # Moto device management
  com.motorola.ccc.mainplm             # Moto PLM
  com.motorola.ccc.notification        # Moto notifications
  com.motorola.demo                    # Demo mode
  com.motorola.genie                   # Moto Genie
  com.motorola.help                    # Moto Help
  com.motorola.motocare                # MotoCare
  com.motorola.motocit                 # Moto diagnostic
  com.motorola.motosignature.app       # Moto Signature
  com.motorola.paks                    # Moto personalise
  com.motorola.paks.notification       # Moto personalise notif
  com.motorola.playautoinstallext      # Auto-install apps from Play
  com.motorola.gamemode                # Game mode (uses resources)
  com.motorola.securevault             # Secure vault
  com.motorola.securityhub             # Security hub
  com.motorola.timeweatherwidget       # Weather widget
  com.motorola.wifi.motowifimetrics    # WiFi metrics/telemetry
  com.motorola.bach.modemstats         # Modem stats/telemetry
  com.motorola.account                 # Moto account
  com.motorola.android.providers.chromehomepage  # Chrome homepage override
  com.dti.motorola                     # DTI Motorola
  com.lenovo.lsf.user                  # Lenovo service framework
  com.motorola.enterprise.adapter.service  # Enterprise adapter
  com.motorola.enterprise.service      # Enterprise service
  com.motorola.installer               # Moto installer
)

# --- Facebook system bloat ---
FB_BLOAT=(
  com.facebook.appmanager
  com.facebook.services
  com.facebook.system
)

# --- Google bloat (safe to remove) ---
GOOGLE_BLOAT=(
  com.google.android.apps.bard          # Gemini AI
  com.google.android.apps.docs          # Google Docs
  com.google.android.apps.tachyon       # Google Duo/Meet
  com.google.android.apps.wellbeing     # Digital Wellbeing
  com.google.android.apps.youtube.music # YouTube Music
  com.google.android.apps.wallpaper     # Wallpapers
  com.google.android.apps.safetyhub     # Safety hub
  com.google.android.calendar           # Google Calendar
  com.google.android.feedback           # Feedback
  com.google.android.gm                 # Gmail
  com.google.android.gms.location.history  # Location history
  com.google.android.googlequicksearchbox  # Google Search/Assistant
  com.google.android.marvin.talkback    # TalkBack accessibility
  com.google.android.printservice.recommendation  # Print service
  com.google.android.projection.gearhead  # Android Auto
  com.google.android.videos             # Google TV
  com.google.android.youtube            # YouTube
  com.google.android.apps.turbo         # Device Health Services
  com.google.android.apps.photos        # Google Photos
  com.google.android.apps.maps          # Google Maps
  com.google.android.apps.nbu.files     # Files by Google
  com.google.android.apps.restore       # Restore
  com.google.android.partnersetup       # Partner setup
  com.google.android.onetimeinitializer # One-time init
  com.google.android.federatedcompute   # Federated ML
  com.google.android.ondevicepersonalization.services  # Personalization
  com.google.android.adservices.api     # Ad services
  com.google.mainline.adservices        # Ad services mainline
  com.google.mainline.telemetry         # Telemetry
  com.google.ambient.streaming          # Ambient streaming
  com.google.android.accessibility.switchaccess  # Switch access
  com.google.android.health.connect.backuprestore  # Health backup
  com.google.android.healthconnect.controller  # Health connect
  com.google.android.as.oss            # AI services OSS
)

# --- Other system bloat ---
OTHER_BLOAT=(
  com.dolby.daxservice                 # Dolby (uses CPU)
  com.ontim.dolby.dolbyui.ui           # Dolby UI
  android.autoinstalls.config.motorola.layout  # Auto-install config
)

echo "  Disabling Motorola bloat..."
for pkg in "${MOTO_BLOAT[@]}"; do
  adb shell pm uninstall -k --user 0 "$pkg" 2>/dev/null && echo "    ✓ $pkg" || echo "    - $pkg (already removed or protected)"
done

echo "  Disabling Facebook bloat..."
for pkg in "${FB_BLOAT[@]}"; do
  adb shell pm uninstall -k --user 0 "$pkg" 2>/dev/null && echo "    ✓ $pkg" || echo "    - $pkg (already removed or protected)"
done

echo "  Disabling Google bloat..."
for pkg in "${GOOGLE_BLOAT[@]}"; do
  adb shell pm uninstall -k --user 0 "$pkg" 2>/dev/null && echo "    ✓ $pkg" || echo "    - $pkg (already removed or protected)"
done

echo "  Disabling other bloat..."
for pkg in "${OTHER_BLOAT[@]}"; do
  adb shell pm uninstall -k --user 0 "$pkg" 2>/dev/null && echo "    ✓ $pkg" || echo "    - $pkg (already removed or protected)"
done

# ─────────────────────────────────────────────
# PHASE 2: ADB PERFORMANCE TWEAKS
# ─────────────────────────────────────────────
echo ""
echo "[Phase 2] Applying performance tweaks..."

# Disable all animations
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
echo "  ✓ Animations disabled"

# Force GPU rendering
adb shell settings put global force_gpu_rendering 1
echo "  ✓ GPU rendering forced"

# Reduce background process limit (max 2 background apps)
adb shell settings put global background_process_limit 2
echo "  ✓ Background process limit set to 2"

# Disable HW overlay (force GPU composition)
adb shell settings put system hw_overlays_disabled 1
echo "  ✓ HW overlay disabled"

# Disable WiFi sleep
adb shell settings put global wifi_sleep_policy 2
echo "  ✓ WiFi sleep disabled"

# Disable network stats collection
adb shell settings put global netstats_enabled 0
echo "  ✓ Network stats disabled"

# Disable usage stats
adb shell settings put global app_standby_enabled 0
echo "  ✓ App standby disabled"

# ─────────────────────────────────────────────
# PHASE 3: ART/DALVIK OPTIMIZATION
# ─────────────────────────────────────────────
echo ""
echo "[Phase 3] Optimizing ART runtime..."

# Use all cores for compilation
adb shell setprop dalvik.vm.dex2oat-threads 8
adb shell setprop dalvik.vm.image-dex2oat-threads 8
echo "  ✓ DEX compilation set to 8 threads"

# Force speed compilation profile
adb shell cmd package compile -m speed -a 2>/dev/null &
COMPILE_PID=$!
echo "  ✓ Background DEX recompilation started (PID: $COMPILE_PID)"
echo "    (This improves app launch speed — runs in background)"

# ─────────────────────────────────────────────
# PHASE 4: DISABLE UNNECESSARY SERVICES
# ─────────────────────────────────────────────
echo ""
echo "[Phase 4] Disabling telemetry and unnecessary services..."

# Disable Google usage reporting
adb shell settings put global usage_stats_enabled 0
echo "  ✓ Usage stats reporting disabled"

# Disable spell checker
adb shell settings put secure spell_checker_enabled 0
echo "  ✓ Spell checker disabled"

# Disable auto-sync (saves battery + CPU)
# adb shell settings put global auto_sync 0  # Uncomment if you don't need auto-sync
# echo "  ✓ Auto-sync disabled"

echo ""
echo "=== Optimization Complete ==="
echo ""
echo "Recommended next steps:"
echo "  1. Reboot the device: adb reboot"
echo "  2. After reboot, the device should feel noticeably faster"
echo "  3. Background DEX compilation may take a few minutes to finish"
echo ""
echo "To undo debloat for a specific package:"
echo "  adb shell cmd package install-existing <package_name>"
