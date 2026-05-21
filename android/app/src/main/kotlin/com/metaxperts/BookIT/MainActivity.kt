////
////
////
////package com.metaxperts.order_booking_app
////
////import android.content.Intent
////import android.net.Uri
////import android.os.Bundle
////import android.os.PowerManager
////import android.provider.Settings
////import com.google.android.gms.common.GoogleApiAvailability
////import com.google.android.gms.security.ProviderInstaller
////import io.flutter.embedding.android.FlutterFragmentActivity
////import io.flutter.embedding.engine.FlutterEngine
////import io.flutter.plugin.common.MethodChannel
////
////class MainActivity : FlutterFragmentActivity(), ProviderInstaller.ProviderInstallListener {
////
////    private val LOCATION_CHANNEL   = "com.metaxperts.order_booking_app/location_monitor"
////    private val SYNC_ALARM_CHANNEL = "com.metaxperts.order_booking_app/sync_alarm"
////    private val BUBBLE_CHANNEL = "com.metaxperts.order_booking_app/floating_bubble"
////
////    private var bubbleServiceStarted = false
////    private val OVERLAY_PERMISSION_REQUEST_CODE = 1001
////
////    override fun onCreate(savedInstanceState: Bundle?) {
////        super.onCreate(savedInstanceState)
////        ProviderInstaller.installIfNeededAsync(this, this)
////        requestBatteryOptimizationIfNeeded()
////    }
////
////    private fun requestBatteryOptimizationIfNeeded() {
////        try {
////            val pm = getSystemService(POWER_SERVICE) as PowerManager
////            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
////                val intent = Intent(
////                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
////                ).apply {
////                    data = Uri.parse("package:$packageName")
////                }
////                startActivity(intent)
////            }
////        } catch (e: Exception) {
////            // ignore
////        }
////    }
////
////    private fun showFloatingBubble() {
////        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
////            // ✅ FIX: startActivityForResult use karo taake wapas app par aa sakein
////            val intent = Intent(
////                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
////                Uri.parse("package:$packageName")
////            )
////            startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
////            return
////        }
////
////        if (!FloatingBubbleService.isRunning()) {
////            FloatingBubbleService.start(this)
////            bubbleServiceStarted = true
////        } else {
////            sendBroadcast(Intent("com.metaxperts.SHOW_BUBBLE"))
////        }
////    }
////
////    // ✅ FIX: Permission screen se wapas aane par automatically app open ho
////    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
////        super.onActivityResult(requestCode, resultCode, data)
////        if (requestCode == OVERLAY_PERMISSION_REQUEST_CODE) {
////            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M
////                && Settings.canDrawOverlays(this)
////            ) {
////                // Permission mil gayi — bubble start karo
////                if (!FloatingBubbleService.isRunning()) {
////                    FloatingBubbleService.start(this)
////                    bubbleServiceStarted = true
////                }
////            }
////            // App ko foreground mein lao (settings stack se nikaalo)
////            val bring = Intent(this, MainActivity::class.java).apply {
////                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
////                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
////            }
////            startActivity(bring)
////        }
////    }
////
////    private fun hideFloatingBubble() {
////        if (bubbleServiceStarted) {
////            sendBroadcast(Intent("com.metaxperts.HIDE_BUBBLE"))
////        }
////    }
////
////    // ✅ NEW: Close bubble completely on clockout
////    private fun closeFloatingBubble() {
////        try {
////            sendBroadcast(Intent("com.metaxperts.CLOSE_BUBBLE"))
////            bubbleServiceStarted = false
////            android.util.Log.d("MainActivity", "✅ Bubble close broadcast sent")
////        } catch (e: Exception) {
////            android.util.Log.e("MainActivity", "Error closing bubble: ${e.message}")
////        }
////    }
////
////    override fun onPause() {
////        super.onPause()
////        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
////        val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
////        if (isClockedIn) {
////            showFloatingBubble()
////        }
////    }
////
////    override fun onResume() {
////        super.onResume()
////        hideFloatingBubble()
////    }
////
////    override fun onProviderInstalled() {}
////
////    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
////        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
////    }
////
////    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
////        super.configureFlutterEngine(flutterEngine)
////
////        // ── 1. Location monitor channel ──────────────────────────
////        MethodChannel(
////            flutterEngine.dartExecutor.binaryMessenger,
////            LOCATION_CHANNEL
////        ).setMethodCallHandler { call, result ->
////            when (call.method) {
////                "startMonitoring" -> {
////                    try {
////                        val userId = call.argument<String>("userId") ?: ""
////                        val bookerName = call.argument<String>("bookerName") ?: ""
////                        val designation = call.argument<String>("designation") ?: ""
////                        val companyCode = call.argument<String>("companyCode") ?: ""
////
////                        LocationMonitorService.start(
////                            context = this,
////                            userId = userId,
////                            bookerName = bookerName,
////                            designation = designation,
////                            companyCode = companyCode
////                        )
////                        result.success(null)
////                    } catch (e: Exception) {
////                        result.error("START_FAILED", e.message, null)
////                    }
////                }
////                "stopMonitoring" -> {
////                    try {
////                        LocationMonitorService.stop(this)
////                        result.success(null)
////                    } catch (e: Exception) {
////                        result.error("STOP_FAILED", e.message, null)
////                    }
////                }
////                "requestBatteryOptimization" -> {
////                    try {
////                        val pm = getSystemService(POWER_SERVICE) as PowerManager
////                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
////                            val intent = Intent(
////                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
////                            ).apply {
////                                data = Uri.parse("package:$packageName")
////                            }
////                            startActivity(intent)
////                        }
////                        result.success(null)
////                    } catch (e: Exception) {
////                        result.success(null)
////                    }
////                }
////                else -> result.notImplemented()
////            }
////        }
////
////        // ── 2. Sync alarm channel ───────────────────────────
////        MethodChannel(
////            flutterEngine.dartExecutor.binaryMessenger,
////            SYNC_ALARM_CHANNEL
////        ).setMethodCallHandler { call, result ->
////            when (call.method) {
////                "startAlarm" -> {
////                    try {
////                        SyncAlarmReceiver.startAlarm(this)
////                        result.success(null)
////                    } catch (e: Exception) {
////                        result.error("ALARM_START_FAILED", e.message, null)
////                    }
////                }
////                "stopAlarm" -> {
////                    try {
////                        SyncAlarmReceiver.stopAlarm(this)
////                        result.success(null)
////                    } catch (e: Exception) {
////                        result.error("ALARM_STOP_FAILED", e.message, null)
////                    }
////                }
////                else -> result.notImplemented()
////            }
////        }
////
////        // ── 3. Floating bubble channel ──────────────────────────
////        MethodChannel(
////            flutterEngine.dartExecutor.binaryMessenger,
////            BUBBLE_CHANNEL
////        ).setMethodCallHandler { call, result ->
////            when (call.method) {
////                "showBubble" -> {
////                    showFloatingBubble()
////                    result.success(true)
////                }
////                "hideBubble" -> {
////                    hideFloatingBubble()
////                    result.success(true)
////                }
////                "isBubbleVisible" -> {
////                    result.success(FloatingBubbleService.isRunning())
////                }
////                "closeBubble" -> {
////                    closeFloatingBubble()
////                    result.success(true)
////                }
////                else -> result.notImplemented()
////            }
////        }
////    }
////}
//
//
//// ══════════════════════════════════════════════════════════════════════════════
//// MainActivity.kt — Overlay Permission Fix
////
//// PROBLEM (purana code):
////   startActivityForResult() → onActivityResult() — Android 12+ par yeh
////   Settings overlay screen se wapas aane par reliably call NAHI hota.
////   Result: permission grant hone ke baad app wapis nahi aata, bubble bhi
////   start nahi hota.
////
//// SOLUTION (naya code):
////   onResume() mein check karo — yeh HAMESHA call hota hai jab bhi app
////   foreground mein aata hai, chahe Settings se, chahe kahi se bhi.
////   pendingBubbleStart = true flag se track karo ke permission ka wait tha.
//// ══════════════════════════════════════════════════════════════════════════════
//
//package com.metaxperts.order_booking_app
//
//import android.content.Intent
//import android.net.Uri
//import android.os.Build
//import android.os.Bundle
//import android.os.PowerManager
//import android.provider.Settings
//import com.google.android.gms.common.GoogleApiAvailability
//import com.google.android.gms.security.ProviderInstaller
//import io.flutter.embedding.android.FlutterFragmentActivity
//import io.flutter.embedding.engine.FlutterEngine
//import io.flutter.plugin.common.MethodChannel
//
//class MainActivity : FlutterFragmentActivity(), ProviderInstaller.ProviderInstallListener {
//
//    private val LOCATION_CHANNEL    = "com.metaxperts.order_booking_app/location_monitor"
//    private val SYNC_ALARM_CHANNEL  = "com.metaxperts.order_booking_app/sync_alarm"
//    private val BUBBLE_CHANNEL      = "com.metaxperts.order_booking_app/floating_bubble"
//
//    private var bubbleServiceStarted = false
//
//    // ✅ KEY FIX: Yeh flag track karta hai ke user overlay permission dene gayi thi
//    // onResume() mein check hoga — onActivityResult() par depend nahi
//    private var pendingBubbleStart = false
//
//    override fun onCreate(savedInstanceState: Bundle?) {
//        super.onCreate(savedInstanceState)
//        ProviderInstaller.installIfNeededAsync(this, this)
//        requestBatteryOptimizationIfNeeded()
//    }
//
//    // ── onResume — Yahan overlay permission check hota hai ────────────────────
//    override fun onResume() {
//        super.onResume()
//
//        // Bubble hide karo jab app foreground mein ho
//        hideFloatingBubble()
//
//        // ✅ FIX: Agar permission ka wait tha aur ab mil gayi
//        if (pendingBubbleStart) {
//            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)) {
//                pendingBubbleStart = false
//                if (!FloatingBubbleService.isRunning()) {
//                    FloatingBubbleService.start(this)
//                    bubbleServiceStarted = true
//                }
//                android.util.Log.d("MainActivity", "✅ Overlay permission confirmed in onResume — bubble started")
//            } else {
//                // User ne permission nahi di — flag reset karo
//                pendingBubbleStart = false
//                android.util.Log.w("MainActivity", "⚠️ Overlay permission still not granted")
//            }
//        }
//    }
//
//    override fun onPause() {
//        super.onPause()
//        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
//        val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
//        if (isClockedIn) {
//            showFloatingBubble()
//        }
//    }
//
//    // ── Floating bubble control ───────────────────────────────────────────────
//
//    private fun showFloatingBubble() {
//        // Permission check
//        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
//            android.util.Log.d("MainActivity", "Overlay permission missing — opening Settings")
//
//            // ✅ FIX: Flag set karo PEHLE Settings kholne se
//            pendingBubbleStart = true
//
//            // Settings kholo (startActivity — NOT startActivityForResult)
//            // startActivityForResult deprecated hai aur Settings screen se
//            // wapas aane par onActivityResult reliably call nahi hota
//            val intent = Intent(
//                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
//                Uri.parse("package:$packageName")
//            )
//            startActivity(intent)
//            return
//        }
//
//        // Permission hai — bubble start ya show karo
//        if (!FloatingBubbleService.isRunning()) {
//            FloatingBubbleService.start(this)
//            bubbleServiceStarted = true
//        } else {
//            sendBroadcast(Intent("com.metaxperts.SHOW_BUBBLE"))
//        }
//    }
//
//    private fun hideFloatingBubble() {
//        if (bubbleServiceStarted || FloatingBubbleService.isRunning()) {
//            sendBroadcast(Intent("com.metaxperts.HIDE_BUBBLE"))
//        }
//    }
//
//    private fun closeFloatingBubble() {
//        try {
//            sendBroadcast(Intent("com.metaxperts.CLOSE_BUBBLE"))
//            bubbleServiceStarted = false
//        } catch (e: Exception) {
//            android.util.Log.e("MainActivity", "Error closing bubble: ${e.message}")
//        }
//    }
//
//    // ── Battery optimization ──────────────────────────────────────────────────
//
//    private fun requestBatteryOptimizationIfNeeded() {
//        try {
//            val pm = getSystemService(POWER_SERVICE) as PowerManager
//            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
//                val intent = Intent(
//                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
//                ).apply {
//                    data = Uri.parse("package:$packageName")
//                }
//                startActivity(intent)
//            }
//        } catch (e: Exception) {
//            // ignore — non-fatal
//        }
//    }
//
//    // ── Google Play security provider ────────────────────────────────────────
//
//    override fun onProviderInstalled() {}
//
//    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
//        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
//    }
//
//    // ── Flutter MethodChannels ────────────────────────────────────────────────
//
//    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
//        super.configureFlutterEngine(flutterEngine)
//
//        // ── 1. Location monitor channel ──────────────────────────────────────
//        MethodChannel(
//            flutterEngine.dartExecutor.binaryMessenger,
//            LOCATION_CHANNEL
//        ).setMethodCallHandler { call, result ->
//            when (call.method) {
//                "startMonitoring" -> {
//                    try {
//                        LocationMonitorService.start(
//                            context     = this,
//                            userId      = call.argument<String>("userId")      ?: "",
//                            bookerName  = call.argument<String>("bookerName")  ?: "",
//                            designation = call.argument<String>("designation") ?: "",
//                            companyCode = call.argument<String>("companyCode") ?: ""
//                        )
//                        result.success(null)
//                    } catch (e: Exception) {
//                        result.error("START_FAILED", e.message, null)
//                    }
//                }
//                "stopMonitoring" -> {
//                    try {
//                        LocationMonitorService.stop(this)
//                        result.success(null)
//                    } catch (e: Exception) {
//                        result.error("STOP_FAILED", e.message, null)
//                    }
//                }
//                "requestBatteryOptimization" -> {
//                    try {
//                        val pm = getSystemService(POWER_SERVICE) as PowerManager
//                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
//                            startActivity(
//                                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
//                                    data = Uri.parse("package:$packageName")
//                                }
//                            )
//                        }
//                        result.success(null)
//                    } catch (e: Exception) {
//                        result.success(null)
//                    }
//                }
//                else -> result.notImplemented()
//            }
//        }
//
//        // ── 2. Sync alarm channel ────────────────────────────────────────────
//        MethodChannel(
//            flutterEngine.dartExecutor.binaryMessenger,
//            SYNC_ALARM_CHANNEL
//        ).setMethodCallHandler { call, result ->
//            when (call.method) {
//                "startAlarm" -> {
//                    try {
//                        SyncAlarmReceiver.startAlarm(this)
//                        result.success(null)
//                    } catch (e: Exception) {
//                        result.error("ALARM_START_FAILED", e.message, null)
//                    }
//                }
//                "stopAlarm" -> {
//                    try {
//                        SyncAlarmReceiver.stopAlarm(this)
//                        result.success(null)
//                    } catch (e: Exception) {
//                        result.error("ALARM_STOP_FAILED", e.message, null)
//                    }
//                }
//                else -> result.notImplemented()
//            }
//        }
//
//        // ── 3. Floating bubble channel ───────────────────────────────────────
//        MethodChannel(
//            flutterEngine.dartExecutor.binaryMessenger,
//            BUBBLE_CHANNEL
//        ).setMethodCallHandler { call, result ->
//            when (call.method) {
//                "showBubble" -> {
//                    showFloatingBubble()
//                    result.success(true)
//                }
//                "hideBubble" -> {
//                    hideFloatingBubble()
//                    result.success(true)
//                }
//                "isBubbleVisible" -> {
//                    result.success(FloatingBubbleService.isRunning())
//                }
//                "closeBubble" -> {
//                    closeFloatingBubble()
//                    result.success(true)
//                }
//                else -> result.notImplemented()
//            }
//        }
//    }
//}

package com.metaxperts.order_booking_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.security.ProviderInstaller
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity(), ProviderInstaller.ProviderInstallListener {

    private val LOCATION_CHANNEL    = "com.metaxperts.order_booking_app/location_monitor"
    private val SYNC_ALARM_CHANNEL  = "com.metaxperts.order_booking_app/sync_alarm"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ProviderInstaller.installIfNeededAsync(this, this)
        requestBatteryOptimizationIfNeeded()
    }

    override fun onResume() {
        super.onResume()
        // No bubble code
    }

    override fun onPause() {
        super.onPause()
        // No bubble code
    }

    private fun requestBatteryOptimizationIfNeeded() {
        try {
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                ).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            }
        } catch (e: Exception) {
            // ignore
        }
    }

    override fun onProviderInstalled() {}

    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── 1. Location monitor channel ──────────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LOCATION_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startMonitoring" -> {
                    try {
                        LocationMonitorService.start(
                            context     = this,
                            userId      = call.argument<String>("userId")      ?: "",
                            bookerName  = call.argument<String>("bookerName")  ?: "",
                            designation = call.argument<String>("designation") ?: "",
                            companyCode = call.argument<String>("companyCode") ?: ""
                        )
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("START_FAILED", e.message, null)
                    }
                }
                "stopMonitoring" -> {
                    try {
                        LocationMonitorService.stop(this)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("STOP_FAILED", e.message, null)
                    }
                }
                "requestBatteryOptimization" -> {
                    try {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                            startActivity(
                                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = Uri.parse("package:$packageName")
                                }
                            )
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ── 2. Sync alarm channel ────────────────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SYNC_ALARM_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAlarm" -> {
                    try {
                        SyncAlarmReceiver.startAlarm(this)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ALARM_START_FAILED", e.message, null)
                    }
                }
                "stopAlarm" -> {
                    try {
                        SyncAlarmReceiver.stopAlarm(this)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ALARM_STOP_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}