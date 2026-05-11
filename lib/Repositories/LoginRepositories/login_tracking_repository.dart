import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../Databases/dp_helper.dart';
import '../../Models/LoginModels/login_tracking_model.dart';

class LoginTrackingRepository extends GetxService {
  final DBHelper dbHelper = DBHelper();

  static const String apiUrl =
      "https://cloud.metaxperts.net:8443/erp/valor_trading/logintrackingpost/post/";

  // =====================================================================
  // LOCAL DATABASE OPERATIONS
  // =====================================================================

  Future<int> saveLoginTrackingLocally(LoginTrackingModel model) async {
    try {
      final result = await dbHelper.insertLoginTracking(model.toMap());
      debugPrint('✅ [LoginTrackingRepo] Saved locally: ${model.id}');
      return result;
    } catch (e) {
      debugPrint('❌ [LoginTrackingRepo] Error saving locally: $e');
      return 0;
    }
  }

  Future<List<LoginTrackingModel>> getUnpostedLoginTracking() async {
    try {
      final records = await dbHelper.getUnpostedLoginTracking();
      return records.map((r) => LoginTrackingModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('❌ [LoginTrackingRepo] Error getting unposted: $e');
      return [];
    }
  }

  Future<List<LoginTrackingModel>> getAllLoginTracking() async {
    try {
      final records = await dbHelper.getAllLoginTracking();
      return records.map((r) => LoginTrackingModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('❌ [LoginTrackingRepo] Error getting all: $e');
      return [];
    }
  }

  Future<void> markAsPosted(List<String> ids) async {
    await dbHelper.markLoginTrackingAsPosted(ids);
  }

  Future<List<LoginTrackingModel>> getLoginTrackingByUserAndDate(
      String userId,
      String date,
      ) async {
    try {
      final records =
      await dbHelper.getLoginTrackingByUserAndDate(userId, date);
      return records.map((r) => LoginTrackingModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('❌ [LoginTrackingRepo] Error getting by user/date: $e');
      return [];
    }
  }

  Future<void> deleteLoginTrackingByDate(String date) async {
    await dbHelper.deleteLoginTrackingByDate(date);
  }

  Future<Map<String, dynamic>> getLoginTrackingStats() async {
    return await dbHelper.getLoginTrackingStats();
  }

  // =====================================================================
  // API OPERATIONS
  // =====================================================================

  Future<bool> postToApi(LoginTrackingModel model) async {
    try {
      final payload = {
        'id': model.id,
        'booker_name': model.bookerName,
        'user_id': model.userId,
        'login_time': model.loginTime,
        'login_date': model.loginDate,
        'designation': model.designation,
        'company_code': model.companyCode,
        'device_info': model.deviceInfo,      // ✅ added
        'android_version': model.androidVersion, // ✅ added
        'device_id': model.deviceId,          // ✅ added
      };

      debugPrint('📤 [LoginTrackingRepo] Posting to: $apiUrl');
      debugPrint('📤 [LoginTrackingRepo] Payload: $payload');

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      debugPrint(
          '📥 [LoginTrackingRepo] Response status: ${response.statusCode}');
      debugPrint('📥 [LoginTrackingRepo] Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final responseBody = jsonDecode(response.body);
          if (responseBody['status'] == 'success' ||
              responseBody['success'] == true) {
            debugPrint('✅ [LoginTrackingRepo] API post successful');
            return true;
          }
        } catch (e) {
          debugPrint(
              '⚠️ [LoginTrackingRepo] Non-JSON response, assuming success');
          return true;
        }
        return true;
      } else {
        debugPrint(
            '❌ [LoginTrackingRepo] Failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ [LoginTrackingRepo] API error: $e');
      return false;
    }
  }

  Future<LoginTrackingModel> createAndPostLoginRecord({
    required String userId,
    required String bookerName,
    required String designation,
    required String companyCode,
  }) async {
    final now = DateTime.now();
    final loginDate = now.toIso8601String().split('T')[0];
    final loginTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    final id = 'login_${userId}_${now.millisecondsSinceEpoch}';

    // Capture device information
    final deviceInfoPlugin = DeviceInfoPlugin();
    String deviceInfoStr = 'Unknown';
    String androidVersionStr = 'Unknown';
    String deviceIdStr = 'Unknown';

    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceInfoStr = '${androidInfo.manufacturer} ${androidInfo.model}';
        androidVersionStr = androidInfo.version.release;
        deviceIdStr = androidInfo.id;               // ✅ correct field
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceInfoStr = '${iosInfo.name} (iOS ${iosInfo.systemVersion})';
        androidVersionStr = iosInfo.systemVersion;
        deviceIdStr = iosInfo.identifierForVendor ?? 'Unknown';
      }
    } catch (e) {
      debugPrint('⚠️ Failed to get device info: $e');
    }

    final model = LoginTrackingModel(
      id: id,
      bookerName: bookerName,
      userId: userId,
      loginTime: loginTime,
      loginDate: loginDate,
      designation: designation,
      companyCode: companyCode,
      posted: 0,
      deviceInfo: deviceInfoStr,
      androidVersion: androidVersionStr,
      deviceId: deviceIdStr,
    );

    await saveLoginTrackingLocally(model);
    final apiSuccess = await postToApi(model);

    if (apiSuccess) {
      model.posted = 1;
      await markAsPosted([model.id!]);
    }
    return model;
  }

  Future<Map<String, dynamic>> syncUnpostedRecords() async {
    try {
      final unpostedRecords = await getUnpostedLoginTracking();

      if (unpostedRecords.isEmpty) {
        debugPrint('📋 [LoginTrackingRepo] No unposted records to sync');
        return {'success': true, 'message': 'No records to sync', 'synced': 0};
      }

      debugPrint(
          '📤 [LoginTrackingRepo] Syncing ${unpostedRecords.length} records');

      int successCount = 0;
      int failureCount = 0;
      List<String> successIds = [];
      List<String> failedIds = [];

      for (var record in unpostedRecords) {
        debugPrint('🔄 [LoginTrackingRepo] Syncing record: ${record.id}');
        final success = await postToApi(record);

        if (success) {
          successCount++;
          successIds.add(record.id!);
          debugPrint(
              '✅ [LoginTrackingRepo] Record ${record.id} synced successfully');
        } else {
          failureCount++;
          failedIds.add(record.id!);
          debugPrint(
              '❌ [LoginTrackingRepo] Record ${record.id} sync failed');
        }
      }

      if (successIds.isNotEmpty) {
        await markAsPosted(successIds);
        debugPrint(
            '✅ [LoginTrackingRepo] Marked ${successIds.length} records as posted');
      }

      debugPrint(
          '📊 [LoginTrackingRepo] Sync complete - Success: $successCount, Failed: $failureCount');

      return {
        'success': true,
        'synced': successCount,
        'failed': failureCount,
        'total': unpostedRecords.length,
        'successIds': successIds,
        'failedIds': failedIds,
      };
    } catch (e) {
      debugPrint('❌ [LoginTrackingRepo] Sync error: $e');
      return {'success': false, 'error': e.toString(), 'synced': 0};
    }
  }

  Future<Map<String, dynamic>> retryFailedRecords() async {
    try {
      final unpostedRecords = await getUnpostedLoginTracking();

      if (unpostedRecords.isEmpty) {
        return {
          'success': true,
          'message': 'No failed records to retry',
          'synced': 0
        };
      }

      debugPrint(
          '🔄 [LoginTrackingRepo] Retrying ${unpostedRecords.length} failed records');

      int successCount = 0;
      List<String> successIds = [];

      for (var record in unpostedRecords) {
        final success = await postToApi(record);
        if (success) {
          successCount++;
          successIds.add(record.id!);
        }
      }

      if (successIds.isNotEmpty) {
        await markAsPosted(successIds);
      }

      return {
        'success': true,
        'retried': unpostedRecords.length,
        'synced': successCount,
        'failed': unpostedRecords.length - successCount,
      };
    } catch (e) {
      debugPrint('❌ [LoginTrackingRepo] Retry error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}