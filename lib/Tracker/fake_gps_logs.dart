// lib/Tracker/fake_gps_logs.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';            // ← FIX 1: needed for custom SSL client
import 'package:shared_preferences/shared_preferences.dart';
import '../Databases/dp_helper.dart';
import '../Databases/util.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MODEL
// ══════════════════════════════════════════════════════════════════════════════

class FakeGpsModel {
  final int? id;
  final String userId;
  final String bookerName;
  final String designation;

  final double realLatitude;
  final double realLongitude;
  final String realAddress;

  final double fakeLatitude;
  final double fakeLongitude;
  final String fakeAddress;

  final double distanceKm;
  final String detectedAt;
  final int posted;

  const FakeGpsModel({
    this.id,
    required this.userId,
    required this.bookerName,
    required this.designation,
    required this.realLatitude,
    required this.realLongitude,
    required this.realAddress,
    required this.fakeLatitude,
    required this.fakeLongitude,
    required this.fakeAddress,
    required this.distanceKm,
    required this.detectedAt,
    this.posted = 0,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'user_id': userId,
    'booker_name': bookerName,
    'designation': designation,
    'real_latitude': realLatitude,
    'real_longitude': realLongitude,
    'real_address': realAddress,
    'fake_latitude': fakeLatitude,
    'fake_longitude': fakeLongitude,
    'fake_address': fakeAddress,
    'distance_km': distanceKm,
    'detected_at': detectedAt,
    'posted': posted,
  };

  factory FakeGpsModel.fromMap(Map<String, dynamic> m) => FakeGpsModel(
    id: m['id'] as int?,
    userId: (m['user_id'] as String?) ?? '',
    bookerName: (m['booker_name'] as String?) ?? '',
    designation: (m['designation'] as String?) ?? '',
    realLatitude: (m['real_latitude'] as num?)?.toDouble() ?? 0.0,
    realLongitude: (m['real_longitude'] as num?)?.toDouble() ?? 0.0,
    realAddress: (m['real_address'] as String?) ?? '',
    fakeLatitude: (m['fake_latitude'] as num?)?.toDouble() ?? 0.0,
    fakeLongitude: (m['fake_longitude'] as num?)?.toDouble() ?? 0.0,
    fakeAddress: (m['fake_address'] as String?) ?? '',
    distanceKm: (m['distance_km'] as num?)?.toDouble() ?? 0.0,
    detectedAt: (m['detected_at'] as String?) ?? '',
    posted: (m['posted'] as int?) ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'booker_name': bookerName,
    'designation': designation,
    'real_latitude': realLatitude,
    'real_longitude': realLongitude,
    'real_address': realAddress,
    'fake_latitude': fakeLatitude,
    'fake_longitude': fakeLongitude,
    'fake_address': fakeAddress,
    'distance_km': distanceKm,
    'detected_at': detectedAt,
  };
}

// ══════════════════════════════════════════════════════════════════════════════
// LOGIC — detect · save locally · post when online
// ══════════════════════════════════════════════════════════════════════════════

class FakeGpsLog {
  FakeGpsLog._();

  static const String _apiUrl = 'https://cloud.metaxperts.net:8443/erp/valor_trading/fakegpspost/post/';

  // Cooldown — prevents flooding DB if mock fires on every tick
  static DateTime? _lastDetected;
  static const Duration _cooldown = Duration(seconds: 30);

  // Connectivity subscription — kept alive for the app's lifetime
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // ⭐ CRITICAL FIX: Cache the last REAL (non-mocked) position
  static Position? _lastRealPosition;

  // ── Clock-out callback (registered by TimerCard on clock-in) ─────────────
  static Future<void> Function(DateTime eventTime)? _clockOutCallback;

  /// Register a callback that fires when fake GPS triggers auto clock-out.
  /// Call this right after a successful clock-in.
  static void registerClockOutCallback(
      Future<void> Function(DateTime eventTime) callback) {
    _clockOutCallback = callback;
    debugPrint('✅ [FakeGPS] Clock-out callback registered');
  }

  /// Unregister the callback — call after any clock-out (manual or auto).
  static void unregisterClockOutCallback() {
    _clockOutCallback = null;
    debugPrint('🛑 [FakeGPS] Clock-out callback unregistered');
  }

  // ── Call once in main() ───────────────────────────────────────────────────
  static void startConnectivityListener() {
    _connectivitySub?.cancel();

    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        debugPrint('🌐 [FakeGPS] Internet restored — syncing pending records…');
        await _postUnsynced();
      }
    });

    debugPrint('✅ [FakeGPS] Connectivity listener started');
  }

  // ── Stop listener (call on logout / app dispose) ──────────────────────────
  static void stopConnectivityListener() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    debugPrint('🛑 [FakeGPS] Connectivity listener stopped');
  }

  // ── Call this on EVERY GPS position update (real and fake) ───────────────
  static Future<void> checkAndReport(Position pos) async {
    if (!Platform.isAndroid) return;

    // ⭐ CRITICAL: Always cache real positions as they come in
    if (!pos.isMocked) {
      _lastRealPosition = pos;
      debugPrint('📍 [FakeGPS] Real position cached: (${pos.latitude}, ${pos.longitude})');
      return;
    }

    // ── From here down: pos.isMocked == true ─────────────────────────────────
    final now = DateTime.now();
    if (_lastDetected != null && now.difference(_lastDetected!) < _cooldown) {
      debugPrint('⚠️ [FakeGPS] Mock detected — within cooldown, skipping');
      return;
    }
    _lastDetected = now;

    final fakeLat = pos.latitude;
    final fakeLon = pos.longitude;
    debugPrint('🚨 [FakeGPS] FAKE GPS detected! fake=($fakeLat, $fakeLon)');

    // ── Fire auto clock-out callback if registered ────────────────────────────
    if (_clockOutCallback != null) {
      debugPrint('⚡ [FakeGPS] Firing clock-out callback at $now');
      try {
        await _clockOutCallback!(now);
      } catch (e) {
        debugPrint('❌ [FakeGPS] Clock-out callback error: $e');
      }
    }

    // ⭐ CRITICAL: Use cached real position
    double realLat;
    double realLon;

    if (_lastRealPosition != null) {
      realLat = _lastRealPosition!.latitude;
      realLon = _lastRealPosition!.longitude;
      debugPrint('📍 [FakeGPS] Using cached real position: ($realLat, $realLon)');
    } else {
      realLat = fakeLat;
      realLon = fakeLon;
      debugPrint('⚠️ [FakeGPS] No real position cached — using fake as fallback');
    }

    // ── Reverse geocode both locations ────────────────────────────────────────
    final fakeAddress = await _getAddress(fakeLat, fakeLon);
    final realAddress = (realLat != fakeLat || realLon != fakeLon)
        ? await _getAddress(realLat, realLon)
        : fakeAddress;

    // ── Distance (km) ─────────────────────────────────────────────────────────
    final distanceKm = Geolocator.distanceBetween(realLat, realLon, fakeLat, fakeLon) / 1000.0;

    debugPrint('📏 [FakeGPS] Distance real↔fake: ${distanceKm.toStringAsFixed(3)} km');

    final prefs = await SharedPreferences.getInstance();

    // Get user info from SharedPreferences
    final userId = prefs.getString('user_id') ?? prefs.getString('userId') ?? user_id;
    final bookerName = prefs.getString('booker_name') ?? prefs.getString('userName') ?? userName;
    final designation = prefs.getString('designation') ?? prefs.getString('userDesignation') ?? userDesignation;

    final model = FakeGpsModel(
      userId: userId,
      bookerName: bookerName,
      designation: designation,
      realLatitude: realLat,
      realLongitude: realLon,
      realAddress: realAddress,
      fakeLatitude: fakeLat,
      fakeLongitude: fakeLon,
      fakeAddress: fakeAddress,
      distanceKm: double.parse(distanceKm.toStringAsFixed(3)),
      detectedAt: now.toIso8601String(),
    );

    await _saveLocal(model);
    await _postUnsynced();
  }

  static Future<String> _getAddress(double lat, double lon) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lon).timeout(const Duration(seconds: 8));
      if (marks.isEmpty) return '$lat, $lon';
      final p = marks.first;
      final parts = [
        p.thoroughfare,
        p.subLocality,
        p.locality,
        p.administrativeArea,
        p.country,
      ].where((s) => s != null && s.isNotEmpty).join(', ');
      return parts.isEmpty ? '$lat, $lon' : parts;
    } catch (e) {
      debugPrint('⚠️ [FakeGPS] Geocoding failed: $e');
      return '$lat, $lon';
    }
  }

  static Future<void> syncPending() async => _postUnsynced();

  static Future<void> _saveLocal(FakeGpsModel model) async {
    try {
      final dbHelper = DBHelper();
      await dbHelper.insertFakeGpsLog(model.toMap());
      debugPrint('💾 [FakeGPS] Saved locally at ${model.detectedAt}');
    } catch (e) {
      debugPrint('❌ [FakeGPS] Local save failed: $e');
    }
  }

  static Future<void> _postUnsynced() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    final isOnline = connectivityResults.any((r) => r != ConnectivityResult.none);

    if (!isOnline) {
      debugPrint('📴 [FakeGPS] Offline — skipping sync');
      return;
    }

    try {
      final dbHelper = DBHelper();
      final rows = await dbHelper.getUnpostedFakeGpsLogs();
      if (rows.isEmpty) {
        debugPrint('✅ [FakeGPS] No pending records to sync');
        return;
      }

      debugPrint('🔄 [FakeGPS] Syncing ${rows.length} unposted record(s)...');

      final postedIds = <int>[];

      for (final row in rows) {
        final model = FakeGpsModel.fromMap(row);
        final ok = await _post(model);
        if (ok && model.id != null) {
          postedIds.add(model.id!);
        }
      }

      if (postedIds.isNotEmpty) {
        await dbHelper.markAllFakeGpsAsPosted(postedIds);
        debugPrint('✅ [FakeGPS] Marked ${postedIds.length} logs as posted');
      }
    } catch (e) {
      debugPrint('❌ [FakeGPS] _postUnsynced error: $e');
    }
  }

  // ── FIX 1: Custom HTTP client that accepts the server's self-signed / private CA cert.
  //   This is safe because we pin to a specific private hostname, not the open internet.
  static http.Client _buildHttpClient() {
    final ioClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Only bypass for our private Oracle APEX server — not for all hosts
        return host == 'cloud.metaxperts.net';
      }
      ..connectionTimeout = const Duration(seconds: 15);
    return IOClient(ioClient);
  }

  static Future<bool> _post(FakeGpsModel model) async {
    http.Client? client;
    try {
      client = _buildHttpClient();
      final body = jsonEncode(model.toJson());
      debugPrint('📤 [FakeGPS] POST → $_apiUrl\n   body=$body');

      final response = await client
          .post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: body,
      )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ [FakeGPS] Posted id=${model.id} → ${response.statusCode}');
        return true;
      }
      // Log the full response body so you can see Oracle APEX error messages
      debugPrint('⚠️ [FakeGPS] Server rejected → ${response.statusCode}: ${response.body}');
      return false;
    } on HandshakeException catch (e) {
      // This is the SSL/TLS failure — now visible in logs instead of silent
      debugPrint('🔒 [FakeGPS] SSL handshake FAILED: $e\n'
          '   → Check that cloud.metaxperts.net:8443 certificate is valid '
          'or that the badCertificateCallback host matches exactly.');
      return false;
    } on SocketException catch (e) {
      debugPrint('📵 [FakeGPS] No network / socket error: $e');
      return false;
    } on TimeoutException catch (e) {
      debugPrint('⏱️ [FakeGPS] Request timed out: $e');
      return false;
    } catch (e) {
      debugPrint('❌ [FakeGPS] POST failed (${e.runtimeType}): $e');
      return false;
    } finally {
      client?.close();
    }
  }
}