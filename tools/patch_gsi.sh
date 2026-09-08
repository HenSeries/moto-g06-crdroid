#!/usr/bin/env bash
# Patch BaikalOS GSI in place: replace /system/bin/rw-system.sh with our patched
# version that adds phh property-redirects for the Trustonic KeyMint + Gatekeeper.
# Preserves inode/mode/owner/SELinux xattr by using `cat > destination`.

set -euo pipefail

GSI=/home/hen/Documentos/code/android/moto-g06-mod/images/BaikalOS-16.0-20260903-01-microG-gsi.img
PATCHED=/home/hen/Documentos/code/android/moto-g06-mod/backup/diag/rw-system.sh
BACKUP=/home/hen/Documentos/code/android/moto-g06-mod/backup/rw-system.sh.gsi-original
MNT=/mnt/gsi_edit

echo "GSI:     $GSI"
echo "Patched: $PATCHED"
echo "Mount:   $MNT"
echo

for f in "$GSI" "$PATCHED"; do
    [ -f "$f" ] || { echo "MISSING: $f" >&2; exit 1; }
done

sudo mkdir -p "$MNT"

if mountpoint -q "$MNT"; then
    echo "$MNT is already mounted — aborting so we don't clobber it. Umount first." >&2
    exit 1
fi

sudo mount -o loop,rw "$GSI" "$MNT"
trap 'sudo umount "$MNT" 2>/dev/null || true; sudo rmdir "$MNT" 2>/dev/null || true' EXIT

echo "=== mount root layout ==="
sudo ls "$MNT/" | head -30

echo "=== locating rw-system.sh inside GSI ==="
TARGET=$(sudo find "$MNT" -maxdepth 4 -type f -name rw-system.sh 2>/dev/null | head -1)
if [ -z "$TARGET" ]; then
    echo "rw-system.sh not found in the GSI (searched depth 4)." >&2
    echo "Files ending in system.sh:" >&2
    sudo find "$MNT" -maxdepth 5 -type f -name '*system.sh' 2>/dev/null >&2 || true
    exit 3
fi
echo "found: $TARGET"

echo "=== target BEFORE ==="
sudo ls -laZ "$TARGET"
sudo md5sum  "$TARGET"

echo "=== backing up original ==="
sudo cp "$TARGET" "$BACKUP"
sudo chown "$(id -u):$(id -g)" "$BACKUP"
echo "backup at: $BACKUP"

echo "=== overwriting content in-place (preserves inode/mode/xattr) ==="
sudo sh -c "cat '$PATCHED' > '$TARGET'"

echo "=== target AFTER ==="
sudo ls -laZ "$TARGET"
sudo md5sum  "$TARGET"

echo "=== confirm our block is present ==="
sudo grep -nE 'debug\.phh\.props\.(mcDriverDaemon|keymint|gatekeeper)|Motorola lagos' "$TARGET" || {
    echo "PATCH MARKER NOT FOUND — something is wrong. NOT unmounting; investigate manually." >&2
    trap - EXIT
    exit 2
}

echo "=== also verify Trustonic binaries are in the sed loop ==="
sudo grep -nE 'trustonic' "$TARGET"

echo
echo "All checks passed. Unmounting…"
