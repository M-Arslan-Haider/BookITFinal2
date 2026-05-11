//
// import 'dart:async';
// import 'dart:convert';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter/foundation.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../Databases/util.dart';
// import '../Repositories/location_tracking_repository.dart';
// import '../Databases/dp_helper.dart';
//
// class LocationTrackingService {
//   static final LocationTrackingService _instance =
//   LocationTrackingService._internal();
//   factory LocationTrackingService() => _instance;
//   LocationTrackingService._internal();
//
//   final LocationTrackingRepository _repo = LocationTrackingRepository();
//   final DBHelper _dbHelper = DBHelper();
//
//   // ── Stream-based GPS ──────────────────────────────────────────────────────
//   //
//   // ROOT CAUSE OF "ONLY 2 POINTS" BUG:
//   //   The previous approach called getCurrentPosition() every 5 seconds.
//   //   On most Android devices each call requests a *fresh satellite fix*
//   //   within a tight timeout. When GPS takes longer than the timeout
//   //   (common at startup, indoors, under trees), the tick is skipped.
//   //   Result: only the first and last successful fix are saved → straight line.
//   //
//   //   FIX: Use getPositionStream() instead. The stream subscribes ONCE to the
//   //   platform GPS engine and delivers every position as it arrives —
//   //   no per-tick timeout, no cold-start penalty, no skipped fixes.
//   //   distanceFilter: 10 m means the OS only wakes us when the user has
//   //   actually moved, so no duplicate coordinates ever reach our code.
//   // ─────────────────────────────────────────────────────────────────────────
//   StreamSubscription<Position>? _positionSubscription;
//   Timer? _syncTimer;
//
//   StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
//   bool _wasOffline = false;
//   bool _connectivityListenerInitialized = false;
//
//   bool _isTracking = false;
//   bool get isTracking => _isTracking;
//
//   int _locationSerialCounter = 1;
//   String _lastGeneratedLocationDay = '';
//   String _currentLocationMonth = '';
//   String _currentUserId = '';
//
//   // Discard fixes with accuracy worse than this (weak signal / indoors)
//   static const double _maxAccuracyMeters = 50.0;
//
//   // ── Company code ──────────────────────────────────────────────────────────
//
//   Future<void> _fetchCompanyCode() async {
//     try {
//       final response = await http.get(
//         Uri.parse(
//             'https://cloud.metaxperts.net:8443/erp/beauty_pro_solutions/registeredcompanies/get/'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Accept': 'application/json',
//         },
//       ).timeout(const Duration(seconds: 10));
//
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         final dynamic data = jsonDecode(response.body);
//         String code = '';
//
//         if (data is Map<String, dynamic>) {
//           if (data.containsKey('items') && data['items'] is List) {
//             final items = data['items'] as List;
//             if (items.isNotEmpty) {
//               final firstItem = items[0] as Map<String, dynamic>;
//               code = firstItem['company_code']?.toString() ?? '';
//             }
//           } else if (data.containsKey('company_code')) {
//             code = data['company_code']?.toString() ?? '';
//           }
//         }
//
//         if (code.isNotEmpty) {
//           companyCode = code;
//           final prefs = await SharedPreferences.getInstance();
//           await prefs.setString('companyCode', code);
//           debugPrint('✅ [COMPANY] Code fetched: $companyCode');
//         } else {
//           debugPrint('⚠️ [COMPANY] Could not parse company_code');
//           await _loadCachedCompanyCode();
//         }
//       } else {
//         await _loadCachedCompanyCode();
//       }
//     } catch (e) {
//       debugPrint('❌ [COMPANY] Failed to fetch: $e');
//       await _loadCachedCompanyCode();
//     }
//   }
//
//   Future<void> _loadCachedCompanyCode() async {
//     final prefs = await SharedPreferences.getInstance();
//     final saved = prefs.getString('companyCode') ?? '';
//     if (saved.isNotEmpty) {
//       companyCode = saved;
//       debugPrint('🔄 [COMPANY] Using cached: $companyCode');
//     } else {
//       companyCode = 'PK-PUN-SKT-MX01-VT001';
//       debugPrint('⚠️ [COMPANY] Using default: $companyCode');
//     }
//   }
//
//   // ── ID generation ─────────────────────────────────────────────────────────
//
//   Future<String> _generateLocationTrackingId() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//
//     final DateTime now = DateTime.now();
//     String currentMonth = DateFormat('MMM').format(now);
//     String currentDayNumber = DateFormat('dd').format(now);
//     String today = DateFormat('yyyy-MM-dd').format(now);
//
//     String lastGeneratedDay = prefs.getString('lastGeneratedLocationDay') ?? '';
//
//     int? highestSerial =
//     await _dbHelper.getHighestLocationSerial(currentDayNumber, currentMonth);
//
//     if (lastGeneratedDay != today) {
//       _locationSerialCounter = (highestSerial ?? 1);
//       _currentUserId = user_id;
//       _currentLocationMonth = currentMonth;
//       await prefs.setString('lastGeneratedLocationDay', today);
//       debugPrint("🔄 [LOCATION] New day - Counter: $_locationSerialCounter");
//     }
//
//     if (_currentUserId != user_id) {
//       _locationSerialCounter = (highestSerial ?? 1);
//       _currentUserId = user_id;
//       debugPrint("🔄 [LOCATION] User changed - Counter: $_locationSerialCounter");
//     }
//
//     if (_currentLocationMonth != currentMonth) {
//       _locationSerialCounter = 1;
//       _currentLocationMonth = currentMonth;
//       debugPrint("🔄 [LOCATION] Month changed - Counter reset to: 1");
//     }
//
//     String locationId =
//         "LT-$user_id-$currentDayNumber-$currentMonth-${_locationSerialCounter.toString().padLeft(3, '0')}";
//
//     debugPrint(
//         "🆔 [LOCATION] ID Generated: $locationId (Serial: $_locationSerialCounter)");
//
//     await prefs.setString('currentLocationId', locationId);
//     _locationSerialCounter++;
//     await prefs.setInt('locationSerialCounter', _locationSerialCounter);
//
//     return locationId;
//   }
//
//   // ── Lifecycle ─────────────────────────────────────────────────────────────
//
//   Future<void> initialize() async {
//     if (_connectivityListenerInitialized) {
//       debugPrint('⚠️ [GPS SERVICE] Already initialized');
//       return;
//     }
//
//     debugPrint('🔧 [GPS SERVICE] Initializing...');
//     await _fetchCompanyCode();
//
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     _locationSerialCounter = prefs.getInt('locationSerialCounter') ?? 1;
//     _lastGeneratedLocationDay = prefs.getString('lastGeneratedLocationDay') ?? '';
//     _currentLocationMonth = prefs.getString('currentLocationMonth') ?? '';
//     _currentUserId = user_id;
//
//     // Read actual connectivity state at startup so _wasOffline is correct
//     // before the listener fires.
//     final initialResults = await Connectivity().checkConnectivity();
//     _wasOffline = initialResults.every((r) => r == ConnectivityResult.none);
//     debugPrint(
//         '🌐 [GPS SERVICE] Starting connectivity: ${_wasOffline ? "OFFLINE" : "ONLINE"}');
//
//     _connectivitySubscription =
//         Connectivity().onConnectivityChanged.listen((results) async {
//           final isOnline = results.any((r) => r != ConnectivityResult.none);
//           _repo.invalidateConnectivityCache();
//
//           if (isOnline && _wasOffline) {
//             debugPrint('🌐 [GPS SERVICE] INTERNET CONNECTED! Syncing...');
//             await _repo.postDataFromDatabaseToAPI();
//           }
//           _wasOffline = !isOnline;
//         });
//
//     _connectivityListenerInitialized = true;
//     debugPrint('🔧 [GPS SERVICE] Initial sync...');
//     await _repo.postDataFromDatabaseToAPI();
//   }
//
//   Future<void> startTracking() async {
//     if (_isTracking) {
//       debugPrint('⚠️ [GPS SERVICE] Already tracking');
//       return;
//     }
//
//     final permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied ||
//         permission == LocationPermission.deniedForever) {
//       debugPrint('❌ [GPS SERVICE] Location permission denied');
//       return;
//     }
//
//     _isTracking = true;
//
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool('isLocationTracking', true);
//
//     debugPrint('✅ [GPS SERVICE] Tracking STARTED for user: $user_id');
//
//     await initialize();
//
//     // ── Subscribe to position stream ──────────────────────────────────────
//     //
//     // distanceFilter: 10 m
//     //   The Android/iOS GPS engine only emits a new event when the device
//     //   has physically moved ≥ 10 metres. This means:
//     //     • No duplicate coordinates (stationary device = no events)
//     //     • Every event IS a meaningful movement — no manual distance check needed
//     //     • Battery efficient — the OS buffers fixes internally
//     //
//     // Tune distanceFilter to your needs:
//     //   5  m → very fine detail (city walking, narrow streets)
//     //   10 m → good balance (default)
//     //   20 m → coarser but very battery-friendly (car/motorbike tracking)
//     // ─────────────────────────────────────────────────────────────────────
//     const locationSettings = LocationSettings(
//       accuracy: LocationAccuracy.high,
//       distanceFilter: 10,
//     );
//
//     _positionSubscription = Geolocator.getPositionStream(
//       locationSettings: locationSettings,
//     ).listen(
//           (Position position) async {
//         await _onPositionReceived(position);
//       },
//       onError: (error) {
//         // Log the error but keep the stream alive.
//         // Most GPS errors are transient (e.g. permission briefly revoked,
//         // airplane mode toggled). cancelOnError: false handles recovery.
//         debugPrint('❌ [GPS STREAM] Error: $error');
//       },
//       cancelOnError: false,
//     );
//
//     debugPrint('📡 [GPS SERVICE] Position stream started (distanceFilter: 10 m)');
//
//     // Sync to cloud every 60 seconds
//     _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
//       debugPrint('🔄 [GPS SERVICE] Periodic sync...');
//       await _repo.postDataFromDatabaseToAPI();
//     });
//   }
//
//   Future<void> stopTracking() async {
//     await _positionSubscription?.cancel();
//     _positionSubscription = null;
//
//     _syncTimer?.cancel();
//     _syncTimer = null;
//
//     _isTracking = false;
//
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool('isLocationTracking', false);
//
//     debugPrint('🛑 [GPS SERVICE] Tracking STOPPED');
//     debugPrint('🔄 [GPS SERVICE] Final sync...');
//     await _repo.postDataFromDatabaseToAPI();
//   }
//
//   Future<void> resumeIfNeeded() async {
//     await initialize();
//
//     final prefs = await SharedPreferences.getInstance();
//     final shouldResume = prefs.getBool('isLocationTracking') ?? false;
//
//     if (shouldResume && !_isTracking) {
//       debugPrint('🔁 [GPS SERVICE] Resuming tracking...');
//       await startTracking();
//     }
//
//     await _repo.postDataFromDatabaseToAPI();
//   }
//
//   Future<void> syncNow() async {
//     debugPrint('🔄 [GPS SERVICE] MANUAL SYNC triggered');
//     await _repo.postDataFromDatabaseToAPI();
//   }
//
//   void dispose() {
//     _positionSubscription?.cancel();
//     _positionSubscription = null;
//     _syncTimer?.cancel();
//     _syncTimer = null;
//     _connectivitySubscription?.cancel();
//     _connectivitySubscription = null;
//     _connectivityListenerInitialized = false;
//     _isTracking = false;
//   }
//
//   // ── Position handler ──────────────────────────────────────────────────────
//   //
//   // Called by the GPS stream for every position that passes the OS distanceFilter.
//   // We only need one guard here: accuracy.
//   // Duplicate/stationary positions are already eliminated by distanceFilter.
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<void> _onPositionReceived(Position pos) async {
//     // Accuracy guard: drop weak fixes (indoors, tunnels, heavy cloud cover).
//     if (pos.accuracy > _maxAccuracyMeters) {
//       debugPrint(
//           '📡 [GPS] Inaccurate fix (${pos.accuracy.toStringAsFixed(1)} m > '
//               '${_maxAccuracyMeters.toStringAsFixed(0)} m threshold) — skipped');
//       return;
//     }
//
//     final now = DateTime.now();
//     final date = DateFormat('yyyy-MM-dd').format(now);
//     final time = DateFormat('HH:mm:ss').format(now);
//
//     if (companyCode.isEmpty) {
//       debugPrint('⚠️ [GPS] company_code is empty, fetching...');
//       await _fetchCompanyCode();
//     }
//
//     final id = await _generateLocationTrackingId();
//
//     final rowData = {
//       'locationtracking_id': id,
//       'locationtracking_date': date,
//       'locationtracking_time': time,
//       'user_id': user_id,
//       'lat_in': pos.latitude.toString(),
//       'lng_in': pos.longitude.toString(),
//       'booker_name': userName,
//       'designation': userDesignation,
//       'company_code':
//       companyCode.isNotEmpty ? companyCode : 'PK-PUN-SKT-MX01-VT001',
//       'posted': 0,
//     };
//
//     await _repo.insertAndSync(rowData);
//     debugPrint('📍 [GPS] $id | ${pos.latitude}, ${pos.longitude} | '
//         'acc: ${pos.accuracy.toStringAsFixed(1)} m | '
//         'spd: ${pos.speed.toStringAsFixed(1)} m/s');
//   }
// }

///5m + 15sec
import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Databases/util.dart';
import '../Repositories/location_tracking_repository.dart';
import '../Databases/dp_helper.dart';

class LocationTrackingService {
  static final LocationTrackingService _instance =
  LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  final LocationTrackingRepository _repo = LocationTrackingRepository();
  final DBHelper _dbHelper = DBHelper();

  Timer? _locationTimer;   // har 15s lat/lng save
  Timer? _syncTimer;       // har 60s server sync

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _wasOffline = false;
  bool _connectivityListenerInitialized = false;

  bool _isTracking = false;
  bool get isTracking => _isTracking;

  int _locationSerialCounter = 1;
  String _lastGeneratedLocationDay = '';
  String _currentLocationMonth = '';
  String _currentUserId = '';

  // ── Company code ──────────────────────────────────────────────────────────

  Future<void> _fetchCompanyCode() async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://cloud.metaxperts.net:8443/erp/beauty_pro_solutions/registeredcompanies/get/'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic data = jsonDecode(response.body);
        String code = '';
        if (data is Map<String, dynamic>) {
          if (data.containsKey('items') && data['items'] is List) {
            final items = data['items'] as List;
            if (items.isNotEmpty) {
              code = (items[0] as Map<String, dynamic>)['company_code']?.toString() ?? '';
            }
          } else if (data.containsKey('company_code')) {
            code = data['company_code']?.toString() ?? '';
          }
        }
        if (code.isNotEmpty) {
          companyCode = code;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('companyCode', code);
        } else {
          await _loadCachedCompanyCode();
        }
      } else {
        await _loadCachedCompanyCode();
      }
    } catch (e) {
      await _loadCachedCompanyCode();
    }
  }

  Future<void> _loadCachedCompanyCode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('companyCode') ?? '';
    companyCode = saved.isNotEmpty ? saved : 'PK-PUN-SKT-MX01-VT001';
  }

  // ── ID generation ─────────────────────────────────────────────────────────

  Future<String> _generateLocationTrackingId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final DateTime now = DateTime.now();
    final String currentMonth = DateFormat('MMM').format(now);
    final String currentDayNumber = DateFormat('dd').format(now);
    final String today = DateFormat('yyyy-MM-dd').format(now);
    final String lastGeneratedDay = prefs.getString('lastGeneratedLocationDay') ?? '';
    final int? highestSerial =
    await _dbHelper.getHighestLocationSerial(currentDayNumber, currentMonth);

    if (lastGeneratedDay != today) {
      _locationSerialCounter = (highestSerial ?? 1);
      _currentUserId = user_id;
      _currentLocationMonth = currentMonth;
      await prefs.setString('lastGeneratedLocationDay', today);
    }
    if (_currentUserId != user_id) {
      _locationSerialCounter = (highestSerial ?? 1);
      _currentUserId = user_id;
    }
    if (_currentLocationMonth != currentMonth) {
      _locationSerialCounter = 1;
      _currentLocationMonth = currentMonth;
    }

    final String locationId =
        "LT-$user_id-$currentDayNumber-$currentMonth-${_locationSerialCounter.toString().padLeft(3, '0')}";
    _locationSerialCounter++;
    await prefs.setInt('locationSerialCounter', _locationSerialCounter);
    await prefs.setString('currentLocationId', locationId);
    return locationId;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_connectivityListenerInitialized) return;

    await _fetchCompanyCode();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _locationSerialCounter = prefs.getInt('locationSerialCounter') ?? 1;
    _lastGeneratedLocationDay = prefs.getString('lastGeneratedLocationDay') ?? '';
    _currentLocationMonth = prefs.getString('currentLocationMonth') ?? '';
    _currentUserId = user_id;

    final initialResults = await Connectivity().checkConnectivity();
    _wasOffline = initialResults.every((r) => r == ConnectivityResult.none);

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) async {
          final isOnline = results.any((r) => r != ConnectivityResult.none);
          _repo.invalidateConnectivityCache();
          if (isOnline && _wasOffline) {
            await _repo.postDataFromDatabaseToAPI();
          }
          _wasOffline = !isOnline;
        });

    _connectivityListenerInitialized = true;
    await _repo.postDataFromDatabaseToAPI();
  }

  Future<void> startTracking() async {
    if (_isTracking) return;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('❌ [GPS] Permission denied');
      return;
    }

    _isTracking = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLocationTracking', true);

    await initialize();

    // ── HAR 15 SECOND — BILKUL SIMPLE ────────────────────────────────────
    // Dart Timer.periodic — exact 15s, GPS engine se zero connection
    // Har tick mein: getCurrentPosition() se fresh lat/lng lo, save karo
    // Koi stream nahi, koi distanceFilter nahi, koi speed check nahi
    // ─────────────────────────────────────────────────────────────────────
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await _saveCurrentLocation();
    });

    // 60s cloud sync
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      await _repo.postDataFromDatabaseToAPI();
    });

    debugPrint('✅ [GPS] Tracking STARTED — saving every 15s');
  }

  // ── Har 15s mein yahi function call hoga ─────────────────────────────────

  // In location_tracking_service.dart - _saveCurrentLocation()
  Future<void> _saveCurrentLocation() async {
    try {
      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // REMOVE any accuracy filtering that might drop fixes
      // if (pos.accuracy > 50) return;  // ← DO NOT add this!

      final now = DateTime.now();
      final date = DateFormat('yyyy-MM-dd').format(now);
      final time = DateFormat('HH:mm:ss').format(now);

      if (companyCode.isEmpty) await _fetchCompanyCode();

      final id = await _generateLocationTrackingId();

      final rowData = {
        'locationtracking_id': id,
        'locationtracking_date': date,
        'locationtracking_time': time,
        'user_id': user_id,
        'lat_in': pos.latitude.toString(),
        'lng_in': pos.longitude.toString(),
        'booker_name': userName,
        'designation': userDesignation,
        'company_code': companyCode.isNotEmpty ? companyCode : 'PK-PUN-SKT-MX01-VT001',
        'posted': 0,
      };

      await _repo.insertAndSync(rowData);
      debugPrint('✅ [15s] $id | ${pos.latitude}, ${pos.longitude} | $time');

    } catch (e) {
      debugPrint('⚠️ [15s] Position error: $e — will retry in 15s');
    }
  }

  // ── Remaining lifecycle ───────────────────────────────────────────────────

  Future<void> stopTracking() async {
    _locationTimer?.cancel();
    _locationTimer = null;
    _syncTimer?.cancel();
    _syncTimer = null;
    _isTracking = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLocationTracking', false);

    debugPrint('🛑 [GPS] Stopped — final sync');
    await _repo.postDataFromDatabaseToAPI();
  }

  Future<void> resumeIfNeeded() async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final shouldResume = prefs.getBool('isLocationTracking') ?? false;
    if (shouldResume && !_isTracking) await startTracking();
    await _repo.postDataFromDatabaseToAPI();
  }

  Future<void> syncNow() async {
    await _repo.postDataFromDatabaseToAPI();
  }

  void dispose() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _syncTimer?.cancel();
    _syncTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _connectivityListenerInitialized = false;
    _isTracking = false;
  }
}