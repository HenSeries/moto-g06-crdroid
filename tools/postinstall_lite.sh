#!/usr/bin/env bash
# Minimal post-install for a GSI (TrebleDroid AOSP 16 + GApps) on Moto G06.
#
# Does exactly two things:
#   1. Debloat  — removes unused Google/AOSP packages for user 0
#   2. Recompile — compiles all apps to native speed
#
# Deliberately does NOT touch: display/SurfaceFlinger settings, Bluetooth A2DP
# props, VoLTE/call-audio props, animation scales, or any other tuning. Apply
# those separately, only if the corresponding problem actually appears.
#
# Reversible: `pm uninstall -k --user 0` keeps the APK on /system and only
# removes it for user 0. Restore any package with:
#     adb shell cmd package install-existing <package>
#
# Usage:  bash tools/postinstall_lite.sh            # debloat + recompile
#         bash tools/postinstall_lite.sh --dry-run  # show what would go
#         bash tools/postinstall_lite.sh --no-compile
#         bash tools/postinstall_lite.sh --restore   # undo the debloat

set -uo pipefail

DRY_RUN=false; DO_COMPILE=true; RESTORE=false
for a in "$@"; do
    case "$a" in
        --dry-run)    DRY_RUN=true ;;
        --no-compile) DO_COMPILE=false ;;
        --restore)    RESTORE=true ;;
        -h|--help)    sed -n '2,20p' "$0"; exit 0 ;;
        *) echo "unknown option: $a" >&2; exit 1 ;;
    esac
done

info() { printf '\033[36m%s\033[0m\n' "$1"; }
ok()   { printf '\033[32m%s\033[0m\n' "$1"; }
warn() { printf '\033[33m%s\033[0m\n' "$1"; }

# ── Packages to remove ────────────────────────────────────────────────
# NEVER listed here (would break Play Services / updates / store):
#   com.google.android.gms, com.google.android.gsf, com.android.vending
BLOAT=(
    # --- AOSP telemetry / ad frameworks ---
    com.android.adservices.api                    # Privacy Sandbox ad APIs
    com.android.federatedcompute.services         # federated learning compute
    com.android.ondevicepersonalization.services  # on-device personalization
    com.google.android.feedback                   # crash/feedback reporting

    # --- AOSP extras rarely used ---
    com.android.bookmarkprovider                  # legacy browser bookmarks
    com.android.dreams.basic                      # screensavers
    com.android.wallpaper.livepicker              # live wallpaper picker
    com.android.printservice.recommendation       # printer discovery
    com.google.android.printservice.recommendation
    com.android.healthconnect.controller          # Health Connect

    # --- Google apps: media / content ---
    com.google.android.videos                     # Google TV
    com.google.android.apps.magazines             # Google News
    com.google.android.music                      # Play Music (legacy)
    com.google.android.apps.youtube.music         # YT Music

    # --- Google apps: productivity you may not use ---
    com.google.android.apps.docs                  # Drive
    com.google.android.apps.tachyon               # Meet
    com.google.android.projection.gearhead        # Android Auto
    com.google.android.apps.subscriptions.red     # Google One
    com.google.android.apps.wellbeing             # Digital Wellbeing

    # --- Sync adapters (safe: Contacts/Calendar sync still works via GMS) ---
    com.google.android.syncadapters.contacts
)

adb wait-for-device || { echo "no device" >&2; exit 1; }
info "Device : $(adb shell getprop ro.build.display.id 2>/dev/null | tr -d '\r')"
info "Android: $(adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')"
echo

# ── Restore mode ──────────────────────────────────────────────────────
if $RESTORE; then
    info "== Restoring all packages for user 0 =="
    for pkg in "${BLOAT[@]}"; do
        if adb shell cmd package install-existing "$pkg" 2>/dev/null | grep -qi "installed"; then
            echo "  restored $pkg"
        else
            echo "  skip     $pkg"
        fi
    done
    ok "Restore complete."
    exit 0
fi

# ── Phase 1: debloat ──────────────────────────────────────────────────
info "== Debloat (user 0 only, reversible with --restore) =="
removed=0; skipped=0
for pkg in "${BLOAT[@]}"; do
    if ! adb shell pm list packages 2>/dev/null | tr -d '\r' | grep -qx "package:$pkg"; then
        echo "  absent  $pkg"; skipped=$((skipped+1)); continue
    fi
    if $DRY_RUN; then
        echo "  WOULD REMOVE  $pkg"; removed=$((removed+1)); continue
    fi
    if adb shell pm uninstall -k --user 0 "$pkg" 2>/dev/null | grep -q Success; then
        echo "  removed $pkg"; removed=$((removed+1))
    else
        echo "  failed  $pkg (protected)"; skipped=$((skipped+1))
    fi
done
echo
ok "Debloat: $removed removed, $skipped skipped"

$DRY_RUN && { warn "Dry run — nothing was changed."; exit 0; }

# ── Phase 2: recompile ────────────────────────────────────────────────
if $DO_COMPILE; then
    echo
    info "== Recompiling all apps to native speed =="
    warn "Runs several minutes on the phone. Keep it plugged in and idle."
    adb shell cmd package compile -m speed -a
    ok "Recompile finished."
fi

echo
ok "Done. Reboot to settle everything:  adb reboot"
