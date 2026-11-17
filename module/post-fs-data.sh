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
# 2b) One UI's face enrolment (metadata only; the face data stays in the secure chip)
for n in settings_face.xml face_enrolled_position_0.xml; do
  if busybox nsenter -t 1 -m cat /data/system/users/0/$n > $D/.face_tmp 2>/dev/null && [ -s $D/.face_tmp ]; then
    if ! cmp -s $D/.face_tmp $D/$n; then
      cp -f $D/.face_tmp $D/$n && chown 1000:1000 $D/$n && chmod 600 $D/$n && chcon u:object_r:system_data_file:s0 $D/$n
      log "copied $n from One UI"
    fi
  else
    # a face removed in One UI must not stay listed here
    [ -f $D/$n ] && rm -f $D/$n && log "removed $n (no face in One UI)"
  fi
done
rm -f $D/.face_tmp
# 3) this phone's measured ring geometry (written by service.sh on the first boot)
if [ -f $MODDIR/geometry.prop ]; then
  while IFS='=' read -r k v; do
    case "$k" in persist.vendor.fingerprint.optical.icon*) [ -n "$v" ] && resetprop -n "$k" "$v" ;; esac
  done < $MODDIR/geometry.prop
fi
# 4) one-time cleanup of v1.0: it set persist.sys.oplus.classic_anim_level=1, which turns off the
#    lock-screen clock's fingerprint-unlock animation. Persistent props live in One UI's store.
if [ ! -f $MODDIR/.classic_cleaned ]; then
  R=$(busybox nsenter -t 1 -m sh -c 'ls /data/adb/ksu/bin/resetprop /data/adb/ap/bin/resetprop /data/adb/magisk/resetprop 2>/dev/null | head -1')
  [ -n "$R" ] && busybox nsenter -t 1 -m $R -p --delete persist.sys.oplus.classic_anim_level 2>/dev/null
  resetprop --delete persist.sys.oplus.classic_anim_level 2>/dev/null
  touch $MODDIR/.classic_cleaned && log "removed persist.sys.oplus.classic_anim_level left by v1.0"
fi
