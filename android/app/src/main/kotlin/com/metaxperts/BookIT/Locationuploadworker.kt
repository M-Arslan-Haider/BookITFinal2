package com.metaxperts.order_booking_app

// ═════════════════════════════════════════════════════════════════════════════
// LocationUploadWorker — FIXED
//
// ROOT CAUSE FIX:
//   The previous version called startForegroundService(LocationMonitorService)
//   inside doWork(). This caused a ForegroundServiceDidNotStartInTimeException
//   crash when the Worker ran while the app process was dying/restarting,
//   because the OS killed the process before startForeground() could be called.
//
// FIX: REMOVED the service restart logic from doWork() entirely.
//   - LocationMonitorService is START_STICKY → OS restarts it automatically
//   - BootCompletedReceiver restarts it after reboot
//   - The Worker only does what it should: upload unposted DB rows
//   - No startForegroundService() here → no 5-second deadline → no crash
// ═════════════════════════════════════════════════════════════════════════════

import android.content.Context
import android.util.Log
import androidx.work.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

class LocationUploadWorker(
    context: Context,
    workerParams: WorkerParameters
) : Worker(context, workerParams) {

    companion object {
        private const val TAG          = "LocationUploadWorker"
        private const val WORK_NAME    = "location_upload_periodic"
        private const val BULK_API_URL = "http://119.153.102.7:8001/location/bulk"

        fun schedule(context: Context) {
            try {
                val constraints = Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build()

                val workRequest = PeriodicWorkRequestBuilder<LocationUploadWorker>(
                    15, TimeUnit.MINUTES
                )
                    .setConstraints(constraints)
                    .setInitialDelay(1, TimeUnit.MINUTES)
                    .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 1, TimeUnit.MINUTES)
                    .build()

                WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                    WORK_NAME,
                    ExistingPeriodicWorkPolicy.KEEP,
                    workRequest
                )
                Log.d(TAG, "✅ Scheduled (15 min periodic, network required)")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Schedule failed: ${e.message}")
            }
        }

        fun cancel(context: Context) {
            try {
                WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
                Log.d(TAG, "✅ Cancelled")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Cancel failed: ${e.message}")
            }
        }
    }

    override fun doWork(): Result {
        val prefs       = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
        val isFrozen    = prefs.getBoolean("flutter.is_timer_frozen", false)

        Log.d(TAG, "🔄 doWork — clockedIn=$isClockedIn frozen=$isFrozen serviceRunning=${LocationMonitorService.isRunning}")

        if (!isClockedIn || isFrozen) {
            Log.d(TAG, "⏭️ Not clocked in or frozen — skipping")
            return Result.success()
        }

        // NOTE: Service restart intentionally REMOVED from here.
        // Reason: calling startForegroundService() from a WorkManager Worker
        // that runs in a dying/restarting process causes:
        //   ForegroundServiceDidNotStartInTimeException (Android fatal crash)
        // because the service may not call startForeground() within 5 seconds.
        //
        // LocationMonitorService is declared START_STICKY — the OS will
        // restart it automatically when the process has stabilized.
        // BootCompletedReceiver handles the reboot case.
        // This Worker only needs to upload rows — nothing else.

        return try {
            val dbHelper = NativeDBHelper(applicationContext)
            val unposted = dbHelper.getUnpostedRows()

            if (unposted.isEmpty()) {
                Log.d(TAG, "✅ No unposted rows — nothing to upload")
                return Result.success()
            }

            Log.d(TAG, "📤 Uploading ${unposted.size} rows → $BULK_API_URL")
            val success = uploadRows(dbHelper, unposted)

            if (success) Result.success()
            else         Result.retry()

        } catch (e: Exception) {
            Log.e(TAG, "❌ doWork exception: ${e.message}")
            Result.retry()
        }
    }

    private fun uploadRows(
        dbHelper: NativeDBHelper,
        unposted: List<Map<String, String>>
    ): Boolean {
        return try {
            val records = JSONArray()
            for (row in unposted) {
                records.put(JSONObject().apply {
                    put("locationtracking_date", row["locationtracking_date"] ?: "")
                    put("locationtracking_time", row["locationtracking_time"] ?: "")
                    put("user_id",               row["user_id"]               ?: "")
                    put("company_code",          row["company_code"]          ?: "")
                    put("lat_in",  (row["lat_in"]  ?: "0").toDoubleOrNull() ?: 0.0)
                    put("lng_in",  (row["lng_in"]  ?: "0").toDoubleOrNull() ?: 0.0)
                    put("booker_name",           row["booker_name"]           ?: "")
                    put("designation",           row["designation"]           ?: "")
                })
            }
            val body = JSONObject().put("records", records).toString()

            val conn = URL(BULK_API_URL).openConnection() as HttpURLConnection
            conn.apply {
                requestMethod  = "POST"
                connectTimeout = 15_000
                readTimeout    = 30_000
                doOutput       = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Accept",       "application/json")
            }
            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(body) }
            val code = conn.responseCode
            conn.disconnect()

            if (code in 200..299) {
                val ids = unposted.mapNotNull { it["locationtracking_id"] }
                dbHelper.markPosted(ids)
                Log.d(TAG, "✅ Upload OK ($code) — marked ${ids.size} rows posted")
                true
            } else {
                Log.w(TAG, "⚠️ Upload failed HTTP $code — will retry")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Upload exception: ${e.message} — will retry")
            false
        }
    }
}