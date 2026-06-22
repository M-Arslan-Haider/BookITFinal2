package com.metaxperts.order_booking_app

import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.BatteryManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.security.SecureRandom
import java.security.cert.X509Certificate
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager
import java.text.SimpleDateFormat
import java.util.*

class BatteryMonitorService : Service() {

    companion object {
        private const val CHANNEL_ID = "battery_monitor_channel"
        private const val NOTIFICATION_ID = 2001
        private const val API_URL = "https://cloud.metaxperts.net:8443/erp/valor_trading/battery_api/post"

        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_IS_CLOCKED_IN = "flutter.isClockedIn"
        private const val KEY_USER_ID = "flutter.userId"
        private const val KEY_USER_NAME = "flutter.userName"
        private const val KEY_DESIGNATION = "flutter.userDesignation"
        private const val KEY_COMPANY_CODE = "flutter.companyCode"
        private const val KEY_LAT = "flutter.last_latitude"
        private const val KEY_LNG = "flutter.last_longitude"

        @Volatile
        var isRunning = false
            private set

        fun start(context: Context) {
            val intent = Intent(context, BatteryMonitorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, BatteryMonitorService::class.java))
        }
    }

    private lateinit var repository: BatteryRepository
    private var lastTriggeredPercent = -1
    private var lastTriggeredTimestamp = 0L
    private val TRIGGER_COOLDOWN_MS = 60000L
    private val TARGET_BATTERY_PERCENT = 3

    private fun disableSSLCertificateChecking() {
        try {
            val trustAllCerts = arrayOf<TrustManager>(object : X509TrustManager {
                override fun checkClientTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
                override fun checkServerTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
                override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
            })
            val sc = SSLContext.getInstance("TLS")
            sc.init(null, trustAllCerts, SecureRandom())
            HttpsURLConnection.setDefaultSSLSocketFactory(sc.socketFactory)
            HttpsURLConnection.setDefaultHostnameVerifier { _, _ -> true }
        } catch (e: Exception) {
            Log.e("BatteryMonitor", "SSL fix error: ${e.message}")
        }
    }

    private val batteryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_BATTERY_CHANGED) {
                val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                val percent = if (scale > 0) (level * 100 / scale) else -1

                Log.d("BatteryMonitor", "🔋 Battery level: $percent%")

                if (percent == TARGET_BATTERY_PERCENT && percent != lastTriggeredPercent) {
                    val now = System.currentTimeMillis()
                    if (now - lastTriggeredTimestamp > TRIGGER_COOLDOWN_MS) {
                        lastTriggeredPercent = percent
                        lastTriggeredTimestamp = now
                        handleLowBattery()
                    }
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        repository = BatteryRepository(this)
        disableSSLCertificateChecking()
        Log.d("BatteryMonitor", "✅ Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()

        // ✅ FIX: Use LOCATION type instead of DATA_SYNC (already have permission)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, buildNotification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, buildNotification())
        }

        val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        registerReceiver(batteryReceiver, filter)

        Log.d("BatteryMonitor", "✅ Service started")
        return START_STICKY
    }

    private fun handleLowBattery() {
        Log.d("BatteryMonitor", "⚠️ BATTERY AT $TARGET_BATTERY_PERCENT% - Saving data!")

        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)

        val isClockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
        if (!isClockedIn) {
            Log.d("BatteryMonitor", "⏭️ Not clocked in — skipping")
            return
        }

        val userId = prefs.getString(KEY_USER_ID, "") ?: ""
        if (userId.isEmpty()) {
            Log.d("BatteryMonitor", "⏭️ UserId empty — skipping")
            return
        }

        val userName = prefs.getString(KEY_USER_NAME, "") ?: ""
        val designation = prefs.getString(KEY_DESIGNATION, "") ?: ""
        val companyCode = prefs.getString(KEY_COMPANY_CODE, "") ?: ""
        val lat = prefs.getString(KEY_LAT, "0.0") ?: "0.0"
        val lng = prefs.getString(KEY_LNG, "0.0") ?: "0.0"

        if (repository.hasTodayEvent(userId)) {
            Log.d("BatteryMonitor", "⏭️ Already saved today — skipping")
            return
        }

        val now = Date()
        val sdf = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
        val detectTimeStr = sdf.format(now)

        val id = repository.insertBatteryEvent(
            userId = userId,
            userName = userName,
            designation = designation,
            companyCode = companyCode,
            latIn = lat.toDoubleOrNull() ?: 0.0,
            lngIn = lng.toDoubleOrNull() ?: 0.0,
            batteryPercent = TARGET_BATTERY_PERCENT,
            detectTime = detectTimeStr
        )

        if (id > 0) {
            Log.d("BatteryMonitor", "✅ Battery event saved! ID=$id")
            tryPostToServer()
        }
    }

    private fun tryPostToServer() {
        Thread {
            try {
                val unposted = repository.getUnpostedEvents()
                if (unposted.isEmpty()) return@Thread

                val successIds = mutableListOf<Long>()
                for (event in unposted) {
                    if (postToServer(event)) {
                        successIds.add(event.id)
                    }
                }

                if (successIds.isNotEmpty()) {
                    repository.markAsPosted(successIds)
                    Log.d("BatteryMonitor", "✅ Posted ${successIds.size} events")
                }
            } catch (e: Exception) {
                Log.e("BatteryMonitor", "Post failed: ${e.message}")
            }
        }.start()
    }

    private fun postToServer(event: BatteryRepository.BatteryLowEvent): Boolean {
        return try {
            val url = URL(API_URL)
            val conn = url.openConnection() as HttpsURLConnection

            conn.apply {
                requestMethod = "POST"
                connectTimeout = 15000
                readTimeout = 30000
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
            }

            val json = JSONObject().apply {
                put("user_id", event.userId)
                put("user_name", event.userName)
                put("designation", event.designation)
                put("company_code", event.companyCode)
                put("lat_in", event.latIn)
                put("lng_in", event.lngIn)
                put("battery", event.battery)
                put("detect_time", event.detectTime)
                put("device_type", "android")
            }

            OutputStreamWriter(conn.outputStream).use { it.write(json.toString()) }
            val success = conn.responseCode in 200..299
            conn.disconnect()
            success
        } catch (e: Exception) {
            Log.e("BatteryMonitor", "Post error: ${e.message}")
            false
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Battery Monitor", NotificationManager.IMPORTANCE_LOW)
            channel.setShowBadge(false)
            channel.enableVibration(false)
            channel.enableLights(false)
            channel.setSound(null, null)
            channel.setDescription("Runs in background to monitor battery")
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(this, 0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("")  // Empty - still required but hidden
            .setContentText("")   // Empty - still required but hidden
            .setSmallIcon(android.R.drawable.ic_menu_agenda)  // Minimal icon
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setSilent(true)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    override fun onDestroy() {
        isRunning = false
        try { unregisterReceiver(batteryReceiver) } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}