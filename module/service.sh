#!/system/bin/sh
# Runs in the ColorOS guest after it has booted.
MODDIR=${0%/*}
LOG=$MODDIR/log.txt
log() { echo "$(date '+%m-%d %H:%M:%S') $*" >> $LOG; }
until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 2; done
sleep 5

# 1) Fingerprint on AOD: ColorOS hides this toggle on Samsung, keep it on
if [ "$(settings get secure show_fingerprint_when_screen_off 2>/dev/null)" != 1 ]; then
  settings put secure show_fingerprint_when_screen_off 1 && log "turned on fingerprint on AOD"
fi

# 2) Measure the ring geometry for this phone from Samsung's sensor position (mm) and the
#    screen's real pixel density, so the ring sits right over the sensor on any S25 model.
P=/sys/class/fingerprint/fingerprint/position
if [ -r $P ]; then
  pos=$(cat $P)
  size=$(wm size 2>/dev/null | grep -oE '[0-9]+x[0-9]+' | tail -1)
  ydpi=$(dumpsys display 2>/dev/null | grep -oE 'yDpi=[0-9]+\.[0-9]+' | head -1 | cut -d= -f2)
  if [ -n "$pos" ] && [ -n "$size" ] && [ -n "$ydpi" ]; then
    geo=$(echo "$pos $size $ydpi" | awk '{
      split($1, p, ","); split($2, s, "x"); pxmm = $3 / 25.4;
      loc = int(p[1] * pxmm + 0.5);   # sensor centre above the bottom edge
      ico = int(p[7] * pxmm + 0.5);   # Samsung icon diameter
      if (loc > 100 && loc < s[2] / 2 && ico > 100 && ico < 400)
        printf "persist.vendor.fingerprint.optical.iconlocation=%d\npersist.vendor.fingerprint.optical.iconsize=%d\n", loc, ico }')
    if [ -n "$geo" ] && [ "$geo" != "$(cat $MODDIR/geometry.prop 2>/dev/null)" ]; then
      echo "$geo" > $MODDIR/geometry.prop
      log "measured ring geometry ($size, ${ydpi} dpi, sensor $pos): $(echo $geo | tr '\n' ' ') - applies after the next Restart guest"
    fi
  fi
fi

# 3) Keep Fingerprint Bridge enabled in Vector with scope "System Framework"
C=/data/adb/modules/zygisk_vector/cli
if [ -x $C ] && pm path com.local.fpbridge >/dev/null 2>&1; then
  n=0; until $C status >/dev/null 2>&1; do n=$((n+1)); [ $n -lt 30 ] || exit 0; sleep 5; done
  changed=0
  $C modules ls 2>/dev/null | grep -E '^com.local.fpbridge ' | grep -q enabled || {
    $C modules enable com.local.fpbridge >/dev/null 2>&1 && { log "enabled Fingerprint Bridge in Vector"; changed=1; }; }
  $C scope ls com.local.fpbridge 2>/dev/null | grep -qE '^system +0( |$)' || {
    $C scope add com.local.fpbridge system/0 >/dev/null 2>&1 && { log "set Fingerprint Bridge scope to System Framework"; changed=1; }; }
  [ $changed = 0 ] || log "Vector settings changed: tap Restart guest once more"
fi
