package com.metaxperts.order_booking_app

// ══════════════════════════════════════════════════════════════════════════════
// DateTimeChangeReceiver.kt  —  Bookit / Order Booking App
//
// PURPOSE:
//   Detects when the user manually changes the device date or time.
//   Works in THREE states:
//     1. App in foreground
//     2. App in background
//     3. App fully killed / process dead
//
// DB TABLE COLUMNS MAPPED:
//   ID           — auto (Oracle sequence)
//   USER_ID      — from SharedPrefs: flutter.userId
//   USER_NAME    — from SharedPrefs: flutter.userName
//   CHANGE_TYPE  — "TIME_SET" | "TIME_CHANGED" | "DATE_CHANGED"
//   OLD_TIME     — device time BEFORE the change (elapsedRealtime snapshot trick)
//   NEW_TIME     — device time AFTER the change
//   NEW_DATE     — newly set date (yyyy-MM-dd)
//   DETECTED_AT  — ISO timestamp when change was detected
//   BATTERY      — battery % at detection time
//   CREATED_AT   — set by server / DB default (TIMESTAMP)
//
// OFFLINE QUEUE:
//   • Offline → payload saved to SharedPreferences ("BookitDateTimePending")
//   • WorkManager (PendingSyncWorker) fires when network restored, even if app killed
//   • Failed posts also queued and retried
//
// MANIFEST — add to AndroidManifest.xml:
// ─────────────────────────────────────────────────────────────────────────────
//   <receiver
//       android:name=".DateTimeChangeReceiver"
//       android:exported="true">
//       <intent-filter>
//           <action android:name="android.intent.action.TIME_SET" />
//           <action android:name="android.intent.action.DATE_CHANGED" />
//       </intent-filter>
//   </receiver>
// ─────────────────────────────────────────────────────────────────────────────
//
// RUNTIME REGISTRATION (in MainActivity.onCreate or Application.onCreate):
// ─────────────────────────────────────────────────────────────────────────────
//   val filter = IntentFilter(Intent.ACTION_TIME_TICK)
//   registerReceiver(DateTimeChangeReceiver(), filter)
//   DateTimeChangeReceiver.snapshotCurrentTime(applicationContext)
// ─────────────────────────────────────────────────────────────────────────────
//
// DEPENDENCY (app/build.gradle):
//   implementation "androidx.work:work-runtime-ktx:2.9.0"
// ══════════════════════════════════════════════════════════════════════════════

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class DateTimeChangeReceiver : BroadcastReceiver() {

    // ── Configuration ──────────────────────────────────────────────────────
    // ⚠️ Replace with your actual Bookit API endpoint
    private val API_URL        = "https://your-bookit-server.com/api/datetimechange/post/"
    private val PREFS_NAME     = "FlutterSharedPreferences"
    private val TAG            = "BookitDTReceiver"

    // ── Offline queue config ───────────────────────────────────────────────
    private val PENDING_PREFS  = "BookitDateTimePending"
    private val PENDING_KEY    = "pending_queue"
    private val SYNC_WORK_NAME = "bookit_datetime_pending_sync"
    private val SNAPSHOT_KEY   = "last_known_time"

    // ── Companion: periodic time snapshot ─────────────────────────────────
    companion object {
        private const val PENDING_PREFS_STATIC = "BookitDateTimePending"
        private const val SNAPSHOT_KEY_STATIC  = "last_known_time"

        /**
         * Call this every minute (via TIME_TICK or WorkManager/AlarmManager).
         * Saves wall-clock + elapsedRealtime so we can reconstruct old_time
         * accurately even after the user has changed the clock.
         */
        fun snapshotCurrentTime(context: Context) {
            val wallMs    = System.currentTimeMillis()
            val elapsedMs = android.os.SystemClock.elapsedRealtime()
            val timeStr   = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date(wallMs))
            context.getSharedPreferences(PENDING_PREFS_STATIC, Context.MODE_PRIVATE)
                .edit()
                .putString(SNAPSHOT_KEY_STATIC,          timeStr)
                .putLong("last_known_wall_ms",    wallMs)
                .putLong("last_known_elapsed_ms", elapsedMs)
                .apply()
            android.util.Log.d("BookitDTReceiver",
                "🕐 Snapshot saved: time='$timeStr'  wall=$wallMs  elapsed=$elapsedMs")
        }
    }

    // ── Entry point ────────────────────────────────────────────────────────
    override fun onReceive(context: Context, intent: Intent?) {
        android.util.Log.d(TAG, "📣 onReceive() fired — action=${intent?.action ?: "null"}")

        val action = intent?.action ?: run {
            android.util.Log.w(TAG, "⚠️ Intent or action is null — ignoring")
            return
        }

        // TIME_TICK fires every minute — just update snapshot, nothing else
        if (action == Intent.ACTION_TIME_TICK) {
            snapshotCurrentTime(context)
            return
        }

        val isTimeSet     = (action == "android.intent.action.TIME_SET")
        val isTimeChanged = (action == Intent.ACTION_TIME_CHANGED)
        val isDateChanged = (action == "android.intent.action.DATE_CHANGED")

        if (!isTimeSet && !isTimeChanged && !isDateChanged) {
            android.util.Log.d(TAG, "ℹ️ Action '$action' not a date/time change — ignoring")
            return
        }

        val changeType = when {
            isTimeSet     -> "TIME_SET"
            isTimeChanged -> "TIME_CHANGED"
            isDateChanged -> "DATE_CHANGED"
            else          -> return
        }

        android.util.Log.d(TAG, "🕐 [$changeType] Device date/time was manually changed")

        // ── Read SharedPrefs ───────────────────────────────────────────────
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        // DEBUG: dump all keys (remove in production if desired)
        val allPrefs: Map<String, *> = prefs.all
        android.util.Log.d(TAG, "🗃️ ===== ALL SharedPreferences keys =====")
        allPrefs.entries.sortedBy { it.key }.forEach { (k, v) ->
            android.util.Log.d(TAG, "🗃️   '$k'  =  '$v'")
        }
        android.util.Log.d(TAG, "🗃️ ===== END SharedPreferences keys =====")

        // ── USER_ID ────────────────────────────────────────────────────────
        // MainActivity writes: flutter.userId
        val userId = firstNonEmpty(prefs, listOf(
            "flutter.userId",
            "flutter.user_id",
            "flutter.emp_id",
            "userId",
            "user_id"
        ))
        android.util.Log.d(TAG, "👤 [$changeType] user_id='$userId'")

        // ── USER_NAME ──────────────────────────────────────────────────────
        // MainActivity writes: flutter.userName
        val userName = firstNonEmpty(prefs, listOf(
            "flutter.userName",
            "flutter.user_name",
            "flutter.bookerName",
            "userName",
            "user_name"
        ))
        android.util.Log.d(TAG, "👤 [$changeType] user_name='$userName'")

        // Skip if user is not logged in
        if (userId.isEmpty()) {
            android.util.Log.w(TAG, "⚠️ [$changeType] user_id empty — user not logged in — skipping")
            return
        }

        // ── Reconstruct OLD_TIME using elapsedRealtime delta ───────────────
        //
        // Android fires TIME_SET AFTER the clock is already updated, so Date()
        // already returns the NEW time. We use the periodic snapshot to recover
        // the pre-change time:
        //
        //   oldWallMs = wallSnap + (elapsedNow − elapsedSnap)
        //
        // elapsedRealtime() counts ms since boot and is immune to clock changes.
        val pendingPrefs = context.getSharedPreferences(PENDING_PREFS, Context.MODE_PRIVATE)
        val elapsedNow   = android.os.SystemClock.elapsedRealtime()
        val elapsedSnap  = pendingPrefs.getLong("last_known_elapsed_ms", -1L)
        val wallSnap     = pendingPrefs.getLong("last_known_wall_ms", -1L)

        val preChangeWallMs: Long? = if (elapsedSnap > 0 && wallSnap > 0) {
            wallSnap + (elapsedNow - elapsedSnap)
        } else {
            null
        }

        val oldTime = if (preChangeWallMs != null) {
            val t = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date(preChangeWallMs))
            android.util.Log.d(TAG, "🕐 [$changeType] old_time reconstructed='$t'")
            t
        } else {
            android.util.Log.w(TAG, "⚠️ [$changeType] No snapshot available — old_time will be empty")
            ""
        }

        // NEW_DATE and NEW_TIME — what user changed TO
        val changedNow = Date()
        val newDate    = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(changedNow)
        val newTime    = SimpleDateFormat("HH:mm:ss",   Locale.getDefault()).format(changedNow)
        val detectedAt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
            .format(if (preChangeWallMs != null) Date(preChangeWallMs) else changedNow)

        android.util.Log.d(TAG, "🗓️ [$changeType] detected_at='$detectedAt'  old_time='$oldTime'  new_date='$newDate'  new_time='$newTime'")

        // Update snapshot to new time so next change has accurate baseline
        snapshotCurrentTime(context)

        // ── BATTERY ────────────────────────────────────────────────────────
        val battery = try {
            val bm    = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY).coerceIn(0, 100)
            android.util.Log.d(TAG, "🔋 [$changeType] battery=$level%")
            level
        } catch (e: Exception) {
            android.util.Log.w(TAG, "⚠️ [$changeType] Could not read battery: ${e.message}")
            -1
        }

        // ── Build JSON Payload ─────────────────────────────────────────────
        // Columns: USER_ID, USER_NAME, CHANGE_TYPE, OLD_TIME, NEW_TIME,
        //          NEW_DATE, DETECTED_AT, BATTERY
        val payload = JSONObject().apply {
            put("user_id",     userId)
            put("user_name",   userName)
            put("change_type", changeType)
            put("old_time",    oldTime)
            put("new_time",    newTime)
            put("new_date",    newDate)
            put("detected_at", detectedAt)
            put("battery",     battery)
        }.toString()

        android.util.Log.d(TAG, "📦 [$changeType] Payload → $payload")

        // ── Send on background thread ──────────────────────────────────────
        Thread {
            android.util.Log.d(TAG, "🧵 [$changeType] Background thread started")

            // Pre-flush any previously failed/offline payloads first
            flushPendingPayloads(context, changeType)

            if (isNetworkAvailable(context)) {
                android.util.Log.d(TAG, "🌐 [$changeType] Online — posting to API")
                val success = postToApi(payload, changeType)
                if (!success) {
                    android.util.Log.w(TAG, "⚠️ [$changeType] Post failed — queuing for WorkManager retry")
                    savePendingPayload(context, payload, changeType)
                }
            } else {
                android.util.Log.w(TAG, "📴 [$changeType] Offline — saving to queue")
                savePendingPayload(context, payload, changeType)
            }
        }.start()
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Offline Queue Helpers
    // ══════════════════════════════════════════════════════════════════════════

    private fun savePendingPayload(context: Context, jsonPayload: String, changeType: String) {
        try {
            val pp       = context.getSharedPreferences(PENDING_PREFS, Context.MODE_PRIVATE)
            val existing = pp.getString(PENDING_KEY, "[]") ?: "[]"
            val arr      = try { JSONArray(existing) } catch (_: Exception) { JSONArray() }
            arr.put(JSONObject(jsonPayload))
            pp.edit().putString(PENDING_KEY, arr.toString()).apply()
            android.util.Log.d(TAG, "💾 [$changeType] Queued — total pending: ${arr.length()}")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ [$changeType] Failed to queue payload: ${e.message}")
        }
        scheduleWorkManagerSync(context, changeType)
    }

    private fun scheduleWorkManagerSync(context: Context, changeType: String) {
        try {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()
            val syncWork = OneTimeWorkRequestBuilder<BookitPendingSyncWorker>()
                .setConstraints(constraints)
                .build()
            WorkManager.getInstance(context.applicationContext)
                .enqueueUniqueWork(SYNC_WORK_NAME, ExistingWorkPolicy.KEEP, syncWork)
            android.util.Log.d(TAG, "📅 [$changeType] WorkManager scheduled — runs when online")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ [$changeType] WorkManager schedule failed: ${e.message}")
        }
    }

    private fun flushPendingPayloads(context: Context, changeType: String) {
        if (!isNetworkAvailable(context)) {
            android.util.Log.d(TAG, "📴 [$changeType] Offline — skipping pre-flush")
            return
        }
        val pp        = context.getSharedPreferences(PENDING_PREFS, Context.MODE_PRIVATE)
        val raw       = pp.getString(PENDING_KEY, "[]") ?: "[]"
        val arr       = try { JSONArray(raw) } catch (_: Exception) { return }
        if (arr.length() == 0) return

        android.util.Log.d(TAG, "📤 [$changeType] Pre-flushing ${arr.length()} pending payload(s)")
        val remaining = JSONArray()
        for (i in 0 until arr.length()) {
            val item = arr.optJSONObject(i) ?: continue
            val ct   = item.optString("change_type", "PENDING")
            if (!postToApi(item.toString(), "$ct[retry]")) remaining.put(item)
        }
        pp.edit().putString(PENDING_KEY, remaining.toString()).apply()
        android.util.Log.d(TAG, "✅ [$changeType] Pre-flush done — sent=${arr.length() - remaining.length()}  pending=${remaining.length()}")
    }

    private fun isNetworkAvailable(context: Context): Boolean {
        return try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val network = cm.activeNetwork ?: return false
                val caps    = cm.getNetworkCapabilities(network) ?: return false
                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                        caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            } else {
                @Suppress("DEPRECATION")
                cm.activeNetworkInfo?.isConnected == true
            }
        } catch (e: Exception) {
            android.util.Log.w(TAG, "⚠️ isNetworkAvailable failed: ${e.message}")
            false
        }
    }

    private fun postToApi(jsonPayload: String, changeType: String): Boolean {
        return try {
            android.util.Log.d(TAG, "📡 [$changeType] Connecting → $API_URL")
            val conn = (URL(API_URL).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Accept",       "application/json")
                doOutput       = true
                connectTimeout = 15_000
                readTimeout    = 15_000
            }
            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(jsonPayload) }
            val code = conn.responseCode
            val msg  = try { conn.responseMessage } catch (_: Exception) { "" }
            conn.disconnect()
            android.util.Log.d(TAG, "📥 [$changeType] HTTP $code $msg")
            if (code in 200..299) {
                android.util.Log.d(TAG, "✅ [$changeType] API post success")
                true
            } else {
                android.util.Log.w(TAG, "⚠️ [$changeType] Non-2xx response: $code")
                false
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ [$changeType] Network error: ${e.message}")
            false
        }
    }

    // ── Utility: find first non-empty value from a list of SharedPrefs keys ──
    private fun firstNonEmpty(
        prefs: android.content.SharedPreferences,
        keys: List<String>
    ): String {
        val map: Map<String, *> = prefs.all
        for (key in keys) {
            val raw = map[key]?.toString()?.trim() ?: continue
            if (raw.isNotEmpty() && raw != "null") {
                android.util.Log.d(TAG, "🔑 Key found: '$key' = '$raw'")
                return raw
            }
        }
        android.util.Log.w(TAG, "⚠️ No value found for keys: $keys")
        return ""
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// TimeSnapshotWorker
//
// Periodic WorkManager worker — calls snapshotCurrentTime() every ~1 min
// so old_time is always accurate.
//
// Register from Application.onCreate() or MainActivity.onCreate():
//
//   val work = PeriodicWorkRequestBuilder<TimeSnapshotWorker>(15, TimeUnit.MINUTES).build()
//   WorkManager.getInstance(this).enqueueUniquePeriodicWork(
//       "bookit_time_snapshot",
//       ExistingPeriodicWorkPolicy.KEEP,
//       work)
//
// NOTE: WorkManager minimum real interval is ~15 min on stock Android (Doze).
// For minute-accurate old_time, prefer registering ACTION_TIME_TICK receiver
// at runtime (see top of file).
// ══════════════════════════════════════════════════════════════════════════════
class TimeSnapshotWorker(
    context: Context,
    params: WorkerParameters
) : Worker(context, params) {
    override fun doWork(): Result {
        DateTimeChangeReceiver.snapshotCurrentTime(applicationContext)
        return Result.success()
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// BookitPendingSyncWorker
//
// WorkManager Worker — flushes offline queue when network is restored.
// Runs even if app is fully killed.
// ══════════════════════════════════════════════════════════════════════════════
class BookitPendingSyncWorker(
    context: Context,
    params: WorkerParameters
) : Worker(context, params) {

    // ⚠️ Same endpoint as DateTimeChangeReceiver — keep in sync
    private val API_URL       = "https://cloud.metaxperts.net:8443/erp/valor_trading/datetime_changes/post"
    private val PENDING_PREFS = "BookitDateTimePending"
    private val PENDING_KEY   = "pending_queue"
    private val TAG           = "BookitSyncWorker"

    override fun doWork(): Result {
        return try {
            android.util.Log.d(TAG, "🔄 WorkManager started — flushing pending queue")

            val prefs = applicationContext.getSharedPreferences(PENDING_PREFS, Context.MODE_PRIVATE)
            val raw   = prefs.getString(PENDING_KEY, "[]") ?: "[]"
            val arr   = try { JSONArray(raw) } catch (e: Exception) {
                android.util.Log.e(TAG, "❌ Cannot parse queue: ${e.message}")
                return Result.failure()
            }

            if (arr.length() == 0) {
                android.util.Log.d(TAG, "✅ Queue empty — nothing to do")
                return Result.success()
            }

            android.util.Log.d(TAG, "📤 Sending ${arr.length()} pending payload(s)")
            val remaining = JSONArray()

            for (i in 0 until arr.length()) {
                val item = arr.optJSONObject(i) ?: continue
                val ct   = item.optString("change_type", "PENDING")
                if (postToApi(item.toString(), ct)) {
                    android.util.Log.d(TAG, "✅ Item $i sent — change_type='$ct'")
                } else {
                    android.util.Log.w(TAG, "⚠️ Item $i failed — keeping for retry")
                    remaining.put(item)
                }
            }

            prefs.edit().putString(PENDING_KEY, remaining.toString()).apply()
            val sent = arr.length() - remaining.length()
            android.util.Log.d(TAG, "✅ Done — sent=$sent  still_pending=${remaining.length()}")

            if (remaining.length() == 0) Result.success() else Result.retry()

        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ Exception: ${e.message}")
            Result.retry()
        }
    }

    private fun postToApi(jsonPayload: String, changeType: String): Boolean {
        return try {
            val conn = (URL(API_URL).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Accept",       "application/json")
                doOutput       = true
                connectTimeout = 15_000
                readTimeout    = 15_000
            }
            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(jsonPayload) }
            val code = conn.responseCode
            conn.disconnect()
            android.util.Log.d(TAG, "📥 [$changeType] HTTP $code")
            code in 200..299
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ [$changeType] ${e.message}")
            false
        }
    }
}