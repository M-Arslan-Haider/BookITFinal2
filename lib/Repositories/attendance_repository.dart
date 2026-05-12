
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Databases/dp_helper.dart';
import '../Databases/util.dart';
import '../Models/attendance_Model.dart';
import '../Services/ApiServices/api_service.dart';
import '../Services/ApiServices/serial_number_genterator.dart';
import '../Services/FirebaseServices/firebase_remote_config.dart';

class AttendanceRepository {
  DBHelper dbHelper = DBHelper();

  Future<List<AttendanceModel>> getAttendance() async {
    var dbClient = await dbHelper.db;
    List<Map> maps = await dbClient.query(attendanceTableName, columns: [
      'attendance_in_id',
      'attendance_in_date',
      'attendance_in_time',
      'user_id',
      'lat_in',
      'lng_in',
      'booker_name',
      'designation',
      'city',
      'address',
      'posted',
      'battery',  // ✅ ADD THIS
    ]);
    List<AttendanceModel> attendance = [];
    for (int i = 0; i < maps.length; i++) {
      attendance.add(AttendanceModel.fromMap(maps[i]));
    }

    debugPrint('Raw data from Attendance database:');

    for (var map in maps) {
      debugPrint("$map");
    }
    return attendance;
  }

  Future<void> fetchAndSaveAttendance() async {
    debugPrint(
        '${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.getApiUrlAttendanceIn}$user_id');
    List<dynamic> data = await ApiService.getData(
        '${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.getApiUrlAttendanceIn}$user_id');
    var dbClient = await dbHelper.db;

    // ✅ Load last saved serial number to prevent duplicates
    await loadLatestSerial();

    SharedPreferences prefs = await SharedPreferences.getInstance();

    for (var item in data) {
      item['posted'] = 1;
      AttendanceModel model = AttendanceModel.fromMap(item);

      // ✅ Increment locally to maintain unique IDs
      attendanceInHighestSerial = (attendanceInHighestSerial ?? 0) + 1;
      model.attendance_in_id = attendanceInHighestSerial.toString();

      await add(model);

      // ✅ Save updated serial number persistently
      await prefs.setInt("attendanceInHighestSerial", attendanceInHighestSerial!);

      debugPrint('✅ Attendance saved locally with ID: ${model.attendance_in_id}');
    }
  }

  Future<List<AttendanceModel>> getUnPostedAttendanceIn() async {
    var dbClient = await dbHelper.db;
    List<Map> maps = await dbClient.query(
      attendanceTableName,
      where: 'posted = ?',
      whereArgs: [0],
    );
    List<AttendanceModel> attendanceIn =
    maps.map((map) => AttendanceModel.fromMap(map)).toList();
    return attendanceIn;
  }

  Future<void> postDataFromDatabaseToAPI() async {
    try {
      var unPostedShops = await getUnPostedAttendanceIn();

      if (await isNetworkAvailable()) {
        for (var shop in unPostedShops) {
          try {
            await postShopToAPI(shop);
            shop.posted = 1;
            await update(shop);
            debugPrint(
                'Shop with id ${shop.attendance_in_id} posted and updated in local database.');
          } catch (e) {
            if (kDebugMode) {
              print('Failed to post shop with id ${shop.attendance_in_id}: $e');
            }
          }
        }
      } else {
        if (kDebugMode) {
          print('Network not available. Unposted shops will remain local.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching unposted shops: $e');
      }
    }
  }

  Future<void> postShopToAPI(AttendanceModel shop) async {
    try {
      await Config.fetchLatestConfig();
      String apiUrl =
          '${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.postApiUrlAttendanceIn}';
      debugPrint('🔄 [REPO-IN] Posting to: $apiUrl');

      var shopData = shop.toMap();
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(shopData),
      );

      debugPrint('📡 [REPO-IN] Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ [REPO-IN] Data posted successfully: ${shop.attendance_in_id}');
        shop.posted = 1;
        await update(shop);
        debugPrint('✅ [REPO-IN] Marked as posted: ${shop.attendance_in_id}');
      } else {
        debugPrint('❌ [REPO-IN] Server error: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ [REPO-IN] Error posting data: $e');
    }
  }

  Future<int> add(AttendanceModel attendanceModel) async {
    var dbClient = await dbHelper.db;

    // ✅ Prevent duplicate insertion
    var existing = await dbClient.query(
      attendanceTableName,
      where: 'attendance_in_id = ?',
      whereArgs: [attendanceModel.attendance_in_id],
    );
    if (existing.isNotEmpty) {
      debugPrint('⚠️ Skipping duplicate: ${attendanceModel.attendance_in_id}');
      return 0;
    }

    return await dbClient.insert(attendanceTableName, attendanceModel.toMap());
  }

  Future<int> update(AttendanceModel attendanceModel) async {
    var dbClient = await dbHelper.db;
    return await dbClient.update(attendanceTableName, attendanceModel.toMap(),
        where: 'attendance_in_id = ?',
        whereArgs: [attendanceModel.attendance_in_id]);
  }

  Future<int> delete(String id) async {
    var dbClient = await dbHelper.db;
    return await dbClient
        .delete(attendanceTableName, where: 'attendance_in_id = ?', whereArgs: [id]);
  }

  // Future<void> serialNumberGeneratorApi() async {
  //   await Config.fetchLatestConfig();
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   final orderDetailsGenerator = SerialNumberGenerator(
  //     apiUrl:
  //     '${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.getApiUrlAttendanceInSerial}$user_id',
  //     maxColumnName: 'max(attendance_in_id)',
  //     serialType: attendanceInHighestSerial,
  //   );
  //   await orderDetailsGenerator.getAndIncrementSerialNumber();
  //   attendanceInHighestSerial = orderDetailsGenerator.serialType;
  //   await prefs.setInt("attendanceInHighestSerial", attendanceInHighestSerial!);
  // }

  Future<void> serialNumberGeneratorApi() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // 1. Get max serial from SERVER (survives reinstall)
      int serverSerial = await fetchMaxSerialFromServer();

      // 2. Get local serial from SharedPreferences (offline fallback)
      int localSerial = prefs.getInt('attendanceInHighestSerial') ?? 0;

      // 3. Use whichever is HIGHER — server always wins after reinstall
      int maxSerial = serverSerial > localSerial ? serverSerial : localSerial;

      // 4. New serial = max + 1
      attendanceInHighestSerial = maxSerial + 1;

      // 5. Save locally so offline works too
      await prefs.setInt('attendanceInHighestSerial', attendanceInHighestSerial!);

      debugPrint('🔢 [REPO-IN] Server=$serverSerial | Local=$localSerial '
          '→ New serial=${attendanceInHighestSerial}');

    } catch (e) {
      debugPrint('❌ [REPO-IN] serialNumberGeneratorApi error: $e');
      // Fallback: increment local serial only
      SharedPreferences prefs = await SharedPreferences.getInstance();
      attendanceInHighestSerial = (prefs.getInt('attendanceInHighestSerial') ?? 0) + 1;
      await prefs.setInt('attendanceInHighestSerial', attendanceInHighestSerial!);
    }
  }


  // ✅ Added: Load saved serial on startup or before saving
  Future<void> loadLatestSerial() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    attendanceInHighestSerial = prefs.getInt("attendanceInHighestSerial") ?? 0;
    debugPrint('🔢 Loaded latest serial: $attendanceInHighestSerial');
  }

  /// Calls AttendanceInSerialGetUrl → gets max existing serial from server
  /// Returns 0 if no records exist or on error
  Future<int> fetchMaxSerialFromServer() async {
    try {
      await Config.fetchLatestConfig();
      final String url =
          '${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}'
          '${Config.getApiUrlAttendanceInSerial}$user_id';

      debugPrint('📡 [REPO-IN] fetchMaxSerial → $url');

      final response = await http
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint('📡 [REPO-IN] fetchMaxSerial status: ${response.statusCode}');
      debugPrint('📡 [REPO-IN] fetchMaxSerial body: ${response.body}');

      if (response.statusCode != 200) return 0;

      final decoded = jsonDecode(response.body);

      String? maxId;
      if (decoded is Map<String, dynamic>) {
        final items = decoded['items'];
        if (items is List && items.isNotEmpty && items.first is Map) {
          maxId = (items.first as Map)['max(attendance_in_id)']?.toString();
        }
      }

      if (maxId == null || maxId.isEmpty || maxId == 'null') {
        debugPrint('ℹ️ [REPO-IN] No records on server → serial starts at 0');
        return 0;
      }

      // Parse the last numeric part of the ID
      final parts = maxId.split('-');
      final serial = int.tryParse(parts.last.trim()) ?? 0;
      debugPrint('✅ [REPO-IN] Server maxId=$maxId → serial=$serial');
      return serial;

    } catch (e) {
      debugPrint('⚠️ [REPO-IN] fetchMaxSerial error: $e');
      return 0;
    }
  }
}
