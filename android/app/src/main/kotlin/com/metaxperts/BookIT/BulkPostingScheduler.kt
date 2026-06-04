package com.metaxperts.order_booking_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

// ─── GPS Policy ───────────────────────────────────────────────────────────────

data class GpsPolicy(
    val locationIntervalSec: Long,
    val gpsAccuracy: String
)

object GpsPolicyManager {

    private const val TAG = "GpsPolicyManager"
    private const val POLICY_API =
        "https://cloud.metaxperts.net:8443/erp/valor_trading/gpstracking/get/"

    private const val PREF_INTERVAL   = "gps_policy_interval_sec"
    private const val PREF_ACCURACY   = "gps_policy_accuracy"
    private const val PREF_FETCHED_AT = "gps_policy_fetched_at"

    private val DEFAULT = GpsPolicy(locationIntervalSec = 60L, gpsAccuracy = "high")
    private const val CACHE_TTL_SEC = 300L

    fun fetchPolicy(context: Context, forceRefresh: Boolean = false): GpsPolicy {
        val prefs       = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val userId      = prefs.getString("flutter.userId", "") ?: ""
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
            val url  = URL("$POLICY_API?company_code=$companyCode&user_id=$userId")
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout = 10_000
            conn.readTimeout    = 10_000
            conn.requestMethod  = "GET"
            conn.setRequestProperty("Accept", "application/json")

            val responseCode = conn.responseCode
            if (responseCode in 200..299) {
                val body   = conn.inputStream.bufferedReader().readText()
                conn.disconnect()
                val policy = parsePolicy(body)
                savePolicyToPrefs(prefs, policy)
                Log.d(TAG, "✅ Policy fetched — interval=${policy.locationIntervalSec}s")
                policy
            } else {
                conn.disconnect()
                Log.w(TAG, "⚠️ Policy API returned $responseCode — using cache")
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

            if (obj == null) {
                Log.w(TAG, "⚠️ Policy: empty items array — using default")
                return DEFAULT
            }

            val rawAccuracy = obj.optString("gps_accuracy", DEFAULT.gpsAccuracy).lowercase()

            GpsPolicy(
                locationIntervalSec = obj.optLong("location_interval_sec", DEFAULT.locationIntervalSec),
                gpsAccuracy         = rawAccuracy
            ).also {
                Log.d(TAG, "✅ Parsed policy: interval=${it.locationIntervalSec}s accuracy=${it.gpsAccuracy}")
            }
        } catch (e: Exception) {
            return try {
                val arr = JSONArray(json)
                val obj = arr.optJSONObject(0) ?: return DEFAULT
                val rawAccuracy = obj.optString("gps_accuracy", DEFAULT.gpsAccuracy).lowercase()
                GpsPolicy(
                    locationIntervalSec = obj.optLong("location_interval_sec", DEFAULT.locationIntervalSec),
                    gpsAccuracy         = rawAccuracy
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
            .putLong(PREF_INTERVAL, policy.locationIntervalSec)
            .putString(PREF_ACCURACY, policy.gpsAccuracy)
            .putLong(PREF_FETCHED_AT, System.currentTimeMillis() / 1000L)
            .apply()
    }
}

// ─── BulkPostingScheduler ─────────────────────────────────────────────────────

class BulkPostingScheduler {

    companion object {
        private const val TAG                = "BulkPostingScheduler"
        private const val ALARM_REQUEST_CODE = 9999
        private const val HEARTBEAT_REQUEST_CODE = 888

        private const val PREF_ALARM_ANCHOR = "bulk_alarm_anchor_elapsed"

        // ✅ FIX: Heartbeat reduced from 5 min → 2 min so service restarts within 2 min of kill
        private const val HEARTBEAT_INTERVAL_MS = 2 * 60_000L

        fun startBulkPostingAlarm(context: Context, resetAnchor: Boolean = false) {
            val policy     = GpsPolicyManager.fetchPolicy(context, forceRefresh = false)
            val intervalMs = policy.locationIntervalSec * 1000L

            Log.d(TAG, "🚀 Scheduling bulk alarm — interval=${policy.locationIntervalSec}s resetAnchor=$resetAnchor")

            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val now   = SystemClock.elapsedRealtime()

            var anchorElapsed = if (resetAnchor) 0L else prefs.getLong(PREF_ALARM_ANCHOR, 0L)

            if (anchorElapsed == 0L) {
                anchorElapsed = now
                prefs.edit().putLong(PREF_ALARM_ANCHOR, anchorElapsed).apply()
                Log.d(TAG, "⚓ [Alarm] Anchor set at elapsed=$anchorElapsed (resetAnchor=$resetAnchor)")
            }

            val elapsed    = now - anchorElapsed
            val nextOffset = intervalMs - (elapsed % intervalMs)
            val triggerAt  = now + nextOffset

            Log.d(TAG, "⏱️ [Alarm] elapsed=${elapsed}ms nextOffset=${nextOffset}ms → fires in ${nextOffset / 1000}s")

            val alarmManager  = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent        = Intent(context, BulkPostAlarmReceiver::class.java)
            val pendingIntent  = PendingIntent.getBroadcast(
                context,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            try {
                when {
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && alarmManager.canScheduleExactAlarms() -> {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
                            triggerAt,
                            pendingIntent
                        )
                        Log.d(TAG, "✅ setExactAndAllowWhileIdle (API 31+) — fires in ${nextOffset / 1000}s")
                    }
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
                            triggerAt,
                            pendingIntent
                        )
                        Log.d(TAG, "✅ setExactAndAllowWhileIdle (API 23+) — fires in ${nextOffset / 1000}s")
                    }
                    else -> {
                        alarmManager.setRepeating(
                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
                            triggerAt,
                            intervalMs,
                            pendingIntent
                        )
                        Log.d(TAG, "✅ setRepeating (API < 23) — interval=${intervalMs}ms")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to schedule alarm: ${e.message}")
            }

            // ✅ FIX: 2-minute Doze-proof heartbeat (was 5 min — too slow after app kill)
            scheduleDozeProofHeartbeat(context)
        }

        fun stopBulkPostingAlarm(context: Context) {
            val alarmManager  = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent        = Intent(context, BulkPostAlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)

            val heartbeatIntent = Intent(context, BulkPostAlarmReceiver::class.java)
            val heartbeatPi = PendingIntent.getBroadcast(
                context,
                HEARTBEAT_REQUEST_CODE,
                heartbeatIntent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            heartbeatPi?.let { alarmManager.cancel(it) }

            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().remove(PREF_ALARM_ANCHOR).apply()

            Log.d(TAG, "🛑 Bulk posting alarm stopped — anchor cleared")
        }

        // ✅ FIX: Heartbeat is now 2 minutes instead of 5 minutes.
        // After app kill, the heartbeat fires in ≤2 min and restarts the service.
        private fun scheduleDozeProofHeartbeat(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, BulkPostAlarmReceiver::class.java).apply {
                putExtra("heartbeat", true)
            }
            val pi = PendingIntent.getBroadcast(
                context, HEARTBEAT_REQUEST_CODE, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val triggerAt = SystemClock.elapsedRealtime() + HEARTBEAT_INTERVAL_MS

            try {
                when {
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && am.canScheduleExactAlarms() ->
                        am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                        am.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
                    else ->
                        am.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
                }
                Log.d(TAG, "✅ [DozeProof] Heartbeat alarm scheduled for ${HEARTBEAT_INTERVAL_MS / 60_000}min")
            } catch (e: Exception) {
                Log.w(TAG, "⚠️ [DozeProof] Heartbeat alarm failed: ${e.message}")
            }
        }
    }
}

// ─── BulkPostAlarmReceiver ────────────────────────────────────────────────────

class BulkPostAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val fireTime    = SystemClock.elapsedRealtime()
        val isHeartbeat = intent.getBooleanExtra("heartbeat", false)

        if (isHeartbeat) {
            Log.d("BulkPostAlarm", "💓 [Heartbeat] Alarm fired — checking service status")

            val prefs       = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
            val isFrozen    = prefs.getBoolean("flutter.is_timer_frozen", false)

            // ✅ FIX: Heartbeat now also restarts the service if it died while user is clocked in
            if (isClockedIn && !isFrozen && !LocationMonitorService.isRunning) {
                Log.d("BulkPostAlarm", "💓 [Heartbeat] Service is dead — restarting from heartbeat alarm")
                val userId = prefs.getString("flutter.userId", "") ?: ""
                if (userId.isNotEmpty()) {
                    try {
                        LocationMonitorService.start(
                            context     = context,
                            userId      = userId,
                            bookerName  = prefs.getString("flutter.userName", "") ?: "",
                            designation = prefs.getString("flutter.userDesignation", "") ?: "",
                            companyCode = prefs.getString("flutter.companyCode", "") ?: ""
                        )
                        Log.d("BulkPostAlarm", "✅ [Heartbeat] Service restart triggered for userId=$userId")
                    } catch (e: Exception) {
                        Log.e("BulkPostAlarm", "❌ [Heartbeat] Service restart failed: ${e.message}")
                    }
                } else {
                    Log.w("BulkPostAlarm", "⚠️ [Heartbeat] userId empty — cannot restart service")
                }
            } else {
                Log.d("BulkPostAlarm", "💓 [Heartbeat] Service is running (${LocationMonitorService.isRunning}) — no restart needed")
            }

            // Reschedule heartbeat
            BulkPostingScheduler.startBulkPostingAlarm(context, resetAnchor = false)
            return
        }

        Log.d("BulkPostAlarm", "⏰ Alarm fired at elapsed=$fireTime")

        // Reschedule next alarm — anchor preserve karo
        BulkPostingScheduler.startBulkPostingAlarm(context, resetAnchor = false)

        // Do work on background thread
        Thread {
            try {
                val prefs       = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
                val isFrozen    = prefs.getBoolean("flutter.is_timer_frozen", false)

                if (isClockedIn && !isFrozen) {

                    // ✅ FIX: Agar service nahi chal rahi to restart karo + sync karo
                    if (!LocationMonitorService.isRunning) {
                        Log.d("BulkPostAlarm", "🔄 Service NOT running — attempting restart from alarm")
                        val userId = prefs.getString("flutter.userId", "") ?: ""
                        if (userId.isNotEmpty()) {
                            try {
                                LocationMonitorService.start(
                                    context     = context,
                                    userId      = userId,
                                    bookerName  = prefs.getString("flutter.userName", "") ?: "",
                                    designation = prefs.getString("flutter.userDesignation", "") ?: "",
                                    companyCode = prefs.getString("flutter.companyCode", "") ?: ""
                                )
                                Log.d("BulkPostAlarm", "✅ Service restart triggered from main alarm")
                            } catch (e: Exception) {
                                Log.e("BulkPostAlarm", "❌ Service restart failed: ${e.message}")
                            }
                        } else {
                            Log.w("BulkPostAlarm", "⚠️ userId empty in prefs — cannot restart service")
                        }

                        // Also sync any unposted rows as fallback
                        val dbHelper = NativeDBHelper(context)
                        val unposted = dbHelper.getUnpostedRows()
                        if (unposted.isNotEmpty()) {
                            Log.d("BulkPostAlarm", "📤 Fallback sync: ${unposted.size} unposted rows")
                            syncUnpostedRows(context, dbHelper, unposted)
                        }
                    } else {
                        // Service is running — it handles its own sync
                        Log.d("BulkPostAlarm", "⏭️ Service is running — skipping alarm sync (double posting prevention)")
                    }
                } else {
                    Log.d("BulkPostAlarm", "⏸️ Not clocked in or frozen — skip sync")
                }

            } catch (e: Exception) {
                Log.e("BulkPostAlarm", "❌ Error: ${e.message}")
            }
        }.start()
    }

    private fun syncUnpostedRows(context: Context, dbHelper: NativeDBHelper, unposted: List<Map<String, String>>) {
        val BULK_API = "http://119.153.102.7:8001/location/bulk"

        try {
            val records = JSONArray()
            for (row in unposted) {
                records.put(JSONObject().apply {
                    put("locationtracking_date", row["locationtracking_date"] ?: "")
                    put("locationtracking_time", row["locationtracking_time"] ?: "")
                    put("user_id",       row["user_id"]       ?: "")
                    put("company_code",  row["company_code"]  ?: "")
                    put("lat_in",        (row["lat_in"]  ?: "0").toDoubleOrNull() ?: 0.0)
                    put("lng_in",        (row["lng_in"]  ?: "0").toDoubleOrNull() ?: 0.0)
                    put("booker_name",   row["booker_name"]   ?: "")
                    put("designation",   row["designation"]   ?: "")
                    put("posted", false)
                })
            }

            val body = JSONObject().put("records", records).toString()
            val url  = URL(BULK_API)
            val conn = url.openConnection() as HttpURLConnection
            conn.apply {
                requestMethod  = "POST"
                connectTimeout = 15_000
                readTimeout    = 30_000
                doOutput       = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Accept",       "application/json")
            }

            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(body) }

            val responseCode = conn.responseCode
            conn.disconnect()

            if (responseCode in 200..299) {
                val ids = unposted.mapNotNull { it["locationtracking_id"] }
                dbHelper.markPosted(ids)
                Log.d("BulkPostAlarm", "✅ Bulk POST OK — marked ${ids.size} rows posted")
            } else {
                Log.d("BulkPostAlarm", "⚠️ Bulk POST failed ($responseCode)")
            }
        } catch (e: Exception) {
            Log.e("BulkPostAlarm", "❌ Bulk POST exception: ${e.message}")
        }
    }
}