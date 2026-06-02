//package com.metaxperts.order_booking_app
//
//import android.content.BroadcastReceiver
//import android.content.Context
//import android.content.Intent
//import android.os.Build
//import android.util.Log
//
//class BootCompletedReceiver : BroadcastReceiver() {
//
//    companion object {
//        private const val TAG = "BootReceiver"
//    }
//
//    override fun onReceive(context: Context, intent: Intent) {
//        val validActions = setOf(
//            Intent.ACTION_BOOT_COMPLETED,
//            Intent.ACTION_LOCKED_BOOT_COMPLETED,
//            Intent.ACTION_MY_PACKAGE_REPLACED,
//            "android.intent.action.QUICKBOOT_POWERON",
//            "com.htc.intent.action.QUICKBOOT_POWERON"
//        )
//        if (intent.action !in validActions) return
//
//        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
//        val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
//        val isFrozen = prefs.getBoolean("flutter.is_timer_frozen", false)
//
//        if (!isClockedIn || isFrozen) {
//            Log.d(TAG, "⏭️ Not clocked in — skipping (action=${intent.action})")
//            return
//        }
//
//        val userId = prefs.getString("flutter.userId", "") ?: ""
//        val bookerName = prefs.getString("flutter.userName", "") ?: ""
//        val designation = prefs.getString("flutter.userDesignation", "") ?: ""
//        val companyCode = prefs.getString("flutter.companyCode", "") ?: ""
//
//        if (userId.isEmpty() || companyCode.isEmpty()) {
//            Log.w(TAG, "❌ userId or companyCode empty — refusing service start")
//            return
//        }
//
//        Log.d(TAG, "✅ Restarting service — userId=$userId action=${intent.action}")
//
//        val serviceIntent = Intent(context, LocationMonitorService::class.java).apply {
//            putExtra("extra_user_id", userId)
//            putExtra("extra_booker_name", bookerName)
//            putExtra("extra_designation", designation)
//            putExtra("extra_company_code", companyCode)
//        }
//
//        try {
//            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
//                context.startForegroundService(serviceIntent)
//            } else {
//                context.startService(serviceIntent)
//            }
//
//            // ✅ NEW: Start backup systems
//            BulkPostingScheduler.startBulkPostingAlarm(context)
//            try {
//                WorkManagerBulkPoster.schedule(context)
//            } catch (e: Exception) {
//                Log.w(TAG, "WorkManager not available: ${e.message}")
//            }
//
//            Log.d(TAG, "✅ Services and backup systems restarted successfully")
//        } catch (e: Exception) {
//            Log.e(TAG, "❌ Service start failed: ${e.message}")
//        }
//    }
//}


package com.metaxperts.order_booking_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

// ─────────────────────────────────────────────────────────────────────────────
// BootCompletedReceiver
// Reboot ke baad:
//   1. MidnightClockoutReceiver alarm reschedule karta hai
//   2. LocationMonitorService restart karta hai
//   3. Backup systems (AlarmManager + WorkManager) start karta hai
//
// Manifest mein pehle se registered hai — koi change nahi chahiye
// ─────────────────────────────────────────────────────────────────────────────

class BootCompletedReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return

        // ✅ Sab OEMs cover karo
        val validActions = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",   // Xiaomi, OnePlus
            "com.htc.intent.action.QUICKBOOT_POWERON"    // HTC
        )

        if (action !in validActions) return

        Log.d(TAG, "📱 Boot detected — action=$action")

        val prefs     = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val clockedIn = prefs.getBoolean("flutter.isClockedIn", false)
        val isFrozen  = prefs.getBoolean("flutter.is_timer_frozen", false)

        Log.d(TAG, "State — clockedIn=$clockedIn frozen=$isFrozen")

        if (!clockedIn || isFrozen) {
            Log.d(TAG, "⏭️ Not clocked in — skipping")
            return
        }

        val userId      = prefs.getString("flutter.userId", "")          ?: ""
        val bookerName  = prefs.getString("flutter.userName", "")        ?: ""
        val designation = prefs.getString("flutter.userDesignation", "") ?: ""
        val companyCode = prefs.getString("flutter.companyCode", "")     ?: ""

        if (userId.isEmpty()) {
            Log.w(TAG, "❌ userId empty — skipping service start")
            // ✅ Alarm phir bhi reschedule karo — service baad mein khud start hogi
        }

        // ── Step 1: Midnight alarm reschedule karo ────────────────
        // Chinese OEM reboot ke baad sab alarms cancel kar dete hain
        // Isliye yahan wapis schedule karna zaroori hai
        try {
            MidnightClockoutReceiver.schedule(context)
            Log.d(TAG, "✅ Midnight alarm rescheduled after boot")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Alarm reschedule failed: ${e.message}")
        }

        // userId empty ho to service start mat karo
        if (userId.isEmpty()) return

        // ── Step 2: LocationMonitorService restart karo ───────────
        try {
            val serviceIntent = Intent(context, LocationMonitorService::class.java).apply {
                putExtra("extra_user_id",      userId)
                putExtra("extra_booker_name",  bookerName)
                putExtra("extra_designation",  designation)
                putExtra("extra_company_code", companyCode)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }

            Log.d(TAG, "✅ LocationMonitorService restarted — userId=$userId")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Service start failed: ${e.message}")
        }

        // ── Step 3: Backup systems restart karo ──────────────────
        try {
            BulkPostingScheduler.startBulkPostingAlarm(context)
            Log.d(TAG, "✅ BulkPostingAlarm restarted")
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ BulkPostingAlarm failed: ${e.message}")
        }

        try {
            WorkManagerBulkPoster.schedule(context)
            Log.d(TAG, "✅ WorkManager restarted")
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ WorkManager not available: ${e.message}")
        }

        Log.d(TAG, "✅ Boot handling complete — userId=$userId")
    }
}