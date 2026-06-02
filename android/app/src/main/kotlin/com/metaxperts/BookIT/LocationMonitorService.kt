//
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
//    private val CHANNEL_ID              = "location_monitor_channel"
//    private val URGENT_CHANNEL_ID       = "urgent_auto_clockout_channel"
//    private val NOTIFICATION_ID         = 1001
//    private val WORKING_NOTIFICATION_ID = 1002
//    private val CHECK_INTERVAL          = 2_000L
//    private val MQTT_PUBLISH_INTERVAL   = 5_000L
//    private val MQTT_RECONNECT_DELAY    = 10_000L
//    private val WAKELOCK_TIMEOUT_MS     = 6 * 60 * 60 * 1000L  // 6 hours
//    private val WATCHDOG_INTERVAL       = 30_000L
//    private val GPS_HEARTBEAT_TIMEOUT   = 60_000L
//
//    private val PREF_HTTP_POST_ANCHOR_WALL = "flutter.http_post_anchor_wall_ms"
//    private val KEY_KOTLIN_MASTER = "flutter.kotlin_service_is_master"
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
//    // ✅ NEW: Fake GPS Detection
//    private val KEY_FAKE_GPS_DETECTED  = "flutter.fake_gps_detected"
//    private val KEY_FAKE_GPS_REASON    = "System ClockOut - Fake GPS Detected"
//    private val FAKE_GPS_COOLDOWN_MS   = 30_000L
//
//    // Cooldown guard to prevent duplicate events
//    @Volatile private var lastFakeGpsEventTime = 0L
//
//    // ✅ FIX: Track the last real (non-mocked) position separately
//    @Volatile private var lastRealLat = 0.0
//    @Volatile private var lastRealLon = 0.0
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
//    // CPU WakeLock for heartbeat
//    private var cpuWakeLock: PowerManager.WakeLock? = null
//    private var heartbeatRunnable: Runnable? = null
//    private var lastSuccessfulPostTime = 0L
//
//    // Working timer
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
//    // ── Dynamic GPS Policy ────────────────────────────────────────────────────
//    @Volatile private var gpsPolicy: GpsPolicy = GpsPolicy(
//        locationIntervalSec = 60L,
//        gpsAccuracy         = "high"
//    )
//    private var policyRefreshRunnable: Runnable? = null
//
//    // ── HTTP post loop — wall-clock anchor-based exact timing ─────────────────
//    @Volatile private var httpPostAnchorMs = 0L
//    private var httpPostRunnable: Runnable? = null
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
//        @Volatile
//        var isRunning = false
//            private set
//
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
//        isRunning = true
//
//        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//            .edit()
//            .putBoolean(KEY_KOTLIN_MASTER, true)
//            .apply()
//
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
//        debugPrint("✅ [Service] onCreate complete — Kotlin is master")
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
//        // Restore working timer from clockIn time
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
//        if (clockedIn && !isFrozen) {
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
//        isRunning = false
//
//        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//            .edit()
//            .putBoolean(KEY_KOTLIN_MASTER, false)
//            .apply()
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
//                MidnightClockoutReceiver.cancel(this)
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
//        debugPrint("🛑 [Service] onDestroy complete — Kotlin master flag cleared")
//    }
//
//    override fun onBind(intent: Intent?): IBinder? = null
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // Monitoring startup / teardown
//    // ═════════════════════════════════════════════════════════════════════════
//
//    private fun startMonitoring() {
//        // ════════════════════════════════════════════════════════════════════
//        // STEP 1 — Policy fetch (synchronous + timeout)
//        // ════════════════════════════════════════════════════════════════════
//        // Hamesha server se FRESH policy lo startup pe (forceRefresh = true).
//        // Background thread pe run hota hai, 5s timeout:
//        //   • Network hai     → server se 30s / 60s / jo bhi ho — wahi use hoga
//        //   • Network nahi    → GpsPolicyManager apna cache return karega
//        //   • Timeout (5s)    → cache ya default use hogi
//        // Koi bhi hardcoded 60L / 30L assumption nahi.
//        // Jo server bole, wahi interval sab loops mein chalega — pehle second se.
//        try {
//            val policyFuture = mqttExecutor.submit<GpsPolicy> {
//                GpsPolicyManager.fetchPolicy(this, forceRefresh = true)
//            }
//            gpsPolicy = try {
//                policyFuture.get(5, java.util.concurrent.TimeUnit.SECONDS)
//            } catch (e: java.util.concurrent.TimeoutException) {
//                debugPrint("⚠️ [Policy] Server fetch timed out (5s) — using cache/default")
//                GpsPolicyManager.fetchPolicy(this, forceRefresh = false)
//            } catch (e: Exception) {
//                debugPrint("⚠️ [Policy] Fetch error: ${e.message} — using cache/default")
//                GpsPolicyManager.fetchPolicy(this, forceRefresh = false)
//            }
//            debugPrint("✅ [Policy] Startup policy ready — interval=${gpsPolicy.locationIntervalSec}s accuracy=${gpsPolicy.gpsAccuracy}")
//        } catch (e: Exception) {
//            debugPrint("⚠️ [Policy] startMonitoring policy block failed: ${e.message}")
//        }
//
//        // ════════════════════════════════════════════════════════════════════
//        // STEP 2 — Start all loops with confirmed policy interval
//        // ════════════════════════════════════════════════════════════════════
//        startLocationUpdates()
//
//        checkRunnable = CheckRunnable()
//        handler.post(checkRunnable!!)
//
//        startMqttPublishing()
//
//        debugPrint("✅ [Service] All loops started — interval=${gpsPolicy.locationIntervalSec}s")
//
//        // resetAnchor=true — naya anchor set karo sahi interval ke saath
//        // ✅ FIX: Dono loops EK SAATH same millisecond pe anchor set karte hain
//        // Pehle BulkPostingScheduler onStartCommand() mein alag start hota tha
//        // jisse dono out-of-phase ho jaate the → 90s gap dashboard pe
//        restartHttpPostLoop(resetAnchor = true)
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        if (prefs.getBoolean(KEY_IS_CLOCKED_IN, false) && !prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) {
//            BulkPostingScheduler.startBulkPostingAlarm(this, resetAnchor = true)
//        }
//
//        // ════════════════════════════════════════════════════════════════════
//        // STEP 3 — Background 5-min policy refresh loop
//        // Agar server pe policy change ho — loadAndApplyPolicy() turant
//        // DONO loops (HttpPostLoop + BulkPostingScheduler) restart karega
//        // ════════════════════════════════════════════════════════════════════
//        startHeartbeat()
//        startWorkingTimer()
//        scheduleKeepAliveAlarm()
//        MidnightClockoutReceiver.schedule(this)
//        startPolicyRefreshLoop()
//    }
//
//    // ─── GPS Policy Functions ─────────────────────────────────────────────────
//
//    private fun loadAndApplyPolicy(forceRefresh: Boolean = false) {
//        // Background thread (mqttExecutor) pe chalta hai
//        val newPolicy = GpsPolicyManager.fetchPolicy(this, forceRefresh)
//
//        val intervalChanged = newPolicy.locationIntervalSec != gpsPolicy.locationIntervalSec
//        val accuracyChanged = newPolicy.gpsAccuracy        != gpsPolicy.gpsAccuracy
//
//        gpsPolicy = newPolicy
//        debugPrint("📋 [Policy] Checked — interval=${gpsPolicy.locationIntervalSec}s accuracy=${gpsPolicy.gpsAccuracy} | intervalChanged=$intervalChanged accuracyChanged=$accuracyChanged")
//
//        // ── GPS provider restart agar accuracy ya interval badla ─────────
//        if ((accuracyChanged || intervalChanged) && locationListener != null) {
//            handler.post {
//                if (!isDestroyed) {
//                    debugPrint("🔄 [Policy] GPS provider restart — interval=${gpsPolicy.locationIntervalSec}s accuracy=${gpsPolicy.gpsAccuracy}")
//                    stopLocationUpdates()
//                    startLocationUpdates()
//                }
//            }
//        }
//
//        // ── Posting loops restart agar interval badla ────────────────────
//        // DONO systems ek saath restart hote hain:
//        //   1. HttpPostLoop          — handler-based loop inside service
//        //   2. BulkPostingScheduler  — AlarmManager-based backup alarm
//        // Pehle sirf HttpPostLoop restart hota tha — BulkPostingScheduler
//        // purane interval pe chalta raha → 30s policy pe bhi 60s data aata tha.
//        // Ab dono sync hain — jo bhi server interval ho (30s/60s/kuch bhi).
//        if (intervalChanged) {
//            debugPrint("🔄 [Policy] Interval changed → ${newPolicy.locationIntervalSec}s — restarting both systems")
//            handler.post {
//                if (!isDestroyed) {
//                    restartHttpPostLoop(resetAnchor = true)
//                    BulkPostingScheduler.startBulkPostingAlarm(this, resetAnchor = true)
//                    debugPrint("✅ [Policy] HttpPostLoop + BulkPostingScheduler restarted @ ${gpsPolicy.locationIntervalSec}s")
//                }
//            }
//        }
//    }
//
//    private fun startPolicyRefreshLoop() {
//        policyRefreshRunnable = object : Runnable {
//            override fun run() {
//                if (isDestroyed) return
//                mqttExecutor.submit { loadAndApplyPolicy(forceRefresh = true) }
//                handler.postDelayed(this, 5 * 60_000L)
//            }
//        }
//        handler.postDelayed(policyRefreshRunnable!!, 5 * 60_000L)
//        debugPrint("✅ [Policy] 5-min refresh loop started")
//    }
//
//    private fun onNetworkRestored() {
//        handler.postDelayed({
//            if (!isDestroyed) {
//                mqttExecutor.submit { loadAndApplyPolicy(forceRefresh = true) }
//                debugPrint("🔄 [Policy] Re-synced after network restore")
//            }
//        }, 5_000L)
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
//            99,
//            keepAliveIntent,
//            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
//        )
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
//    // ─── Heartbeat ────────────────────────────────────────────────────────────
//
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
//    // ─── Wall-clock anchor-based exact HTTP post loop ─────────────────────────
//
//    private fun restartHttpPostLoop(resetAnchor: Boolean = false) {
//        httpPostRunnable?.let { handler.removeCallbacks(it) }
//        httpPostRunnable = null
//
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        val nowWall = System.currentTimeMillis()
//
//        if (resetAnchor) {
//            httpPostAnchorMs = nowWall
//            prefs.edit().putLong(PREF_HTTP_POST_ANCHOR_WALL, httpPostAnchorMs).apply()
//            debugPrint("⚓ [HttpLoop] Anchor RESET (wall-clock) at $httpPostAnchorMs")
//        } else {
//            val savedWall = prefs.getLong(PREF_HTTP_POST_ANCHOR_WALL, 0L)
//            if (savedWall > 0L && savedWall <= nowWall) {
//                httpPostAnchorMs = savedWall
//                debugPrint("⚓ [HttpLoop] Restored wall-clock anchor = $httpPostAnchorMs (age=${(nowWall - savedWall) / 1000}s)")
//            } else {
//                httpPostAnchorMs = nowWall
//                prefs.edit().putLong(PREF_HTTP_POST_ANCHOR_WALL, httpPostAnchorMs).apply()
//                debugPrint("⚓ [HttpLoop] No valid anchor — new wall-clock anchor set at $httpPostAnchorMs")
//            }
//        }
//
//        scheduleNextHttpTick()
//        debugPrint("✅ [HttpLoop] Started — interval=${gpsPolicy.locationIntervalSec}s wall-clock anchor")
//    }
//
//    private fun scheduleNextHttpTick() {
//        if (isDestroyed) return
//
//        val intervalMs = gpsPolicy.locationIntervalSec * 1000L
//        val now = System.currentTimeMillis()
//
//        var anchor = httpPostAnchorMs
//        if (anchor == 0L) {
//            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//            anchor = prefs.getLong(PREF_HTTP_POST_ANCHOR_WALL, 0L)
//            if (anchor == 0L || anchor > now) {
//                anchor = now
//                httpPostAnchorMs = anchor
//                prefs.edit().putLong(PREF_HTTP_POST_ANCHOR_WALL, anchor).apply()
//            } else {
//                httpPostAnchorMs = anchor
//            }
//            debugPrint("⚓ [HttpLoop] Recovered wall-clock anchor=$anchor")
//        }
//
//        val elapsed   = now - anchor
//        val ticksDone = elapsed / intervalMs
//        val nextMs    = (ticksDone + 1) * intervalMs
//        var delayMs   = nextMs - elapsed
//
//        if (delayMs <= 0L) {
//            delayMs = intervalMs - (elapsed % intervalMs)
//            if (delayMs <= 0L) delayMs = 200L
//        }
//
//        debugPrint("⏱️ [HttpLoop] Next tick in ${delayMs}ms (interval=${intervalMs}ms, elapsed=${elapsed}ms)")
//
//        httpPostRunnable = Runnable {
//            if (isDestroyed) return@Runnable
//            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//            val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//            val isFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//            if (clockedIn && !isFrozen) {
//                mqttExecutor.submit { postLocationToServer(prefs) }
//            }
//            scheduleNextHttpTick()
//        }
//        handler.postDelayed(httpPostRunnable!!, delayMs)
//    }
//
//    private fun stopAllLoops() {
//        checkRunnable?.let        { handler.removeCallbacks(it) }
//        mqttPublishRunnable?.let  { handler.removeCallbacks(it) }
//        mqttReconnectRunnable?.let{ handler.removeCallbacks(it) }
//        locationPostRunnable?.let { handler.removeCallbacks(it) }
//        heartbeatRunnable?.let    { handler.removeCallbacks(it) }
//        workingTimerRunnable?.let { handler.removeCallbacks(it) }
//        policyRefreshRunnable?.let{ handler.removeCallbacks(it) }
//        httpPostRunnable?.let     { handler.removeCallbacks(it) }
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
//
//                    // ✅ FIX: Mock GPS check — trigger auto clock-out immediately
//                    if (loc.isFromMockProvider) {
//                        debugPrint("🚨 [GPS] isMocked=true @ (${loc.latitude}, ${loc.longitude})")
//                        handleFakeGpsDetected(loc.latitude, loc.longitude)
//                        return
//                    }
//
//                    // ✅ FIX: Always update real-position cache for non-mocked fixes
//                    lastRealLat = loc.latitude
//                    lastRealLon = loc.longitude
//
//                    val maxAccuracy = when (gpsPolicy.gpsAccuracy) {
//                        "best"   -> 20f
//                        "high"   -> 50f
//                        "medium" -> 100f
//                        "low"    -> 200f
//                        "lowest" -> 500f
//                        else     -> 100f
//                    }
//                    if (loc.accuracy > maxAccuracy) return
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
//            val gpsIntervalMs = gpsPolicy.locationIntervalSec * 1000L
//
//            listOf(SysLocationManager.GPS_PROVIDER, SysLocationManager.NETWORK_PROVIDER)
//                .forEach { provider ->
//                    try {
//                        if (locationManager?.isProviderEnabled(provider) == true) {
//                            locationManager?.requestLocationUpdates(
//                                provider,
//                                gpsIntervalMs,
//                                0f,
//                                locationListener!!, gpsLooper!!
//                            )
//                        }
//                    } catch (_: Exception) {}
//                }
//            debugPrint("✅ [GPS] Location updates started — interval=${gpsPolicy.locationIntervalSec}s accuracy=${gpsPolicy.gpsAccuracy}")
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
//        val BULK_API = "http://119.153.102.7:8001/location/bulk"
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
//        MidnightClockoutReceiver.cancel(this)
//
//        try { (getSystemService(NotificationManager::class.java)).cancel(WORKING_NOTIFICATION_ID) } catch (_: Exception) {}
//        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
//        stopSelf()
//    }
//
//    /**
//     * Called when mock location is detected on the device.
//     * Triggers an immediate auto clock-out with reason "System ClockOut - Fake GPS Detected".
//     * All coordinates are written in ONE atomic commit() — no race condition with separate .apply() blocks.
//     *
//     * @param fakeLat   latitude reported by the mock provider
//     * @param fakeLng   longitude reported by the mock provider
//     */
//    fun handleFakeGpsDetected(fakeLat: Double, fakeLng: Double) {
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//
//        if (!prefs.getBoolean(KEY_IS_CLOCKED_IN, false) ||
//            prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) return
//
//        val now = System.currentTimeMillis()
//        if (now - lastFakeGpsEventTime < FAKE_GPS_COOLDOWN_MS) {
//            debugPrint("⚠️ [FakeGPS-Clockout] Within cooldown — skipping duplicate event")
//            return
//        }
//        lastFakeGpsEventTime = now
//
//        // ✅ FIX: Use the cached real position (never 0,0 unless no fix received yet)
//        val realLat = if (lastRealLat != 0.0) lastRealLat else lastLat
//        val realLon = if (lastRealLon != 0.0) lastRealLon else lastLon
//
//        debugPrint("🚨 [FakeGPS-Clockout] Mock GPS detected — triggering auto clock-out")
//        debugPrint("   fake=($fakeLat, $fakeLng) | real=($realLat, $realLon)")
//
//        handler.post {
//            // ✅ FIX: Pass coords into dedicated method so they are written in ONE atomic commit()
//            handleCriticalEventFakeGps(
//                reason  = KEY_FAKE_GPS_REASON,
//                fakeLat = fakeLat,
//                fakeLng = fakeLng,
//                realLat = realLat,
//                realLng = realLon,
//            )
//        }
//    }
//
//    /**
//     * Fake-GPS-specific critical event handler.
//     * Runs on the main thread (via handler.post). Uses the atomic prefs writer below.
//     */
//    private fun handleCriticalEventFakeGps(
//        reason: String,
//        fakeLat: Double,
//        fakeLng: Double,
//        realLat: Double,
//        realLng: Double,
//    ) {
//        if (isDestroyed) return
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        saveCriticalEventToPrefsWithFakeGps(prefs, reason, fakeLat, fakeLng, realLat, realLng)
//        showCriticalNotification(reason, SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date()))
//        updateNotification("⚠️ AUTO CLOCKOUT: $reason", true)
//        stopAllLoops()
//        disconnectMqtt()
//        MidnightClockoutReceiver.cancel(this)
//        try { (getSystemService(NotificationManager::class.java)).cancel(WORKING_NOTIFICATION_ID) } catch (_: Exception) {}
//        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
//        stopSelf()
//    }
//
//    /**
//     * Atomic prefs write for Fake GPS clock-out.
//     * ALL keys — including fake/real coordinates — go into ONE .commit() call,
//     * eliminating the race condition where fake_gps_lat/lon written with .apply()
//     * could be lost on slow devices before Flutter reads them.
//     */
//    private fun saveCriticalEventToPrefsWithFakeGps(
//        prefs: android.content.SharedPreferences,
//        reason: String,
//        fakeLat: Double,
//        fakeLng: Double,
//        realLat: Double,
//        realLng: Double,
//        eventTime: Date = Date(),
//    ) {
//        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(eventTime)
//        val elapsed   = prefs.getString(KEY_ELAPSED_TIME, "00:00:00") ?: "00:00:00"
//        val clockInT  = prefs.getString("flutter.clockInTime", "") ?: ""
//
//        prefs.edit()
//            // ── Critical event flags ──────────────────────────────────────────
//            .putBoolean(KEY_HAS_CRITICAL_EVENT, true)
//            .putBoolean("has_critical_event_pending", true)
//            .putBoolean(KEY_IS_TIMER_FROZEN, true)
//            .putString(KEY_EVENT_TIMESTAMP, timestamp)
//            .putString(KEY_EVENT_REASON, reason)
//            .putString("critical_event_reason", reason)
//            .putString(KEY_FROZEN_TIME, "00:00:00")
//            .putFloat(KEY_EVENT_DISTANCE, 0f)
//            .putFloat(KEY_EVENT_LAT, 0f)
//            .putFloat(KEY_EVENT_LNG, 0f)
//            .putBoolean(KEY_IS_CLOCKED_IN, false)
//            .putBoolean("isClockedIn", false)
//            .putBoolean("flutter.pending_gpx_close", true)
//            // ── Fast clock-out data ───────────────────────────────────────────
//            .putString("flutter.fastClockOutTime", timestamp)
//            .putFloat("flutter.fastClockOutDistance", 0f)
//            .putString("flutter.fastClockOutReason", reason)
//            .putBoolean("flutter.hasFastClockOutData", true)
//            .putBoolean("flutter.clockOutPending", true)
//            // ── ✅ FIX: Fake GPS coordinates — same commit, no race condition ─
//            .putBoolean(KEY_FAKE_GPS_DETECTED, true)
//            .putFloat("flutter.fake_gps_lat", fakeLat.toFloat())
//            .putFloat("flutter.fake_gps_lon", fakeLng.toFloat())
//            .putFloat("flutter.real_gps_lat", realLat.toFloat())
//            .putFloat("flutter.real_gps_lon", realLng.toFloat())
//            // ── Payload JSON ──────────────────────────────────────────────────
//            .putString(
//                "flutter.fastClockOutData",
//                """{"fast_attendanceId":"","fast_userId":"$userId","fast_clockOutTime":"$timestamp","fast_totalTime":"$elapsed","fast_totalDistance":0.0,"fast_latOut":${realLat},"fast_lngOut":${realLng},"fast_address":"","fast_reason":"$reason","fast_savedAt":"${System.currentTimeMillis()}","fast_clockInTime":"$clockInT"}"""
//            )
//            .putString(
//                KEY_BG_CLOCKOUT_PAYLOAD,
//                """{"timestamp":"$timestamp","reason":"$reason","elapsed_at_event":"$elapsed","distance":0.0,"fake_latitude":$fakeLat,"fake_longitude":$fakeLng,"real_latitude":$realLat,"real_longitude":$realLng,"source":"fake_gps"}"""
//            )
//            .commit()   // ← synchronous: everything persisted before Flutter reads
//
//        debugPrint("💾 [FakeGPS-Critical] Saved atomically: reason=$reason ts=$timestamp fake=($fakeLat,$fakeLng) real=($realLat,$realLng)")
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
//                    debugPrint("🌐 [Network] Internet available — triggering MQTT reconnect + policy refresh")
//                    handler.post {
//                        if (!isDestroyed && !isMqttConnected) {
//                            mqttReconnectRunnable?.let { handler.removeCallbacks(it) }
//                            mqttReconnectRunnable = null
//                            connectMqtt()
//                        }
//                        onNetworkRestored()
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
//    // ─── Working Timer ────────────────────────────────────────────────────────
//
//    private fun startWorkingTimer() {
//        workingTimerRunnable?.let { handler.removeCallbacks(it) }
//        workingTimerRunnable = object : Runnable {
//            override fun run() {
//                if (isDestroyed) return
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
//            this, 1,
//            packageManager.getLaunchIntentForPackage(packageName),
//            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
//        )
//        val n = NotificationCompat.Builder(this, CHANNEL_ID)
//            .setContentTitle("Working")
//            .setContentText("Time: $timeStr")
//            .setSmallIcon(R.mipmap.ic_launcher)
//            .setContentIntent(pi)
//            .setOngoing(true)
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
//            "System ClockOut - Fake GPS Detected"  -> "🚨 FAKE GPS DETECTED"
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
//
//// ─────────────────────────────────────────────────────────────────────────────
//// MidnightClockoutReceiver — fires at 22:00, works even when app is killed
//// ─────────────────────────────────────────────────────────────────────────────
//
//class MidnightClockoutReceiver : BroadcastReceiver() {
//
//    companion object {
//        const val ACTION_MIDNIGHT_CLOCKOUT = "com.metaxperts.order_booking_app.MIDNIGHT_CLOCKOUT"
//
//        fun schedule(context: Context) {
//            val prefs     = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
//            val clockedIn = prefs.getBoolean("flutter.isClockedIn", false)
//            val isFrozen  = prefs.getBoolean("flutter.is_timer_frozen", false)
//            if (!clockedIn || isFrozen) return
//
//            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
//
//            val intent = Intent(context, MidnightClockoutReceiver::class.java).apply {
//                action = ACTION_MIDNIGHT_CLOCKOUT
//            }
//            val pi = PendingIntent.getBroadcast(
//                context, 2200,
//                intent,
//                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
//            )
//
//            val now    = java.util.Calendar.getInstance()
//            val target = java.util.Calendar.getInstance().apply {
//                set(java.util.Calendar.HOUR_OF_DAY, 22)
//                set(java.util.Calendar.MINUTE, 0)
//                set(java.util.Calendar.SECOND, 0)
//                set(java.util.Calendar.MILLISECOND, 0)
//            }
//            if (now.after(target)) target.add(java.util.Calendar.DAY_OF_MONTH, 1)
//
//            try {
//                when {
//                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && am.canScheduleExactAlarms() ->
//                        am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.timeInMillis, pi)
//                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
//                        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.timeInMillis, pi)
//                    else ->
//                        am.set(AlarmManager.RTC_WAKEUP, target.timeInMillis, pi)
//                }
//                android.util.Log.d("MidnightClockout", "✅ Midnight alarm scheduled for ${target.time}")
//            } catch (e: Exception) {
//                android.util.Log.d("MidnightClockout", "⚠️ Alarm schedule failed: ${e.message}")
//            }
//        }
//
//        fun cancel(context: Context) {
//            try {
//                val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
//                val intent = Intent(context, MidnightClockoutReceiver::class.java).apply {
//                    action = ACTION_MIDNIGHT_CLOCKOUT
//                }
//                val pi = PendingIntent.getBroadcast(
//                    context, 2200,
//                    intent,
//                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
//                )
//                pi?.let { am.cancel(it) }
//                android.util.Log.d("MidnightClockout", "✅ Midnight alarm cancelled")
//            } catch (e: Exception) {
//                android.util.Log.d("MidnightClockout", "⚠️ Alarm cancel failed: ${e.message}")
//            }
//        }
//    }
//
//    override fun onReceive(context: Context, intent: Intent?) {
//        if (intent?.action != ACTION_MIDNIGHT_CLOCKOUT) return
//
//        val prefs     = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
//        val clockedIn = prefs.getBoolean("flutter.isClockedIn", false)
//        val isFrozen  = prefs.getBoolean("flutter.is_timer_frozen", false)
//
//        android.util.Log.d("MidnightClockout", "⏰ Midnight alarm fired — clockedIn=$clockedIn frozen=$isFrozen")
//
//        if (!clockedIn || isFrozen) return
//
//        val now       = java.util.Date()
//        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(now)
//        val reason    = "System ClockOut - 10:00 PM"
//
//        val userId   = prefs.getString("flutter.userId", "")   ?: ""
//        val elapsed  = prefs.getString("flutter.elapsed_time", "00:00:00") ?: "00:00:00"
//        val clockInT = prefs.getString("flutter.clockInTime", "") ?: ""
//
//        prefs.edit()
//            .putBoolean("flutter.has_critical_event_pending", true)
//            .putBoolean("has_critical_event_pending", true)
//            .putString("flutter.critical_event_reason", reason)
//            .putString("critical_event_reason", reason)
//            .putString("flutter.critical_event_timestamp", timestamp)
//            .putBoolean("flutter.is_timer_frozen", true)
//            .putBoolean("flutter.isClockedIn", false)
//            .putBoolean("isClockedIn", false)
//            .putString("flutter.fastClockOutTime", timestamp)
//            .putFloat("flutter.fastClockOutDistance", 0f)
//            .putString("flutter.fastClockOutReason", reason)
//            .putBoolean("flutter.hasFastClockOutData", true)
//            .putBoolean("flutter.clockOutPending", true)
//            .putString(
//                "flutter.fastClockOutData",
//                """{"fast_attendanceId":"","fast_userId":"$userId","fast_clockOutTime":"$timestamp","fast_totalTime":"$elapsed","fast_totalDistance":0.0,"fast_latOut":0.0,"fast_lngOut":0.0,"fast_address":"","fast_reason":"$reason","fast_savedAt":"${System.currentTimeMillis()}","fast_clockInTime":"$clockInT"}"""
//            )
//            .commit()
//
//        android.util.Log.d("MidnightClockout", "✅ Midnight clockout saved — userId=$userId ts=$timestamp clockIn=$clockInT")
//
//        try {
//            context.stopService(Intent(context, LocationMonitorService::class.java))
//        } catch (e: Exception) {
//            android.util.Log.d("MidnightClockout", "⚠️ stopService: ${e.message}")
//        }
//
//        showMidnightNotification(context, timestamp)
//    }
//
//    private fun showMidnightNotification(context: Context, time: String) {
//        try {
//            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
//            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
//                nm.createNotificationChannel(
//                    NotificationChannel(
//                        "urgent_auto_clockout_channel",
//                        "URGENT Auto Clockout",
//                        NotificationManager.IMPORTANCE_HIGH
//                    ).apply {
//                        enableVibration(true)
//                        vibrationPattern = longArrayOf(0, 1000, 500, 1000)
//                        enableLights(true)
//                        lightColor = android.graphics.Color.RED
//                    }
//                )
//            }
//            val launchIntent = context.packageManager
//                .getLaunchIntentForPackage(context.packageName)?.apply {
//                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
//                }
//            val pi = PendingIntent.getActivity(
//                context, 0,
//                launchIntent,
//                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
//            )
//            val n = NotificationCompat.Builder(context, "urgent_auto_clockout_channel")
//                .setContentTitle("⏰ Auto Clock-Out at 10:00 PM")
//                .setContentText("You were automatically clocked out. Open app to sync.")
//                .setSmallIcon(R.mipmap.ic_launcher)
//                .setPriority(NotificationCompat.PRIORITY_MAX)
//                .setCategory(NotificationCompat.CATEGORY_ALARM)
//                .setAutoCancel(true)
//                .setContentIntent(pi)
//                .setVibrate(longArrayOf(0, 1000, 500, 1000))
//                .build()
//            nm.notify(9997, n)
//        } catch (e: Exception) {
//            android.util.Log.d("MidnightClockout", "⚠️ Notification failed: ${e.message}")
//        }
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
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
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
    private val CHANNEL_ID              = "location_monitor_channel"
    private val URGENT_CHANNEL_ID       = "urgent_auto_clockout_channel"
    private val NOTIFICATION_ID         = 1001
    private val WORKING_NOTIFICATION_ID = 1002
    private val CHECK_INTERVAL          = 3_000L   // ✅ FIX: 2s → 30s (battery saving)
    private val MQTT_PUBLISH_INTERVAL   = 5_000L   // ✅ FIX: 5s → 60s (battery saving)
    private val MQTT_RECONNECT_DELAY    = 10_000L
    // ✅ FIX: Permanent WakeLock hataya — sirf 1 hour safety net agar kuch galat ho
    // Asli GPS wake ab postLocationToServer() mein on-demand hota hai
    private val WAKELOCK_TIMEOUT_MS     = 1 * 60 * 60 * 1000L  // 1 hour (safety net only)
    private val WATCHDOG_INTERVAL       = 30_000L
    private val GPS_HEARTBEAT_TIMEOUT   = 60_000L

    private val PREF_HTTP_POST_ANCHOR_WALL = "flutter.http_post_anchor_wall_ms"
    private val KEY_KOTLIN_MASTER = "flutter.kotlin_service_is_master"

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

    // Fake GPS Detection
    private val KEY_FAKE_GPS_DETECTED  = "flutter.fake_gps_detected"
    private val KEY_FAKE_GPS_REASON    = "System ClockOut - Fake GPS Detected"
    private val FAKE_GPS_COOLDOWN_MS   = 30_000L

    @Volatile private var lastFakeGpsEventTime = 0L
    @Volatile private var lastRealLat = 0.0
    @Volatile private var lastRealLon = 0.0

    private val EXTRA_USER_ID      = "extra_user_id"
    private val EXTRA_BOOKER_NAME  = "extra_booker_name"
    private val EXTRA_DESIGNATION  = "extra_designation"
    private val EXTRA_COMPANY_CODE = "extra_company_code"

    // ─── State ───────────────────────────────────────────────────────────────
    private lateinit var handler: Handler
    // ✅ FIX: Old LocationManager + HandlerThread removed — FusedLocationProvider use karo
    private var fusedClient: FusedLocationProviderClient? = null
    private var fusedCallback: LocationCallback? = null

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

    // ✅ FIX: wakeLock sirf safety net — onCreate mein acquire NAHI karo
    // postLocationToServer() mein on-demand acquire/release hoga
    private var wakeLock: PowerManager.WakeLock? = null

    // CPU WakeLock for heartbeat (short-lived, 10s max)
    private var cpuWakeLock: PowerManager.WakeLock? = null
    private var heartbeatRunnable: Runnable? = null
    private var lastSuccessfulPostTime = 0L

    private var workingTimerRunnable: Runnable? = null
    private var workingSeconds = 0L

    // Identity
    private var userId      = ""
    private var bookerName  = ""
    private var designation = ""
    private var companyCode = ""

    // Location
    @Volatile private var lastLat      = 0.0
    @Volatile private var lastLon      = 0.0
    @Volatile private var lastSavedLat  = 0.0
    @Volatile private var lastSavedLon  = 0.0
    @Volatile private var lastSavedTime = 0L
    private val recentFixes = ArrayDeque<Location>(3)
    @Volatile private var lastAccuracy = 0f
    @Volatile private var lastSpeed    = 0f
    private var lastHeartbeatTime: Long = 0

    // Dynamic GPS Policy
    @Volatile private var gpsPolicy: GpsPolicy = GpsPolicy(
        locationIntervalSec = 60L,
        gpsAccuracy         = "high"
    )
    private var policyRefreshRunnable: Runnable? = null

    // HTTP post loop
    @Volatile private var httpPostAnchorMs = 0L
    private var httpPostRunnable: Runnable? = null

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
            handler.postDelayed(this, CHECK_INTERVAL)  // 30s interval
        }
    }

    inner class MqttPublishRunnable : Runnable {
        override fun run() {
            if (isDestroyed) return
            publishLocationToMqtt()
            handler.postDelayed(this, MQTT_PUBLISH_INTERVAL)  // 60s interval
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

    // ─── Companion ────────────────────────────────────────────────────────────
    companion object {
        @Volatile
        var isRunning = false
            private set

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
        isRunning = true

        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_KOTLIN_MASTER, true)
            .apply()

        handler = Handler(Looper.getMainLooper())

        // ✅ FIX: WakeLock sirf initialize karo — acquire NAHI karo
        // Permanent WakeLock = lagatar heat + battery drain
        // Ab GPS save karte waqt on-demand acquire hoga (postLocationToServer mein)
        // Yeh 1-hour safety net hai — agar koi edge case ho to bhi service survive kare
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "BookIT::LocationServiceWakeLock"
            )
            // ✅ FIX: wakeLock?.acquire() HATA DIYA — on-demand acquire use hoga
            debugPrint("✅ [Service] WakeLock initialized (NOT acquired — on-demand mode)")
        } catch (e: Exception) {
            debugPrint("⚠️ [Service] WakeLock init failed: ${e.message}")
        }

        registerReceivers()
        registerAppOpsListener()
        registerNetworkCallback()
        debugPrint("✅ [Service] onCreate complete — Kotlin is master")
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

        if (clockedIn && !isFrozen) {
            try {
                WorkManagerBulkPoster.schedule(this)
            } catch (e: Exception) {
                debugPrint("⚠️ [Service] WorkManager not available: ${e.message}")
            }
            debugPrint("✅ [Service] Backup systems started: WorkManager")
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
        isRunning = false

        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_KOTLIN_MASTER, false)
            .apply()

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
                MidnightClockoutReceiver.cancel(this)
            } else {
                debugPrint("🔄 [Service] onDestroy while clocked in — scheduling restart")
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

        // ✅ FIX: Release wakelocks safely
        try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (_: Exception) {}
        try { if (cpuWakeLock?.isHeld == true) cpuWakeLock?.release() } catch (_: Exception) {}

        mqttExecutor.shutdown()
        super.onDestroy()
        debugPrint("🛑 [Service] onDestroy complete")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ═════════════════════════════════════════════════════════════════════════
    // Monitoring startup
    // ═════════════════════════════════════════════════════════════════════════

    private fun startMonitoring() {
        try {
            val policyFuture = mqttExecutor.submit<GpsPolicy> {
                GpsPolicyManager.fetchPolicy(this, forceRefresh = true)
            }
            gpsPolicy = try {
                policyFuture.get(5, java.util.concurrent.TimeUnit.SECONDS)
            } catch (e: java.util.concurrent.TimeoutException) {
                debugPrint("⚠️ [Policy] Server fetch timed out — using cache/default")
                GpsPolicyManager.fetchPolicy(this, forceRefresh = false)
            } catch (e: Exception) {
                debugPrint("⚠️ [Policy] Fetch error: ${e.message} — using cache/default")
                GpsPolicyManager.fetchPolicy(this, forceRefresh = false)
            }
            debugPrint("✅ [Policy] Startup policy — interval=${gpsPolicy.locationIntervalSec}s accuracy=${gpsPolicy.gpsAccuracy}")
        } catch (e: Exception) {
            debugPrint("⚠️ [Policy] startMonitoring policy block failed: ${e.message}")
        }

        startLocationUpdates()

        checkRunnable = CheckRunnable()
        handler.post(checkRunnable!!)

        startMqttPublishing()

        debugPrint("✅ [Service] All loops started — interval=${gpsPolicy.locationIntervalSec}s")

        restartHttpPostLoop(resetAnchor = true)
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (prefs.getBoolean(KEY_IS_CLOCKED_IN, false) && !prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) {
            BulkPostingScheduler.startBulkPostingAlarm(this, resetAnchor = true)
        }

        startHeartbeat()
        startWorkingTimer()
        scheduleKeepAliveAlarm()
        MidnightClockoutReceiver.schedule(this)
        startPolicyRefreshLoop()
    }

    // ─── GPS Policy ───────────────────────────────────────────────────────────

    private fun loadAndApplyPolicy(forceRefresh: Boolean = false) {
        val newPolicy = GpsPolicyManager.fetchPolicy(this, forceRefresh)
        val intervalChanged = newPolicy.locationIntervalSec != gpsPolicy.locationIntervalSec
        val accuracyChanged = newPolicy.gpsAccuracy        != gpsPolicy.gpsAccuracy

        gpsPolicy = newPolicy
        debugPrint("📋 [Policy] Applied — interval=${gpsPolicy.locationIntervalSec}s accuracy=${gpsPolicy.gpsAccuracy}")

        if ((accuracyChanged || intervalChanged) && fusedCallback != null) {
            handler.post {
                if (!isDestroyed) {
                    debugPrint("🔄 [Policy] GPS restart — interval=${gpsPolicy.locationIntervalSec}s")
                    stopLocationUpdates()
                    startLocationUpdates()
                }
            }
        }

        if (intervalChanged) {
            debugPrint("🔄 [Policy] Interval → ${newPolicy.locationIntervalSec}s — restarting both systems")
            handler.post {
                if (!isDestroyed) {
                    restartHttpPostLoop(resetAnchor = true)
                    BulkPostingScheduler.startBulkPostingAlarm(this, resetAnchor = true)
                }
            }
        }
    }

    private fun startPolicyRefreshLoop() {
        policyRefreshRunnable = object : Runnable {
            override fun run() {
                if (isDestroyed) return
                mqttExecutor.submit { loadAndApplyPolicy(forceRefresh = true) }
                handler.postDelayed(this, 5 * 60_000L)
            }
        }
        handler.postDelayed(policyRefreshRunnable!!, 5 * 60_000L)
        debugPrint("✅ [Policy] 5-min refresh loop started")
    }

    private fun onNetworkRestored() {
        handler.postDelayed({
            if (!isDestroyed) {
                mqttExecutor.submit { loadAndApplyPolicy(forceRefresh = true) }
                debugPrint("🔄 [Policy] Re-synced after network restore")
            }
        }, 5_000L)
    }

    private fun scheduleKeepAliveAlarm() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_IS_CLOCKED_IN, false) || prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) return

        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val keepAliveIntent = Intent(applicationContext, ServiceRestartReceiver::class.java).apply {
            action = ServiceRestartReceiver.ACTION_RESTART_SERVICE
        }
        val pIntent = PendingIntent.getBroadcast(
            applicationContext, 99, keepAliveIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
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
            debugPrint("✅ [KeepAlive] 15-min alarm set")
        } catch (e: Exception) {
            debugPrint("⚠️ [KeepAlive] Alarm failed: ${e.message}")
        }
    }

    // ─── Heartbeat ────────────────────────────────────────────────────────────

    private fun startHeartbeat() {
        heartbeatRunnable = object : Runnable {
            override fun run() {
                if (isDestroyed) return
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                if (prefs.getBoolean(KEY_IS_CLOCKED_IN, false) &&
                    !prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) {
                    acquireCpuWakeLock()
                    mqttExecutor.submit {
                        syncUnpostedRows()
                        debugPrint("💓 [Heartbeat] Bulk sync executed")
                    }
                }
                if (!isDestroyed) handler.postDelayed(this, 30_000L)
            }
        }
        handler.postDelayed(heartbeatRunnable!!, 30_000L)
        debugPrint("✅ [Heartbeat] Started (30s interval)")
    }

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
                cpuWakeLock?.acquire(10_000L)  // sirf 10s — sync ke liye kaafi
                debugPrint("✅ [WakeLock] CPU lock acquired (10s)")
            }
        } catch (e: Exception) {
            debugPrint("⚠️ [WakeLock] Failed: ${e.message}")
        }
    }

    // ─── HTTP Post Loop ───────────────────────────────────────────────────────

    private fun restartHttpPostLoop(resetAnchor: Boolean = false) {
        httpPostRunnable?.let { handler.removeCallbacks(it) }
        httpPostRunnable = null

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val nowWall = System.currentTimeMillis()

        if (resetAnchor) {
            httpPostAnchorMs = nowWall
            prefs.edit().putLong(PREF_HTTP_POST_ANCHOR_WALL, httpPostAnchorMs).apply()
            debugPrint("⚓ [HttpLoop] Anchor RESET at $httpPostAnchorMs")
        } else {
            val savedWall = prefs.getLong(PREF_HTTP_POST_ANCHOR_WALL, 0L)
            if (savedWall > 0L && savedWall <= nowWall) {
                httpPostAnchorMs = savedWall
                debugPrint("⚓ [HttpLoop] Restored anchor (age=${(nowWall - savedWall) / 1000}s)")
            } else {
                httpPostAnchorMs = nowWall
                prefs.edit().putLong(PREF_HTTP_POST_ANCHOR_WALL, httpPostAnchorMs).apply()
                debugPrint("⚓ [HttpLoop] No valid anchor — new anchor set")
            }
        }

        scheduleNextHttpTick()
        debugPrint("✅ [HttpLoop] Started — interval=${gpsPolicy.locationIntervalSec}s")
    }

    private fun scheduleNextHttpTick() {
        if (isDestroyed) return

        val intervalMs = gpsPolicy.locationIntervalSec * 1000L
        val now = System.currentTimeMillis()

        var anchor = httpPostAnchorMs
        if (anchor == 0L) {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            anchor = prefs.getLong(PREF_HTTP_POST_ANCHOR_WALL, 0L)
            if (anchor == 0L || anchor > now) {
                anchor = now
                httpPostAnchorMs = anchor
                prefs.edit().putLong(PREF_HTTP_POST_ANCHOR_WALL, anchor).apply()
            } else {
                httpPostAnchorMs = anchor
            }
        }

        val elapsed   = now - anchor
        val ticksDone = elapsed / intervalMs
        val nextMs    = (ticksDone + 1) * intervalMs
        var delayMs   = nextMs - elapsed

        if (delayMs <= 0L) {
            delayMs = intervalMs - (elapsed % intervalMs)
            if (delayMs <= 0L) delayMs = 200L
        }

        debugPrint("⏱️ [HttpLoop] Next tick in ${delayMs / 1000}s")

        httpPostRunnable = Runnable {
            if (isDestroyed) return@Runnable
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            if (prefs.getBoolean(KEY_IS_CLOCKED_IN, false) &&
                !prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) {
                mqttExecutor.submit { postLocationToServer(prefs) }
            }
            scheduleNextHttpTick()
        }
        handler.postDelayed(httpPostRunnable!!, delayMs)
    }

    private fun stopAllLoops() {
        checkRunnable?.let        { handler.removeCallbacks(it) }
        mqttPublishRunnable?.let  { handler.removeCallbacks(it) }
        mqttReconnectRunnable?.let{ handler.removeCallbacks(it) }
        locationPostRunnable?.let { handler.removeCallbacks(it) }
        heartbeatRunnable?.let    { handler.removeCallbacks(it) }
        workingTimerRunnable?.let { handler.removeCallbacks(it) }
        policyRefreshRunnable?.let{ handler.removeCallbacks(it) }
        httpPostRunnable?.let     { handler.removeCallbacks(it) }
        try { (getSystemService(NotificationManager::class.java)).cancel(WORKING_NOTIFICATION_ID) } catch (_: Exception) {}
        handler.removeCallbacksAndMessages(null)
        stopLocationUpdates()
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ✅ FIX: GPS — FusedLocationProvider (Android recommended, battery efficient)
    // Old: LocationManager (GPS_PROVIDER + NETWORK_PROVIDER dono = double updates)
    // New: FusedLocationProvider — smart mix, exact interval, PRIORITY_BALANCED = less heat
    // ═════════════════════════════════════════════════════════════════════════

    private fun startLocationUpdates() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION)
            != PackageManager.PERMISSION_GRANTED) return

        try {
            if (fusedCallback != null) return  // already running

            fusedClient = LocationServices.getFusedLocationProviderClient(this)

            val intervalMs = gpsPolicy.locationIntervalSec * 1000L

            // ✅ Priority based on policy accuracy setting
            val priority = when (gpsPolicy.gpsAccuracy) {
                "best", "high" -> Priority.PRIORITY_HIGH_ACCURACY
                "medium"       -> Priority.PRIORITY_BALANCED_POWER_ACCURACY
                "low", "lowest"-> Priority.PRIORITY_LOW_POWER
                else           -> Priority.PRIORITY_BALANCED_POWER_ACCURACY
            }

            val request = LocationRequest.Builder(intervalMs)
                .setMinUpdateIntervalMillis(intervalMs)        // ✅ OS se pehle update mat do
                .setMaxUpdateDelayMillis(intervalMs + 5_000L)  // 5s grace period
                .setPriority(priority)
                .build()

            fusedCallback = object : LocationCallback() {
                override fun onLocationResult(result: LocationResult) {
                    val loc = result.lastLocation ?: return

                    // ✅ Mock GPS check
                    if (loc.isFromMockProvider) {
                        debugPrint("🚨 [GPS] Mock detected @ (${loc.latitude}, ${loc.longitude})")
                        handleFakeGpsDetected(loc.latitude, loc.longitude)
                        return
                    }

                    lastRealLat = loc.latitude
                    lastRealLon = loc.longitude

                    // ✅ Accuracy filter per policy
                    val maxAccuracy = when (gpsPolicy.gpsAccuracy) {
                        "best"   -> 20f
                        "high"   -> 50f
                        "medium" -> 100f
                        "low"    -> 200f
                        "lowest" -> 500f
                        else     -> 100f
                    }
                    if (loc.accuracy > maxAccuracy) {
                        debugPrint("⚠️ [GPS] Low accuracy (${loc.accuracy}m > ${maxAccuracy}m) — skipping")
                        return
                    }

                    // Weighted smoothing
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

                    debugPrint("📍 [GPS] Fix: lat=$smoothLat lon=$smoothLon acc=${loc.accuracy}m")
                }
            }

            fusedClient?.requestLocationUpdates(
                request,
                fusedCallback!!,
                Looper.getMainLooper()
            )

            debugPrint("✅ [GPS] FusedLocation started — interval=${gpsPolicy.locationIntervalSec}s priority=${priority}")
        } catch (e: Exception) {
            debugPrint("⚠️ [GPS] FusedLocation failed: ${e.message}")
        }
    }

    private fun stopLocationUpdates() {
        try {
            fusedCallback?.let { fusedClient?.removeLocationUpdates(it) }
        } catch (_: Exception) {}
        fusedCallback = null
        fusedClient   = null
        debugPrint("🛑 [GPS] FusedLocation stopped")
    }

    // ═════════════════════════════════════════════════════════════════════════
    // MQTT
    // ═════════════════════════════════════════════════════════════════════════

    private fun connectMqtt() {
        if (isMqttConnected) return
        mqttExecutor.submit {
            if (isDestroyed || isMqttConnected) return@submit
            try {
                val clientId = "android_${userId}_${System.currentTimeMillis()}"
                val client   = MqttClient("tcp://$MQTT_HOST:$MQTT_PORT", clientId, MemoryPersistence())
                val opts = MqttConnectOptions().apply {
                    isCleanSession       = true
                    connectionTimeout    = 10
                    keepAliveInterval    = 30
                    isAutomaticReconnect = false
                }
                client.setCallback(object : MqttCallback {
                    override fun connectionLost(cause: Throwable?) {
                        isMqttConnected = false
                        handler.post { scheduleReconnect() }
                    }
                    override fun messageArrived(topic: String?, msg: MqttMessage?) {}
                    override fun deliveryComplete(token: IMqttDeliveryToken?) {}
                })
                client.connect(opts)
                mqttClient      = client
                isMqttConnected = true
                handler.post { updateNotification("✅ MQTT connected — tracking active", false) }
                debugPrint("✅ [MQTT] Connected → tcp://$MQTT_HOST:$MQTT_PORT")
            } catch (e: Exception) {
                isMqttConnected = false
                handler.post { scheduleReconnect() }
                debugPrint("❌ [MQTT] Connect failed: ${e.message}")
            }
        }
    }

    private fun disconnectMqtt() {
        mqttReconnectRunnable?.let { handler.removeCallbacks(it) }
        mqttReconnectRunnable = null
        mqttPublishRunnable?.let { handler.removeCallbacks(it) }
        mqttPublishRunnable = null
        mqttExecutor.submit {
            try { if (mqttClient?.isConnected == true) mqttClient?.disconnect(0) } catch (_: Exception) {}
            mqttClient      = null
            isMqttConnected = false
        }
    }

    private fun scheduleReconnect() {
        if (isDestroyed) return
        mqttReconnectRunnable?.let { handler.removeCallbacks(it) }
        mqttReconnectRunnable = Runnable {
            if (!isDestroyed && !isMqttConnected) connectMqtt()
        }
        handler.postDelayed(mqttReconnectRunnable!!, MQTT_RECONNECT_DELAY)
    }

    private fun publishLocationToMqtt() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_IS_CLOCKED_IN, false)) return
        if (prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) return
        if (lastLat == 0.0 && lastLon == 0.0) {
            updateNotification("⏳ Waiting for GPS fix…", false)
            return
        }

        val payload = JSONObject().apply {
            put("device_id",    userId)
            put("company_code", companyCode.ifEmpty { COMPANY_CODE })
            put("emp_name",     bookerName)
            put("dept_id",      designation)
            put("lat",          lastLat)
            put("lon",          lastLon)
            put("accuracy",     lastAccuracy)
            put("speed",        lastSpeed)
            put("track_id",     System.currentTimeMillis())
            put("timestamp",    SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date()))
            put("source",       "android_background_service")
        }.toString()

        mqttExecutor.submit {
            try {
                val client = mqttClient
                if (!isMqttConnected || client == null || !client.isConnected) {
                    handler.post { scheduleReconnect() }
                    return@submit
                }
                val msg = MqttMessage(payload.toByteArray(Charsets.UTF_8)).apply {
                    qos        = 1
                    isRetained = false
                }
                client.publish(mqttTopic, msg)
                mqttPublishCount++
                handler.post { updateNotification("✅ Live tracking • #$mqttPublishCount sent", false) }
                debugPrint("✅ [MQTT] #$mqttPublishCount published")
            } catch (e: Exception) {
                isMqttConnected = false
                handler.post { scheduleReconnect() }
            }
        }
    }

    private fun startMqttPublishing() {
        connectMqtt()
        mqttPublishRunnable?.let { handler.removeCallbacks(it) }
        mqttPublishRunnable = MqttPublishRunnable()
        handler.postDelayed(mqttPublishRunnable!!, MQTT_PUBLISH_INTERVAL)
        debugPrint("✅ [MQTT] 60-second publish loop started")
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ✅ FIX: HTTP POST — On-demand WakeLock + Hard Time Gate
    // WakeLock: sirf GPS save karte waqt acquire karo, phir release karo
    // Time Gate: policy interval se pehle koi save nahi hoga (spurious update block)
    // ═════════════════════════════════════════════════════════════════════════

    private val nativeDb: NativeDBHelper by lazy { NativeDBHelper(applicationContext) }

    private fun postLocationToServer(prefs: android.content.SharedPreferences) {
        val lat = lastLat
        val lon = lastLon
        if (lat == 0.0 && lon == 0.0) {
            debugPrint("⚠️ [HTTP] No GPS fix — skipping save")
            return
        }

        // ✅ HARD TIME GATE — policy interval se pehle save nahi hoga
        val nowMs = System.currentTimeMillis()
        val minIntervalMs = gpsPolicy.locationIntervalSec * 1000L
        if (lastSavedTime > 0 && (nowMs - lastSavedTime) < minIntervalMs) {
            val waitSec = (minIntervalMs - (nowMs - lastSavedTime)) / 1000
            debugPrint("⏭️ [HTTP] Too soon — skipping (${waitSec}s remaining)")
            return
        }

        // ✅ ON-DEMAND WAKELOCK — sirf save karte waqt CPU jagao
        // 30s kaafi hai: DB write + network sync complete ho jaata hai
        val gpsWl = try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "BookIT::GpsSaveLock").also {
                it.acquire(30_000L)
                debugPrint("✅ [WakeLock] GPS save lock acquired (30s)")
            }
        } catch (e: Exception) {
            debugPrint("⚠️ [WakeLock] GPS save lock failed: ${e.message}")
            null
        }

        try {
            if (lat > 90.0 || lat < -90.0 || lon > 180.0 || lon < -180.0) {
                debugPrint("⚠️ [HTTP] Invalid coordinates — skipping")
                return
            }

            val sdf  = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            val stf  = SimpleDateFormat("HH:mm:ss",   Locale.getDefault())
            val now  = Date()
            val rowId = "LT-$userId-${SimpleDateFormat("dd", Locale.getDefault()).format(now)}" +
                    "-${SimpleDateFormat("MMM", Locale.getDefault()).format(now)}" +
                    "-${UUID.randomUUID().toString().takeLast(6).uppercase()}"
            val code = companyCode.ifEmpty { COMPANY_CODE }

            nativeDb.insertLocationRow(
                id          = rowId,
                date        = sdf.format(now),
                time        = stf.format(now),
                userId      = userId,
                lat         = lat.toString(),
                lng         = lon.toString(),
                bookerName  = bookerName,
                designation = designation,
                companyCode = code
            )
            debugPrint("💾 [HTTP] Saved: $rowId  lat=$lat lng=$lon")

            lastSavedLat  = lat
            lastSavedLon  = lon
            lastSavedTime = nowMs
            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
                .putFloat("flutter.lastSavedLat",  lat.toFloat())
                .putFloat("flutter.lastSavedLon",  lon.toFloat())
                .putLong("flutter.lastSavedTime",  lastSavedTime)
                .apply()

            syncUnpostedRows()

        } catch (e: Exception) {
            debugPrint("❌ [HTTP] Save failed: ${e.message}")
        } finally {
            // ✅ WakeLock release — CPU ab so sakta hai
            try {
                if (gpsWl?.isHeld == true) {
                    gpsWl.release()
                    debugPrint("✅ [WakeLock] GPS save lock released")
                }
            } catch (_: Exception) {}
        }
    }

    private fun syncUnpostedRows() {
        val BULK_API = "http://119.153.102.7:8001/location/bulk"

        val unposted = try { nativeDb.getUnpostedRows() } catch (e: Exception) {
            debugPrint("❌ [HTTP] DB read failed: ${e.message}")
            return
        }

        if (unposted.isEmpty()) {
            debugPrint("✅ [HTTP] No unposted rows")
            return
        }

        debugPrint("🚀 [HTTP] Syncing ${unposted.size} rows → $BULK_API")

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

        try {
            val conn = URL(BULK_API).openConnection() as HttpURLConnection
            conn.apply {
                requestMethod  = "POST"
                connectTimeout = 15_000
                readTimeout    = 30_000
                doOutput       = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Accept",       "application/json")
            }
            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use {
                it.write(JSONObject().put("records", records).toString())
            }
            val code = conn.responseCode
            conn.disconnect()

            if (code in 200..299) {
                val ids = unposted.mapNotNull { it["locationtracking_id"] }
                nativeDb.markPosted(ids)
                debugPrint("✅ [HTTP] Bulk OK ($code) — marked ${ids.size} rows posted")
            } else {
                debugPrint("⚠️ [HTTP] Bulk failed ($code) — retry next tick")
            }
        } catch (e: Exception) {
            debugPrint("📴 [HTTP] Bulk exception: ${e.message} — will retry")
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Service restart
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
        } catch (e: Exception) {
            debugPrint("⚠️ [Restart] Direct start failed: ${e.message}")
        }

        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val restartIntent = Intent(applicationContext, ServiceRestartReceiver::class.java).apply {
            action = ServiceRestartReceiver.ACTION_RESTART_SERVICE
        }
        val delays = longArrayOf(1_500L, 8_000L, 30_000L, 60_000L, 120_000L)
        delays.forEachIndexed { index, delay ->
            val pIntent = PendingIntent.getBroadcast(
                applicationContext, 20 + index, restartIntent,
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
            } catch (e: Exception) {
                debugPrint("⚠️ [Restart] Alarm $index failed: ${e.message}")
            }
        }
        debugPrint("✅ [Service] Restart alarms scheduled")
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Critical events
    // ═════════════════════════════════════════════════════════════════════════

    private fun handleCriticalEvent(reason: String) = handleCriticalEventWithTime(reason, Date())

    private fun handleCriticalEventWithTime(reason: String, eventTime: Date) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) return

        saveCriticalEventToPrefs(prefs, reason, eventTime)
        showCriticalNotification(reason, SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(eventTime))
        updateNotification("⚠️ AUTO CLOCKOUT: $reason", true)
        stopAllLoops()
        disconnectMqtt()
        MidnightClockoutReceiver.cancel(this)
        try { (getSystemService(NotificationManager::class.java)).cancel(WORKING_NOTIFICATION_ID) } catch (_: Exception) {}
        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
        stopSelf()
    }

    fun handleFakeGpsDetected(fakeLat: Double, fakeLng: Double) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_IS_CLOCKED_IN, false) ||
            prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) return

        val now = System.currentTimeMillis()
        if (now - lastFakeGpsEventTime < FAKE_GPS_COOLDOWN_MS) return
        lastFakeGpsEventTime = now

        val realLat = if (lastRealLat != 0.0) lastRealLat else lastLat
        val realLon = if (lastRealLon != 0.0) lastRealLon else lastLon

        handler.post {
            handleCriticalEventFakeGps(KEY_FAKE_GPS_REASON, fakeLat, fakeLng, realLat, realLon)
        }
    }

    private fun handleCriticalEventFakeGps(
        reason: String, fakeLat: Double, fakeLng: Double, realLat: Double, realLng: Double
    ) {
        if (isDestroyed) return
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        saveCriticalEventToPrefsWithFakeGps(prefs, reason, fakeLat, fakeLng, realLat, realLng)
        showCriticalNotification(reason, SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date()))
        updateNotification("⚠️ AUTO CLOCKOUT: $reason", true)
        stopAllLoops()
        disconnectMqtt()
        MidnightClockoutReceiver.cancel(this)
        try { (getSystemService(NotificationManager::class.java)).cancel(WORKING_NOTIFICATION_ID) } catch (_: Exception) {}
        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
        stopSelf()
    }

    private fun saveCriticalEventToPrefsWithFakeGps(
        prefs: android.content.SharedPreferences, reason: String,
        fakeLat: Double, fakeLng: Double, realLat: Double, realLng: Double,
        eventTime: Date = Date()
    ) {
        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(eventTime)
        val elapsed   = prefs.getString(KEY_ELAPSED_TIME, "00:00:00") ?: "00:00:00"
        val clockInT  = prefs.getString("flutter.clockInTime", "") ?: ""

        prefs.edit()
            .putBoolean(KEY_HAS_CRITICAL_EVENT, true)
            .putBoolean("has_critical_event_pending", true)
            .putBoolean(KEY_IS_TIMER_FROZEN, true)
            .putString(KEY_EVENT_TIMESTAMP, timestamp)
            .putString(KEY_EVENT_REASON, reason)
            .putString("critical_event_reason", reason)
            .putString(KEY_FROZEN_TIME, "00:00:00")
            .putFloat(KEY_EVENT_DISTANCE, 0f)
            .putFloat(KEY_EVENT_LAT, 0f)
            .putFloat(KEY_EVENT_LNG, 0f)
            .putBoolean(KEY_IS_CLOCKED_IN, false)
            .putBoolean("isClockedIn", false)
            .putBoolean("flutter.pending_gpx_close", true)
            .putString("flutter.fastClockOutTime", timestamp)
            .putFloat("flutter.fastClockOutDistance", 0f)
            .putString("flutter.fastClockOutReason", reason)
            .putBoolean("flutter.hasFastClockOutData", true)
            .putBoolean("flutter.clockOutPending", true)
            .putBoolean(KEY_FAKE_GPS_DETECTED, true)
            .putFloat("flutter.fake_gps_lat", fakeLat.toFloat())
            .putFloat("flutter.fake_gps_lon", fakeLng.toFloat())
            .putFloat("flutter.real_gps_lat", realLat.toFloat())
            .putFloat("flutter.real_gps_lon", realLng.toFloat())
            .putString("flutter.fastClockOutData",
                """{"fast_attendanceId":"","fast_userId":"$userId","fast_clockOutTime":"$timestamp","fast_totalTime":"$elapsed","fast_totalDistance":0.0,"fast_latOut":${realLat},"fast_lngOut":${realLng},"fast_address":"","fast_reason":"$reason","fast_savedAt":"${System.currentTimeMillis()}","fast_clockInTime":"$clockInT"}""")
            .putString(KEY_BG_CLOCKOUT_PAYLOAD,
                """{"timestamp":"$timestamp","reason":"$reason","elapsed_at_event":"$elapsed","distance":0.0,"fake_latitude":$fakeLat,"fake_longitude":$fakeLng,"real_latitude":$realLat,"real_longitude":$realLng,"source":"fake_gps"}""")
            .commit()
    }

    private fun saveCriticalEventToPrefs(
        prefs: android.content.SharedPreferences, reason: String, eventTime: Date = Date()
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
            .putString("flutter.fastClockOutData",
                """{"fast_attendanceId":"","fast_userId":"$userId","fast_clockOutTime":"$timestamp","fast_totalTime":"$elapsed","fast_totalDistance":0.0,"fast_latOut":0.0,"fast_lngOut":0.0,"fast_address":"","fast_reason":"$reason","fast_savedAt":"${System.currentTimeMillis()}","fast_clockInTime":"$clockInT"}""")
            .putString(KEY_BG_CLOCKOUT_PAYLOAD,
                """{"timestamp":"$timestamp","reason":"$reason","elapsed_at_event":"$elapsed","distance":0.0,"latitude":0.0,"longitude":0.0,"source":"critical_event"}""")
            .commit()

        debugPrint("💾 [Critical] Saved: reason=$reason ts=$timestamp")
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Location + Permission checks
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
            if (now - lastEventTime > 5000 && lastEventReason != "System ClockOut - Permission Revoked") {
                lastEventTime   = now
                lastEventReason = "System ClockOut - Permission Revoked"
                handleCriticalEventWithTime("System ClockOut - Permission Revoked", Date())
                return
            }
        }

        if (wasLocationEnabled && !currentLocEnabled) {
            val now = System.currentTimeMillis()
            if (now - lastEventTime > 5000 && lastEventReason != "System ClockOut - Location Off") {
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
            if (now - lastEventTime > 5000 || lastEventReason != "System ClockOut - Permission Revoked") {
                lastEventTime   = now
                lastEventReason = "System ClockOut - Permission Revoked"
                handleCriticalEventWithTime("System ClockOut - Permission Revoked", Date())
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Broadcast receivers
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
        registerReceiver(locationModeReceiver, IntentFilter(SysLocationManager.MODE_CHANGED_ACTION))
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
                if (pkg == packageName) handler.post { instantCheckAndHandlePermissionRevoke() }
                else handler.post { checkLocationAndPermission() }
            }
            appOpsManager?.startWatchingMode(AppOpsManager.OPSTR_FINE_LOCATION, packageName, listener)
            appOpsCallback = listener
        } catch (e: Exception) {
            debugPrint("⚠️ [AppOps] Register failed: ${e.message}")
        }
    }

    private fun unregisterAppOpsListener() {
        try {
            appOpsCallback?.let { appOpsManager?.stopWatchingMode(it); appOpsCallback = null }
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
                    handler.post {
                        if (!isDestroyed && !isMqttConnected) {
                            mqttReconnectRunnable?.let { handler.removeCallbacks(it) }
                            connectMqtt()
                        }
                        onNetworkRestored()
                    }
                }
                override fun onLost(network: Network) {
                    isMqttConnected = false
                    handler.post { updateNotification("❌ MQTT offline — no internet…", false) }
                }
            }
            connectivityManager?.registerNetworkCallback(request, networkCallback!!)
        } catch (e: Exception) {
            debugPrint("⚠️ [Network] registerNetworkCallback failed: ${e.message}")
        }
    }

    private fun unregisterNetworkCallback() {
        try {
            networkCallback?.let { connectivityManager?.unregisterNetworkCallback(it); networkCallback = null }
        } catch (_: Exception) {}
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Helpers
    // ═════════════════════════════════════════════════════════════════════════

    private fun getStringPref(prefs: android.content.SharedPreferences, vararg keys: String): String {
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
                Settings.Secure.getInt(contentResolver, Settings.Secure.LOCATION_MODE) != Settings.Secure.LOCATION_MODE_OFF
            }
        } catch (_: Exception) { false }
    }

    private fun checkLocationPermission(): Boolean {
        return try {
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                    ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        } catch (_: Exception) { false }
    }

    private fun debugPrint(msg: String) = android.util.Log.d("LocationMonitor", msg)

    // ─── Working Timer ────────────────────────────────────────────────────────

    private fun startWorkingTimer() {
        workingTimerRunnable?.let { handler.removeCallbacks(it) }
        workingTimerRunnable = object : Runnable {
            override fun run() {
                if (isDestroyed) return
                workingSeconds++
                val hours   = workingSeconds / 3600
                val minutes = (workingSeconds % 3600) / 60
                val secs    = workingSeconds % 60
                updateWorkingNotification("%02d:%02d:%02d".format(hours, minutes, secs))
                if (!isDestroyed) handler.postDelayed(this, 1000L)
            }
        }
        handler.postDelayed(workingTimerRunnable!!, 1000L)
        debugPrint("✅ [Timer] Working timer started at $workingSeconds seconds")
    }

    private fun updateWorkingNotification(timeStr: String) {
        val pi = PendingIntent.getActivity(
            this, 1,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val n = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Working")
            .setContentText("Time: $timeStr")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pi)
            .setOngoing(true)
            .setSilent(true)
            .build()
        try {
            (getSystemService(NotificationManager::class.java)).notify(WORKING_NOTIFICATION_ID, n)
        } catch (e: Exception) {
            debugPrint("⚠️ [Timer] Notification update failed: ${e.message}")
        }
    }

    // ─── Notifications ────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Location Monitor Service", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Monitors location for attendance tracking"
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            }
        )
        nm.createNotificationChannel(
            NotificationChannel(URGENT_CHANNEL_ID, "URGENT Auto Clockout", NotificationManager.IMPORTANCE_HIGH).apply {
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 1000, 500, 1000)
                enableLights(true)
                lightColor = android.graphics.Color.RED
            }
        )
    }

    private fun buildNotification(): Notification {
        val pi = PendingIntent.getActivity(this, 0, packageManager.getLaunchIntentForPackage(packageName), PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("BookIT Attendance Active")
            .setContentText("⏳ Starting tracking…")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pi)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    private fun updateNotification(text: String, isAlert: Boolean) {
        val pi = PendingIntent.getActivity(this, 0, packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
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
            "System ClockOut - Fake GPS Detected"  -> "🚨 FAKE GPS DETECTED"
            else                                   -> "⚠️ AUTO CLOCKOUT"
        }
        val pi = PendingIntent.getActivity(this, 0,
            packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
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
        writableDatabase.insertWithOnConflict("location_tracking", null, cv, SQLiteDatabase.CONFLICT_IGNORE)
    }

    fun getUnpostedRows(): List<Map<String, String>> {
        val rows   = mutableListOf<Map<String, String>>()
        val cursor = readableDatabase.rawQuery(
            "SELECT * FROM location_tracking WHERE posted = 0 ORDER BY locationtracking_date, locationtracking_time", null
        )
        cursor.use {
            while (it.moveToNext()) {
                val row = mutableMapOf<String, String>()
                for (i in 0 until it.columnCount) row[it.getColumnName(i)] = it.getString(i) ?: ""
                rows.add(row)
            }
        }
        return rows
    }

    fun markPosted(ids: List<String>) {
        if (ids.isEmpty()) return
        writableDatabase.execSQL(
            "UPDATE location_tracking SET posted = 1 WHERE locationtracking_id IN (${ids.joinToString(",") { "?" }})",
            ids.toTypedArray()
        )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MidnightClockoutReceiver
// ─────────────────────────────────────────────────────────────────────────────

class MidnightClockoutReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_MIDNIGHT_CLOCKOUT = "com.metaxperts.order_booking_app.MIDNIGHT_CLOCKOUT"

        fun schedule(context: Context) {
            val prefs     = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val clockedIn = prefs.getBoolean("flutter.isClockedIn", false)
            val isFrozen  = prefs.getBoolean("flutter.is_timer_frozen", false)
            if (!clockedIn || isFrozen) return

            val am     = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, MidnightClockoutReceiver::class.java).apply { action = ACTION_MIDNIGHT_CLOCKOUT }
            val pi     = PendingIntent.getBroadcast(context, 2200, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

            val now    = java.util.Calendar.getInstance()
            val target = java.util.Calendar.getInstance().apply {
                set(java.util.Calendar.HOUR_OF_DAY, 22)
                set(java.util.Calendar.MINUTE, 0)
                set(java.util.Calendar.SECOND, 0)
                set(java.util.Calendar.MILLISECOND, 0)
            }
            if (now.after(target)) target.add(java.util.Calendar.DAY_OF_MONTH, 1)

            try {
                when {
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && am.canScheduleExactAlarms() ->
                        am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.timeInMillis, pi)
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.timeInMillis, pi)
                    else ->
                        am.set(AlarmManager.RTC_WAKEUP, target.timeInMillis, pi)
                }
                android.util.Log.d("MidnightClockout", "✅ Alarm scheduled for ${target.time}")
            } catch (e: Exception) {
                android.util.Log.d("MidnightClockout", "⚠️ Alarm schedule failed: ${e.message}")
            }
        }

        fun cancel(context: Context) {
            try {
                val am     = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, MidnightClockoutReceiver::class.java).apply { action = ACTION_MIDNIGHT_CLOCKOUT }
                val pi     = PendingIntent.getBroadcast(context, 2200, intent,
                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
                pi?.let { am.cancel(it) }
            } catch (e: Exception) {
                android.util.Log.d("MidnightClockout", "⚠️ Alarm cancel failed: ${e.message}")
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_MIDNIGHT_CLOCKOUT) return

        val prefs     = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val clockedIn = prefs.getBoolean("flutter.isClockedIn", false)
        val isFrozen  = prefs.getBoolean("flutter.is_timer_frozen", false)

        if (!clockedIn || isFrozen) return

        val now       = java.util.Date()
        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(now)
        val reason    = "System ClockOut - 10:00 PM"
        val userId    = prefs.getString("flutter.userId", "")   ?: ""
        val elapsed   = prefs.getString("flutter.elapsed_time", "00:00:00") ?: "00:00:00"
        val clockInT  = prefs.getString("flutter.clockInTime", "") ?: ""

        prefs.edit()
            .putBoolean("flutter.has_critical_event_pending", true)
            .putBoolean("has_critical_event_pending", true)
            .putString("flutter.critical_event_reason", reason)
            .putString("critical_event_reason", reason)
            .putString("flutter.critical_event_timestamp", timestamp)
            .putBoolean("flutter.is_timer_frozen", true)
            .putBoolean("flutter.isClockedIn", false)
            .putBoolean("isClockedIn", false)
            .putString("flutter.fastClockOutTime", timestamp)
            .putFloat("flutter.fastClockOutDistance", 0f)
            .putString("flutter.fastClockOutReason", reason)
            .putBoolean("flutter.hasFastClockOutData", true)
            .putBoolean("flutter.clockOutPending", true)
            .putString("flutter.fastClockOutData",
                """{"fast_attendanceId":"","fast_userId":"$userId","fast_clockOutTime":"$timestamp","fast_totalTime":"$elapsed","fast_totalDistance":0.0,"fast_latOut":0.0,"fast_lngOut":0.0,"fast_address":"","fast_reason":"$reason","fast_savedAt":"${System.currentTimeMillis()}","fast_clockInTime":"$clockInT"}""")
            .commit()

        try { context.stopService(Intent(context, LocationMonitorService::class.java)) } catch (_: Exception) {}
        showMidnightNotification(context, timestamp)
    }

    private fun showMidnightNotification(context: Context, time: String) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                nm.createNotificationChannel(
                    NotificationChannel("urgent_auto_clockout_channel", "URGENT Auto Clockout", NotificationManager.IMPORTANCE_HIGH).apply {
                        enableVibration(true)
                        vibrationPattern = longArrayOf(0, 1000, 500, 1000)
                        enableLights(true)
                        lightColor = android.graphics.Color.RED
                    }
                )
            }
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pi = PendingIntent.getActivity(context, 0, launchIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            val n = NotificationCompat.Builder(context, "urgent_auto_clockout_channel")
                .setContentTitle("⏰ Auto Clock-Out at 10:00 PM")
                .setContentText("You were automatically clocked out. Open app to sync.")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setAutoCancel(true)
                .setContentIntent(pi)
                .setVibrate(longArrayOf(0, 1000, 500, 1000))
                .build()
            nm.notify(9997, n)
        } catch (_: Exception) {}
    }
}