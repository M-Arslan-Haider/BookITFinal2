package com.metaxperts.order_booking_app

// ═════════════════════════════════════════════════════════════════════════════
// BootCompletedReceiver — REDESIGNED
//
// After device reboot:
//   1. Restart LocationMonitorService (foreground, location tracking + timer)
//   2. Re-schedule LocationUploadWorker (WorkManager, bulk upload)
//   3. Reschedule MidnightClockoutReceiver alarm
//
// No AlarmManager heartbeat. No ServiceRestartReceiver.
// WorkManager is self-scheduling and survives reboots natively.
// ═════════════════════════════════════════════════════════════════════════════

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class BootCompletedReceiver : BroadcastReceiver() {

    companion object { private const val TAG = "BootReceiver" }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return

        val validActions = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",  // Xiaomi / OnePlus
            "com.htc.intent.action.QUICKBOOT_POWERON"   // HTC
        )
        if (action !in validActions) return

        Log.d(TAG, "📱 Boot detected — action=$action")

        val prefs     = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val clockedIn = prefs.getBoolean("flutter.isClockedIn", false)
        val isFrozen  = prefs.getBoolean("flutter.is_timer_frozen", false)

        if (!clockedIn || isFrozen) {
            Log.d(TAG, "⏭️ Not clocked in — skipping")
            return
        }

        val userId      = prefs.getString("flutter.userId",          "") ?: ""
        val bookerName  = prefs.getString("flutter.userName",        "") ?: ""
        val designation = prefs.getString("flutter.userDesignation", "") ?: ""
        val companyCode = prefs.getString("flutter.companyCode",     "") ?: ""

        // ── Step 1: Reschedule midnight alarm ─────────────────────────────────
        // AlarmManager alarms are lost on reboot; must reschedule
        try {
            MidnightClockoutReceiver.schedule(context)
            Log.d(TAG, "✅ Midnight alarm rescheduled")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Midnight alarm reschedule failed: ${e.message}")
        }

        if (userId.isEmpty()) {
            Log.w(TAG, "⚠️ userId empty — skipping service start (WorkManager will retry)")
            // WorkManager will still schedule itself and restart service when prefs are ready
            LocationUploadWorker.schedule(context)
            return
        }

        // ── Step 2: Restart LocationMonitorService ────────────────────────────
        try {
            val serviceIntent = Intent(context, LocationMonitorService::class.java).apply {
                putExtra(LocationMonitorService.EXTRA_USER_ID,      userId)
                putExtra(LocationMonitorService.EXTRA_BOOKER_NAME,  bookerName)
                putExtra(LocationMonitorService.EXTRA_DESIGNATION,  designation)
                putExtra(LocationMonitorService.EXTRA_COMPANY_CODE, companyCode)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d(TAG, "✅ LocationMonitorService started — userId=$userId")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Service start failed: ${e.message}")
        }

        // ── Step 3: Re-schedule WorkManager upload job ────────────────────────
        // WorkManager technically persists across reboots, but re-enqueuing
        // with KEEP policy is safe and ensures it's always running
        try {
            LocationUploadWorker.schedule(context)
            Log.d(TAG, "✅ LocationUploadWorker rescheduled")
        } catch (e: Exception) {
            Log.e(TAG, "❌ LocationUploadWorker schedule failed: ${e.message}")
        }

        Log.d(TAG, "✅ Boot handling complete — userId=$userId")
    }
}