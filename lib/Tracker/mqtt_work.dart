

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  MqttTracker  —  thin Dart coordinator
//
//  All GPS collection and MQTT publishing live inside LocationMonitorService.kt
//  (Kotlin foreground service).  This class just starts/stops that service via
//  MethodChannel and persists the user identity so the service can recover it
//  after being restarted by the OS or after a device reboot.
//
//  Channel: com.metaxperts.order_booking_app/location_monitor
//  Methods: startMonitoring({ userId, bookerName, designation, companyCode })
//           stopMonitoring()
//           requestBatteryOptimization()
// ══════════════════════════════════════════════════════════════════════════════

const String _mqttHost    = '119.153.102.7';
const int    _mqttPort    = 1883;
const String _companyCode = 'PK-PUN-SKT-MX01-VT001';

const _locationChannel =
MethodChannel('com.metaxperts.order_booking_app/location_monitor');

class MqttTracker {
  // Singleton
  static final MqttTracker _instance = MqttTracker._internal();
  factory MqttTracker() => _instance;
  MqttTracker._internal();

  // ── User identity ──────────────────────────────────────────────────────────
  String _userId      = '';
  String _bookerName  = '';
  String _designation = '';

  String get userId      => _userId;
  String get bookerName  => _bookerName;
  String get designation => _designation;

  // ── Status (Kotlin service owns real state; this mirrors clock-in flag) ────
  bool _clockedIn = false;
  bool get isMqttConnected => _clockedIn;

  // ── Initialize — call once from TimerCard.initState() ─────────────────────
  Future<void> initialize() async {
    debugPrint('🚀 [MqttTracker] initialize()');
    await _loadIdentityFromPrefs();
    debugPrint('🚀 [MqttTracker] ready | userId=$_userId');
  }

  Future<void> _loadIdentityFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ FIX: SharedPreferences on Android stores keys WITHOUT the 'flutter.'
      // prefix when written from Dart (the prefix is added internally by the
      // plugin on some platforms but stripped on read).  The original code tried
      // 'flutter.userId' first — this key never exists when read from Dart,
      // causing _userId to always be '' in release builds where debugPrint is
      // suppressed and the bug is invisible.
      //
      // Correct priority order (plain keys first, prefixed as last fallback):
      _userId = prefs.getString('user_id')
          ?? prefs.getString('userId')
          ?? prefs.getString('flutter.userId')   // kept as last-resort fallback
          ?? '';

      _bookerName = prefs.getString('booker_name')
          ?? prefs.getString('userName')
          ?? prefs.getString('emp_name')
          ?? prefs.getString('flutter.userName')
          ?? '';

      _designation = prefs.getString('designation')
          ?? prefs.getString('userDesignation')
          ?? prefs.getString('flutter.userDesignation')
          ?? '';

      debugPrint('📋 [MqttTracker] Loaded: userId=$_userId | name=$_bookerName | desg=$_designation');
    } catch (e) {
      debugPrint('❌ [MqttTracker] prefs load error: $e');
    }
  }

  // ── Clock In — starts Kotlin foreground service (GPS + MQTT) ──────────────
  Future<bool> clockInMqtt({
    required String userId,
    required String bookerName,
    String designation = '',
    String companyCode = _companyCode,
  }) async {
    debugPrint('🟢 [ClockIn] userId=$userId booker=$bookerName');

    // ✅ FIX: If caller passes empty strings (because prefs read failed before
    // login saved them), fall back to whatever _loadIdentityFromPrefs found.
    // Empty userId → Kotlin service publishes to topic "null" or "" which the
    // broker silently drops — this is the #1 silent failure in release builds.
    if (userId.isEmpty) {
      debugPrint('⚠️ [ClockIn] userId empty — reloading from prefs');
      await _loadIdentityFromPrefs();
      userId      = _userId;
      bookerName  = _bookerName.isNotEmpty ? _bookerName : bookerName;
      designation = _designation.isNotEmpty ? _designation : designation;
    }

    _userId      = userId;
    _bookerName  = bookerName;
    _designation = designation;

    // Persist identity — Kotlin service reads these on OS-restart and reboot.
    // ✅ FIX: Write BOTH plain keys (read by Dart) AND flutter-prefixed keys
    // (read by Kotlin via getSharedPreferences in some plugin versions).
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id',                 userId);
    await prefs.setString('booker_name',             bookerName);
    await prefs.setString('designation',             designation);
    await prefs.setString('flutter.userId',          userId);
    await prefs.setString('flutter.userName',        bookerName);
    await prefs.setString('flutter.userDesignation', designation);
    await prefs.setString('flutter.companyCode',     companyCode);
    await prefs.setBool('flutter.isClockedIn',       true);
    await prefs.setInt('flutter.clockInTimeMs',      DateTime.now().millisecondsSinceEpoch);

    // Request battery-optimisation exemption (silently skips if already granted)
    try {
      await _locationChannel.invokeMethod('requestBatteryOptimization');
      debugPrint('✅ [ClockIn] Battery optimisation exemption requested');
    } catch (e) {
      debugPrint('⚠️ [ClockIn] Battery opt request skipped: $e');
    }

    // Start the Kotlin foreground service
    try {
      await _locationChannel.invokeMethod('startMonitoring', {
        'userId':      userId,
        'bookerName':  bookerName,
        'designation': designation,
        'companyCode': companyCode,
      });
      _clockedIn = true;
      debugPrint('✅ [ClockIn] Kotlin service started — MQTT publishing every 5s');
      return true;
    } catch (e) {
      debugPrint('❌ [ClockIn] startMonitoring failed: $e');
      // ✅ FIX: In release, a PlatformException here often means the
      // MethodChannel handler was stripped by R8.  Check proguard-rules.pro.
      // The error message will contain "No implementation found" or similar.
      return false;
    }
  }

  // ── Clock Out — stops Kotlin foreground service ────────────────────────────
  Future<void> clockOutMqtt() async {
    debugPrint('🔴 [ClockOut] Stopping live tracking & MQTT');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('flutter.isClockedIn', false);
    await prefs.remove('flutter.clockInTimeMs');

    try {
      await _locationChannel.invokeMethod('stopMonitoring');
      debugPrint('✅ [ClockOut] Kotlin service stopped');
    } catch (e) {
      debugPrint('⚠️ [ClockOut] stopMonitoring error: $e');
    }

    _clockedIn = false;
    debugPrint('✅ [ClockOut] Complete');
  }

  // ── Dispose (only if you explicitly want to stop on widget dispose) ─────────
  Future<void> dispose() async {
    debugPrint('🧹 [Dispose] MqttTracker');
    if (_clockedIn) await clockOutMqtt();
  }
}