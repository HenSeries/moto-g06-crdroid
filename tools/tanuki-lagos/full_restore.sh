#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/bin"
ANTUMBRA=("$BIN/antumbra" "-v")
FASTBOOT=("$BIN/fastboot")
DA1="$BIN/lagos.bin"
DA2="$BIN/lamulg.bin"
PRELOADER="$BIN/preloader_lagos.bin"
KAERU="$BIN/lagos-kaeru.bin"
BOOT_MSG="$BIN/boot-bootloader.bin"

STOCK="/tmp/stock"

RED=$(tput setaf 1 2>/dev/null || true)
GREEN=$(tput setaf 2 2>/dev/null || true)
CYAN=$(tput setaf 6 2>/dev/null || true)
YELLOW=$(tput setaf 3 2>/dev/null || true)
BOLD=$(tput bold 2>/dev/null || true)
RESET=$(tput sgr0 2>/dev/null || true)

info()    { echo "${CYAN}$1${RESET}"; }
success() { echo "${GREEN}$1${RESET}"; }
warn()    { echo "${YELLOW}$1${RESET}"; }
error()   { echo "${RED}$1${RESET}"; }

clear_antumbra_state() {
    rm -f "$SCRIPT_DIR/.antumbra_state" 2>/dev/null || true
}

is_all_zeros() {
    local file="$1"
    local char
    [[ -f "$file" && -s "$file" ]] || return 0
    char=$(tr -d '\0' < "$file" | head -c1)
    [[ -z "$char" ]]
}

run_antumbra() {
    local tmpfile cmd
    tmpfile=$(mktemp)
    cmd=$(printf '%q ' "${ANTUMBRA[@]}" "$@")
    script -q -c "$cmd" /dev/null 2>&1 | tee "$tmpfile"
    local exit_code=${PIPESTATUS[0]}
    if grep -q "I/O Error" "$tmpfile"; then
        rm -f "$tmpfile"
        echo ""
        error "Device is stuck. To recover:"
        error "  1. Disconnect your device."
        error "  2. Hold all three buttons simultaneously !!FOR 10 SECONDS!!, then release."
        error "  3. Run the script again, then reconnect."
        exit 1
    fi
    rm -f "$tmpfile"
    return "$exit_code"
}

trap clear_antumbra_state EXIT

echo ""
echo "${BOLD}=== Moto G06 (lagos) FULL STOCK RESTORE ===${RESET}"
echo "${BOLD}=== This will flash the entire stock firmware ===${RESET}"
echo ""

# Verify all images exist
for f in boot.img init_boot.img vendor_boot.img vbmeta.img vbmeta_system.img vbmeta_vendor.img dtbo.img super.img; do
    if [ ! -f "$STOCK/$f" ]; then
        error "Missing: $STOCK/$f"
        exit 1
    fi
done
success "All stock images found."
echo ""

info "Turn off your device completely."
info "After pressing ENTER, connect your powered-off device."
echo ""
read -rp "Press ENTER when ready..."

clear_antumbra_state

# === PHASE 1: Enter BROM (same as tanuki) ===
info "=== Phase 1: Entering BROM ==="

info "Dumping Preloader..."
run_antumbra --disable-exploits carbonara upload --da "$DA1" preloader preloader.bin --pl "$PRELOADER" || { error "Failed!"; exit 1; }

info "Dumping Preloader (backup)..."
run_antumbra --disable-exploits carbonara upload --da "$DA1" preloader_backup preloader_backup.bin --pl "$PRELOADER" || { error "Failed!"; exit 1; }

info "Erasing Preloader..."
run_antumbra --disable-exploits carbonara erase --da "$DA1" preloader --pl "$PRELOADER" || { error "Failed!"; exit 1; }

info "Erasing Preloader (backup)..."
run_antumbra --disable-exploits carbonara erase --da "$DA1" preloader_backup --pl "$PRELOADER" || { error "Failed!"; exit 1; }

info "Rebooting to BROM..."
run_antumbra --disable-exploits carbonara reboot --da "$DA1" fastboot --pl "$PRELOADER" || { error "Failed!"; exit 1; }

clear_antumbra_state && sleep 5

# === PHASE 2: Unlock and flash everything ===
info "=== Phase 2: Unlocking seccfg ==="
run_antumbra seccfg unlock --da "$DA2" --pl "$PRELOADER" || { error "Failed!"; exit 1; }

info "=== Phase 3: Flashing SUPER partition (this will take a while) ==="
run_antumbra write --da "$DA2" super "$STOCK/super.img" --pl "$PRELOADER" || { error "Failed to flash super!"; exit 1; }
success "Super partition flashed!"

info "=== Phase 4: Flashing boot partitions ==="

for slot in a b; do
    info "Flashing boot_${slot}..."
    run_antumbra write --da "$DA2" "boot_${slot}" "$STOCK/boot.img" --pl "$PRELOADER" || warn "boot_${slot} failed"

    info "Flashing init_boot_${slot}..."
    run_antumbra write --da "$DA2" "init_boot_${slot}" "$STOCK/init_boot.img" --pl "$PRELOADER" || warn "init_boot_${slot} failed"

    info "Flashing vendor_boot_${slot}..."
    run_antumbra write --da "$DA2" "vendor_boot_${slot}" "$STOCK/vendor_boot.img" --pl "$PRELOADER" || warn "vendor_boot_${slot} failed"

    info "Flashing vbmeta_${slot}..."
    run_antumbra write --da "$DA2" "vbmeta_${slot}" "$STOCK/vbmeta.img" --pl "$PRELOADER" || warn "vbmeta_${slot} failed"

    info "Flashing vbmeta_system_${slot}..."
    run_antumbra write --da "$DA2" "vbmeta_system_${slot}" "$STOCK/vbmeta_system.img" --pl "$PRELOADER" || warn "vbmeta_system_${slot} failed"

    info "Flashing vbmeta_vendor_${slot}..."
    run_antumbra write --da "$DA2" "vbmeta_vendor_${slot}" "$STOCK/vbmeta_vendor.img" --pl "$PRELOADER" || warn "vbmeta_vendor_${slot} failed"

    info "Flashing dtbo_${slot}..."
    run_antumbra write --da "$DA2" "dtbo_${slot}" "$STOCK/dtbo.img" --pl "$PRELOADER" || warn "dtbo_${slot} failed"
done

# === PHASE 5: Reinstall kaeru + preloader ===
info "=== Phase 5: Reinstalling kaeru bootloader ==="

run_antumbra write --da "$DA2" lk_a "$KAERU" --pl "$PRELOADER" || { error "Failed kaeru lk_a!"; exit 1; }
run_antumbra write --da "$DA2" lk_b "$KAERU" --pl "$PRELOADER" || { error "Failed kaeru lk_b!"; exit 1; }
run_antumbra write --da "$DA2" misc "$BOOT_MSG" --pl "$PRELOADER" || { error "Failed misc!"; exit 1; }

info "Restoring Preloader..."
if ! is_all_zeros preloader.bin; then
    FLASH_PL="preloader.bin"
elif ! is_all_zeros preloader_backup.bin; then
    FLASH_PL="preloader_backup.bin"
else
    FLASH_PL="$PRELOADER"
fi
run_antumbra write --da "$DA2" preloader "$FLASH_PL" --pl "$PRELOADER" || { error "Failed!"; exit 1; }

if ! is_all_zeros preloader_backup.bin; then
    FLASH_PLB="preloader_backup.bin"
elif ! is_all_zeros preloader.bin; then
    FLASH_PLB="preloader.bin"
else
    FLASH_PLB="$PRELOADER"
fi
run_antumbra write --da "$DA2" preloader_backup "$FLASH_PLB" --pl "$PRELOADER" || { error "Failed!"; exit 1; }

# === PHASE 6: Reboot ===
info "Rebooting to fastboot..."
run_antumbra reboot --da "$DA2" fastboot --pl "$PRELOADER" || { error "Failed!"; exit 1; }

sleep 5
echo ""
success "========================================="
success "  FULL STOCK RESTORE COMPLETE!"
success "========================================="
success ""
success "From fastboot run:"
success "  fastboot -w           (wipe userdata)"
success "  fastboot reboot       (boot into stock ROM)"
clear_antumbra_state
