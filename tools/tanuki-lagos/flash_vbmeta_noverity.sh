#!/usr/bin/env bash
# Flash vbmeta images with AVB verity+verification DISABLED, via Penumbra/BROM.
# kaeru rejects `fastboot flash vbmeta*` ("No such file or directory"), so we go
# through BROM the same way flash_initboot.sh / recover.sh do.
#
# The images in images/*-noverity.img already have the AVB header flags set to 3
# (HASHTREE_DISABLED | VERIFICATION_DISABLED), so no --disable-* flag is needed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
BIN="$SCRIPT_DIR/bin"
ANTUMBRA=("$BIN/antumbra" "-v")
DA1="$BIN/lagos.bin"
DA2="$BIN/lamulg.bin"
PRELOADER="$BIN/preloader_lagos.bin"
KAERU="$BIN/lagos-kaeru.bin"
BOOT_MSG="$BIN/boot-bootloader.bin"

VBMETA="$REPO/images/vbmeta-noverity.img"
VBMETA_SYSTEM="$REPO/images/vbmeta_system-noverity.img"
VBMETA_VENDOR="$REPO/images/vbmeta_vendor-noverity.img"

info()  { echo -e "\033[36m$1\033[0m"; }
error() { echo -e "\033[31m$1\033[0m"; }
ok()    { echo -e "\033[32m$1\033[0m"; }

is_all_zeros() {
    local file="$1"
    [[ -f "$file" && -s "$file" ]] || return 0
    [[ -z "$(tr -d '\0' < "$file" | head -c1)" ]]
}

run_antumbra() {
    local tmpfile cmd ec
    tmpfile=$(mktemp)
    cmd=$(printf '%q ' "${ANTUMBRA[@]}" "$@")
    script -q -c "$cmd" /dev/null 2>&1 | tee "$tmpfile"
    ec=${PIPESTATUS[0]}
    grep -q "I/O Error" "$tmpfile" && { rm -f "$tmpfile"; error "Device stuck — disconnect, hold all buttons 10s, retry."; exit 1; }
    rm -f "$tmpfile"
    return "$ec"
}

rm -f "$SCRIPT_DIR/.antumbra_state" 2>/dev/null
trap 'rm -f "$SCRIPT_DIR/.antumbra_state" 2>/dev/null' EXIT

echo ""
info "=== Flash vbmeta (verity DISABLED) via Penumbra ==="
echo ""

for f in "$VBMETA" "$VBMETA_SYSTEM" "$VBMETA_VENDOR"; do
    [ ! -f "$f" ] && { error "Missing: $f"; error "Run the vbmeta patch step first."; exit 1; }
done

# sanity: confirm AVB magic + flags==3 before writing anything
python3 - "$VBMETA" "$VBMETA_SYSTEM" "$VBMETA_VENDOR" <<'PY'
import struct, sys
for p in sys.argv[1:]:
    d = open(p, 'rb').read()
    assert d[:4] == b'AVB0', f"{p}: bad AVB magic {d[:4]!r}"
    flags, = struct.unpack_from('>I', d, 120)
    assert flags == 3, f"{p}: flags={flags}, expected 3"
    print(f"  OK {p}  flags={flags}")
PY
echo ""

info "Power off device completely, then press ENTER and connect it."
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

info "Flashing vbmeta_a (verity disabled)..."
run_antumbra write --da "$DA2" vbmeta_a "$VBMETA" --pl "$PRELOADER"

info "Flashing vbmeta_system_a..."
run_antumbra write --da "$DA2" vbmeta_system_a "$VBMETA_SYSTEM" --pl "$PRELOADER" || \
    error "vbmeta_system_a failed (non-critical, continuing)"

info "Flashing vbmeta_vendor_a..."
run_antumbra write --da "$DA2" vbmeta_vendor_a "$VBMETA_VENDOR" --pl "$PRELOADER" || \
    error "vbmeta_vendor_a failed (non-critical, continuing)"

ok "vbmeta flashed with verity disabled!"

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

ok "=== Done. vbmeta now has verity + verification disabled. ==="
ok "Next:  fastboot -w  &&  fastboot reboot"
rm -f "$SCRIPT_DIR/.antumbra_state" 2>/dev/null
