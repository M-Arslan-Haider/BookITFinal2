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

class BulkPostingScheduler {

    companion object {
        private const val TAG = "BulkPostingScheduler"
        private const val BULK_POST_INTERVAL_MS = 60_000L
        private const val ALARM_REQUEST_CODE = 9999

        fun startBulkPostingAlarm(context: Context) {
            Log.d(TAG, "🚀 Starting bulk posting alarm (every 60 seconds)")

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, BulkPostAlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            try {
                alarmManager.cancel(pendingIntent)
            } catch (e: Exception) { }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + BULK_POST_INTERVAL_MS,
                    pendingIntent
                )
            } else {
                alarmManager.setRepeating(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + BULK_POST_INTERVAL_MS,
                    BULK_POST_INTERVAL_MS,
                    pendingIntent
                )
            }

            Log.d(TAG, "✅ Bulk posting alarm scheduled")
        }

        fun stopBulkPostingAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, BulkPostAlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
            Log.d(TAG, "🛑 Bulk posting alarm stopped")
        }
    }
}

class BulkPostAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("BulkPostAlarm", "⏰ Alarm triggered - executing bulk post")

        Thread {
            try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
                val isFrozen = prefs.getBoolean("flutter.is_timer_frozen", false)

                if (isClockedIn && !isFrozen) {
                    val dbHelper = NativeDBHelper(context)
                    val unposted = dbHelper.getUnpostedRows()

                    if (unposted.isNotEmpty()) {
                        Log.d("BulkPostAlarm", "📤 Found ${unposted.size} unposted rows - syncing...")
                        syncUnpostedRows(context, dbHelper, unposted)
                    } else {
                        Log.d("BulkPostAlarm", "✅ No unposted rows")
                    }
                }

                BulkPostingScheduler.startBulkPostingAlarm(context)

            } catch (e: Exception) {
                Log.e("BulkPostAlarm", "❌ Error: ${e.message}")
                BulkPostingScheduler.startBulkPostingAlarm(context)
            }
        }.start()
    }

    private fun syncUnpostedRows(context: Context, dbHelper: NativeDBHelper, unposted: List<Map<String, String>>) {
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
                    put("posted", false)
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
                setRequestProperty("Accept", "application/json")
            }

            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(body) }

            val responseCode = conn.responseCode
            conn.disconnect()

            if (responseCode in 200..299) {
                val ids = unposted.mapNotNull { it["locationtracking_id"] }
                dbHelper.markPosted(ids)
                Log.d("BulkPostAlarm", "✅ Bulk POST OK - marked ${ids.size} rows posted")
            } else {
                Log.d("BulkPostAlarm", "⚠️ Bulk POST failed ($responseCode)")
            }
        } catch (e: Exception) {
            Log.e("BulkPostAlarm", "❌ Bulk POST exception: ${e.message}")
        }
    }
}