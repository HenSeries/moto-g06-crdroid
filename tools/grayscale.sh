#!/usr/bin/env bash
# Grayscale toggle + black-screen recovery for the Moto G06 (lagos).
#
# THE BUG (GUIDE Issue 8): on this MT6768 + GSI combination, anything that
# forces GPU composition corrupts the SurfaceFlinger/HWC pipeline and the panel
# goes black (backlight on, nothing rendered). Enabling grayscale trips it: the
# accessibility daltonizer applies a colour transform the MediaTek HWC cannot do
# in hardware, so composition falls to the GPU.
#
# WHAT ACTUALLY RECOVERS THE SCREEN (verified on-device 2026-09-07) — the full
# crDroid-era sequence, all three calls:
#   settings put system hw_overlays_disabled 0
#   settings put global force_gpu_rendering  0
#   service call SurfaceFlinger 1015 i32 0    # reset colour transform matrix
#   service call SurfaceFlinger 1022 f 1.0    # saturation back to 1.0
#   service call SurfaceFlinger 1008 i32 0    # re-enable Hardware Composer
#
# TRADE-OFF, STATED PLAINLY: call 1015 clears the colour matrix, which is the
# same matrix grayscale uses. Recovering the screen therefore also cancels
# grayscale. On this hardware the two are mutually exclusive — the panel cannot
# render a colour transform. This script's job is to make sure you never get
# stuck on a black screen, not to make grayscale usable.
#
# Usage:
#   bash tools/grayscale.sh status   # current grayscale + trigger state
#   bash tools/grayscale.sh on       # enable grayscale (screen may go black)
#   bash tools/grayscale.sh off      # disable grayscale + repair
#   bash tools/grayscale.sh toggle   # flip based on current state
#   bash tools/grayscale.sh fix      # repair a black screen right now

set -uo pipefail
ACTION="${1:-status}"

sh_get() { adb shell settings get "$1" "$2" 2>/dev/null | tr -d '\r'; }
sh_put() { adb shell settings put "$1" "$2" "$3" >/dev/null 2>&1; }
sf()     { adb shell "su -c 'service call SurfaceFlinger $*'" >/dev/null 2>&1; }

is_on() { [ "$(sh_get secure accessibility_display_daltonizer_enabled)" = "1" ]; }

# The sequence proven to bring the panel back.
repair_display() {
    sh_put system hw_overlays_disabled 0
    sh_put global force_gpu_rendering 0
    sf 1015 i32 0
    sf 1022 f 1.0
    sf 1008 i32 0
}

show_status() {
    if is_on; then echo "  grayscale : ON"; else echo "  grayscale : OFF"; fi
    echo "    daltonizer_enabled   = $(sh_get secure accessibility_display_daltonizer_enabled)"
    echo "    daltonizer           = $(sh_get secure accessibility_display_daltonizer)  (0 = monochromacy)"
    echo "    hw_overlays_disabled = $(sh_get system hw_overlays_disabled)"
    echo "    force_gpu_rendering  = $(sh_get global force_gpu_rendering)"
}

adb get-state >/dev/null 2>&1 || { echo "no device over adb" >&2; exit 1; }

case "$ACTION" in
    status) show_status ;;
    on)
        echo "  enabling grayscale..."
        echo "  NOTE: on this device the panel may go black. Run 'grayscale.sh fix'"
        echo "        (or wait for the watcher module) to recover."
        sh_put secure accessibility_display_daltonizer 0
        sh_put secure accessibility_display_daltonizer_enabled 1
        show_status
        ;;
    off)
        echo "  disabling grayscale + repairing display..."
        sh_put secure accessibility_display_daltonizer_enabled 0
        sleep 1
        repair_display
        show_status
        ;;
    toggle)
        if is_on; then "$0" off; else "$0" on; fi
        ;;
    fix)
        echo "  repairing display..."
        # Grayscale cannot survive the repair, so clear it too and stay consistent.
        sh_put secure accessibility_display_daltonizer_enabled 0
        repair_display
        show_status
        ;;
    *) sed -n '2,30p' "$0"; exit 1 ;;
esac
