#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/bin"
ANTUMBRA=("$BIN/antumbra" "-v")
DA1="$BIN/lagos.bin"
DA2="$BIN/lamulg.bin"
PRELOADER="$BIN/preloader_lagos.bin"
KAERU="$BIN/lagos-kaeru.bin"
BOOT_MSG="$BIN/boot-bootloader.bin"
INIT_BOOT="/tmp/stock158/init_boot.img"

info()  { echo -e "\033[36m$1\033[0m"; }
error() { echo -e "\033[31m$1\033[0m"; }
ok()    { echo -e "\033[32m$1\033[0m"; }

is_all_zeros() {
    local file="$1"
    [[ -f "$file" && -s "$file" ]] || return 0
    [[ -z "$(tr -d '\0' < "$file" | head -c1)" ]]
}

run_antumbra() {
    local tmpfile=$(mktemp)
    local cmd=$(printf '%q ' "${ANTUMBRA[@]}" "$@")
    script -q -c "$cmd" /dev/null 2>&1 | tee "$tmpfile"
    local ec=${PIPESTATUS[0]}
    grep -q "I/O Error" "$tmpfile" && { rm -f "$tmpfile"; error "Device stuck — disconnect, hold all buttons 10s, retry."; exit 1; }
    rm -f "$tmpfile"
    return "$ec"
}

rm -f "$SCRIPT_DIR/.antumbra_state" 2>/dev/null
trap 'rm -f "$SCRIPT_DIR/.antumbra_state" 2>/dev/null' EXIT

echo ""
info "=== Flash init_boot_b via Penumbra ==="
echo ""
[ ! -f "$INIT_BOOT" ] && { error "Missing: $INIT_BOOT"; exit 1; }
info "Power off device, then press ENTER and connect it."
read -rp "Press ENTER when ready..."

info "Dumping preloader..."
run_antumbra --disable-exploits carbonara upload --da "$DA1" preloader preloader.bin --pl "$PRELOADER"
run_antumbra --disable-exploits carbonara upload --da "$DA1" preloader_backup preloader_backup.bin --pl "$PRELOADER"

info "Erasing preloader..."
run_antumbra --disable-exploits carbonara erase --da "$DA1" preloader --pl "$PRELOADER"
run_antumbra --disable-exploits carbonara erase --da "$DA1" preloader_backup --pl "$PRELOADER"

info "Rebooting to BROM..."
run_antumbra --disable-exploits carbonara reboot --da "$DA1" fastboot --pl "$PRELOADER"
rm -f "$SCRIPT_DIR/.antumbra_state" 2>/dev/null; sleep 5

info "Unlocking seccfg..."
run_antumbra seccfg unlock --da "$DA2" --pl "$PRELOADER"

info "Flashing init_boot_b..."
run_antumbra write --da "$DA2" init_boot_b "$INIT_BOOT" --pl "$PRELOADER"
ok "init_boot_b flashed!"

info "Reinstalling kaeru + preloader..."
run_antumbra write --da "$DA2" lk_a "$KAERU" --pl "$PRELOADER"
run_antumbra write --da "$DA2" lk_b "$KAERU" --pl "$PRELOADER"
run_antumbra write --da "$DA2" misc "$BOOT_MSG" --pl "$PRELOADER"

if ! is_all_zeros preloader.bin; then PL="preloader.bin"
elif ! is_all_zeros preloader_backup.bin; then PL="preloader_backup.bin"
else PL="$PRELOADER"; fi
run_antumbra write --da "$DA2" preloader "$PL" --pl "$PRELOADER"

if ! is_all_zeros preloader_backup.bin; then PLB="preloader_backup.bin"
elif ! is_all_zeros preloader.bin; then PLB="preloader.bin"
else PLB="$PRELOADER"; fi
run_antumbra write --da "$DA2" preloader_backup "$PLB" --pl "$PRELOADER"

info "Rebooting to fastboot..."
run_antumbra reboot --da "$DA2" fastboot --pl "$PRELOADER"
sleep 5

ok "=== Done! init_boot_b flashed. ==="
ok "Now run: fastboot reboot"
rm -f "$SCRIPT_DIR/.antumbra_state" 2>/dev/null
