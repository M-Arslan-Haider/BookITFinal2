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
// // ─── GPS Policy Model ─────────────────────────────────────────────────────────
// class GpsTrackingPolicy {
//   final int locationIntervalSec;
//   final LocationAccuracy gpsAccuracy;
//
//   const GpsTrackingPolicy({
//     required this.locationIntervalSec,
//     required this.gpsAccuracy,
//   });
//
//   factory GpsTrackingPolicy.defaultPolicy() => const GpsTrackingPolicy(
//     locationIntervalSec: 60,
//     gpsAccuracy: LocationAccuracy.high,
//   );
//
//   factory GpsTrackingPolicy.fromJson(Map<String, dynamic> json) {
//     return GpsTrackingPolicy(
//       locationIntervalSec: (json['location_interval_sec'] as num?)?.toInt() ?? 60,
//       gpsAccuracy: _parseAccuracy(json['gps_accuracy']?.toString()),
//     );
//   }
//
//   Map<String, dynamic> toJson() => {
//     'location_interval_sec': locationIntervalSec,
//     'gps_accuracy': _accuracyToString(gpsAccuracy),
//   };
//
//   static LocationAccuracy _parseAccuracy(String? value) {
//     // ✅ FIX: API "HIGH" (uppercase) bhi handle karo
//     switch (value?.toLowerCase()) {
//       case 'best':   return LocationAccuracy.best;
//       case 'high':   return LocationAccuracy.high;
//       case 'medium': return LocationAccuracy.medium;
//       case 'low':    return LocationAccuracy.low;
//       case 'lowest': return LocationAccuracy.lowest;
//       default:       return LocationAccuracy.high;
//     }
//   }
//
//   static String _accuracyToString(LocationAccuracy acc) {
//     switch (acc) {
//       case LocationAccuracy.best:   return 'best';
//       case LocationAccuracy.high:   return 'high';
//       case LocationAccuracy.medium: return 'medium';
//       case LocationAccuracy.low:    return 'low';
//       case LocationAccuracy.lowest: return 'lowest';
//       default:                      return 'high';
//     }
//   }
// }
//
// // ─── Policy Cache Keys ────────────────────────────────────────────────────────
// const _kPolicyIntervalKey  = 'gps_policy_interval_sec';
// const _kPolicyAccuracyKey  = 'gps_policy_accuracy';
// const _kPolicyFetchedAtKey = 'gps_policy_fetched_at';
// const _kTimerAnchorKey     = 'gps_timer_anchor_ms'; // ✅ NEW — anchor for exact timing
// const _kHttpPostAnchorKey = 'http_post_anchor_ms';
//
// const _kPolicyCacheTtlSeconds = 300;
// const _kGpsPolicyApi =
//     'https://cloud.metaxperts.net:8443/erp/valor_trading/gpstracking/get/';
//
// // ─────────────────────────────────────────────────────────────────────────────
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
//   Timer? _locationTimer;
//   Timer? _syncTimer;
//   Timer? _policyRefreshTimer;
//
//   StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
//   bool _wasOffline = false;
//   bool _connectivityListenerInitialized = false;
//
//   bool _isTracking = false;
//   bool get isTracking => _isTracking;
//
//   GpsTrackingPolicy _policy = GpsTrackingPolicy.defaultPolicy();
//
//   // ✅ Anchor time — exact interval ke liye
//   DateTime? _timerAnchor;
//
//   int _locationSerialCounter = 1;
//   String _lastGeneratedLocationDay = '';
//   String _currentLocationMonth = '';
//   String _currentUserId = '';
//
//   // ── GPS Policy ────────────────────────────────────────────────────────────
//
//   Future<GpsTrackingPolicy> _fetchPolicy({bool forceRefresh = false}) async {
//     final prefs = await SharedPreferences.getInstance();
//
//     if (!forceRefresh) {
//       final fetchedAt  = prefs.getInt(_kPolicyFetchedAtKey) ?? 0;
//       final ageSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000 - fetchedAt;
//       if (ageSeconds < _kPolicyCacheTtlSeconds) {
//         return _loadCachedPolicy(prefs);
//       }
//     }
//
//     try {
//       final response = await http
//           .get(
//         Uri.parse('$_kGpsPolicyApi?company_code=$companyCode&user_id=$user_id'),
//         headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
//       )
//           .timeout(const Duration(seconds: 10));
//
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         final dynamic data = jsonDecode(response.body);
//         Map<String, dynamic>? policyMap;
//
//         // ✅ FIX: API {"items":[{...}],...} handle karo
//         if (data is Map<String, dynamic>) {
//           if (data.containsKey('items') && data['items'] is List) {
//             final items = data['items'] as List;
//             if (items.isNotEmpty) policyMap = items[0] as Map<String, dynamic>?;
//           } else {
//             policyMap = data;
//           }
//         } else if (data is List && data.isNotEmpty) {
//           policyMap = data[0] as Map<String, dynamic>?;
//         }
//
//         if (policyMap != null) {
//           final policy = GpsTrackingPolicy.fromJson(policyMap);
//           await _cachePolicyToPrefs(prefs, policy);
//           debugPrint(
//               '✅ [Policy] Fetched — interval=${policy.locationIntervalSec}s accuracy=${policy.gpsAccuracy}');
//           return policy;
//         }
//       }
//     } catch (e) {
//       debugPrint('⚠️ [Policy] Backend fetch failed: $e — using cache/default');
//     }
//
//     return _loadCachedPolicy(prefs);
//   }
//
//   GpsTrackingPolicy _loadCachedPolicy(SharedPreferences prefs) {
//     final intervalSec = prefs.getInt(_kPolicyIntervalKey);
//     final accuracyStr = prefs.getString(_kPolicyAccuracyKey);
//
//     if (intervalSec == null || accuracyStr == null) {
//       debugPrint('⚠️ [Policy] No cache — using default');
//       return GpsTrackingPolicy.defaultPolicy();
//     }
//
//     final policy = GpsTrackingPolicy.fromJson({
//       'location_interval_sec': intervalSec,
//       'gps_accuracy': accuracyStr,
//     });
//     debugPrint('📦 [Policy] Loaded from cache — interval=${policy.locationIntervalSec}s');
//     return policy;
//   }
//
//   Future<void> _cachePolicyToPrefs(SharedPreferences prefs, GpsTrackingPolicy policy) async {
//     await prefs.setInt(_kPolicyIntervalKey, policy.locationIntervalSec);
//     await prefs.setString(_kPolicyAccuracyKey, policy.toJson()['gps_accuracy'] as String);
//     await prefs.setInt(_kPolicyFetchedAtKey, DateTime.now().millisecondsSinceEpoch ~/ 1000);
//   }
//
//   // ✅ FIXED _applyPolicy — anchor-based exact restart
//   void _applyPolicy(GpsTrackingPolicy newPolicy) {
//     final intervalChanged = newPolicy.locationIntervalSec != _policy.locationIntervalSec;
//     _policy = newPolicy;
//
//     if (_isTracking && intervalChanged) {
//       debugPrint(
//           '🔄 [Policy] Interval changed → restarting exact timer (${newPolicy.locationIntervalSec}s)');
//       _restartLocationTimer(resetAnchor: true);
//     }
//   }
//
//   // ── Company code ──────────────────────────────────────────────────────────
//
//   Future<void> _fetchCompanyCode() async {
//     try {
//       final response = await http
//           .get(
//         Uri.parse(
//             'https://cloud.metaxperts.net:8443/erp/beauty_pro_solutions/registeredcompanies/get/'),
//         headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
//       )
//           .timeout(const Duration(seconds: 10));
//
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         final dynamic data = jsonDecode(response.body);
//         String code = '';
//         if (data is Map<String, dynamic>) {
//           if (data.containsKey('items') && data['items'] is List) {
//             final items = data['items'] as List;
//             if (items.isNotEmpty) {
//               code = (items[0] as Map<String, dynamic>)['company_code']?.toString() ?? '';
//             }
//           } else if (data.containsKey('company_code')) {
//             code = data['company_code']?.toString() ?? '';
//           }
//         }
//         if (code.isNotEmpty) {
//           companyCode = code;
//           final prefs = await SharedPreferences.getInstance();
//           await prefs.setString('companyCode', code);
//         } else {
//           await _loadCachedCompanyCode();
//         }
//       } else {
//         await _loadCachedCompanyCode();
//       }
//     } catch (e) {
//       await _loadCachedCompanyCode();
//     }
//   }
//
//   Future<void> _loadCachedCompanyCode() async {
//     final prefs = await SharedPreferences.getInstance();
//     final saved = prefs.getString('companyCode') ?? '';
//     companyCode = saved.isNotEmpty ? saved : 'PK-PUN-SKT-MX01-VT001';
//   }
//
//   // ── ID generation ─────────────────────────────────────────────────────────
//
//   Future<String> _generateLocationTrackingId() async {
//     final SharedPreferences prefs = await SharedPreferences.getInstance();
//     final DateTime now           = DateTime.now();
//     final String currentMonth    = DateFormat('MMM').format(now);
//     final String currentDayNum   = DateFormat('dd').format(now);
//     final String today           = DateFormat('yyyy-MM-dd').format(now);
//     final String lastGenDay      = prefs.getString('lastGeneratedLocationDay') ?? '';
//     final int? highestSerial =
//     await _dbHelper.getHighestLocationSerial(currentDayNum, currentMonth);
//
//     if (lastGenDay != today) {
//       _locationSerialCounter = highestSerial ?? 1;
//       _currentUserId = user_id;
//       _currentLocationMonth = currentMonth;
//       await prefs.setString('lastGeneratedLocationDay', today);
//     }
//     if (_currentUserId != user_id) {
//       _locationSerialCounter = highestSerial ?? 1;
//       _currentUserId = user_id;
//     }
//     if (_currentLocationMonth != currentMonth) {
//       _locationSerialCounter = 1;
//       _currentLocationMonth = currentMonth;
//     }
//
//     final String locationId =
//         "LT-$user_id-$currentDayNum-$currentMonth-${_locationSerialCounter.toString().padLeft(3, '0')}";
//     _locationSerialCounter++;
//     await prefs.setInt('locationSerialCounter', _locationSerialCounter);
//     await prefs.setString('currentLocationId', locationId);
//     return locationId;
//   }
//
//   // ── Lifecycle ─────────────────────────────────────────────────────────────
//
//   Future<void> initialize() async {
//     if (_connectivityListenerInitialized) return;
//
//     await _fetchCompanyCode();
//
//     final SharedPreferences prefs = await SharedPreferences.getInstance();
//     _locationSerialCounter   = prefs.getInt('locationSerialCounter') ?? 1;
//     _lastGeneratedLocationDay = prefs.getString('lastGeneratedLocationDay') ?? '';
//     _currentLocationMonth    = prefs.getString('currentLocationMonth') ?? '';
//     _currentUserId           = user_id;
//
//     _policy = _loadCachedPolicy(prefs);
//     final freshPolicy = await _fetchPolicy(forceRefresh: true);
//     _applyPolicy(freshPolicy);
//
//     final initialResults = await Connectivity().checkConnectivity();
//     _wasOffline = initialResults.every((r) => r == ConnectivityResult.none);
//
//     _connectivitySubscription =
//         Connectivity().onConnectivityChanged.listen((results) async {
//           final isOnline = results.any((r) => r != ConnectivityResult.none);
//           _repo.invalidateConnectivityCache();
//
//           if (isOnline && _wasOffline) {
//             await _repo.postDataFromDatabaseToAPI();
//             await Future.delayed(const Duration(seconds: 5));
//             final updatedPolicy = await _fetchPolicy(forceRefresh: true);
//             _applyPolicy(updatedPolicy);
//             debugPrint('🔄 [Policy] Re-synced after coming online');
//           }
//
//           _wasOffline = !isOnline;
//         });
//
//     _connectivityListenerInitialized = true;
//     await _repo.postDataFromDatabaseToAPI();
//   }
//
//   Future<void> startTracking() async {
//     if (_isTracking) return;
//
//     final permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied ||
//         permission == LocationPermission.deniedForever) {
//       debugPrint('❌ [GPS] Permission denied');
//       return;
//     }
//
//     _isTracking = true;
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool('isLocationTracking', true);
//
//     await initialize();
//
//     _policy = await _fetchPolicy();
//     debugPrint(
//         '🚀 [GPS] Tracking STARTED — interval=${_policy.locationIntervalSec}s accuracy=${_policy.gpsAccuracy}');
//
//     // ✅ EXACT TIMER — anchor-based, drift nahi karta
//     _restartLocationTimer(resetAnchor: true);
//
//     // 60s cloud sync
//     _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
//       await _repo.postDataFromDatabaseToAPI();
//     });
//
//     // Policy refresh har 5 minute
//     _policyRefreshTimer =
//         Timer.periodic(const Duration(seconds: _kPolicyCacheTtlSeconds), (_) async {
//           final updated = await _fetchPolicy(forceRefresh: true);
//           _applyPolicy(updated);
//         });
//   }
//
//   // ✅ KEY FIX — Exact interval timer using absolute timestamps
//   // Problem: Timer.periodic mein kaam karne ka waqt bhi add ho jata tha
//   //   → 60s task + 2s work = 62s gap
//   // Solution: Anchor se compute karo ke EXACTLY kitne ms baad next tick ho
//   //   → Anchor time fixed rehta hai, har tick sirf "next boundary" tak wait karta hai
//   void _restartLocationTimer({bool resetAnchor = false}) {
//     _locationTimer?.cancel();
//
//     final intervalMs = _policy.locationIntervalSec * 1000;
//
//     if (resetAnchor) {
//       _timerAnchor = DateTime.now();
//       debugPrint('⚓ [Timer] Anchor RESET at ${_timerAnchor!.toIso8601String()}');
//     } else {
//       _timerAnchor = DateTime.now();
//       debugPrint('⚓ [Timer] Anchor set at ${_timerAnchor!.toIso8601String()}');
//     }
//
//     _scheduleNextTick(intervalMs);
//   }
//
//   void _scheduleNextTick(int intervalMs) {
//     if (!_isTracking) return;
//
//     final anchor  = _timerAnchor ?? DateTime.now();
//     final now     = DateTime.now();
//     final elapsed = now.difference(anchor).inMilliseconds;
//
//     // Agla exact boundary: interval ke multiples mein se next wala
//     final ticksElapsed = elapsed ~/ intervalMs;
//     final nextBoundary = anchor.add(Duration(milliseconds: (ticksElapsed + 1) * intervalMs));
//     final delayMs      = nextBoundary.difference(now).inMilliseconds;
//
//     // Safety: agar delay negative ya zero ho (processor lag) toh minimum 100ms wait
//     final safeDelay = delayMs > 0 ? delayMs : 100;
//
//     debugPrint('⏱️ [Timer] Next tick in ${safeDelay}ms (target: ${nextBoundary.toIso8601String()})');
//
//     _locationTimer = Timer(Duration(milliseconds: safeDelay), () async {
//       // Kaam karo
//       await _saveCurrentLocation();
//       // Phir agle tick schedule karo
//       _scheduleNextTick(intervalMs);
//     });
//   }
//
//   // ── Save location ─────────────────────────────────────────────────────────
//
//   Future<void> _saveCurrentLocation() async {
//     try {
//       final Position pos = await Geolocator.getCurrentPosition(
//         locationSettings: LocationSettings(
//           accuracy: _policy.gpsAccuracy,
//           timeLimit: const Duration(seconds: 10),
//         ),
//       );
//
//       final now  = DateTime.now();
//       final date = DateFormat('yyyy-MM-dd').format(now);
//       final time = DateFormat('HH:mm:ss').format(now);
//
//       if (companyCode.isEmpty) await _fetchCompanyCode();
//
//       final id = await _generateLocationTrackingId();
//
//       final rowData = {
//         'locationtracking_id':   id,
//         'locationtracking_date': date,
//         'locationtracking_time': time,
//         'user_id':               user_id,
//         'lat_in':                pos.latitude.toString(),
//         'lng_in':                pos.longitude.toString(),
//         'booker_name':           userName,
//         'designation':           userDesignation,
//         'company_code':          companyCode.isNotEmpty ? companyCode : 'PK-PUN-SKT-MX01-VT001',
//         'posted':                0,
//       };
//
//       await _repo.insertAndSync(rowData);
//       debugPrint(
//           '✅ [${_policy.locationIntervalSec}s] $id | ${pos.latitude}, ${pos.longitude} | $time');
//     } catch (e) {
//       debugPrint(
//           '⚠️ [GPS] Position error: $e — will retry in ${_policy.locationIntervalSec}s');
//     }
//   }
//
//   // ── Remaining lifecycle ───────────────────────────────────────────────────
//
//   Future<void> stopTracking() async {
//     _locationTimer?.cancel();
//     _locationTimer = null;
//     _syncTimer?.cancel();
//     _syncTimer = null;
//     _policyRefreshTimer?.cancel();
//     _policyRefreshTimer = null;
//     _isTracking   = false;
//     _timerAnchor  = null;
//
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool('isLocationTracking', false);
//
//     debugPrint('🛑 [GPS] Stopped — final sync');
//     await _repo.postDataFromDatabaseToAPI();
//   }
//
//   Future<void> resumeIfNeeded() async {
//     await initialize();
//     final prefs       = await SharedPreferences.getInstance();
//     final shouldResume = prefs.getBool('isLocationTracking') ?? false;
//     if (shouldResume && !_isTracking) await startTracking();
//     await _repo.postDataFromDatabaseToAPI();
//   }
//
//   Future<void> syncNow() async {
//     await _repo.postDataFromDatabaseToAPI();
//   }
//
//   void dispose() {
//     _locationTimer?.cancel();
//     _locationTimer = null;
//     _syncTimer?.cancel();
//     _syncTimer = null;
//     _policyRefreshTimer?.cancel();
//     _policyRefreshTimer = null;
//     _connectivitySubscription?.cancel();
//     _connectivitySubscription = null;
//     _connectivityListenerInitialized = false;
//     _isTracking  = false;
//     _timerAnchor = null;
//   }
// }

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

// ─── GPS Policy Model ─────────────────────────────────────────────────────────
class GpsTrackingPolicy {
  final int locationIntervalSec;
  final LocationAccuracy gpsAccuracy;

  const GpsTrackingPolicy({
    required this.locationIntervalSec,
    required this.gpsAccuracy,
  });

  factory GpsTrackingPolicy.defaultPolicy() => const GpsTrackingPolicy(
    locationIntervalSec: 60,
    gpsAccuracy: LocationAccuracy.high,
  );

  factory GpsTrackingPolicy.fromJson(Map<String, dynamic> json) {
    return GpsTrackingPolicy(
      locationIntervalSec: (json['location_interval_sec'] as num?)?.toInt() ?? 60,
      gpsAccuracy: _parseAccuracy(json['gps_accuracy']?.toString()),
    );
  }

  Map<String, dynamic> toJson() => {
    'location_interval_sec': locationIntervalSec,
    'gps_accuracy': _accuracyToString(gpsAccuracy),
  };

  static LocationAccuracy _parseAccuracy(String? value) {
    switch (value?.toLowerCase()) {
      case 'best':   return LocationAccuracy.best;
      case 'high':   return LocationAccuracy.high;
      case 'medium': return LocationAccuracy.medium;
      case 'low':    return LocationAccuracy.low;
      case 'lowest': return LocationAccuracy.lowest;
      default:       return LocationAccuracy.high;
    }
  }

  static String _accuracyToString(LocationAccuracy acc) {
    switch (acc) {
      case LocationAccuracy.best:   return 'best';
      case LocationAccuracy.high:   return 'high';
      case LocationAccuracy.medium: return 'medium';
      case LocationAccuracy.low:    return 'low';
      case LocationAccuracy.lowest: return 'lowest';
      default:                      return 'high';
    }
  }
}

// ─── Policy Cache Keys ────────────────────────────────────────────────────────
const _kPolicyIntervalKey  = 'gps_policy_interval_sec';
const _kPolicyAccuracyKey  = 'gps_policy_accuracy';
const _kPolicyFetchedAtKey = 'gps_policy_fetched_at';
const _kTimerAnchorKey     = 'gps_timer_anchor_ms';
const _kHttpPostAnchorKey  = 'http_post_anchor_ms';

const _kPolicyCacheTtlSeconds = 300;
const _kGpsPolicyApi =
    'https://cloud.metaxperts.net:8443/erp/valor_trading/gpstracking/get/';

// ✅ KEY: Kotlin service "is master" flag key — same key Kotlin bhi set karta hai
// Jab Kotlin service chal rahi ho to Flutter GPS save skip karta hai (double posting rokne ke liye)
const _kKotlinServiceMasterKey = 'flutter.kotlin_service_is_master';

// ─────────────────────────────────────────────────────────────────────────────

class LocationTrackingService {
  static final LocationTrackingService _instance =
  LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  final LocationTrackingRepository _repo = LocationTrackingRepository();
  final DBHelper _dbHelper = DBHelper();

  Timer? _locationTimer;
  Timer? _syncTimer;
  Timer? _policyRefreshTimer;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _wasOffline = false;
  bool _connectivityListenerInitialized = false;

  bool _isTracking = false;
  bool get isTracking => _isTracking;

  GpsTrackingPolicy _policy = GpsTrackingPolicy.defaultPolicy();

  // ✅ Anchor time — exact interval ke liye
  DateTime? _timerAnchor;

  int _locationSerialCounter = 1;
  String _lastGeneratedLocationDay = '';
  String _currentLocationMonth = '';
  String _currentUserId = '';

  // ── GPS Policy ────────────────────────────────────────────────────────────

  Future<GpsTrackingPolicy> _fetchPolicy({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final fetchedAt  = prefs.getInt(_kPolicyFetchedAtKey) ?? 0;
      final ageSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000 - fetchedAt;
      if (ageSeconds < _kPolicyCacheTtlSeconds) {
        return _loadCachedPolicy(prefs);
      }
    }

    try {
      final response = await http
          .get(
        Uri.parse('$_kGpsPolicyApi?company_code=$companyCode&user_id=$user_id'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic data = jsonDecode(response.body);
        Map<String, dynamic>? policyMap;

        if (data is Map<String, dynamic>) {
          if (data.containsKey('items') && data['items'] is List) {
            final items = data['items'] as List;
            if (items.isNotEmpty) policyMap = items[0] as Map<String, dynamic>?;
          } else {
            policyMap = data;
          }
        } else if (data is List && data.isNotEmpty) {
          policyMap = data[0] as Map<String, dynamic>?;
        }

        if (policyMap != null) {
          final policy = GpsTrackingPolicy.fromJson(policyMap);
          await _cachePolicyToPrefs(prefs, policy);
          debugPrint(
              '✅ [Policy] Fetched — interval=${policy.locationIntervalSec}s accuracy=${policy.gpsAccuracy}');
          return policy;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [Policy] Backend fetch failed: $e — using cache/default');
    }

    return _loadCachedPolicy(prefs);
  }

  GpsTrackingPolicy _loadCachedPolicy(SharedPreferences prefs) {
    final intervalSec = prefs.getInt(_kPolicyIntervalKey);
    final accuracyStr = prefs.getString(_kPolicyAccuracyKey);

    if (intervalSec == null || accuracyStr == null) {
      debugPrint('⚠️ [Policy] No cache — using default');
      return GpsTrackingPolicy.defaultPolicy();
    }

    final policy = GpsTrackingPolicy.fromJson({
      'location_interval_sec': intervalSec,
      'gps_accuracy': accuracyStr,
    });
    debugPrint('📦 [Policy] Loaded from cache — interval=${policy.locationIntervalSec}s');
    return policy;
  }

  Future<void> _cachePolicyToPrefs(SharedPreferences prefs, GpsTrackingPolicy policy) async {
    await prefs.setInt(_kPolicyIntervalKey, policy.locationIntervalSec);
    await prefs.setString(_kPolicyAccuracyKey, policy.toJson()['gps_accuracy'] as String);
    await prefs.setInt(_kPolicyFetchedAtKey, DateTime.now().millisecondsSinceEpoch ~/ 1000);
  }

  void _applyPolicy(GpsTrackingPolicy newPolicy) {
    final intervalChanged = newPolicy.locationIntervalSec != _policy.locationIntervalSec;
    _policy = newPolicy;

    if (_isTracking && intervalChanged) {
      debugPrint(
          '🔄 [Policy] Interval changed → restarting exact timer (${newPolicy.locationIntervalSec}s)');
      _restartLocationTimer(resetAnchor: true);
    }
  }

  // ── Company code ──────────────────────────────────────────────────────────

  Future<void> _fetchCompanyCode() async {
    try {
      final response = await http
          .get(
        Uri.parse(
            'https://cloud.metaxperts.net:8443/erp/beauty_pro_solutions/registeredcompanies/get/'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      )
          .timeout(const Duration(seconds: 10));

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
    final DateTime now           = DateTime.now();
    final String currentMonth    = DateFormat('MMM').format(now);
    final String currentDayNum   = DateFormat('dd').format(now);
    final String today           = DateFormat('yyyy-MM-dd').format(now);
    final String lastGenDay      = prefs.getString('lastGeneratedLocationDay') ?? '';
    final int? highestSerial =
    await _dbHelper.getHighestLocationSerial(currentDayNum, currentMonth);

    if (lastGenDay != today) {
      _locationSerialCounter = highestSerial ?? 1;
      _currentUserId = user_id;
      _currentLocationMonth = currentMonth;
      await prefs.setString('lastGeneratedLocationDay', today);
    }
    if (_currentUserId != user_id) {
      _locationSerialCounter = highestSerial ?? 1;
      _currentUserId = user_id;
    }
    if (_currentLocationMonth != currentMonth) {
      _locationSerialCounter = 1;
      _currentLocationMonth = currentMonth;
    }

    final String locationId =
        "LT-$user_id-$currentDayNum-$currentMonth-${_locationSerialCounter.toString().padLeft(3, '0')}";
    _locationSerialCounter++;
    await prefs.setInt('locationSerialCounter', _locationSerialCounter);
    await prefs.setString('currentLocationId', locationId);
    return locationId;
  }

  // ── Kotlin service master check ───────────────────────────────────────────

  /// ✅ FIX: Check karo ke Kotlin LocationMonitorService chal rahi hai ya nahi.
  /// Agar chal rahi hai to Flutter GPS save skip karo — Kotlin khud save karta hai.
  /// Is se app kill/restart ke baad double posting completely band hoti hai.
  ///
  /// Kotlin service onStartCommand() mein 'flutter.kotlin_service_is_master' = true set karta hai
  /// aur onDestroy() mein false set karta hai.
  Future<bool> _isKotlinServiceMaster() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kKotlinServiceMasterKey) ?? false;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_connectivityListenerInitialized) return;

    await _fetchCompanyCode();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _locationSerialCounter   = prefs.getInt('locationSerialCounter') ?? 1;
    _lastGeneratedLocationDay = prefs.getString('lastGeneratedLocationDay') ?? '';
    _currentLocationMonth    = prefs.getString('currentLocationMonth') ?? '';
    _currentUserId           = user_id;

    _policy = _loadCachedPolicy(prefs);
    final freshPolicy = await _fetchPolicy(forceRefresh: true);
    _applyPolicy(freshPolicy);

    final initialResults = await Connectivity().checkConnectivity();
    _wasOffline = initialResults.every((r) => r == ConnectivityResult.none);

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) async {
          final isOnline = results.any((r) => r != ConnectivityResult.none);
          _repo.invalidateConnectivityCache();

          if (isOnline && _wasOffline) {
            await _repo.postDataFromDatabaseToAPI();
            await Future.delayed(const Duration(seconds: 5));
            final updatedPolicy = await _fetchPolicy(forceRefresh: true);
            _applyPolicy(updatedPolicy);
            debugPrint('🔄 [Policy] Re-synced after coming online');
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

    _policy = await _fetchPolicy();
    debugPrint(
        '🚀 [GPS] Tracking STARTED — interval=${_policy.locationIntervalSec}s accuracy=${_policy.gpsAccuracy}');

    // ✅ EXACT TIMER — anchor-based, drift nahi karta
    _restartLocationTimer(resetAnchor: true);

    // 60s cloud sync
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      await _repo.postDataFromDatabaseToAPI();
    });

    // Policy refresh har 5 minute
    _policyRefreshTimer =
        Timer.periodic(const Duration(seconds: _kPolicyCacheTtlSeconds), (_) async {
          final updated = await _fetchPolicy(forceRefresh: true);
          _applyPolicy(updated);
        });
  }

  // ✅ Exact interval timer using absolute timestamps — drift free
  void _restartLocationTimer({bool resetAnchor = false}) {
    _locationTimer?.cancel();

    final intervalMs = _policy.locationIntervalSec * 1000;

    if (resetAnchor) {
      _timerAnchor = DateTime.now();
      debugPrint('⚓ [Timer] Anchor RESET at ${_timerAnchor!.toIso8601String()}');
    } else {
      _timerAnchor = DateTime.now();
      debugPrint('⚓ [Timer] Anchor set at ${_timerAnchor!.toIso8601String()}');
    }

    _scheduleNextTick(intervalMs);
  }

  void _scheduleNextTick(int intervalMs) {
    if (!_isTracking) return;

    final anchor  = _timerAnchor ?? DateTime.now();
    final now     = DateTime.now();
    final elapsed = now.difference(anchor).inMilliseconds;

    final ticksElapsed = elapsed ~/ intervalMs;
    final nextBoundary = anchor.add(Duration(milliseconds: (ticksElapsed + 1) * intervalMs));
    final delayMs      = nextBoundary.difference(now).inMilliseconds;
    final safeDelay = delayMs > 0 ? delayMs : 100;

    debugPrint('⏱️ [Timer] Next tick in ${safeDelay}ms (target: ${nextBoundary.toIso8601String()})');

    _locationTimer = Timer(Duration(milliseconds: safeDelay), () async {
      // ✅ FIX: Kotlin service master hai to Flutter GPS save skip karo
      // App open + background dono mein Kotlin service chal rahi hoti hai
      // Sirf jab service bilkul nahi chal rahi (e.g. permission issue) tab Flutter save kare
      final kotlinIsMaster = await _isKotlinServiceMaster();
      if (kotlinIsMaster) {
        debugPrint(
            '⏭️ [Timer] Kotlin service is master — skipping Flutter GPS save (double posting prevention)');
      } else {
        // Kotlin service nahi chal rahi — Flutter fallback mode mein save kare
        debugPrint('🔄 [Timer] Kotlin service NOT master — Flutter saving location');
        await _saveCurrentLocation();
      }
      // Next tick schedule karo regardless
      _scheduleNextTick(intervalMs);
    });
  }

  // ── Save location ─────────────────────────────────────────────────────────

  Future<void> _saveCurrentLocation() async {
    try {
      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: _policy.gpsAccuracy,
          timeLimit: const Duration(seconds: 10),
        ),
      );

      final now  = DateTime.now();
      final date = DateFormat('yyyy-MM-dd').format(now);
      final time = DateFormat('HH:mm:ss').format(now);

      if (companyCode.isEmpty) await _fetchCompanyCode();

      final id = await _generateLocationTrackingId();

      final rowData = {
        'locationtracking_id':   id,
        'locationtracking_date': date,
        'locationtracking_time': time,
        'user_id':               user_id,
        'lat_in':                pos.latitude.toString(),
        'lng_in':                pos.longitude.toString(),
        'booker_name':           userName,
        'designation':           userDesignation,
        'company_code':          companyCode.isNotEmpty ? companyCode : 'PK-PUN-SKT-MX01-VT001',
        'posted':                0,
      };

      await _repo.insertAndSync(rowData);
      debugPrint(
          '✅ [${_policy.locationIntervalSec}s] $id | ${pos.latitude}, ${pos.longitude} | $time');
    } catch (e) {
      debugPrint(
          '⚠️ [GPS] Position error: $e — will retry in ${_policy.locationIntervalSec}s');
    }
  }

  // ── Remaining lifecycle ───────────────────────────────────────────────────

  Future<void> stopTracking() async {
    _locationTimer?.cancel();
    _locationTimer = null;
    _syncTimer?.cancel();
    _syncTimer = null;
    _policyRefreshTimer?.cancel();
    _policyRefreshTimer = null;
    _isTracking   = false;
    _timerAnchor  = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLocationTracking', false);

    debugPrint('🛑 [GPS] Stopped — final sync');
    await _repo.postDataFromDatabaseToAPI();
  }

  Future<void> resumeIfNeeded() async {
    await initialize();
    final prefs       = await SharedPreferences.getInstance();
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
    _policyRefreshTimer?.cancel();
    _policyRefreshTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _connectivityListenerInitialized = false;
    _isTracking  = false;
    _timerAnchor = null;
  }
}