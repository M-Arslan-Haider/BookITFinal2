// ============================================================
// location_log_service.dart
//
// Har 2 minute baad user ki lat/lng server pe POST karta hai
// jab tak user clocked-in ho — foreground, background, aur
// app kill hone ke baad bhi (LocationMonitorService.kt restart
// karta hai service ko onTaskRemoved mein).
//
// Table columns (server):
//   ID, USER_ID, BOOKER_NAME, DESIGNATION,
//   LAT_IN, LNG_IN, BATTERY_PERCENT, ADDRESS,
//   POSTED, CREATED_AT
//
// API: POST https://cloud.metaxperts.net:8443/erp/valor_trading/locationlogpost/post/
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --------------- SharedPreferences Keys ---------------
// ⚠️ timer_card.dart mein prefs.setBool('isClockedIn', true) use hota hai
// isliye 'flutter.' prefix NAHI lagana — warna service socha clocked-out hai
const String _kIsClockedIn   = 'isClockedIn';
const String _kUserId        = 'userId';
const String _kBookerName    = 'userName';
const String _kDesignation   = 'userDesignation';

// --------------- API endpoint ---------------
const String _kApiUrl =
    'https://cloud.metaxperts.net:8443/erp/valor_trading/locationlogpost/post/';

// --------------- MethodChannel (same as MainActivity.kt) ---------------
const _channel =
MethodChannel('com.metaxperts.order_booking_app/location_monitor');

// ================================================================
// LocationLogService
// ================================================================
class LocationLogService {
  // Singleton
  LocationLogService._internal();
  static final LocationLogService instance = LocationLogService._internal();
  factory LocationLogService() => instance;

  // ---------------------------------------------------------------
  Timer?   _timer;
  bool     _isRunning = false;
  Position? _lastKnownPosition;
  final Battery _battery = Battery();

  // ---------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------

  /// Clock-in karte waqt call karo.
  /// Native foreground service bhi start karta hai (app kill survival).
  Future<void> startOnClockIn() async {
    if (_isRunning) return;
    _isRunning = true;

    // Native Kotlin service start karo (foreground — survives kill)
    try {
      await _channel.invokeMethod('startMonitoring');
    } catch (e) {
      _log('⚠️ Native service start failed: $e');
    }

    // Pehli reading foran bhejo
    await _captureAndPost();

    // Phir har 2 minute baad
    _timer = Timer.periodic(const Duration(minutes: 2), (_) async {
      await _captureAndPost();
    });

    _log('✅ LocationLogService started — posting every 2 min');
  }

  /// Clock-out karte waqt call karo.
  Future<void> stopOnClockOut() async {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;

    try {
      await _channel.invokeMethod('stopMonitoring');
    } catch (e) {
      _log('⚠️ Native service stop failed: $e');
    }

    _log('🛑 LocationLogService stopped');
  }

  /// App open hone par call karo: agar clocked-in tha aur service
  /// chal rahi hai to kuch nahi karna, warna restart karo.
  Future<void> resumeIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final isClockedIn = prefs.getBool(_kIsClockedIn) ?? false;

    if (!isClockedIn) return;
    if (_isRunning) return;

    _log('🔄 App resumed — restarting location log timer');
    await startOnClockIn();
  }

  // ---------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------

  Future<void> _captureAndPost() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      // Agar user clock-out ho gaya to ruk jao
      final isClockedIn = prefs.getBool(_kIsClockedIn) ?? false;
      if (!isClockedIn) {
        await stopOnClockOut();
        return;
      }

      final userId      = prefs.getString(_kUserId)     ?? '';
      final bookerName  = prefs.getString(_kBookerName) ?? '';
      final designation = prefs.getString(_kDesignation) ?? '';

      // --- GPS ---
      final pos = await _getPosition();
      if (pos == null) {
        _log('❌ No position — skipping this tick');
        return;
      }

      // --- Battery ---
      int batteryPercent = 0;
      try {
        batteryPercent = await _battery.batteryLevel;
      } catch (_) {}

      // --- Timestamp ---
      final now       = DateTime.now();
      final createdAt = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      // --- Payload ---
      final body = {
        'user_id'         : userId,
        'booker_name'     : bookerName,
        'designation'     : designation,
        'lat_in'          : pos.latitude.toString(),
        'lng_in'          : pos.longitude.toString(),
        'battery_percent' : batteryPercent.toString(),
        'address'         : '',   // Reverse geocoding lazim ho to yahan add karo
        'posted'          : '0',
        'created_at'      : createdAt,
      };

      _log('📤 Posting: $createdAt | ${pos.latitude}, ${pos.longitude} | 🔋$batteryPercent%');

      await _postToServer(body);
    } catch (e) {
      _log('❌ _captureAndPost error: $e');
    }
  }

  Future<Position?> _getPosition() async {
    // Permission check
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return _lastKnownPosition;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 8));
      _lastKnownPosition = pos;
      return pos;
    } on TimeoutException {
      _log('⏱️ GPS timeout — fallback to last known');
      return _lastKnownPosition ?? await Geolocator.getLastKnownPosition();
    } catch (e) {
      _log('⚠️ GPS error: $e — fallback');
      return _lastKnownPosition ?? await Geolocator.getLastKnownPosition();
    }
  }

  Future<void> _postToServer(Map<String, String> body) async {
    try {
      final response = await http
          .post(
        Uri.parse(_kApiUrl),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        _log('✅ Posted successfully — ${response.statusCode}');
      } else {
        _log('⚠️ Server returned ${response.statusCode}: ${response.body}');
      }
    } on SocketException {
      _log('📵 No internet — will retry on next tick');
    } on TimeoutException {
      _log('⏱️ POST timeout — will retry on next tick');
    } catch (e) {
      _log('❌ POST error: $e');
    }
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[LocationLogService] $msg');
  }
}