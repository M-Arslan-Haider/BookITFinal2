package com.metaxperts.order_booking_app

import android.content.Context
import android.content.Intent
import android.os.Build
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
            val prefs       = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
            val isFrozen    = prefs.getBoolean("flutter.is_timer_frozen", false)

            if (isClockedIn && !isFrozen) {

                // ✅ FIX: Agar service nahi chal rahi to WorkManager restart kare
                if (!LocationMonitorService.isRunning) {
                    android.util.Log.d("WorkManager", "🔄 Service NOT running — WorkManager attempting restart")
                    val userId = prefs.getString("flutter.userId", "") ?: ""

                    if (userId.isNotEmpty()) {
                        try {
                            val serviceIntent = Intent(applicationContext, LocationMonitorService::class.java).apply {
                                putExtra("extra_user_id",      userId)
                                putExtra("extra_booker_name",  prefs.getString("flutter.userName", "") ?: "")
                                putExtra("extra_designation",  prefs.getString("flutter.userDesignation", "") ?: "")
                                putExtra("extra_company_code", prefs.getString("flutter.companyCode", "") ?: "")
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                applicationContext.startForegroundService(serviceIntent)
                            } else {
                                applicationContext.startService(serviceIntent)
                            }
                            android.util.Log.d("WorkManager", "✅ Service restart triggered for userId=$userId")
                        } catch (e: Exception) {
                            android.util.Log.e("WorkManager", "❌ Service restart failed: ${e.message}")
                        }
                    } else {
                        android.util.Log.w("WorkManager", "⚠️ userId empty — cannot restart service")
                    }

                    // Also sync unposted rows as fallback while service is restarting
                    val dbHelper = NativeDBHelper(applicationContext)
                    val unposted = dbHelper.getUnpostedRows()
                    if (unposted.isNotEmpty()) {
                        android.util.Log.d("WorkManager", "📤 WorkManager fallback syncing ${unposted.size} rows")
                        syncToServer(dbHelper, unposted)
                    }
                } else {
                    // Service is running — it handles its own sync via heartbeat
                    android.util.Log.d("WorkManager", "⏭️ Service is running — skipping WorkManager sync (double posting prevention)")
                }
            }
            Result.success()
        } catch (e: Exception) {
            android.util.Log.e("WorkManager", "❌ WorkManager doWork error: ${e.message}")
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
                    put("user_id",      row["user_id"]      ?: "")
                    put("company_code", row["company_code"] ?: "")
                    put("lat_in",       (row["lat_in"]  ?: "0").toDoubleOrNull() ?: 0.0)
                    put("lng_in",       (row["lng_in"]  ?: "0").toDoubleOrNull() ?: 0.0)
                    put("booker_name",  row["booker_name"]  ?: "")
                    put("designation",  row["designation"]  ?: "")
                })
            }

            val body = JSONObject().put("records", records).toString()

            val url  = URL(BULK_API)
            val conn = url.openConnection() as HttpURLConnection
            conn.apply {
                requestMethod = "POST"
                connectTimeout = 15000
                readTimeout    = 30000
                doOutput       = true
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