SKIPUNZIP=0
command -v abort >/dev/null 2>&1 || abort() { ui_print "$1"; exit 1; }
command -v ui_print >/dev/null 2>&1 || ui_print() { echo "$1"; }
ui_print " "
ui_print "  S25 ColorOS Fingerprint"
ui_print "  for the ColorOS 17 guest (OneOS) on Galaxy S25"
ui_print " "
if [ -z "$(getprop ro.build.version.oplusrom)" ]; then
  abort "! This is not ColorOS. Install it from inside the ColorOS guest."
fi
model=$(getprop ro.product.model)
case "$model" in
  SM-S93*) ui_print "- Phone: $model" ;;
  *) ui_print "! $model is not a Galaxy S25-series phone; installing anyway, untested." ;;
esac
if ! busybox nsenter -t 1 -m test -e /data/system/users/0 2>/dev/null; then
  ui_print "! Could not reach One UI's data. Fingerprints may not appear."
fi
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
ui_print " "
ui_print "- Next: install FingerprintBridge.apk, enable it in"
ui_print "  Vector/LSPosed with scope 'System Framework',"
ui_print "  then tap 'Restart guest' in OneOS."
ui_print "- Fingerprints come from One UI. Add them there."
ui_print "- Do NOT delete a fingerprint in ColorOS: it is"
ui_print "  deleted from One UI too."
