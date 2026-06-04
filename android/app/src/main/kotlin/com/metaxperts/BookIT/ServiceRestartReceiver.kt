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
        val isFrozen    = prefs.getBoolean("flutter.is_timer_frozen", false)

        if (!isClockedIn || isFrozen) {
            Log.d(TAG, "⏭️ Skipping restart — not clocked in or frozen")
            return
        }

        val userId      = prefs.getString("flutter.userId", "")      ?: ""
        val bookerName  = prefs.getString("flutter.userName", "")    ?: ""
        val designation = prefs.getString("flutter.userDesignation", "") ?: ""
        val companyCode = prefs.getString("flutter.companyCode", "") ?: ""

        // ✅ FIX: Guard — don't restart service if we have no userId.
        // This prevents a "zombie" service that would run without identity and post empty rows.
        // The next heartbeat alarm (2 min) will retry when prefs are fully available.
        if (userId.isEmpty()) {
            Log.w(TAG, "⚠️ userId is empty in prefs — skipping restart (next heartbeat will retry)")
            return
        }

        // ✅ FIX: Skip restart if service is already running to avoid double-start
        if (LocationMonitorService.isRunning) {
            Log.d(TAG, "⏭️ Service already running — skipping duplicate restart")
            return
        }

        Log.d(TAG, "🔄 Restarting LocationMonitorService — userId=$userId")

        val serviceIntent = Intent(context, LocationMonitorService::class.java).apply {
            putExtra("extra_user_id",      userId)
            putExtra("extra_booker_name",  bookerName)
            putExtra("extra_designation",  designation)
            putExtra("extra_company_code", companyCode)
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d(TAG, "✅ Service restart triggered — backup systems will be started by onStartCommand()")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to restart service: ${e.message}")
        }
    }
}