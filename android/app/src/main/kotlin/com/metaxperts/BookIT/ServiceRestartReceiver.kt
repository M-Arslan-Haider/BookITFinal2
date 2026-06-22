//package com.metaxperts.order_booking_app
//
//import android.content.BroadcastReceiver
//import android.content.Context
//import android.content.Intent
//import android.os.Build
//import android.util.Log
//
//class ServiceRestartReceiver : BroadcastReceiver() {
//
//    companion object {
//        const val ACTION_RESTART_SERVICE = "com.metaxperts.order_booking_app.RESTART_SERVICE"
//        private const val TAG = "ServiceRestartReceiver"
//    }
//
//    override fun onReceive(context: Context, intent: Intent) {
//        if (intent.action != ACTION_RESTART_SERVICE) return
//
//        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
//        val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
//        val isFrozen    = prefs.getBoolean("flutter.is_timer_frozen", false)
//
//        if (!isClockedIn || isFrozen) {
//            Log.d(TAG, "⏭️ Skipping restart — not clocked in or frozen")
//            return
//        }
//
//        val userId      = prefs.getString("flutter.userId", "")      ?: ""
//        val bookerName  = prefs.getString("flutter.userName", "")    ?: ""
//        val designation = prefs.getString("flutter.userDesignation", "") ?: ""
//        val companyCode = prefs.getString("flutter.companyCode", "") ?: ""
//
//        // ✅ FIX: Guard — don't restart service if we have no userId.
//        // This prevents a "zombie" service that would run without identity and post empty rows.
//        // The next heartbeat alarm (2 min) will retry when prefs are fully available.
//        if (userId.isEmpty()) {
//            Log.w(TAG, "⚠️ userId is empty in prefs — skipping restart (next heartbeat will retry)")
//            return
//        }
//
//        // ✅ FIX: Skip restart if service is already running to avoid double-start
//        if (LocationMonitorService.isRunning) {
//            Log.d(TAG, "⏭️ Service already running — skipping duplicate restart")
//            return
//        }
//
//        Log.d(TAG, "🔄 Restarting LocationMonitorService — userId=$userId")
//
//        val serviceIntent = Intent(context, LocationMonitorService::class.java).apply {
//            putExtra("extra_user_id",      userId)
//            putExtra("extra_booker_name",  bookerName)
//            putExtra("extra_designation",  designation)
//            putExtra("extra_company_code", companyCode)
//        }
//
//        try {
//            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
//                context.startForegroundService(serviceIntent)
//            } else {
//                context.startService(serviceIntent)
//            }
//            Log.d(TAG, "✅ Service restart triggered — backup systems will be started by onStartCommand()")
//        } catch (e: Exception) {
//            Log.e(TAG, "❌ Failed to restart service: ${e.message}")
//        }
//    }
//}

///poweroff
package com.metaxperts.order_booking_app

// ═════════════════════════════════════════════════════════════════════════════
// ServiceRestartReceiver — AlarmManager watchdog (self-repeating)
//
// Why this exists:
//   On aggressive OEM devices (Transsion/Tecno/Infinix, Xiaomi, Oppo, Vivo...)
//   the "Phone Manager" / RAM cleaner can SIGKILL the app process directly,
//   WITHOUT calling onTaskRemoved() or onDestroy(). When that happens:
//     - The 5-min power-status heartbeat (in-process Handler) stops dead.
//     - WorkManager periodic work can also be deferred 15-60+ min by Doze.
//
//   AlarmManager alarms are registered with the OS, independent of the app
//   process. Even if the process was killed, firing this alarm makes Android
//   START A NEW PROCESS to deliver the broadcast — which lets us restart
//   LocationMonitorService.
//
// How it works:
//   - scheduleWatchdog() arms a one-shot exact alarm ~5 min in the future.
//   - When it fires, onReceive() checks isClockedIn/isFrozen:
//       - if NOT clocked in (or frozen) -> do nothing, chain stops here.
//       - if clocked in -> restart the service if not already running,
//         then immediately re-arm the NEXT alarm (self-repeating chain).
//   - This chain restarts itself every time LocationMonitorService starts
//     (startAllLoops -> scheduleWatchdog), and on every boot
//     (BootCompletedReceiver -> scheduleWatchdog), so it's always armed
//     while the booker is clocked in.
// ═════════════════════════════════════════════════════════════════════════════

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class ServiceRestartReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_RESTART_SERVICE = "com.metaxperts.order_booking_app.RESTART_SERVICE"
        private const val TAG = "ServiceRestartReceiver"
        private const val REQUEST_CODE = 9001

        // Watchdog interval — short enough to recover quickly from an OEM
        // kill, long enough to not be noticeable on battery.
        private const val WATCHDOG_INTERVAL_MS = 5 * 60_000L  // 5 minutes

        private fun pendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, ServiceRestartReceiver::class.java).apply {
                action = ACTION_RESTART_SERVICE
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            return PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)
        }

        /** Arm (or re-arm) the next watchdog alarm, ~5 min from now. */
        fun scheduleWatchdog(context: Context, delayMillis: Long = WATCHDOG_INTERVAL_MS) {
            try {
                val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val pi = pendingIntent(context)
                val triggerAt = System.currentTimeMillis() + delayMillis

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    // Fires even in Doze — this is the whole point of the watchdog.
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
                } else {
                    am.set(AlarmManager.RTC_WAKEUP, triggerAt, pi)
                }
                Log.d(TAG, "⏰ Watchdog armed — next check in ${delayMillis / 60_000L} min")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to schedule watchdog: ${e.message}")
            }
        }

        /** Cancel the watchdog chain (call on clock-out, if/when that flow can reach here). */
        fun cancelWatchdog(context: Context) {
            try {
                val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                am.cancel(pendingIntent(context))
                Log.d(TAG, "🛑 Watchdog cancelled")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to cancel watchdog: ${e.message}")
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_RESTART_SERVICE) return

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
        val isFrozen    = prefs.getBoolean("flutter.is_timer_frozen", false)

        if (!isClockedIn || isFrozen) {
            Log.d(TAG, "⏭️ Not clocked in / frozen — watchdog chain stopping")
            // Do NOT reschedule — chain stops. It will be re-armed next time
            // LocationMonitorService starts (clock-in) or on next boot.
            return
        }

        val userId      = prefs.getString("flutter.userId", "")      ?: ""
        val bookerName  = prefs.getString("flutter.userName", "")    ?: ""
        val designation = prefs.getString("flutter.userDesignation", "") ?: ""
        val companyCode = prefs.getString("flutter.companyCode", "") ?: ""

        if (userId.isEmpty()) {
            Log.w(TAG, "⚠️ userId empty — skipping restart, but keeping watchdog armed")
            scheduleWatchdog(context)
            return
        }

        if (LocationMonitorService.isRunning) {
            Log.d(TAG, "✅ Service already running — watchdog OK, re-arming")
        } else {
            Log.d(TAG, "🔄 Service NOT running — restarting (userId=$userId)")

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
                Log.d(TAG, "✅ Service restart triggered")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to restart service: ${e.message}")
            }
        }

        // Self-repeating chain: as long as we're clocked in, keep checking.
        scheduleWatchdog(context)
    }
}