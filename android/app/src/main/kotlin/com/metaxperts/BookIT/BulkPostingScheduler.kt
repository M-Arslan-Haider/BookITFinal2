//package com.metaxperts.order_booking_app
//
//// ═════════════════════════════════════════════════════════════════════════════
//// BulkPostingScheduler.kt — REDESIGNED
////
//// What's LEFT here (kept because needed elsewhere):
////   ✅ GpsPolicy data class
////   ✅ GpsPolicyManager (fetches interval + accuracy from server)
////   ✅ MidnightClockoutReceiver (exact 10 PM alarm — AlarmManager needed here)
////
//// What's REMOVED:
////   ❌ BulkPostingScheduler class (replaced by LocationUploadWorker)
////   ❌ BulkPostAlarmReceiver class (replaced by LocationUploadWorker)
////   ❌ Heartbeat alarm (replaced by WorkManager periodic)
////   ❌ ServiceRestartAlarm (replaced by WorkManager + START_STICKY)
//// ═════════════════════════════════════════════════════════════════════════════
//
//import android.app.AlarmManager
//import android.app.NotificationChannel
//import android.app.NotificationManager
//import android.app.PendingIntent
//import android.content.BroadcastReceiver
//import android.content.Context
//import android.content.Intent
//import android.graphics.Color
//import android.os.Build
//import android.util.Log
//import androidx.core.app.NotificationCompat
//import org.json.JSONArray
//import org.json.JSONObject
//import java.text.SimpleDateFormat
//import java.util.Locale
//
//// ─────────────────────────────────────────────────────────────────────────────
//// GpsPolicy — interval and accuracy settings from server
//// ─────────────────────────────────────────────────────────────────────────────
//
//data class GpsPolicy(
//    val locationIntervalSec: Long,
//    val gpsAccuracy: String
//)
//
//// ─────────────────────────────────────────────────────────────────────────────
//// GpsPolicyManager — fetches/caches GPS policy from backend API
//// ─────────────────────────────────────────────────────────────────────────────
//
//object GpsPolicyManager {
//
//    private const val TAG        = "GpsPolicyManager"
//    private const val POLICY_API = "https://cloud.metaxperts.net:8443/erp/valor_trading/gpstracking/get/"
//
//    private const val PREF_INTERVAL   = "gps_policy_interval_sec"
//    private const val PREF_ACCURACY   = "gps_policy_accuracy"
//    private const val PREF_FETCHED_AT = "gps_policy_fetched_at"
//
//    private val DEFAULT      = GpsPolicy(locationIntervalSec = 60L, gpsAccuracy = "high")
//    private const val CACHE_TTL_SEC = 300L  // 5 minutes
//
//    fun fetchPolicy(context: Context, forceRefresh: Boolean = false): GpsPolicy {
//        val prefs       = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
//        val userId      = prefs.getString("flutter.userId",      "") ?: ""
//        val companyCode = prefs.getString("flutter.companyCode", "") ?: ""
//
//        if (userId.isEmpty() || companyCode.isEmpty()) {
//            Log.w(TAG, "⚠️ userId/companyCode empty — using cached/default policy")
//            return loadCachedPolicy(prefs)
//        }
//
//        if (!forceRefresh) {
//            val fetchedAt = prefs.getLong(PREF_FETCHED_AT, 0L)
//            val ageSec    = System.currentTimeMillis() / 1000L - fetchedAt
//            if (ageSec < CACHE_TTL_SEC) {
//                val cached = loadCachedPolicy(prefs)
//                Log.d(TAG, "📦 Policy cache hit — interval=${cached.locationIntervalSec}s")
//                return cached
//            }
//        }
//
//        return try {
//            val url  = java.net.URL("$POLICY_API?company_code=$companyCode&user_id=$userId")
//            val conn = url.openConnection() as java.net.HttpURLConnection
//            conn.connectTimeout = 10_000
//            conn.readTimeout    = 10_000
//            conn.requestMethod  = "GET"
//            conn.setRequestProperty("Accept", "application/json")
//
//            val code = conn.responseCode
//            if (code in 200..299) {
//                val body   = conn.inputStream.bufferedReader().readText()
//                conn.disconnect()
//                val policy = parsePolicy(body)
//                savePolicyToPrefs(prefs, policy)
//                Log.d(TAG, "✅ Policy fetched — interval=${policy.locationIntervalSec}s accuracy=${policy.gpsAccuracy}")
//                policy
//            } else {
//                conn.disconnect()
//                Log.w(TAG, "⚠️ Policy API returned $code — using cache")
//                loadCachedPolicy(prefs)
//            }
//        } catch (e: Exception) {
//            Log.e(TAG, "❌ Policy fetch failed: ${e.message} — using cache")
//            loadCachedPolicy(prefs)
//        }
//    }
//
//    private fun parsePolicy(json: String): GpsPolicy {
//        return try {
//            val root = JSONObject(json)
//            val obj: JSONObject? = when {
//                root.has("items") -> {
//                    val items = root.getJSONArray("items")
//                    if (items.length() > 0) items.getJSONObject(0) else null
//                }
//                else -> root
//            }
//            if (obj == null) { Log.w(TAG, "⚠️ Empty policy items — using default"); return DEFAULT }
//            GpsPolicy(
//                locationIntervalSec = obj.optLong("location_interval_sec", DEFAULT.locationIntervalSec),
//                gpsAccuracy         = obj.optString("gps_accuracy", DEFAULT.gpsAccuracy).lowercase()
//            )
//        } catch (_: Exception) {
//            try {
//                val arr = JSONArray(json)
//                val obj = arr.optJSONObject(0) ?: return DEFAULT
//                GpsPolicy(
//                    locationIntervalSec = obj.optLong("location_interval_sec", DEFAULT.locationIntervalSec),
//                    gpsAccuracy         = obj.optString("gps_accuracy", DEFAULT.gpsAccuracy).lowercase()
//                )
//            } catch (e2: Exception) {
//                Log.e(TAG, "❌ Policy parse error: ${e2.message}")
//                DEFAULT
//            }
//        }
//    }
//
//    private fun loadCachedPolicy(prefs: android.content.SharedPreferences): GpsPolicy {
//        val interval = prefs.getLong(PREF_INTERVAL, DEFAULT.locationIntervalSec)
//        val accuracy = prefs.getString(PREF_ACCURACY, DEFAULT.gpsAccuracy) ?: DEFAULT.gpsAccuracy
//        return GpsPolicy(locationIntervalSec = interval, gpsAccuracy = accuracy)
//    }
//
//    private fun savePolicyToPrefs(prefs: android.content.SharedPreferences, policy: GpsPolicy) {
//        prefs.edit()
//            .putLong(PREF_INTERVAL,   policy.locationIntervalSec)
//            .putString(PREF_ACCURACY, policy.gpsAccuracy)
//            .putLong(PREF_FETCHED_AT, System.currentTimeMillis() / 1000L)
//            .apply()
//    }
//}
//
//// ─────────────────────────────────────────────────────────────────────────────
//// MidnightClockoutReceiver
//// Uses AlarmManager (exact, RTC_WAKEUP) because it needs to fire at a specific
//// wall-clock time (10 PM). WorkManager cannot guarantee exact wall-clock time.
//// ─────────────────────────────────────────────────────────────────────────────
//
//class MidnightClockoutReceiver : BroadcastReceiver() {
//
//    companion object {
//        const val ACTION_MIDNIGHT_CLOCKOUT = "com.metaxperts.order_booking_app.MIDNIGHT_CLOCKOUT"
//
//        fun schedule(context: Context) {
//            val prefs     = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
//            val clockedIn = prefs.getBoolean("flutter.isClockedIn", false)
//            val isFrozen  = prefs.getBoolean("flutter.is_timer_frozen", false)
//            if (!clockedIn || isFrozen) return
//
//            val am     = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
//            val intent = Intent(context, MidnightClockoutReceiver::class.java).apply {
//                action = ACTION_MIDNIGHT_CLOCKOUT
//            }
//            val pi = PendingIntent.getBroadcast(context, 2200, intent,
//                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
//
//            val now    = java.util.Calendar.getInstance()
//            val target = java.util.Calendar.getInstance().apply {
//                set(java.util.Calendar.HOUR_OF_DAY, 22)
//                set(java.util.Calendar.MINUTE, 0)
//                set(java.util.Calendar.SECOND, 0)
//                set(java.util.Calendar.MILLISECOND, 0)
//            }
//            if (now.after(target)) target.add(java.util.Calendar.DAY_OF_MONTH, 1)
//
//            try {
//                when {
//                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && am.canScheduleExactAlarms() ->
//                        am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.timeInMillis, pi)
//                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
//                        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.timeInMillis, pi)
//                    else ->
//                        am.set(AlarmManager.RTC_WAKEUP, target.timeInMillis, pi)
//                }
//                Log.d("MidnightClockout", "✅ Alarm scheduled for ${target.time}")
//            } catch (e: Exception) {
//                Log.d("MidnightClockout", "⚠️ Alarm schedule failed: ${e.message}")
//            }
//        }
//
//        fun cancel(context: Context) {
//            try {
//                val am     = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
//                val intent = Intent(context, MidnightClockoutReceiver::class.java).apply {
//                    action = ACTION_MIDNIGHT_CLOCKOUT
//                }
//                val pi = PendingIntent.getBroadcast(context, 2200, intent,
//                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
//                pi?.let { am.cancel(it) }
//            } catch (_: Exception) {}
//        }
//    }
//
//    override fun onReceive(context: Context, intent: Intent?) {
//        if (intent?.action != ACTION_MIDNIGHT_CLOCKOUT) return
//
//        val prefs     = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
//        val clockedIn = prefs.getBoolean("flutter.isClockedIn", false)
//        val isFrozen  = prefs.getBoolean("flutter.is_timer_frozen", false)
//        if (!clockedIn || isFrozen) return
//
//        val now       = java.util.Date()
//        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(now)
//        val reason    = "System ClockOut - 10:00 PM"
//        val userId    = prefs.getString("flutter.userId",   "") ?: ""
//        val elapsed   = prefs.getString("flutter.elapsed_time", "00:00:00") ?: "00:00:00"
//        val clockInT  = prefs.getString("flutter.clockInTime",  "") ?: ""
//
//        prefs.edit()
//            .putBoolean("flutter.has_critical_event_pending", true)
//            .putBoolean("has_critical_event_pending", true)
//            .putString("flutter.critical_event_reason", reason)
//            .putString("critical_event_reason", reason)
//            .putString("flutter.critical_event_timestamp", timestamp)
//            .putBoolean("flutter.is_timer_frozen", true)
//            .putBoolean("flutter.isClockedIn", false)
//            .putBoolean("isClockedIn", false)
//            .putString("flutter.fastClockOutTime", timestamp)
//            .putFloat("flutter.fastClockOutDistance", 0f)
//            .putString("flutter.fastClockOutReason", reason)
//            .putBoolean("flutter.hasFastClockOutData", true)
//            .putBoolean("flutter.clockOutPending", true)
//            .putString("flutter.fastClockOutData",
//                """{"fast_attendanceId":"","fast_userId":"$userId","fast_clockOutTime":"$timestamp","fast_totalTime":"$elapsed","fast_totalDistance":0.0,"fast_latOut":0.0,"fast_lngOut":0.0,"fast_address":"","fast_reason":"$reason","fast_savedAt":"${System.currentTimeMillis()}","fast_clockInTime":"$clockInT"}""")
//            .commit()
//
//        // Stop service + cancel WorkManager
//        try { context.stopService(Intent(context, LocationMonitorService::class.java)) } catch (_: Exception) {}
//        try { LocationUploadWorker.cancel(context) } catch (_: Exception) {}
//
//        showMidnightNotification(context, timestamp)
//    }
//
//    private fun showMidnightNotification(context: Context, time: String) {
//        try {
//            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
//            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
//                nm.createNotificationChannel(
//                    NotificationChannel("urgent_auto_clockout_channel", "URGENT Auto Clockout",
//                        NotificationManager.IMPORTANCE_HIGH).apply {
//                        enableVibration(true)
//                        vibrationPattern = longArrayOf(0, 1000, 500, 1000)
//                        enableLights(true)
//                        lightColor = Color.RED
//                    }
//                )
//            }
//            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
//                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
//            }
//            val pi = PendingIntent.getActivity(context, 0, launchIntent,
//                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
//            val n = NotificationCompat.Builder(context, "urgent_auto_clockout_channel")
//                .setContentTitle("⏰ Auto Clock-Out at 10:00 PM")
//                .setContentText("You were automatically clocked out. Open app to sync.")
//                .setSmallIcon(R.mipmap.ic_launcher)
//                .setPriority(NotificationCompat.PRIORITY_MAX)
//                .setCategory(NotificationCompat.CATEGORY_ALARM)
//                .setAutoCancel(true)
//                .setContentIntent(pi)
//                .setVibrate(longArrayOf(0, 1000, 500, 1000))
//                .build()
//            nm.notify(9997, n)
//        } catch (_: Exception) {}
//    }
//}


package com.metaxperts.order_booking_app

// ═════════════════════════════════════════════════════════════════════════════
// BulkPostingScheduler.kt — UPDATED
//
// Changes vs previous version:
//   ✅ MidnightClockoutReceiver now sets TWO alarms:
//        • 10:00 PM  — primary (strict, exact, RTC_WAKEUP)
//        • 11:00 PM  — backup  (fires ONLY if 10 PM was missed / device was off)
//   ✅ Backup alarm checks a SharedPref flag "flutter.midnight_clockout_done_<date>"
//      so it SKIPS execution if 10 PM already ran successfully.
//   ✅ Both alarms use separate PendingIntent request codes (2200 / 2201) to
//      coexist without cancelling each other.
//   ✅ cancel() cancels BOTH alarms.
// ═════════════════════════════════════════════════════════════════════════════

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Locale

// ─────────────────────────────────────────────────────────────────────────────
// GpsPolicy
// ─────────────────────────────────────────────────────────────────────────────

data class GpsPolicy(
    val locationIntervalSec: Long,
    val gpsAccuracy: String
)

// ─────────────────────────────────────────────────────────────────────────────
// GpsPolicyManager
// ─────────────────────────────────────────────────────────────────────────────

object GpsPolicyManager {

    private const val TAG        = "GpsPolicyManager"
    private const val POLICY_API = "https://cloud.metaxperts.net:8443/erp/valor_trading/gpstracking/get/"

    private const val PREF_INTERVAL   = "gps_policy_interval_sec"
    private const val PREF_ACCURACY   = "gps_policy_accuracy"
    private const val PREF_FETCHED_AT = "gps_policy_fetched_at"

    private val DEFAULT      = GpsPolicy(locationIntervalSec = 60L, gpsAccuracy = "high")
    private const val CACHE_TTL_SEC = 300L

    fun fetchPolicy(context: Context, forceRefresh: Boolean = false): GpsPolicy {
        val prefs       = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val userId      = prefs.getString("flutter.userId",      "") ?: ""
        val companyCode = prefs.getString("flutter.companyCode", "") ?: ""

        if (userId.isEmpty() || companyCode.isEmpty()) {
            Log.w(TAG, "⚠️ userId/companyCode empty — using cached/default policy")
            return loadCachedPolicy(prefs)
        }

        if (!forceRefresh) {
            val fetchedAt = prefs.getLong(PREF_FETCHED_AT, 0L)
            val ageSec    = System.currentTimeMillis() / 1000L - fetchedAt
            if (ageSec < CACHE_TTL_SEC) {
                val cached = loadCachedPolicy(prefs)
                Log.d(TAG, "📦 Policy cache hit — interval=${cached.locationIntervalSec}s")
                return cached
            }
        }

        return try {
            val url  = java.net.URL("$POLICY_API?company_code=$companyCode&user_id=$userId")
            val conn = url.openConnection() as java.net.HttpURLConnection
            conn.connectTimeout = 10_000
            conn.readTimeout    = 10_000
            conn.requestMethod  = "GET"
            conn.setRequestProperty("Accept", "application/json")

            val code = conn.responseCode
            if (code in 200..299) {
                val body   = conn.inputStream.bufferedReader().readText()
                conn.disconnect()
                val policy = parsePolicy(body)
                savePolicyToPrefs(prefs, policy)
                Log.d(TAG, "✅ Policy fetched — interval=${policy.locationIntervalSec}s accuracy=${policy.gpsAccuracy}")
                policy
            } else {
                conn.disconnect()
                Log.w(TAG, "⚠️ Policy API returned $code — using cache")
                loadCachedPolicy(prefs)
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Policy fetch failed: ${e.message} — using cache")
            loadCachedPolicy(prefs)
        }
    }

    private fun parsePolicy(json: String): GpsPolicy {
        return try {
            val root = JSONObject(json)
            val obj: JSONObject? = when {
                root.has("items") -> {
                    val items = root.getJSONArray("items")
                    if (items.length() > 0) items.getJSONObject(0) else null
                }
                else -> root
            }
            if (obj == null) { Log.w(TAG, "⚠️ Empty policy items — using default"); return DEFAULT }
            GpsPolicy(
                locationIntervalSec = obj.optLong("location_interval_sec", DEFAULT.locationIntervalSec),
                gpsAccuracy         = obj.optString("gps_accuracy", DEFAULT.gpsAccuracy).lowercase()
            )
        } catch (_: Exception) {
            try {
                val arr = JSONArray(json)
                val obj = arr.optJSONObject(0) ?: return DEFAULT
                GpsPolicy(
                    locationIntervalSec = obj.optLong("location_interval_sec", DEFAULT.locationIntervalSec),
                    gpsAccuracy         = obj.optString("gps_accuracy", DEFAULT.gpsAccuracy).lowercase()
                )
            } catch (e2: Exception) {
                Log.e(TAG, "❌ Policy parse error: ${e2.message}")
                DEFAULT
            }
        }
    }

    private fun loadCachedPolicy(prefs: android.content.SharedPreferences): GpsPolicy {
        val interval = prefs.getLong(PREF_INTERVAL, DEFAULT.locationIntervalSec)
        val accuracy = prefs.getString(PREF_ACCURACY, DEFAULT.gpsAccuracy) ?: DEFAULT.gpsAccuracy
        return GpsPolicy(locationIntervalSec = interval, gpsAccuracy = accuracy)
    }

    private fun savePolicyToPrefs(prefs: android.content.SharedPreferences, policy: GpsPolicy) {
        prefs.edit()
            .putLong(PREF_INTERVAL,   policy.locationIntervalSec)
            .putString(PREF_ACCURACY, policy.gpsAccuracy)
            .putLong(PREF_FETCHED_AT, System.currentTimeMillis() / 1000L)
            .apply()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MidnightClockoutReceiver
//
// TWO ALARMS:
//   • 10:00 PM (request code 2200) — PRIMARY, always fires, clock-out runs
//   • 11:00 PM (request code 2201) — BACKUP, fires only if 10 PM was missed
//
// How the "already done" guard works:
//   When 10 PM alarm fires and executes the clock-out, it writes:
//       SharedPref: "flutter.midnight_clockout_done_<YYYY-MM-DD>" = true
//   When 11 PM alarm fires, it first checks that key for today's date.
//   If found → skip (10 PM already clocked them out). If not found → run.
//
// This means:
//   ✅ 10 PM fires normally → user is clocked out → 11 PM wakes up, sees flag, does nothing
//   ✅ Device was off / Doze killed 10 PM alarm → device wakes, 11 PM fires → clocks out
//   ✅ Both alarms are set on every schedule() call (boot, clock-in, reschedule)
// ─────────────────────────────────────────────────────────────────────────────

class MidnightClockoutReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_MIDNIGHT_CLOCKOUT        = "com.metaxperts.order_booking_app.MIDNIGHT_CLOCKOUT"
        const val ACTION_MIDNIGHT_CLOCKOUT_BACKUP = "com.metaxperts.order_booking_app.MIDNIGHT_CLOCKOUT_BACKUP"

        // PendingIntent request codes — must be different so alarms coexist
        private const val REQ_CODE_10PM   = 2200
        private const val REQ_CODE_11PM   = 2201

        private const val TAG = "MidnightClockout"

        // ── Schedule BOTH alarms ────────────────────────────────────────────────
        fun schedule(context: Context) {
            val prefs     = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val clockedIn = prefs.getBoolean("flutter.isClockedIn", false)
            val isFrozen  = prefs.getBoolean("flutter.is_timer_frozen", false)
            if (!clockedIn || isFrozen) return

            scheduleSingleAlarm(
                context  = context,
                action   = ACTION_MIDNIGHT_CLOCKOUT,
                hour     = 22,
                reqCode  = REQ_CODE_10PM,
                label    = "10 PM primary"
            )
            scheduleSingleAlarm(
                context  = context,
                action   = ACTION_MIDNIGHT_CLOCKOUT_BACKUP,
                hour     = 23,
                reqCode  = REQ_CODE_11PM,
                label    = "11 PM backup"
            )
        }

        // ── Cancel BOTH alarms ──────────────────────────────────────────────────
        fun cancel(context: Context) {
            cancelSingleAlarm(context, ACTION_MIDNIGHT_CLOCKOUT,        REQ_CODE_10PM)
            cancelSingleAlarm(context, ACTION_MIDNIGHT_CLOCKOUT_BACKUP, REQ_CODE_11PM)
        }

        // ── Internal helpers ────────────────────────────────────────────────────

        private fun scheduleSingleAlarm(
            context: Context,
            action:  String,
            hour:    Int,
            reqCode: Int,
            label:   String
        ) {
            try {
                val am     = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, MidnightClockoutReceiver::class.java).apply {
                    this.action = action
                }
                val pi = PendingIntent.getBroadcast(
                    context, reqCode, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                val now    = java.util.Calendar.getInstance()
                val target = java.util.Calendar.getInstance().apply {
                    set(java.util.Calendar.HOUR_OF_DAY, hour)
                    set(java.util.Calendar.MINUTE, 0)
                    set(java.util.Calendar.SECOND, 0)
                    set(java.util.Calendar.MILLISECOND, 0)
                }
                // If we're past that hour today, schedule for tomorrow
                if (now.after(target)) target.add(java.util.Calendar.DAY_OF_MONTH, 1)

                when {
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && am.canScheduleExactAlarms() ->
                        am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.timeInMillis, pi)
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.timeInMillis, pi)
                    else ->
                        am.set(AlarmManager.RTC_WAKEUP, target.timeInMillis, pi)
                }
                Log.d(TAG, "✅ Alarm scheduled — $label at ${target.time}")
            } catch (e: Exception) {
                Log.w(TAG, "⚠️ Alarm schedule failed ($label): ${e.message}")
            }
        }

        private fun cancelSingleAlarm(context: Context, action: String, reqCode: Int) {
            try {
                val am     = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, MidnightClockoutReceiver::class.java).apply {
                    this.action = action
                }
                val pi = PendingIntent.getBroadcast(
                    context, reqCode, intent,
                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                )
                pi?.let { am.cancel(it) }
            } catch (_: Exception) {}
        }

        // Key used to mark that today's clockout already ran
        // Format: "flutter.midnight_clockout_done_2025-01-31"
        fun todayDoneKey(): String {
            val date = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(java.util.Date())
            return "flutter.midnight_clockout_done_$date"
        }
    }

    // ── onReceive: handles both PRIMARY (10 PM) and BACKUP (11 PM) ─────────────
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return

        when (action) {
            ACTION_MIDNIGHT_CLOCKOUT -> {
                // 10 PM — PRIMARY. Always attempt clockout if user is still in.
                Log.d(TAG, "🔔 10 PM PRIMARY alarm fired")
                performClockOut(context, isBackup = false)
            }
            ACTION_MIDNIGHT_CLOCKOUT_BACKUP -> {
                // 11 PM — BACKUP. Only run if 10 PM did NOT already clock out.
                Log.d(TAG, "🔔 11 PM BACKUP alarm fired")
                val prefs  = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val done   = prefs.getBoolean(todayDoneKey(), false)
                if (done) {
                    Log.d(TAG, "⏭️ 10 PM already ran today — skipping 11 PM backup")
                    return
                }
                Log.d(TAG, "⚠️ 10 PM was missed — running 11 PM backup clockout")
                performClockOut(context, isBackup = true)
            }
        }
    }

    // ── Core clockout logic (shared between 10 PM and 11 PM) ───────────────────
    private fun performClockOut(context: Context, isBackup: Boolean) {
        val prefs     = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val clockedIn = prefs.getBoolean("flutter.isClockedIn", false)
        val isFrozen  = prefs.getBoolean("flutter.is_timer_frozen", false)

        if (!clockedIn || isFrozen) {
            Log.d(TAG, "⏭️ Not clocked in or frozen — skipping")
            return
        }

        val now       = java.util.Date()
        // For 10 PM alarm → record as 22:00:00 exactly (not current time which may be 22:00:03)
        // For 11 PM backup → record as 22:00:00 of today (still treat it as end-of-day 10 PM)
        val clockoutCal = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, 22)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
            .format(clockoutCal.time)

        val reason  = if (isBackup) "System ClockOut - 10:00 PM (Backup)" else "System ClockOut - 10:00 PM"
        val userId  = prefs.getString("flutter.userId",         "") ?: ""
        val elapsed = prefs.getString("flutter.elapsed_time",   "00:00:00") ?: "00:00:00"
        val clockInT = prefs.getString("flutter.clockInTime",   "") ?: ""

        prefs.edit()
            .putBoolean("flutter.has_critical_event_pending", true)
            .putBoolean("has_critical_event_pending", true)
            .putString("flutter.critical_event_reason", reason)
            .putString("critical_event_reason", reason)
            .putString("flutter.critical_event_timestamp", timestamp)
            .putBoolean("flutter.is_timer_frozen", true)
            .putBoolean("flutter.isClockedIn", false)
            .putBoolean("isClockedIn", false)
            .putString("flutter.fastClockOutTime", timestamp)
            .putFloat("flutter.fastClockOutDistance", 0f)
            .putString("flutter.fastClockOutReason", reason)
            .putBoolean("flutter.hasFastClockOutData", true)
            .putBoolean("flutter.clockOutPending", true)
            .putString("flutter.fastClockOutData",
                """{"fast_attendanceId":"","fast_userId":"$userId","fast_clockOutTime":"$timestamp","fast_totalTime":"$elapsed","fast_totalDistance":0.0,"fast_latOut":0.0,"fast_lngOut":0.0,"fast_address":"","fast_reason":"$reason","fast_savedAt":"${System.currentTimeMillis()}","fast_clockInTime":"$clockInT"}""")
            // ✅ Mark today's clockout as done — prevents 11 PM backup from double-firing
            .putBoolean(todayDoneKey(), true)
            .commit()

        // Stop service + cancel WorkManager
        try { context.stopService(Intent(context, LocationMonitorService::class.java)) } catch (_: Exception) {}
        try { LocationUploadWorker.cancel(context) } catch (_: Exception) {}
        // Cancel the OTHER alarm since we've now clocked out
        cancel(context)

        showMidnightNotification(context, timestamp, isBackup)
        Log.d(TAG, "✅ Clock-out written — isBackup=$isBackup timestamp=$timestamp userId=$userId")
    }

    private fun showMidnightNotification(context: Context, time: String, isBackup: Boolean) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                nm.createNotificationChannel(
                    NotificationChannel(
                        "urgent_auto_clockout_channel",
                        "URGENT Auto Clockout",
                        NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        enableVibration(true)
                        vibrationPattern = longArrayOf(0, 1000, 500, 1000)
                        enableLights(true)
                        lightColor = Color.RED
                    }
                )
            }
            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)?.apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
            val pi = PendingIntent.getActivity(
                context, 0, launchIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            val title = if (isBackup) "⏰ Auto Clock-Out (Backup 11 PM)" else "⏰ Auto Clock-Out at 10:00 PM"
            val body  = if (isBackup)
                "10 PM alarm was missed. Clocked out at 10:00 PM record. Open app to sync."
            else
                "You were automatically clocked out. Open app to sync."

            val n = NotificationCompat.Builder(context, "urgent_auto_clockout_channel")
                .setContentTitle(title)
                .setContentText(body)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setAutoCancel(true)
                .setContentIntent(pi)
                .setVibrate(longArrayOf(0, 1000, 500, 1000))
                .build()
            nm.notify(9997, n)
        } catch (_: Exception) {}
    }
}