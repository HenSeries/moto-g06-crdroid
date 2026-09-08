#!/usr/bin/env bash
# Post-install tuning for Moto G06 (lagos) on TrebleDroid AOSP 16.
# Safe to re-run. Needs only adb (no root).
#
# Covers GUIDE.md Step 9 performance tweaks + the debloat list, and skips the
# two settings known to cause the black screen on this device (Issue #8):
#   hw_overlays_disabled and force_gpu_rendering must stay 0.

set -uo pipefail

info() { printf '\033[36m%s\033[0m\n' "$1"; }
ok()   { printf '\033[32m%s\033[0m\n' "$1"; }
warn() { printf '\033[33m%s\033[0m\n' "$1"; }

adb wait-for-device || { echo "no device"; exit 1; }
info "Device: $(adb shell getprop ro.build.display.id 2>/dev/null | tr -d '\r')"
info "Android: $(adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')"
echo

info "== Animations off (biggest perceived-speed win) =="
for k in window_animation_scale transition_animation_scale animator_duration_scale; do
    adb shell settings put global $k 0 && echo "  $k = 0"
done

info "== Memory / background limits (4 GB device) =="
adb shell settings put global background_process_limit 2   && echo "  background_process_limit = 2"
adb shell settings put global app_standby_enabled 1        && echo "  app_standby_enabled = 1"
adb shell settings put global netstats_enabled 0           && echo "  netstats_enabled = 0"
adb shell settings put secure spell_checker_enabled 0      && echo "  spell_checker_enabled = 0"

info "== Safety: force the two black-screen triggers OFF (GUIDE Issue #8) =="
adb shell settings put system hw_overlays_disabled 0   && echo "  hw_overlays_disabled = 0"
adb shell settings put global force_gpu_rendering 0    && echo "  force_gpu_rendering = 0"

info "== Debloat (ignore 'not installed' errors) =="
for pkg in \
    com.android.adservices.api \
    com.android.federatedcompute.services \
    com.android.healthconnect.controller \
    com.android.ondevicepersonalization.services \
    com.android.printservice.recommendation \
    com.android.bookmarkprovider \
    com.android.dreams.basic \
    com.android.wallpaper.livepicker
do
    if adb shell pm uninstall -k --user 0 "$pkg" 2>/dev/null | grep -q Success; then
        echo "  removed $pkg"
    else
        echo "  skip    $pkg (absent or protected)"
    fi
done

echo
info "== DEX recompile to native speed =="
warn "This runs for several minutes in the background on the phone."
warn "Leave it plugged in and idle until it finishes."
adb shell cmd package compile -m speed -a

echo
ok "Done. Reboot once, then judge the speed:"
ok "  adb reboot"
