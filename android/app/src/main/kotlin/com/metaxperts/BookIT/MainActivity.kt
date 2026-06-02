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
//
//    override fun onCreate(savedInstanceState: Bundle?) {
//        super.onCreate(savedInstanceState)
//        ProviderInstaller.installIfNeededAsync(this, this)
//        requestBatteryOptimizationIfNeeded()
//    }
//
//    override fun onResume() {
//        super.onResume()
//        // No bubble code
//    }
//
//    override fun onPause() {
//        super.onPause()
//        // No bubble code
//    }
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
//            // ignore
//        }
//    }
//
//    override fun onProviderInstalled() {}
//
//    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
//        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
//    }
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

    private val LOCATION_CHANNEL   = "com.metaxperts.order_booking_app/location_monitor"
    private val SYNC_ALARM_CHANNEL = "com.metaxperts.order_booking_app/sync_alarm"

    // ✅ NEW: Auto Date & Time check channel
    private val AUTO_TIME_CHANNEL  = "com.metaxperts.order_booking_app/auto_time"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ProviderInstaller.installIfNeededAsync(this, this)
        requestBatteryOptimizationIfNeeded()
    }

    override fun onResume() {
        super.onResume()
    }

    override fun onPause() {
        super.onPause()
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

    // ── Check whether Android "Automatic date & time" is enabled ─────────────
    private fun isAutoTimeEnabled(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
                Settings.Global.getInt(
                    contentResolver,
                    Settings.Global.AUTO_TIME,
                    0
                ) == 1
            } else {
                @Suppress("DEPRECATION")
                Settings.System.getInt(
                    contentResolver,
                    Settings.System.AUTO_TIME,
                    0
                ) == 1
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "isAutoTimeEnabled error: ${e.message}")
            false
        }
    }

    // ── Open Android Date & Time settings ────────────────────────────────────
    private fun openDateTimeSettings() {
        try {
            startActivity(Intent(Settings.ACTION_DATE_SETTINGS))
        } catch (e: Exception) {
            // Fallback
            startActivity(Intent(Settings.ACTION_SETTINGS))
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

        // ── 3. ✅ NEW: Auto Date & Time channel ──────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUTO_TIME_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // Returns true if Android Automatic Date & Time is ON
                "isAutoTimeEnabled" -> {
                    result.success(isAutoTimeEnabled())
                }
                // Opens Android Date & Time settings screen
                "openDateTimeSettings" -> {
                    openDateTimeSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}