package com.metaxperts.order_booking_app

// ═════════════════════════════════════════════════════════════════════════════
// MainActivity — REDESIGNED
//
// Changes from old version:
//   ❌ Removed: SyncAlarmReceiver.startAlarm/stopAlarm (replaced by WorkManager)
//   ✅ Kept: location_monitor channel (start/stop service)
//   ✅ Kept: auto_time channel
//   ✅ Kept: oem_settings channel
//   ✅ Kept: battery optimization request
//   ✅ Kept: synchronous prefs commit before service start
//
// On "startMonitoring":
//   1. Commit user identity to SharedPreferences (sync .commit())
//   2. Start LocationMonitorService (foreground)
//   3. Schedule LocationUploadWorker (WorkManager, 15 min periodic)
//
// On "stopMonitoring":
//   1. Stop LocationMonitorService
//   2. Cancel LocationUploadWorker
//   3. Cancel MidnightClockoutReceiver alarm
// ═════════════════════════════════════════════════════════════════════════════

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

    private val LOCATION_CHANNEL    = "com.metaxperts.order_booking_app/location_monitor"
    private val AUTO_TIME_CHANNEL   = "com.metaxperts.order_booking_app/auto_time"
    private val OEM_SETTINGS_CHANNEL= "com.metaxperts.order_booking_app/oem_settings"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ProviderInstaller.installIfNeededAsync(this, this)
        requestBatteryOptimizationIfNeeded()
    }

    // ── Synchronously write user identity before starting service ─────────────
    // Uses .commit() not .apply() to guarantee disk write before service reads prefs.
    // Critical on OEM devices where cold restart reads prefs before apply() flushes.
    private fun saveUserIdentitySync(
        userId:      String,
        bookerName:  String,
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
                .commit()
            android.util.Log.d("MainActivity", "✅ Identity committed (sync) — userId=$userId")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "❌ saveUserIdentitySync failed: ${e.message}")
        }
    }

    private fun requestBatteryOptimizationIfNeeded() {
        try {
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                })
            }
        } catch (_: Exception) {}
    }

    private fun isAutoTimeEnabled(): Boolean = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
            Settings.Global.getInt(contentResolver, Settings.Global.AUTO_TIME, 0) == 1
        } else {
            @Suppress("DEPRECATION")
            Settings.System.getInt(contentResolver, Settings.System.AUTO_TIME, 0) == 1
        }
    } catch (_: Exception) { false }

    private fun openDateTimeSettings() {
        try { startActivity(Intent(Settings.ACTION_DATE_SETTINGS)) }
        catch (_: Exception) { startActivity(Intent(Settings.ACTION_SETTINGS)) }
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
            try { startActivity(intent); return } catch (_: Exception) {}
        }
    }

    override fun onProviderInstalled() {}
    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── 1. Location Monitor Channel ───────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startMonitoring" -> {
                        try {
                            val userId      = call.argument<String>("userId")      ?: ""
                            val bookerName  = call.argument<String>("bookerName")  ?: ""
                            val designation = call.argument<String>("designation") ?: ""
                            val companyCode = call.argument<String>("companyCode") ?: ""

                            // Step 1: Write identity synchronously FIRST
                            saveUserIdentitySync(userId, bookerName, designation, companyCode)

                            // Step 2: Start foreground service
                            LocationMonitorService.start(this, userId, bookerName, designation, companyCode)

                            // Step 3: Schedule WorkManager upload job
                            LocationUploadWorker.schedule(this)

                            result.success(null)
                        } catch (e: Exception) {
                            result.error("START_FAILED", e.message, null)
                        }
                    }
                    "stopMonitoring" -> {
                        try {
                            // Stop foreground service
                            LocationMonitorService.stop(this)
                            // Cancel WorkManager upload job
                            LocationUploadWorker.cancel(this)
                            // Cancel midnight alarm
                            MidnightClockoutReceiver.cancel(this)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("STOP_FAILED", e.message, null)
                        }
                    }
                    "requestBatteryOptimization" -> {
                        try {
                            val pm = getSystemService(POWER_SERVICE) as PowerManager
                            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = Uri.parse("package:$packageName")
                                })
                            }
                            result.success(null)
                        } catch (_: Exception) { result.success(null) }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── 2. Auto Date & Time Channel ───────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUTO_TIME_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAutoTimeEnabled"  -> result.success(isAutoTimeEnabled())
                    "openDateTimeSettings" -> { openDateTimeSettings(); result.success(null) }
                    else -> result.notImplemented()
                }
            }

        // ── 3. OEM Settings Channel ───────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OEM_SETTINGS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openOemAutoStartSettings" -> { openOemAutoStartSettings(); result.success(null) }
                    "getOemBrand"              -> result.success(Build.MANUFACTURER.lowercase())
                    else -> result.notImplemented()
                }
            }
    }
}