#!/data/data/com.termux/files/usr/bin/sh
# Builds release/S25-ColorOS-Fingerprint-<version>.zip and release/FingerprintBridge.apk
set -e
cd "$(dirname "$0")"
V=$(sed -n 's/^version=//p' module/module.prop)
mkdir -p release
python -I - "$V" <<'P'
import os, sys, zipfile
out = f"release/S25-ColorOS-Fingerprint-{sys.argv[1]}.zip"
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk("module"):
        for f in files:
            if f in ("log.txt", "geometry.prop", ".classic_cleaned"): continue
            p = os.path.join(root, f); z.write(p, os.path.relpath(p, "module"))
print("built:", out)
P
sh bridge/build.sh | tail -1
rm -f release/FingerprintBridge.apk
cp bridge/FingerprintBridge.apk release/
