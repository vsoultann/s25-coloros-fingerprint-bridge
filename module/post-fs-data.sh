#!/system/bin/sh
# Runs in the ColorOS guest BEFORE its system server starts.
MODDIR=${0%/*}
LOG=$MODDIR/log.txt
log() { echo "$(date '+%m-%d %H:%M:%S') $*" >> $LOG; }
# 1) the folder ColorOS's fingerprint service needs
F=/data/vendor_de/0/fpdata
if [ ! -d $F ]; then
  mkdir -p $F && chown system:system $F && chmod 700 $F && chcon u:object_r:fingerprint_vendor_data_file:s0 $F && log "created $F"
fi
# 2) One UI's fingerprint list (names/ids only; the fingerprints stay in the secure chip)
H=/data/system/users/0/settings_fingerprint_0.xml
D=/data/system/users/0
tmp=$D/.fp_oneui.xml
if busybox nsenter -t 1 -m cat $H > $tmp 2>/dev/null && [ -s $tmp ]; then
  for n in settings_fingerprint_0.xml settings_fingerprint.xml; do
    if ! cmp -s $tmp $D/$n; then
      cp -f $tmp $D/$n && chown 1000:1000 $D/$n && chmod 600 $D/$n && chcon u:object_r:system_data_file:s0 $D/$n
      log "copied $n from One UI"
    fi
  done
else
  log "no fingerprints found in One UI (add them in One UI settings first)"
fi
rm -f $tmp
# 3) this phone's measured ring geometry (written by service.sh on the first boot)
if [ -f $MODDIR/geometry.prop ]; then
  while IFS='=' read -r k v; do
    case "$k" in persist.vendor.fingerprint.optical.icon*) [ -n "$v" ] && resetprop -n "$k" "$v" ;; esac
  done < $MODDIR/geometry.prop
fi
