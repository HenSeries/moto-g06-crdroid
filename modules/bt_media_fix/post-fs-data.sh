#!/system/bin/sh
# Bluetooth Media (A2DP) fix for MT6768 crDroid GSI
#
# Problem: the phh-treble "system Bluetooth audio HAL" (software A2DP) advertises
# AAC/aptX/LDAC but can only encode SBC, so the audio policy rejects the A2DP
# output (setDeviceConnectionStateInt ... format 4000000 connection failed) and
# media has no Bluetooth output device (the output switcher spins forever).
# Voice/VoIP calls are unaffected because they use the separate SCO/PCM path.
#
# Fix: turn the software audio HAL OFF so the vendor MediaTek A2DP *hardware
# offload* path is used instead (vendor DSP encodes AAC/SBC natively).
# /vendor/build.prop already has ro.bluetooth.a2dp_offload.supported=true.

RESETPROP=/data/adb/ksu/bin/resetprop
[ -x "$RESETPROP" ] || RESETPROP=resetprop

# Route A2DP through the vendor hardware-offload path
$RESETPROP persist.bluetooth.system_audio_hal.enabled false
$RESETPROP persist.bluetooth.a2dp_offload.disabled   false
$RESETPROP ro.bluetooth.a2dp_offload.supported       true
# Make sure the phh software-HAL override is not forcing it off
$RESETPROP --delete persist.bluetooth.bluetooth_audio_hal.disabled 2>/dev/null
