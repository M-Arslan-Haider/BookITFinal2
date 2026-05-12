//
//
/////09-05-2026
//package com.metaxperts.order_booking_app
//
//import android.Manifest
//import android.app.AlarmManager
//import android.app.AppOpsManager
//import android.app.Notification
//import android.app.NotificationChannel
//import android.app.NotificationManager
//import android.app.PendingIntent
//import android.app.Service
//import android.content.BroadcastReceiver
//import android.content.Context
//import android.content.Intent
//import android.content.IntentFilter
//import android.content.pm.PackageManager
//import android.content.pm.ServiceInfo
//import android.location.Location
//import android.location.LocationListener
//import android.location.LocationManager as SysLocationManager
//import android.net.ConnectivityManager
//import android.net.Network
//import android.net.NetworkCapabilities
//import android.net.NetworkRequest
//import android.os.Build
//import android.os.Bundle
//import android.os.Handler
//import android.os.IBinder
//import android.os.Looper
//import android.os.PowerManager
//import android.provider.Settings
//import androidx.core.app.NotificationCompat
//import androidx.core.content.ContextCompat
//import org.eclipse.paho.client.mqttv3.IMqttDeliveryToken
//import org.eclipse.paho.client.mqttv3.MqttCallback
//import org.eclipse.paho.client.mqttv3.MqttClient
//import org.eclipse.paho.client.mqttv3.MqttConnectOptions
//import org.eclipse.paho.client.mqttv3.MqttMessage
//import org.eclipse.paho.client.mqttv3.persist.MemoryPersistence
//import android.content.ContentValues
//import android.database.sqlite.SQLiteDatabase
//import android.database.sqlite.SQLiteOpenHelper
//import org.json.JSONArray
//import org.json.JSONObject
//import java.io.OutputStreamWriter
//import java.net.HttpURLConnection
//import java.net.URL
//import java.text.SimpleDateFormat
//import java.util.Date
//import java.util.Locale
//import java.util.UUID
//import java.util.concurrent.Executors
//
//class LocationMonitorService : Service() {
//
//    // ─── Constants ───────────────────────────────────────────────────────────
//    private val CHANNEL_ID            = "location_monitor_channel"
//    private val URGENT_CHANNEL_ID     = "urgent_auto_clockout_channel"
//    private val NOTIFICATION_ID       = 1001
//    private val WORKING_NOTIFICATION_ID = 1002  // Working timer notification
//    private val CHECK_INTERVAL        = 2_000L
//    private val MQTT_PUBLISH_INTERVAL = 5_000L
//    private val MQTT_RECONNECT_DELAY  = 10_000L
//    private val WAKELOCK_TIMEOUT_MS   = 12 * 60 * 60 * 1000L  // 12 hours
//    private val WATCHDOG_INTERVAL     = 30_000L
//    private val GPS_HEARTBEAT_TIMEOUT = 60_000L
//
//    // MQTT Broker
//    private val MQTT_HOST    = "119.153.102.7"
//    private val MQTT_PORT    = 1883
//    private val COMPANY_CODE = "PK-PUN-SKT-MX01-VT001"
//
//    // SharedPreferences keys (Flutter prefix)
//    private val PREFS_NAME              = "FlutterSharedPreferences"
//    private val KEY_IS_CLOCKED_IN       = "flutter.isClockedIn"
//    private val KEY_HAS_CRITICAL_EVENT  = "flutter.has_critical_event_pending"
//    private val KEY_EVENT_TIMESTAMP     = "flutter.critical_event_timestamp"
//    private val KEY_EVENT_REASON        = "flutter.critical_event_reason"
//    private val KEY_EVENT_DISTANCE      = "flutter.critical_event_distance"
//    private val KEY_EVENT_LAT           = "flutter.critical_event_latitude"
//    private val KEY_EVENT_LNG           = "flutter.critical_event_longitude"
//    private val KEY_IS_TIMER_FROZEN     = "flutter.is_timer_frozen"
//    private val KEY_FROZEN_TIME         = "flutter.frozen_display_time"
//    private val KEY_ELAPSED_TIME        = "flutter.elapsed_time"
//    private val KEY_BG_CLOCKOUT_PAYLOAD = "flutter.bg_clockout_payload"
//
//    private val EXTRA_USER_ID      = "extra_user_id"
//    private val EXTRA_BOOKER_NAME  = "extra_booker_name"
//    private val EXTRA_DESIGNATION  = "extra_designation"
//    private val EXTRA_COMPANY_CODE = "extra_company_code"
//
//    // ─── State ───────────────────────────────────────────────────────────────
//    private lateinit var handler: Handler
//    private var gpsThread: android.os.HandlerThread? = null
//    private var gpsLooper: Looper? = null
//
//    private var checkRunnable:         CheckRunnable?        = null
//    private var mqttPublishRunnable:   MqttPublishRunnable?  = null
//    private var mqttReconnectRunnable: Runnable?             = null
//    private var locationPostRunnable:  LocationPostRunnable? = null
//
//    private val mqttExecutor = Executors.newSingleThreadExecutor { r ->
//        Thread(r, "MqttWorkerThread").apply { isDaemon = true }
//    }
//
//    @Volatile private var isDestroyed     = false
//    @Volatile private var isMqttConnected = false
//
//    private var wasLocationEnabled   = true
//    private var wasPermissionGranted = true
//    private var isClockedIn          = false
//    private var lastEventTime: Long  = 0
//    private var lastEventReason      = ""
//    private var serviceStartTime: Date = Date()
//
//    private var wakeLock: PowerManager.WakeLock? = null
//
//    // ✅ NEW: CPU WakeLock for heartbeat
//    private var cpuWakeLock: PowerManager.WakeLock? = null
//    private var heartbeatRunnable: Runnable? = null
//    private var lastSuccessfulPostTime = 0L
//
//    // Working timer — Kotlin side pe timer rakho (Flutter isolate kill hone pe bhi survive kare)
//    private var workingTimerRunnable: Runnable? = null
//    private var workingSeconds = 0L
//
//    // Identity
//    private var userId      = ""
//    private var bookerName  = ""
//    private var designation = ""
//    private var companyCode = ""
//
//    // Location
//    private var locationManager: SysLocationManager? = null
//    private var locationListener: LocationListener?  = null
//    @Volatile private var lastLat      = 0.0
//    @Volatile private var lastLon      = 0.0
//    @Volatile private var lastSavedLat  = 0.0
//    @Volatile private var lastSavedLon  = 0.0
//    @Volatile private var lastSavedTime = 0L
//    private val recentFixes = ArrayDeque<android.location.Location>(3)
//    @Volatile private var lastAccuracy = 0f
//    @Volatile private var lastSpeed    = 0f
//    private var lastHeartbeatTime: Long = 0
//
//    // MQTT
//    private var mqttClient: MqttClient? = null
//    private var mqttPublishCount = 0
//    private val mqttTopic get() = "gps/$companyCode/$userId"
//
//    // AppOps
//    private var appOpsManager: AppOpsManager? = null
//    private var appOpsCallback: AppOpsManager.OnOpChangedListener? = null
//
//    // Network connectivity
//    private var connectivityManager: ConnectivityManager? = null
//    private var networkCallback: ConnectivityManager.NetworkCallback? = null
//
//    // ─── Named inner Runnables ────────────────────────────────────────────────
//
//    inner class CheckRunnable : Runnable {
//        override fun run() {
//            if (isDestroyed) return
//            checkLocationAndPermission()
//            handler.postDelayed(this, CHECK_INTERVAL)
//        }
//    }
//
//    inner class MqttPublishRunnable : Runnable {
//        override fun run() {
//            if (isDestroyed) return
//            publishLocationToMqtt()
//            handler.postDelayed(this, MQTT_PUBLISH_INTERVAL)
//        }
//    }
//
//    inner class LocationPostRunnable : Runnable {
//        override fun run() {
//            if (isDestroyed) return
//            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//            if (prefs.getBoolean(KEY_IS_CLOCKED_IN, false) &&
//                !prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) {
//                mqttExecutor.submit { postLocationToServer(prefs) }
//            }
//            if (!isDestroyed) handler.postDelayed(this, 2 * 60_000L)
//        }
//    }
//
//    // ─── Companion (start / stop helpers) ────────────────────────────────────
//    companion object {
//        fun start(
//            context: Context,
//            userId: String = "",
//            bookerName: String = "",
//            designation: String = "",
//            companyCode: String = ""
//        ) {
//            val intent = Intent(context, LocationMonitorService::class.java).apply {
//                putExtra("extra_user_id",      userId)
//                putExtra("extra_booker_name",  bookerName)
//                putExtra("extra_designation",  designation)
//                putExtra("extra_company_code", companyCode)
//            }
//            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
//                context.startForegroundService(intent)
//            else
//                context.startService(intent)
//        }
//
//        fun stop(context: Context) {
//            context.stopService(Intent(context, LocationMonitorService::class.java))
//        }
//    }
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // Lifecycle
//    // ═════════════════════════════════════════════════════════════════════════
//
//    override fun onCreate() {
//        super.onCreate()
//        handler = Handler(Looper.getMainLooper())
//
//        try {
//            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
//            wakeLock = pm.newWakeLock(
//                PowerManager.PARTIAL_WAKE_LOCK,
//                "BookIT::LocationServiceWakeLock"
//            )
//            wakeLock?.acquire(WAKELOCK_TIMEOUT_MS)
//            debugPrint("✅ [Service] WakeLock acquired (12h)")
//        } catch (e: Exception) {
//            debugPrint("⚠️ [Service] WakeLock failed: ${e.message}")
//        }
//
//        registerReceivers()
//        registerAppOpsListener()
//        registerNetworkCallback()
//        debugPrint("✅ [Service] onCreate complete")
//    }
//
//    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
//        createNotificationChannel()
//        serviceStartTime = Date()
//
//        try {
//            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
//                startForeground(
//                    NOTIFICATION_ID,
//                    buildNotification(),
//                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
//                )
//            } else {
//                startForeground(NOTIFICATION_ID, buildNotification())
//            }
//        } catch (e: Exception) {
//            debugPrint("⚠️ [Service] startForeground failed: ${e.message}")
//            stopSelf()
//            return START_NOT_STICKY
//        }
//
//        wasLocationEnabled   = isLocationEnabled()
//        wasPermissionGranted = checkLocationPermission()
//
//        val prefs     = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//        val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//
//        lastSavedLat  = prefs.getFloat("flutter.lastSavedLat",  0f).toDouble()
//        lastSavedLon  = prefs.getFloat("flutter.lastSavedLon",  0f).toDouble()
//        lastSavedTime = prefs.getLong("flutter.lastSavedTime", 0L)
//
//        if (lastSavedLat != 0.0 || lastSavedLon != 0.0) {
//            lastLat = lastSavedLat
//            lastLon = lastSavedLon
//            debugPrint("📍 [Service] lastLat/Lon pre-filled from prefs: $lastLat, $lastLon")
//        }
//
//        val intentUserId = intent?.getStringExtra(EXTRA_USER_ID)?.takeIf { it.isNotEmpty() }
//        if (intentUserId != null) {
//            userId      = intentUserId
//            bookerName  = intent.getStringExtra(EXTRA_BOOKER_NAME)  ?: ""
//            designation = intent.getStringExtra(EXTRA_DESIGNATION)   ?: ""
//            companyCode = intent.getStringExtra(EXTRA_COMPANY_CODE)
//                ?.takeIf { it.isNotEmpty() } ?: COMPANY_CODE
//            prefs.edit()
//                .putString("flutter.userId",          userId)
//                .putString("flutter.userName",        bookerName)
//                .putString("flutter.userDesignation", designation)
//                .putString("flutter.companyCode",     companyCode)
//                .apply()
//            debugPrint("👤 [Service] Identity from Intent → userId=$userId")
//        } else {
//            userId      = getStringPref(prefs, "flutter.userId", "userId")
//            bookerName  = getStringPref(prefs, "flutter.userName", "userName", "booker_name")
//            designation = getStringPref(prefs, "flutter.userDesignation", "userDesignation", "designation")
//            companyCode = prefs.getString("flutter.companyCode", "")
//                ?.takeIf { it.isNotEmpty() } ?: COMPANY_CODE
//            debugPrint("👤 [Service] Identity from prefs → userId=$userId")
//        }
//
//        if (clockedIn && !isFrozen) {
//            if (!wasPermissionGranted) {
//                handler.post { handleCriticalEvent("System ClockOut - Permission Revoked") }
//                return START_STICKY
//            }
//            if (!wasLocationEnabled) {
//                handler.post { handleCriticalEvent("System ClockOut - Location Off") }
//                return START_STICKY
//            }
//        }
//
//        // ✅ Restore working timer from clockIn time (service restart ke baad bhi sahi time dikhe)
//        if (clockedIn && !isFrozen) {
//            val clockInTimeStr = prefs.getString("flutter.clockInTime", "") ?: ""
//            if (clockInTimeStr.isNotEmpty()) {
//                try {
//                    val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
//                    val clockInDate = sdf.parse(clockInTimeStr)
//                    if (clockInDate != null) {
//                        workingSeconds = (System.currentTimeMillis() - clockInDate.time) / 1000
//                        if (workingSeconds < 0) workingSeconds = 0
//                        debugPrint("⏱️ [Timer] Restored workingSeconds=$workingSeconds from clockInTime=$clockInTimeStr")
//                    }
//                } catch (e: Exception) {
//                    workingSeconds = 0
//                    debugPrint("⚠️ [Timer] clockInTime parse failed: ${e.message}")
//                }
//            }
//        }
//
//        startMonitoring()
//
//        // ✅ NEW: Start backup systems when clocked in
//        if (clockedIn && !isFrozen) {
//            BulkPostingScheduler.startBulkPostingAlarm(this)
//            try {
//                WorkManagerBulkPoster.schedule(this)
//            } catch (e: Exception) {
//                debugPrint("⚠️ [Service] WorkManager not available: ${e.message}")
//            }
//            debugPrint("✅ [Service] Backup systems started: AlarmManager + WorkManager")
//        }
//
//        return START_STICKY
//    }
//
//    override fun onTaskRemoved(rootIntent: Intent?) {
//        super.onTaskRemoved(rootIntent)
//        debugPrint("🔄 [Service] App removed from recents — scheduling restart")
//
//        val prefs     = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//        val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//
//        if (clockedIn && !isFrozen) scheduleServiceRestart()
//    }
//
//    override fun onDestroy() {
//        isDestroyed = true
//
//        val prefs     = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//        val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//
//        if (clockedIn && !isFrozen) {
//            val permRevoked = !checkLocationPermission()
//            val locOff      = !isLocationEnabled()
//            if (permRevoked || locOff) {
//                val reason = if (permRevoked)
//                    "System ClockOut - Permission Revoked"
//                else
//                    "System ClockOut - Location Off"
//                saveCriticalEventToPrefs(prefs, reason)
//            } else {
//                debugPrint("🔄 [Service] onDestroy while clocked in — scheduling restart (old device fix)")
//                scheduleServiceRestart()
//            }
//        }
//
//        stopAllLoops()
//        disconnectMqtt()
//        unregisterAppOpsListener()
//        unregisterNetworkCallback()
//
//        try { unregisterReceiver(locationModeReceiver)   } catch (_: Exception) {}
//        try { unregisterReceiver(packageReceiver)        } catch (_: Exception) {}
//        try { unregisterReceiver(screenReceiver)         } catch (_: Exception) {}
//        try { unregisterReceiver(dateTimeChangeReceiver) } catch (_: Exception) {}
//
//        try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (_: Exception) {}
//        try { if (cpuWakeLock?.isHeld == true) cpuWakeLock?.release() } catch (_: Exception) {}
//
//        mqttExecutor.shutdown()
//
//        super.onDestroy()
//        debugPrint("🛑 [Service] onDestroy complete")
//    }
//
//    override fun onBind(intent: Intent?): IBinder? = null
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // Monitoring startup / teardown
//    // ═════════════════════════════════════════════════════════════════════════
//
//    private fun startMonitoring() {
//        startLocationUpdates()
//
//        checkRunnable = CheckRunnable()
//        handler.post(checkRunnable!!)
//
//        startMqttPublishing()
//
//        debugPrint("✅ [Service] All loops started (GPS every 2s, MQTT every 5s)")
//        startHttpPostLoop()
//
//        // ✅ NEW: Start heartbeat for regular bulk sync
//        startHeartbeat()
//
//        // ✅ Start working timer — Kotlin side (all devices pe survive karta hai)
//        startWorkingTimer()
//
//        // ✅ FIX: Doze-proof keep-alive — har 15 min ek alarm reschedule karo
//        // Jab device Doze se bahar aata hai yeh alarm fire hoga aur service alive confirm karega
//        scheduleKeepAliveAlarm()
//    }
//
//    private fun scheduleKeepAliveAlarm() {
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//        val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//        if (!clockedIn || isFrozen) return
//
//        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
//        val keepAliveIntent = Intent(applicationContext, ServiceRestartReceiver::class.java).apply {
//            action = ServiceRestartReceiver.ACTION_RESTART_SERVICE
//        }
//        val pIntent = PendingIntent.getBroadcast(
//            applicationContext,
//            99,  // unique request code for keep-alive
//            keepAliveIntent,
//            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
//        )
//        // 15 minute baad fire hoga — agar service zinda hai toh onStartCommand phir se run
//        // hoga lekin koi harm nahi (idempotent) — agar service mari hai toh restart ho jaayegi
//        val triggerAt = android.os.SystemClock.elapsedRealtime() + 15 * 60 * 1000L
//        try {
//            when {
//                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && am.canScheduleExactAlarms() ->
//                    am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pIntent)
//                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
//                    am.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pIntent)
//                else ->
//                    am.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pIntent)
//            }
//            debugPrint("✅ [KeepAlive] 15-min alarm set — Doze-proof watchdog")
//        } catch (e: Exception) {
//            debugPrint("⚠️ [KeepAlive] Alarm failed: ${e.message}")
//        }
//    }
//
//    // ✅ NEW: Start heartbeat for CPU wake and bulk sync
//    private fun startHeartbeat() {
//        heartbeatRunnable = object : Runnable {
//            override fun run() {
//                if (isDestroyed) return
//
//                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//                val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//                val isFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//
//                if (clockedIn && !isFrozen) {
//                    acquireCpuWakeLock()
//
//                    mqttExecutor.submit {
//                        syncUnpostedRows()
//                        debugPrint("💓 [Heartbeat] Bulk sync executed")
//                    }
//                }
//
//                if (!isDestroyed) {
//                    handler.postDelayed(this, 30_000L)
//                }
//            }
//        }
//        handler.postDelayed(heartbeatRunnable!!, 30_000L)
//        debugPrint("✅ [Heartbeat] Started (30s interval)")
//    }
//
//    // ✅ NEW: Acquire CPU wake lock
//    private fun acquireCpuWakeLock() {
//        try {
//            if (cpuWakeLock == null) {
//                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
//                cpuWakeLock = pm.newWakeLock(
//                    PowerManager.PARTIAL_WAKE_LOCK,
//                    "BookIT::CpuHeartbeatLock"
//                )
//            }
//            if (cpuWakeLock?.isHeld != true) {
//                cpuWakeLock?.acquire(10_000L)
//                debugPrint("✅ [WakeLock] CPU lock acquired")
//            }
//        } catch (e: Exception) {
//            debugPrint("⚠️ [WakeLock] Failed: ${e.message}")
//        }
//    }
//
//    private fun startHttpPostLoop() {
//        handler.post(object : Runnable {
//            override fun run() {
//                if (isDestroyed) return
//                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//                val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//                val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//
//                if (clockedIn && !isFrozen) {
//                    mqttExecutor.submit { postLocationToServer(prefs) }
//                }
//                handler.postDelayed(this, 15_000L)
//            }
//        })
//    }
//
//    private fun stopAllLoops() {
//        checkRunnable?.let        { handler.removeCallbacks(it) }
//        mqttPublishRunnable?.let  { handler.removeCallbacks(it) }
//        mqttReconnectRunnable?.let{ handler.removeCallbacks(it) }
//        locationPostRunnable?.let { handler.removeCallbacks(it) }
//        heartbeatRunnable?.let    { handler.removeCallbacks(it) }  // ✅ NEW
//        workingTimerRunnable?.let { handler.removeCallbacks(it) }  // Working timer
//        // ✅ FIX: Working notification explicitly cancel karo clockout pe
//        try { (getSystemService(NotificationManager::class.java)).cancel(WORKING_NOTIFICATION_ID) } catch (_: Exception) {}
//        handler.removeCallbacksAndMessages(null)
//        stopLocationUpdates()
//    }
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // GPS Location Updates
//    // ═════════════════════════════════════════════════════════════════════════
//
//    private fun startLocationUpdates() {
//        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
//            != PackageManager.PERMISSION_GRANTED &&
//            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION)
//            != PackageManager.PERMISSION_GRANTED) return
//
//        try {
//            if (locationListener != null) return
//            locationManager = getSystemService(Context.LOCATION_SERVICE) as SysLocationManager
//
//            locationListener = object : LocationListener {
//                override fun onLocationChanged(loc: Location) {
//                    if (loc.accuracy > 100f) return
//
//                    synchronized(recentFixes) {
//                        if (recentFixes.size >= 3) recentFixes.removeFirst()
//                        recentFixes.addLast(loc)
//                    }
//                    val fixes  = synchronized(recentFixes) { recentFixes.toList() }
//                    val totalW = fixes.sumOf { 1.0 / it.accuracy }
//                    val smoothLat = fixes.sumOf { (1.0 / it.accuracy) * it.latitude  } / totalW
//                    val smoothLon = fixes.sumOf { (1.0 / it.accuracy) * it.longitude } / totalW
//
//                    lastLat           = smoothLat
//                    lastLon           = smoothLon
//                    lastAccuracy      = loc.accuracy
//                    lastSpeed         = loc.speed
//                    lastHeartbeatTime = System.currentTimeMillis()
//                }
//                @Deprecated("Deprecated in API level 29")
//                override fun onStatusChanged(p: String?, s: Int, e: Bundle?) {}
//                override fun onProviderEnabled(p: String) {}
//                override fun onProviderDisabled(p: String) {}
//            }
//
//            gpsThread = android.os.HandlerThread("gps-callback-thread").also { it.start() }
//            gpsLooper = gpsThread!!.looper
//
//            listOf(SysLocationManager.GPS_PROVIDER, SysLocationManager.NETWORK_PROVIDER)
//                .forEach { provider ->
//                    try {
//                        if (locationManager?.isProviderEnabled(provider) == true) {
//                            locationManager?.requestLocationUpdates(
//                                provider,
//                                2_000L,
//                                0f,
//                                locationListener!!, gpsLooper!!
//                            )
//                        }
//                    } catch (_: Exception) {}
//                }
//            debugPrint("✅ [GPS] Location updates started")
//        } catch (e: Exception) {
//            debugPrint("⚠️ [GPS] startLocationUpdates failed: ${e.message}")
//        }
//    }
//
//    private fun stopLocationUpdates() {
//        try { locationListener?.let { locationManager?.removeUpdates(it) } } catch (_: Exception) {}
//        locationListener = null
//        gpsThread?.quitSafely()
//        gpsThread = null
//        gpsLooper = null
//    }
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // MQTT — Connect / Publish / Reconnect
//    // ═════════════════════════════════════════════════════════════════════════
//
//    private fun connectMqtt() {
//        if (isMqttConnected) return
//        mqttExecutor.submit {
//            if (isDestroyed || isMqttConnected) return@submit
//            try {
//                val clientId = "android_${userId}_${System.currentTimeMillis()}"
//                val client   = MqttClient(
//                    "tcp://$MQTT_HOST:$MQTT_PORT",
//                    clientId,
//                    MemoryPersistence()
//                )
//                val opts = MqttConnectOptions().apply {
//                    isCleanSession       = true
//                    connectionTimeout    = 10
//                    keepAliveInterval    = 30
//                    isAutomaticReconnect = false
//                }
//                client.setCallback(object : MqttCallback {
//                    override fun connectionLost(cause: Throwable?) {
//                        debugPrint("⚠️ [MQTT] Connection lost: ${cause?.message}")
//                        isMqttConnected = false
//                        handler.post {
//                            updateNotification("❌ MQTT connection lost — retrying…", false)
//                            scheduleReconnect()
//                        }
//                    }
//                    override fun messageArrived(topic: String?, msg: MqttMessage?) {}
//                    override fun deliveryComplete(token: IMqttDeliveryToken?) {}
//                })
//                client.connect(opts)
//                mqttClient      = client
//                isMqttConnected = true
//                handler.post { updateNotification("✅ MQTT connected — waiting for GPS…", false) }
//                debugPrint("✅ [MQTT] Connected → tcp://$MQTT_HOST:$MQTT_PORT | topic=$mqttTopic")
//            } catch (e: Exception) {
//                debugPrint("❌ [MQTT] Connect failed: ${e.message}")
//                isMqttConnected = false
//                handler.post {
//                    updateNotification("❌ MQTT connect failed — retrying in 10s…", false)
//                    scheduleReconnect()
//                }
//            }
//        }
//    }
//
//    private fun disconnectMqtt() {
//        mqttReconnectRunnable?.let { handler.removeCallbacks(it) }
//        mqttReconnectRunnable = null
//        mqttPublishRunnable?.let { handler.removeCallbacks(it) }
//        mqttPublishRunnable = null
//        mqttExecutor.submit {
//            try {
//                if (mqttClient?.isConnected == true) mqttClient?.disconnect(0)
//            } catch (_: Exception) {}
//            mqttClient      = null
//            isMqttConnected = false
//            debugPrint("🛑 [MQTT] Disconnected")
//        }
//    }
//
//    private fun scheduleReconnect() {
//        if (isDestroyed) return
//        mqttReconnectRunnable?.let { handler.removeCallbacks(it) }
//        mqttReconnectRunnable = Runnable {
//            if (!isDestroyed && !isMqttConnected) {
//                debugPrint("🔄 [MQTT] Reconnecting…")
//                connectMqtt()
//            }
//        }
//        handler.postDelayed(mqttReconnectRunnable!!, MQTT_RECONNECT_DELAY)
//    }
//
//    private fun publishLocationToMqtt() {
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        if (!prefs.getBoolean(KEY_IS_CLOCKED_IN, false)) return
//        if (prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) return
//        if (lastLat == 0.0 && lastLon == 0.0) {
//            debugPrint("⚠️ [MQTT] No GPS fix yet, skipping")
//            updateNotification("⏳ Waiting for GPS fix…", false)
//            return
//        }
//
//        val lat       = lastLat
//        val lon       = lastLon
//        val accuracy  = lastAccuracy
//        val speed     = lastSpeed
//        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date())
//
//        val payload = JSONObject().apply {
//            put("device_id",    userId)
//            put("company_code", companyCode.ifEmpty { COMPANY_CODE })
//            put("emp_name",     bookerName)
//            put("dept_id",      designation)
//            put("lat",          lat)
//            put("lon",          lon)
//            put("accuracy",     accuracy)
//            put("speed",        speed)
//            put("track_id",     System.currentTimeMillis())
//            put("timestamp",    timestamp)
//            put("source",       "android_background_service")
//        }.toString()
//
//        mqttExecutor.submit {
//            try {
//                val client = mqttClient
//                if (!isMqttConnected || client == null || !client.isConnected) {
//                    debugPrint("⚠️ [MQTT] Not connected — queuing reconnect")
//                    if (!isMqttConnected) handler.post {
//                        updateNotification("❌ MQTT offline — reconnecting…", false)
//                        scheduleReconnect()
//                    }
//                    return@submit
//                }
//                val msg = MqttMessage(payload.toByteArray(Charsets.UTF_8)).apply {
//                    qos        = 1
//                    isRetained = false
//                }
//                client.publish(mqttTopic, msg)
//                mqttPublishCount++
//                debugPrint("✅ [MQTT] #$mqttPublishCount lat=$lat lon=$lon → $mqttTopic")
//                handler.post {
//                    updateNotification("✅ Live tracking • #$mqttPublishCount sent", false)
//                }
//            } catch (e: Exception) {
//                debugPrint("❌ [MQTT] Publish error: ${e.message}")
//                isMqttConnected = false
//                handler.post {
//                    updateNotification("❌ MQTT publish failed — reconnecting…", false)
//                    scheduleReconnect()
//                }
//            }
//        }
//    }
//
//    private fun startMqttPublishing() {
//        connectMqtt()
//        mqttPublishRunnable?.let { handler.removeCallbacks(it) }
//        mqttPublishRunnable = MqttPublishRunnable()
//        handler.postDelayed(mqttPublishRunnable!!, MQTT_PUBLISH_INTERVAL)
//        debugPrint("✅ [MQTT] 5-second publish loop started")
//    }
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // HTTP POST fallback
//    // ═════════════════════════════════════════════════════════════════════════
//
//    private val nativeDb: NativeDBHelper by lazy { NativeDBHelper(applicationContext) }
//
//    private fun postLocationToServer(prefs: android.content.SharedPreferences) {
//        val lat = lastLat
//        val lon = lastLon
//        if (lat == 0.0 && lon == 0.0) {
//            debugPrint("⚠️ [HTTP] No GPS fix yet — skipping save")
//            return
//        }
//
//        val sdf      = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
//        val stf      = SimpleDateFormat("HH:mm:ss",   Locale.getDefault())
//        val now      = Date()
//        val date     = sdf.format(now)
//        val time     = stf.format(now)
//        val rowId    = "LT-$userId-${SimpleDateFormat("dd", Locale.getDefault()).format(now)}" +
//                "-${SimpleDateFormat("MMM", Locale.getDefault()).format(now)}" +
//                "-${UUID.randomUUID().toString().takeLast(6).uppercase()}"
//        val code     = companyCode.ifEmpty { COMPANY_CODE }
//
//        if (lat > 90.0 || lat < -90.0 || lon > 180.0 || lon < -180.0) {
//            debugPrint("⚠️ [HTTP] Invalid coordinates — skipping")
//            return
//        }
//
//        try {
//            nativeDb.insertLocationRow(
//                id          = rowId,
//                date        = date,
//                time        = time,
//                userId      = userId,
//                lat         = lat.toString(),
//                lng         = lon.toString(),
//                bookerName  = bookerName,
//                designation = designation,
//                companyCode = code
//            )
//            debugPrint("💾 [HTTP] Saved locally: $rowId  lat=$lat lng=$lon")
//            lastSavedLat  = lat
//            lastSavedLon  = lon
//            lastSavedTime = System.currentTimeMillis()
//            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
//                .putFloat("flutter.lastSavedLat",  lat.toFloat())
//                .putFloat("flutter.lastSavedLon",  lon.toFloat())
//                .putLong("flutter.lastSavedTime",  lastSavedTime)
//                .apply()
//        } catch (e: Exception) {
//            debugPrint("❌ [HTTP] DB save failed: ${e.message}")
//            return
//        }
//
//        syncUnpostedRows()
//    }
//
//    private fun syncUnpostedRows() {
//        val BULK_API = "http://103.149.33.102:8001/location/bulk"
//
//        val unposted = try { nativeDb.getUnpostedRows() } catch (e: Exception) {
//            debugPrint("❌ [HTTP] DB read failed: ${e.message}")
//            return
//        }
//
//        if (unposted.isEmpty()) {
//            debugPrint("✅ [HTTP] No unposted rows — nothing to sync")
//            return
//        }
//
//        debugPrint("🚀 [HTTP] Syncing ${unposted.size} unposted rows → $BULK_API")
//
//        val records = JSONArray()
//        for (row in unposted) {
//            records.put(JSONObject().apply {
//                put("locationtracking_date", row["locationtracking_date"] ?: "")
//                put("locationtracking_time", row["locationtracking_time"] ?: "")
//                put("user_id",              row["user_id"] ?: "")
//                put("company_code",         row["company_code"] ?: "")
//                put("lat_in",               (row["lat_in"] ?: "0").toDoubleOrNull() ?: 0.0)
//                put("lng_in",               (row["lng_in"] ?: "0").toDoubleOrNull() ?: 0.0)
//                put("booker_name",          row["booker_name"] ?: "")
//                put("designation",          row["designation"] ?: "")
//                put("posted",               false)
//            })
//        }
//        val body = JSONObject().put("records", records).toString()
//
//        try {
//            val conn = URL(BULK_API).openConnection() as HttpURLConnection
//            conn.apply {
//                requestMethod       = "POST"
//                connectTimeout      = 15_000
//                readTimeout         = 30_000
//                doOutput            = true
//                setRequestProperty("Content-Type", "application/json")
//                setRequestProperty("Accept",       "application/json")
//            }
//            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(body) }
//
//            val code = conn.responseCode
//            conn.disconnect()
//
//            if (code in 200..299) {
//                val ids = unposted.mapNotNull { it["locationtracking_id"] }
//                nativeDb.markPosted(ids)
//                debugPrint("✅ [HTTP] Bulk POST OK ($code) — marked ${ids.size} rows posted")
//            } else {
//                debugPrint("⚠️ [HTTP] Bulk POST failed ($code) — will retry next tick")
//            }
//        } catch (e: Exception) {
//            debugPrint("📴 [HTTP] Bulk POST exception: ${e.message} — will retry")
//        }
//    }
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // Service restart scheduling
//    // ═════════════════════════════════════════════════════════════════════════
//
//    private fun scheduleServiceRestart() {
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        if (userId.isNotEmpty()) {
//            prefs.edit()
//                .putString("flutter.userId",          userId)
//                .putString("flutter.userName",        bookerName)
//                .putString("flutter.userDesignation", designation)
//                .putString("flutter.companyCode",     companyCode)
//                .apply()
//        }
//
//        // ✅ FIX 1: Pehle directly service start karne ki koshish karo (fastest restart)
//        // Doze mein alarm delay hota hai lekin startForegroundService immediate hota hai
//        try {
//            val directIntent = Intent(applicationContext, LocationMonitorService::class.java).apply {
//                putExtra("extra_user_id",      userId)
//                putExtra("extra_booker_name",  bookerName)
//                putExtra("extra_designation",  designation)
//                putExtra("extra_company_code", companyCode)
//            }
//            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
//                applicationContext.startForegroundService(directIntent)
//            else
//                applicationContext.startService(directIntent)
//            debugPrint("✅ [Restart] Direct service start attempted from scheduleServiceRestart")
//        } catch (e: Exception) {
//            debugPrint("⚠️ [Restart] Direct start failed: ${e.message} — falling back to alarms")
//        }
//
//        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
//
//        val restartIntent = Intent(applicationContext, ServiceRestartReceiver::class.java).apply {
//            action = ServiceRestartReceiver.ACTION_RESTART_SERVICE
//        }
//
//        // ✅ FIX 2: 5 alarm points — Doze batches defer karta hai, zyada attempts = zyada chance
//        val delays = longArrayOf(1_500L, 8_000L, 30_000L, 60_000L, 120_000L)
//        delays.forEachIndexed { index, delay ->
//            val pIntent = PendingIntent.getBroadcast(
//                applicationContext,
//                20 + index,
//                restartIntent,
//                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
//            )
//            val triggerAt = android.os.SystemClock.elapsedRealtime() + delay
//            try {
//                when {
//                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && am.canScheduleExactAlarms() ->
//                        am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pIntent)
//                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
//                        am.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pIntent)
//                    else ->
//                        am.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pIntent)
//                }
//                debugPrint("⏱️ [Restart] Alarm $index set at ${delay}ms via BroadcastReceiver")
//            } catch (e: Exception) {
//                debugPrint("⚠️ [Restart] Alarm $index failed: ${e.message}")
//            }
//        }
//        debugPrint("✅ [Service] Restart scheduled: direct + 1.5s + 8s + 30s + 60s + 120s")
//    }
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // Critical event
//    // ═════════════════════════════════════════════════════════════════════════
//
//    private fun handleCriticalEvent(reason: String) = handleCriticalEventWithTime(reason, Date())
//
//    private fun handleCriticalEventWithTime(reason: String, eventTime: Date) {
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        if (prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) return
//
//        saveCriticalEventToPrefs(prefs, reason, eventTime)
//        showCriticalNotification(
//            reason,
//            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(eventTime)
//        )
//        updateNotification("⚠️ AUTO CLOCKOUT: $reason", true)
//
//        stopAllLoops()
//        disconnectMqtt()
//
//        // Cancel working timer notification on clockout
//        try { (getSystemService(NotificationManager::class.java)).cancel(WORKING_NOTIFICATION_ID) } catch (_: Exception) {}
//        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
//        stopSelf()
//    }
//
//    private fun saveCriticalEventToPrefs(
//        prefs: android.content.SharedPreferences,
//        reason: String,
//        eventTime: Date = Date()
//    ) {
//        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(eventTime)
//        val elapsed   = prefs.getString(KEY_ELAPSED_TIME, "00:00:00") ?: "00:00:00"
//        val clockInT  = prefs.getString("flutter.clockInTime", "") ?: ""
//
//        prefs.edit()
//            .putBoolean(KEY_HAS_CRITICAL_EVENT, true)
//            .putBoolean(KEY_IS_TIMER_FROZEN, true)
//            .putString(KEY_EVENT_TIMESTAMP, timestamp)
//            .putString(KEY_EVENT_REASON, reason)
//            .putString(KEY_FROZEN_TIME, "00:00:00")
//            .putFloat(KEY_EVENT_DISTANCE, 0f)
//            .putFloat(KEY_EVENT_LAT, 0f)
//            .putFloat(KEY_EVENT_LNG, 0f)
//            .putBoolean(KEY_IS_CLOCKED_IN, false)
//            .putBoolean("flutter.pending_gpx_close", true)
//            .putString("flutter.fastClockOutTime", timestamp)
//            .putFloat("flutter.fastClockOutDistance", 0f)
//            .putString("flutter.fastClockOutReason", reason)
//            .putBoolean("flutter.hasFastClockOutData", true)
//            .putBoolean("flutter.clockOutPending", true)
//            .putString(
//                "flutter.fastClockOutData",
//                """{"fast_attendanceId":"","fast_userId":"$userId","fast_clockOutTime":"$timestamp","fast_totalTime":"$elapsed","fast_totalDistance":0.0,"fast_latOut":0.0,"fast_lngOut":0.0,"fast_address":"","fast_reason":"$reason","fast_savedAt":"${System.currentTimeMillis()}","fast_clockInTime":"$clockInT"}"""
//            )
//            .putString(
//                KEY_BG_CLOCKOUT_PAYLOAD,
//                """{"timestamp":"$timestamp","reason":"$reason","elapsed_at_event":"$elapsed","distance":0.0,"latitude":0.0,"longitude":0.0,"source":"critical_event"}"""
//            )
//            .commit()
//
//        debugPrint("💾 [Critical] Saved: reason=$reason ts=$timestamp")
//    }
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // Location + Permission Checks
//    // ═════════════════════════════════════════════════════════════════════════
//
//    private fun checkLocationAndPermission() {
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        isClockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//
//        if (!isClockedIn) {
//            updateNotification("Not clocked in", false)
//            return
//        }
//
//        val isFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//        if (isFrozen) {
//            checkRunnable?.let { handler.removeCallbacks(it) }
//            return
//        }
//
//        val currentLocEnabled  = isLocationEnabled()
//        val currentPermGranted = checkLocationPermission()
//
//        if (wasPermissionGranted && !currentPermGranted) {
//            val now = System.currentTimeMillis()
//            if (now - lastEventTime > 5000 &&
//                lastEventReason != "System ClockOut - Permission Revoked") {
//                lastEventTime   = now
//                lastEventReason = "System ClockOut - Permission Revoked"
//                handleCriticalEventWithTime("System ClockOut - Permission Revoked", Date())
//                return
//            }
//        }
//
//        if (wasLocationEnabled && !currentLocEnabled) {
//            val now = System.currentTimeMillis()
//            if (now - lastEventTime > 5000 &&
//                lastEventReason != "System ClockOut - Location Off") {
//                lastEventTime   = now
//                lastEventReason = "System ClockOut - Location Off"
//                handleCriticalEventWithTime("System ClockOut - Location Off", Date())
//                return
//            }
//        }
//
//        wasLocationEnabled   = currentLocEnabled
//        wasPermissionGranted = currentPermGranted
//        if (isMqttConnected) {
//            updateNotification("✅ Live tracking • #$mqttPublishCount sent", false)
//        } else {
//            updateNotification("❌ MQTT offline — reconnecting…", false)
//        }
//    }
//
//    private fun instantCheckAndHandlePermissionRevoke() {
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        if (!prefs.getBoolean(KEY_IS_CLOCKED_IN, false) ||
//            prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) return
//        if (!checkLocationPermission()) {
//            val now = System.currentTimeMillis()
//            if (now - lastEventTime > 5000 ||
//                lastEventReason != "System ClockOut - Permission Revoked") {
//                lastEventTime   = now
//                lastEventReason = "System ClockOut - Permission Revoked"
//                handleCriticalEventWithTime("System ClockOut - Permission Revoked", Date())
//            }
//        }
//    }
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // Broadcast Receivers
//    // ═════════════════════════════════════════════════════════════════════════
//
//    private val locationModeReceiver = object : BroadcastReceiver() {
//        override fun onReceive(context: Context?, intent: Intent?) {
//            if (intent?.action == SysLocationManager.MODE_CHANGED_ACTION)
//                handler.post { checkLocationAndPermission() }
//        }
//    }
//
//    private val packageReceiver = object : BroadcastReceiver() {
//        override fun onReceive(context: Context?, intent: Intent?) {
//            val pkg = intent?.data?.schemeSpecificPart
//            if (pkg == null || pkg == packageName)
//                handler.post { instantCheckAndHandlePermissionRevoke() }
//            else
//                handler.post { checkLocationAndPermission() }
//        }
//    }
//
//    private val screenReceiver = object : BroadcastReceiver() {
//        override fun onReceive(context: Context?, intent: Intent?) {
//            handler.post { checkLocationAndPermission() }
//        }
//    }
//
//    private val dateTimeChangeReceiver = object : BroadcastReceiver() {
//        override fun onReceive(context: Context?, intent: Intent?) {}
//    }
//
//    private fun registerReceivers() {
//        registerReceiver(
//            locationModeReceiver,
//            IntentFilter(SysLocationManager.MODE_CHANGED_ACTION)
//        )
//        val packageFilter = IntentFilter().apply {
//            addAction(Intent.ACTION_PACKAGE_CHANGED)
//            addAction(Intent.ACTION_PACKAGE_REMOVED)
//            addDataScheme("package")
//        }
//        registerReceiver(packageReceiver, packageFilter)
//        registerReceiver(screenReceiver, IntentFilter(Intent.ACTION_SCREEN_ON))
//        val timeFilter = IntentFilter().apply {
//            addAction(Intent.ACTION_TIME_CHANGED)
//            addAction(Intent.ACTION_DATE_CHANGED)
//            addAction(Intent.ACTION_TIMEZONE_CHANGED)
//        }
//        registerReceiver(dateTimeChangeReceiver, timeFilter)
//    }
//
//    private fun registerAppOpsListener() {
//        try {
//            appOpsManager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
//            val listener = AppOpsManager.OnOpChangedListener { _, pkg ->
//                if (pkg == packageName)
//                    handler.post { instantCheckAndHandlePermissionRevoke() }
//                else
//                    handler.post { checkLocationAndPermission() }
//            }
//            appOpsManager?.startWatchingMode(
//                AppOpsManager.OPSTR_FINE_LOCATION, packageName, listener
//            )
//            appOpsCallback = listener
//        } catch (e: Exception) {
//            debugPrint("⚠️ [AppOps] Register failed: ${e.message}")
//        }
//    }
//
//    private fun unregisterAppOpsListener() {
//        try {
//            appOpsCallback?.let {
//                appOpsManager?.stopWatchingMode(it)
//                appOpsCallback = null
//            }
//        } catch (_: Exception) {}
//    }
//
//    private fun registerNetworkCallback() {
//        try {
//            connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
//            val request = NetworkRequest.Builder()
//                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
//                .build()
//            networkCallback = object : ConnectivityManager.NetworkCallback() {
//                override fun onAvailable(network: Network) {
//                    debugPrint("🌐 [Network] Internet available — triggering MQTT reconnect")
//                    handler.post {
//                        if (!isDestroyed && !isMqttConnected) {
//                            mqttReconnectRunnable?.let { handler.removeCallbacks(it) }
//                            mqttReconnectRunnable = null
//                            connectMqtt()
//                        }
//                    }
//                }
//                override fun onLost(network: Network) {
//                    debugPrint("🌐 [Network] Internet lost")
//                    isMqttConnected = false
//                    handler.post {
//                        updateNotification("❌ MQTT offline — no internet…", false)
//                    }
//                }
//            }
//            connectivityManager?.registerNetworkCallback(request, networkCallback!!)
//            debugPrint("✅ [Network] Connectivity callback registered")
//        } catch (e: Exception) {
//            debugPrint("⚠️ [Network] registerNetworkCallback failed: ${e.message}")
//        }
//    }
//
//    private fun unregisterNetworkCallback() {
//        try {
//            networkCallback?.let {
//                connectivityManager?.unregisterNetworkCallback(it)
//                networkCallback = null
//            }
//        } catch (_: Exception) {}
//    }
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // Helpers
//    // ═════════════════════════════════════════════════════════════════════════
//
//    private fun getStringPref(
//        prefs: android.content.SharedPreferences, vararg keys: String
//    ): String {
//        for (key in keys) {
//            val v = prefs.getString(key, "")
//            if (!v.isNullOrEmpty()) return v
//        }
//        return ""
//    }
//
//    private fun isLocationEnabled(): Boolean {
//        return try {
//            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
//                (getSystemService(Context.LOCATION_SERVICE) as SysLocationManager).isLocationEnabled
//            } else {
//                @Suppress("DEPRECATION")
//                Settings.Secure.getInt(
//                    contentResolver, Settings.Secure.LOCATION_MODE
//                ) != Settings.Secure.LOCATION_MODE_OFF
//            }
//        } catch (_: Exception) { false }
//    }
//
//    private fun checkLocationPermission(): Boolean {
//        return try {
//            ContextCompat.checkSelfPermission(
//                this, Manifest.permission.ACCESS_FINE_LOCATION
//            ) == PackageManager.PERMISSION_GRANTED ||
//                    ContextCompat.checkSelfPermission(
//                        this, Manifest.permission.ACCESS_COARSE_LOCATION
//                    ) == PackageManager.PERMISSION_GRANTED
//        } catch (_: Exception) { false }
//    }
//
//    private fun debugPrint(msg: String) = android.util.Log.d("LocationMonitor", msg)
//
//    // ─── Working Timer (Kotlin side — all devices pe survive karta hai) ────────
//
//    private fun startWorkingTimer() {
//        workingTimerRunnable?.let { handler.removeCallbacks(it) }
//        workingTimerRunnable = object : Runnable {
//            override fun run() {
//                if (isDestroyed) return
//
//                // ✅ FIX: isClockedIn check NAHI karo yahan
//                // Critical event (location off/permission revoked) isClockedIn=false likh deta tha
//                // aur timer khud band ho jaata tha jabke user ne manually clockout nahi kiya tha.
//                // Timer sirf 2 jagah band hoga: (1) stopAllLoops() — jo sirf actual clockout/destroy pe chal
//                // aur (2) isDestroyed=true — service destroy hone pe
//                // isFrozen bhi check nahi karein — frozen pe bhi time dikhana chahiye
//
//                workingSeconds++
//                val hours   = workingSeconds / 3600
//                val minutes = (workingSeconds % 3600) / 60
//                val secs    = workingSeconds % 60
//                val timeStr = "%02d:%02d:%02d".format(hours, minutes, secs)
//
//                updateWorkingNotification(timeStr)
//
//                if (!isDestroyed) handler.postDelayed(this, 1000L)
//            }
//        }
//        handler.postDelayed(workingTimerRunnable!!, 1000L)
//        debugPrint("✅ [Timer] Working timer started at $workingSeconds seconds")
//    }
//
//    private fun updateWorkingNotification(timeStr: String) {
//        val pi = PendingIntent.getActivity(
//            this, 1,  // requestCode 1 — NOTIFICATION_ID=1001 se alag
//            packageManager.getLaunchIntentForPackage(packageName),
//            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
//        )
//        val n = NotificationCompat.Builder(this, CHANNEL_ID)
//            .setContentTitle("Working")
//            .setContentText("Time: $timeStr")
//            .setSmallIcon(R.mipmap.ic_launcher)
//            .setContentIntent(pi)
//            .setOngoing(true)   // Swipe se dismiss nahi hogi
//            .setSilent(true)
//            .build()
//        try {
//            (getSystemService(NotificationManager::class.java))
//                .notify(WORKING_NOTIFICATION_ID, n)
//        } catch (e: Exception) {
//            debugPrint("⚠️ [Timer] Working notification update failed: ${e.message}")
//        }
//    }
//
//    // ─── Notifications ────────────────────────────────────────────────────────
//
//    private fun createNotificationChannel() {
//        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
//        val nm = getSystemService(NotificationManager::class.java)
//        nm.createNotificationChannel(
//            NotificationChannel(
//                CHANNEL_ID,
//                "Location Monitor Service",
//                NotificationManager.IMPORTANCE_HIGH
//            ).apply {
//                description = "Monitors location for attendance tracking"
//                setShowBadge(false)
//                enableVibration(false)
//                setSound(null, null)
//            }
//        )
//        nm.createNotificationChannel(
//            NotificationChannel(
//                URGENT_CHANNEL_ID,
//                "URGENT Auto Clockout",
//                NotificationManager.IMPORTANCE_HIGH
//            ).apply {
//                enableVibration(true)
//                vibrationPattern = longArrayOf(0, 1000, 500, 1000)
//                enableLights(true)
//                lightColor = android.graphics.Color.RED
//            }
//        )
//    }
//
//    private fun buildNotification(): Notification {
//        val pi = PendingIntent.getActivity(
//            this, 0,
//            packageManager.getLaunchIntentForPackage(packageName),
//            PendingIntent.FLAG_IMMUTABLE
//        )
//        return NotificationCompat.Builder(this, CHANNEL_ID)
//            .setContentTitle("BookIT Attendance Active")
//            .setContentText("⏳ Starting MQTT tracking…")
//            .setSmallIcon(R.mipmap.ic_launcher)
//            .setContentIntent(pi)
//            .setOngoing(true)
//            .setSilent(true)
//            .build()
//    }
//
//    private fun updateNotification(text: String, isAlert: Boolean) {
//        val pi = PendingIntent.getActivity(
//            this, 0,
//            packageManager.getLaunchIntentForPackage(packageName),
//            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
//        )
//        val n = NotificationCompat.Builder(this, CHANNEL_ID)
//            .setContentTitle(if (isAlert) "⚠️ ATTENTION REQUIRED" else "BookIT Attendance Active")
//            .setContentText(text)
//            .setSmallIcon(R.mipmap.ic_launcher)
//            .setContentIntent(pi)
//            .setOngoing(true)
//            .setSilent(!isAlert)
//            .apply { if (isAlert) setColor(android.graphics.Color.RED) }
//            .build()
//        (getSystemService(NotificationManager::class.java)).notify(NOTIFICATION_ID, n)
//    }
//
//    private fun showCriticalNotification(reason: String, time: String) {
//        val title = when (reason) {
//            "System ClockOut - Location Off"       -> "⚠️ LOCATION TURNED OFF"
//            "System ClockOut - Permission Revoked" -> "⚠️ PERMISSION REVOKED"
//            else                                   -> "⚠️ AUTO CLOCKOUT"
//        }
//        val pi = PendingIntent.getActivity(
//            this, 0,
//            packageManager.getLaunchIntentForPackage(packageName)?.apply {
//                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
//            },
//            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
//        )
//        val n = NotificationCompat.Builder(this, URGENT_CHANNEL_ID)
//            .setContentTitle(title)
//            .setContentText("Auto clockout at $time. Open app to sync.")
//            .setSmallIcon(R.mipmap.ic_launcher)
//            .setPriority(NotificationCompat.PRIORITY_MAX)
//            .setCategory(NotificationCompat.CATEGORY_ALARM)
//            .setAutoCancel(true)
//            .setContentIntent(pi)
//            .setVibrate(longArrayOf(0, 1000, 500, 1000))
//            .build()
//        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(9998, n)
//    }
//}
//
//// ─────────────────────────────────────────────────────────────────────────────
//// NativeDBHelper
//// ─────────────────────────────────────────────────────────────────────────────
//
//class NativeDBHelper(context: Context) :
//    SQLiteOpenHelper(context, "bookIt.db", null, 1) {
//
//    override fun onCreate(db: SQLiteDatabase) {
//        db.execSQL(
//            """CREATE TABLE IF NOT EXISTS location_tracking (
//                locationtracking_id   TEXT PRIMARY KEY,
//                locationtracking_date TEXT,
//                locationtracking_time TEXT,
//                user_id               TEXT,
//                lat_in                TEXT,
//                lng_in                TEXT,
//                booker_name           TEXT,
//                designation           TEXT,
//                posted                INTEGER DEFAULT 0,
//                company_code          TEXT DEFAULT ''
//            )"""
//        )
//    }
//
//    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {}
//
//    fun insertLocationRow(
//        id: String, date: String, time: String,
//        userId: String, lat: String, lng: String,
//        bookerName: String, designation: String, companyCode: String
//    ) {
//        val cv = ContentValues().apply {
//            put("locationtracking_id",   id)
//            put("locationtracking_date", date)
//            put("locationtracking_time", time)
//            put("user_id",               userId)
//            put("lat_in",                lat)
//            put("lng_in",                lng)
//            put("booker_name",           bookerName)
//            put("designation",           designation)
//            put("posted",                0)
//            put("company_code",          companyCode)
//        }
//        writableDatabase.insertWithOnConflict(
//            "location_tracking", null, cv, SQLiteDatabase.CONFLICT_IGNORE
//        )
//    }
//
//    fun getUnpostedRows(): List<Map<String, String>> {
//        val rows    = mutableListOf<Map<String, String>>()
//        val cursor  = readableDatabase.rawQuery(
//            "SELECT * FROM location_tracking WHERE posted = 0 ORDER BY locationtracking_date, locationtracking_time",
//            null
//        )
//        cursor.use {
//            while (it.moveToNext()) {
//                val row = mutableMapOf<String, String>()
//                for (i in 0 until it.columnCount) {
//                    row[it.getColumnName(i)] = it.getString(i) ?: ""
//                }
//                rows.add(row)
//            }
//        }
//        return rows
//    }
//
//    fun markPosted(ids: List<String>) {
//        if (ids.isEmpty()) return
//        val db           = writableDatabase
//        val placeholders = ids.joinToString(",") { "?" }
//        db.execSQL(
//            "UPDATE location_tracking SET posted = 1 WHERE locationtracking_id IN ($placeholders)",
//            ids.toTypedArray()
//        )
//    }
//}


package com.metaxperts.order_booking_app

import android.Manifest
import android.app.AlarmManager
import android.app.AppOpsManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager as SysLocationManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.eclipse.paho.client.mqttv3.IMqttDeliveryToken
import org.eclipse.paho.client.mqttv3.MqttCallback
import org.eclipse.paho.client.mqttv3.MqttClient
import org.eclipse.paho.client.mqttv3.MqttConnectOptions
import org.eclipse.paho.client.mqttv3.MqttMessage
import org.eclipse.paho.client.mqttv3.persist.MemoryPersistence
import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import java.util.concurrent.Executors

class LocationMonitorService : Service() {

    // ─── Constants ───────────────────────────────────────────────────────────
    private val CHANNEL_ID            = "location_monitor_channel"
    private val URGENT_CHANNEL_ID     = "urgent_auto_clockout_channel"
    private val NOTIFICATION_ID       = 1001
    private val WORKING_NOTIFICATION_ID = 1002  // Working timer notification
    private val CHECK_INTERVAL        = 2_000L
    private val MQTT_PUBLISH_INTERVAL = 5_000L
    private val MQTT_RECONNECT_DELAY  = 10_000L
    private val WAKELOCK_TIMEOUT_MS   = 12 * 60 * 60 * 1000L  // 12 hours
    private val WATCHDOG_INTERVAL     = 30_000L
    private val GPS_HEARTBEAT_TIMEOUT = 60_000L

    // MQTT Broker
    private val MQTT_HOST    = "119.153.102.7"
    private val MQTT_PORT    = 1883
    private val COMPANY_CODE = "PK-PUN-SKT-MX01-VT001"

    // SharedPreferences keys (Flutter prefix)
    private val PREFS_NAME              = "FlutterSharedPreferences"
    private val KEY_IS_CLOCKED_IN       = "flutter.isClockedIn"
    private val KEY_HAS_CRITICAL_EVENT  = "flutter.has_critical_event_pending"
    private val KEY_EVENT_TIMESTAMP     = "flutter.critical_event_timestamp"
    private val KEY_EVENT_REASON        = "flutter.critical_event_reason"
    private val KEY_EVENT_DISTANCE      = "flutter.critical_event_distance"
    private val KEY_EVENT_LAT           = "flutter.critical_event_latitude"
    private val KEY_EVENT_LNG           = "flutter.critical_event_longitude"
    private val KEY_IS_TIMER_FROZEN     = "flutter.is_timer_frozen"
    private val KEY_FROZEN_TIME         = "flutter.frozen_display_time"
    private val KEY_ELAPSED_TIME        = "flutter.elapsed_time"
    private val KEY_BG_CLOCKOUT_PAYLOAD = "flutter.bg_clockout_payload"

    private val EXTRA_USER_ID      = "extra_user_id"
    private val EXTRA_BOOKER_NAME  = "extra_booker_name"
    private val EXTRA_DESIGNATION  = "extra_designation"
    private val EXTRA_COMPANY_CODE = "extra_company_code"

    // ─── State ───────────────────────────────────────────────────────────────
    private lateinit var handler: Handler
    private var gpsThread: android.os.HandlerThread? = null
    private var gpsLooper: Looper? = null

    private var checkRunnable:         CheckRunnable?        = null
    private var mqttPublishRunnable:   MqttPublishRunnable?  = null
    private var mqttReconnectRunnable: Runnable?             = null
    private var locationPostRunnable:  LocationPostRunnable? = null

    private val mqttExecutor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "MqttWorkerThread").apply { isDaemon = true }
    }

    @Volatile private var isDestroyed     = false
    @Volatile private var isMqttConnected = false

    private var wasLocationEnabled   = true
    private var wasPermissionGranted = true
    private var isClockedIn          = false
    private var lastEventTime: Long  = 0
    private var lastEventReason      = ""
    private var serviceStartTime: Date = Date()

    private var wakeLock: PowerManager.WakeLock? = null

    // ✅ NEW: CPU WakeLock for heartbeat
    private var cpuWakeLock: PowerManager.WakeLock? = null
    private var heartbeatRunnable: Runnable? = null
    private var lastSuccessfulPostTime = 0L

    // Working timer — Kotlin side pe timer rakho (Flutter isolate kill hone pe bhi survive kare)
    private var workingTimerRunnable: Runnable? = null
    private var workingSeconds = 0L

    // Identity
    private var userId      = ""
    private var bookerName  = ""
    private var designation = ""
    private var companyCode = ""

    // Location
    private var locationManager: SysLocationManager? = null
    private var locationListener: LocationListener?  = null
    @Volatile private var lastLat      = 0.0
    @Volatile private var lastLon      = 0.0
    @Volatile private var lastSavedLat  = 0.0
    @Volatile private var lastSavedLon  = 0.0
    @Volatile private var lastSavedTime = 0L
    private val recentFixes = ArrayDeque<android.location.Location>(3)
    @Volatile private var lastAccuracy = 0f
    @Volatile private var lastSpeed    = 0f
    private var lastHeartbeatTime: Long = 0

    // MQTT
    private var mqttClient: MqttClient? = null
    private var mqttPublishCount = 0
    private val mqttTopic get() = "gps/$companyCode/$userId"

    // AppOps
    private var appOpsManager: AppOpsManager? = null
    private var appOpsCallback: AppOpsManager.OnOpChangedListener? = null

    // Network connectivity
    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    // ─── Named inner Runnables ────────────────────────────────────────────────

    inner class CheckRunnable : Runnable {
        override fun run() {
            if (isDestroyed) return
            checkLocationAndPermission()
            handler.postDelayed(this, CHECK_INTERVAL)
        }
    }

    inner class MqttPublishRunnable : Runnable {
        override fun run() {
            if (isDestroyed) return
            publishLocationToMqtt()
            handler.postDelayed(this, MQTT_PUBLISH_INTERVAL)
        }
    }

    inner class LocationPostRunnable : Runnable {
        override fun run() {
            if (isDestroyed) return
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            if (prefs.getBoolean(KEY_IS_CLOCKED_IN, false) &&
                !prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) {
                mqttExecutor.submit { postLocationToServer(prefs) }
            }
            if (!isDestroyed) handler.postDelayed(this, 2 * 60_000L)
        }
    }

    // ─── Companion (start / stop helpers) ────────────────────────────────────
    companion object {
        fun start(
            context: Context,
            userId: String = "",
            bookerName: String = "",
            designation: String = "",
            companyCode: String = ""
        ) {
            val intent = Intent(context, LocationMonitorService::class.java).apply {
                putExtra("extra_user_id",      userId)
                putExtra("extra_booker_name",  bookerName)
                putExtra("extra_designation",  designation)
                putExtra("extra_company_code", companyCode)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                context.startForegroundService(intent)
            else
                context.startService(intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, LocationMonitorService::class.java))
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Lifecycle
    // ═════════════════════════════════════════════════════════════════════════

    override fun onCreate() {
        super.onCreate()
        handler = Handler(Looper.getMainLooper())

        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "BookIT::LocationServiceWakeLock"
            )
            wakeLock?.acquire(WAKELOCK_TIMEOUT_MS)
            debugPrint("✅ [Service] WakeLock acquired (12h)")
        } catch (e: Exception) {
            debugPrint("⚠️ [Service] WakeLock failed: ${e.message}")
        }

        registerReceivers()
        registerAppOpsListener()
        registerNetworkCallback()
        debugPrint("✅ [Service] onCreate complete")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()
        serviceStartTime = Date()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID,
                    buildNotification(),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
                )
            } else {
                startForeground(NOTIFICATION_ID, buildNotification())
            }
        } catch (e: Exception) {
            debugPrint("⚠️ [Service] startForeground failed: ${e.message}")
            stopSelf()
            return START_NOT_STICKY
        }

        wasLocationEnabled   = isLocationEnabled()
        wasPermissionGranted = checkLocationPermission()

        val prefs     = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
        val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

        lastSavedLat  = prefs.getFloat("flutter.lastSavedLat",  0f).toDouble()
        lastSavedLon  = prefs.getFloat("flutter.lastSavedLon",  0f).toDouble()
        lastSavedTime = prefs.getLong("flutter.lastSavedTime", 0L)

        if (lastSavedLat != 0.0 || lastSavedLon != 0.0) {
            lastLat = lastSavedLat
            lastLon = lastSavedLon
            debugPrint("📍 [Service] lastLat/Lon pre-filled from prefs: $lastLat, $lastLon")
        }

        val intentUserId = intent?.getStringExtra(EXTRA_USER_ID)?.takeIf { it.isNotEmpty() }
        if (intentUserId != null) {
            userId      = intentUserId
            bookerName  = intent.getStringExtra(EXTRA_BOOKER_NAME)  ?: ""
            designation = intent.getStringExtra(EXTRA_DESIGNATION)   ?: ""
            companyCode = intent.getStringExtra(EXTRA_COMPANY_CODE)
                ?.takeIf { it.isNotEmpty() } ?: COMPANY_CODE
            prefs.edit()
                .putString("flutter.userId",          userId)
                .putString("flutter.userName",        bookerName)
                .putString("flutter.userDesignation", designation)
                .putString("flutter.companyCode",     companyCode)
                .apply()
            debugPrint("👤 [Service] Identity from Intent → userId=$userId")
        } else {
            userId      = getStringPref(prefs, "flutter.userId", "userId")
            bookerName  = getStringPref(prefs, "flutter.userName", "userName", "booker_name")
            designation = getStringPref(prefs, "flutter.userDesignation", "userDesignation", "designation")
            companyCode = prefs.getString("flutter.companyCode", "")
                ?.takeIf { it.isNotEmpty() } ?: COMPANY_CODE
            debugPrint("👤 [Service] Identity from prefs → userId=$userId")
        }

        if (clockedIn && !isFrozen) {
            if (!wasPermissionGranted) {
                handler.post { handleCriticalEvent("System ClockOut - Permission Revoked") }
                return START_STICKY
            }
            if (!wasLocationEnabled) {
                handler.post { handleCriticalEvent("System ClockOut - Location Off") }
                return START_STICKY
            }
        }

        // ✅ Restore working timer from clockIn time (service restart ke baad bhi sahi time dikhe)
        if (clockedIn && !isFrozen) {
            val clockInTimeStr = prefs.getString("flutter.clockInTime", "") ?: ""
            if (clockInTimeStr.isNotEmpty()) {
                try {
                    val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
                    val clockInDate = sdf.parse(clockInTimeStr)
                    if (clockInDate != null) {
                        workingSeconds = (System.currentTimeMillis() - clockInDate.time) / 1000
                        if (workingSeconds < 0) workingSeconds = 0
                        debugPrint("⏱️ [Timer] Restored workingSeconds=$workingSeconds from clockInTime=$clockInTimeStr")
                    }
                } catch (e: Exception) {
                    workingSeconds = 0
                    debugPrint("⚠️ [Timer] clockInTime parse failed: ${e.message}")
                }
            }
        }

        startMonitoring()

        // ✅ NEW: Start backup systems when clocked in
        if (clockedIn && !isFrozen) {
            BulkPostingScheduler.startBulkPostingAlarm(this)
            try {
                WorkManagerBulkPoster.schedule(this)
            } catch (e: Exception) {
                debugPrint("⚠️ [Service] WorkManager not available: ${e.message}")
            }
            debugPrint("✅ [Service] Backup systems started: AlarmManager + WorkManager")
        }

        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        debugPrint("🔄 [Service] App removed from recents — scheduling restart")

        val prefs     = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
        val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

        if (clockedIn && !isFrozen) scheduleServiceRestart()
    }

    override fun onDestroy() {
        isDestroyed = true

        val prefs     = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
        val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

        if (clockedIn && !isFrozen) {
            val permRevoked = !checkLocationPermission()
            val locOff      = !isLocationEnabled()
            if (permRevoked || locOff) {
                val reason = if (permRevoked)
                    "System ClockOut - Permission Revoked"
                else
                    "System ClockOut - Location Off"
                saveCriticalEventToPrefs(prefs, reason)
            } else {
                debugPrint("🔄 [Service] onDestroy while clocked in — scheduling restart (old device fix)")
                scheduleServiceRestart()
            }
        }

        stopAllLoops()
        disconnectMqtt()
        unregisterAppOpsListener()
        unregisterNetworkCallback()

        try { unregisterReceiver(locationModeReceiver)   } catch (_: Exception) {}
        try { unregisterReceiver(packageReceiver)        } catch (_: Exception) {}
        try { unregisterReceiver(screenReceiver)         } catch (_: Exception) {}
        try { unregisterReceiver(dateTimeChangeReceiver) } catch (_: Exception) {}

        try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (_: Exception) {}
        try { if (cpuWakeLock?.isHeld == true) cpuWakeLock?.release() } catch (_: Exception) {}

        mqttExecutor.shutdown()

        super.onDestroy()
        debugPrint("🛑 [Service] onDestroy complete")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ═════════════════════════════════════════════════════════════════════════
    // Monitoring startup / teardown
    // ═════════════════════════════════════════════════════════════════════════

    private fun startMonitoring() {
        startLocationUpdates()

        checkRunnable = CheckRunnable()
        handler.post(checkRunnable!!)

        startMqttPublishing()

        debugPrint("✅ [Service] All loops started (GPS every 2s, MQTT every 5s)")
        startHttpPostLoop()

        // ✅ NEW: Start heartbeat for regular bulk sync
        startHeartbeat()

        // ✅ Start working timer — Kotlin side (all devices pe survive karta hai)
        startWorkingTimer()

        // ✅ FIX: Doze-proof keep-alive — har 15 min ek alarm reschedule karo
        // Jab device Doze se bahar aata hai yeh alarm fire hoga aur service alive confirm karega
        scheduleKeepAliveAlarm()
    }

    private fun scheduleKeepAliveAlarm() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
        val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
        if (!clockedIn || isFrozen) return

        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val keepAliveIntent = Intent(applicationContext, ServiceRestartReceiver::class.java).apply {
            action = ServiceRestartReceiver.ACTION_RESTART_SERVICE
        }
        val pIntent = PendingIntent.getBroadcast(
            applicationContext,
            99,  // unique request code for keep-alive
            keepAliveIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        // 15 minute baad fire hoga — agar service zinda hai toh onStartCommand phir se run
        // hoga lekin koi harm nahi (idempotent) — agar service mari hai toh restart ho jaayegi
        val triggerAt = android.os.SystemClock.elapsedRealtime() + 15 * 60 * 1000L
        try {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && am.canScheduleExactAlarms() ->
                    am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pIntent)
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                    am.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pIntent)
                else ->
                    am.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pIntent)
            }
            debugPrint("✅ [KeepAlive] 15-min alarm set — Doze-proof watchdog")
        } catch (e: Exception) {
            debugPrint("⚠️ [KeepAlive] Alarm failed: ${e.message}")
        }
    }

    // ✅ NEW: Start heartbeat for CPU wake and bulk sync
    private fun startHeartbeat() {
        heartbeatRunnable = object : Runnable {
            override fun run() {
                if (isDestroyed) return

                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
                val isFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

                if (clockedIn && !isFrozen) {
                    acquireCpuWakeLock()

                    mqttExecutor.submit {
                        syncUnpostedRows()
                        debugPrint("💓 [Heartbeat] Bulk sync executed")
                    }
                }

                if (!isDestroyed) {
                    handler.postDelayed(this, 30_000L)
                }
            }
        }
        handler.postDelayed(heartbeatRunnable!!, 30_000L)
        debugPrint("✅ [Heartbeat] Started (30s interval)")
    }

    // ✅ NEW: Acquire CPU wake lock
    private fun acquireCpuWakeLock() {
        try {
            if (cpuWakeLock == null) {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                cpuWakeLock = pm.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "BookIT::CpuHeartbeatLock"
                )
            }
            if (cpuWakeLock?.isHeld != true) {
                cpuWakeLock?.acquire(10_000L)
                debugPrint("✅ [WakeLock] CPU lock acquired")
            }
        } catch (e: Exception) {
            debugPrint("⚠️ [WakeLock] Failed: ${e.message}")
        }
    }

    private fun startHttpPostLoop() {
        handler.post(object : Runnable {
            override fun run() {
                if (isDestroyed) return
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
                val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

                if (clockedIn && !isFrozen) {
                    mqttExecutor.submit { postLocationToServer(prefs) }
                }
                handler.postDelayed(this, 15_000L)
            }
        })
    }

    private fun stopAllLoops() {
        checkRunnable?.let        { handler.removeCallbacks(it) }
        mqttPublishRunnable?.let  { handler.removeCallbacks(it) }
        mqttReconnectRunnable?.let{ handler.removeCallbacks(it) }
        locationPostRunnable?.let { handler.removeCallbacks(it) }
        heartbeatRunnable?.let    { handler.removeCallbacks(it) }  // ✅ NEW
        workingTimerRunnable?.let { handler.removeCallbacks(it) }  // Working timer
        // ✅ FIX: Working notification explicitly cancel karo clockout pe
        try { (getSystemService(NotificationManager::class.java)).cancel(WORKING_NOTIFICATION_ID) } catch (_: Exception) {}
        handler.removeCallbacksAndMessages(null)
        stopLocationUpdates()
    }

    // ═════════════════════════════════════════════════════════════════════════
    // GPS Location Updates
    // ═════════════════════════════════════════════════════════════════════════

    private fun startLocationUpdates() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION)
            != PackageManager.PERMISSION_GRANTED) return

        try {
            if (locationListener != null) return
            locationManager = getSystemService(Context.LOCATION_SERVICE) as SysLocationManager

            locationListener = object : LocationListener {
                override fun onLocationChanged(loc: Location) {
                    if (loc.accuracy > 100f) return

                    synchronized(recentFixes) {
                        if (recentFixes.size >= 3) recentFixes.removeFirst()
                        recentFixes.addLast(loc)
                    }
                    val fixes  = synchronized(recentFixes) { recentFixes.toList() }
                    val totalW = fixes.sumOf { 1.0 / it.accuracy }
                    val smoothLat = fixes.sumOf { (1.0 / it.accuracy) * it.latitude  } / totalW
                    val smoothLon = fixes.sumOf { (1.0 / it.accuracy) * it.longitude } / totalW

                    lastLat           = smoothLat
                    lastLon           = smoothLon
                    lastAccuracy      = loc.accuracy
                    lastSpeed         = loc.speed
                    lastHeartbeatTime = System.currentTimeMillis()
                }
                @Deprecated("Deprecated in API level 29")
                override fun onStatusChanged(p: String?, s: Int, e: Bundle?) {}
                override fun onProviderEnabled(p: String) {}
                override fun onProviderDisabled(p: String) {}
            }

            gpsThread = android.os.HandlerThread("gps-callback-thread").also { it.start() }
            gpsLooper = gpsThread!!.looper

            listOf(SysLocationManager.GPS_PROVIDER, SysLocationManager.NETWORK_PROVIDER)
                .forEach { provider ->
                    try {
                        if (locationManager?.isProviderEnabled(provider) == true) {
                            locationManager?.requestLocationUpdates(
                                provider,
                                2_000L,
                                0f,
                                locationListener!!, gpsLooper!!
                            )
                        }
                    } catch (_: Exception) {}
                }
            debugPrint("✅ [GPS] Location updates started")
        } catch (e: Exception) {
            debugPrint("⚠️ [GPS] startLocationUpdates failed: ${e.message}")
        }
    }

    private fun stopLocationUpdates() {
        try { locationListener?.let { locationManager?.removeUpdates(it) } } catch (_: Exception) {}
        locationListener = null
        gpsThread?.quitSafely()
        gpsThread = null
        gpsLooper = null
    }

    // ═════════════════════════════════════════════════════════════════════════
    // MQTT — Connect / Publish / Reconnect
    // ═════════════════════════════════════════════════════════════════════════

    private fun connectMqtt() {
        if (isMqttConnected) return
        mqttExecutor.submit {
            if (isDestroyed || isMqttConnected) return@submit
            try {
                val clientId = "android_${userId}_${System.currentTimeMillis()}"
                val client   = MqttClient(
                    "tcp://$MQTT_HOST:$MQTT_PORT",
                    clientId,
                    MemoryPersistence()
                )
                val opts = MqttConnectOptions().apply {
                    isCleanSession       = true
                    connectionTimeout    = 10
                    keepAliveInterval    = 30
                    isAutomaticReconnect = false
                }
                client.setCallback(object : MqttCallback {
                    override fun connectionLost(cause: Throwable?) {
                        debugPrint("⚠️ [MQTT] Connection lost: ${cause?.message}")
                        isMqttConnected = false
                        handler.post {
                            updateNotification("❌ MQTT connection lost — retrying…", false)
                            scheduleReconnect()
                        }
                    }
                    override fun messageArrived(topic: String?, msg: MqttMessage?) {}
                    override fun deliveryComplete(token: IMqttDeliveryToken?) {}
                })
                client.connect(opts)
                mqttClient      = client
                isMqttConnected = true
                handler.post { updateNotification("✅ MQTT connected — waiting for GPS…", false) }
                debugPrint("✅ [MQTT] Connected → tcp://$MQTT_HOST:$MQTT_PORT | topic=$mqttTopic")
            } catch (e: Exception) {
                debugPrint("❌ [MQTT] Connect failed: ${e.message}")
                isMqttConnected = false
                handler.post {
                    updateNotification("❌ MQTT connect failed — retrying in 10s…", false)
                    scheduleReconnect()
                }
            }
        }
    }

    private fun disconnectMqtt() {
        mqttReconnectRunnable?.let { handler.removeCallbacks(it) }
        mqttReconnectRunnable = null
        mqttPublishRunnable?.let { handler.removeCallbacks(it) }
        mqttPublishRunnable = null
        mqttExecutor.submit {
            try {
                if (mqttClient?.isConnected == true) mqttClient?.disconnect(0)
            } catch (_: Exception) {}
            mqttClient      = null
            isMqttConnected = false
            debugPrint("🛑 [MQTT] Disconnected")
        }
    }

    private fun scheduleReconnect() {
        if (isDestroyed) return
        mqttReconnectRunnable?.let { handler.removeCallbacks(it) }
        mqttReconnectRunnable = Runnable {
            if (!isDestroyed && !isMqttConnected) {
                debugPrint("🔄 [MQTT] Reconnecting…")
                connectMqtt()
            }
        }
        handler.postDelayed(mqttReconnectRunnable!!, MQTT_RECONNECT_DELAY)
    }

    private fun publishLocationToMqtt() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_IS_CLOCKED_IN, false)) return
        if (prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) return
        if (lastLat == 0.0 && lastLon == 0.0) {
            debugPrint("⚠️ [MQTT] No GPS fix yet, skipping")
            updateNotification("⏳ Waiting for GPS fix…", false)
            return
        }

        val lat       = lastLat
        val lon       = lastLon
        val accuracy  = lastAccuracy
        val speed     = lastSpeed
        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date())

        val payload = JSONObject().apply {
            put("device_id",    userId)
            put("company_code", companyCode.ifEmpty { COMPANY_CODE })
            put("emp_name",     bookerName)
            put("dept_id",      designation)
            put("lat",          lat)
            put("lon",          lon)
            put("accuracy",     accuracy)
            put("speed",        speed)
            put("track_id",     System.currentTimeMillis())
            put("timestamp",    timestamp)
            put("source",       "android_background_service")
        }.toString()

        mqttExecutor.submit {
            try {
                val client = mqttClient
                if (!isMqttConnected || client == null || !client.isConnected) {
                    debugPrint("⚠️ [MQTT] Not connected — queuing reconnect")
                    if (!isMqttConnected) handler.post {
                        updateNotification("❌ MQTT offline — reconnecting…", false)
                        scheduleReconnect()
                    }
                    return@submit
                }
                val msg = MqttMessage(payload.toByteArray(Charsets.UTF_8)).apply {
                    qos        = 1
                    isRetained = false
                }
                client.publish(mqttTopic, msg)
                mqttPublishCount++
                debugPrint("✅ [MQTT] #$mqttPublishCount lat=$lat lon=$lon → $mqttTopic")
                handler.post {
                    updateNotification("✅ Live tracking • #$mqttPublishCount sent", false)
                }
            } catch (e: Exception) {
                debugPrint("❌ [MQTT] Publish error: ${e.message}")
                isMqttConnected = false
                handler.post {
                    updateNotification("❌ MQTT publish failed — reconnecting…", false)
                    scheduleReconnect()
                }
            }
        }
    }

    private fun startMqttPublishing() {
        connectMqtt()
        mqttPublishRunnable?.let { handler.removeCallbacks(it) }
        mqttPublishRunnable = MqttPublishRunnable()
        handler.postDelayed(mqttPublishRunnable!!, MQTT_PUBLISH_INTERVAL)
        debugPrint("✅ [MQTT] 5-second publish loop started")
    }

    // ═════════════════════════════════════════════════════════════════════════
    // HTTP POST fallback
    // ═════════════════════════════════════════════════════════════════════════

    private val nativeDb: NativeDBHelper by lazy { NativeDBHelper(applicationContext) }

    private fun postLocationToServer(prefs: android.content.SharedPreferences) {
        val lat = lastLat
        val lon = lastLon
        if (lat == 0.0 && lon == 0.0) {
            debugPrint("⚠️ [HTTP] No GPS fix yet — skipping save")
            return
        }

        val sdf      = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        val stf      = SimpleDateFormat("HH:mm:ss",   Locale.getDefault())
        val now      = Date()
        val date     = sdf.format(now)
        val time     = stf.format(now)
        val rowId    = "LT-$userId-${SimpleDateFormat("dd", Locale.getDefault()).format(now)}" +
                "-${SimpleDateFormat("MMM", Locale.getDefault()).format(now)}" +
                "-${UUID.randomUUID().toString().takeLast(6).uppercase()}"
        val code     = companyCode.ifEmpty { COMPANY_CODE }

        if (lat > 90.0 || lat < -90.0 || lon > 180.0 || lon < -180.0) {
            debugPrint("⚠️ [HTTP] Invalid coordinates — skipping")
            return
        }

        try {
            nativeDb.insertLocationRow(
                id          = rowId,
                date        = date,
                time        = time,
                userId      = userId,
                lat         = lat.toString(),
                lng         = lon.toString(),
                bookerName  = bookerName,
                designation = designation,
                companyCode = code
            )
            debugPrint("💾 [HTTP] Saved locally: $rowId  lat=$lat lng=$lon")
            lastSavedLat  = lat
            lastSavedLon  = lon
            lastSavedTime = System.currentTimeMillis()
            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
                .putFloat("flutter.lastSavedLat",  lat.toFloat())
                .putFloat("flutter.lastSavedLon",  lon.toFloat())
                .putLong("flutter.lastSavedTime",  lastSavedTime)
                .apply()
        } catch (e: Exception) {
            debugPrint("❌ [HTTP] DB save failed: ${e.message}")
            return
        }

        syncUnpostedRows()
    }

    private fun syncUnpostedRows() {
        val BULK_API = "http://119.153.102.7:8001/location/bulk'"


        val unposted = try { nativeDb.getUnpostedRows() } catch (e: Exception) {
            debugPrint("❌ [HTTP] DB read failed: ${e.message}")
            return
        }

        if (unposted.isEmpty()) {
            debugPrint("✅ [HTTP] No unposted rows — nothing to sync")
            return
        }

        debugPrint("🚀 [HTTP] Syncing ${unposted.size} unposted rows → $BULK_API")

        val records = JSONArray()
        for (row in unposted) {
            records.put(JSONObject().apply {
                put("locationtracking_date", row["locationtracking_date"] ?: "")
                put("locationtracking_time", row["locationtracking_time"] ?: "")
                put("user_id",              row["user_id"] ?: "")
                put("company_code",         row["company_code"] ?: "")
                put("lat_in",               (row["lat_in"] ?: "0").toDoubleOrNull() ?: 0.0)
                put("lng_in",               (row["lng_in"] ?: "0").toDoubleOrNull() ?: 0.0)
                put("booker_name",          row["booker_name"] ?: "")
                put("designation",          row["designation"] ?: "")
                put("posted",               false)
            })
        }
        val body = JSONObject().put("records", records).toString()

        try {
            val conn = URL(BULK_API).openConnection() as HttpURLConnection
            conn.apply {
                requestMethod       = "POST"
                connectTimeout      = 15_000
                readTimeout         = 30_000
                doOutput            = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Accept",       "application/json")
            }
            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(body) }

            val code = conn.responseCode
            conn.disconnect()

            if (code in 200..299) {
                val ids = unposted.mapNotNull { it["locationtracking_id"] }
                nativeDb.markPosted(ids)
                debugPrint("✅ [HTTP] Bulk POST OK ($code) — marked ${ids.size} rows posted")
            } else {
                debugPrint("⚠️ [HTTP] Bulk POST failed ($code) — will retry next tick")
            }
        } catch (e: Exception) {
            debugPrint("📴 [HTTP] Bulk POST exception: ${e.message} — will retry")
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Service restart scheduling
    // ═════════════════════════════════════════════════════════════════════════

    private fun scheduleServiceRestart() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (userId.isNotEmpty()) {
            prefs.edit()
                .putString("flutter.userId",          userId)
                .putString("flutter.userName",        bookerName)
                .putString("flutter.userDesignation", designation)
                .putString("flutter.companyCode",     companyCode)
                .apply()
        }

        // ✅ FIX 1: Pehle directly service start karne ki koshish karo (fastest restart)
        // Doze mein alarm delay hota hai lekin startForegroundService immediate hota hai
        try {
            val directIntent = Intent(applicationContext, LocationMonitorService::class.java).apply {
                putExtra("extra_user_id",      userId)
                putExtra("extra_booker_name",  bookerName)
                putExtra("extra_designation",  designation)
                putExtra("extra_company_code", companyCode)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                applicationContext.startForegroundService(directIntent)
            else
                applicationContext.startService(directIntent)
            debugPrint("✅ [Restart] Direct service start attempted from scheduleServiceRestart")
        } catch (e: Exception) {
            debugPrint("⚠️ [Restart] Direct start failed: ${e.message} — falling back to alarms")
        }

        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val restartIntent = Intent(applicationContext, ServiceRestartReceiver::class.java).apply {
            action = ServiceRestartReceiver.ACTION_RESTART_SERVICE
        }

        // ✅ FIX 2: 5 alarm points — Doze batches defer karta hai, zyada attempts = zyada chance
        val delays = longArrayOf(1_500L, 8_000L, 30_000L, 60_000L, 120_000L)
        delays.forEachIndexed { index, delay ->
            val pIntent = PendingIntent.getBroadcast(
                applicationContext,
                20 + index,
                restartIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val triggerAt = android.os.SystemClock.elapsedRealtime() + delay
            try {
                when {
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && am.canScheduleExactAlarms() ->
                        am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pIntent)
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                        am.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pIntent)
                    else ->
                        am.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pIntent)
                }
                debugPrint("⏱️ [Restart] Alarm $index set at ${delay}ms via BroadcastReceiver")
            } catch (e: Exception) {
                debugPrint("⚠️ [Restart] Alarm $index failed: ${e.message}")
            }
        }
        debugPrint("✅ [Service] Restart scheduled: direct + 1.5s + 8s + 30s + 60s + 120s")
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Critical event
    // ═════════════════════════════════════════════════════════════════════════

    private fun handleCriticalEvent(reason: String) = handleCriticalEventWithTime(reason, Date())

    private fun handleCriticalEventWithTime(reason: String, eventTime: Date) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) return

        saveCriticalEventToPrefs(prefs, reason, eventTime)
        showCriticalNotification(
            reason,
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(eventTime)
        )
        updateNotification("⚠️ AUTO CLOCKOUT: $reason", true)

        stopAllLoops()
        disconnectMqtt()

        // Cancel working timer notification on clockout
        try { (getSystemService(NotificationManager::class.java)).cancel(WORKING_NOTIFICATION_ID) } catch (_: Exception) {}
        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
        stopSelf()
    }

    private fun saveCriticalEventToPrefs(
        prefs: android.content.SharedPreferences,
        reason: String,
        eventTime: Date = Date()
    ) {
        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(eventTime)
        val elapsed   = prefs.getString(KEY_ELAPSED_TIME, "00:00:00") ?: "00:00:00"
        val clockInT  = prefs.getString("flutter.clockInTime", "") ?: ""

        prefs.edit()
            .putBoolean(KEY_HAS_CRITICAL_EVENT, true)
            .putBoolean(KEY_IS_TIMER_FROZEN, true)
            .putString(KEY_EVENT_TIMESTAMP, timestamp)
            .putString(KEY_EVENT_REASON, reason)
            .putString(KEY_FROZEN_TIME, "00:00:00")
            .putFloat(KEY_EVENT_DISTANCE, 0f)
            .putFloat(KEY_EVENT_LAT, 0f)
            .putFloat(KEY_EVENT_LNG, 0f)
            .putBoolean(KEY_IS_CLOCKED_IN, false)
            .putBoolean("flutter.pending_gpx_close", true)
            .putString("flutter.fastClockOutTime", timestamp)
            .putFloat("flutter.fastClockOutDistance", 0f)
            .putString("flutter.fastClockOutReason", reason)
            .putBoolean("flutter.hasFastClockOutData", true)
            .putBoolean("flutter.clockOutPending", true)
            .putString(
                "flutter.fastClockOutData",
                """{"fast_attendanceId":"","fast_userId":"$userId","fast_clockOutTime":"$timestamp","fast_totalTime":"$elapsed","fast_totalDistance":0.0,"fast_latOut":0.0,"fast_lngOut":0.0,"fast_address":"","fast_reason":"$reason","fast_savedAt":"${System.currentTimeMillis()}","fast_clockInTime":"$clockInT"}"""
            )
            .putString(
                KEY_BG_CLOCKOUT_PAYLOAD,
                """{"timestamp":"$timestamp","reason":"$reason","elapsed_at_event":"$elapsed","distance":0.0,"latitude":0.0,"longitude":0.0,"source":"critical_event"}"""
            )
            .commit()

        debugPrint("💾 [Critical] Saved: reason=$reason ts=$timestamp")
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Location + Permission Checks
    // ═════════════════════════════════════════════════════════════════════════

    private fun checkLocationAndPermission() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        isClockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)

        if (!isClockedIn) {
            updateNotification("Not clocked in", false)
            return
        }

        val isFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
        if (isFrozen) {
            checkRunnable?.let { handler.removeCallbacks(it) }
            return
        }

        val currentLocEnabled  = isLocationEnabled()
        val currentPermGranted = checkLocationPermission()

        if (wasPermissionGranted && !currentPermGranted) {
            val now = System.currentTimeMillis()
            if (now - lastEventTime > 5000 &&
                lastEventReason != "System ClockOut - Permission Revoked") {
                lastEventTime   = now
                lastEventReason = "System ClockOut - Permission Revoked"
                handleCriticalEventWithTime("System ClockOut - Permission Revoked", Date())
                return
            }
        }

        if (wasLocationEnabled && !currentLocEnabled) {
            val now = System.currentTimeMillis()
            if (now - lastEventTime > 5000 &&
                lastEventReason != "System ClockOut - Location Off") {
                lastEventTime   = now
                lastEventReason = "System ClockOut - Location Off"
                handleCriticalEventWithTime("System ClockOut - Location Off", Date())
                return
            }
        }

        wasLocationEnabled   = currentLocEnabled
        wasPermissionGranted = currentPermGranted
        if (isMqttConnected) {
            updateNotification("✅ Live tracking • #$mqttPublishCount sent", false)
        } else {
            updateNotification("❌ MQTT offline — reconnecting…", false)
        }
    }

    private fun instantCheckAndHandlePermissionRevoke() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_IS_CLOCKED_IN, false) ||
            prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) return
        if (!checkLocationPermission()) {
            val now = System.currentTimeMillis()
            if (now - lastEventTime > 5000 ||
                lastEventReason != "System ClockOut - Permission Revoked") {
                lastEventTime   = now
                lastEventReason = "System ClockOut - Permission Revoked"
                handleCriticalEventWithTime("System ClockOut - Permission Revoked", Date())
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Broadcast Receivers
    // ═════════════════════════════════════════════════════════════════════════

    private val locationModeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == SysLocationManager.MODE_CHANGED_ACTION)
                handler.post { checkLocationAndPermission() }
        }
    }

    private val packageReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val pkg = intent?.data?.schemeSpecificPart
            if (pkg == null || pkg == packageName)
                handler.post { instantCheckAndHandlePermissionRevoke() }
            else
                handler.post { checkLocationAndPermission() }
        }
    }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            handler.post { checkLocationAndPermission() }
        }
    }

    private val dateTimeChangeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {}
    }

    private fun registerReceivers() {
        registerReceiver(
            locationModeReceiver,
            IntentFilter(SysLocationManager.MODE_CHANGED_ACTION)
        )
        val packageFilter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_CHANGED)
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addDataScheme("package")
        }
        registerReceiver(packageReceiver, packageFilter)
        registerReceiver(screenReceiver, IntentFilter(Intent.ACTION_SCREEN_ON))
        val timeFilter = IntentFilter().apply {
            addAction(Intent.ACTION_TIME_CHANGED)
            addAction(Intent.ACTION_DATE_CHANGED)
            addAction(Intent.ACTION_TIMEZONE_CHANGED)
        }
        registerReceiver(dateTimeChangeReceiver, timeFilter)
    }

    private fun registerAppOpsListener() {
        try {
            appOpsManager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val listener = AppOpsManager.OnOpChangedListener { _, pkg ->
                if (pkg == packageName)
                    handler.post { instantCheckAndHandlePermissionRevoke() }
                else
                    handler.post { checkLocationAndPermission() }
            }
            appOpsManager?.startWatchingMode(
                AppOpsManager.OPSTR_FINE_LOCATION, packageName, listener
            )
            appOpsCallback = listener
        } catch (e: Exception) {
            debugPrint("⚠️ [AppOps] Register failed: ${e.message}")
        }
    }

    private fun unregisterAppOpsListener() {
        try {
            appOpsCallback?.let {
                appOpsManager?.stopWatchingMode(it)
                appOpsCallback = null
            }
        } catch (_: Exception) {}
    }

    private fun registerNetworkCallback() {
        try {
            connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val request = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()
            networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    debugPrint("🌐 [Network] Internet available — triggering MQTT reconnect")
                    handler.post {
                        if (!isDestroyed && !isMqttConnected) {
                            mqttReconnectRunnable?.let { handler.removeCallbacks(it) }
                            mqttReconnectRunnable = null
                            connectMqtt()
                        }
                    }
                }
                override fun onLost(network: Network) {
                    debugPrint("🌐 [Network] Internet lost")
                    isMqttConnected = false
                    handler.post {
                        updateNotification("❌ MQTT offline — no internet…", false)
                    }
                }
            }
            connectivityManager?.registerNetworkCallback(request, networkCallback!!)
            debugPrint("✅ [Network] Connectivity callback registered")
        } catch (e: Exception) {
            debugPrint("⚠️ [Network] registerNetworkCallback failed: ${e.message}")
        }
    }

    private fun unregisterNetworkCallback() {
        try {
            networkCallback?.let {
                connectivityManager?.unregisterNetworkCallback(it)
                networkCallback = null
            }
        } catch (_: Exception) {}
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Helpers
    // ═════════════════════════════════════════════════════════════════════════

    private fun getStringPref(
        prefs: android.content.SharedPreferences, vararg keys: String
    ): String {
        for (key in keys) {
            val v = prefs.getString(key, "")
            if (!v.isNullOrEmpty()) return v
        }
        return ""
    }

    private fun isLocationEnabled(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                (getSystemService(Context.LOCATION_SERVICE) as SysLocationManager).isLocationEnabled
            } else {
                @Suppress("DEPRECATION")
                Settings.Secure.getInt(
                    contentResolver, Settings.Secure.LOCATION_MODE
                ) != Settings.Secure.LOCATION_MODE_OFF
            }
        } catch (_: Exception) { false }
    }

    private fun checkLocationPermission(): Boolean {
        return try {
            ContextCompat.checkSelfPermission(
                this, Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED ||
                    ContextCompat.checkSelfPermission(
                        this, Manifest.permission.ACCESS_COARSE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED
        } catch (_: Exception) { false }
    }

    private fun debugPrint(msg: String) = android.util.Log.d("LocationMonitor", msg)

    // ─── Working Timer (Kotlin side — all devices pe survive karta hai) ────────

    private fun startWorkingTimer() {
        workingTimerRunnable?.let { handler.removeCallbacks(it) }
        workingTimerRunnable = object : Runnable {
            override fun run() {
                if (isDestroyed) return

                // ✅ FIX: isClockedIn check NAHI karo yahan
                // Critical event (location off/permission revoked) isClockedIn=false likh deta tha
                // aur timer khud band ho jaata tha jabke user ne manually clockout nahi kiya tha.
                // Timer sirf 2 jagah band hoga: (1) stopAllLoops() — jo sirf actual clockout/destroy pe chal
                // aur (2) isDestroyed=true — service destroy hone pe
                // isFrozen bhi check nahi karein — frozen pe bhi time dikhana chahiye

                workingSeconds++
                val hours   = workingSeconds / 3600
                val minutes = (workingSeconds % 3600) / 60
                val secs    = workingSeconds % 60
                val timeStr = "%02d:%02d:%02d".format(hours, minutes, secs)

                updateWorkingNotification(timeStr)

                if (!isDestroyed) handler.postDelayed(this, 1000L)
            }
        }
        handler.postDelayed(workingTimerRunnable!!, 1000L)
        debugPrint("✅ [Timer] Working timer started at $workingSeconds seconds")
    }

    private fun updateWorkingNotification(timeStr: String) {
        val pi = PendingIntent.getActivity(
            this, 1,  // requestCode 1 — NOTIFICATION_ID=1001 se alag
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val n = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Working")
            .setContentText("Time: $timeStr")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pi)
            .setOngoing(true)   // Swipe se dismiss nahi hogi
            .setSilent(true)
            .build()
        try {
            (getSystemService(NotificationManager::class.java))
                .notify(WORKING_NOTIFICATION_ID, n)
        } catch (e: Exception) {
            debugPrint("⚠️ [Timer] Working notification update failed: ${e.message}")
        }
    }

    // ─── Notifications ────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Location Monitor Service",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Monitors location for attendance tracking"
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            }
        )
        nm.createNotificationChannel(
            NotificationChannel(
                URGENT_CHANNEL_ID,
                "URGENT Auto Clockout",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 1000, 500, 1000)
                enableLights(true)
                lightColor = android.graphics.Color.RED
            }
        )
    }

    private fun buildNotification(): Notification {
        val pi = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("BookIT Attendance Active")
            .setContentText("⏳ Starting MQTT tracking…")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pi)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    private fun updateNotification(text: String, isAlert: Boolean) {
        val pi = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val n = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(if (isAlert) "⚠️ ATTENTION REQUIRED" else "BookIT Attendance Active")
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pi)
            .setOngoing(true)
            .setSilent(!isAlert)
            .apply { if (isAlert) setColor(android.graphics.Color.RED) }
            .build()
        (getSystemService(NotificationManager::class.java)).notify(NOTIFICATION_ID, n)
    }

    private fun showCriticalNotification(reason: String, time: String) {
        val title = when (reason) {
            "System ClockOut - Location Off"       -> "⚠️ LOCATION TURNED OFF"
            "System ClockOut - Permission Revoked" -> "⚠️ PERMISSION REVOKED"
            else                                   -> "⚠️ AUTO CLOCKOUT"
        }
        val pi = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val n = NotificationCompat.Builder(this, URGENT_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText("Auto clockout at $time. Open app to sync.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(pi)
            .setVibrate(longArrayOf(0, 1000, 500, 1000))
            .build()
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(9998, n)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// NativeDBHelper
// ─────────────────────────────────────────────────────────────────────────────

class NativeDBHelper(context: Context) :
    SQLiteOpenHelper(context, "bookIt.db", null, 1) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """CREATE TABLE IF NOT EXISTS location_tracking (
                locationtracking_id   TEXT PRIMARY KEY,
                locationtracking_date TEXT,
                locationtracking_time TEXT,
                user_id               TEXT,
                lat_in                TEXT,
                lng_in                TEXT,
                booker_name           TEXT,
                designation           TEXT,
                posted                INTEGER DEFAULT 0,
                company_code          TEXT DEFAULT ''
            )"""
        )
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {}

    fun insertLocationRow(
        id: String, date: String, time: String,
        userId: String, lat: String, lng: String,
        bookerName: String, designation: String, companyCode: String
    ) {
        val cv = ContentValues().apply {
            put("locationtracking_id",   id)
            put("locationtracking_date", date)
            put("locationtracking_time", time)
            put("user_id",               userId)
            put("lat_in",                lat)
            put("lng_in",                lng)
            put("booker_name",           bookerName)
            put("designation",           designation)
            put("posted",                0)
            put("company_code",          companyCode)
        }
        writableDatabase.insertWithOnConflict(
            "location_tracking", null, cv, SQLiteDatabase.CONFLICT_IGNORE
        )
    }

    fun getUnpostedRows(): List<Map<String, String>> {
        val rows    = mutableListOf<Map<String, String>>()
        val cursor  = readableDatabase.rawQuery(
            "SELECT * FROM location_tracking WHERE posted = 0 ORDER BY locationtracking_date, locationtracking_time",
            null
        )
        cursor.use {
            while (it.moveToNext()) {
                val row = mutableMapOf<String, String>()
                for (i in 0 until it.columnCount) {
                    row[it.getColumnName(i)] = it.getString(i) ?: ""
                }
                rows.add(row)
            }
        }
        return rows
    }

    fun markPosted(ids: List<String>) {
        if (ids.isEmpty()) return
        val db           = writableDatabase
        val placeholders = ids.joinToString(",") { "?" }
        db.execSQL(
            "UPDATE location_tracking SET posted = 1 WHERE locationtracking_id IN ($placeholders)",
            ids.toTypedArray()
        )
    }
}