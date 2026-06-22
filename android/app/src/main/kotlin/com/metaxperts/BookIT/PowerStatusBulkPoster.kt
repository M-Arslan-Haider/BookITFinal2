package com.metaxperts.order_booking_app

// ═════════════════════════════════════════════════════════════════════════════
// PowerStatusBulkPoster
//
// Periodic WorkManager worker (every 15 min — WorkManager's minimum period for
// PeriodicWorkRequest; the heartbeat itself runs every 5 min and is purely
// local, so no data is lost between syncs).
//
// The backend endpoint inserts ONE row per call (APEX_JSON PL/SQL handler),
// so this worker loops over unsynced rows and POSTs each individually:
//
//   POST https://cloud.metaxperts.net:8443/erp/valor_trading/power_status_log/post
//   {
//     "user_id":       "...",
//     "user_name":     "...",
//     "city":          "...",
//     "designation":   "...",
//     "battery":       87.0,
//     "status":        "online",
//     "log_timestamp": "2026-06-13T14:05:00"   // matches TO_TIMESTAMP(...,'YYYY-MM-DD"T"HH24:MI:SS')
//   }
//
// The PL/SQL handler always responds with HTTP 200 (success or error are both
// wrapped in {"status": "..."}), so success is determined by reading the JSON
// body's "status" field, not just the HTTP status code.
// ═════════════════════════════════════════════════════════════════════════════

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

class PowerStatusBulkPoster(
    context: Context,
    workerParameters: WorkerParameters
) : Worker(context, workerParameters) {

    private val POST_API = "https://cloud.metaxperts.net:8443/erp/valor_trading/power_status_log/post"

    override fun doWork(): Result {
        return try {
            val dbHelper = PowerStatusDBHelper(applicationContext)
            val unposted = dbHelper.getUnpostedRows()

            if (unposted.isEmpty()) {
                android.util.Log.d("PowerStatusPoster", "⏭️ Nothing to sync")
                return Result.success()
            }

            var allOk = true
            for (row in unposted) {
                val rowId = row[PowerStatusDBHelper.COL_ID] ?: continue
                val ok = postRow(row)
                if (ok) {
                    dbHelper.markPosted(listOf(rowId))
                } else {
                    allOk = false
                    // Stop on first failure — keep remaining rows for next run,
                    // in original order (avoids reordering / hammering on a down server).
                    break
                }
            }
            dbHelper.pruneOldPosted()

            if (allOk) Result.success() else Result.retry()
        } catch (e: Exception) {
            android.util.Log.e("PowerStatusPoster", "❌ doWork error: ${e.message}")
            Result.retry()
        }
    }

    /** POST a single power-status row. Returns true only if backend reports status=="success". */
    private fun postRow(row: Map<String, String>): Boolean {
        var conn: HttpURLConnection? = null
        return try {
            val payload = JSONObject().apply {
                put("user_id",       row[PowerStatusDBHelper.COL_USER_ID]     ?: "")
                put("user_name",     row[PowerStatusDBHelper.COL_USER_NAME]   ?: "")
                put("city",          row[PowerStatusDBHelper.COL_CITY]        ?: "")
                put("designation",   row[PowerStatusDBHelper.COL_DESIGNATION] ?: "")
                put("battery",       (row[PowerStatusDBHelper.COL_BATTERY] ?: "0").toDoubleOrNull() ?: 0.0)
                put("status",        row[PowerStatusDBHelper.COL_STATUS]      ?: "online")
                put("log_timestamp", row[PowerStatusDBHelper.COL_TIMESTAMP]   ?: "")
            }.toString()

            conn = (URL(POST_API).openConnection() as HttpURLConnection).apply {
                requestMethod  = "POST"
                connectTimeout = 15_000
                readTimeout    = 30_000
                doOutput       = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Accept", "application/json")
            }

            OutputStreamWriter(conn.outputStream).use { it.write(payload) }

            val httpOk = conn.responseCode in 200..299
            val stream = if (httpOk) conn.inputStream else conn.errorStream
            val responseText = stream?.let { BufferedReader(InputStreamReader(it)).use { r -> r.readText() } } ?: ""

            // Backend always returns {"status":"success"|"error", ...} with HTTP 200,
            // so check the body even when httpOk is true.
            val backendOk = try {
                JSONObject(responseText).optString("status") == "success"
            } catch (_: Exception) {
                false
            }

            if (httpOk && backendOk) {
                android.util.Log.d("PowerStatusPoster", "✅ Row ${row[PowerStatusDBHelper.COL_ID]} synced")
                true
            } else {
                android.util.Log.w(
                    "PowerStatusPoster",
                    "⚠️ Row ${row[PowerStatusDBHelper.COL_ID]} failed — http=${conn.responseCode} body=$responseText"
                )
                false
            }
        } catch (e: Exception) {
            android.util.Log.e("PowerStatusPoster", "❌ postRow failed: ${e.message}")
            false
        } finally {
            conn?.disconnect()
        }
    }

    companion object {
        private const val WORK_NAME = "power_status_bulk_posting_work"

        fun schedule(context: Context) {
            try {
                val constraints = Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build()

                val workRequest = PeriodicWorkRequestBuilder<PowerStatusBulkPoster>(
                    15, TimeUnit.MINUTES
                )
                    .setConstraints(constraints)
                    .setInitialDelay(2, TimeUnit.MINUTES)
                    .build()

                WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                    WORK_NAME,
                    ExistingPeriodicWorkPolicy.KEEP,
                    workRequest
                )
                android.util.Log.d("PowerStatusPoster", "✅ Scheduled (15 min)")
            } catch (e: Exception) {
                android.util.Log.e("PowerStatusPoster", "Failed to schedule: ${e.message}")
            }
        }

        fun cancel(context: Context) {
            try {
                WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
            } catch (e: Exception) {
                android.util.Log.e("PowerStatusPoster", "Failed to cancel: ${e.message}")
            }
        }
    }
}