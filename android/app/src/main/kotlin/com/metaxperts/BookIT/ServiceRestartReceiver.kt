package com.metaxperts.order_booking_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class ServiceRestartReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_RESTART_SERVICE = "com.metaxperts.order_booking_app.RESTART_SERVICE"
        private const val TAG = "ServiceRestartReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_RESTART_SERVICE) return

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
        val isFrozen = prefs.getBoolean("flutter.is_timer_frozen", false)

        if (!isClockedIn || isFrozen) {
            Log.d(TAG, "⏭️ Skipping restart — not clocked in or frozen")
            return
        }

        val userId = prefs.getString("flutter.userId", "") ?: ""
        val bookerName = prefs.getString("flutter.userName", "") ?: ""
        val designation = prefs.getString("flutter.userDesignation", "") ?: ""
        val companyCode = prefs.getString("flutter.companyCode", "") ?: ""

        Log.d(TAG, "🔄 Restarting LocationMonitorService via BroadcastReceiver — userId=$userId")

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

            // ✅ NEW: Ensure backup systems are running after restart
            BulkPostingScheduler.startBulkPostingAlarm(context)
            try {
                WorkManagerBulkPoster.schedule(context)
            } catch (e: Exception) {
                Log.w(TAG, "WorkManager not available: ${e.message}")
            }

            Log.d(TAG, "✅ Service and backup systems restarted successfully")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to restart service: ${e.message}")
        }
    }
}