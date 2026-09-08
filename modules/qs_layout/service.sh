#!/system/bin/sh
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
sleep 8
cmd overlay enable --user 0 com.lagos.qsoverlay 2>/dev/null
log -t qs_layout "enabled com.lagos.qsoverlay"
