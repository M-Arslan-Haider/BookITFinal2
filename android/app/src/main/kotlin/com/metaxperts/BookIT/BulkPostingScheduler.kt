//////
//////
//////package com.metaxperts.order_booking_app
//////
//////import android.app.AlarmManager
//////import android.app.PendingIntent
//////import android.content.BroadcastReceiver
//////import android.content.Context
//////import android.content.Intent
//////import android.os.Build
//////import android.os.SystemClock
//////import android.util.Log
//////import org.json.JSONArray
//////import org.json.JSONObject
//////import java.io.OutputStreamWriter
//////import java.net.HttpURLConnection
//////import java.net.URL
//////
//////// ─── GPS Policy ───────────────────────────────────────────────────────────────
//////
//////data class GpsPolicy(
//////    val locationIntervalSec: Long,
//////    val gpsAccuracy: String
//////)
//////
//////object GpsPolicyManager {
//////
//////    private const val TAG = "GpsPolicyManager"
//////    private const val POLICY_API =
//////        "https://cloud.metaxperts.net:8443/erp/valor_trading/gpstracking/get/"
//////
//////    private const val PREF_INTERVAL   = "gps_policy_interval_sec"
//////    private const val PREF_ACCURACY   = "gps_policy_accuracy"
//////    private const val PREF_FETCHED_AT = "gps_policy_fetched_at"
//////
//////    private val DEFAULT = GpsPolicy(locationIntervalSec = 60L, gpsAccuracy = "high")
//////    private const val CACHE_TTL_SEC = 300L
//////
//////    fun fetchPolicy(context: Context, forceRefresh: Boolean = false): GpsPolicy {
//////        val prefs       = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
//////        val userId      = prefs.getString("flutter.userId", "") ?: ""
//////        val companyCode = prefs.getString("flutter.companyCode", "") ?: ""
//////
//////        if (userId.isEmpty() || companyCode.isEmpty()) {
//////            Log.w(TAG, "⚠️ userId/companyCode empty — using cached/default policy")
//////            return loadCachedPolicy(prefs)
//////        }
//////
//////        if (!forceRefresh) {
//////            val fetchedAt = prefs.getLong(PREF_FETCHED_AT, 0L)
//////            val ageSec    = System.currentTimeMillis() / 1000L - fetchedAt
//////            if (ageSec < CACHE_TTL_SEC) {
//////                val cached = loadCachedPolicy(prefs)
//////                Log.d(TAG, "📦 Policy cache hit — interval=${cached.locationIntervalSec}s")
//////                return cached
//////            }
//////        }
//////
//////        return try {
//////            val url  = URL("$POLICY_API?company_code=$companyCode&user_id=$userId")
//////            val conn = url.openConnection() as HttpURLConnection
//////            conn.connectTimeout = 10_000
//////            conn.readTimeout    = 10_000
//////            conn.requestMethod  = "GET"
//////            conn.setRequestProperty("Accept", "application/json")
//////
//////            val responseCode = conn.responseCode
//////            if (responseCode in 200..299) {
//////                val body   = conn.inputStream.bufferedReader().readText()
//////                conn.disconnect()
//////                val policy = parsePolicy(body)
//////                savePolicyToPrefs(prefs, policy)
//////                Log.d(TAG, "✅ Policy fetched — interval=${policy.locationIntervalSec}s")
//////                policy
//////            } else {
//////                conn.disconnect()
//////                Log.w(TAG, "⚠️ Policy API returned $responseCode — using cache")
//////                loadCachedPolicy(prefs)
//////            }
//////        } catch (e: Exception) {
//////            Log.e(TAG, "❌ Policy fetch failed: ${e.message} — using cache")
//////            loadCachedPolicy(prefs)
//////        }
//////    }
//////
//////    private fun parsePolicy(json: String): GpsPolicy {
//////        return try {
//////            // ✅ FIX: API response {"items":[{...}],...} handle karo
//////            // Pehle "items" key check karo, phir plain array, phir plain object
//////            val root = JSONObject(json)
//////            val obj: JSONObject? = when {
//////                root.has("items") -> {
//////                    val items = root.getJSONArray("items")
//////                    if (items.length() > 0) items.getJSONObject(0) else null
//////                }
//////                else -> root
//////            }
//////
//////            if (obj == null) {
//////                Log.w(TAG, "⚠️ Policy: empty items array — using default")
//////                return DEFAULT
//////            }
//////
//////            // ✅ gps_accuracy case-insensitive: API "HIGH" → lowercase karo
//////            val rawAccuracy = obj.optString("gps_accuracy", DEFAULT.gpsAccuracy).lowercase()
//////
//////            GpsPolicy(
//////                locationIntervalSec = obj.optLong("location_interval_sec", DEFAULT.locationIntervalSec),
//////                gpsAccuracy         = rawAccuracy
//////            ).also {
//////                Log.d(TAG, "✅ Parsed policy: interval=${it.locationIntervalSec}s accuracy=${it.gpsAccuracy}")
//////            }
//////        } catch (e: Exception) {
//////            // Fallback: plain array format try karo
//////            return try {
//////                val arr = JSONArray(json)
//////                val obj = arr.optJSONObject(0) ?: return DEFAULT
//////                val rawAccuracy = obj.optString("gps_accuracy", DEFAULT.gpsAccuracy).lowercase()
//////                GpsPolicy(
//////                    locationIntervalSec = obj.optLong("location_interval_sec", DEFAULT.locationIntervalSec),
//////                    gpsAccuracy         = rawAccuracy
//////                )
//////            } catch (e2: Exception) {
//////                Log.e(TAG, "❌ Policy parse error: ${e2.message}")
//////                DEFAULT
//////            }
//////        }
//////    }
//////
//////    private fun loadCachedPolicy(prefs: android.content.SharedPreferences): GpsPolicy {
//////        val interval = prefs.getLong(PREF_INTERVAL, DEFAULT.locationIntervalSec)
//////        val accuracy = prefs.getString(PREF_ACCURACY, DEFAULT.gpsAccuracy) ?: DEFAULT.gpsAccuracy
//////        return GpsPolicy(locationIntervalSec = interval, gpsAccuracy = accuracy)
//////    }
//////
//////    private fun savePolicyToPrefs(prefs: android.content.SharedPreferences, policy: GpsPolicy) {
//////        prefs.edit()
//////            .putLong(PREF_INTERVAL, policy.locationIntervalSec)
//////            .putString(PREF_ACCURACY, policy.gpsAccuracy)
//////            .putLong(PREF_FETCHED_AT, System.currentTimeMillis() / 1000L)
//////            .apply()
//////    }
//////}
//////
//////// ─── BulkPostingScheduler ─────────────────────────────────────────────────────
//////
//////class BulkPostingScheduler {
//////
//////    companion object {
//////        private const val TAG              = "BulkPostingScheduler"
//////        private const val ALARM_REQUEST_CODE = 9999
//////
//////        // ✅ KEY FIX: Alarm ka anchor time SharedPreferences mein store karo
//////        // Taake har reschedule "drift" nahi kare balke original anchor se
//////        // exact multiples par fire ho
//////        private const val PREF_ALARM_ANCHOR = "bulk_alarm_anchor_elapsed"
//////
//////        /**
//////         * Pehli baar alarm set karna — anchor time save karo.
//////         * Dobara call karne par (reschedule) anchor se compute karo.
//////         */
//////        fun startBulkPostingAlarm(context: Context) {
//////            // ─── STEP 1: Policy fetch — yeh CACHED se hona chahiye ────────────
//////            // Network call mat karo blocking thread pe — sirf cache use karo
//////            // Policy refresh alag loop handle karta hai (GpsPolicyManager cache TTL 5 min)
//////            val policy     = GpsPolicyManager.fetchPolicy(context, forceRefresh = false)
//////            val intervalMs = policy.locationIntervalSec * 1000L
//////
//////            Log.d(TAG, "🚀 Scheduling bulk alarm — interval=${policy.locationIntervalSec}s")
//////
//////            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
//////
//////            // ─── STEP 2: Anchor time set karo (sirf pehli baar) ──────────────
//////            // Agar anchor already set hai toh use karo — drift avoid karne ke liye
//////            val now          = SystemClock.elapsedRealtime()
//////            var anchorElapsed = prefs.getLong(PREF_ALARM_ANCHOR, 0L)
//////
//////            if (anchorElapsed == 0L) {
//////                // Pehli baar — anchor abhi set karo
//////                anchorElapsed = now
//////                prefs.edit().putLong(PREF_ALARM_ANCHOR, anchorElapsed).apply()
//////                Log.d(TAG, "⚓ [Alarm] Anchor set at elapsed=$anchorElapsed")
//////            }
//////
//////            // ─── STEP 3: Next fire time exactly intervalMs ke multiple se ────
//////            // Anchor se count karo: kitne intervals guzar chuke hain?
//////            val elapsed     = now - anchorElapsed
//////            val nextOffset  = intervalMs - (elapsed % intervalMs)
//////            val triggerAt   = now + nextOffset
//////
//////            Log.d(TAG, "⏱️ [Alarm] elapsed=${elapsed}ms nextOffset=${nextOffset}ms → triggerAt in ${nextOffset/1000}s")
//////
//////            // ─── STEP 4: Exact alarm set karo ────────────────────────────────
//////            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
//////            val intent       = Intent(context, BulkPostAlarmReceiver::class.java)
//////            val pendingIntent = PendingIntent.getBroadcast(
//////                context,
//////                ALARM_REQUEST_CODE,
//////                intent,
//////                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
//////            )
//////
//////            try { alarmManager.cancel(pendingIntent) } catch (_: Exception) {}
//////
//////            when {
//////                // Android 12+ — SCHEDULE_EXACT_ALARM permission check
//////                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
//////                    if (alarmManager.canScheduleExactAlarms()) {
//////                        alarmManager.setExactAndAllowWhileIdle(
//////                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
//////                            triggerAt,
//////                            pendingIntent
//////                        )
//////                        Log.d(TAG, "✅ setExactAndAllowWhileIdle (API 31+) — fires in ${nextOffset/1000}s")
//////                    } else {
//////                        // Fallback — setAndAllowWhileIdle (Doze pe bhi chalega, ~1-3 min accuracy)
//////                        alarmManager.setAndAllowWhileIdle(
//////                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
//////                            triggerAt,
//////                            pendingIntent
//////                        )
//////                        Log.w(TAG, "⚠️ canScheduleExactAlarms=false — using setAndAllowWhileIdle")
//////                    }
//////                }
//////                // Android 6-11 — setExactAndAllowWhileIdle available
//////                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
//////                    alarmManager.setExactAndAllowWhileIdle(
//////                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
//////                        triggerAt,
//////                        pendingIntent
//////                    )
//////                    Log.d(TAG, "✅ setExactAndAllowWhileIdle (API 23+) — fires in ${nextOffset/1000}s")
//////                }
//////                // Android < 6 — setRepeating exact nahi hai, lekin acceptable
//////                else -> {
//////                    alarmManager.setRepeating(
//////                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
//////                        triggerAt,
//////                        intervalMs,
//////                        pendingIntent
//////                    )
//////                    Log.d(TAG, "✅ setRepeating (API < 23) — interval=${intervalMs}ms")
//////                }
//////            }
//////        }
//////
//////        fun stopBulkPostingAlarm(context: Context) {
//////            val alarmManager  = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
//////            val intent        = Intent(context, BulkPostAlarmReceiver::class.java)
//////            val pendingIntent = PendingIntent.getBroadcast(
//////                context,
//////                ALARM_REQUEST_CODE,
//////                intent,
//////                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
//////            )
//////            alarmManager.cancel(pendingIntent)
//////
//////            // ✅ Anchor reset karo taake agley clockin par fresh start ho
//////            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
//////            prefs.edit().remove(PREF_ALARM_ANCHOR).apply()
//////
//////            Log.d(TAG, "🛑 Bulk posting alarm stopped — anchor cleared")
//////        }
//////    }
//////}
//////
//////// ─── BulkPostAlarmReceiver ────────────────────────────────────────────────────
//////
//////class BulkPostAlarmReceiver : BroadcastReceiver() {
//////    override fun onReceive(context: Context, intent: Intent) {
//////        val fireTime = SystemClock.elapsedRealtime()
//////        Log.d("BulkPostAlarm", "⏰ Alarm fired at elapsed=$fireTime")
//////
//////        // ✅ KEY FIX: Immediately reschedule PEHLE karo — kaam baad mein
//////        // Is se agla alarm exactly intervalMs baad fire hoga regardless of how long the work takes
//////        BulkPostingScheduler.startBulkPostingAlarm(context)
//////
//////        // Ab kaam karo background thread pe
//////        Thread {
//////            try {
//////                val prefs       = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
//////                val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
//////                val isFrozen    = prefs.getBoolean("flutter.is_timer_frozen", false)
//////
//////                if (isClockedIn && !isFrozen) {
//////                    val dbHelper = NativeDBHelper(context)
//////                    val unposted = dbHelper.getUnpostedRows()
//////
//////                    if (unposted.isNotEmpty()) {
//////                        Log.d("BulkPostAlarm", "📤 Found ${unposted.size} unposted rows — syncing...")
//////                        syncUnpostedRows(context, dbHelper, unposted)
//////                    } else {
//////                        Log.d("BulkPostAlarm", "✅ No unposted rows")
//////                    }
//////                } else {
//////                    Log.d("BulkPostAlarm", "⏸️ Not clocked in or frozen — skip sync")
//////                }
//////
//////            } catch (e: Exception) {
//////                Log.e("BulkPostAlarm", "❌ Error: ${e.message}")
//////            }
//////        }.start()
//////    }
//////
//////    private fun syncUnpostedRows(context: Context, dbHelper: NativeDBHelper, unposted: List<Map<String, String>>) {
//////        val BULK_API = "http://119.153.102.7:8001/location/bulk"
//////
//////        try {
//////            val records = JSONArray()
//////            for (row in unposted) {
//////                records.put(JSONObject().apply {
//////                    put("locationtracking_date", row["locationtracking_date"] ?: "")
//////                    put("locationtracking_time", row["locationtracking_time"] ?: "")
//////                    put("user_id",       row["user_id"]       ?: "")
//////                    put("company_code",  row["company_code"]  ?: "")
//////                    put("lat_in",        (row["lat_in"]  ?: "0").toDoubleOrNull() ?: 0.0)
//////                    put("lng_in",        (row["lng_in"]  ?: "0").toDoubleOrNull() ?: 0.0)
//////                    put("booker_name",   row["booker_name"]   ?: "")
//////                    put("designation",   row["designation"]   ?: "")
//////                    put("posted", false)
//////                })
//////            }
//////
//////            val body = JSONObject().put("records", records).toString()
//////            val url  = URL(BULK_API)
//////            val conn = url.openConnection() as HttpURLConnection
//////            conn.apply {
//////                requestMethod  = "POST"
//////                connectTimeout = 15_000
//////                readTimeout    = 30_000
//////                doOutput       = true
//////                setRequestProperty("Content-Type", "application/json")
//////                setRequestProperty("Accept",       "application/json")
//////            }
//////
//////            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(body) }
//////
//////            val responseCode = conn.responseCode
//////            conn.disconnect()
//////
//////            if (responseCode in 200..299) {
//////                val ids = unposted.mapNotNull { it["locationtracking_id"] }
//////                dbHelper.markPosted(ids)
//////                Log.d("BulkPostAlarm", "✅ Bulk POST OK — marked ${ids.size} rows posted")
//////            } else {
//////                Log.d("BulkPostAlarm", "⚠️ Bulk POST failed ($responseCode)")
//////            }
//////        } catch (e: Exception) {
//////            Log.e("BulkPostAlarm", "❌ Bulk POST exception: ${e.message}")
//////        }
//////    }
//////}
////
////package com.metaxperts.order_booking_app
////
////import android.app.AlarmManager
////import android.app.PendingIntent
////import android.content.BroadcastReceiver
////import android.content.Context
////import android.content.Intent
////import android.os.Build
////import android.os.SystemClock
////import android.util.Log
////import org.json.JSONArray
////import org.json.JSONObject
////import java.io.OutputStreamWriter
////import java.net.HttpURLConnection
////import java.net.URL
////
////// ─── GPS Policy ───────────────────────────────────────────────────────────────
////
////data class GpsPolicy(
////    val locationIntervalSec: Long,
////    val gpsAccuracy: String
////)
////
////object GpsPolicyManager {
////
////    private const val TAG = "GpsPolicyManager"
////    private const val POLICY_API =
////        "https://cloud.metaxperts.net:8443/erp/valor_trading/gpstracking/get/"
////
////    private const val PREF_INTERVAL   = "gps_policy_interval_sec"
////    private const val PREF_ACCURACY   = "gps_policy_accuracy"
////    private const val PREF_FETCHED_AT = "gps_policy_fetched_at"
////
////    private val DEFAULT = GpsPolicy(locationIntervalSec = 60L, gpsAccuracy = "high")
////    private const val CACHE_TTL_SEC = 300L
////
////    fun fetchPolicy(context: Context, forceRefresh: Boolean = false): GpsPolicy {
////        val prefs       = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
////        val userId      = prefs.getString("flutter.userId", "") ?: ""
////        val companyCode = prefs.getString("flutter.companyCode", "") ?: ""
////
////        if (userId.isEmpty() || companyCode.isEmpty()) {
////            Log.w(TAG, "⚠️ userId/companyCode empty — using cached/default policy")
////            return loadCachedPolicy(prefs)
////        }
////
////        if (!forceRefresh) {
////            val fetchedAt = prefs.getLong(PREF_FETCHED_AT, 0L)
////            val ageSec    = System.currentTimeMillis() / 1000L - fetchedAt
////            if (ageSec < CACHE_TTL_SEC) {
////                val cached = loadCachedPolicy(prefs)
////                Log.d(TAG, "📦 Policy cache hit — interval=${cached.locationIntervalSec}s")
////                return cached
////            }
////        }
////
////        return try {
////            val url  = URL("$POLICY_API?company_code=$companyCode&user_id=$userId")
////            val conn = url.openConnection() as HttpURLConnection
////            conn.connectTimeout = 10_000
////            conn.readTimeout    = 10_000
////            conn.requestMethod  = "GET"
////            conn.setRequestProperty("Accept", "application/json")
////
////            val responseCode = conn.responseCode
////            if (responseCode in 200..299) {
////                val body   = conn.inputStream.bufferedReader().readText()
////                conn.disconnect()
////                val policy = parsePolicy(body)
////                savePolicyToPrefs(prefs, policy)
////                Log.d(TAG, "✅ Policy fetched — interval=${policy.locationIntervalSec}s")
////                policy
////            } else {
////                conn.disconnect()
////                Log.w(TAG, "⚠️ Policy API returned $responseCode — using cache")
////                loadCachedPolicy(prefs)
////            }
////        } catch (e: Exception) {
////            Log.e(TAG, "❌ Policy fetch failed: ${e.message} — using cache")
////            loadCachedPolicy(prefs)
////        }
////    }
////
////    private fun parsePolicy(json: String): GpsPolicy {
////        return try {
////            // ✅ FIX: API response {"items":[{...}],...} handle karo
////            // Pehle "items" key check karo, phir plain array, phir plain object
////            val root = JSONObject(json)
////            val obj: JSONObject? = when {
////                root.has("items") -> {
////                    val items = root.getJSONArray("items")
////                    if (items.length() > 0) items.getJSONObject(0) else null
////                }
////                else -> root
////            }
////
////            if (obj == null) {
////                Log.w(TAG, "⚠️ Policy: empty items array — using default")
////                return DEFAULT
////            }
////
////            // ✅ gps_accuracy case-insensitive: API "HIGH" → lowercase karo
////            val rawAccuracy = obj.optString("gps_accuracy", DEFAULT.gpsAccuracy).lowercase()
////
////            GpsPolicy(
////                locationIntervalSec = obj.optLong("location_interval_sec", DEFAULT.locationIntervalSec),
////                gpsAccuracy         = rawAccuracy
////            ).also {
////                Log.d(TAG, "✅ Parsed policy: interval=${it.locationIntervalSec}s accuracy=${it.gpsAccuracy}")
////            }
////        } catch (e: Exception) {
////            // Fallback: plain array format try karo
////            return try {
////                val arr = JSONArray(json)
////                val obj = arr.optJSONObject(0) ?: return DEFAULT
////                val rawAccuracy = obj.optString("gps_accuracy", DEFAULT.gpsAccuracy).lowercase()
////                GpsPolicy(
////                    locationIntervalSec = obj.optLong("location_interval_sec", DEFAULT.locationIntervalSec),
////                    gpsAccuracy         = rawAccuracy
////                )
////            } catch (e2: Exception) {
////                Log.e(TAG, "❌ Policy parse error: ${e2.message}")
////                DEFAULT
////            }
////        }
////    }
////
////    private fun loadCachedPolicy(prefs: android.content.SharedPreferences): GpsPolicy {
////        val interval = prefs.getLong(PREF_INTERVAL, DEFAULT.locationIntervalSec)
////        val accuracy = prefs.getString(PREF_ACCURACY, DEFAULT.gpsAccuracy) ?: DEFAULT.gpsAccuracy
////        return GpsPolicy(locationIntervalSec = interval, gpsAccuracy = accuracy)
////    }
////
////    private fun savePolicyToPrefs(prefs: android.content.SharedPreferences, policy: GpsPolicy) {
////        prefs.edit()
////            .putLong(PREF_INTERVAL, policy.locationIntervalSec)
////            .putString(PREF_ACCURACY, policy.gpsAccuracy)
////            .putLong(PREF_FETCHED_AT, System.currentTimeMillis() / 1000L)
////            .apply()
////    }
////}
////
////// ─── BulkPostingScheduler ─────────────────────────────────────────────────────
////
////class BulkPostingScheduler {
////
////    companion object {
////        private const val TAG               = "BulkPostingScheduler"
////        private const val ALARM_REQUEST_CODE = 9999
////
////        // Alarm ka anchor time SharedPreferences mein store karo
////        // Taake har reschedule "drift" nahi kare balke original anchor se
////        // exact multiples par fire ho
////        private const val PREF_ALARM_ANCHOR = "bulk_alarm_anchor_elapsed"
////
////        /**
////         * Alarm schedule karo.
////         *
////         * @param resetAnchor
////         *   TRUE  → fresh start (app kill→restart, clockIn) — purana anchor ignore karo,
////         *           naya anchor abhi se set karo → next fire exactly 1 interval baad hoga.
////         *   FALSE → normal reschedule (alarm receiver ke andar) — anchor preserve karo
////         *           taake original cadence se drift na ho.
////         *
////         * ✅ FIX: App kill → restart pe resetAnchor=true pass karo (LocationMonitorService se).
////         *         Alarm receiver ke andar resetAnchor=false (default) rakho.
////         *         Is se double-interval bug (60s → 120s) solve hota hai.
////         */
////        fun startBulkPostingAlarm(context: Context, resetAnchor: Boolean = false) {
////            // ─── STEP 1: Policy fetch — CACHED se (blocking thread pe network call nahi) ──
////            val policy     = GpsPolicyManager.fetchPolicy(context, forceRefresh = false)
////            val intervalMs = policy.locationIntervalSec * 1000L
////
////            Log.d(TAG, "🚀 Scheduling bulk alarm — interval=${policy.locationIntervalSec}s resetAnchor=$resetAnchor")
////
////            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
////            val now   = SystemClock.elapsedRealtime()
////
////            // ─── STEP 2: Anchor decide karo ──────────────────────────────────────────────
////            // resetAnchor=true  → purana anchor clear, fresh anchor = now
////            // resetAnchor=false → existing anchor use karo (0 ho toh now set karo — safety)
////            var anchorElapsed = if (resetAnchor) 0L else prefs.getLong(PREF_ALARM_ANCHOR, 0L)
////
////            if (anchorElapsed == 0L) {
////                anchorElapsed = now
////                prefs.edit().putLong(PREF_ALARM_ANCHOR, anchorElapsed).apply()
////                Log.d(TAG, "⚓ [Alarm] Anchor set at elapsed=$anchorElapsed (resetAnchor=$resetAnchor)")
////            }
////
////            // ─── STEP 3: Next fire time exactly intervalMs ke multiple se ────────────────
////            val elapsed    = now - anchorElapsed
////            val nextOffset = intervalMs - (elapsed % intervalMs)
////            val triggerAt  = now + nextOffset
////
////            Log.d(TAG, "⏱️ [Alarm] elapsed=${elapsed}ms nextOffset=${nextOffset}ms → fires in ${nextOffset / 1000}s")
////
////            // ─── STEP 4: Exact alarm set karo ────────────────────────────────────────────
////            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
////            val intent       = Intent(context, BulkPostAlarmReceiver::class.java)
////            val pendingIntent = PendingIntent.getBroadcast(
////                context,
////                ALARM_REQUEST_CODE,
////                intent,
////                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
////            )
////
////            try { alarmManager.cancel(pendingIntent) } catch (_: Exception) {}
////
////            when {
////                // Android 12+ — SCHEDULE_EXACT_ALARM permission check
////                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
////                    if (alarmManager.canScheduleExactAlarms()) {
////                        alarmManager.setExactAndAllowWhileIdle(
////                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
////                            triggerAt,
////                            pendingIntent
////                        )
////                        Log.d(TAG, "✅ setExactAndAllowWhileIdle (API 31+) — fires in ${nextOffset / 1000}s")
////                    } else {
////                        // Fallback — Doze pe bhi chalega (~1-3 min accuracy)
////                        alarmManager.setAndAllowWhileIdle(
////                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
////                            triggerAt,
////                            pendingIntent
////                        )
////                        Log.w(TAG, "⚠️ canScheduleExactAlarms=false — using setAndAllowWhileIdle")
////                    }
////                }
////                // Android 6-11
////                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
////                    alarmManager.setExactAndAllowWhileIdle(
////                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
////                        triggerAt,
////                        pendingIntent
////                    )
////                    Log.d(TAG, "✅ setExactAndAllowWhileIdle (API 23+) — fires in ${nextOffset / 1000}s")
////                }
////                // Android < 6
////                else -> {
////                    alarmManager.setRepeating(
////                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
////                        triggerAt,
////                        intervalMs,
////                        pendingIntent
////                    )
////                    Log.d(TAG, "✅ setRepeating (API < 23) — interval=${intervalMs}ms")
////                }
////            }
////        }
////
////        fun stopBulkPostingAlarm(context: Context) {
////            val alarmManager  = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
////            val intent        = Intent(context, BulkPostAlarmReceiver::class.java)
////            val pendingIntent = PendingIntent.getBroadcast(
////                context,
////                ALARM_REQUEST_CODE,
////                intent,
////                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
////            )
////            alarmManager.cancel(pendingIntent)
////
////            // Anchor reset karo taake agley clockIn par fresh start ho
////            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
////            prefs.edit().remove(PREF_ALARM_ANCHOR).apply()
////
////            Log.d(TAG, "🛑 Bulk posting alarm stopped — anchor cleared")
////        }
////    }
////}
////
////// ─── BulkPostAlarmReceiver ────────────────────────────────────────────────────
////
////class BulkPostAlarmReceiver : BroadcastReceiver() {
////    override fun onReceive(context: Context, intent: Intent) {
////        val fireTime = SystemClock.elapsedRealtime()
////        Log.d("BulkPostAlarm", "⏰ Alarm fired at elapsed=$fireTime")
////
////        // ✅ FIX: resetAnchor=false — anchor preserve karo, original cadence maintain ho
////        // (resetAnchor=true sirf service fresh-start pe hona chahiye, yahan nahi)
////        BulkPostingScheduler.startBulkPostingAlarm(context, resetAnchor = false)
////
////        // Ab kaam karo background thread pe
////        Thread {
////            try {
////                val prefs       = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
////                val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
////                val isFrozen    = prefs.getBoolean("flutter.is_timer_frozen", false)
////
////                if (isClockedIn && !isFrozen) {
////                    val dbHelper = NativeDBHelper(context)
////                    val unposted = dbHelper.getUnpostedRows()
////
////                    if (unposted.isNotEmpty()) {
////                        Log.d("BulkPostAlarm", "📤 Found ${unposted.size} unposted rows — syncing...")
////                        syncUnpostedRows(context, dbHelper, unposted)
////                    } else {
////                        Log.d("BulkPostAlarm", "✅ No unposted rows")
////                    }
////                } else {
////                    Log.d("BulkPostAlarm", "⏸️ Not clocked in or frozen — skip sync")
////                }
////
////            } catch (e: Exception) {
////                Log.e("BulkPostAlarm", "❌ Error: ${e.message}")
////            }
////        }.start()
////    }
////
////    private fun syncUnpostedRows(context: Context, dbHelper: NativeDBHelper, unposted: List<Map<String, String>>) {
////        val BULK_API = "http://119.153.102.7:8001/location/bulk"
////
////        try {
////            val records = JSONArray()
////            for (row in unposted) {
////                records.put(JSONObject().apply {
////                    put("locationtracking_date", row["locationtracking_date"] ?: "")
////                    put("locationtracking_time", row["locationtracking_time"] ?: "")
////                    put("user_id",       row["user_id"]       ?: "")
////                    put("company_code",  row["company_code"]  ?: "")
////                    put("lat_in",        (row["lat_in"]  ?: "0").toDoubleOrNull() ?: 0.0)
////                    put("lng_in",        (row["lng_in"]  ?: "0").toDoubleOrNull() ?: 0.0)
////                    put("booker_name",   row["booker_name"]   ?: "")
////                    put("designation",   row["designation"]   ?: "")
////                    put("posted", false)
////                })
////            }
////
////            val body = JSONObject().put("records", records).toString()
////            val url  = URL(BULK_API)
////            val conn = url.openConnection() as HttpURLConnection
////            conn.apply {
////                requestMethod  = "POST"
////                connectTimeout = 15_000
////                readTimeout    = 30_000
////                doOutput       = true
////                setRequestProperty("Content-Type", "application/json")
////                setRequestProperty("Accept",       "application/json")
////            }
////
////            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(body) }
////
////            val responseCode = conn.responseCode
////            conn.disconnect()
////
////            if (responseCode in 200..299) {
////                val ids = unposted.mapNotNull { it["locationtracking_id"] }
////                dbHelper.markPosted(ids)
////                Log.d("BulkPostAlarm", "✅ Bulk POST OK — marked ${ids.size} rows posted")
////            } else {
////                Log.d("BulkPostAlarm", "⚠️ Bulk POST failed ($responseCode)")
////            }
////        } catch (e: Exception) {
////            Log.e("BulkPostAlarm", "❌ Bulk POST exception: ${e.message}")
////        }
////    }
////}
//
//package com.metaxperts.order_booking_app
//
//import android.app.AlarmManager
//import android.app.PendingIntent
//import android.content.BroadcastReceiver
//import android.content.Context
//import android.content.Intent
//import android.os.Build
//import android.os.SystemClock
//import android.util.Log
//import org.json.JSONArray
//import org.json.JSONObject
//import java.io.OutputStreamWriter
//import java.net.HttpURLConnection
//import java.net.URL
//
//// ─── GPS Policy ───────────────────────────────────────────────────────────────
//
//data class GpsPolicy(
//    val locationIntervalSec: Long,
//    val gpsAccuracy: String
//)
//
//object GpsPolicyManager {
//
//    private const val TAG = "GpsPolicyManager"
//    private const val POLICY_API =
//        "https://cloud.metaxperts.net:8443/erp/valor_trading/gpstracking/get/"
//
//    private const val PREF_INTERVAL   = "gps_policy_interval_sec"
//    private const val PREF_ACCURACY   = "gps_policy_accuracy"
//    private const val PREF_FETCHED_AT = "gps_policy_fetched_at"
//
//    private val DEFAULT = GpsPolicy(locationIntervalSec = 60L, gpsAccuracy = "high")
//    private const val CACHE_TTL_SEC = 300L
//
//    fun fetchPolicy(context: Context, forceRefresh: Boolean = false): GpsPolicy {
//        val prefs       = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
//        val userId      = prefs.getString("flutter.userId", "") ?: ""
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
//            val url  = URL("$POLICY_API?company_code=$companyCode&user_id=$userId")
//            val conn = url.openConnection() as HttpURLConnection
//            conn.connectTimeout = 10_000
//            conn.readTimeout    = 10_000
//            conn.requestMethod  = "GET"
//            conn.setRequestProperty("Accept", "application/json")
//
//            val responseCode = conn.responseCode
//            if (responseCode in 200..299) {
//                val body   = conn.inputStream.bufferedReader().readText()
//                conn.disconnect()
//                val policy = parsePolicy(body)
//                savePolicyToPrefs(prefs, policy)
//                Log.d(TAG, "✅ Policy fetched — interval=${policy.locationIntervalSec}s")
//                policy
//            } else {
//                conn.disconnect()
//                Log.w(TAG, "⚠️ Policy API returned $responseCode — using cache")
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
//
//            if (obj == null) {
//                Log.w(TAG, "⚠️ Policy: empty items array — using default")
//                return DEFAULT
//            }
//
//            val rawAccuracy = obj.optString("gps_accuracy", DEFAULT.gpsAccuracy).lowercase()
//
//            GpsPolicy(
//                locationIntervalSec = obj.optLong("location_interval_sec", DEFAULT.locationIntervalSec),
//                gpsAccuracy         = rawAccuracy
//            ).also {
//                Log.d(TAG, "✅ Parsed policy: interval=${it.locationIntervalSec}s accuracy=${it.gpsAccuracy}")
//            }
//        } catch (e: Exception) {
//            return try {
//                val arr = JSONArray(json)
//                val obj = arr.optJSONObject(0) ?: return DEFAULT
//                val rawAccuracy = obj.optString("gps_accuracy", DEFAULT.gpsAccuracy).lowercase()
//                GpsPolicy(
//                    locationIntervalSec = obj.optLong("location_interval_sec", DEFAULT.locationIntervalSec),
//                    gpsAccuracy         = rawAccuracy
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
//            .putLong(PREF_INTERVAL, policy.locationIntervalSec)
//            .putString(PREF_ACCURACY, policy.gpsAccuracy)
//            .putLong(PREF_FETCHED_AT, System.currentTimeMillis() / 1000L)
//            .apply()
//    }
//}
//
//// ─── BulkPostingScheduler ─────────────────────────────────────────────────────
//
//class BulkPostingScheduler {
//
//    companion object {
//        private const val TAG               = "BulkPostingScheduler"
//        private const val ALARM_REQUEST_CODE = 9999
//
//        // Alarm ka anchor time SharedPreferences mein store karo
//        // Taake har reschedule "drift" nahi kare balke original anchor se exact multiples par fire ho
//        private const val PREF_ALARM_ANCHOR = "bulk_alarm_anchor_elapsed"
//
//        /**
//         * Alarm schedule karo.
//         *
//         * @param resetAnchor
//         *   TRUE  → fresh start (app kill→restart, clockIn) — naya anchor abhi se set karo.
//         *   FALSE → normal reschedule (alarm receiver ke andar) — anchor preserve karo.
//         *
//         * ✅ FIX: App kill → restart pe resetAnchor=true pass karo (LocationMonitorService se).
//         *         Alarm receiver ke andar resetAnchor=false (default) rakho.
//         *         Is se double-interval bug (60s → 120s) solve hota hai.
//         */
//        fun startBulkPostingAlarm(context: Context, resetAnchor: Boolean = false) {
//            val policy     = GpsPolicyManager.fetchPolicy(context, forceRefresh = false)
//            val intervalMs = policy.locationIntervalSec * 1000L
//
//            Log.d(TAG, "🚀 Scheduling bulk alarm — interval=${policy.locationIntervalSec}s resetAnchor=$resetAnchor")
//
//            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
//            val now   = SystemClock.elapsedRealtime()
//
//            var anchorElapsed = if (resetAnchor) 0L else prefs.getLong(PREF_ALARM_ANCHOR, 0L)
//
//            if (anchorElapsed == 0L) {
//                anchorElapsed = now
//                prefs.edit().putLong(PREF_ALARM_ANCHOR, anchorElapsed).apply()
//                Log.d(TAG, "⚓ [Alarm] Anchor set at elapsed=$anchorElapsed (resetAnchor=$resetAnchor)")
//            }
//
//            val elapsed    = now - anchorElapsed
//            val nextOffset = intervalMs - (elapsed % intervalMs)
//            val triggerAt  = now + nextOffset
//
//            Log.d(TAG, "⏱️ [Alarm] elapsed=${elapsed}ms nextOffset=${nextOffset}ms → fires in ${nextOffset / 1000}s")
//
//            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
//            val intent       = Intent(context, BulkPostAlarmReceiver::class.java)
//            val pendingIntent = PendingIntent.getBroadcast(
//                context,
//                ALARM_REQUEST_CODE,
//                intent,
//                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
//            )
//
//            try { alarmManager.cancel(pendingIntent) } catch (_: Exception) {}
//
//            when {
//                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
//                    if (alarmManager.canScheduleExactAlarms()) {
//                        alarmManager.setExactAndAllowWhileIdle(
//                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
//                            triggerAt,
//                            pendingIntent
//                        )
//                        Log.d(TAG, "✅ setExactAndAllowWhileIdle (API 31+) — fires in ${nextOffset / 1000}s")
//                    } else {
//                        alarmManager.setAndAllowWhileIdle(
//                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
//                            triggerAt,
//                            pendingIntent
//                        )
//                        Log.w(TAG, "⚠️ canScheduleExactAlarms=false — using setAndAllowWhileIdle")
//                    }
//                }
//                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
//                    alarmManager.setExactAndAllowWhileIdle(
//                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
//                        triggerAt,
//                        pendingIntent
//                    )
//                    Log.d(TAG, "✅ setExactAndAllowWhileIdle (API 23+) — fires in ${nextOffset / 1000}s")
//                }
//                else -> {
//                    alarmManager.setRepeating(
//                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
//                        triggerAt,
//                        intervalMs,
//                        pendingIntent
//                    )
//                    Log.d(TAG, "✅ setRepeating (API < 23) — interval=${intervalMs}ms")
//                }
//            }
//        }
//
//        fun stopBulkPostingAlarm(context: Context) {
//            val alarmManager  = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
//            val intent        = Intent(context, BulkPostAlarmReceiver::class.java)
//            val pendingIntent = PendingIntent.getBroadcast(
//                context,
//                ALARM_REQUEST_CODE,
//                intent,
//                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
//            )
//            alarmManager.cancel(pendingIntent)
//
//            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
//            prefs.edit().remove(PREF_ALARM_ANCHOR).apply()
//
//            Log.d(TAG, "🛑 Bulk posting alarm stopped — anchor cleared")
//        }
//    }
//}
//
//// ─── BulkPostAlarmReceiver ────────────────────────────────────────────────────
//
//class BulkPostAlarmReceiver : BroadcastReceiver() {
//    override fun onReceive(context: Context, intent: Intent) {
//        val fireTime = SystemClock.elapsedRealtime()
//        Log.d("BulkPostAlarm", "⏰ Alarm fired at elapsed=$fireTime")
//
//        // ✅ FIX: resetAnchor=false — anchor preserve karo, original cadence maintain ho
//        BulkPostingScheduler.startBulkPostingAlarm(context, resetAnchor = false)
//
//        // Ab kaam karo background thread pe
//        Thread {
//            try {
//                val prefs       = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
//                val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
//                val isFrozen    = prefs.getBoolean("flutter.is_timer_frozen", false)
//
//                if (isClockedIn && !isFrozen) {
//
//                    // ✅ FIX: Agar LocationMonitorService chal rahi hai to alarm sync skip karo.
//                    // Service khud 30s heartbeat aur httpPostLoop mein sync karti hai.
//                    // Alarm sirf tab sync kare jab service band ho (true fallback mode).
//                    // Yeh double posting ka core fix hai — app kill ke baad service restart hoti hai
//                    // aur alarm dono ek saath sync karne lagte the.
//                    if (LocationMonitorService.isRunning) {
//                        Log.d("BulkPostAlarm", "⏭️ Service is running — skipping alarm sync (double posting prevention)")
//                        return@Thread
//                    }
//
//                    Log.d("BulkPostAlarm", "🔄 Service NOT running — alarm doing fallback sync")
//                    val dbHelper = NativeDBHelper(context)
//                    val unposted = dbHelper.getUnpostedRows()
//
//                    if (unposted.isNotEmpty()) {
//                        Log.d("BulkPostAlarm", "📤 Found ${unposted.size} unposted rows — syncing...")
//                        syncUnpostedRows(context, dbHelper, unposted)
//                    } else {
//                        Log.d("BulkPostAlarm", "✅ No unposted rows")
//                    }
//                } else {
//                    Log.d("BulkPostAlarm", "⏸️ Not clocked in or frozen — skip sync")
//                }
//
//            } catch (e: Exception) {
//                Log.e("BulkPostAlarm", "❌ Error: ${e.message}")
//            }
//        }.start()
//    }
//
//    private fun syncUnpostedRows(context: Context, dbHelper: NativeDBHelper, unposted: List<Map<String, String>>) {
//        val BULK_API = "http://119.153.102.7:8001/location/bulk"
//
//        try {
//            val records = JSONArray()
//            for (row in unposted) {
//                records.put(JSONObject().apply {
//                    put("locationtracking_date", row["locationtracking_date"] ?: "")
//                    put("locationtracking_time", row["locationtracking_time"] ?: "")
//                    put("user_id",       row["user_id"]       ?: "")
//                    put("company_code",  row["company_code"]  ?: "")
//                    put("lat_in",        (row["lat_in"]  ?: "0").toDoubleOrNull() ?: 0.0)
//                    put("lng_in",        (row["lng_in"]  ?: "0").toDoubleOrNull() ?: 0.0)
//                    put("booker_name",   row["booker_name"]   ?: "")
//                    put("designation",   row["designation"]   ?: "")
//                    put("posted", false)
//                })
//            }
//
//            val body = JSONObject().put("records", records).toString()
//            val url  = URL(BULK_API)
//            val conn = url.openConnection() as HttpURLConnection
//            conn.apply {
//                requestMethod  = "POST"
//                connectTimeout = 15_000
//                readTimeout    = 30_000
//                doOutput       = true
//                setRequestProperty("Content-Type", "application/json")
//                setRequestProperty("Accept",       "application/json")
//            }
//
//            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(body) }
//
//            val responseCode = conn.responseCode
//            conn.disconnect()
//
//            if (responseCode in 200..299) {
//                val ids = unposted.mapNotNull { it["locationtracking_id"] }
//                dbHelper.markPosted(ids)
//                Log.d("BulkPostAlarm", "✅ Bulk POST OK — marked ${ids.size} rows posted")
//            } else {
//                Log.d("BulkPostAlarm", "⚠️ Bulk POST failed ($responseCode)")
//            }
//        } catch (e: Exception) {
//            Log.e("BulkPostAlarm", "❌ Bulk POST exception: ${e.message}")
//        }
//    }
//}

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
        private const val TAG               = "BulkPostingScheduler"
        private const val ALARM_REQUEST_CODE = 9999

        // Alarm ka anchor time SharedPreferences mein store karo
        // Taake har reschedule "drift" nahi kare balke original anchor se exact multiples par fire ho
        private const val PREF_ALARM_ANCHOR = "bulk_alarm_anchor_elapsed"

        /**
         * Alarm schedule karo.
         *
         * @param resetAnchor
         *   TRUE  → fresh start (app kill→restart, clockIn) — naya anchor abhi se set karo.
         *   FALSE → normal reschedule (alarm receiver ke andar) — anchor preserve karo.
         *
         * ✅ FIX: App kill → restart pe resetAnchor=true pass karo (LocationMonitorService se).
         *         Alarm receiver ke andar resetAnchor=false (default) rakho.
         *         Is se double-interval bug (60s → 120s) solve hota hai.
         */
        fun startBulkPostingAlarm(context: Context, resetAnchor: Boolean = false) {
            // ✅ Cache se policy lo — forceRefresh=false
            // Fresh fetch hamesha LocationMonitorService.startMonitoring() karta hai (5s timeout).
            // Policy change hone par loadAndApplyPolicy() is function ko resetAnchor=true ke saath
            // call karta hai — is tarah interval automatically update ho jata hai.
            // Yahan network call nahi hoti — blocking thread safe rahta hai.
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

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent       = Intent(context, BulkPostAlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            try { alarmManager.cancel(pendingIntent) } catch (_: Exception) {}

            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                    if (alarmManager.canScheduleExactAlarms()) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
                            triggerAt,
                            pendingIntent
                        )
                        Log.d(TAG, "✅ setExactAndAllowWhileIdle (API 31+) — fires in ${nextOffset / 1000}s")
                    } else {
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
                            triggerAt,
                            pendingIntent
                        )
                        Log.w(TAG, "⚠️ canScheduleExactAlarms=false — using setAndAllowWhileIdle")
                    }
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

            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().remove(PREF_ALARM_ANCHOR).apply()

            Log.d(TAG, "🛑 Bulk posting alarm stopped — anchor cleared")
        }
    }
}

// ─── BulkPostAlarmReceiver ────────────────────────────────────────────────────

class BulkPostAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val fireTime = SystemClock.elapsedRealtime()
        Log.d("BulkPostAlarm", "⏰ Alarm fired at elapsed=$fireTime")

        // ✅ FIX: resetAnchor=false — anchor preserve karo, original cadence maintain ho
        BulkPostingScheduler.startBulkPostingAlarm(context, resetAnchor = false)

        // Ab kaam karo background thread pe
        Thread {
            try {
                val prefs       = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
                val isFrozen    = prefs.getBoolean("flutter.is_timer_frozen", false)

                if (isClockedIn && !isFrozen) {

                    // ✅ FIX: Agar LocationMonitorService chal rahi hai to alarm sync skip karo.
                    // Service khud 30s heartbeat aur httpPostLoop mein sync karti hai.
                    // Alarm sirf tab sync kare jab service band ho (true fallback mode).
                    // Yeh double posting ka core fix hai — app kill ke baad service restart hoti hai
                    // aur alarm dono ek saath sync karne lagte the.
                    if (LocationMonitorService.isRunning) {
                        Log.d("BulkPostAlarm", "⏭️ Service is running — skipping alarm sync (double posting prevention)")
                        return@Thread
                    }

                    Log.d("BulkPostAlarm", "🔄 Service NOT running — alarm doing fallback sync")
                    val dbHelper = NativeDBHelper(context)
                    val unposted = dbHelper.getUnpostedRows()

                    if (unposted.isNotEmpty()) {
                        Log.d("BulkPostAlarm", "📤 Found ${unposted.size} unposted rows — syncing...")
                        syncUnpostedRows(context, dbHelper, unposted)
                    } else {
                        Log.d("BulkPostAlarm", "✅ No unposted rows")
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