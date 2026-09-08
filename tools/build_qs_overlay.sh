#!/usr/bin/env bash
# Build a Quick Settings layout RRO overlay and package it as a KernelSU module
# so Mountify installs it into /system/product/overlay.
#
# WHY A MODULE AND NOT `adb install`:
#   Android refuses a sideloaded overlay that targets a system app:
#     "Overlay X and target com.android.systemui signed with different
#      certificates, and the overlay lacks <overlay android:targetName>"
#   Overlays living in /system/product/overlay are exempt from that check.
#   This is exactly how Iconify ships its 51 overlays.
#
# WHY THIS EXISTS AT ALL:
#   Iconify 8.0.0 does not implement QS layout hooks for Android 16 (verified:
#   no qs.panels classes referenced in the Vector module log), so the layout is
#   changed at the resource level instead.
#
# Stock values on lagos (Android 16 uses the "infinite grid"):
#   quick_settings_infinite_grid_num_columns = 4   (portrait)
#   qs_tile_height                           = 80dp
#   qs_tile_margin_horizontal                = 8dp
#
# Usage:  bash tools/build_qs_overlay.sh [COLUMNS] [TILE_HEIGHT_DP] [COLLAPSED_ROWS]
#   e.g.  bash tools/build_qs_overlay.sh 5 70 2   # denser, BaikalOS-ish
#         bash tools/build_qs_overlay.sh 4 80 2   # back to stock
#
# Re-run with new numbers to iterate, then reboot.

set -euo pipefail

COLUMNS="${1:-5}"
TILE_H="${2:-70}"
QQS_ROWS="${3:-2}"

REPO=/home/hen/Documentos/code/android/moto-g06-mod
SDK=/home/hen/Android/Sdk/build-tools/36.0.0
export PATH="$PATH:$SDK"
PKG=com.lagos.qsoverlay
WORK=/tmp/qs_overlay_build
MODDIR="$REPO/modules/qs_layout"

ANDROID_JAR=$(ls -d /home/hen/Android/Sdk/platforms/android-3[0-9]/android.jar 2>/dev/null | tail -1)
[ -n "$ANDROID_JAR" ] || { echo "No android.jar found" >&2; exit 1; }

echo "  columns=$COLUMNS  tile_height=${TILE_H}dp  collapsed_rows=$QQS_ROWS"

rm -rf "$WORK"; mkdir -p "$WORK/res/values"

cat > "$WORK/AndroidManifest.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="$PKG"
    android:versionCode="1"
    android:versionName="1.0">
    <application android:hasCode="false" android:label="QS Layout" />
    <overlay
        android:targetPackage="com.android.systemui"
        android:isStatic="false"
        android:priority="9999" />
</manifest>
EOF

cat > "$WORK/res/values/values.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Android 16 infinite grid: tiles per row -->
    <integer name="quick_settings_infinite_grid_num_columns">$COLUMNS</integer>
    <!-- legacy grid, kept in sync in case the build falls back to it -->
    <integer name="quick_settings_num_columns">$COLUMNS</integer>
    <!-- rows visible in the collapsed (pull-down) shade -->
    <integer name="quick_qs_paginated_grid_num_rows">$QQS_ROWS</integer>
    <!-- tile size -->
    <dimen name="qs_tile_height">${TILE_H}dp</dimen>
</resources>
EOF

echo "  compiling + linking..."
aapt2 compile --dir "$WORK/res" -o "$WORK/res.zip"
aapt2 link -I "$ANDROID_JAR" \
    --manifest "$WORK/AndroidManifest.xml" \
    --min-sdk-version 24 --target-sdk-version 36 \
    -o "$WORK/unsigned.apk" "$WORK/res.zip"

echo "  signing..."
KS="$WORK/ks.jks"
keytool -genkeypair -keystore "$KS" -alias qs -storepass android -keypass android \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=QS Overlay, OU=lagos, O=local, L=x, S=x, C=US" >/dev/null 2>&1
zipalign -f 4 "$WORK/unsigned.apk" "$WORK/aligned.apk"
apksigner sign --ks "$KS" --ks-pass pass:android --key-pass pass:android \
    --out "$WORK/qs-overlay.apk" "$WORK/aligned.apk"

# ---- package as a KernelSU module for Mountify to mount ----
echo "  packaging as KernelSU module..."
rm -rf "$MODDIR"
mkdir -p "$MODDIR/system/product/overlay"
cp "$WORK/qs-overlay.apk" "$MODDIR/system/product/overlay/QSLayoutOverlay.apk"

cat > "$MODDIR/module.prop" <<EOF
id=qs_layout
name=QS Layout Overlay (${COLUMNS} cols, ${TILE_H}dp tiles)
version=1.0-c${COLUMNS}-h${TILE_H}
versionCode=1
author=HenSeries
description=RRO overlay changing SystemUI Quick Settings columns and tile size. Iconify 8.0.0 cannot do this on Android 16.
EOF

# Mountify honours auto_mount; harmless if ignored.
touch "$MODDIR/auto_mount"

# Enable the overlay once the system is up (it is disabled by default).
cat > "$MODDIR/service.sh" <<EOF
#!/system/bin/sh
until [ "\$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
sleep 8
cmd overlay enable --user 0 $PKG 2>/dev/null
log -t qs_layout "enabled $PKG"
EOF
chmod 0755 "$MODDIR/service.sh"

echo "  module built at $MODDIR"
find "$MODDIR" -type f | sed "s|$MODDIR|    .|"

echo
echo "  installing to device..."
adb push "$MODDIR" /data/local/tmp/qs_layout >/dev/null 2>&1
adb shell "su -c '
  rm -rf /data/adb/modules/qs_layout
  mkdir -p /data/adb/modules/qs_layout
  cp -a /data/local/tmp/qs_layout/. /data/adb/modules/qs_layout/
  chmod 0755 /data/adb/modules/qs_layout/service.sh
  chown -R 0:0 /data/adb/modules/qs_layout
  # PackageManager SKIPS system APKs with loose modes — dirs must be 0755, files 0644.
  # (adb push lands them 0771/0666, which silently prevents registration.)
  find /data/adb/modules/qs_layout/system -type d -exec chmod 0755 {} +
  find /data/adb/modules/qs_layout/system -type f -exec chmod 0644 {} +
  chcon -R u:object_r:system_file:s0 /data/adb/modules/qs_layout/system 2>/dev/null
  ls -la /data/adb/modules/qs_layout/system/product/overlay/
'" 2>&1 | tr -d '\r' | sed 's/^/    /'

echo
echo "  REBOOT required — Mountify mounts it at boot, then service.sh enables it."
echo "  After reboot verify with:"
echo "    adb shell su -c 'cmd overlay list --user 0 | grep qsoverlay'"
