package com.metaxperts.order_booking_app

// ═════════════════════════════════════════════════════════════════════════════
// BulkPostingScheduler.kt — REDESIGNED
//
// What's LEFT here (kept because needed elsewhere):
//   ✅ GpsPolicy data class
//   ✅ GpsPolicyManager (fetches interval + accuracy from server)
//   ✅ MidnightClockoutReceiver (exact 10 PM alarm — AlarmManager needed here)
//
// What's REMOVED:
//   ❌ BulkPostingScheduler class (replaced by LocationUploadWorker)
//   ❌ BulkPostAlarmReceiver class (replaced by LocationUploadWorker)
//   ❌ Heartbeat alarm (replaced by WorkManager periodic)
//   ❌ ServiceRestartAlarm (replaced by WorkManager + START_STICKY)
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
// GpsPolicy — interval and accuracy settings from server
// ─────────────────────────────────────────────────────────────────────────────

data class GpsPolicy(
    val locationIntervalSec: Long,
    val gpsAccuracy: String
)

// ─────────────────────────────────────────────────────────────────────────────
// GpsPolicyManager — fetches/caches GPS policy from backend API
// ─────────────────────────────────────────────────────────────────────────────

object GpsPolicyManager {

    private const val TAG        = "GpsPolicyManager"
    private const val POLICY_API = "https://cloud.metaxperts.net:8443/erp/valor_trading/gpstracking/get/"

    private const val PREF_INTERVAL   = "gps_policy_interval_sec"
    private const val PREF_ACCURACY   = "gps_policy_accuracy"
    private const val PREF_FETCHED_AT = "gps_policy_fetched_at"

    private val DEFAULT      = GpsPolicy(locationIntervalSec = 60L, gpsAccuracy = "high")
    private const val CACHE_TTL_SEC = 300L  // 5 minutes

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
// Uses AlarmManager (exact, RTC_WAKEUP) because it needs to fire at a specific
// wall-clock time (10 PM). WorkManager cannot guarantee exact wall-clock time.
// ─────────────────────────────────────────────────────────────────────────────

class MidnightClockoutReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_MIDNIGHT_CLOCKOUT = "com.metaxperts.order_booking_app.MIDNIGHT_CLOCKOUT"

        fun schedule(context: Context) {
            val prefs     = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val clockedIn = prefs.getBoolean("flutter.isClockedIn", false)
            val isFrozen  = prefs.getBoolean("flutter.is_timer_frozen", false)
            if (!clockedIn || isFrozen) return

            val am     = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, MidnightClockoutReceiver::class.java).apply {
                action = ACTION_MIDNIGHT_CLOCKOUT
            }
            val pi = PendingIntent.getBroadcast(context, 2200, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

            val now    = java.util.Calendar.getInstance()
            val target = java.util.Calendar.getInstance().apply {
                set(java.util.Calendar.HOUR_OF_DAY, 22)
                set(java.util.Calendar.MINUTE, 0)
                set(java.util.Calendar.SECOND, 0)
                set(java.util.Calendar.MILLISECOND, 0)
            }
            if (now.after(target)) target.add(java.util.Calendar.DAY_OF_MONTH, 1)

            try {
                when {
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && am.canScheduleExactAlarms() ->
                        am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.timeInMillis, pi)
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.timeInMillis, pi)
                    else ->
                        am.set(AlarmManager.RTC_WAKEUP, target.timeInMillis, pi)
                }
                Log.d("MidnightClockout", "✅ Alarm scheduled for ${target.time}")
            } catch (e: Exception) {
                Log.d("MidnightClockout", "⚠️ Alarm schedule failed: ${e.message}")
            }
        }

        fun cancel(context: Context) {
            try {
                val am     = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, MidnightClockoutReceiver::class.java).apply {
                    action = ACTION_MIDNIGHT_CLOCKOUT
                }
                val pi = PendingIntent.getBroadcast(context, 2200, intent,
                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
                pi?.let { am.cancel(it) }
            } catch (_: Exception) {}
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_MIDNIGHT_CLOCKOUT) return

        val prefs     = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val clockedIn = prefs.getBoolean("flutter.isClockedIn", false)
        val isFrozen  = prefs.getBoolean("flutter.is_timer_frozen", false)
        if (!clockedIn || isFrozen) return

        val now       = java.util.Date()
        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(now)
        val reason    = "System ClockOut - 10:00 PM"
        val userId    = prefs.getString("flutter.userId",   "") ?: ""
        val elapsed   = prefs.getString("flutter.elapsed_time", "00:00:00") ?: "00:00:00"
        val clockInT  = prefs.getString("flutter.clockInTime",  "") ?: ""

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
            .commit()

        // Stop service + cancel WorkManager
        try { context.stopService(Intent(context, LocationMonitorService::class.java)) } catch (_: Exception) {}
        try { LocationUploadWorker.cancel(context) } catch (_: Exception) {}

        showMidnightNotification(context, timestamp)
    }

    private fun showMidnightNotification(context: Context, time: String) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                nm.createNotificationChannel(
                    NotificationChannel("urgent_auto_clockout_channel", "URGENT Auto Clockout",
                        NotificationManager.IMPORTANCE_HIGH).apply {
                        enableVibration(true)
                        vibrationPattern = longArrayOf(0, 1000, 500, 1000)
                        enableLights(true)
                        lightColor = Color.RED
                    }
                )
            }
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pi = PendingIntent.getActivity(context, 0, launchIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            val n = NotificationCompat.Builder(context, "urgent_auto_clockout_channel")
                .setContentTitle("⏰ Auto Clock-Out at 10:00 PM")
                .setContentText("You were automatically clocked out. Open app to sync.")
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