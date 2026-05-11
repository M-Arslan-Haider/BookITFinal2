# ============================================================
#  proguard-rules.pro
#
#  ✅ FIX: MQTT not working in release APK
#
#  ROOT CAUSE: R8/ProGuard strips and renames Paho MQTT classes
#  in release builds because they are loaded via reflection and
#  ServiceLoader — R8 cannot trace these references statically.
#  In a debug build (run via Android Studio) R8 is off, so MQTT
#  works fine. In a release APK it silently fails.
#
#  ALSO: Inner Runnable classes (CheckRunnable, MqttPublishRunnable,
#  LocationPostRunnable) inside LocationMonitorService are stripped
#  by R8 in release — MQTT publish loop never runs.
#
#  SOLUTION: Keep all Paho classes + inner service classes.
# ============================================================

# ── Paho MQTT client — keep everything ──────────────────────
-keep class org.eclipse.paho.** { *; }
-keep interface org.eclipse.paho.** { *; }
-keepclassmembers class org.eclipse.paho.** { *; }
-dontwarn org.eclipse.paho.**

# ── Android Paho service (if using paho-android-service) ────
-keep class org.eclipse.paho.android.service.** { *; }
-dontwarn org.eclipse.paho.android.service.**

# ── Keep ServiceLoader entries that Paho uses internally ────
-keepnames class org.eclipse.paho.**

# ── Flutter / Dart interop — never rename ───────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ── Your app's native service & receiver ────────────────────
-keep class com.metaxperts.order_booking_app.LocationMonitorService { *; }
# ✅ CRITICAL: Keep inner Runnable classes — R8 strips these in release
# (CheckRunnable, MqttPublishRunnable, LocationPostRunnable)
-keep class com.metaxperts.order_booking_app.LocationMonitorService$* { *; }
-keep class com.metaxperts.order_booking_app.BootCompletedReceiver { *; }
-keep class com.metaxperts.order_booking_app.MainActivity { *; }

# ── Keep all Runnable implementations (handler.post lambdas) ─
-keepclassmembers class * implements java.lang.Runnable {
    public void run();
}

# ── Google Play Services / Security Provider ────────────────
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ── Keep line numbers for crash reports ─────────────────────
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile