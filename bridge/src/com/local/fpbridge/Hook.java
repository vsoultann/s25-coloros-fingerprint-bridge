package com.local.fpbridge;

import de.robv.android.xposed.IXposedHookLoadPackage;
import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XposedBridge;
import de.robv.android.xposed.XposedHelpers;
import de.robv.android.xposed.callbacks.XC_LoadPackage;

/**
 * ColorOS on a Samsung (OneOS guest): Samsung's ultrasonic fingerprint HAL reports finger
 * down/up as ACQUIRED_VENDOR (6) with vendorCode 10002 (finger on sensor) / 10014 (finger lifted); 10001 only means "sensor ready" and comes at every wake, finger or not. ColorOS expects
 * OPPO's HAL command callback onFingerprintCmd(1201 = touch down, 1202 = touch up), which
 * drives the pressed-ring effect and AOD fingerprint unlock. This module translates one into
 * the other inside system_server. Samsung's own events still pass through unchanged.
 */
public class Hook implements IXposedHookLoadPackage {
    static final String TAG = "FpBridge: ";
    static final String CLS = "com.android.server.biometrics.sensors.fingerprint.aidl.FingerprintServiceProviderExtImpl";
    static final int ACQUIRED_VENDOR = 6, SEC_FINGER_DOWN = 10002, SEC_FINGER_UP = 10014;
    static final int OPLUS_TOUCH_DOWN = 1201, OPLUS_TOUCH_UP = 1202;
    static final long FALLBACK_UP_MS = 3000;

    static volatile boolean down = false;
    static volatile Runnable pendingUp = null;

    @Override
    public void handleLoadPackage(XC_LoadPackage.LoadPackageParam lp) throws Throwable {
        if (!"android".equals(lp.packageName)) return;
        try {
            XposedHelpers.findAndHookMethod(CLS, lp.classLoader, "onAcquired", int.class, int.class, new XC_MethodHook() {
                @Override
                protected void afterHookedMethod(MethodHookParam p) {
                    try {
                        int info = (Integer) p.args[0], code = (Integer) p.args[1];
                        if (info != ACQUIRED_VENDOR) return;
                        if (code == SEC_FINGER_DOWN) touchDown(p.thisObject);
                        else if (code == SEC_FINGER_UP) touchUp(p.thisObject, "finger up");
                    } catch (Throwable t) { XposedBridge.log(TAG + "onAcquired: " + t); }
                }
            });
            XposedBridge.log(TAG + "hooked " + CLS + ".onAcquired");
        } catch (Throwable t) {
            XposedBridge.log(TAG + "hook failed: " + t);
        }
    }

    static void touchDown(final Object self) {
        if (!down) {
            down = true;
            XposedHelpers.callMethod(self, "onFingerprintCmd", OPLUS_TOUCH_DOWN, new byte[8], 8);
            XposedBridge.log(TAG + "touch down");
        }
        // safety net: never leave ColorOS thinking a finger is still on the sensor
        Object h = XposedHelpers.getObjectField(self, "mHandler");
        if (h == null) return;
        if (pendingUp != null) XposedHelpers.callMethod(h, "removeCallbacks", pendingUp);
        // runs on system_server's fingerprint thread: must never throw (an uncaught
        // exception there would kill system_server and OneOS would fall back to One UI)
        pendingUp = new Runnable() { public void run() {
            try { touchUp(self, "timeout"); } catch (Throwable t) { XposedBridge.log(TAG + "timeout up: " + t); }
        } };
        XposedHelpers.callMethod(h, "postDelayed", pendingUp, FALLBACK_UP_MS);
    }

    static void touchUp(Object self, String why) {
        if (!down) return;
        down = false;
        try {
            Object h = XposedHelpers.getObjectField(self, "mHandler");
            if (h != null && pendingUp != null) XposedHelpers.callMethod(h, "removeCallbacks", pendingUp);
        } catch (Throwable ignored) {}
        pendingUp = null;
        XposedHelpers.callMethod(self, "onFingerprintCmd", OPLUS_TOUCH_UP, new byte[0], 0);
        XposedBridge.log(TAG + "touch up (" + why + ")");
    }
}
