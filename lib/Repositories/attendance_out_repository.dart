
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Databases/dp_helper.dart';
import '../Databases/util.dart';
import '../Models/attendanceOut_model.dart';
import '../Services/ApiServices/api_service.dart';
import '../Services/ApiServices/serial_number_genterator.dart';
import '../Services/FirebaseServices/firebase_remote_config.dart';

class AttendanceOutRepository extends GetxService {
  DBHelper dbHelper = DBHelper();

  // Track posted IDs to prevent duplicate posting in the same session
  Set<String> _postedIds = {};

  Future<List<AttendanceOutModel>> getAttendanceOut() async {
    var dbClient = await dbHelper.db;
    List<Map> maps = await dbClient.query(attendanceOutTableName, columns: [
      'attendance_out_id',
      'attendance_out_date',
      'attendance_out_time',
      'user_id',
      'total_time',
      'lat_out',
      'lng_out',
      'total_distance',
      'address',
      'posted',
      'reason', // ✅ FIX: Added missing comma that caused 'posted' and 'reason' to merge into one broken column name
    ]);
    List<AttendanceOutModel> attendanceout = [];

    for (int i = 0; i < maps.length; i++) {
      attendanceout.add(AttendanceOutModel.fromMap(maps[i]));
    }

    debugPrint('📊 [REPO-OUT] Raw data from AttendanceOut database: ${maps.length} records');
    for (var map in maps) {
      debugPrint("   - ID: ${map['attendance_out_id']}, Posted: ${map['posted']}, Reason: ${map['reason']}");
    }
    return attendanceout;
  }

  Future<void> fetchAndSaveAttendanceOut() async {
    try {
      debugPrint('🔍 [REPO-OUT] Fetching from API: ${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.getApiUrlAttendanceOut}$user_id');

      List<dynamic> data = await ApiService.getData(
          '${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.getApiUrlAttendanceOut}$user_id'
      );

      var dbClient = await dbHelper.db;

      int savedCount = 0;
      for (var item in data) {
        try {
          item['posted'] = 1;
          AttendanceOutModel model = AttendanceOutModel.fromMap(item);

          List<Map> existing = await dbClient.query(
            attendanceOutTableName,
            where: 'attendance_out_id = ?',
            whereArgs: [model.attendance_out_id],
          );

          if (existing.isEmpty) {
            await dbClient.insert(attendanceOutTableName, model.toMap());
            savedCount++;
            debugPrint("✅ [REPO-OUT] Saved from API: ${model.attendance_out_id}");
          } else {
            debugPrint("⚠️ [REPO-OUT] Skipping duplicate from API: ${model.attendance_out_id}");
          }
        } catch (e) {
          debugPrint("❌ [REPO-OUT] Error saving item from API: $e");
        }
      }

      debugPrint("✅ [REPO-OUT] Fetched and saved $savedCount records from API");
    } catch (e) {
      debugPrint('❌ [REPO-OUT] Error fetching from API: $e');
    }
  }

  Future<List<AttendanceOutModel>> getUnPostedAttendanceOut() async {
    try {
      var dbClient = await dbHelper.db;
      List<Map> maps = await dbClient.query(
        attendanceOutTableName,
        where: 'posted = ?',
        whereArgs: [0],
      );

      List<AttendanceOutModel> attendanceOutModel =
      maps.map((map) => AttendanceOutModel.fromMap(map)).toList();

      debugPrint('📊 [REPO-OUT] Found ${attendanceOutModel.length} unposted records');
      for (var r in attendanceOutModel) {
        debugPrint("   - Unposted ID: ${r.attendance_out_id}, Reason: ${r.reason}");
      }

      return attendanceOutModel;
    } catch (e) {
      debugPrint('❌ [REPO-OUT] Error getting unposted records: $e');
      return [];
    }
  }

  /// ✅ FIX: postDataFromDatabaseToAPI now returns bool so callers know if anything was posted
  Future<bool> postDataFromDatabaseToAPI() async {
    debugPrint('🔄 [REPO-OUT] ===== STARTING POST TO API =====');
    bool anySuccess = false;

    try {
      if (!await isNetworkAvailable()) {
        debugPrint('📴 [REPO-OUT] Network not available. Skipping post.');
        return false;
      }

      var unPostedRecords = await getUnPostedAttendanceOut();

      if (unPostedRecords.isEmpty) {
        debugPrint('📭 [REPO-OUT] No unposted records to send');
        return false;
      }

      debugPrint('📤 [REPO-OUT] Attempting to post ${unPostedRecords.length} records');

      // Deduplicate by ID
      Map<String, AttendanceOutModel> uniqueRecords = {};
      for (var record in unPostedRecords) {
        if (record.attendance_out_id != null) {
          uniqueRecords[record.attendance_out_id.toString()] = record;
        }
      }

      debugPrint('🔍 [REPO-OUT] After deduplication: ${uniqueRecords.length} unique records');

      int successCount = 0;
      int failCount = 0;

      for (var record in uniqueRecords.values) {
        try {
          if (_postedIds.contains(record.attendance_out_id.toString())) {
            debugPrint('⚠️ [REPO-OUT] Skipping already-posted in this session: ${record.attendance_out_id}');
            continue;
          }

          if (record.attendance_out_id == null || record.attendance_out_id.toString().isEmpty) {
            debugPrint('❌ [REPO-OUT] Invalid record ID, skipping');
            continue;
          }

          debugPrint('📤 [REPO-OUT] Posting: ${record.attendance_out_id}, reason: ${record.reason}');

          bool posted = await _postSingleRecord(record);

          if (posted) {
            successCount++;
            anySuccess = true;
            record.posted = 1;
            await update(record);
            _postedIds.add(record.attendance_out_id.toString());
            debugPrint('✅ [REPO-OUT] Successfully posted: ${record.attendance_out_id}');
          } else {
            failCount++;
            debugPrint('❌ [REPO-OUT] Failed to post: ${record.attendance_out_id}');
          }

          await Future.delayed(const Duration(milliseconds: 100));

        } catch (e) {
          failCount++;
          debugPrint('❌ [REPO-OUT] Error posting ${record.attendance_out_id}: $e');
        }
      }

      debugPrint('📊 [REPO-OUT] Posting results: $successCount success, $failCount failed');
      await _cleanDuplicateRecords();

    } catch (e) {
      debugPrint('❌ [REPO-OUT] Error in postDataFromDatabaseToAPI: $e');
    }

    debugPrint('🔄 [REPO-OUT] ===== POST COMPLETED =====');
    return anySuccess;
  }

  Future<bool> _postSingleRecord(AttendanceOutModel record) async {
    int maxRetries = 2;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await Config.fetchLatestConfig();
        String apiUrl = '${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.postApiUrlAttendanceOut}';

        debugPrint('🌐 [REPO-OUT] Attempt $attempt: Posting to $apiUrl');

        var recordData = record.toMap();
        // ✅ FIX: Always include reason — this was missing, causing server to reject or mis-record
        recordData['reason'] = record.reason?.isNotEmpty == true ? record.reason : 'manual';

        debugPrint('📦 [REPO-OUT] Payload reason: ${recordData['reason']}, time: ${recordData['attendance_out_time']}');

        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
          body: jsonEncode(recordData),
        ).timeout(const Duration(seconds: 15));

        debugPrint('📡 [REPO-OUT] Response: ${response.statusCode}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint('✅ [REPO-OUT] Posted successfully: ${record.attendance_out_id}');
          return true;
        } else if (response.statusCode == 409) {
          // 409 Conflict — record already exists on server, treat as success
          debugPrint('⚠️ [REPO-OUT] Record already exists on server (409): ${record.attendance_out_id}');
          return true;
        } else {
          debugPrint('❌ [REPO-OUT] Server error ${response.statusCode}: ${response.body}');
          if (attempt < maxRetries) {
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      } catch (e) {
        debugPrint('❌ [REPO-OUT] Attempt $attempt failed: $e');
        if (attempt < maxRetries) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    return false;
  }

  Future<bool> checkIfExists(String attendanceId) async {
    try {
      var dbClient = await dbHelper.db;
      List<Map> existing = await dbClient.query(
        attendanceOutTableName,
        where: 'attendance_out_id = ?',
        whereArgs: [attendanceId],
        limit: 1,
      );
      return existing.isNotEmpty;
    } catch (e) {
      debugPrint('❌ [REPO-OUT] Error checking existence: $e');
      return false;
    }
  }

  /// ✅ FIX: add() now returns the row ID (>0 = inserted, 0 = duplicate skipped, -1 = error)
  /// Callers can check the return value to know if a DB insert actually happened.
  Future<int> add(AttendanceOutModel attendanceoutModel) async {
    try {
      var dbClient = await dbHelper.db;

      bool exists = await checkIfExists(attendanceoutModel.attendance_out_id.toString());
      if (exists) {
        debugPrint('⚠️ [REPO-OUT] Duplicate record found, skipping: ${attendanceoutModel.attendance_out_id}');
        return 0;
      }

      debugPrint('✅ [REPO-OUT] Adding new record: ${attendanceoutModel.attendance_out_id}, reason: ${attendanceoutModel.reason}');
      return await dbClient.insert(
          attendanceOutTableName,
          attendanceoutModel.toMap()
      );
    } catch (e) {
      debugPrint('❌ [REPO-OUT] Error adding record: $e');
      return -1;
    }
  }

  Future<int> update(AttendanceOutModel attendanceoutModel) async {
    try {
      var dbClient = await dbHelper.db;
      debugPrint('✏️ [REPO-OUT] Updating record: ${attendanceoutModel.attendance_out_id}');

      return await dbClient.update(
          attendanceOutTableName,
          attendanceoutModel.toMap(),
          where: 'attendance_out_id = ?',
          whereArgs: [attendanceoutModel.attendance_out_id]
      );
    } catch (e) {
      debugPrint('❌ [REPO-OUT] Error updating record: $e');
      rethrow;
    }
  }

  Future<int> delete(String id) async {
    try {
      var dbClient = await dbHelper.db;
      debugPrint('🗑️ [REPO-OUT] Deleting record: $id');

      return await dbClient.delete(
          attendanceOutTableName,
          where: 'attendance_out_id = ?',
          whereArgs: [id]
      );
    } catch (e) {
      debugPrint('❌ [REPO-OUT] Error deleting record: $e');
      rethrow;
    }
  }

  Future<void> serialNumberGeneratorApi() async {
    try {
      await Config.fetchLatestConfig();
      SharedPreferences prefs = await SharedPreferences.getInstance();

      final orderDetailsGenerator = SerialNumberGenerator(
        apiUrl: '${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.getApiUrlAttendanceOutSerial}$user_id',
        maxColumnName: 'max(attendance_out_id)',
        serialType: attendanceOutHighestSerial,
      );

      await orderDetailsGenerator.getAndIncrementSerialNumber();
      attendanceOutHighestSerial = orderDetailsGenerator.serialType;

      await prefs.setInt("attendanceOutHighestSerial", attendanceOutHighestSerial!);

      debugPrint('🔢 [REPO-OUT] Generated serial: $attendanceOutHighestSerial');
    } catch (e) {
      debugPrint('❌ [REPO-OUT] Error in serialNumberGeneratorApi: $e');
    }
  }

  Future<void> _cleanDuplicateRecords() async {
    try {
      var dbClient = await dbHelper.db;

      List<Map> allRecords = await dbClient.query(
        attendanceOutTableName,
        columns: ['attendance_out_id'],
      );

      Set<String> uniqueIds = {};
      List<String> duplicateIds = [];

      for (var record in allRecords) {
        String id = record['attendance_out_id'].toString();
        if (uniqueIds.contains(id)) {
          duplicateIds.add(id);
        } else {
          uniqueIds.add(id);
        }
      }

      for (String duplicateId in duplicateIds) {
        debugPrint('⚠️ [REPO-OUT] Found duplicates for ID: $duplicateId');

        List<Map> duplicates = await dbClient.query(
          attendanceOutTableName,
          where: 'attendance_out_id = ?',
          whereArgs: [duplicateId],
        );

        if (duplicates.length > 1) {
          for (int i = 1; i < duplicates.length; i++) {
            await dbClient.delete(
              attendanceOutTableName,
              where: 'rowid = ?',
              whereArgs: [duplicates[i]['rowid']],
            );
          }
          debugPrint('✅ [REPO-OUT] Cleaned ${duplicates.length - 1} duplicates for ID: $duplicateId');
        }
      }

    } catch (e) {
      debugPrint('❌ [REPO-OUT] Error cleaning duplicates: $e');
    }
  }

  Future<AttendanceOutModel?> getRecordById(String attendanceId) async {
    try {
      var dbClient = await dbHelper.db;
      List<Map> maps = await dbClient.query(
        attendanceOutTableName,
        where: 'attendance_out_id = ?',
        whereArgs: [attendanceId],
      );

      if (maps.isNotEmpty) {
        return AttendanceOutModel.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('❌ [REPO-OUT] Error getting record by ID: $e');
      return null;
    }
  }

  void clearPostedCache() {
    _postedIds.clear();
    debugPrint('🧹 [REPO-OUT] Cleared posted IDs cache');
  }

  Future<void> markAsPosted(String attendanceId) async {
    try {
      var record = await getRecordById(attendanceId);
      if (record != null) {
        record.posted = 1;
        await update(record);
        debugPrint('✅ [REPO-OUT] Manually marked as posted: $attendanceId');
      }
    } catch (e) {
      debugPrint('❌ [REPO-OUT] Error marking as posted: $e');
    }
  }
}