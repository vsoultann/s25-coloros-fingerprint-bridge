#!/data/data/com.termux/files/usr/bin/sh
# Builds FingerprintBridge.apk (Xposed/Vector module). Needs: openjdk-21 d8 aapt2 apksigner, root
# (to read framework-res.apk). Signing key: $FPBRIDGE_KS (default ./fpbridge.jks, created if missing).
set -e
cd "$(dirname "$0")"
KS=${FPBRIDGE_KS:-fpbridge.jks}; PASS=${FPBRIDGE_KS_PASS:-fpbridge}
rm -rf build && mkdir -p build/stubs build/classes build/dex build/res
[ -f build-framework-res.apk ] || su -c "cp /system/framework/framework-res.apk $PWD/build-framework-res.apk && chown $(id -u):$(id -g) $PWD/build-framework-res.apk"
javac -nowarn --release 8 -d build/stubs $(find stubs -name '*.java')
javac -nowarn --release 8 -cp build/stubs -d build/classes $(find src -name '*.java')
d8 --release --min-api 29 --output build/dex $(find build/classes -name '*.class')
aapt2 compile --dir res -o build/res/res.zip
aapt2 link -o build/unsigned.apk -I build-framework-res.apk --manifest AndroidManifest.xml -A assets build/res/res.zip
python -I -c "import zipfile; z=zipfile.ZipFile('build/unsigned.apk','a',zipfile.ZIP_DEFLATED); z.write('build/dex/classes.dex','classes.dex'); z.close()"
[ -f "$KS" ] || keytool -genkeypair -keystore "$KS" -alias fpbridge -keyalg RSA -keysize 2048 -validity 36500 -storepass "$PASS" -keypass "$PASS" -dname "CN=fpbridge" >/dev/null 2>&1
rm -f FingerprintBridge.apk
apksigner sign --ks "$KS" --ks-pass pass:"$PASS" --key-pass pass:"$PASS" --out FingerprintBridge.apk build/unsigned.apk
apksigner verify FingerprintBridge.apk && echo "built: $PWD/FingerprintBridge.apk"
