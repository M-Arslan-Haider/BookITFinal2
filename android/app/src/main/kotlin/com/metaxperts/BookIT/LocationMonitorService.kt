//package com.metaxperts.order_booking_app
//
//// ═════════════════════════════════════════════════════════════════════════════
//// LocationMonitorService — FINAL FIX
////
//// ROOT CAUSE OF TIMER STOPPING:
////   Old code used workingSeconds++ (increment per tick).
////   When service restarted (START_STICKY / app resume), workingSeconds was
////   recalculated from clockInTime — but if clockInTime parse failed OR
////   startAllLoops() was called again (e.g. Flutter calls startMonitoring on
////   resume), the old runnable was cancelled + new one started from wrong value.
////
//// FINAL FIX — Wall-clock timer (no increment, no state):
////   Every tick reads System.currentTimeMillis() and clockInTimeMs from prefs.
////   elapsed = (now - clockInTimeMs) / 1000
////   This means:
////     ✅ Timer NEVER stops even if service restarts 10 times
////     ✅ Timer NEVER drifts — always shows real elapsed time
////     ✅ No workingSeconds state to corrupt
////     ✅ Notification always accurate even after phone sleep/wake
////
//// OTHER FIXES:
////   ✅ startWorkingTimer() guard — if already running, don't restart
////   ✅ startAllLoops() guard — timer only starts ONCE per service instance
////   ✅ startForeground() called ONCE (foregroundStarted flag)
////   ✅ START_NOT_STICKY on error paths to avoid OS restart loop
//// ═════════════════════════════════════════════════════════════════════════════
//
//import android.Manifest
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
//import android.location.LocationManager as SysLocationManager
//import android.net.ConnectivityManager
//import android.net.Network
//import android.net.NetworkCapabilities
//import android.net.NetworkRequest
//import android.os.Build
//import android.os.Handler
//import android.os.IBinder
//import android.os.Looper
//import android.os.PowerManager
//import android.provider.Settings
//import androidx.core.app.NotificationCompat
//import androidx.core.content.ContextCompat
//import com.google.android.gms.location.FusedLocationProviderClient
//import com.google.android.gms.location.LocationCallback
//import com.google.android.gms.location.LocationRequest
//import com.google.android.gms.location.LocationResult
//import com.google.android.gms.location.LocationServices
//import com.google.android.gms.location.Priority
//import org.eclipse.paho.client.mqttv3.IMqttDeliveryToken
//import org.eclipse.paho.client.mqttv3.MqttCallback
//import org.eclipse.paho.client.mqttv3.MqttClient
//import org.eclipse.paho.client.mqttv3.MqttConnectOptions
//import org.eclipse.paho.client.mqttv3.MqttMessage
//import org.eclipse.paho.client.mqttv3.persist.MemoryPersistence
//import org.json.JSONObject
//import java.text.SimpleDateFormat
//import java.util.Date
//import java.util.Locale
//import java.util.UUID
//import java.util.concurrent.Executors
//
//class LocationMonitorService : Service() {
//
//    // ─── Notification IDs & Channels ─────────────────────────────────────────
//    private val CHANNEL_ID              = "location_monitor_channel"
//    private val URGENT_CHANNEL_ID       = "urgent_auto_clockout_channel"
//    private val NOTIFICATION_ID         = 1001
//    private val WORKING_NOTIFICATION_ID = 1002
//
//    // ─── MQTT ─────────────────────────────────────────────────────────────────
//    private val MQTT_HOST             = "119.153.102.7"
//    private val MQTT_PORT             = 1883
//    private val MQTT_PUBLISH_INTERVAL = 60_000L
//    private val MQTT_RECONNECT_DELAY  = 15_000L
//    private val DEFAULT_COMPANY_CODE  = "PK-PUN-SKT-MX01-VT001"
//
//    // ─── SharedPreferences Keys ───────────────────────────────────────────────
//    private val PREFS_NAME              = "FlutterSharedPreferences"
//    private val KEY_IS_CLOCKED_IN       = "flutter.isClockedIn"
//    private val KEY_IS_TIMER_FROZEN     = "flutter.is_timer_frozen"
//    private val KEY_ELAPSED_TIME        = "flutter.elapsed_time"
//    private val KEY_HAS_CRITICAL_EVENT  = "flutter.has_critical_event_pending"
//    private val KEY_EVENT_TIMESTAMP     = "flutter.critical_event_timestamp"
//    private val KEY_EVENT_REASON        = "flutter.critical_event_reason"
//    private val KEY_EVENT_DISTANCE      = "flutter.critical_event_distance"
//    private val KEY_EVENT_LAT           = "flutter.critical_event_latitude"
//    private val KEY_EVENT_LNG           = "flutter.critical_event_longitude"
//    private val KEY_BG_CLOCKOUT_PAYLOAD = "flutter.bg_clockout_payload"
//    private val KEY_FAKE_GPS_DETECTED   = "flutter.fake_gps_detected"
//    private val KEY_LAST_SAVE_WALL_MS   = "flutter.last_location_save_wall_ms"
//    // KEY for wall-clock clock-in time (milliseconds) — written on clock-in
//    private val KEY_CLOCK_IN_WALL_MS    = "flutter.clock_in_wall_ms"
//
//    companion object {
//        const val EXTRA_USER_ID      = "extra_user_id"
//        const val EXTRA_BOOKER_NAME  = "extra_booker_name"
//        const val EXTRA_DESIGNATION  = "extra_designation"
//        const val EXTRA_COMPANY_CODE = "extra_company_code"
//
//        @Volatile var isRunning = false
//            private set
//
//        fun start(
//            context: Context,
//            userId: String      = "",
//            bookerName: String  = "",
//            designation: String = "",
//            companyCode: String = ""
//        ) {
//            val intent = Intent(context, LocationMonitorService::class.java).apply {
//                putExtra(EXTRA_USER_ID,      userId)
//                putExtra(EXTRA_BOOKER_NAME,  bookerName)
//                putExtra(EXTRA_DESIGNATION,  designation)
//                putExtra(EXTRA_COMPANY_CODE, companyCode)
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
//    // ─── State ────────────────────────────────────────────────────────────────
//    private lateinit var handler: Handler
//    private val ioExecutor = Executors.newSingleThreadExecutor { r ->
//        Thread(r, "LocationIOThread").apply { isDaemon = true }
//    }
//
//    @Volatile private var foregroundStarted = false
//    @Volatile private var isDestroyed       = false
//    @Volatile private var isMqttConnected   = false
//    // TIMER FIX: guard so timer starts only once per service instance
//    @Volatile private var timerStarted      = false
//
//    private var userId      = ""
//    private var bookerName  = ""
//    private var designation = ""
//    private var companyCode = ""
//
//    @Volatile private var lastLat      = 0.0
//    @Volatile private var lastLon      = 0.0
//    @Volatile private var lastAccuracy = 0f
//    @Volatile private var lastSpeed    = 0f
//    @Volatile private var lastRealLat  = 0.0
//    @Volatile private var lastRealLon  = 0.0
//
//    private var fusedClient:   FusedLocationProviderClient? = null
//    private var fusedCallback: LocationCallback?            = null
//
//    @Volatile private var gpsPolicy: GpsPolicy = GpsPolicy(60L, "high")
//
//    // TIMER FIX: no more workingSeconds — use wall clock instead
//    private var clockInWallMs          = 0L
//    private var workingTimerRunnable:  Runnable? = null
//
//    // ── Persistent WakeLock — keeps CPU alive while service is running ─────────
//    // Acquired in onStartCommand (after startForeground), released in onDestroy.
//    // PARTIAL_WAKE_LOCK: screen can turn off but CPU stays on → GPS + DB writes work.
//    private var persistentWakeLock: PowerManager.WakeLock? = null
//
//    private var mqttClient:            MqttClient? = null
//    private var mqttPublishRunnable:   Runnable?   = null
//    private var mqttReconnectRunnable: Runnable?   = null
//    private var mqttPublishCount = 0
//
//    private var wasLocationEnabled   = true
//    private var wasPermissionGranted = true
//    private var lastEventTime: Long  = 0
//    private var lastEventReason      = ""
//
//    private val PREF_SAVE_ANCHOR_WALL  = "flutter.location_save_anchor_wall_ms"
//    private var saveAnchorMs           = 0L
//    private var locationSaveRunnable:  Runnable? = null
//    private var policyRefreshRunnable: Runnable? = null
//    private var checkRunnable:         Runnable? = null
//
//    private var connectivityManager: ConnectivityManager? = null
//    private var networkCallback:     ConnectivityManager.NetworkCallback? = null
//
//    private val nativeDb: NativeDBHelper by lazy { NativeDBHelper(applicationContext) }
//
//    private val FAKE_GPS_COOLDOWN_MS     = 30_000L
//    @Volatile private var lastFakeGpsEventTime = 0L
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // Lifecycle
//    // ═════════════════════════════════════════════════════════════════════════
//
//    override fun onCreate() {
//        super.onCreate()
//        isRunning = true
//        handler   = Handler(Looper.getMainLooper())
//        registerReceivers()
//        registerNetworkCallback()
//        log("✅ [Service] onCreate")
//    }
//
//    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
//        createNotificationChannels()
//
//        // startForeground() ONCE — must happen within 5s of startForegroundService()
//        if (!foregroundStarted) {
//            foregroundStarted = true
//            try {
//                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
//                    startForeground(NOTIFICATION_ID, buildServiceNotification("⏳ Starting…"),
//                        ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
//                } else {
//                    startForeground(NOTIFICATION_ID, buildServiceNotification("⏳ Starting…"))
//                }
//            } catch (e: Exception) {
//                log("❌ [Service] startForeground failed: ${e.message}")
//                isRunning = false
//                stopSelf()
//                return START_NOT_STICKY
//            }
//            // ── Acquire persistent WakeLock right after startForeground ────────
//            // Must happen here (not in onCreate) so it's re-acquired on each
//            // START_STICKY restart, keeping the CPU awake for GPS + DB writes.
//            acquirePersistentWakeLock()
//        }
//
//        // Resolve identity
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        val intentUserId = intent?.getStringExtra(EXTRA_USER_ID)?.takeIf { it.isNotEmpty() }
//        if (intentUserId != null) {
//            userId      = intentUserId
//            bookerName  = intent.getStringExtra(EXTRA_BOOKER_NAME)  ?: ""
//            designation = intent.getStringExtra(EXTRA_DESIGNATION)   ?: ""
//            companyCode = intent.getStringExtra(EXTRA_COMPANY_CODE)
//                ?.takeIf { it.isNotEmpty() } ?: DEFAULT_COMPANY_CODE
//            prefs.edit()
//                .putString("flutter.userId",          userId)
//                .putString("flutter.userName",        bookerName)
//                .putString("flutter.userDesignation", designation)
//                .putString("flutter.companyCode",     companyCode)
//                .commit()
//        } else {
//            userId      = prefs.getString("flutter.userId",          "") ?: ""
//            bookerName  = prefs.getString("flutter.userName",        "") ?: ""
//            designation = prefs.getString("flutter.userDesignation", "") ?: ""
//            companyCode = (prefs.getString("flutter.companyCode",    "") ?: "")
//                .ifEmpty { DEFAULT_COMPANY_CODE }
//        }
//
//        if (userId.isEmpty()) {
//            log("❌ [Service] userId empty — stopSelf")
//            stopSelf()
//            return START_NOT_STICKY
//        }
//
//        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//        val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//
//        wasPermissionGranted = checkLocationPermission()
//        wasLocationEnabled   = isLocationEnabled()
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
//        // ── TIMER FIX: resolve clockInWallMs from prefs ───────────────────────
//        // Priority 1: flutter.clock_in_wall_ms (most accurate, set below)
//        // Priority 2: flutter.clockInTime ISO string (set by Flutter on clock-in)
//        // Priority 3: now (fallback — timer starts from 0)
//        //
//        // CRITICAL: Always try to write clock_in_wall_ms from clockInTime if not
//        // already present. This ensures the timer survives service kill/restart
//        // even if Flutter never explicitly wrote clock_in_wall_ms.
//        if (clockedIn && !isFrozen) {
//            val savedWallMs = prefs.getLong(KEY_CLOCK_IN_WALL_MS, 0L)
//            if (savedWallMs > 0L) {
//                clockInWallMs = savedWallMs
//                log("⏱️ [Timer] Restored wall-ms: $clockInWallMs → ${(System.currentTimeMillis() - clockInWallMs) / 1000}s elapsed")
//            } else {
//                // Try parsing ISO clockInTime from Flutter
//                val clockInStr = prefs.getString("flutter.clockInTime", "") ?: ""
//                val parsed = tryParseClockInTime(clockInStr)
//                clockInWallMs = if (parsed > 0L) {
//                    // Save it as wall-ms so we don't parse again on next restart
//                    prefs.edit().putLong(KEY_CLOCK_IN_WALL_MS, parsed).commit()
//                    log("⏱️ [Timer] Parsed clockInTime: $clockInStr → ${(System.currentTimeMillis() - parsed) / 1000}s elapsed")
//                    parsed
//                } else {
//                    // Fallback: check if elapsed_time string gives us a clue
//                    // e.g. "01:23:45" → subtract that from now to reconstruct clockInTime
//                    val elapsedStr = prefs.getString(KEY_ELAPSED_TIME, "") ?: ""
//                    val elapsedSec = parseElapsedToSeconds(elapsedStr)
//                    if (elapsedSec > 0L) {
//                        val reconstructed = System.currentTimeMillis() - (elapsedSec * 1000L)
//                        prefs.edit().putLong(KEY_CLOCK_IN_WALL_MS, reconstructed).commit()
//                        log("⏱️ [Timer] Reconstructed from elapsed_time '$elapsedStr' → ${elapsedSec}s ago")
//                        reconstructed
//                    } else {
//                        // True fallback — treat as clocked in just now
//                        val now = System.currentTimeMillis()
//                        prefs.edit().putLong(KEY_CLOCK_IN_WALL_MS, now).commit()
//                        log("⚠️ [Timer] Could not parse clockInTime — starting from 0")
//                        now
//                    }
//                }
//            }
//        }
//
//        startAllLoops(prefs, resetAnchor = (intent?.action == "ACTION_CLOCK_IN"))
//
//        return START_STICKY
//    }
//
//    // Parse ISO string "yyyy-MM-dd'T'HH:mm:ss" or "yyyy-MM-dd HH:mm:ss" → epoch ms
//    private fun tryParseClockInTime(str: String): Long {
//        if (str.isEmpty()) return 0L
//        val formats = listOf(
//            "yyyy-MM-dd'T'HH:mm:ss",
//            "yyyy-MM-dd HH:mm:ss",
//            "yyyy-MM-dd'T'HH:mm:ss.SSS"
//        )
//        for (fmt in formats) {
//            try {
//                val d = SimpleDateFormat(fmt, Locale.getDefault()).parse(str)
//                if (d != null) return d.time
//            } catch (_: Exception) {}
//        }
//        return 0L
//    }
//
//    // Parse "HH:mm:ss" elapsed string → total seconds
//    // Used to reconstruct clockInWallMs when clock_in_wall_ms pref is missing
//    private fun parseElapsedToSeconds(str: String): Long {
//        if (str.isEmpty()) return 0L
//        return try {
//            val parts = str.split(":")
//            if (parts.size == 3) {
//                val h = parts[0].toLong()
//                val m = parts[1].toLong()
//                val s = parts[2].toLong()
//                h * 3600L + m * 60L + s
//            } else 0L
//        } catch (_: Exception) { 0L }
//    }
//
//    override fun onTaskRemoved(rootIntent: Intent?) {
//        super.onTaskRemoved(rootIntent)
//        log("🔄 [Service] App removed from recents — scheduling AlarmManager watchdog")
//
//        // START_STICKY alone is often killed by aggressive OEMs (Vivo, Xiaomi, OPPO).
//        // Belt-and-suspenders: also schedule a 5-second AlarmManager wakeup that
//        // fires ServiceRestartReceiver → it checks isClockedIn and restarts service.
//        try {
//            val prefs     = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//            val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//            val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//            if (!clockedIn || isFrozen) return
//
//            val am = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
//            val intent = android.content.Intent(this, ServiceRestartReceiver::class.java).apply {
//                action = ServiceRestartReceiver.ACTION_RESTART_SERVICE
//            }
//            val pi = android.app.PendingIntent.getBroadcast(
//                this, 9001, intent,
//                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
//            )
//            val triggerAt = System.currentTimeMillis() + 5_000L
//            when {
//                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
//                    am.setAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, triggerAt, pi)
//                else -> am.set(android.app.AlarmManager.RTC_WAKEUP, triggerAt, pi)
//            }
//            log("✅ [Service] Watchdog alarm set for +5s")
//        } catch (e: Exception) {
//            log("⚠️ [Service] Watchdog alarm failed: ${e.message}")
//        }
//    }
//
//    override fun onDestroy() {
//        isDestroyed   = true
//        isRunning     = false
//        timerStarted  = false
//
//        val prefs     = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//        val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//
//        if (clockedIn && !isFrozen) {
//            val permRevoked = !checkLocationPermission()
//            val locOff      = !isLocationEnabled()
//            if (permRevoked || locOff) {
//                val reason = if (permRevoked) "System ClockOut - Permission Revoked"
//                else             "System ClockOut - Location Off"
//                saveCriticalEventToPrefs(prefs, reason)
//                MidnightClockoutReceiver.cancel(this)
//            }
//        }
//
//        stopAllLoops()
//        disconnectMqtt()
//        unregisterNetworkCallback()
//        try { unregisterReceiver(locationModeReceiver)   } catch (_: Exception) {}
//        try { unregisterReceiver(screenReceiver)         } catch (_: Exception) {}
//        try { unregisterReceiver(dateTimeChangeReceiver) } catch (_: Exception) {}
//        ioExecutor.shutdown()
//
//        // ── ROOT FIX: Remove BOTH notifications + release WakeLock ───────────
//        // Without stopForeground(), notification 1001 stays stuck in status bar
//        // even after stopService() — this is the "stuck notification" bug.
//        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
//        try { (getSystemService(NotificationManager::class.java)).cancel(NOTIFICATION_ID) } catch (_: Exception) {}
//        try { (getSystemService(NotificationManager::class.java)).cancel(WORKING_NOTIFICATION_ID) } catch (_: Exception) {}
//        releasePersistentWakeLock()
//
//        super.onDestroy()
//        log("🛑 [Service] onDestroy")
//    }
//
//    override fun onBind(intent: Intent?): IBinder? = null
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // Start / Stop all loops
//    // ═════════════════════════════════════════════════════════════════════════
//
//    private fun startAllLoops(
//        prefs: android.content.SharedPreferences,
//        resetAnchor: Boolean
//    ) {
//        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//        val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//
//        // GPS policy fetch (async) → then start GPS + save loop
//        ioExecutor.submit {
//            gpsPolicy = GpsPolicyManager.fetchPolicy(this, forceRefresh = true)
//            log("📋 [Policy] interval=${gpsPolicy.locationIntervalSec}s accuracy=${gpsPolicy.gpsAccuracy}")
//            handler.post { restartGpsAndSaveLoop(resetAnchor) }
//        }
//
//        if (clockedIn && !isFrozen) {
//            // TIMER FIX: only start timer once per service instance
//            if (!timerStarted) {
//                timerStarted = true
//                startWorkingTimer()
//            }
//            MidnightClockoutReceiver.schedule(this)
//            LocationUploadWorker.schedule(this)
//        }
//
//        startMqttPublishing()
//        startPermissionCheckLoop()
//        startPolicyRefreshLoop()
//    }
//
//    private fun stopAllLoops() {
//        checkRunnable?.let        { handler.removeCallbacks(it) }
//        workingTimerRunnable?.let { handler.removeCallbacks(it) }
//        policyRefreshRunnable?.let{ handler.removeCallbacks(it) }
//        locationSaveRunnable?.let { handler.removeCallbacks(it) }
//        mqttPublishRunnable?.let  { handler.removeCallbacks(it) }
//        mqttReconnectRunnable?.let{ handler.removeCallbacks(it) }
//        handler.removeCallbacksAndMessages(null)
//        stopLocationUpdates()
//        try { (getSystemService(NotificationManager::class.java)).cancel(WORKING_NOTIFICATION_ID) } catch (_: Exception) {}
//    }
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // Working Timer — WALL CLOCK BASED (the real fix)
//    //
//    // Instead of workingSeconds++, we calculate:
//    //   elapsed = (System.currentTimeMillis() - clockInWallMs) / 1000
//    //
//    // This means:
//    //   - Phone sleep/wake → timer picks up exactly where it left off
//    //   - Service restart  → timer picks up exactly where it left off
//    //   - App kill/resume  → timer picks up exactly where it left off
//    //   - No drift, no stuck, no reset
//    // ═════════════════════════════════════════════════════════════════════════
//
//    private fun startWorkingTimer() {
//        workingTimerRunnable?.let { handler.removeCallbacks(it) }
//
//        workingTimerRunnable = object : Runnable {
//            override fun run() {
//                if (isDestroyed) return
//
//                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//                // Stop ticking if clocked out or frozen
//                if (!prefs.getBoolean(KEY_IS_CLOCKED_IN, false) ||
//                    prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) {
//                    return
//                }
//
//                // WALL CLOCK: always calculate from actual clock-in time
//                val ref = if (clockInWallMs > 0L) clockInWallMs
//                else prefs.getLong(KEY_CLOCK_IN_WALL_MS, System.currentTimeMillis())
//
//                val totalSec = ((System.currentTimeMillis() - ref) / 1000L).coerceAtLeast(0L)
//                val h = totalSec / 3600
//                val m = (totalSec % 3600) / 60
//                val s = totalSec % 60
//                val timeStr = "%02d:%02d:%02d".format(h, m, s)
//
//                updateWorkingTimerNotification(timeStr)
//
//                // Persist for Flutter to read
//                try {
//                    prefs.edit().putString(KEY_ELAPSED_TIME, timeStr).apply()
//                } catch (_: Exception) {}
//
//                // Schedule next tick aligned to next second boundary
//                // This keeps the timer from drifting over time
//                val nowMs     = System.currentTimeMillis()
//                val elapsedMs = nowMs - ref
//                val nextTick  = 1000L - (elapsedMs % 1000L)
//                val delay     = if (nextTick < 50L) nextTick + 1000L else nextTick
//
//                if (!isDestroyed) handler.postDelayed(this, delay)
//            }
//        }
//        handler.post(workingTimerRunnable!!)   // start immediately
//        log("✅ [Timer] Wall-clock timer started — clockInWallMs=$clockInWallMs")
//    }
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // GPS Policy
//    // ═════════════════════════════════════════════════════════════════════════
//
//    private fun startPolicyRefreshLoop() {
//        policyRefreshRunnable = object : Runnable {
//            override fun run() {
//                if (isDestroyed) return
//                ioExecutor.submit {
//                    val newPolicy = GpsPolicyManager.fetchPolicy(this@LocationMonitorService, forceRefresh = true)
//                    val changed   = newPolicy.locationIntervalSec != gpsPolicy.locationIntervalSec ||
//                            newPolicy.gpsAccuracy        != gpsPolicy.gpsAccuracy
//                    gpsPolicy = newPolicy
//                    if (changed) {
//                        log("📋 [Policy] Changed → restarting GPS loop")
//                        handler.post { restartGpsAndSaveLoop(resetAnchor = true) }
//                    }
//                }
//                if (!isDestroyed) handler.postDelayed(this, 5 * 60_000L)
//            }
//        }
//        handler.postDelayed(policyRefreshRunnable!!, 5 * 60_000L)
//    }
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // FusedLocation GPS updates
//    // ═════════════════════════════════════════════════════════════════════════
//
//    private fun startLocationUpdates() {
//        if (!checkLocationPermission()) return
//        if (fusedCallback != null) return
//
//        try {
//            fusedClient  = LocationServices.getFusedLocationProviderClient(this)
//            val intervalMs = gpsPolicy.locationIntervalSec * 1000L
//            val priority = when (gpsPolicy.gpsAccuracy) {
//                "best", "high" -> Priority.PRIORITY_HIGH_ACCURACY
//                "medium"       -> Priority.PRIORITY_BALANCED_POWER_ACCURACY
//                else           -> Priority.PRIORITY_LOW_POWER
//            }
//            val request = LocationRequest.Builder(intervalMs)
//                .setMinUpdateIntervalMillis(intervalMs)
//                .setMaxUpdateDelayMillis(intervalMs + 5_000L)
//                .setPriority(priority)
//                .build()
//
//            fusedCallback = object : LocationCallback() {
//                override fun onLocationResult(result: LocationResult) {
//                    val loc = result.lastLocation ?: return
//                    if (loc.isFromMockProvider) {
//                        log("🚨 [GPS] Mock location detected")
//                        handleFakeGpsDetected(loc.latitude, loc.longitude)
//                        return
//                    }
//                    lastRealLat = loc.latitude
//                    lastRealLon = loc.longitude
//                    val maxAccuracy = when (gpsPolicy.gpsAccuracy) {
//                        "best"   -> 20f;  "high"   -> 50f
//                        "medium" -> 100f; "low"    -> 200f
//                        "lowest" -> 500f; else     -> 100f
//                    }
//                    if (loc.accuracy > maxAccuracy) {
//                        log("⚠️ [GPS] Skipped low-accuracy: ${loc.accuracy}m")
//                        return
//                    }
//                    lastLat      = loc.latitude
//                    lastLon      = loc.longitude
//                    lastAccuracy = loc.accuracy
//                    lastSpeed    = loc.speed
//                }
//            }
//            fusedClient?.requestLocationUpdates(request, fusedCallback!!, Looper.getMainLooper())
//            log("✅ [GPS] FusedLocation started — interval=${gpsPolicy.locationIntervalSec}s")
//        } catch (e: Exception) {
//            log("❌ [GPS] startLocationUpdates failed: ${e.message}")
//        }
//    }
//
//    private fun stopLocationUpdates() {
//        try { fusedCallback?.let { fusedClient?.removeLocationUpdates(it) } } catch (_: Exception) {}
//        fusedCallback = null
//        fusedClient   = null
//    }
//
//    private fun restartGpsAndSaveLoop(resetAnchor: Boolean) {
//        if (isDestroyed) return
//        stopLocationUpdates()
//        startLocationUpdates()
//        scheduleLocationSave(resetAnchor)
//    }
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // Location Save — Anchor-Based Precise Scheduling
//    // ═════════════════════════════════════════════════════════════════════════
//
//    private fun scheduleLocationSave(resetAnchor: Boolean = false) {
//        locationSaveRunnable?.let { handler.removeCallbacks(it) }
//        locationSaveRunnable = null
//
//        val prefs      = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        val nowWall    = System.currentTimeMillis()
//        val intervalMs = gpsPolicy.locationIntervalSec * 1000L
//
//        if (resetAnchor) {
//            saveAnchorMs = nowWall
//            prefs.edit().putLong(PREF_SAVE_ANCHOR_WALL, saveAnchorMs).apply()
//            log("⚓ [SaveLoop] Anchor RESET at $saveAnchorMs")
//        } else {
//            val stored = prefs.getLong(PREF_SAVE_ANCHOR_WALL, 0L)
//            saveAnchorMs = if (stored > 0L && stored <= nowWall) stored else {
//                nowWall.also { prefs.edit().putLong(PREF_SAVE_ANCHOR_WALL, it).apply() }
//            }
//        }
//        scheduleNextSaveTick()
//    }
//
//    private fun scheduleNextSaveTick() {
//        if (isDestroyed) return
//
//        val intervalMs = gpsPolicy.locationIntervalSec * 1000L
//        val nowWall    = System.currentTimeMillis()
//        val elapsed    = nowWall - saveAnchorMs
//        val ticksDone  = elapsed / intervalMs
//        val nextWall   = saveAnchorMs + (ticksDone + 1) * intervalMs
//        var delayMs    = nextWall - nowWall
//        if (delayMs <= 0L) delayMs = intervalMs
//
//        log("⏱️ [SaveLoop] Next save in ${delayMs / 1000}s (interval=${intervalMs / 1000}s)")
//
//        locationSaveRunnable = Runnable {
//            if (isDestroyed) return@Runnable
//            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//            if (prefs.getBoolean(KEY_IS_CLOCKED_IN, false) &&
//                !prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) {
//                ioExecutor.submit { saveLocationToDB(prefs) }
//            }
//            scheduleNextSaveTick()
//        }
//        handler.postDelayed(locationSaveRunnable!!, delayMs)
//    }
//
//    private fun saveLocationToDB(prefs: android.content.SharedPreferences) {
//        val lat = lastLat
//        val lon = lastLon
//        if (lat == 0.0 && lon == 0.0) {
//            log("⚠️ [SaveLoop] No GPS fix yet — skipping")
//            return
//        }
//        val wl = acquireShortWakeLock("BookIT::DbWriteLock", 15_000L)
//        try {
//            val now  = Date()
//            val sdf  = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
//            val stf  = SimpleDateFormat("HH:mm:ss",   Locale.getDefault())
//            val ddf  = SimpleDateFormat("dd",          Locale.getDefault())
//            val mdf  = SimpleDateFormat("MMM",         Locale.getDefault())
//            val rowId = "LT-$userId-${ddf.format(now)}-${mdf.format(now)}" +
//                    "-${UUID.randomUUID().toString().takeLast(6).uppercase()}"
//            val code = companyCode.ifEmpty { DEFAULT_COMPANY_CODE }
//            nativeDb.insertLocationRow(
//                id          = rowId,
//                date        = sdf.format(now),
//                time        = stf.format(now),
//                userId      = userId,
//                lat         = lat.toString(),
//                lng         = lon.toString(),
//                bookerName  = bookerName,
//                designation = designation,
//                companyCode = code
//            )
//            prefs.edit().putLong(KEY_LAST_SAVE_WALL_MS, System.currentTimeMillis()).apply()
//            log("💾 [SaveLoop] Saved: $rowId lat=$lat lng=$lon")
//        } catch (e: Exception) {
//            log("❌ [SaveLoop] DB save failed: ${e.message}")
//        } finally {
//            releaseWakeLock(wl)
//        }
//    }
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // MQTT
//    // ═════════════════════════════════════════════════════════════════════════
//
//    private fun startMqttPublishing() {
//        connectMqtt()
//        mqttPublishRunnable?.let { handler.removeCallbacks(it) }
//        mqttPublishRunnable = object : Runnable {
//            override fun run() {
//                if (isDestroyed) return
//                publishLocationToMqtt()
//                handler.postDelayed(this, MQTT_PUBLISH_INTERVAL)
//            }
//        }
//        handler.postDelayed(mqttPublishRunnable!!, MQTT_PUBLISH_INTERVAL)
//    }
//
//    private fun connectMqtt() {
//        ioExecutor.submit {
//            try {
//                if (isMqttConnected) return@submit
//                val clientId = "android-$userId-${UUID.randomUUID().toString().take(8)}"
//                val client   = MqttClient("tcp://$MQTT_HOST:$MQTT_PORT", clientId, MemoryPersistence())
//                client.setCallback(object : MqttCallback {
//                    override fun connectionLost(cause: Throwable?) {
//                        isMqttConnected = false
//                        handler.post { scheduleReconnect() }
//                    }
//                    override fun messageArrived(t: String?, m: MqttMessage?) {}
//                    override fun deliveryComplete(t: IMqttDeliveryToken?) {}
//                })
//                val opts = MqttConnectOptions().apply {
//                    isCleanSession       = true
//                    connectionTimeout    = 10
//                    keepAliveInterval    = 30
//                    isAutomaticReconnect = false
//                }
//                client.connect(opts)
//                mqttClient      = client
//                isMqttConnected = true
//                handler.post { updateServiceNotification("✅ Live tracking active") }
//                log("✅ [MQTT] Connected")
//            } catch (e: Exception) {
//                isMqttConnected = false
//                handler.post { scheduleReconnect() }
//                log("❌ [MQTT] Connect failed: ${e.message}")
//            }
//        }
//    }
//
//    private fun disconnectMqtt() {
//        mqttReconnectRunnable?.let { handler.removeCallbacks(it) }
//        mqttReconnectRunnable = null
//        ioExecutor.submit {
//            try { if (mqttClient?.isConnected == true) mqttClient?.disconnect(0) } catch (_: Exception) {}
//            mqttClient = null; isMqttConnected = false
//        }
//    }
//
//    private fun scheduleReconnect() {
//        if (isDestroyed) return
//        mqttReconnectRunnable?.let { handler.removeCallbacks(it) }
//        mqttReconnectRunnable = Runnable { if (!isDestroyed && !isMqttConnected) connectMqtt() }
//        handler.postDelayed(mqttReconnectRunnable!!, MQTT_RECONNECT_DELAY)
//    }
//
//    private fun publishLocationToMqtt() {
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        if (!prefs.getBoolean(KEY_IS_CLOCKED_IN, false)) return
//        if (prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) return
//        if (lastLat == 0.0 && lastLon == 0.0) return
//        val payload = JSONObject().apply {
//            put("device_id",    userId)
//            put("company_code", companyCode.ifEmpty { DEFAULT_COMPANY_CODE })
//            put("emp_name",     bookerName)
//            put("dept_id",      designation)
//            put("lat",          lastLat)
//            put("lon",          lastLon)
//            put("accuracy",     lastAccuracy)
//            put("speed",        lastSpeed)
//            put("track_id",     System.currentTimeMillis())
//            put("timestamp",    SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date()))
//            put("source",       "android_foreground_service")
//        }.toString()
//        ioExecutor.submit {
//            try {
//                val client = mqttClient ?: return@submit
//                if (!client.isConnected) { handler.post { scheduleReconnect() }; return@submit }
//                val msg = MqttMessage(payload.toByteArray(Charsets.UTF_8)).apply {
//                    qos = 1; isRetained = false
//                }
//                client.publish("gps/${companyCode.ifEmpty { DEFAULT_COMPANY_CODE }}/$userId", msg)
//                mqttPublishCount++
//                handler.post { updateServiceNotification("✅ Live tracking • #$mqttPublishCount") }
//            } catch (e: Exception) {
//                isMqttConnected = false
//                handler.post { scheduleReconnect() }
//            }
//        }
//    }
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // Permission / Location Check Loop
//    // ═════════════════════════════════════════════════════════════════════════
//
//    private fun startPermissionCheckLoop() {
//        checkRunnable = object : Runnable {
//            override fun run() {
//                if (isDestroyed) return
//                checkPermissionsAndLocation()
//                handler.postDelayed(this, 30_000L)
//            }
//        }
//        handler.postDelayed(checkRunnable!!, 30_000L)
//    }
//
//    private fun checkPermissionsAndLocation() {
//        val prefs     = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//        val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//        if (!clockedIn || isFrozen) return
//
//        val permOk = checkLocationPermission()
//        val locOn  = isLocationEnabled()
//
//        if (wasPermissionGranted && !permOk) {
//            val now = System.currentTimeMillis()
//            if (now - lastEventTime > 5_000L) {
//                lastEventTime   = now
//                lastEventReason = "System ClockOut - Permission Revoked"
//                handleCriticalEvent("System ClockOut - Permission Revoked")
//                return
//            }
//        }
//        if (wasLocationEnabled && !locOn) {
//            val now = System.currentTimeMillis()
//            if (now - lastEventTime > 5_000L) {
//                lastEventTime   = now
//                lastEventReason = "System ClockOut - Location Off"
//                handleCriticalEvent("System ClockOut - Location Off")
//                return
//            }
//        }
//        wasPermissionGranted = permOk
//        wasLocationEnabled   = locOn
//    }
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // Critical Events
//    // ═════════════════════════════════════════════════════════════════════════
//
//    private fun handleCriticalEvent(reason: String) = handleCriticalEventWithTime(reason, Date())
//
//    private fun handleCriticalEventWithTime(reason: String, eventTime: Date) {
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        if (prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) return
//        saveCriticalEventToPrefs(prefs, reason, eventTime)
//        showCriticalNotification(reason,
//            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(eventTime))
//        MidnightClockoutReceiver.cancel(this)
//        LocationUploadWorker.cancel(this)
//        stopAllLoops()
//        disconnectMqtt()
//        try { (getSystemService(NotificationManager::class.java)).cancel(WORKING_NOTIFICATION_ID) } catch (_: Exception) {}
//        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
//        stopSelf()
//    }
//
//    fun handleFakeGpsDetected(fakeLat: Double, fakeLng: Double) {
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        if (!prefs.getBoolean(KEY_IS_CLOCKED_IN, false) ||
//            prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) return
//        val now = System.currentTimeMillis()
//        if (now - lastFakeGpsEventTime < FAKE_GPS_COOLDOWN_MS) return
//        lastFakeGpsEventTime = now
//        handler.post {
//            val prefs2   = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//            val ts       = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date())
//            val elapsed  = prefs2.getString(KEY_ELAPSED_TIME, "00:00:00") ?: "00:00:00"
//            val clockInT = prefs2.getString("flutter.clockInTime", "") ?: ""
//            prefs2.edit()
//                .putBoolean(KEY_HAS_CRITICAL_EVENT, true)
//                .putBoolean("has_critical_event_pending", true)
//                .putBoolean(KEY_IS_TIMER_FROZEN, true)
//                .putString(KEY_EVENT_TIMESTAMP,  ts)
//                .putString(KEY_EVENT_REASON,     "System ClockOut - Fake GPS Detected")
//                .putString("critical_event_reason", "System ClockOut - Fake GPS Detected")
//                .putBoolean(KEY_IS_CLOCKED_IN, false)
//                .putBoolean("isClockedIn", false)
//                .putBoolean(KEY_FAKE_GPS_DETECTED, true)
//                .putFloat("flutter.fake_gps_lat", fakeLat.toFloat())
//                .putFloat("flutter.fake_gps_lon", fakeLng.toFloat())
//                .putFloat("flutter.real_gps_lat", lastRealLat.toFloat())
//                .putFloat("flutter.real_gps_lon", lastRealLon.toFloat())
//                .putString("flutter.fastClockOutTime", ts)
//                .putFloat("flutter.fastClockOutDistance", 0f)
//                .putString("flutter.fastClockOutReason", "System ClockOut - Fake GPS Detected")
//                .putBoolean("flutter.hasFastClockOutData", true)
//                .putBoolean("flutter.clockOutPending", true)
//                .putString("flutter.fastClockOutData",
//                    """{"fast_attendanceId":"","fast_userId":"$userId","fast_clockOutTime":"$ts","fast_totalTime":"$elapsed","fast_totalDistance":0.0,"fast_latOut":${lastRealLat},"fast_lngOut":${lastRealLon},"fast_address":"","fast_reason":"System ClockOut - Fake GPS Detected","fast_savedAt":"${System.currentTimeMillis()}","fast_clockInTime":"$clockInT"}""")
//                .commit()
//            showCriticalNotification("System ClockOut - Fake GPS Detected", ts)
//            MidnightClockoutReceiver.cancel(this)
//            LocationUploadWorker.cancel(this)
//            stopAllLoops()
//            disconnectMqtt()
//            try { (getSystemService(NotificationManager::class.java)).cancel(WORKING_NOTIFICATION_ID) } catch (_: Exception) {}
//            try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
//            stopSelf()
//        }
//    }
//
//    private fun saveCriticalEventToPrefs(
//        prefs: android.content.SharedPreferences,
//        reason: String,
//        eventTime: Date = Date()
//    ) {
//        val ts       = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(eventTime)
//        val elapsed  = prefs.getString(KEY_ELAPSED_TIME, "00:00:00") ?: "00:00:00"
//        val clockInT = prefs.getString("flutter.clockInTime", "") ?: ""
//        prefs.edit()
//            .putBoolean(KEY_HAS_CRITICAL_EVENT, true)
//            .putBoolean("has_critical_event_pending", true)
//            .putBoolean(KEY_IS_TIMER_FROZEN, true)
//            .putString(KEY_EVENT_TIMESTAMP, ts)
//            .putString(KEY_EVENT_REASON, reason)
//            .putString("critical_event_reason", reason)
//            .putFloat(KEY_EVENT_DISTANCE, 0f)
//            .putFloat(KEY_EVENT_LAT, 0f)
//            .putFloat(KEY_EVENT_LNG, 0f)
//            .putBoolean(KEY_IS_CLOCKED_IN, false)
//            .putBoolean("isClockedIn", false)
//            .putBoolean("flutter.pending_gpx_close", true)
//            .putString("flutter.fastClockOutTime", ts)
//            .putFloat("flutter.fastClockOutDistance", 0f)
//            .putString("flutter.fastClockOutReason", reason)
//            .putBoolean("flutter.hasFastClockOutData", true)
//            .putBoolean("flutter.clockOutPending", true)
//            .putString("flutter.fastClockOutData",
//                """{"fast_attendanceId":"","fast_userId":"$userId","fast_clockOutTime":"$ts","fast_totalTime":"$elapsed","fast_totalDistance":0.0,"fast_latOut":0.0,"fast_lngOut":0.0,"fast_address":"","fast_reason":"$reason","fast_savedAt":"${System.currentTimeMillis()}","fast_clockInTime":"$clockInT"}""")
//            .putString(KEY_BG_CLOCKOUT_PAYLOAD,
//                """{"timestamp":"$ts","reason":"$reason","elapsed_at_event":"$elapsed","distance":0.0,"latitude":0.0,"longitude":0.0}""")
//            .commit()
//        log("💾 [Critical] Saved: reason=$reason ts=$ts")
//    }
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // Broadcast Receivers
//    // ═════════════════════════════════════════════════════════════════════════
//
//    private val locationModeReceiver = object : BroadcastReceiver() {
//        override fun onReceive(context: Context?, intent: Intent?) {
//            if (intent?.action == SysLocationManager.MODE_CHANGED_ACTION)
//                handler.post { checkPermissionsAndLocation() }
//        }
//    }
//
//    private val screenReceiver = object : BroadcastReceiver() {
//        override fun onReceive(context: Context?, intent: Intent?) {
//            handler.post { checkPermissionsAndLocation() }
//        }
//    }
//
//    private val dateTimeChangeReceiver = object : BroadcastReceiver() {
//        override fun onReceive(context: Context?, intent: Intent?) {}
//    }
//
//    private fun registerReceivers() {
//        registerReceiver(locationModeReceiver, IntentFilter(SysLocationManager.MODE_CHANGED_ACTION))
//        registerReceiver(screenReceiver, IntentFilter(Intent.ACTION_SCREEN_ON))
//        val tf = IntentFilter().apply {
//            addAction(Intent.ACTION_TIME_CHANGED)
//            addAction(Intent.ACTION_DATE_CHANGED)
//            addAction(Intent.ACTION_TIMEZONE_CHANGED)
//        }
//        registerReceiver(dateTimeChangeReceiver, tf)
//    }
//
//    private fun registerNetworkCallback() {
//        try {
//            connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
//            val req = NetworkRequest.Builder()
//                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET).build()
//            networkCallback = object : ConnectivityManager.NetworkCallback() {
//                override fun onAvailable(network: Network) {
//                    handler.post {
//                        if (!isDestroyed && !isMqttConnected) connectMqtt()
//                        ioExecutor.submit {
//                            gpsPolicy = GpsPolicyManager.fetchPolicy(
//                                this@LocationMonitorService, forceRefresh = true)
//                        }
//                    }
//                }
//                override fun onLost(network: Network) {
//                    isMqttConnected = false
//                    handler.post { updateServiceNotification("❌ MQTT offline — no internet") }
//                }
//            }
//            connectivityManager?.registerNetworkCallback(req, networkCallback!!)
//        } catch (e: Exception) { log("⚠️ [Network] Callback reg failed: ${e.message}") }
//    }
//
//    private fun unregisterNetworkCallback() {
//        try { networkCallback?.let { connectivityManager?.unregisterNetworkCallback(it) } } catch (_: Exception) {}
//        networkCallback = null
//    }
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // WakeLock helpers
//    // ═════════════════════════════════════════════════════════════════════════
//
//    // ── Persistent WakeLock (held for entire service lifetime) ────────────────
//    // PARTIAL_WAKE_LOCK: screen OFF is fine, CPU stays ON.
//    // This prevents the OS from putting the CPU to sleep while GPS is running.
//    // Must be held continuously — releasing it even briefly can drop GPS fixes.
//    private fun acquirePersistentWakeLock() {
//        try {
//            if (persistentWakeLock?.isHeld == true) return  // already held
//            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
//            persistentWakeLock = pm.newWakeLock(
//                PowerManager.PARTIAL_WAKE_LOCK,
//                "BookIT::LocationServiceWakeLock"
//            ).also {
//                it.setReferenceCounted(false)
//                it.acquire()  // no timeout — held for entire service lifetime
//            }
//            log("✅ [WakeLock] Persistent lock acquired")
//        } catch (e: Exception) {
//            log("⚠️ [WakeLock] Persistent lock failed: ${e.message}")
//        }
//    }
//
//    private fun releasePersistentWakeLock() {
//        try {
//            if (persistentWakeLock?.isHeld == true) persistentWakeLock?.release()
//            persistentWakeLock = null
//            log("✅ [WakeLock] Persistent lock released")
//        } catch (_: Exception) {}
//    }
//
//    // ── Short WakeLock (timed, for DB writes) ─────────────────────────────────
//    private fun acquireShortWakeLock(tag: String, timeoutMs: Long): PowerManager.WakeLock? {
//        return try {
//            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
//            pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, tag).also { it.acquire(timeoutMs) }
//        } catch (e: Exception) { log("⚠️ [WakeLock] $tag failed: ${e.message}"); null }
//    }
//
//    private fun releaseWakeLock(wl: PowerManager.WakeLock?) {
//        try { if (wl?.isHeld == true) wl.release() } catch (_: Exception) {}
//    }
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // Notifications
//    // ═════════════════════════════════════════════════════════════════════════
//
//    private fun createNotificationChannels() {
//        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
//        val nm = getSystemService(NotificationManager::class.java)
//        nm.createNotificationChannel(
//            NotificationChannel(CHANNEL_ID, "Location Monitor",
//                NotificationManager.IMPORTANCE_LOW).apply {
//                description = "Monitors location for attendance tracking"
//                setShowBadge(false)
//                enableVibration(false)
//                setSound(null, null)
//            }
//        )
//        nm.createNotificationChannel(
//            NotificationChannel(URGENT_CHANNEL_ID, "URGENT Auto Clockout",
//                NotificationManager.IMPORTANCE_HIGH).apply {
//                enableVibration(true)
//                vibrationPattern = longArrayOf(0, 1000, 500, 1000)
//                enableLights(true)
//                lightColor = android.graphics.Color.RED
//            }
//        )
//    }
//
//    private fun buildServiceNotification(text: String): Notification {
//        val pi = PendingIntent.getActivity(this, 0,
//            packageManager.getLaunchIntentForPackage(packageName),
//            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
//        return NotificationCompat.Builder(this, CHANNEL_ID)
//            .setContentTitle("BookIT Attendance Active")
//            .setContentText(text)
//            .setSmallIcon(R.mipmap.ic_launcher)
//            .setContentIntent(pi)
//            .setOngoing(true)
//            .setSilent(true)
//            .setPriority(NotificationCompat.PRIORITY_LOW)
//            .build()
//    }
//
//    private fun updateServiceNotification(text: String) {
//        if (isDestroyed) return
//        val n = buildServiceNotification(text)
//        (getSystemService(NotificationManager::class.java)).notify(NOTIFICATION_ID, n)
//    }
//
//    private fun updateWorkingTimerNotification(timeStr: String) {
//        if (isDestroyed) return
//        val pi = PendingIntent.getActivity(this, 1,
//            packageManager.getLaunchIntentForPackage(packageName),
//            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
//        val n = NotificationCompat.Builder(this, CHANNEL_ID)
//            .setContentTitle("Working Time")
//            .setContentText("⏱ $timeStr")
//            .setSmallIcon(R.mipmap.ic_launcher)
//            .setContentIntent(pi)
//            .setOngoing(true)
//            .setSilent(true)
//            .setPriority(NotificationCompat.PRIORITY_LOW)
//            .build()
//        try {
//            (getSystemService(NotificationManager::class.java)).notify(WORKING_NOTIFICATION_ID, n)
//        } catch (_: Exception) {}
//    }
//
//    private fun showCriticalNotification(reason: String, time: String) {
//        val title = when (reason) {
//            "System ClockOut - Location Off"       -> "⚠️ LOCATION TURNED OFF"
//            "System ClockOut - Permission Revoked" -> "⚠️ PERMISSION REVOKED"
//            "System ClockOut - Fake GPS Detected"  -> "🚨 FAKE GPS DETECTED"
//            else                                   -> "⚠️ AUTO CLOCKOUT"
//        }
//        val pi = PendingIntent.getActivity(this, 0,
//            packageManager.getLaunchIntentForPackage(packageName)?.apply {
//                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
//            }, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
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
//
//    // ═════════════════════════════════════════════════════════════════════════
//    // Helpers
//    // ═════════════════════════════════════════════════════════════════════════
//
//    private fun isLocationEnabled(): Boolean = try {
//        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
//            (getSystemService(Context.LOCATION_SERVICE) as SysLocationManager).isLocationEnabled
//        } else {
//            @Suppress("DEPRECATION")
//            Settings.Secure.getInt(contentResolver, Settings.Secure.LOCATION_MODE) !=
//                    Settings.Secure.LOCATION_MODE_OFF
//        }
//    } catch (_: Exception) { false }
//
//    private fun checkLocationPermission() = try {
//        ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) ==
//                PackageManager.PERMISSION_GRANTED ||
//                ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) ==
//                PackageManager.PERMISSION_GRANTED
//    } catch (_: Exception) { false }
//
//    private fun log(msg: String) = android.util.Log.d("LocationMonitor", msg)
//}

package com.metaxperts.order_booking_app

// ═════════════════════════════════════════════════════════════════════════════
// LocationMonitorService — GPS PROVIDER EDITION
//
// CHANGES FROM PREVIOUS VERSION:
//   ❌ Removed: FusedLocationProviderClient (Google Play Services dependency)
//   ✅ Replaced with: android.location.LocationManager (GPS_PROVIDER — native)
//
//   ❌ Removed: WakeLock with no timeout (could trigger ANR/OS kill warnings)
//   ✅ Replaced with: 12-hour WakeLock timeout (covers a full work shift)
//      If service is still alive after 12 h, START_STICKY restarts it and
//      re-acquires the lock — continuous operation is still fully supported.
//
// WHY NATIVE GPS INSTEAD OF FUSED?
//   - No Google Play Services dependency (works on HMS / AOSP devices)
//   - Direct hardware GPS — no fused/network location blending
//   - Simpler mock-detection path (isMock on API 31+, isFromMockProvider below)
//   - Full control over provider and update interval
//
// TIMER LOGIC, MQTT, DB SAVE, CRITICAL EVENTS: unchanged from previous version
// ═════════════════════════════════════════════════════════════════════════════

import android.Manifest
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
// android.location.LocationManager used directly (no alias needed)
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import org.eclipse.paho.client.mqttv3.IMqttDeliveryToken
import org.eclipse.paho.client.mqttv3.MqttCallback
import org.eclipse.paho.client.mqttv3.MqttClient
import org.eclipse.paho.client.mqttv3.MqttConnectOptions
import org.eclipse.paho.client.mqttv3.MqttMessage
import org.eclipse.paho.client.mqttv3.persist.MemoryPersistence
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import java.util.concurrent.Executors

class LocationMonitorService : Service() {

    // ─── Notification IDs & Channels ─────────────────────────────────────────
    private val CHANNEL_ID              = "location_monitor_channel"
    private val URGENT_CHANNEL_ID       = "urgent_auto_clockout_channel"
    private val NOTIFICATION_ID         = 1001
    private val WORKING_NOTIFICATION_ID = 1002

    // ─── MQTT ─────────────────────────────────────────────────────────────────
    private val MQTT_HOST             = "119.153.102.7"
    private val MQTT_PORT             = 1883
    private val MQTT_PUBLISH_INTERVAL = 60_000L
    private val MQTT_RECONNECT_DELAY  = 15_000L
    private val DEFAULT_COMPANY_CODE  = "PK-PUN-SKT-MX01-VT001"

    // ─── SharedPreferences Keys ───────────────────────────────────────────────
    private val PREFS_NAME              = "FlutterSharedPreferences"
    private val KEY_IS_CLOCKED_IN       = "flutter.isClockedIn"
    private val KEY_IS_TIMER_FROZEN     = "flutter.is_timer_frozen"
    private val KEY_ELAPSED_TIME        = "flutter.elapsed_time"
    private val KEY_HAS_CRITICAL_EVENT  = "flutter.has_critical_event_pending"
    private val KEY_EVENT_TIMESTAMP     = "flutter.critical_event_timestamp"
    private val KEY_EVENT_REASON        = "flutter.critical_event_reason"
    private val KEY_EVENT_DISTANCE      = "flutter.critical_event_distance"
    private val KEY_EVENT_LAT           = "flutter.critical_event_latitude"
    private val KEY_EVENT_LNG           = "flutter.critical_event_longitude"
    private val KEY_BG_CLOCKOUT_PAYLOAD = "flutter.bg_clockout_payload"
    private val KEY_FAKE_GPS_DETECTED   = "flutter.fake_gps_detected"
    private val KEY_LAST_SAVE_WALL_MS   = "flutter.last_location_save_wall_ms"
    // KEY for wall-clock clock-in time (milliseconds) — written on clock-in
    private val KEY_CLOCK_IN_WALL_MS    = "flutter.clock_in_wall_ms"

    companion object {
        const val EXTRA_USER_ID      = "extra_user_id"
        const val EXTRA_BOOKER_NAME  = "extra_booker_name"
        const val EXTRA_DESIGNATION  = "extra_designation"
        const val EXTRA_COMPANY_CODE = "extra_company_code"

        @Volatile var isRunning = false
            private set

        fun start(
            context: Context,
            userId: String      = "",
            bookerName: String  = "",
            designation: String = "",
            companyCode: String = ""
        ) {
            val intent = Intent(context, LocationMonitorService::class.java).apply {
                putExtra(EXTRA_USER_ID,      userId)
                putExtra(EXTRA_BOOKER_NAME,  bookerName)
                putExtra(EXTRA_DESIGNATION,  designation)
                putExtra(EXTRA_COMPANY_CODE, companyCode)
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

    // ─── State ────────────────────────────────────────────────────────────────
    private lateinit var handler: Handler
    private val ioExecutor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "LocationIOThread").apply { isDaemon = true }
    }

    @Volatile private var foregroundStarted = false
    @Volatile private var isDestroyed       = false
    @Volatile private var isMqttConnected   = false
    // TIMER FIX: guard so timer starts only once per service instance
    @Volatile private var timerStarted      = false

    private var userId      = ""
    private var bookerName  = ""
    private var designation = ""
    private var companyCode = ""

    @Volatile private var lastLat      = 0.0
    @Volatile private var lastLon      = 0.0
    @Volatile private var lastAccuracy = 0f
    @Volatile private var lastSpeed    = 0f
    @Volatile private var lastRealLat  = 0.0
    @Volatile private var lastRealLon  = 0.0

    private var gpsLocationManager: LocationManager? = null
    private var gpsLocationListener: LocationListener? = null

    @Volatile private var gpsPolicy: GpsPolicy = GpsPolicy(60L, "high")

    // TIMER FIX: no more workingSeconds — use wall clock instead
    private var clockInWallMs          = 0L
    private var workingTimerRunnable:  Runnable? = null

    // ── Persistent WakeLock — 12-hour timeout ────────────────────────────────
    // PARTIAL_WAKE_LOCK: screen can turn off but CPU stays on → GPS + DB writes work.
    // Acquired in onStartCommand (after startForeground), released in onDestroy.
    // 12-hour timeout = maximum shift length. START_STICKY restart re-acquires it
    // automatically if the service outlives a single shift (overnight edge case).
    private var persistentWakeLock: PowerManager.WakeLock? = null

    private var mqttClient:            MqttClient? = null
    private var mqttPublishRunnable:   Runnable?   = null
    private var mqttReconnectRunnable: Runnable?   = null
    private var mqttPublishCount = 0

    private var wasLocationEnabled   = true
    private var wasPermissionGranted = true
    private var lastEventTime: Long  = 0
    private var lastEventReason      = ""

    private val PREF_SAVE_ANCHOR_WALL  = "flutter.location_save_anchor_wall_ms"
    private var saveAnchorMs           = 0L
    private var locationSaveRunnable:  Runnable? = null
    private var policyRefreshRunnable: Runnable? = null
    private var checkRunnable:         Runnable? = null

    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback:     ConnectivityManager.NetworkCallback? = null

    private val nativeDb: NativeDBHelper by lazy { NativeDBHelper(applicationContext) }

    private val FAKE_GPS_COOLDOWN_MS     = 30_000L
    @Volatile private var lastFakeGpsEventTime = 0L

    // ═════════════════════════════════════════════════════════════════════════
    // Lifecycle
    // ═════════════════════════════════════════════════════════════════════════

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        handler   = Handler(Looper.getMainLooper())
        registerReceivers()
        registerNetworkCallback()
        log("✅ [Service] onCreate")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannels()

        // startForeground() ONCE — must happen within 5s of startForegroundService()
        if (!foregroundStarted) {
            foregroundStarted = true
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(NOTIFICATION_ID, buildServiceNotification("⏳ Starting…"),
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
                } else {
                    startForeground(NOTIFICATION_ID, buildServiceNotification("⏳ Starting…"))
                }
            } catch (e: Exception) {
                log("❌ [Service] startForeground failed: ${e.message}")
                isRunning = false
                stopSelf()
                return START_NOT_STICKY
            }
            // ── Acquire persistent WakeLock right after startForeground ────────
            // Must happen here (not in onCreate) so it's re-acquired on each
            // START_STICKY restart, keeping the CPU awake for GPS + DB writes.
            acquirePersistentWakeLock()
        }

        // Resolve identity
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val intentUserId = intent?.getStringExtra(EXTRA_USER_ID)?.takeIf { it.isNotEmpty() }
        if (intentUserId != null) {
            userId      = intentUserId
            bookerName  = intent.getStringExtra(EXTRA_BOOKER_NAME)  ?: ""
            designation = intent.getStringExtra(EXTRA_DESIGNATION)   ?: ""
            companyCode = intent.getStringExtra(EXTRA_COMPANY_CODE)
                ?.takeIf { it.isNotEmpty() } ?: DEFAULT_COMPANY_CODE
            prefs.edit()
                .putString("flutter.userId",          userId)
                .putString("flutter.userName",        bookerName)
                .putString("flutter.userDesignation", designation)
                .putString("flutter.companyCode",     companyCode)
                .commit()
        } else {
            userId      = prefs.getString("flutter.userId",          "") ?: ""
            bookerName  = prefs.getString("flutter.userName",        "") ?: ""
            designation = prefs.getString("flutter.userDesignation", "") ?: ""
            companyCode = (prefs.getString("flutter.companyCode",    "") ?: "")
                .ifEmpty { DEFAULT_COMPANY_CODE }
        }

        if (userId.isEmpty()) {
            log("❌ [Service] userId empty — stopSelf")
            stopSelf()
            return START_NOT_STICKY
        }

        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
        val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

        wasPermissionGranted = checkLocationPermission()
        wasLocationEnabled   = isLocationEnabled()

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

        // ── TIMER FIX: resolve clockInWallMs from prefs ───────────────────────
        // Priority 1: flutter.clock_in_wall_ms (most accurate, set below)
        // Priority 2: flutter.clockInTime ISO string (set by Flutter on clock-in)
        // Priority 3: now (fallback — timer starts from 0)
        //
        // CRITICAL: Always try to write clock_in_wall_ms from clockInTime if not
        // already present. This ensures the timer survives service kill/restart
        // even if Flutter never explicitly wrote clock_in_wall_ms.
        if (clockedIn && !isFrozen) {
            val savedWallMs = prefs.getLong(KEY_CLOCK_IN_WALL_MS, 0L)
            if (savedWallMs > 0L) {
                clockInWallMs = savedWallMs
                log("⏱️ [Timer] Restored wall-ms: $clockInWallMs → ${(System.currentTimeMillis() - clockInWallMs) / 1000}s elapsed")
            } else {
                // Try parsing ISO clockInTime from Flutter
                val clockInStr = prefs.getString("flutter.clockInTime", "") ?: ""
                val parsed = tryParseClockInTime(clockInStr)
                clockInWallMs = if (parsed > 0L) {
                    // Save it as wall-ms so we don't parse again on next restart
                    prefs.edit().putLong(KEY_CLOCK_IN_WALL_MS, parsed).commit()
                    log("⏱️ [Timer] Parsed clockInTime: $clockInStr → ${(System.currentTimeMillis() - parsed) / 1000}s elapsed")
                    parsed
                } else {
                    // Fallback: check if elapsed_time string gives us a clue
                    // e.g. "01:23:45" → subtract that from now to reconstruct clockInTime
                    val elapsedStr = prefs.getString(KEY_ELAPSED_TIME, "") ?: ""
                    val elapsedSec = parseElapsedToSeconds(elapsedStr)
                    if (elapsedSec > 0L) {
                        val reconstructed = System.currentTimeMillis() - (elapsedSec * 1000L)
                        prefs.edit().putLong(KEY_CLOCK_IN_WALL_MS, reconstructed).commit()
                        log("⏱️ [Timer] Reconstructed from elapsed_time '$elapsedStr' → ${elapsedSec}s ago")
                        reconstructed
                    } else {
                        // True fallback — treat as clocked in just now
                        val now = System.currentTimeMillis()
                        prefs.edit().putLong(KEY_CLOCK_IN_WALL_MS, now).commit()
                        log("⚠️ [Timer] Could not parse clockInTime — starting from 0")
                        now
                    }
                }
            }
        }

        startAllLoops(prefs, resetAnchor = (intent?.action == "ACTION_CLOCK_IN"))

        return START_STICKY
    }

    // Parse ISO string "yyyy-MM-dd'T'HH:mm:ss" or "yyyy-MM-dd HH:mm:ss" → epoch ms
    private fun tryParseClockInTime(str: String): Long {
        if (str.isEmpty()) return 0L
        val formats = listOf(
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSS"
        )
        for (fmt in formats) {
            try {
                val d = SimpleDateFormat(fmt, Locale.getDefault()).parse(str)
                if (d != null) return d.time
            } catch (_: Exception) {}
        }
        return 0L
    }

    // Parse "HH:mm:ss" elapsed string → total seconds
    // Used to reconstruct clockInWallMs when clock_in_wall_ms pref is missing
    private fun parseElapsedToSeconds(str: String): Long {
        if (str.isEmpty()) return 0L
        return try {
            val parts = str.split(":")
            if (parts.size == 3) {
                val h = parts[0].toLong()
                val m = parts[1].toLong()
                val s = parts[2].toLong()
                h * 3600L + m * 60L + s
            } else 0L
        } catch (_: Exception) { 0L }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        log("🔄 [Service] App removed from recents — scheduling AlarmManager watchdog")

        // START_STICKY alone is often killed by aggressive OEMs (Vivo, Xiaomi, OPPO).
        // Belt-and-suspenders: also schedule a 5-second AlarmManager wakeup that
        // fires ServiceRestartReceiver → it checks isClockedIn and restarts service.
        try {
            val prefs     = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
            val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
            if (!clockedIn || isFrozen) return

            val am = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            val intent = android.content.Intent(this, ServiceRestartReceiver::class.java).apply {
                action = ServiceRestartReceiver.ACTION_RESTART_SERVICE
            }
            val pi = android.app.PendingIntent.getBroadcast(
                this, 9001, intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            val triggerAt = System.currentTimeMillis() + 5_000L
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                    am.setAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, triggerAt, pi)
                else -> am.set(android.app.AlarmManager.RTC_WAKEUP, triggerAt, pi)
            }
            log("✅ [Service] Watchdog alarm set for +5s")
        } catch (e: Exception) {
            log("⚠️ [Service] Watchdog alarm failed: ${e.message}")
        }
    }

    override fun onDestroy() {
        isDestroyed   = true
        isRunning     = false
        timerStarted  = false

        val prefs     = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
        val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

        if (clockedIn && !isFrozen) {
            val permRevoked = !checkLocationPermission()
            val locOff      = !isLocationEnabled()
            if (permRevoked || locOff) {
                val reason = if (permRevoked) "System ClockOut - Permission Revoked"
                else             "System ClockOut - Location Off"
                saveCriticalEventToPrefs(prefs, reason)
                MidnightClockoutReceiver.cancel(this)
            }
        }

        stopAllLoops()
        disconnectMqtt()
        unregisterNetworkCallback()
        try { unregisterReceiver(locationModeReceiver)   } catch (_: Exception) {}
        try { unregisterReceiver(screenReceiver)         } catch (_: Exception) {}
        try { unregisterReceiver(dateTimeChangeReceiver) } catch (_: Exception) {}
        ioExecutor.shutdown()

        // ── ROOT FIX: Remove BOTH notifications + release WakeLock ───────────
        // Without stopForeground(), notification 1001 stays stuck in status bar
        // even after stopService() — this is the "stuck notification" bug.
        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
        try { (getSystemService(NotificationManager::class.java)).cancel(NOTIFICATION_ID) } catch (_: Exception) {}
        try { (getSystemService(NotificationManager::class.java)).cancel(WORKING_NOTIFICATION_ID) } catch (_: Exception) {}
        releasePersistentWakeLock()

        super.onDestroy()
        log("🛑 [Service] onDestroy")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ═════════════════════════════════════════════════════════════════════════
    // Start / Stop all loops
    // ═════════════════════════════════════════════════════════════════════════

    private fun startAllLoops(
        prefs: android.content.SharedPreferences,
        resetAnchor: Boolean
    ) {
        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
        val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

        // GPS policy fetch (async) → then start GPS + save loop
        ioExecutor.submit {
            gpsPolicy = GpsPolicyManager.fetchPolicy(this, forceRefresh = true)
            log("📋 [Policy] interval=${gpsPolicy.locationIntervalSec}s accuracy=${gpsPolicy.gpsAccuracy}")
            handler.post { restartGpsAndSaveLoop(resetAnchor) }
        }

        if (clockedIn && !isFrozen) {
            // TIMER FIX: only start timer once per service instance
            if (!timerStarted) {
                timerStarted = true
                startWorkingTimer()
            }
            MidnightClockoutReceiver.schedule(this)
            LocationUploadWorker.schedule(this)
        }

        startMqttPublishing()
        startPermissionCheckLoop()
        startPolicyRefreshLoop()
    }

    private fun stopAllLoops() {
        checkRunnable?.let        { handler.removeCallbacks(it) }
        workingTimerRunnable?.let { handler.removeCallbacks(it) }
        policyRefreshRunnable?.let{ handler.removeCallbacks(it) }
        locationSaveRunnable?.let { handler.removeCallbacks(it) }
        mqttPublishRunnable?.let  { handler.removeCallbacks(it) }
        mqttReconnectRunnable?.let{ handler.removeCallbacks(it) }
        handler.removeCallbacksAndMessages(null)
        stopLocationUpdates()
        try { (getSystemService(NotificationManager::class.java)).cancel(WORKING_NOTIFICATION_ID) } catch (_: Exception) {}
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Working Timer — WALL CLOCK BASED (the real fix)
    //
    // Instead of workingSeconds++, we calculate:
    //   elapsed = (System.currentTimeMillis() - clockInWallMs) / 1000
    //
    // This means:
    //   - Phone sleep/wake → timer picks up exactly where it left off
    //   - Service restart  → timer picks up exactly where it left off
    //   - App kill/resume  → timer picks up exactly where it left off
    //   - No drift, no stuck, no reset
    // ═════════════════════════════════════════════════════════════════════════

    private fun startWorkingTimer() {
        workingTimerRunnable?.let { handler.removeCallbacks(it) }

        workingTimerRunnable = object : Runnable {
            override fun run() {
                if (isDestroyed) return

                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                // Stop ticking if clocked out or frozen
                if (!prefs.getBoolean(KEY_IS_CLOCKED_IN, false) ||
                    prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) {
                    return
                }

                // WALL CLOCK: always calculate from actual clock-in time
                val ref = if (clockInWallMs > 0L) clockInWallMs
                else prefs.getLong(KEY_CLOCK_IN_WALL_MS, System.currentTimeMillis())

                val totalSec = ((System.currentTimeMillis() - ref) / 1000L).coerceAtLeast(0L)
                val h = totalSec / 3600
                val m = (totalSec % 3600) / 60
                val s = totalSec % 60
                val timeStr = "%02d:%02d:%02d".format(h, m, s)

                updateWorkingTimerNotification(timeStr)

                // Persist for Flutter to read
                try {
                    prefs.edit().putString(KEY_ELAPSED_TIME, timeStr).apply()
                } catch (_: Exception) {}

                // Schedule next tick aligned to next second boundary
                // This keeps the timer from drifting over time
                val nowMs     = System.currentTimeMillis()
                val elapsedMs = nowMs - ref
                val nextTick  = 1000L - (elapsedMs % 1000L)
                val delay     = if (nextTick < 50L) nextTick + 1000L else nextTick

                if (!isDestroyed) handler.postDelayed(this, delay)
            }
        }
        handler.post(workingTimerRunnable!!)   // start immediately
        log("✅ [Timer] Wall-clock timer started — clockInWallMs=$clockInWallMs")
    }

    // ═════════════════════════════════════════════════════════════════════════
    // GPS Policy
    // ═════════════════════════════════════════════════════════════════════════

    private fun startPolicyRefreshLoop() {
        policyRefreshRunnable = object : Runnable {
            override fun run() {
                if (isDestroyed) return
                ioExecutor.submit {
                    val newPolicy = GpsPolicyManager.fetchPolicy(this@LocationMonitorService, forceRefresh = true)
                    val changed   = newPolicy.locationIntervalSec != gpsPolicy.locationIntervalSec ||
                            newPolicy.gpsAccuracy        != gpsPolicy.gpsAccuracy
                    gpsPolicy = newPolicy
                    if (changed) {
                        log("📋 [Policy] Changed → restarting GPS loop")
                        handler.post { restartGpsAndSaveLoop(resetAnchor = true) }
                    }
                }
                if (!isDestroyed) handler.postDelayed(this, 5 * 60_000L)
            }
        }
        handler.postDelayed(policyRefreshRunnable!!, 5 * 60_000L)
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Native GPS (LocationManager) updates
    // ═════════════════════════════════════════════════════════════════════════

    private fun startLocationUpdates() {
        if (!checkLocationPermission()) return
        if (gpsLocationListener != null) return   // already running

        try {
            val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            gpsLocationManager = lm

            // Require GPS_PROVIDER — no fused / network fallback
            if (!lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                log("❌ [GPS] GPS_PROVIDER disabled — skipping startLocationUpdates")
                return
            }

            val intervalMs   = gpsPolicy.locationIntervalSec * 1000L
            val minDistanceM = 0f   // accept every fix regardless of distance moved

            val maxAccuracy = when (gpsPolicy.gpsAccuracy) {
                "best"   -> 20f;  "high"   -> 50f
                "medium" -> 100f; "low"    -> 200f
                "lowest" -> 500f; else     -> 50f
            }

            gpsLocationListener = object : LocationListener {
                override fun onLocationChanged(loc: Location) {
                    // Reject mock / fake GPS
                    @Suppress("DEPRECATION")
                    val isMock = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                        loc.isMock
                    else
                        loc.isFromMockProvider
                    if (isMock) {
                        log("🚨 [GPS] Mock location detected")
                        handleFakeGpsDetected(loc.latitude, loc.longitude)
                        return
                    }
                    lastRealLat = loc.latitude
                    lastRealLon = loc.longitude

                    // Accuracy filter
                    if (loc.accuracy > maxAccuracy) {
                        log("⚠️ [GPS] Skipped low-accuracy: ${loc.accuracy}m (max=${maxAccuracy}m)")
                        return
                    }
                    lastLat      = loc.latitude
                    lastLon      = loc.longitude
                    lastAccuracy = loc.accuracy
                    lastSpeed    = loc.speed
                }

                @Deprecated("Deprecated in API 29")
                override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {}

                override fun onProviderEnabled(provider: String) {
                    log("✅ [GPS] Provider enabled: $provider")
                }

                override fun onProviderDisabled(provider: String) {
                    log("⚠️ [GPS] Provider disabled: $provider")
                    if (provider == LocationManager.GPS_PROVIDER) {
                        // GPS turned off — trigger critical event (same as FusedLocation path)
                        handler.post { checkPermissionsAndLocation() }
                    }
                }
            }

            lm.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                intervalMs,
                minDistanceM,
                gpsLocationListener!!,
                Looper.getMainLooper()
            )
            log("✅ [GPS] Native GPS_PROVIDER started — interval=${gpsPolicy.locationIntervalSec}s accuracy=$maxAccuracy m")
        } catch (e: Exception) {
            log("❌ [GPS] startLocationUpdates failed: ${e.message}")
        }
    }

    private fun stopLocationUpdates() {
        try {
            gpsLocationListener?.let { gpsLocationManager?.removeUpdates(it) }
        } catch (_: Exception) {}
        gpsLocationListener = null
        gpsLocationManager  = null
    }

    private fun restartGpsAndSaveLoop(resetAnchor: Boolean) {
        if (isDestroyed) return
        stopLocationUpdates()
        startLocationUpdates()
        scheduleLocationSave(resetAnchor)
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Location Save — Anchor-Based Precise Scheduling
    // ═════════════════════════════════════════════════════════════════════════

    private fun scheduleLocationSave(resetAnchor: Boolean = false) {
        locationSaveRunnable?.let { handler.removeCallbacks(it) }
        locationSaveRunnable = null

        val prefs      = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val nowWall    = System.currentTimeMillis()
        val intervalMs = gpsPolicy.locationIntervalSec * 1000L

        if (resetAnchor) {
            saveAnchorMs = nowWall
            prefs.edit().putLong(PREF_SAVE_ANCHOR_WALL, saveAnchorMs).apply()
            log("⚓ [SaveLoop] Anchor RESET at $saveAnchorMs")
        } else {
            val stored = prefs.getLong(PREF_SAVE_ANCHOR_WALL, 0L)
            saveAnchorMs = if (stored > 0L && stored <= nowWall) stored else {
                nowWall.also { prefs.edit().putLong(PREF_SAVE_ANCHOR_WALL, it).apply() }
            }
        }
        scheduleNextSaveTick()
    }

    private fun scheduleNextSaveTick() {
        if (isDestroyed) return

        val intervalMs = gpsPolicy.locationIntervalSec * 1000L
        val nowWall    = System.currentTimeMillis()
        val elapsed    = nowWall - saveAnchorMs
        val ticksDone  = elapsed / intervalMs
        val nextWall   = saveAnchorMs + (ticksDone + 1) * intervalMs
        var delayMs    = nextWall - nowWall
        if (delayMs <= 0L) delayMs = intervalMs

        log("⏱️ [SaveLoop] Next save in ${delayMs / 1000}s (interval=${intervalMs / 1000}s)")

        locationSaveRunnable = Runnable {
            if (isDestroyed) return@Runnable
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            if (prefs.getBoolean(KEY_IS_CLOCKED_IN, false) &&
                !prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) {
                ioExecutor.submit { saveLocationToDB(prefs) }
            }
            scheduleNextSaveTick()
        }
        handler.postDelayed(locationSaveRunnable!!, delayMs)
    }

    private fun saveLocationToDB(prefs: android.content.SharedPreferences) {
        val lat = lastLat
        val lon = lastLon
        if (lat == 0.0 && lon == 0.0) {
            log("⚠️ [SaveLoop] No GPS fix yet — skipping")
            return
        }
        val wl = acquireShortWakeLock("BookIT::DbWriteLock", 15_000L)
        try {
            val now  = Date()
            val sdf  = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            val stf  = SimpleDateFormat("HH:mm:ss",   Locale.getDefault())
            val ddf  = SimpleDateFormat("dd",          Locale.getDefault())
            val mdf  = SimpleDateFormat("MMM",         Locale.getDefault())
            val rowId = "LT-$userId-${ddf.format(now)}-${mdf.format(now)}" +
                    "-${UUID.randomUUID().toString().takeLast(6).uppercase()}"
            val code = companyCode.ifEmpty { DEFAULT_COMPANY_CODE }
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
            prefs.edit().putLong(KEY_LAST_SAVE_WALL_MS, System.currentTimeMillis()).apply()
            log("💾 [SaveLoop] Saved: $rowId lat=$lat lng=$lon")
        } catch (e: Exception) {
            log("❌ [SaveLoop] DB save failed: ${e.message}")
        } finally {
            releaseWakeLock(wl)
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // MQTT
    // ═════════════════════════════════════════════════════════════════════════

    private fun startMqttPublishing() {
        connectMqtt()
        mqttPublishRunnable?.let { handler.removeCallbacks(it) }
        mqttPublishRunnable = object : Runnable {
            override fun run() {
                if (isDestroyed) return
                publishLocationToMqtt()
                handler.postDelayed(this, MQTT_PUBLISH_INTERVAL)
            }
        }
        handler.postDelayed(mqttPublishRunnable!!, MQTT_PUBLISH_INTERVAL)
    }

    private fun connectMqtt() {
        ioExecutor.submit {
            try {
                if (isMqttConnected) return@submit
                val clientId = "android-$userId-${UUID.randomUUID().toString().take(8)}"
                val client   = MqttClient("tcp://$MQTT_HOST:$MQTT_PORT", clientId, MemoryPersistence())
                client.setCallback(object : MqttCallback {
                    override fun connectionLost(cause: Throwable?) {
                        isMqttConnected = false
                        handler.post { scheduleReconnect() }
                    }
                    override fun messageArrived(t: String?, m: MqttMessage?) {}
                    override fun deliveryComplete(t: IMqttDeliveryToken?) {}
                })
                val opts = MqttConnectOptions().apply {
                    isCleanSession       = true
                    connectionTimeout    = 10
                    keepAliveInterval    = 30
                    isAutomaticReconnect = false
                }
                client.connect(opts)
                mqttClient      = client
                isMqttConnected = true
                handler.post { updateServiceNotification("✅ Live tracking active") }
                log("✅ [MQTT] Connected")
            } catch (e: Exception) {
                isMqttConnected = false
                handler.post { scheduleReconnect() }
                log("❌ [MQTT] Connect failed: ${e.message}")
            }
        }
    }

    private fun disconnectMqtt() {
        mqttReconnectRunnable?.let { handler.removeCallbacks(it) }
        mqttReconnectRunnable = null
        ioExecutor.submit {
            try { if (mqttClient?.isConnected == true) mqttClient?.disconnect(0) } catch (_: Exception) {}
            mqttClient = null; isMqttConnected = false
        }
    }

    private fun scheduleReconnect() {
        if (isDestroyed) return
        mqttReconnectRunnable?.let { handler.removeCallbacks(it) }
        mqttReconnectRunnable = Runnable { if (!isDestroyed && !isMqttConnected) connectMqtt() }
        handler.postDelayed(mqttReconnectRunnable!!, MQTT_RECONNECT_DELAY)
    }

    private fun publishLocationToMqtt() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_IS_CLOCKED_IN, false)) return
        if (prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) return
        if (lastLat == 0.0 && lastLon == 0.0) return
        val payload = JSONObject().apply {
            put("device_id",    userId)
            put("company_code", companyCode.ifEmpty { DEFAULT_COMPANY_CODE })
            put("emp_name",     bookerName)
            put("dept_id",      designation)
            put("lat",          lastLat)
            put("lon",          lastLon)
            put("accuracy",     lastAccuracy)
            put("speed",        lastSpeed)
            put("track_id",     System.currentTimeMillis())
            put("timestamp",    SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date()))
            put("source",       "android_foreground_service")
        }.toString()
        ioExecutor.submit {
            try {
                val client = mqttClient ?: return@submit
                if (!client.isConnected) { handler.post { scheduleReconnect() }; return@submit }
                val msg = MqttMessage(payload.toByteArray(Charsets.UTF_8)).apply {
                    qos = 1; isRetained = false
                }
                client.publish("gps/${companyCode.ifEmpty { DEFAULT_COMPANY_CODE }}/$userId", msg)
                mqttPublishCount++
                handler.post { updateServiceNotification("✅ Live tracking • #$mqttPublishCount") }
            } catch (e: Exception) {
                isMqttConnected = false
                handler.post { scheduleReconnect() }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Permission / Location Check Loop
    // ═════════════════════════════════════════════════════════════════════════

    private fun startPermissionCheckLoop() {
        checkRunnable = object : Runnable {
            override fun run() {
                if (isDestroyed) return
                checkPermissionsAndLocation()
                handler.postDelayed(this, 30_000L)
            }
        }
        handler.postDelayed(checkRunnable!!, 30_000L)
    }

    private fun checkPermissionsAndLocation() {
        val prefs     = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
        val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
        if (!clockedIn || isFrozen) return

        val permOk = checkLocationPermission()
        val locOn  = isLocationEnabled()

        if (wasPermissionGranted && !permOk) {
            val now = System.currentTimeMillis()
            if (now - lastEventTime > 5_000L) {
                lastEventTime   = now
                lastEventReason = "System ClockOut - Permission Revoked"
                handleCriticalEvent("System ClockOut - Permission Revoked")
                return
            }
        }
        if (wasLocationEnabled && !locOn) {
            val now = System.currentTimeMillis()
            if (now - lastEventTime > 5_000L) {
                lastEventTime   = now
                lastEventReason = "System ClockOut - Location Off"
                handleCriticalEvent("System ClockOut - Location Off")
                return
            }
        }
        wasPermissionGranted = permOk
        wasLocationEnabled   = locOn
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Critical Events
    // ═════════════════════════════════════════════════════════════════════════

    private fun handleCriticalEvent(reason: String) = handleCriticalEventWithTime(reason, Date())

    private fun handleCriticalEventWithTime(reason: String, eventTime: Date) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)) return
        saveCriticalEventToPrefs(prefs, reason, eventTime)
        showCriticalNotification(reason,
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(eventTime))
        MidnightClockoutReceiver.cancel(this)
        LocationUploadWorker.cancel(this)
        stopAllLoops()
        disconnectMqtt()
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
        handler.post {
            val prefs2   = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val ts       = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date())
            val elapsed  = prefs2.getString(KEY_ELAPSED_TIME, "00:00:00") ?: "00:00:00"
            val clockInT = prefs2.getString("flutter.clockInTime", "") ?: ""
            prefs2.edit()
                .putBoolean(KEY_HAS_CRITICAL_EVENT, true)
                .putBoolean("has_critical_event_pending", true)
                .putBoolean(KEY_IS_TIMER_FROZEN, true)
                .putString(KEY_EVENT_TIMESTAMP,  ts)
                .putString(KEY_EVENT_REASON,     "System ClockOut - Fake GPS Detected")
                .putString("critical_event_reason", "System ClockOut - Fake GPS Detected")
                .putBoolean(KEY_IS_CLOCKED_IN, false)
                .putBoolean("isClockedIn", false)
                .putBoolean(KEY_FAKE_GPS_DETECTED, true)
                .putFloat("flutter.fake_gps_lat", fakeLat.toFloat())
                .putFloat("flutter.fake_gps_lon", fakeLng.toFloat())
                .putFloat("flutter.real_gps_lat", lastRealLat.toFloat())
                .putFloat("flutter.real_gps_lon", lastRealLon.toFloat())
                .putString("flutter.fastClockOutTime", ts)
                .putFloat("flutter.fastClockOutDistance", 0f)
                .putString("flutter.fastClockOutReason", "System ClockOut - Fake GPS Detected")
                .putBoolean("flutter.hasFastClockOutData", true)
                .putBoolean("flutter.clockOutPending", true)
                .putString("flutter.fastClockOutData",
                    """{"fast_attendanceId":"","fast_userId":"$userId","fast_clockOutTime":"$ts","fast_totalTime":"$elapsed","fast_totalDistance":0.0,"fast_latOut":${lastRealLat},"fast_lngOut":${lastRealLon},"fast_address":"","fast_reason":"System ClockOut - Fake GPS Detected","fast_savedAt":"${System.currentTimeMillis()}","fast_clockInTime":"$clockInT"}""")
                .commit()
            showCriticalNotification("System ClockOut - Fake GPS Detected", ts)
            MidnightClockoutReceiver.cancel(this)
            LocationUploadWorker.cancel(this)
            stopAllLoops()
            disconnectMqtt()
            try { (getSystemService(NotificationManager::class.java)).cancel(WORKING_NOTIFICATION_ID) } catch (_: Exception) {}
            try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
            stopSelf()
        }
    }

    private fun saveCriticalEventToPrefs(
        prefs: android.content.SharedPreferences,
        reason: String,
        eventTime: Date = Date()
    ) {
        val ts       = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(eventTime)
        val elapsed  = prefs.getString(KEY_ELAPSED_TIME, "00:00:00") ?: "00:00:00"
        val clockInT = prefs.getString("flutter.clockInTime", "") ?: ""
        prefs.edit()
            .putBoolean(KEY_HAS_CRITICAL_EVENT, true)
            .putBoolean("has_critical_event_pending", true)
            .putBoolean(KEY_IS_TIMER_FROZEN, true)
            .putString(KEY_EVENT_TIMESTAMP, ts)
            .putString(KEY_EVENT_REASON, reason)
            .putString("critical_event_reason", reason)
            .putFloat(KEY_EVENT_DISTANCE, 0f)
            .putFloat(KEY_EVENT_LAT, 0f)
            .putFloat(KEY_EVENT_LNG, 0f)
            .putBoolean(KEY_IS_CLOCKED_IN, false)
            .putBoolean("isClockedIn", false)
            .putBoolean("flutter.pending_gpx_close", true)
            .putString("flutter.fastClockOutTime", ts)
            .putFloat("flutter.fastClockOutDistance", 0f)
            .putString("flutter.fastClockOutReason", reason)
            .putBoolean("flutter.hasFastClockOutData", true)
            .putBoolean("flutter.clockOutPending", true)
            .putString("flutter.fastClockOutData",
                """{"fast_attendanceId":"","fast_userId":"$userId","fast_clockOutTime":"$ts","fast_totalTime":"$elapsed","fast_totalDistance":0.0,"fast_latOut":0.0,"fast_lngOut":0.0,"fast_address":"","fast_reason":"$reason","fast_savedAt":"${System.currentTimeMillis()}","fast_clockInTime":"$clockInT"}""")
            .putString(KEY_BG_CLOCKOUT_PAYLOAD,
                """{"timestamp":"$ts","reason":"$reason","elapsed_at_event":"$elapsed","distance":0.0,"latitude":0.0,"longitude":0.0}""")
            .commit()
        log("💾 [Critical] Saved: reason=$reason ts=$ts")
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Broadcast Receivers
    // ═════════════════════════════════════════════════════════════════════════

    private val locationModeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == LocationManager.MODE_CHANGED_ACTION)
                handler.post { checkPermissionsAndLocation() }
        }
    }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            handler.post { checkPermissionsAndLocation() }
        }
    }

    private val dateTimeChangeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {}
    }

    private fun registerReceivers() {
        registerReceiver(locationModeReceiver, IntentFilter(LocationManager.MODE_CHANGED_ACTION))
        registerReceiver(screenReceiver, IntentFilter(Intent.ACTION_SCREEN_ON))
        val tf = IntentFilter().apply {
            addAction(Intent.ACTION_TIME_CHANGED)
            addAction(Intent.ACTION_DATE_CHANGED)
            addAction(Intent.ACTION_TIMEZONE_CHANGED)
        }
        registerReceiver(dateTimeChangeReceiver, tf)
    }

    private fun registerNetworkCallback() {
        try {
            connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val req = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET).build()
            networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    handler.post {
                        if (!isDestroyed && !isMqttConnected) connectMqtt()
                        ioExecutor.submit {
                            gpsPolicy = GpsPolicyManager.fetchPolicy(
                                this@LocationMonitorService, forceRefresh = true)
                        }
                    }
                }
                override fun onLost(network: Network) {
                    isMqttConnected = false
                    handler.post { updateServiceNotification("❌ MQTT offline — no internet") }
                }
            }
            connectivityManager?.registerNetworkCallback(req, networkCallback!!)
        } catch (e: Exception) { log("⚠️ [Network] Callback reg failed: ${e.message}") }
    }

    private fun unregisterNetworkCallback() {
        try { networkCallback?.let { connectivityManager?.unregisterNetworkCallback(it) } } catch (_: Exception) {}
        networkCallback = null
    }

    // ═════════════════════════════════════════════════════════════════════════
    // WakeLock helpers
    // ═════════════════════════════════════════════════════════════════════════

    // ── Persistent WakeLock (held for entire service lifetime) ────────────────
    // PARTIAL_WAKE_LOCK: screen OFF is fine, CPU stays ON.
    // This prevents the OS from putting the CPU to sleep while GPS is running.
    // Must be held continuously — releasing it even briefly can drop GPS fixes.
    private fun acquirePersistentWakeLock() {
        try {
            if (persistentWakeLock?.isHeld == true) return  // already held
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            persistentWakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "BookIT::LocationServiceWakeLock"
            ).also {
                it.setReferenceCounted(false)
                // 12-hour hard timeout — covers a full work shift.
                // If the user is still clocked in after 12 h the service's
                // onStartCommand re-acquires the lock on the next START_STICKY restart,
                // so continuous operation beyond 12 h is still supported.
                val TWELVE_HOURS_MS = 12L * 60L * 60L * 1000L
                it.acquire(TWELVE_HOURS_MS)
            }
            log("✅ [WakeLock] Persistent lock acquired (12-hour timeout)")
        } catch (e: Exception) {
            log("⚠️ [WakeLock] Persistent lock failed: ${e.message}")
        }
    }

    private fun releasePersistentWakeLock() {
        try {
            if (persistentWakeLock?.isHeld == true) persistentWakeLock?.release()
            persistentWakeLock = null
            log("✅ [WakeLock] Persistent lock released")
        } catch (_: Exception) {}
    }

    // ── Short WakeLock (timed, for DB writes) ─────────────────────────────────
    private fun acquireShortWakeLock(tag: String, timeoutMs: Long): PowerManager.WakeLock? {
        return try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, tag).also { it.acquire(timeoutMs) }
        } catch (e: Exception) { log("⚠️ [WakeLock] $tag failed: ${e.message}"); null }
    }

    private fun releaseWakeLock(wl: PowerManager.WakeLock?) {
        try { if (wl?.isHeld == true) wl.release() } catch (_: Exception) {}
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Notifications
    // ═════════════════════════════════════════════════════════════════════════

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Location Monitor",
                NotificationManager.IMPORTANCE_LOW).apply {
                description = "Monitors location for attendance tracking"
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            }
        )
        nm.createNotificationChannel(
            NotificationChannel(URGENT_CHANNEL_ID, "URGENT Auto Clockout",
                NotificationManager.IMPORTANCE_HIGH).apply {
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 1000, 500, 1000)
                enableLights(true)
                lightColor = android.graphics.Color.RED
            }
        )
    }

    private fun buildServiceNotification(text: String): Notification {
        val pi = PendingIntent.getActivity(this, 0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("BookIT Attendance Active")
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pi)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateServiceNotification(text: String) {
        if (isDestroyed) return
        val n = buildServiceNotification(text)
        (getSystemService(NotificationManager::class.java)).notify(NOTIFICATION_ID, n)
    }

    private fun updateWorkingTimerNotification(timeStr: String) {
        if (isDestroyed) return
        val pi = PendingIntent.getActivity(this, 1,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val n = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Working Time")
            .setContentText("⏱ $timeStr")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pi)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        try {
            (getSystemService(NotificationManager::class.java)).notify(WORKING_NOTIFICATION_ID, n)
        } catch (_: Exception) {}
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
            }, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
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

    // ═════════════════════════════════════════════════════════════════════════
    // Helpers
    // ═════════════════════════════════════════════════════════════════════════

    private fun isLocationEnabled(): Boolean = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            (getSystemService(Context.LOCATION_SERVICE) as LocationManager).isLocationEnabled
        } else {
            @Suppress("DEPRECATION")
            Settings.Secure.getInt(contentResolver, Settings.Secure.LOCATION_MODE) !=
                    Settings.Secure.LOCATION_MODE_OFF
        }
    } catch (_: Exception) { false }

    private fun checkLocationPermission() = try {
        ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
    } catch (_: Exception) { false }

    private fun log(msg: String) = android.util.Log.d("LocationMonitor", msg)
}