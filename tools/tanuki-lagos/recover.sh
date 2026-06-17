#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/bin"
ANTUMBRA=("$BIN/antumbra" "-v")
FASTBOOT=("$BIN/fastboot")
DA1="$BIN/lagos.bin"
DA2="$BIN/lamulg.bin"
PRELOADER="$BIN/preloader_lagos.bin"

STOCK_BOOT="/tmp/stock/boot.img"
STOCK_INIT_BOOT="/tmp/stock/init_boot.img"
STOCK_VENDOR_BOOT="/tmp/stock/vendor_boot.img"
STOCK_VBMETA="/tmp/stock/vbmeta.img"
STOCK_VBMETA_SYSTEM="/tmp/stock/vbmeta_system.img"
STOCK_VBMETA_VENDOR="/tmp/stock/vbmeta_vendor.img"
STOCK_DTBO="/tmp/stock/dtbo.img"

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
echo "${BOLD}=== Moto G06 (lagos) Full Recovery ===${RESET}"
echo ""

# Verify stock images exist
for f in "$STOCK_BOOT" "$STOCK_INIT_BOOT" "$STOCK_VENDOR_BOOT" "$STOCK_VBMETA" "$STOCK_VBMETA_SYSTEM" "$STOCK_VBMETA_VENDOR" "$STOCK_DTBO"; do
    if [ ! -f "$f" ]; then
        error "Missing: $f"
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

# Phase 1: Dump and erase preloader (same as tanuki)
info "Dumping Preloader..."
if ! run_antumbra --disable-exploits carbonara upload --da "$DA1" preloader preloader.bin --pl "$PRELOADER"; then
    error "Failed to dump Preloader!"
    exit 1
fi

info "Dumping Preloader (backup)..."
if ! run_antumbra --disable-exploits carbonara upload --da "$DA1" preloader_backup preloader_backup.bin --pl "$PRELOADER"; then
    error "Failed to dump Preloader (backup)!"
    exit 1
fi

info "Erasing Preloader..."
if ! run_antumbra --disable-exploits carbonara erase --da "$DA1" preloader --pl "$PRELOADER"; then
    error "Failed to erase Preloader."
    exit 1
fi

info "Erasing Preloader (backup)..."
if ! run_antumbra --disable-exploits carbonara erase --da "$DA1" preloader_backup --pl "$PRELOADER"; then
    error "Failed to erase Preloader (backup)."
    exit 1
fi

info "Rebooting to BROM..."
if ! run_antumbra --disable-exploits carbonara reboot --da "$DA1" fastboot --pl "$PRELOADER"; then
    error "Failed to reboot to BROM."
    exit 1
fi

clear_antumbra_state && sleep 5

# Phase 2: Unlock seccfg
info "Unlocking seccfg..."
if ! run_antumbra seccfg unlock --da "$DA2" --pl "$PRELOADER"; then
    error "Failed to unlock seccfg."
    exit 1
fi

# Phase 3: Flash stock boot images to BOTH slots
info "Flashing stock boot_a..."
if ! run_antumbra write --da "$DA2" boot_a "$STOCK_BOOT" --pl "$PRELOADER"; then
    error "Failed to flash boot_a."
    exit 1
fi

info "Flashing stock boot_b..."
if ! run_antumbra write --da "$DA2" boot_b "$STOCK_BOOT" --pl "$PRELOADER"; then
    error "Failed to flash boot_b."
    exit 1
fi

info "Flashing stock init_boot_a..."
if ! run_antumbra write --da "$DA2" init_boot_a "$STOCK_INIT_BOOT" --pl "$PRELOADER"; then
    error "Failed to flash init_boot_a."
    exit 1
fi

info "Flashing stock init_boot_b..."
if ! run_antumbra write --da "$DA2" init_boot_b "$STOCK_INIT_BOOT" --pl "$PRELOADER"; then
    error "Failed to flash init_boot_b."
    exit 1
fi

info "Flashing stock vendor_boot_a..."
if ! run_antumbra write --da "$DA2" vendor_boot_a "$STOCK_VENDOR_BOOT" --pl "$PRELOADER"; then
    error "Failed to flash vendor_boot_a."
    exit 1
fi

info "Flashing stock vendor_boot_b..."
if ! run_antumbra write --da "$DA2" vendor_boot_b "$STOCK_VENDOR_BOOT" --pl "$PRELOADER"; then
    error "Failed to flash vendor_boot_b."
    exit 1
fi

info "Flashing stock vbmeta_a..."
if ! run_antumbra write --da "$DA2" vbmeta_a "$STOCK_VBMETA" --pl "$PRELOADER"; then
    error "Failed to flash vbmeta_a."
    exit 1
fi

info "Flashing stock vbmeta_b..."
if ! run_antumbra write --da "$DA2" vbmeta_b "$STOCK_VBMETA" --pl "$PRELOADER"; then
    error "Failed to flash vbmeta_b."
    exit 1
fi

info "Flashing stock vbmeta_system_a..."
if ! run_antumbra write --da "$DA2" vbmeta_system_a "$STOCK_VBMETA_SYSTEM" --pl "$PRELOADER"; then
    warn "Failed to flash vbmeta_system_a (non-critical)."
fi

info "Flashing stock vbmeta_system_b..."
if ! run_antumbra write --da "$DA2" vbmeta_system_b "$STOCK_VBMETA_SYSTEM" --pl "$PRELOADER"; then
    warn "Failed to flash vbmeta_system_b (non-critical)."
fi

info "Flashing stock vbmeta_vendor_a..."
if ! run_antumbra write --da "$DA2" vbmeta_vendor_a "$STOCK_VBMETA_VENDOR" --pl "$PRELOADER"; then
    warn "Failed to flash vbmeta_vendor_a (non-critical)."
fi

info "Flashing stock vbmeta_vendor_b..."
if ! run_antumbra write --da "$DA2" vbmeta_vendor_b "$STOCK_VBMETA_VENDOR" --pl "$PRELOADER"; then
    warn "Failed to flash vbmeta_vendor_b (non-critical)."
fi

info "Flashing stock dtbo_a..."
if ! run_antumbra write --da "$DA2" dtbo_a "$STOCK_DTBO" --pl "$PRELOADER"; then
    warn "Failed to flash dtbo_a (non-critical)."
fi

info "Flashing stock dtbo_b..."
if ! run_antumbra write --da "$DA2" dtbo_b "$STOCK_DTBO" --pl "$PRELOADER"; then
    warn "Failed to flash dtbo_b (non-critical)."
fi

# Phase 4: Flash kaeru back + preloader (same as tanuki)
info "Flashing kaeru..."
KAERU="$BIN/lagos-kaeru.bin"
if ! run_antumbra write --da "$DA2" lk_a "$KAERU" --pl "$PRELOADER"; then
    error "Failed to flash kaeru to lk_a."
    exit 1
fi

if ! run_antumbra write --da "$DA2" lk_b "$KAERU" --pl "$PRELOADER"; then
    error "Failed to flash kaeru to lk_b."
    exit 1
fi

info "Flashing bootloader message..."
BOOT_MSG="$BIN/boot-bootloader.bin"
if ! run_antumbra write --da "$DA2" misc "$BOOT_MSG" --pl "$PRELOADER"; then
    error "Failed to write boot message."
    exit 1
fi

info "Flashing Preloader..."
if ! is_all_zeros preloader.bin; then
    FLASH_PRELOADER="preloader.bin"
elif ! is_all_zeros preloader_backup.bin; then
    warn "preloader.bin is empty, using backup..."
    FLASH_PRELOADER="preloader_backup.bin"
else
    warn "Both dumps empty, using stock..."
    FLASH_PRELOADER="$PRELOADER"
fi

if ! run_antumbra write --da "$DA2" preloader "$FLASH_PRELOADER" --pl "$PRELOADER"; then
    error "Failed to flash Preloader."
    exit 1
fi

info "Flashing Preloader (backup)..."
if ! is_all_zeros preloader_backup.bin; then
    FLASH_PRELOADER_BACKUP="preloader_backup.bin"
elif ! is_all_zeros preloader.bin; then
    warn "preloader_backup.bin is empty, using primary..."
    FLASH_PRELOADER_BACKUP="preloader.bin"
else
    warn "Both dumps empty, using stock..."
    FLASH_PRELOADER_BACKUP="$PRELOADER"
fi

if ! run_antumbra write --da "$DA2" preloader_backup "$FLASH_PRELOADER_BACKUP" --pl "$PRELOADER"; then
    error "Failed to flash Preloader (backup)."
    exit 1
fi

# Phase 5: Reboot to fastboot
info "Rebooting to fastboot..."
if ! run_antumbra reboot --da "$DA2" fastboot --pl "$PRELOADER"; then
    error "Failed to reboot."
    exit 1
fi

info "Waiting for bootloader..."
sleep 5

echo ""
success "=== Recovery complete! ==="
success "Both slots now have stock boot images."
success "From fastboot, you can now:"
success "  1. Reboot to stock ROM: fastboot reboot"
success "  2. Or reflash crDroid GSI to system_b via fastbootd"
clear_antumbra_state
