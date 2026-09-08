#!/system/bin/sh
# Black-screen watchdog for lagos (GUIDE Issue 8).
#
# Successor to the crDroid-era headphone_jack_fix service.sh. That one reset
# SurfaceFlinger blindly on a timer; this one watches for the events that
# actually trigger the bug and only repairs on a real state CHANGE.
#
# WHAT TRIGGERS THE BLACK SCREEN
#   Anything forcing GPU composition. The MediaTek HWC on this panel cannot do
#   colour transforms in hardware, so a grayscale/colour-matrix change pushes
#   composition to the GPU and the panel renders nothing (backlight stays on).
#
# WHAT WE WATCH, AND WHY EACH ONE
#   secure accessibility_display_daltonizer_enabled
#       Accessibility grayscale (Settings > Accessibility > Colour correction).
#   global zen_mode
#       Bedtime / Wind Down mode. Verified 2026-09-07: bedtime's grayscale is
#       applied at RUNTIME through ColorDisplayManager.setSaturationLevel() and
#       is NEVER written to any setting — a full 322-key settings diff across a
#       bedtime toggle showed only zen_mode changing. So zen_mode is the only
#       observable proxy for "bedtime just changed the display".
#   system hw_overlays_disabled / global force_gpu_rendering
#       The two documented triggers from GUIDE Issue 8. Forced back to 0.
#
# RECOVERY SEQUENCE (verified working on-device)
#   hw_overlays_disabled=0, force_gpu_rendering=0,
#   SurfaceFlinger 1015 (reset colour matrix), 1022 (saturation 1.0), 1008 (HWC on)
#
# TRADE-OFF, STATED PLAINLY: call 1015 clears the colour matrix — the same one
# grayscale uses. Recovering the panel therefore cancels grayscale. On this
# hardware the two are mutually exclusive. The goal here is that you are never
# left staring at a black screen, not that grayscale becomes usable.

LOG=/data/local/tmp/display_guard.log
: > "$LOG"
log() { echo "[$(date +%H:%M:%S)] $*" >> "$LOG"; }
get() { settings get "$1" "$2" 2>/dev/null; }

repair() {
    settings put system hw_overlays_disabled 0
    settings put global force_gpu_rendering 0
    service call SurfaceFlinger 1015 i32 0 >/dev/null 2>&1
    service call SurfaceFlinger 1022 f 1.0 >/dev/null 2>&1
    service call SurfaceFlinger 1008 i32 0 >/dev/null 2>&1
    log "repaired display pipeline"
}

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
sleep 20

PREV_GS="$(get secure accessibility_display_daltonizer_enabled)"
PREV_ZEN="$(get global zen_mode)"
log "watchdog start (grayscale=$PREV_GS zen=$PREV_ZEN)"
repair

while true; do
    sleep 5

    GS="$(get secure accessibility_display_daltonizer_enabled)"
    ZEN="$(get global zen_mode)"
    HW="$(get system hw_overlays_disabled)"
    FG="$(get global force_gpu_rendering)"

    # Accessibility grayscale switched on -> panel is about to go black.
    if [ "$GS" = "1" ] && [ "$PREV_GS" != "1" ]; then
        log "grayscale ENABLED -> repairing (cancels grayscale; panel cannot render it)"
        settings put secure accessibility_display_daltonizer_enabled 0
        sleep 1
        repair
        PREV_GS=0; PREV_ZEN="$ZEN"
        continue
    fi

    # Accessibility grayscale switched off -> make sure pipeline is sane.
    if [ "$GS" != "1" ] && [ "$PREV_GS" = "1" ]; then
        log "grayscale DISABLED -> repairing"
        repair
        PREV_GS="$GS"; PREV_ZEN="$ZEN"
        continue
    fi

    # Bedtime / Wind Down toggled (either direction) -> it just touched the
    # display through ColorDisplayManager, which we cannot observe directly.
    if [ "$ZEN" != "$PREV_ZEN" ]; then
        log "zen_mode $PREV_ZEN -> $ZEN (bedtime toggled) -> repairing"
        sleep 2
        repair
        PREV_ZEN="$ZEN"; PREV_GS="$GS"
        continue
    fi

    # The two documented triggers, independent of the above.
    if [ "$HW" = "1" ] || [ "$FG" = "1" ]; then
        log "trigger detected (hw_overlays=$HW force_gpu=$FG) -> repairing"
        repair
    fi

    PREV_GS="$GS"; PREV_ZEN="$ZEN"
done &
