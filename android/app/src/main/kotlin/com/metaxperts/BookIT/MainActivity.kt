package com.metaxperts.order_booking_app

import android.content.ComponentName
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
    private val AUTO_TIME_CHANNEL  = "com.metaxperts.order_booking_app/auto_time"
    private val OEM_SETTINGS_CHANNEL = "com.metaxperts.order_booking_app/oem_settings"

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

    // ✅ FIX: Synchronously commit user identity to SharedPreferences BEFORE starting service.
    // Using .commit() (not .apply()) so the write is guaranteed on disk before service start.
    // When Android restarts the service after an app kill, it reads these prefs on cold restart.
    // If .apply() was used, a race condition could cause userId to be empty on first restart.
    private fun saveUserIdentitySync(
        userId: String,
        bookerName: String,
        designation: String,
        companyCode: String
    ) {
        try {
            getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                .edit()
                .putString("flutter.userId",          userId)
                .putString("flutter.userName",        bookerName)
                .putString("flutter.userDesignation", designation)
                .putString("flutter.companyCode",     companyCode)
                .commit() // synchronous — guarantees disk write before service start
            android.util.Log.d("MainActivity", "✅ User identity committed to prefs (sync) — userId=$userId")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "❌ saveUserIdentitySync failed: ${e.message}")
        }
    }

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

    private fun openDateTimeSettings() {
        try {
            startActivity(Intent(Settings.ACTION_DATE_SETTINGS))
        } catch (e: Exception) {
            startActivity(Intent(Settings.ACTION_SETTINGS))
        }
    }

    private fun openOemAutoStartSettings() {
        val intents = listOf(
            Intent().setComponent(ComponentName("com.miui.securitycenter",
                "com.miui.permcenter.autostart.AutoStartManagementActivity")),
            Intent().setComponent(ComponentName("com.coloros.safecenter",
                "com.coloros.privacypermissionsentry.PermissionTopActivity")),
            Intent().setComponent(ComponentName("com.oppo.safe",
                "com.oppo.safe.permission.startup.StartupAppListActivity")),
            Intent().setComponent(ComponentName("com.vivo.permissionmanager",
                "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")),
            Intent().setComponent(ComponentName("com.huawei.systemmanager",
                "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")),
            Intent().setComponent(ComponentName("com.samsung.android.lool",
                "com.samsung.android.sm.ui.battery.BatteryActivity")),
            Intent().setComponent(ComponentName("com.oneplus.security",
                "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity")),
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
        )

        for (intent in intents) {
            try {
                startActivity(intent)
                return
            } catch (e: Exception) {
                // continue to next intent
            }
        }
    }

    private fun getOemBrand(): String {
        return Build.MANUFACTURER.lowercase()
    }

    override fun onProviderInstalled() {}

    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Location monitor channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LOCATION_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startMonitoring" -> {
                    try {
                        val userId      = call.argument<String>("userId")      ?: ""
                        val bookerName  = call.argument<String>("bookerName")  ?: ""
                        val designation = call.argument<String>("designation") ?: ""
                        val companyCode = call.argument<String>("companyCode") ?: ""

                        // ✅ FIX: Write identity to prefs synchronously FIRST.
                        // Guarantees userId is on disk before the service starts.
                        // Critical for cold restarts after app kill — service reads from prefs.
                        saveUserIdentitySync(userId, bookerName, designation, companyCode)

                        LocationMonitorService.start(
                            context     = this,
                            userId      = userId,
                            bookerName  = bookerName,
                            designation = designation,
                            companyCode = companyCode
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

        // 2. Sync alarm channel
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

        // 3. Auto Date & Time channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUTO_TIME_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAutoTimeEnabled" -> {
                    result.success(isAutoTimeEnabled())
                }
                "openDateTimeSettings" -> {
                    openDateTimeSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // 4. OEM Settings Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OEM_SETTINGS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openOemAutoStartSettings" -> {
                    openOemAutoStartSettings()
                    result.success(null)
                }
                "getOemBrand" -> {
                    result.success(getOemBrand())
                }
                else -> result.notImplemented()
            }
        }
    }
}