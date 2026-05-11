package com.metaxperts.order_booking_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class BootCompletedReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val validActions = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON"
        )
        if (intent.action !in validActions) return

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
        val isFrozen = prefs.getBoolean("flutter.is_timer_frozen", false)

        if (!isClockedIn || isFrozen) {
            Log.d(TAG, "⏭️ Not clocked in — skipping (action=${intent.action})")
            return
        }

        val userId = prefs.getString("flutter.userId", "") ?: ""
        val bookerName = prefs.getString("flutter.userName", "") ?: ""
        val designation = prefs.getString("flutter.userDesignation", "") ?: ""
        val companyCode = prefs.getString("flutter.companyCode", "") ?: ""

        if (userId.isEmpty() || companyCode.isEmpty()) {
            Log.w(TAG, "❌ userId or companyCode empty — refusing service start")
            return
        }

        Log.d(TAG, "✅ Restarting service — userId=$userId action=${intent.action}")

        val serviceIntent = Intent(context, LocationMonitorService::class.java).apply {
            putExtra("extra_user_id", userId)
            putExtra("extra_booker_name", bookerName)
            putExtra("extra_designation", designation)
            putExtra("extra_company_code", companyCode)
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }

            // ✅ NEW: Start backup systems
            BulkPostingScheduler.startBulkPostingAlarm(context)
            try {
                WorkManagerBulkPoster.schedule(context)
            } catch (e: Exception) {
                Log.w(TAG, "WorkManager not available: ${e.message}")
            }

            Log.d(TAG, "✅ Services and backup systems restarted successfully")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Service start failed: ${e.message}")
        }
    }
}