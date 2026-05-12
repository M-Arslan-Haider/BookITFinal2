//
// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
//
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
// import 'package:order_booking_app/Databases/util.dart';
//
// import '../Databases/dp_helper.dart';
//
// class LocationTrackingRepository {
//   final DBHelper _dbHelper = DBHelper();
//
//   // static const String _apiUrl = 'http://103.149.33.102:8001/location/bulk';
//
//   static const String _apiUrl = 'http://119.153.102.7:8001/location/bulk';
//
//   bool _isSyncing = false;
//   bool _cachedOnline = false;
//   DateTime? _lastConnectivityCheck;
//   static const Duration _connectivityCacheDuration = Duration(seconds: 5);
//
//   Future<void> insertAndSync(Map<String, dynamic> data) async {
//     await _dbHelper.insertLocationTracking(data);
//     debugPrint('💾 [TRACKING REPO] Saved locally: ${data['locationtracking_id']}');
//
//     final online = await _isOnlineCached();
//     if (!online) {
//       debugPrint('📴 [TRACKING REPO] Offline — will sync later');
//       return;
//     }
//
//     if (!_isSyncing) {
//       await postDataFromDatabaseToAPI();
//     }
//   }
//
//   Future<void> postDataFromDatabaseToAPI() async {
//     if (_isSyncing) {
//       debugPrint('⏳ [TRACKING REPO] Sync already in progress — skipping');
//       return;
//     }
//     _isSyncing = true;
//
//     try {
//       final unpostedRows = await _dbHelper.getUnpostedLocationTracking();
//
//       if (unpostedRows.isEmpty) {
//         debugPrint('✅ [TRACKING REPO] No unposted rows — nothing to sync');
//         return;
//       }
//
//       debugPrint('🚀 [TRACKING REPO] Syncing ${unpostedRows.length} rows via BULK...');
//
//       final isOnlineNow = await isOnline();
//       if (!isOnlineNow) {
//         debugPrint('📴 [TRACKING REPO] Device is offline — will retry later');
//         return;
//       }
//
//       // BULK only — no single-row fallback (causes duplicate rows on backend)
//       final success = await _postBulkRows(unpostedRows);
//
//       if (success) {
//         final postedIds = unpostedRows
//             .map((row) => row['locationtracking_id'] as String)
//             .toList();
//         await _dbHelper.markLocationTrackingAsPosted(postedIds);
//         debugPrint('✅ [TRACKING REPO] Marked ${postedIds.length} rows as posted');
//       } else {
//         debugPrint('⚠️ [TRACKING REPO] Bulk failed — will retry on next sync');
//       }
//     } catch (e) {
//       debugPrint('❌ [TRACKING REPO] postDataFromDatabaseToAPI error: $e');
//     } finally {
//       _isSyncing = false;
//     }
//   }
//
//   Future<bool> _postBulkRows(List<Map<String, dynamic>> rows) async {
//     try {
//       final List<Map<String, dynamic>> records = rows.map((row) {
//         double? latDouble;
//         double? lngDouble;
//
//         try {
//           latDouble = double.tryParse(row['lat_in']?.toString() ?? '');
//           lngDouble = double.tryParse(row['lng_in']?.toString() ?? '');
//         } catch (e) {
//           debugPrint('⚠️ [TRACKING REPO] Error parsing lat/lng: $e');
//         }
//
//         // ─────────────────────────────────────────────────────────────────
//         // locationtracking_id is intentionally NOT sent to the server.
//         // It is only used locally as the SQLite primary key and for
//         // markLocationTrackingAsPosted() after a successful bulk sync.
//         // Sending it was causing duplicate rows on the backend.
//         // ─────────────────────────────────────────────────────────────────
//         return {
//           'locationtracking_date': row['locationtracking_date']?.toString() ?? '',
//           'locationtracking_time': row['locationtracking_time']?.toString() ?? '',
//           'user_id': row['user_id']?.toString() ?? '',
//           'company_code': row['company_code']?.toString() ?? '',
//           'lat_in': latDouble ?? 0.0,
//           'lng_in': lngDouble ?? 0.0,
//           'booker_name': row['booker_name']?.toString() ?? '',
//           'designation': row['designation']?.toString() ?? '',
//           'posted': false,
//         };
//       }).toList();
//
//       final requestBody = {'records': records};
//
//       debugPrint('📡 [TRACKING REPO] BULK posting ${records.length} rows → $_apiUrl');
//       if (records.isNotEmpty) {
//         debugPrint('📡 Sample: ${records.first}');
//       }
//
//       final response = await http
//           .post(
//         Uri.parse(_apiUrl),
//         headers: {
//           'Content-Type': 'application/json',
//           'Accept': 'application/json',
//         },
//         body: jsonEncode(requestBody),
//       )
//           .timeout(const Duration(seconds: 30));
//
//       debugPrint('📡 BULK response status: ${response.statusCode}');
//
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         debugPrint('✅ [TRACKING REPO] BULK post successful');
//         return true;
//       }
//
//       final preview = response.body.length > 300
//           ? '${response.body.substring(0, 300)}...'
//           : response.body;
//       debugPrint('⚠️ [TRACKING REPO] BULK failed ${response.statusCode}: $preview');
//       return false;
//     } on SocketException catch (e) {
//       debugPrint('📴 [TRACKING REPO] No internet for bulk post: $e');
//       return false;
//     } on TimeoutException catch (e) {
//       debugPrint('⏱️ [TRACKING REPO] Timeout for bulk post: $e');
//       return false;
//     } catch (e) {
//       debugPrint('❌ [TRACKING REPO] Unexpected error in bulk post: $e');
//       return false;
//     }
//   }
//
//   Future<bool> _isOnlineCached() async {
//     final now = DateTime.now();
//     if (_lastConnectivityCheck != null &&
//         now.difference(_lastConnectivityCheck!) < _connectivityCacheDuration) {
//       return _cachedOnline;
//     }
//     _cachedOnline = await isOnline();
//     _lastConnectivityCheck = now;
//     return _cachedOnline;
//   }
//
//   Future<bool> isOnline() async {
//     try {
//       final result = await InternetAddress.lookup('119.153.102.7')
//           .timeout(const Duration(seconds: 3));
//       return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
//     } on SocketException {
//       return false;
//     } on TimeoutException {
//       return false;
//     } catch (_) {
//       return false;
//     }
//   }
//
//   void invalidateConnectivityCache() {
//     _lastConnectivityCheck = null;
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:order_booking_app/Databases/util.dart';

import '../Databases/dp_helper.dart';

class LocationTrackingRepository {
  final DBHelper _dbHelper = DBHelper();

  // static const String _apiUrl = 'http://103.149.33.102:8001/location/bulk';

  static const String _apiUrl = 'http://119.153.102.7:8001/location/bulk';

  bool _isSyncing = false;
  bool _cachedOnline = false;
  DateTime? _lastConnectivityCheck;
  static const Duration _connectivityCacheDuration = Duration(seconds: 5);

  Future<void> insertAndSync(Map<String, dynamic> data) async {
    await _dbHelper.insertLocationTracking(data);
    debugPrint('💾 [TRACKING REPO] Saved locally: ${data['locationtracking_id']}');

    final online = await _isOnlineCached();
    if (!online) {
      debugPrint('📴 [TRACKING REPO] Offline — will sync later');
      return;
    }

    if (!_isSyncing) {
      await postDataFromDatabaseToAPI();
    }
  }

  Future<void> postDataFromDatabaseToAPI() async {
    if (_isSyncing) {
      debugPrint('⏳ [TRACKING REPO] Sync already in progress — skipping');
      return;
    }
    _isSyncing = true;

    try {
      final unpostedRows = await _dbHelper.getUnpostedLocationTracking();

      if (unpostedRows.isEmpty) {
        debugPrint('✅ [TRACKING REPO] No unposted rows — nothing to sync');
        return;
      }

      debugPrint('🚀 [TRACKING REPO] Syncing ${unpostedRows.length} rows via BULK...');

      final isOnlineNow = await isOnline();
      if (!isOnlineNow) {
        debugPrint('📴 [TRACKING REPO] Device is offline — will retry later');
        return;
      }

      // BULK only — no single-row fallback (causes duplicate rows on backend)
      final success = await _postBulkRows(unpostedRows);

      if (success) {
        final postedIds = unpostedRows
            .map((row) => row['locationtracking_id'] as String)
            .toList();
        await _dbHelper.markLocationTrackingAsPosted(postedIds);
        debugPrint('✅ [TRACKING REPO] Marked ${postedIds.length} rows as posted');
      } else {
        debugPrint('⚠️ [TRACKING REPO] Bulk failed — will retry on next sync');
      }
    } catch (e) {
      debugPrint('❌ [TRACKING REPO] postDataFromDatabaseToAPI error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _postBulkRows(List<Map<String, dynamic>> rows) async {
    try {
      final List<Map<String, dynamic>> records = rows.map((row) {
        double? latDouble;
        double? lngDouble;

        try {
          latDouble = double.tryParse(row['lat_in']?.toString() ?? '');
          lngDouble = double.tryParse(row['lng_in']?.toString() ?? '');
        } catch (e) {
          debugPrint('⚠️ [TRACKING REPO] Error parsing lat/lng: $e');
        }

        // ─────────────────────────────────────────────────────────────────
        // locationtracking_id is intentionally NOT sent to the server.
        // It is only used locally as the SQLite primary key and for
        // markLocationTrackingAsPosted() after a successful bulk sync.
        // Sending it was causing duplicate rows on the backend.
        // ─────────────────────────────────────────────────────────────────
        return {
          'locationtracking_id': row['locationtracking_id']?.toString() ?? '',  // ← ADD THIS
          'locationtracking_date': row['locationtracking_date']?.toString() ?? '',
          'locationtracking_time': row['locationtracking_time']?.toString() ?? '',
          'user_id': row['user_id']?.toString() ?? '',
          'company_code': row['company_code']?.toString() ?? '',
          'lat_in': latDouble ?? 0.0,
          'lng_in': lngDouble ?? 0.0,
          'booker_name': row['booker_name']?.toString() ?? '',
          'designation': row['designation']?.toString() ?? '',
          'posted': false,
        };
      }).toList();

      final requestBody = {'records': records};

      debugPrint('📡 [TRACKING REPO] BULK posting ${records.length} rows → $_apiUrl');
      if (records.isNotEmpty) {
        debugPrint('📡 Sample: ${records.first}');
      }

      final response = await http
          .post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      )
          .timeout(const Duration(seconds: 30));

      debugPrint('📡 BULK response status: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ [TRACKING REPO] BULK post successful');
        return true;
      }

      final preview = response.body.length > 300
          ? '${response.body.substring(0, 300)}...'
          : response.body;
      debugPrint('⚠️ [TRACKING REPO] BULK failed ${response.statusCode}: $preview');
      return false;
    } on SocketException catch (e) {
      debugPrint('📴 [TRACKING REPO] No internet for bulk post: $e');
      return false;
    } on TimeoutException catch (e) {
      debugPrint('⏱️ [TRACKING REPO] Timeout for bulk post: $e');
      return false;
    } catch (e) {
      debugPrint('❌ [TRACKING REPO] Unexpected error in bulk post: $e');
      return false;
    }
  }

  Future<bool> _isOnlineCached() async {
    final now = DateTime.now();
    if (_lastConnectivityCheck != null &&
        now.difference(_lastConnectivityCheck!) < _connectivityCacheDuration) {
      return _cachedOnline;
    }
    _cachedOnline = await isOnline();
    _lastConnectivityCheck = now;
    return _cachedOnline;
  }

  Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup('119.153.102.7')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  void invalidateConnectivityCache() {
    _lastConnectivityCheck = null;
  }
}