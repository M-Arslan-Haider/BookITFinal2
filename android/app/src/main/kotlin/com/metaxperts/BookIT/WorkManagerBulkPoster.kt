package com.metaxperts.order_booking_app

import android.content.Context
import androidx.work.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

class WorkManagerBulkPoster(
    context: Context,
    private val workerParameters: WorkerParameters
) : Worker(context, workerParameters) {

    override fun doWork(): Result {
        return try {
            val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
            val isFrozen = prefs.getBoolean("flutter.is_timer_frozen", false)

            if (isClockedIn && !isFrozen) {
                val dbHelper = NativeDBHelper(applicationContext)
                val unposted = dbHelper.getUnpostedRows()

                if (unposted.isNotEmpty()) {
                    syncToServer(dbHelper, unposted)
                }
            }
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }

    private fun syncToServer(dbHelper: NativeDBHelper, unposted: List<Map<String, String>>) {
        val BULK_API = "http://103.149.33.102:8001/location/bulk"

        try {
            val records = JSONArray()
            for (row in unposted) {
                records.put(JSONObject().apply {
                    put("locationtracking_date", row["locationtracking_date"] ?: "")
                    put("locationtracking_time", row["locationtracking_time"] ?: "")
                    put("user_id", row["user_id"] ?: "")
                    put("company_code", row["company_code"] ?: "")
                    put("lat_in", (row["lat_in"] ?: "0").toDoubleOrNull() ?: 0.0)
                    put("lng_in", (row["lng_in"] ?: "0").toDoubleOrNull() ?: 0.0)
                    put("booker_name", row["booker_name"] ?: "")
                    put("designation", row["designation"] ?: "")
                })
            }

            val body = JSONObject().put("records", records).toString()

            val url = URL(BULK_API)
            val conn = url.openConnection() as HttpURLConnection
            conn.apply {
                requestMethod = "POST"
                connectTimeout = 15000
                readTimeout = 30000
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
            }

            OutputStreamWriter(conn.outputStream).use { it.write(body) }

            if (conn.responseCode in 200..299) {
                val ids = unposted.mapNotNull { it["locationtracking_id"] }
                dbHelper.markPosted(ids)
                android.util.Log.d("WorkManager", "✅ Synced ${ids.size} rows")
            }
            conn.disconnect()
        } catch (e: Exception) {
            android.util.Log.e("WorkManager", "Sync failed: ${e.message}")
        }
    }

    companion object {
        fun schedule(context: Context) {
            try {
                val constraints = Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build()

                val workRequest = PeriodicWorkRequestBuilder<WorkManagerBulkPoster>(
                    15, TimeUnit.MINUTES
                )
                    .setConstraints(constraints)
                    .setInitialDelay(5, TimeUnit.MINUTES)
                    .build()

                WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                    "bulk_posting_work",
                    ExistingPeriodicWorkPolicy.KEEP,
                    workRequest
                )

                android.util.Log.d("WorkManager", "✅ WorkManager scheduled (15 min fallback)")
            } catch (e: Exception) {
                android.util.Log.e("WorkManager", "Failed to schedule: ${e.message}")
            }
        }

        fun cancel(context: Context) {
            try {
                WorkManager.getInstance(context).cancelUniqueWork("bulk_posting_work")
            } catch (e: Exception) {
                android.util.Log.e("WorkManager", "Failed to cancel: ${e.message}")
            }
        }
    }
}