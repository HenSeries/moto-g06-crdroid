#!/system/bin/sh
# Enable the 4 GB swapfile once /data is mounted and boot has settled.
# zram is impossible on lagos (no zram.ko shipped), so we use a storage-backed
# swapfile instead - the same approach stock's "RAM expansion" used.

SWAPFILE=/data/swapfile
SIZE=4G

# wait for /data to be genuinely ready
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
sleep 10

# already active? nothing to do
if grep -q "^${SWAPFILE} " /proc/swaps 2>/dev/null; then
    log -t swap_4gb "swapfile already active"
    exit 0
fi

# (re)create only if missing or wrong size
if [ ! -f "$SWAPFILE" ] || [ "$(stat -c%s "$SWAPFILE" 2>/dev/null)" != "4294967296" ]; then
    rm -f "$SWAPFILE"
    fallocate -l "$SIZE" "$SWAPFILE" || exit 1
    chmod 0600 "$SWAPFILE"
    chown root:root "$SWAPFILE"
    mkswap "$SWAPFILE" >/dev/null 2>&1
fi

swapon "$SWAPFILE" && log -t swap_4gb "swap enabled: $SWAPFILE"

# keep swappiness high so the swap actually gets used on this 4GB device
echo 160 > /proc/sys/vm/swappiness 2>/dev/null
