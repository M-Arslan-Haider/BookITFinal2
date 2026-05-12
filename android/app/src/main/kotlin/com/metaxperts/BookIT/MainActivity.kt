////////////
////////////package com.metaxperts.order_booking_app
////////////
////////////import android.content.Intent
////////////import android.net.Uri
////////////import android.os.Bundle
////////////import android.os.PowerManager
////////////import android.provider.Settings
////////////import com.google.android.gms.common.GoogleApiAvailability
////////////import com.google.android.gms.security.ProviderInstaller
////////////import io.flutter.embedding.android.FlutterFragmentActivity
////////////import io.flutter.embedding.engine.FlutterEngine
////////////import io.flutter.plugin.common.MethodChannel
////////////
////////////class MainActivity : FlutterFragmentActivity(), ProviderInstaller.ProviderInstallListener {
////////////
////////////    // Must match the channel name used in Dart (mqtt_work.dart + timer_card.dart)
////////////    private val LOCATION_CHANNEL = "com.metaxperts.order_booking_app/location_monitor"
////////////
////////////    override fun onCreate(savedInstanceState: Bundle?) {
////////////        super.onCreate(savedInstanceState)
////////////        // Update Android security provider — required for TLS on older devices
////////////        ProviderInstaller.installIfNeededAsync(this, this)
////////////    }
////////////
////////////    override fun onProviderInstalled() {}
////////////
////////////    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
////////////        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
////////////    }
////////////
////////////    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
////////////        super.configureFlutterEngine(flutterEngine)
////////////
////////////        MethodChannel(
////////////            flutterEngine.dartExecutor.binaryMessenger,
////////////            LOCATION_CHANNEL
////////////        ).setMethodCallHandler { call, result ->
////////////            when (call.method) {
////////////
////////////                "startMonitoring" -> {
////////////                    try {
////////////                        val userId      = call.argument<String>("userId")      ?: ""
////////////                        val bookerName  = call.argument<String>("bookerName")  ?: ""
////////////                        val designation = call.argument<String>("designation") ?: ""
////////////                        val companyCode = call.argument<String>("companyCode") ?: ""
////////////
////////////                        LocationMonitorService.start(
////////////                            context     = this,
////////////                            userId      = userId,
////////////                            bookerName  = bookerName,
////////////                            designation = designation,
////////////                            companyCode = companyCode
////////////                        )
////////////                        result.success(null)
////////////                    } catch (e: Exception) {
////////////                        result.error("START_FAILED", e.message, null)
////////////                    }
////////////                }
////////////
////////////                "stopMonitoring" -> {
////////////                    try {
////////////                        LocationMonitorService.stop(this)
////////////                        result.success(null)
////////////                    } catch (e: Exception) {
////////////                        result.error("STOP_FAILED", e.message, null)
////////////                    }
////////////                }
////////////
////////////                "requestBatteryOptimization" -> {
////////////                    try {
////////////                        val pm = getSystemService(POWER_SERVICE) as PowerManager
////////////                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
////////////                            val intent = Intent(
////////////                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
////////////                            ).apply {
////////////                                data = Uri.parse("package:$packageName")
////////////                            }
////////////                            startActivity(intent)
////////////                        }
////////////                        result.success(null)
////////////                    } catch (e: Exception) {
////////////                        result.success(null) // non-fatal
////////////                    }
////////////                }
////////////
////////////                else -> result.notImplemented()
////////////            }
////////////        }
////////////    }
////////////}
//////////
//////////package com.metaxperts.order_booking_app
//////////
//////////// ══════════════════════════════════════════════════════════════════════════════
//////////// MainActivity.kt — Updated version
//////////// Sirf sync_alarm MethodChannel add kiya gaya hai — baqi sab same hai
//////////// ══════════════════════════════════════════════════════════════════════════════
//////////
//////////import android.content.Intent
//////////import android.net.Uri
//////////import android.os.Bundle
//////////import android.os.PowerManager
//////////import android.provider.Settings
//////////import com.google.android.gms.common.GoogleApiAvailability
//////////import com.google.android.gms.security.ProviderInstaller
//////////import io.flutter.embedding.android.FlutterFragmentActivity
//////////import io.flutter.embedding.engine.FlutterEngine
//////////import io.flutter.plugin.common.MethodChannel
//////////
//////////class MainActivity : FlutterFragmentActivity(), ProviderInstaller.ProviderInstallListener {
//////////
//////////    private val LOCATION_CHANNEL  = "com.metaxperts.order_booking_app/location_monitor"
//////////    // ✅ NEW: Sync alarm channel
//////////    private val SYNC_ALARM_CHANNEL = "com.metaxperts.order_booking_app/sync_alarm"
//////////
//////////    override fun onCreate(savedInstanceState: Bundle?) {
//////////        super.onCreate(savedInstanceState)
//////////        ProviderInstaller.installIfNeededAsync(this, this)
//////////    }
//////////
//////////    override fun onProviderInstalled() {}
//////////
//////////    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
//////////        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
//////////    }
//////////
//////////    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
//////////        super.configureFlutterEngine(flutterEngine)
//////////
//////////        // ── Existing location monitor channel ─────────────────────────────
//////////        MethodChannel(
//////////            flutterEngine.dartExecutor.binaryMessenger,
//////////            LOCATION_CHANNEL
//////////        ).setMethodCallHandler { call, result ->
//////////            when (call.method) {
//////////
//////////                "startMonitoring" -> {
//////////                    try {
//////////                        val userId      = call.argument<String>("userId")      ?: ""
//////////                        val bookerName  = call.argument<String>("bookerName")  ?: ""
//////////                        val designation = call.argument<String>("designation") ?: ""
//////////                        val companyCode = call.argument<String>("companyCode") ?: ""
//////////
//////////                        LocationMonitorService.start(
//////////                            context     = this,
//////////                            userId      = userId,
//////////                            bookerName  = bookerName,
//////////                            designation = designation,
//////////                            companyCode = companyCode
//////////                        )
//////////                        result.success(null)
//////////                    } catch (e: Exception) {
//////////                        result.error("START_FAILED", e.message, null)
//////////                    }
//////////                }
//////////
//////////                "stopMonitoring" -> {
//////////                    try {
//////////                        LocationMonitorService.stop(this)
//////////                        result.success(null)
//////////                    } catch (e: Exception) {
//////////                        result.error("STOP_FAILED", e.message, null)
//////////                    }
//////////                }
//////////
//////////                "requestBatteryOptimization" -> {
//////////                    try {
//////////                        val pm = getSystemService(POWER_SERVICE) as PowerManager
//////////                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
//////////                            val intent = Intent(
//////////                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
//////////                            ).apply {
//////////                                data = Uri.parse("package:$packageName")
//////////                            }
//////////                            startActivity(intent)
//////////                        }
//////////                        result.success(null)
//////////                    } catch (e: Exception) {
//////////                        result.success(null)
//////////                    }
//////////                }
//////////
//////////                else -> result.notImplemented()
//////////            }
//////////        }
//////////
//////////        // ✅ NEW: Sync alarm channel — Flutter se alarm start/stop karne ke liye
//////////        MethodChannel(
//////////            flutterEngine.dartExecutor.binaryMessenger,
//////////            SYNC_ALARM_CHANNEL
//////////        ).setMethodCallHandler { call, result ->
//////////            when (call.method) {
//////////
//////////                "startAlarm" -> {
//////////                    try {
//////////                        SyncAlarmReceiver.startAlarm(this)
//////////                        result.success(null)
//////////                    } catch (e: Exception) {
//////////                        result.error("ALARM_START_FAILED", e.message, null)
//////////                    }
//////////                }
//////////
//////////                "stopAlarm" -> {
//////////                    try {
//////////                        SyncAlarmReceiver.stopAlarm(this)
//////////                        result.success(null)
//////////                    } catch (e: Exception) {
//////////                        result.error("ALARM_STOP_FAILED", e.message, null)
//////////                    }
//////////                }
//////////
//////////                else -> result.notImplemented()
//////////            }
//////////        }
//////////    }
//////////}
////////
////////
///////////8pm alaram
////////package com.metaxperts.order_booking_app
////////
////////// ══════════════════════════════════════════════════════════════════════════════
////////// MainActivity.kt — Updated with Clockout Alarm Channel
////////// Existing code same hai — sirf ek naya MethodChannel add kiya gaya hai
////////// ══════════════════════════════════════════════════════════════════════════════
////////
////////import android.content.Intent
////////import android.net.Uri
////////import android.os.Bundle
////////import android.os.PowerManager
////////import android.provider.Settings
////////import com.google.android.gms.common.GoogleApiAvailability
////////import com.google.android.gms.security.ProviderInstaller
////////import io.flutter.embedding.android.FlutterFragmentActivity
////////import io.flutter.embedding.engine.FlutterEngine
////////import io.flutter.plugin.common.MethodChannel
////////
////////class MainActivity : FlutterFragmentActivity(), ProviderInstaller.ProviderInstallListener {
////////
////////    private val LOCATION_CHANNEL      = "com.metaxperts.order_booking_app/location_monitor"
////////    private val SYNC_ALARM_CHANNEL    = "com.metaxperts.order_booking_app/sync_alarm"
////////    // ✅ NEW: Clockout 8PM alarm channel
////////    private val CLOCKOUT_ALARM_CHANNEL = "com.metaxperts.order_booking_app/clockout_alarm"
////////
////////    override fun onCreate(savedInstanceState: Bundle?) {
////////        super.onCreate(savedInstanceState)
////////        ProviderInstaller.installIfNeededAsync(this, this)
////////    }
////////
////////    override fun onProviderInstalled() {}
////////
////////    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
////////        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
////////    }
////////
////////    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
////////        super.configureFlutterEngine(flutterEngine)
////////
////////        // ── 1. Existing location monitor channel ──────────────────────────
////////        MethodChannel(
////////            flutterEngine.dartExecutor.binaryMessenger,
////////            LOCATION_CHANNEL
////////        ).setMethodCallHandler { call, result ->
////////            when (call.method) {
////////
////////                "startMonitoring" -> {
////////                    try {
////////                        val userId      = call.argument<String>("userId")      ?: ""
////////                        val bookerName  = call.argument<String>("bookerName")  ?: ""
////////                        val designation = call.argument<String>("designation") ?: ""
////////                        val companyCode = call.argument<String>("companyCode") ?: ""
////////
////////                        LocationMonitorService.start(
////////                            context     = this,
////////                            userId      = userId,
////////                            bookerName  = bookerName,
////////                            designation = designation,
////////                            companyCode = companyCode
////////                        )
////////                        result.success(null)
////////                    } catch (e: Exception) {
////////                        result.error("START_FAILED", e.message, null)
////////                    }
////////                }
////////
////////                "stopMonitoring" -> {
////////                    try {
////////                        LocationMonitorService.stop(this)
////////                        result.success(null)
////////                    } catch (e: Exception) {
////////                        result.error("STOP_FAILED", e.message, null)
////////                    }
////////                }
////////
////////                "requestBatteryOptimization" -> {
////////                    try {
////////                        val pm = getSystemService(POWER_SERVICE) as PowerManager
////////                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
////////                            val intent = Intent(
////////                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
////////                            ).apply {
////////                                data = Uri.parse("package:$packageName")
////////                            }
////////                            startActivity(intent)
////////                        }
////////                        result.success(null)
////////                    } catch (e: Exception) {
////////                        result.success(null)
////////                    }
////////                }
////////
////////                else -> result.notImplemented()
////////            }
////////        }
////////
////////        // ── 2. Existing sync alarm channel (15-minute reminder) ───────────
////////        MethodChannel(
////////            flutterEngine.dartExecutor.binaryMessenger,
////////            SYNC_ALARM_CHANNEL
////////        ).setMethodCallHandler { call, result ->
////////            when (call.method) {
////////
////////                "startAlarm" -> {
////////                    try {
////////                        SyncAlarmReceiver.startAlarm(this)
////////                        result.success(null)
////////                    } catch (e: Exception) {
////////                        result.error("ALARM_START_FAILED", e.message, null)
////////                    }
////////                }
////////
////////                "stopAlarm" -> {
////////                    try {
////////                        SyncAlarmReceiver.stopAlarm(this)
////////                        result.success(null)
////////                    } catch (e: Exception) {
////////                        result.error("ALARM_STOP_FAILED", e.message, null)
////////                    }
////////                }
////////
////////                else -> result.notImplemented()
////////            }
////////        }
////////
////////        // ── 3. ✅ NEW: Clockout 8PM alarm channel ─────────────────────────
////////        MethodChannel(
////////            flutterEngine.dartExecutor.binaryMessenger,
////////            CLOCKOUT_ALARM_CHANNEL
////////        ).setMethodCallHandler { call, result ->
////////            when (call.method) {
////////
////////                // Flutter clock-in kare → 8PM alarm schedule karo
////////                "schedule8PMAlarm" -> {
////////                    try {
////////                        ClockoutAlarmReceiver.scheduleDaily8PMAlarm(this)
////////                        result.success(null)
////////                    } catch (e: Exception) {
////////                        result.error("CLOCKOUT_ALARM_FAILED", e.message, null)
////////                    }
////////                }
////////
////////                // Flutter clock-out kare ya manually stop kare → sab band karo
////////                "stopEverything" -> {
////////                    try {
////////                        ClockoutAlarmReceiver.stopEverything(this)
////////                        result.success(null)
////////                    } catch (e: Exception) {
////////                        result.error("CLOCKOUT_STOP_FAILED", e.message, null)
////////                    }
////////                }
////////
////////                // Abhi se ringtone shuru karo (8PM guzar gayi, app open hua)
////////                "startRingtoneNow" -> {
////////                    try {
////////                        ClockoutAlarmReceiver.startRingtoneService(this)
////////                        result.success(null)
////////                    } catch (e: Exception) {
////////                        result.error("RINGTONE_START_FAILED", e.message, null)
////////                    }
////////                }
////////
////////                // Alarm band karo lekin ringtone nahi (agar sirf alarm reschedule chahiye)
////////                "cancelAlarmOnly" -> {
////////                    try {
////////                        ClockoutAlarmReceiver.cancelAlarm(this)
////////                        result.success(null)
////////                    } catch (e: Exception) {
////////                        result.error("CANCEL_ALARM_FAILED", e.message, null)
////////                    }
////////                }
////////
////////                else -> result.notImplemented()
////////            }
////////        }
////////    }
////////}
//////
//////
//////package com.metaxperts.order_booking_app
//////
//////import android.content.Intent
//////import android.net.Uri
//////import android.os.Bundle
//////import android.os.PowerManager
//////import android.provider.Settings
//////import com.google.android.gms.common.GoogleApiAvailability
//////import com.google.android.gms.security.ProviderInstaller
//////import io.flutter.embedding.android.FlutterFragmentActivity
//////import io.flutter.embedding.engine.FlutterEngine
//////import io.flutter.plugin.common.MethodChannel
//////
//////class MainActivity : FlutterFragmentActivity(), ProviderInstaller.ProviderInstallListener {
//////
//////    private val LOCATION_CHANNEL   = "com.metaxperts.order_booking_app/location_monitor"
//////    private val SYNC_ALARM_CHANNEL = "com.metaxperts.order_booking_app/sync_alarm"
//////
//////    override fun onCreate(savedInstanceState: Bundle?) {
//////        super.onCreate(savedInstanceState)
//////        ProviderInstaller.installIfNeededAsync(this, this)
//////    }
//////
//////    override fun onProviderInstalled() {}
//////
//////    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
//////        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
//////    }
//////
//////    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
//////        super.configureFlutterEngine(flutterEngine)
//////
//////        // ── 1. Existing location monitor channel ──────────────────────────
//////        MethodChannel(
//////            flutterEngine.dartExecutor.binaryMessenger,
//////            LOCATION_CHANNEL
//////        ).setMethodCallHandler { call, result ->
//////            when (call.method) {
//////
//////                "startMonitoring" -> {
//////                    try {
//////                        val userId      = call.argument<String>("userId")      ?: ""
//////                        val bookerName  = call.argument<String>("bookerName")  ?: ""
//////                        val designation = call.argument<String>("designation") ?: ""
//////                        val companyCode = call.argument<String>("companyCode") ?: ""
//////
//////                        LocationMonitorService.start(
//////                            context     = this,
//////                            userId      = userId,
//////                            bookerName  = bookerName,
//////                            designation = designation,
//////                            companyCode = companyCode
//////                        )
//////                        result.success(null)
//////                    } catch (e: Exception) {
//////                        result.error("START_FAILED", e.message, null)
//////                    }
//////                }
//////
//////                "stopMonitoring" -> {
//////                    try {
//////                        LocationMonitorService.stop(this)
//////                        result.success(null)
//////                    } catch (e: Exception) {
//////                        result.error("STOP_FAILED", e.message, null)
//////                    }
//////                }
//////
//////                "requestBatteryOptimization" -> {
//////                    try {
//////                        val pm = getSystemService(POWER_SERVICE) as PowerManager
//////                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
//////                            val intent = Intent(
//////                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
//////                            ).apply {
//////                                data = Uri.parse("package:$packageName")
//////                            }
//////                            startActivity(intent)
//////                        }
//////                        result.success(null)
//////                    } catch (e: Exception) {
//////                        result.success(null)
//////                    }
//////                }
//////
//////                else -> result.notImplemented()
//////            }
//////        }
//////
//////        // ── 2. Existing sync alarm channel (15-minute reminder) ───────────
//////        MethodChannel(
//////            flutterEngine.dartExecutor.binaryMessenger,
//////            SYNC_ALARM_CHANNEL
//////        ).setMethodCallHandler { call, result ->
//////            when (call.method) {
//////
//////                "startAlarm" -> {
//////                    try {
//////                        SyncAlarmReceiver.startAlarm(this)
//////                        result.success(null)
//////                    } catch (e: Exception) {
//////                        result.error("ALARM_START_FAILED", e.message, null)
//////                    }
//////                }
//////
//////                "stopAlarm" -> {
//////                    try {
//////                        SyncAlarmReceiver.stopAlarm(this)
//////                        result.success(null)
//////                    } catch (e: Exception) {
//////                        result.error("ALARM_STOP_FAILED", e.message, null)
//////                    }
//////                }
//////
//////                else -> result.notImplemented()
//////            }
//////        }
//////    }
//////}
////
////
///////new
//////////
//////////package com.metaxperts.order_booking_app
//////////
//////////import android.content.Intent
//////////import android.net.Uri
//////////import android.os.Bundle
//////////import android.os.PowerManager
//////////import android.provider.Settings
//////////import com.google.android.gms.common.GoogleApiAvailability
//////////import com.google.android.gms.security.ProviderInstaller
//////////import io.flutter.embedding.android.FlutterFragmentActivity
//////////import io.flutter.embedding.engine.FlutterEngine
//////////import io.flutter.plugin.common.MethodChannel
//////////
//////////class MainActivity : FlutterFragmentActivity(), ProviderInstaller.ProviderInstallListener {
//////////
//////////    // Must match the channel name used in Dart (mqtt_work.dart + timer_card.dart)
//////////    private val LOCATION_CHANNEL = "com.metaxperts.order_booking_app/location_monitor"
//////////
//////////    override fun onCreate(savedInstanceState: Bundle?) {
//////////        super.onCreate(savedInstanceState)
//////////        // Update Android security provider — required for TLS on older devices
//////////        ProviderInstaller.installIfNeededAsync(this, this)
//////////    }
//////////
//////////    override fun onProviderInstalled() {}
//////////
//////////    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
//////////        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
//////////    }
//////////
//////////    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
//////////        super.configureFlutterEngine(flutterEngine)
//////////
//////////        MethodChannel(
//////////            flutterEngine.dartExecutor.binaryMessenger,
//////////            LOCATION_CHANNEL
//////////        ).setMethodCallHandler { call, result ->
//////////            when (call.method) {
//////////
//////////                "startMonitoring" -> {
//////////                    try {
//////////                        val userId      = call.argument<String>("userId")      ?: ""
//////////                        val bookerName  = call.argument<String>("bookerName")  ?: ""
//////////                        val designation = call.argument<String>("designation") ?: ""
//////////                        val companyCode = call.argument<String>("companyCode") ?: ""
//////////
//////////                        LocationMonitorService.start(
//////////                            context     = this,
//////////                            userId      = userId,
//////////                            bookerName  = bookerName,
//////////                            designation = designation,
//////////                            companyCode = companyCode
//////////                        )
//////////                        result.success(null)
//////////                    } catch (e: Exception) {
//////////                        result.error("START_FAILED", e.message, null)
//////////                    }
//////////                }
//////////
//////////                "stopMonitoring" -> {
//////////                    try {
//////////                        LocationMonitorService.stop(this)
//////////                        result.success(null)
//////////                    } catch (e: Exception) {
//////////                        result.error("STOP_FAILED", e.message, null)
//////////                    }
//////////                }
//////////
//////////                "requestBatteryOptimization" -> {
//////////                    try {
//////////                        val pm = getSystemService(POWER_SERVICE) as PowerManager
//////////                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
//////////                            val intent = Intent(
//////////                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
//////////                            ).apply {
//////////                                data = Uri.parse("package:$packageName")
//////////                            }
//////////                            startActivity(intent)
//////////                        }
//////////                        result.success(null)
//////////                    } catch (e: Exception) {
//////////                        result.success(null) // non-fatal
//////////                    }
//////////                }
//////////
//////////                else -> result.notImplemented()
//////////            }
//////////        }
//////////    }
//////////}
////////
////////package com.metaxperts.order_booking_app
////////
////////// ══════════════════════════════════════════════════════════════════════════════
////////// MainActivity.kt — Updated version
////////// Sirf sync_alarm MethodChannel add kiya gaya hai — baqi sab same hai
////////// ══════════════════════════════════════════════════════════════════════════════
////////
////////import android.content.Intent
////////import android.net.Uri
////////import android.os.Bundle
////////import android.os.PowerManager
////////import android.provider.Settings
////////import com.google.android.gms.common.GoogleApiAvailability
////////import com.google.android.gms.security.ProviderInstaller
////////import io.flutter.embedding.android.FlutterFragmentActivity
////////import io.flutter.embedding.engine.FlutterEngine
////////import io.flutter.plugin.common.MethodChannel
////////
////////class MainActivity : FlutterFragmentActivity(), ProviderInstaller.ProviderInstallListener {
////////
////////    private val LOCATION_CHANNEL  = "com.metaxperts.order_booking_app/location_monitor"
////////    // ✅ NEW: Sync alarm channel
////////    private val SYNC_ALARM_CHANNEL = "com.metaxperts.order_booking_app/sync_alarm"
////////
////////    override fun onCreate(savedInstanceState: Bundle?) {
////////        super.onCreate(savedInstanceState)
////////        ProviderInstaller.installIfNeededAsync(this, this)
////////    }
////////
////////    override fun onProviderInstalled() {}
////////
////////    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
////////        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
////////    }
////////
////////    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
////////        super.configureFlutterEngine(flutterEngine)
////////
////////        // ── Existing location monitor channel ─────────────────────────────
////////        MethodChannel(
////////            flutterEngine.dartExecutor.binaryMessenger,
////////            LOCATION_CHANNEL
////////        ).setMethodCallHandler { call, result ->
////////            when (call.method) {
////////
////////                "startMonitoring" -> {
////////                    try {
////////                        val userId      = call.argument<String>("userId")      ?: ""
////////                        val bookerName  = call.argument<String>("bookerName")  ?: ""
////////                        val designation = call.argument<String>("designation") ?: ""
////////                        val companyCode = call.argument<String>("companyCode") ?: ""
////////
////////                        LocationMonitorService.start(
////////                            context     = this,
////////                            userId      = userId,
////////                            bookerName  = bookerName,
////////                            designation = designation,
////////                            companyCode = companyCode
////////                        )
////////                        result.success(null)
////////                    } catch (e: Exception) {
////////                        result.error("START_FAILED", e.message, null)
////////                    }
////////                }
////////
////////                "stopMonitoring" -> {
////////                    try {
////////                        LocationMonitorService.stop(this)
////////                        result.success(null)
////////                    } catch (e: Exception) {
////////                        result.error("STOP_FAILED", e.message, null)
////////                    }
////////                }
////////
////////                "requestBatteryOptimization" -> {
////////                    try {
////////                        val pm = getSystemService(POWER_SERVICE) as PowerManager
////////                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
////////                            val intent = Intent(
////////                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
////////                            ).apply {
////////                                data = Uri.parse("package:$packageName")
////////                            }
////////                            startActivity(intent)
////////                        }
////////                        result.success(null)
////////                    } catch (e: Exception) {
////////                        result.success(null)
////////                    }
////////                }
////////
////////                else -> result.notImplemented()
////////            }
////////        }
////////
////////        // ✅ NEW: Sync alarm channel — Flutter se alarm start/stop karne ke liye
////////        MethodChannel(
////////            flutterEngine.dartExecutor.binaryMessenger,
////////            SYNC_ALARM_CHANNEL
////////        ).setMethodCallHandler { call, result ->
////////            when (call.method) {
////////
////////                "startAlarm" -> {
////////                    try {
////////                        SyncAlarmReceiver.startAlarm(this)
////////                        result.success(null)
////////                    } catch (e: Exception) {
////////                        result.error("ALARM_START_FAILED", e.message, null)
////////                    }
////////                }
////////
////////                "stopAlarm" -> {
////////                    try {
////////                        SyncAlarmReceiver.stopAlarm(this)
////////                        result.success(null)
////////                    } catch (e: Exception) {
////////                        result.error("ALARM_STOP_FAILED", e.message, null)
////////                    }
////////                }
////////
////////                else -> result.notImplemented()
////////            }
////////        }
////////    }
////////}
//////
//////
/////////8pm alaram
//////package com.metaxperts.order_booking_app
//////
//////// ══════════════════════════════════════════════════════════════════════════════
//////// MainActivity.kt — Updated with Clockout Alarm Channel
//////// Existing code same hai — sirf ek naya MethodChannel add kiya gaya hai
//////// ══════════════════════════════════════════════════════════════════════════════
//////
//////import android.content.Intent
//////import android.net.Uri
//////import android.os.Bundle
//////import android.os.PowerManager
//////import android.provider.Settings
//////import com.google.android.gms.common.GoogleApiAvailability
//////import com.google.android.gms.security.ProviderInstaller
//////import io.flutter.embedding.android.FlutterFragmentActivity
//////import io.flutter.embedding.engine.FlutterEngine
//////import io.flutter.plugin.common.MethodChannel
//////
//////class MainActivity : FlutterFragmentActivity(), ProviderInstaller.ProviderInstallListener {
//////
//////    private val LOCATION_CHANNEL      = "com.metaxperts.order_booking_app/location_monitor"
//////    private val SYNC_ALARM_CHANNEL    = "com.metaxperts.order_booking_app/sync_alarm"
//////    // ✅ NEW: Clockout 8PM alarm channel
//////    private val CLOCKOUT_ALARM_CHANNEL = "com.metaxperts.order_booking_app/clockout_alarm"
//////
//////    override fun onCreate(savedInstanceState: Bundle?) {
//////        super.onCreate(savedInstanceState)
//////        ProviderInstaller.installIfNeededAsync(this, this)
//////    }
//////
//////    override fun onProviderInstalled() {}
//////
//////    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
//////        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
//////    }
//////
//////    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
//////        super.configureFlutterEngine(flutterEngine)
//////
//////        // ── 1. Existing location monitor channel ──────────────────────────
//////        MethodChannel(
//////            flutterEngine.dartExecutor.binaryMessenger,
//////            LOCATION_CHANNEL
//////        ).setMethodCallHandler { call, result ->
//////            when (call.method) {
//////
//////                "startMonitoring" -> {
//////                    try {
//////                        val userId      = call.argument<String>("userId")      ?: ""
//////                        val bookerName  = call.argument<String>("bookerName")  ?: ""
//////                        val designation = call.argument<String>("designation") ?: ""
//////                        val companyCode = call.argument<String>("companyCode") ?: ""
//////
//////                        LocationMonitorService.start(
//////                            context     = this,
//////                            userId      = userId,
//////                            bookerName  = bookerName,
//////                            designation = designation,
//////                            companyCode = companyCode
//////                        )
//////                        result.success(null)
//////                    } catch (e: Exception) {
//////                        result.error("START_FAILED", e.message, null)
//////                    }
//////                }
//////
//////                "stopMonitoring" -> {
//////                    try {
//////                        LocationMonitorService.stop(this)
//////                        result.success(null)
//////                    } catch (e: Exception) {
//////                        result.error("STOP_FAILED", e.message, null)
//////                    }
//////                }
//////
//////                "requestBatteryOptimization" -> {
//////                    try {
//////                        val pm = getSystemService(POWER_SERVICE) as PowerManager
//////                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
//////                            val intent = Intent(
//////                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
//////                            ).apply {
//////                                data = Uri.parse("package:$packageName")
//////                            }
//////                            startActivity(intent)
//////                        }
//////                        result.success(null)
//////                    } catch (e: Exception) {
//////                        result.success(null)
//////                    }
//////                }
//////
//////                else -> result.notImplemented()
//////            }
//////        }
//////
//////        // ── 2. Existing sync alarm channel (15-minute reminder) ───────────
//////        MethodChannel(
//////            flutterEngine.dartExecutor.binaryMessenger,
//////            SYNC_ALARM_CHANNEL
//////        ).setMethodCallHandler { call, result ->
//////            when (call.method) {
//////
//////                "startAlarm" -> {
//////                    try {
//////                        SyncAlarmReceiver.startAlarm(this)
//////                        result.success(null)
//////                    } catch (e: Exception) {
//////                        result.error("ALARM_START_FAILED", e.message, null)
//////                    }
//////                }
//////
//////                "stopAlarm" -> {
//////                    try {
//////                        SyncAlarmReceiver.stopAlarm(this)
//////                        result.success(null)
//////                    } catch (e: Exception) {
//////                        result.error("ALARM_STOP_FAILED", e.message, null)
//////                    }
//////                }
//////
//////                else -> result.notImplemented()
//////            }
//////        }
//////
//////        // ── 3. ✅ NEW: Clockout 8PM alarm channel ─────────────────────────
//////        MethodChannel(
//////            flutterEngine.dartExecutor.binaryMessenger,
//////            CLOCKOUT_ALARM_CHANNEL
//////        ).setMethodCallHandler { call, result ->
//////            when (call.method) {
//////
//////                // Flutter clock-in kare → 8PM alarm schedule karo
//////                "schedule8PMAlarm" -> {
//////                    try {
//////                        ClockoutAlarmReceiver.scheduleDaily8PMAlarm(this)
//////                        result.success(null)
//////                    } catch (e: Exception) {
//////                        result.error("CLOCKOUT_ALARM_FAILED", e.message, null)
//////                    }
//////                }
//////
//////                // Flutter clock-out kare ya manually stop kare → sab band karo
//////                "stopEverything" -> {
//////                    try {
//////                        ClockoutAlarmReceiver.stopEverything(this)
//////                        result.success(null)
//////                    } catch (e: Exception) {
//////                        result.error("CLOCKOUT_STOP_FAILED", e.message, null)
//////                    }
//////                }
//////
//////                // Abhi se ringtone shuru karo (8PM guzar gayi, app open hua)
//////                "startRingtoneNow" -> {
//////                    try {
//////                        ClockoutAlarmReceiver.startRingtoneService(this)
//////                        result.success(null)
//////                    } catch (e: Exception) {
//////                        result.error("RINGTONE_START_FAILED", e.message, null)
//////                    }
//////                }
//////
//////                // Alarm band karo lekin ringtone nahi (agar sirf alarm reschedule chahiye)
//////                "cancelAlarmOnly" -> {
//////                    try {
//////                        ClockoutAlarmReceiver.cancelAlarm(this)
//////                        result.success(null)
//////                    } catch (e: Exception) {
//////                        result.error("CANCEL_ALARM_FAILED", e.message, null)
//////                    }
//////                }
//////
//////                else -> result.notImplemented()
//////            }
//////        }
//////    }
//////}
////
////
////package com.metaxperts.order_booking_app
////
////import android.content.Intent
////import android.net.Uri
////import android.os.Bundle
////import android.os.PowerManager
////import android.provider.Settings
////import com.google.android.gms.common.GoogleApiAvailability
////import com.google.android.gms.security.ProviderInstaller
////import io.flutter.embedding.android.FlutterFragmentActivity
////import io.flutter.embedding.engine.FlutterEngine
////import io.flutter.plugin.common.MethodChannel
////
////class MainActivity : FlutterFragmentActivity(), ProviderInstaller.ProviderInstallListener {
////
////    private val LOCATION_CHANNEL   = "com.metaxperts.order_booking_app/location_monitor"
////    private val SYNC_ALARM_CHANNEL = "com.metaxperts.order_booking_app/sync_alarm"
////
////    override fun onCreate(savedInstanceState: Bundle?) {
////        super.onCreate(savedInstanceState)
////        ProviderInstaller.installIfNeededAsync(this, this)
////
////        // ✅ FIX: App open hote hi battery optimization check karo
////        // Purane weak devices pe yeh sab se important step hai service ko alive rakhne ke liye
////        requestBatteryOptimizationIfNeeded()
////    }
////
////    private fun requestBatteryOptimizationIfNeeded() {
////        try {
////            val pm = getSystemService(POWER_SERVICE) as PowerManager
////            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
////                val intent = Intent(
////                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
////                ).apply {
////                    data = Uri.parse("package:$packageName")
////                }
////                startActivity(intent)
////            }
////        } catch (e: Exception) {
////            // Kuch devices pe yeh setting available nahi hoti — ignore karo
////        }
////    }
////
////    override fun onProviderInstalled() {}
////
////    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
////        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
////    }
////
////    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
////        super.configureFlutterEngine(flutterEngine)
////
////        // ── 1. Existing location monitor channel ──────────────────────────
////        MethodChannel(
////            flutterEngine.dartExecutor.binaryMessenger,
////            LOCATION_CHANNEL
////        ).setMethodCallHandler { call, result ->
////            when (call.method) {
////
////                "startMonitoring" -> {
////                    try {
////                        val userId      = call.argument<String>("userId")      ?: ""
////                        val bookerName  = call.argument<String>("bookerName")  ?: ""
////                        val designation = call.argument<String>("designation") ?: ""
////                        val companyCode = call.argument<String>("companyCode") ?: ""
////
////                        LocationMonitorService.start(
////                            context     = this,
////                            userId      = userId,
////                            bookerName  = bookerName,
////                            designation = designation,
////                            companyCode = companyCode
////                        )
////                        result.success(null)
////                    } catch (e: Exception) {
////                        result.error("START_FAILED", e.message, null)
////                    }
////                }
////
////                "stopMonitoring" -> {
////                    try {
////                        LocationMonitorService.stop(this)
////                        result.success(null)
////                    } catch (e: Exception) {
////                        result.error("STOP_FAILED", e.message, null)
////                    }
////                }
////
////                "requestBatteryOptimization" -> {
////                    try {
////                        val pm = getSystemService(POWER_SERVICE) as PowerManager
////                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
////                            val intent = Intent(
////                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
////                            ).apply {
////                                data = Uri.parse("package:$packageName")
////                            }
////                            startActivity(intent)
////                        }
////                        result.success(null)
////                    } catch (e: Exception) {
////                        result.success(null)
////                    }
////                }
////
////                else -> result.notImplemented()
////            }
////        }
////
////        // ── 2. Existing sync alarm channel (15-minute reminder) ───────────
////        MethodChannel(
////            flutterEngine.dartExecutor.binaryMessenger,
////            SYNC_ALARM_CHANNEL
////        ).setMethodCallHandler { call, result ->
////            when (call.method) {
////
////                "startAlarm" -> {
////                    try {
////                        SyncAlarmReceiver.startAlarm(this)
////                        result.success(null)
////                    } catch (e: Exception) {
////                        result.error("ALARM_START_FAILED", e.message, null)
////                    }
////                }
////
////                "stopAlarm" -> {
////                    try {
////                        SyncAlarmReceiver.stopAlarm(this)
////                        result.success(null)
////                    } catch (e: Exception) {
////                        result.error("ALARM_STOP_FAILED", e.message, null)
////                    }
////                }
////
////                else -> result.notImplemented()
////            }
////        }
////    }
////}
//
//package com.metaxperts.order_booking_app
//
//import android.content.Intent
//import android.net.Uri
//import android.os.Bundle
//import android.os.PowerManager
//import android.provider.Settings
//import com.google.android.gms.common.GoogleApiAvailability
//import com.google.android.gms.security.ProviderInstaller
//import io.flutter.embedding.android.FlutterFragmentActivity
//import io.flutter.embedding.engine.FlutterEngine
//import io.flutter.plugin.common.MethodChannel
//
//class MainActivity : FlutterFragmentActivity(), ProviderInstaller.ProviderInstallListener {
//
//    private val LOCATION_CHANNEL   = "com.metaxperts.order_booking_app/location_monitor"
//    private val SYNC_ALARM_CHANNEL = "com.metaxperts.order_booking_app/sync_alarm"
//    private val BUBBLE_CHANNEL = "com.metaxperts.order_booking_app/floating_bubble"
//
//    private var bubbleServiceStarted = false
//
//    override fun onCreate(savedInstanceState: Bundle?) {
//        super.onCreate(savedInstanceState)
//        ProviderInstaller.installIfNeededAsync(this, this)
//        requestBatteryOptimizationIfNeeded()
//    }
//
//    private fun requestBatteryOptimizationIfNeeded() {
//        try {
//            val pm = getSystemService(POWER_SERVICE) as PowerManager
//            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
//                val intent = Intent(
//                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
//                ).apply {
//                    data = Uri.parse("package:$packageName")
//                }
//                startActivity(intent)
//            }
//        } catch (e: Exception) {
//            // ignore
//        }
//    }
//
//    private fun showFloatingBubble() {
//        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
//            val intent = Intent(
//                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
//                Uri.parse("package:$packageName")
//            )
//            startActivity(intent)
//            return
//        }
//
//        if (!FloatingBubbleService.isRunning()) {
//            FloatingBubbleService.start(this)
//            bubbleServiceStarted = true
//        } else {
//            sendBroadcast(Intent("com.metaxperts.SHOW_BUBBLE"))
//        }
//    }
//
//    private fun hideFloatingBubble() {
//        if (bubbleServiceStarted) {
//            sendBroadcast(Intent("com.metaxperts.HIDE_BUBBLE"))
//        }
//    }
//
//    // ✅ NEW: Close bubble completely on clockout
//    private fun closeFloatingBubble() {
//        try {
//            sendBroadcast(Intent("com.metaxperts.CLOSE_BUBBLE"))
//            bubbleServiceStarted = false
//            android.util.Log.d("MainActivity", "✅ Bubble close broadcast sent")
//        } catch (e: Exception) {
//            android.util.Log.e("MainActivity", "Error closing bubble: ${e.message}")
//        }
//    }
//
//    override fun onPause() {
//        super.onPause()
//        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
//        val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
//        if (isClockedIn) {
//            showFloatingBubble()
//        }
//    }
//
//    override fun onResume() {
//        super.onResume()
//        hideFloatingBubble()
//    }
//
//    override fun onProviderInstalled() {}
//
//    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
//        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
//    }
//
//    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
//        super.configureFlutterEngine(flutterEngine)
//
//        // ── 1. Location monitor channel ──────────────────────────
//        MethodChannel(
//            flutterEngine.dartExecutor.binaryMessenger,
//            LOCATION_CHANNEL
//        ).setMethodCallHandler { call, result ->
//            when (call.method) {
//                "startMonitoring" -> {
//                    try {
//                        val userId = call.argument<String>("userId") ?: ""
//                        val bookerName = call.argument<String>("bookerName") ?: ""
//                        val designation = call.argument<String>("designation") ?: ""
//                        val companyCode = call.argument<String>("companyCode") ?: ""
//
//                        LocationMonitorService.start(
//                            context = this,
//                            userId = userId,
//                            bookerName = bookerName,
//                            designation = designation,
//                            companyCode = companyCode
//                        )
//                        result.success(null)
//                    } catch (e: Exception) {
//                        result.error("START_FAILED", e.message, null)
//                    }
//                }
//                "stopMonitoring" -> {
//                    try {
//                        LocationMonitorService.stop(this)
//                        result.success(null)
//                    } catch (e: Exception) {
//                        result.error("STOP_FAILED", e.message, null)
//                    }
//                }
//                "requestBatteryOptimization" -> {
//                    try {
//                        val pm = getSystemService(POWER_SERVICE) as PowerManager
//                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
//                            val intent = Intent(
//                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
//                            ).apply {
//                                data = Uri.parse("package:$packageName")
//                            }
//                            startActivity(intent)
//                        }
//                        result.success(null)
//                    } catch (e: Exception) {
//                        result.success(null)
//                    }
//                }
//                else -> result.notImplemented()
//            }
//        }
//
//        // ── 2. Sync alarm channel ───────────────────────────
//        MethodChannel(
//            flutterEngine.dartExecutor.binaryMessenger,
//            SYNC_ALARM_CHANNEL
//        ).setMethodCallHandler { call, result ->
//            when (call.method) {
//                "startAlarm" -> {
//                    try {
//                        SyncAlarmReceiver.startAlarm(this)
//                        result.success(null)
//                    } catch (e: Exception) {
//                        result.error("ALARM_START_FAILED", e.message, null)
//                    }
//                }
//                "stopAlarm" -> {
//                    try {
//                        SyncAlarmReceiver.stopAlarm(this)
//                        result.success(null)
//                    } catch (e: Exception) {
//                        result.error("ALARM_STOP_FAILED", e.message, null)
//                    }
//                }
//                else -> result.notImplemented()
//            }
//        }
//
//        // ── 3. Floating bubble channel ──────────────────────────
//        MethodChannel(
//            flutterEngine.dartExecutor.binaryMessenger,
//            BUBBLE_CHANNEL
//        ).setMethodCallHandler { call, result ->
//            when (call.method) {
//                "showBubble" -> {
//                    showFloatingBubble()
//                    result.success(true)
//                }
//                "hideBubble" -> {
//                    hideFloatingBubble()
//                    result.success(true)
//                }
//                "isBubbleVisible" -> {
//                    result.success(FloatingBubbleService.isRunning())
//                }
//                "closeBubble" -> {
//                    closeFloatingBubble()
//                    result.success(true)
//                }
//                else -> result.notImplemented()
//            }
//        }
//    }
//}



package com.metaxperts.order_booking_app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.security.ProviderInstaller
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity(), ProviderInstaller.ProviderInstallListener {

    private val LOCATION_CHANNEL   = "com.metaxperts.order_booking_app/location_monitor"
    private val SYNC_ALARM_CHANNEL = "com.metaxperts.order_booking_app/sync_alarm"
    private val BUBBLE_CHANNEL = "com.metaxperts.order_booking_app/floating_bubble"

    private var bubbleServiceStarted = false
    private val OVERLAY_PERMISSION_REQUEST_CODE = 1001

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ProviderInstaller.installIfNeededAsync(this, this)
        requestBatteryOptimizationIfNeeded()
    }

    private fun requestBatteryOptimizationIfNeeded() {
        try {
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                ).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            }
        } catch (e: Exception) {
            // ignore
        }
    }

    private fun showFloatingBubble() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            // ✅ FIX: startActivityForResult use karo taake wapas app par aa sakein
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
            return
        }

        if (!FloatingBubbleService.isRunning()) {
            FloatingBubbleService.start(this)
            bubbleServiceStarted = true
        } else {
            sendBroadcast(Intent("com.metaxperts.SHOW_BUBBLE"))
        }
    }

    // ✅ FIX: Permission screen se wapas aane par automatically app open ho
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OVERLAY_PERMISSION_REQUEST_CODE) {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M
                && Settings.canDrawOverlays(this)
            ) {
                // Permission mil gayi — bubble start karo
                if (!FloatingBubbleService.isRunning()) {
                    FloatingBubbleService.start(this)
                    bubbleServiceStarted = true
                }
            }
            // App ko foreground mein lao (settings stack se nikaalo)
            val bring = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            startActivity(bring)
        }
    }

    private fun hideFloatingBubble() {
        if (bubbleServiceStarted) {
            sendBroadcast(Intent("com.metaxperts.HIDE_BUBBLE"))
        }
    }

    // ✅ NEW: Close bubble completely on clockout
    private fun closeFloatingBubble() {
        try {
            sendBroadcast(Intent("com.metaxperts.CLOSE_BUBBLE"))
            bubbleServiceStarted = false
            android.util.Log.d("MainActivity", "✅ Bubble close broadcast sent")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error closing bubble: ${e.message}")
        }
    }

    override fun onPause() {
        super.onPause()
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
        if (isClockedIn) {
            showFloatingBubble()
        }
    }

    override fun onResume() {
        super.onResume()
        hideFloatingBubble()
    }

    override fun onProviderInstalled() {}

    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── 1. Location monitor channel ──────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LOCATION_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startMonitoring" -> {
                    try {
                        val userId = call.argument<String>("userId") ?: ""
                        val bookerName = call.argument<String>("bookerName") ?: ""
                        val designation = call.argument<String>("designation") ?: ""
                        val companyCode = call.argument<String>("companyCode") ?: ""

                        LocationMonitorService.start(
                            context = this,
                            userId = userId,
                            bookerName = bookerName,
                            designation = designation,
                            companyCode = companyCode
                        )
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("START_FAILED", e.message, null)
                    }
                }
                "stopMonitoring" -> {
                    try {
                        LocationMonitorService.stop(this)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("STOP_FAILED", e.message, null)
                    }
                }
                "requestBatteryOptimization" -> {
                    try {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                            val intent = Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                            ).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ── 2. Sync alarm channel ───────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SYNC_ALARM_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAlarm" -> {
                    try {
                        SyncAlarmReceiver.startAlarm(this)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ALARM_START_FAILED", e.message, null)
                    }
                }
                "stopAlarm" -> {
                    try {
                        SyncAlarmReceiver.stopAlarm(this)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ALARM_STOP_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ── 3. Floating bubble channel ──────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BUBBLE_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "showBubble" -> {
                    showFloatingBubble()
                    result.success(true)
                }
                "hideBubble" -> {
                    hideFloatingBubble()
                    result.success(true)
                }
                "isBubbleVisible" -> {
                    result.success(FloatingBubbleService.isRunning())
                }
                "closeBubble" -> {
                    closeFloatingBubble()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}