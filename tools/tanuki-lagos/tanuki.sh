#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/bin"
ANTUMBRA=("$BIN/antumbra" "-v")
FASTBOOT=("$BIN/fastboot")
DA1="$BIN/lagos.bin"
DA2="$BIN/lamulg.bin"
KAERU="$BIN/lagos-kaeru.bin"
BOOT_MSG="$BIN/boot-bootloader.bin"
PRELOADER="$BIN/preloader_lagos.bin"

if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    CYAN=$(tput setaf 6)
    MAGENTA=$(tput setaf 5)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED="" GREEN="" YELLOW="" CYAN="" MAGENTA="" BOLD="" RESET=""
fi

info()    { echo "${CYAN}$1${RESET}"; }
success() { echo "${GREEN}$1${RESET}"; }
warn()    { echo "${YELLOW}$1${RESET}"; }
error()   { echo "${RED}$1${RESET}"; }

banner() {
    echo "${MAGENTA}"
    cat << 'EOF'
  __                       __   .__
_/  |______    ____  __ __|  | _|__|
\   __\__  \  /    \|  |  \  |/ /  |
 |  |  / __ \|   |  \  |  /    <|  |
 |__| (____  /___|  /____/|__|_ \__|
           \/     \/           \/
                  by r0rt1z2 & shomy
EOF
    echo "${RESET}"
}

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
banner
echo "${BOLD}Motorola G06 (lagos) Bootloader Unlock${RESET}"
echo ""
error "${BOLD}DISCLAIMER - READ CAREFULLY${RESET}"
echo ""
error "This tool is provided completely FREE OF CHARGE. If you paid money"
error "for this, YOU HAVE BEEN SCAMMED. Report the seller immediately."
echo ""
error "USE AT YOUR OWN RISK. Unlocking your bootloader will void your"
error "warranty, erase all user data, and there is a real risk of"
error "permanently bricking your device. The authors are not responsible"
error "for any damage whatsoever. Nobody will help you if something goes wrong."
echo ""
error "This tool uses Penumbra (by shomy) and kaeru (by Roger Ortiz & shomy)."
echo ""
error "If you do not fully understand what you are doing, CLOSE THIS NOW."
echo ""
read -rp "Press ENTER to accept the risks and continue, or Ctrl+C to cancel..."

echo ""
info "Turn off your device completely."
info "After pressing ENTER, connect your powered-off device."
echo ""
read -rp "Press ENTER when ready..."

clear_antumbra_state

echo ""
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

info "Unlocking seccfg..."
if ! run_antumbra seccfg unlock --da "$DA2" --pl "$PRELOADER"; then
    error "Failed to unlock seccfg."
    exit 1
fi

info "Flashing kaeru..."
if ! run_antumbra write --da "$DA2" lk_a "$KAERU" --pl "$PRELOADER"; then
    error "Failed to flash kaeru to lk_a."
    exit 1
fi

if ! run_antumbra write --da "$DA2" lk_b "$KAERU" --pl "$PRELOADER"; then
    error "Failed to flash kaeru to lk_b."
    exit 1
fi

info "Flashing bootloader message..."
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

info "Rebooting..."
if ! run_antumbra reboot --da "$DA2" fastboot --pl "$PRELOADER"; then
    error "Failed to reboot."
    exit 1
fi

info "Waiting for bootloader..."
sleep 5
"${FASTBOOT[@]}" oem kaeru-version >/dev/null 2>&1 || true

echo ""
success "Unlock completed successfully!"
clear_antumbra_state