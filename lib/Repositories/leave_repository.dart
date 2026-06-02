
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:order_booking_app/Databases/util.dart';
import 'package:order_booking_app/Databases/dp_helper.dart';
import '../Models/leave_model.dart';
import '../Services/FirebaseServices/firebase_remote_config.dart';
import 'package:http_parser/http_parser.dart';

class LeaveRepository {
  final DBHelper dbHelper = DBHelper();

  Future<bool> submitLeave(LeaveModel model) async {
    try {
      print('🔄 Starting leave submission...');
      print('🔗 API URL: ${Config.postApiUrlLeaveForm}');

      // First save to local database
      final dbResult = await dbHelper.insertLeave(model);
      if (dbResult > 0) {
        print('✅ Leave saved locally with ID: $dbResult');
      } else {
        print('❌ Failed to save locally');
        return false;
      }

      // Get the latest leave ID for this booker
      final latestLeaves = await dbHelper.getLeavesByBookerId(model.bookerId);
      String? generatedLeaveId;

      if (latestLeaves.isNotEmpty) {
        generatedLeaveId = latestLeaves.first['leave_id']?.toString();
        print('📋 Using leave ID: $generatedLeaveId');
      }

      final isOnline = await isNetworkAvailable();
      if (!isOnline) {
        print('📴 No internet - saved locally only');
        return true;
      }

      // Try ALL methods in sequence
      print('🔄 Trying submission methods...');

      // Method 1: Main method (Most reliable)
      print('\n=== METHOD 1: MAIN MULTIPART ===');
      final method1Success = await _submitLeaveMethod1(model, generatedLeaveId);
      if (method1Success) {
        print('✅ Submission successful via Method 1');
        return true;
      }

      // Method 2: Backup method
      print('\n=== METHOD 2: BACKUP JSON ===');
      final method2Success = await _submitLeaveMethod2(model, generatedLeaveId);
      if (method2Success) {
        print('✅ Submission successful via Method 2');
        return true;
      }

      print('❌ All methods failed');
      return false;

    } catch (e) {
      print('❌ Error in submitLeave: $e');
      return false;
    }
  }

  // ==================== MAIN METHOD: MULTIPART FORM ====================
  Future<bool> _submitLeaveMethod1(LeaveModel model, String? generatedLeaveId) async {
    try {
      String fullUrl = "${Config.postApiUrlLeaveForm}";
      print('🌐 Method 1: Multipart to: $fullUrl');

      var request = http.MultipartRequest('POST', Uri.parse(fullUrl));

      // ========== CRITICAL PART: ADD ALL TEXT FIELDS ==========
      // Use both UPPER_CASE and lower_case variations to ensure compatibility

      // UPPER_CASE (Oracle standard)
      request.fields['ID'] = model.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      request.fields['LEAVE_ID'] = generatedLeaveId ?? '';
      request.fields['BOOKER_ID'] = model.bookerId;
      request.fields['BOOKER_NAME'] = model.bookerName ?? '';
      request.fields['LEAVE_TYPE'] = model.leaveType;
      request.fields['START_DATE'] = _formatDateForServer(model.startDate);
      request.fields['END_DATE'] = _formatDateForServer(model.endDate);
      request.fields['TOTAL_DAYS'] = model.totalDays.toString();
      request.fields['IS_HALF_DAY'] = model.isHalfDay ? '1' : '0';
      request.fields['REASON'] = model.reason;
      request.fields['APPLICATION_DATE'] = model.applicationDate ?? _getFormattedDate();
      request.fields['APPLICATION_TIME'] = model.applicationTime ?? _getFormattedTime();
      request.fields['STATUS'] = model.status ?? 'pending';
      request.fields['POSTED'] = (model.posted ?? 0).toString();
      request.fields['ATTACHMENT_IMAGE'] = model.attachmentImage ?? '';

      // Lower_case (for some servers)
      request.fields['id'] = model.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      request.fields['leave_id'] = generatedLeaveId ?? '';
      request.fields['booker_id'] = model.bookerId;
      request.fields['booker_name'] = model.bookerName ?? '';
      request.fields['leave_type'] = model.leaveType;
      request.fields['start_date'] = _formatDateForServer(model.startDate);
      request.fields['end_date'] = _formatDateForServer(model.endDate);
      request.fields['total_days'] = model.totalDays.toString();
      request.fields['is_half_day'] = model.isHalfDay ? '1' : '0';
      request.fields['reason'] = model.reason;
      request.fields['application_date'] = model.applicationDate ?? _getFormattedDate();
      request.fields['application_time'] = model.applicationTime ?? _getFormattedTime();
      request.fields['status'] = model.status ?? 'pending';
      request.fields['posted'] = (model.posted ?? 0).toString();
      request.fields['attachment_image'] = model.attachmentImage ?? '';

      // CamelCase (alternative)
      request.fields['BookerId'] = model.bookerId;
      request.fields['BookerName'] = model.bookerName ?? '';
      request.fields['LeaveType'] = model.leaveType;
      request.fields['StartDate'] = _formatDateForServer(model.startDate);
      request.fields['EndDate'] = _formatDateForServer(model.endDate);
      request.fields['Reason'] = model.reason;

      // ========== ADD FILE ATTACHMENT ==========
      if (model.attachmentData != null && model.attachmentData!.isNotEmpty) {
        String filename = 'leave_${model.bookerId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        // Try multiple field names for file
        request.files.add(
            http.MultipartFile.fromBytes(
              'ATTACHMENT_DATA', // Primary field name
              model.attachmentData!,
              filename: filename,
              contentType: MediaType('image', 'jpeg'),
            )
        );

        // Alternative field names
        request.files.add(
            http.MultipartFile.fromBytes(
              'attachment_data', // lowercase
              model.attachmentData!,
              filename: filename,
              contentType: MediaType('image', 'jpeg'),
            )
        );

        request.files.add(
            http.MultipartFile.fromBytes(
              'file', // generic
              model.attachmentData!,
              filename: filename,
              contentType: MediaType('image', 'jpeg'),
            )
        );

        print('📎 Added file: $filename (${model.attachmentData!.length} bytes)');
      } else {
        print('📎 No attachment to upload');
      }

      // ========== DEBUG LOGGING ==========
      print('📡 TEXT FIELDS being sent:');
      request.fields.forEach((key, value) {
        if (value.isNotEmpty && value != 'null') {
          print('   "$key" = "$value"');
        }
      });
      print('📡 Total text fields: ${request.fields.length}');
      print('📡 Files count: ${request.files.length}');

      // ========== SEND REQUEST ==========
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📡 Response Status: ${response.statusCode}');
      print('📡 Response Headers: ${response.headers}');
      print('📡 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Method 1 successful!');

        // Parse response to check for success
        try {
          final jsonResponse = jsonDecode(response.body);
          print('📡 Parsed JSON Response: $jsonResponse');

          // Check server response message
          if (jsonResponse is Map) {
            if (jsonResponse.containsKey('success') && jsonResponse['success'] == true) {
              print('🎉 Server confirmed success');
            } else if (jsonResponse.containsKey('message')) {
              print('📝 Server message: ${jsonResponse['message']}');
            }
          }
        } catch (e) {
          print('📡 Response is not JSON, but success status received');
        }

        // Mark as posted in local DB
        if (generatedLeaveId != null) {
          await dbHelper.markLeaveAsPosted(generatedLeaveId);
          print('📝 Marked leave as posted in local DB');
        }

        return true;
      } else {
        print('❌ Server returned error: ${response.statusCode}');
        print('❌ Error response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Method 1 error: $e');
      print('❌ Stack trace: ${e.toString()}');
      return false;
    }
  }

  // ==================== BACKUP METHOD: JSON ====================
  Future<bool> _submitLeaveMethod2(LeaveModel model, String? generatedLeaveId) async {
    try {
      String fullUrl = "${Config.postApiUrlLeaveForm}";
      print('🌐 Method 2: JSON to: $fullUrl');

      Map<String, dynamic> jsonData = {
        // UPPER_CASE
        "ID": model.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        "LEAVE_ID": generatedLeaveId ?? "",
        "BOOKER_ID": model.bookerId,
        "BOOKER_NAME": model.bookerName ?? "",
        "LEAVE_TYPE": model.leaveType,
        "START_DATE": _formatDateForServer(model.startDate),
        "END_DATE": _formatDateForServer(model.endDate),
        "TOTAL_DAYS": model.totalDays,
        "IS_HALF_DAY": model.isHalfDay ? 1 : 0,
        "REASON": model.reason,
        "APPLICATION_DATE": model.applicationDate ?? _getFormattedDate(),
        "APPLICATION_TIME": model.applicationTime ?? _getFormattedTime(),
        "STATUS": model.status ?? "pending",
        "POSTED": model.posted ?? 0,
        "ATTACHMENT_IMAGE": model.attachmentImage ?? "",

        // Lower_case
        "id": model.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        "leave_id": generatedLeaveId ?? "",
        "booker_id": model.bookerId,
        "booker_name": model.bookerName ?? "",
        "leave_type": model.leaveType,
        "start_date": _formatDateForServer(model.startDate),
        "end_date": _formatDateForServer(model.endDate),
        "total_days": model.totalDays,
        "is_half_day": model.isHalfDay ? 1 : 0,
        "reason": model.reason,
        "application_date": model.applicationDate ?? _getFormattedDate(),
        "application_time": model.applicationTime ?? _getFormattedTime(),
        "status": model.status ?? "pending",
        "posted": model.posted ?? 0,
        "attachment_image": model.attachmentImage ?? "",
      };

      // Add base64 image if exists
      if (model.attachmentData != null && model.attachmentData!.isNotEmpty) {
        jsonData["ATTACHMENT_DATA"] = base64Encode(model.attachmentData!);
        jsonData["attachment_data"] = base64Encode(model.attachmentData!);
        print('📎 Added base64 image (${model.attachmentData!.length} bytes)');
      }

      print('📡 JSON Data being sent:');
      jsonData.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty && value.toString() != 'null') {
          print('   "$key": "$value"');
        }
      });

      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(jsonData),
      );

      print('📡 Response: ${response.statusCode}');
      print('📡 Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Method 2 successful!');
        if (generatedLeaveId != null) {
          await dbHelper.markLeaveAsPosted(generatedLeaveId);
        }
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Method 2 error: $e');
      return false;
    }
  }

  // ==================== IMPROVED DATE FORMATTING ====================
  String _formatDateForServer(String dateString) {
    try {
      // Remove time part if exists
      String dateOnly = dateString.split(' ')[0].split('T')[0];

      // Parse to ensure proper format
      List<String> parts = dateOnly.split('-');
      if (parts.length == 3) {
        int year = int.tryParse(parts[0]) ?? DateTime.now().year;
        int month = int.tryParse(parts[1]) ?? DateTime.now().month;
        int day = int.tryParse(parts[2]) ?? DateTime.now().day;

        // Return in YYYY-MM-DD format
        return "${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
      }

      return dateOnly;
    } catch (e) {
      print('⚠️ Date formatting error for "$dateString": $e');
      return dateString;
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    return "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  String _getFormattedTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
  }

  // ==================== SYNC PENDING LEAVES ====================
  Future<void> syncPendingLeaves() async {
    try {
      final isOnline = await isNetworkAvailable();
      if (!isOnline) {
        print('📴 No internet - cannot sync');
        return;
      }

      final pendingLeaves = await dbHelper.getPendingLeaves();
      if (pendingLeaves.isEmpty) {
        print('📭 No pending leaves to sync');
        return;
      }

      print('🔄 Syncing ${pendingLeaves.length} pending leaves...');

      int successCount = 0;
      for (var leave in pendingLeaves) {
        try {
          print('\n--- Syncing Leave ID: ${leave['leave_id']} ---');

          // Get attachment data if exists
          Uint8List? attachmentData;
          if (leave['has_attachment'] == 1) {
            attachmentData = await dbHelper.getLeaveAttachment(leave['leave_id'].toString());
            print('📎 Found attachment: ${attachmentData?.length ?? 0} bytes');
          }

          final model = LeaveModel(
            id: leave['id']?.toString(),
            leaveId: leave['leave_id']?.toString(),
            bookerId: leave['booker_id'].toString(),
            bookerName: leave['booker_name']?.toString(),
            leaveType: leave['leave_type'].toString(),
            startDate: leave['start_date'].toString(),
            endDate: leave['end_date'].toString(),
            totalDays: leave['total_days'] as int,
            isHalfDay: leave['is_half_day'] == 1,
            reason: leave['reason'].toString(),
            attachmentData: attachmentData,
            attachmentImage: leave['attachment_image']?.toString(),
            applicationDate: leave['application_date']?.toString(),
            applicationTime: leave['application_time']?.toString(),
            status: leave['status']?.toString(),
            posted: leave['posted'] as int?,
          );

          // Try main method first
          bool success = await _submitLeaveMethod1(model, leave['leave_id']?.toString());

          if (!success) {
            // Try backup method
            success = await _submitLeaveMethod2(model, leave['leave_id']?.toString());
          }

          if (success) {
            successCount++;
            print('✅ Successfully synced leave: ${leave['leave_id']}');
          } else {
            print('❌ Failed to sync leave: ${leave['leave_id']}');
          }
        } catch (e) {
          print('🚨 Error syncing ${leave['leave_id']}: $e');
        }
      }

      print('\n✅ Sync completed: $successCount/${pendingLeaves.length} leaves synced successfully');

    } catch (e) {
      print('❌ Sync error: $e');
    }
  }

  // ==================== OTHER METHODS ====================
  Future<List<Map<String, dynamic>>> getMyLeaves(String bookerId) async {
    return await dbHelper.getLeavesByBookerId(bookerId);
  }

  Future<List<Map<String, dynamic>>> getPendingLeaves() async {
    return await dbHelper.getPendingLeaves();
  }

  // ==================== TEST ENDPOINT ====================
  Future<Map<String, dynamic>> testServerConnection() async {
    try {
      print('🔍 Testing server connection...');

      // Test GET request
      final getResponse = await http.get(
        Uri.parse(Config.postApiUrlLeaveForm),
        headers: {'Accept': 'application/json'},
      );

      print('📡 GET Test Status: ${getResponse.statusCode}');
      print('📡 GET Test Headers: ${getResponse.headers}');
      print('📡 GET Test Body (first 500 chars): ${getResponse.body.length > 500 ? getResponse.body.substring(0, 500) + '...' : getResponse.body}');

      return {
        'status': getResponse.statusCode,
        'body': getResponse.body,
        'headers': getResponse.headers.toString(),
      };
    } catch (e) {
      print('❌ Test connection error: $e');
      return {'error': e.toString()};
    }
  }

  // ==================== VALIDATE DATA ====================
  Future<bool> validateLeaveData(LeaveModel model) async {
    try {
      // Check required fields
      if (model.bookerId.isEmpty) {
        print('❌ Validation failed: Booker ID is empty');
        return false;
      }

      if (model.leaveType.isEmpty) {
        print('❌ Validation failed: Leave Type is empty');
        return false;
      }

      if (model.startDate.isEmpty) {
        print('❌ Validation failed: Start Date is empty');
        return false;
      }

      if (model.endDate.isEmpty) {
        print('❌ Validation failed: End Date is empty');
        return false;
      }

      if (model.reason.isEmpty) {
        print('❌ Validation failed: Reason is empty');
        return false;
      }

      // Validate dates
      try {
        final start = DateTime.parse(_formatDateForServer(model.startDate));
        final end = DateTime.parse(_formatDateForServer(model.endDate));

        if (end.isBefore(start)) {
          print('❌ Validation failed: End date is before start date');
          return false;
        }
      } catch (e) {
        print('❌ Validation failed: Invalid date format');
        return false;
      }

      print('✅ Data validation passed');
      return true;
    } catch (e) {
      print('❌ Validation error: $e');
      return false;
    }
  }
}