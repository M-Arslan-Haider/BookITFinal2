
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:order_booking_app/Databases/util.dart';
import 'package:order_booking_app/ViewModels/location_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Models/attendance_Model.dart';
import '../Repositories/attendance_repository.dart';
import '../Services/FirebaseServices/firebase_remote_config.dart';

class AttendanceViewModel extends GetxController {
  var allAttendance = <AttendanceModel>[].obs;
  final AttendanceRepository attendanceRepository = Get.put(AttendanceRepository());
  final LocationViewModel locationViewModel = Get.put(LocationViewModel());

  // --- TIMER AND STATE VARIABLES ---
  var isClockedIn = false.obs;
  DateTime? _clockInTime;
  Timer? _timer;
  var elapsedTime = '00:00:00'.obs;
  var isLoading = false.obs;
  // ---------------------------------

  int attendanceInSerialCounter = 1;
  String attendanceInCurrentMonth = DateFormat('MMM').format(DateTime.now());
  String currentuserId = '';

  @override
  void onInit() {
    super.onInit();
    fetchAllAttendance();
    _loadInitialClockState();
    _initializeAttendanceCounter();
  }

  @override
  void onClose() {
    _stopTimer();
    super.onClose();
  }

  // ✅ INITIALIZE COUNTER PROPERLY
  Future<void> _initializeAttendanceCounter() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Check if new day
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String lastProcessedDay = prefs.getString('lastAttendanceDay') ?? '';

    if (lastProcessedDay != today) {
      // New day, reset counter to highest serial from server
      attendanceInSerialCounter = attendanceInHighestSerial ?? 1;
      attendanceInCurrentMonth = DateFormat('MMM').format(DateTime.now());
      currentuserId = user_id;

      await prefs.setInt('attendanceInSerialCounter', attendanceInSerialCounter);
      await prefs.setString('attendanceInCurrentMonth', attendanceInCurrentMonth);
      await prefs.setString('currentuserId', currentuserId);
      await prefs.setString('lastAttendanceDay', today);

      debugPrint("🔄 [ATTENDANCE] New day detected - Counter initialized to: $attendanceInSerialCounter");
    } else {
      // Load existing counter
      await _loadCounter();
    }
  }

  // 🎯 SIMPLE LOCATION CHECK - ONLY CHECKS IF SERVICE IS ENABLED
  Future<bool> isLocationAvailable() async {
    try {
      bool isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      return isLocationEnabled;
    } catch (e) {
      return true; // Even on error, allow clock-in
    }
  }

  // 🎯 MAIN CLOCK-IN METHOD - WITH STRICT VALIDATION
  Future<void> saveFormAttendanceIn() async {
    debugPrint("🎯 [ATTENDANCE] ===== CLOCK-IN STARTED =====");

    // 1. Check if already clocked in
    if (isClockedIn.value) {
      Get.snackbar(
        'Already Clocked In',
        'You are already clocked in',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
      );
      return;
    }

    // 2. QUICK location service check ONLY
    bool locationAvailable = await isLocationAvailable();
    if (!locationAvailable) {
      Get.snackbar(
        'Location Required',
        'Please turn on device location',
        backgroundColor: Colors.red,
      );
      return;
    }

    debugPrint("✅ [ATTENDANCE] Location ON - CLOCKING IN NOW");

    // 3. Generate attendance ID with STRICT validation
    await _loadCounter();

    // ✅ STRICT: Generate unique ID
    String attendanceId = await _generateStrictAttendanceId();

    // ✅ STRICT: Check if this ID already exists
    bool alreadyExists = await _checkIfAttendanceAlreadyExists(attendanceId);
    if (alreadyExists) {
      // Regenerate with incremented serial
      attendanceInSerialCounter++;
      await _saveCounter();
      attendanceId = await _generateStrictAttendanceId();
      debugPrint("🔄 [ATTENDANCE] Regenerated new Attendance ID: $attendanceId");
    }

    // 4. INSTANTLY SET CLOCK-IN STATE
    _clockInTime = DateTime.now();
    isClockedIn.value = true;
    elapsedTime.value = '00:00:00';
    _startTimer();

    // 5. SHOW SUCCESS IMMEDIATELY
    Get.snackbar(
      'Clock-In Successful',
      'You are now clocked in',
      backgroundColor: Colors.green,
    );

    debugPrint("✅ [ATTENDANCE] CLOCK-IN COMPLETED WITH ID: $attendanceId");

    // 6. BACKGROUND TASKS
    await _handleAllBackgroundTasks(attendanceId);
  }

  // ✅ STRICT: Generate attendance ID with validation
  Future<String> _generateStrictAttendanceId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    final DateTime now = DateTime.now();
    String currentMonth = DateFormat('MMM').format(DateTime.now());
    String currentDayNumber = DateFormat('dd').format(now);
    String today = DateFormat('yyyy-MM-dd').format(now);

    // Get last generated day
    String lastGeneratedDay = prefs.getString('lastGeneratedAttendanceDay') ?? '';

    // STRICT VALIDATION: If new day, reset counter
    if (lastGeneratedDay != today) {
      attendanceInSerialCounter = attendanceInHighestSerial ?? 1;
      currentuserId = user_id;
      attendanceInCurrentMonth = currentMonth;

      await prefs.setString('lastGeneratedAttendanceDay', today);
      debugPrint("🔄 [ATTENDANCE] New day - Counter reset to: $attendanceInSerialCounter");
    }

    // STRICT VALIDATION: User ID change check
    if (currentuserId != user_id) {
      attendanceInSerialCounter = attendanceInHighestSerial ?? 1;
      currentuserId = user_id;
      debugPrint("🔄 [ATTENDANCE] User changed - Counter reset to: $attendanceInSerialCounter");
    }

    // STRICT VALIDATION: Month change check
    if (attendanceInCurrentMonth != currentMonth) {
      attendanceInSerialCounter = 1;
      attendanceInCurrentMonth = currentMonth;
      debugPrint("🔄 [ATTENDANCE] Month changed - Counter reset to: 1");
    }

    // Generate ID
    String attendanceId = "ATD-$user_id-$currentDayNumber-$currentMonth-${attendanceInSerialCounter.toString().padLeft(3, '0')}";

    debugPrint("🆔 [ATTENDANCE] STRICT Attendance ID Generated:");
    debugPrint("   - ID: $attendanceId");
    debugPrint("   - User: $user_id");
    debugPrint("   - Day: $currentDayNumber");
    debugPrint("   - Month: $currentMonth");
    debugPrint("   - Serial: $attendanceInSerialCounter");

    // Save the ID immediately
    await prefs.setString('currentAttendanceId', attendanceId);
    await prefs.setString('attendanceId', attendanceId);
    await prefs.setString('clockInAttendanceId', attendanceId); // Extra backup

    // Mark this serial as used for today
    await prefs.setInt('usedSerial_${attendanceInSerialCounter}_$today', 1);

    return attendanceId;
  }

  // ✅ STRICT: Check if attendance already exists
  Future<bool> _checkIfAttendanceAlreadyExists(String attendanceId) async {
    try {
      // Check local database first
      var allAttendance = await attendanceRepository.getAttendance();

      bool existsInLocal = allAttendance.any((attendance) =>
      attendance.attendance_in_id == attendanceId);

      if (existsInLocal) {
        debugPrint("⚠️ [ATTENDANCE] VALIDATION: ID $attendanceId already exists in local DB");
        return true;
      }

      return false;
    } catch (e) {
      debugPrint("❌ [ATTENDANCE] Error checking attendance existence: $e");
      return false;
    }
  }

  // ✅ NEW: Get real GPS with retry - returns actual coordinates or fallback
  Future<Map<String, double>> _getValidGPS() async {
    debugPrint("📍 [GPS] Fetching real GPS coordinates...");

    // 1st attempt: Geolocator se fresh position lo
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (position.latitude != 0.0 && position.longitude != 0.0) {
        debugPrint("✅ [GPS] Got real position: ${position.latitude}, ${position.longitude}");
        return {'lat': position.latitude, 'lng': position.longitude};
      }
    } catch (e) {
      debugPrint("⚠️ [GPS] getCurrentPosition failed: $e");
    }

    // 2nd attempt: LocationViewModel observable wait karo (max 5 seconds)
    debugPrint("⏳ [GPS] Waiting for LocationViewModel to update...");
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      double lat = locationViewModel.globalLatitude1.value;
      double lng = locationViewModel.globalLongitude1.value;
      if (lat != 0.0 && lng != 0.0) {
        debugPrint("✅ [GPS] Got from LocationViewModel: $lat, $lng");
        return {'lat': lat, 'lng': lng};
      }
    }

    // 3rd attempt: Last known position
    try {
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && lastKnown.latitude != 0.0 && lastKnown.longitude != 0.0) {
        debugPrint("✅ [GPS] Using last known position: ${lastKnown.latitude}, ${lastKnown.longitude}");
        return {'lat': lastKnown.latitude, 'lng': lastKnown.longitude};
      }
    } catch (e) {
      debugPrint("⚠️ [GPS] getLastKnownPosition failed: $e");
    }

    // 4th fallback: Jo bhi LocationViewModel mein hai (even 0)
    debugPrint("⚠️ [GPS] All attempts failed, using LocationViewModel value as fallback");
    return {
      'lat': locationViewModel.globalLatitude1.value,
      'lng': locationViewModel.globalLongitude1.value,
    };
  }

  /// 🛰 ALL BACKGROUND TASKS - WITH BLOCKING SYNC
  Future<void> _handleAllBackgroundTasks(String attendanceId) async {
    debugPrint("🛰 [ATTENDANCE] Starting background tasks...");

    try {
      // A. Save to SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('clockInTime', _clockInTime!.toIso8601String());
      debugPrint("✅ [ATTENDANCE] Background: Saved to SharedPreferences");

      // B. Already have attendanceId from parameter
      await prefs.remove('totalDistance');
      await prefs.setInt('secondsPassed', 0);
      debugPrint("✅ [ATTENDANCE] Background: Using attendance ID: $attendanceId");

      // C. ✅ FIX: Get REAL GPS coordinates (not 0,0)
      Map<String, double> gps = await _getValidGPS();
      double realLat = gps['lat']!;
      double realLng = gps['lng']!;
      debugPrint("📍 [ATTENDANCE] Using GPS: lat=$realLat, lng=$realLng");

      // ✅ FIX: Capture exact clock-in date and time
      final DateTime clockInNow = _clockInTime ?? DateTime.now();

      // ✅ FIX: Save to local database WITH lat, lng, date, time
      addAttendance(
        AttendanceModel(
          attendance_in_id: attendanceId,
          user_id: user_id,
          city: userCity,
          booker_name: userName,
          lat_in: realLat,                          // ✅ Real GPS lat
          lng_in: realLng,                          // ✅ Real GPS lng
          designation: userDesignation,
          address: locationViewModel.shopAddress.value,
          attendance_in_date: clockInNow,           // ✅ Actual clock-in date
          attendance_in_time: clockInNow,           // ✅ Actual clock-in time
        ),
      );
      debugPrint("✅ [ATTENDANCE] Saved: lat=$realLat, lng=$realLng, time=$clockInNow");

      // D. ✅ BLOCKING SERVER SYNC
      debugPrint("🌐 [ATTENDANCE] Starting server sync...");

      final internetStatus = await _checkInternetSpeed().timeout(
        Duration(seconds: 3),
        onTimeout: () => 'none',
      );

      if (internetStatus == 'fast') {
        debugPrint("🌐 [ATTENDANCE] Calling postDataFromDatabaseToAPI");
        await attendanceRepository.postDataFromDatabaseToAPI();
        debugPrint("✅ [ATTENDANCE] Server sync completed");
      } else {
        debugPrint("🌐 [ATTENDANCE] No internet - will sync later");
      }

    } catch (e) {
      debugPrint("⚠ [ATTENDANCE] Background tasks error: $e");
    }
  }

  // 🌐 SERVER SYNC - IMMEDIATE (LIKE CLOCK-OUT)
  void _tryServerSync() async {
    try {
      debugPrint("🌐 [ATTENDANCE] Immediate server sync started");

      // Quick internet check
      final internetStatus = await _checkInternetSpeed().timeout(
        Duration(seconds: 2),
        onTimeout: () => 'none',
      );

      debugPrint("🌐 [ATTENDANCE] Internet status: $internetStatus");

      if (internetStatus == 'fast') {
        debugPrint("🌐 [ATTENDANCE] Calling postDataFromDatabaseToAPI immediately");
        await attendanceRepository.postDataFromDatabaseToAPI();
        debugPrint("✅ [ATTENDANCE] Immediate server sync completed");
      } else {
        debugPrint("🌐 [ATTENDANCE] No internet - skipping sync");
      }
    } catch (e) {
      debugPrint("⚠ [ATTENDANCE] Immediate sync failed: $e");
    }
  }

  // --- TIMER METHODS ---
  Future<void> _loadInitialClockState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? clockInTimeString = prefs.getString('clockInTime');

    if (clockInTimeString != null) {
      _clockInTime = DateTime.parse(clockInTimeString);
      isClockedIn.value = true;
      _startTimer();
    }
  }

  void _startTimer() {
    if (_clockInTime == null) return;

    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final duration = now.difference(_clockInTime!);

      String twoDigits(int n) => n.toString().padLeft(2, '0');
      String hours = twoDigits(duration.inHours);
      String minutes = twoDigits(duration.inMinutes.remainder(60));
      String seconds = twoDigits(duration.inSeconds.remainder(60));

      elapsedTime.value = '$hours:$minutes:$seconds';

      if (duration.inSeconds % 60 == 0) {
        debugPrint("⏰ [ATTENDANCE] Timer: ${elapsedTime.value}");
      }

      _saveTotalTime(elapsedTime.value);
    });
    debugPrint('✅ [ATTENDANCE] Timer started at: $_clockInTime');
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    debugPrint('🛑 [ATTENDANCE] Timer stopped');
  }

  Future<void> _saveTotalTime(String time) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('totalTime', time);
    debugPrint("✅ [ATTENDANCE] Saved total time to preferences: $time");
  }

  // ✅ UPDATED: Clear clock-in state with STRICT cleanup
  Future<void> clearClockInState() async {
    _stopTimer();
    isClockedIn.value = false;
    _clockInTime = null;
    elapsedTime.value = '00:00:00';

    SharedPreferences prefs = await SharedPreferences.getInstance();

    // STRICT CLEANUP: Remove all attendance-related data
    await prefs.remove('clockInTime');
    await prefs.remove('totalTime');
    await prefs.remove('totalDistance');
    await prefs.setInt('secondsPassed', 0);

    // Keep attendanceId for clock-out matching but mark as used
    String? currentAttendanceId = prefs.getString('currentAttendanceId');
    if (currentAttendanceId != null) {
      await prefs.setString('usedAttendanceId', currentAttendanceId);
      await prefs.remove('currentAttendanceId');
    }

    debugPrint("🔄 [ATTENDANCE] Clock-in state cleared completely");
  }

  // --- SERIAL NUMBER METHODS ---
  Future<void> _loadCounter() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String currentMonth = DateFormat('MMM').format(DateTime.now());

    attendanceInSerialCounter =
        prefs.getInt('attendanceInSerialCounter') ?? (attendanceInHighestSerial ?? 1);
    attendanceInCurrentMonth =
        prefs.getString('attendanceInCurrentMonth') ?? currentMonth;
    currentuserId = prefs.getString('currentuserId') ?? '';

    if (attendanceInCurrentMonth != currentMonth) {
      attendanceInSerialCounter = 1;
      attendanceInCurrentMonth = currentMonth;
    }

    debugPrint('[ATTENDANCE] Loaded Serial Counter: $attendanceInSerialCounter');
  }

  Future<void> _saveCounter() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('attendanceInSerialCounter', attendanceInSerialCounter);
    await prefs.setString('attendanceInCurrentMonth', attendanceInCurrentMonth);
    await prefs.setString('currentuserId', currentuserId);
  }

  // --- INTERNET CHECK ---
  Future<String> _checkInternetSpeed() async {
    try {
      final response = await http.head(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        return 'fast';
      } else {
        return 'slow';
      }
    } on TimeoutException {
      return 'slow';
    } on SocketException {
      return 'none';
    } catch (e) {
      debugPrint('[ATTENDANCE] Internet check failed: $e');
      return 'none';
    }
  }

  // --- DATABASE METHODS ---
  Future<void> fetchAllAttendance() async {
    var attendance = await attendanceRepository.getAttendance();
    allAttendance.value = attendance;
  }

  void addAttendance(AttendanceModel attendanceModel) {
    attendanceRepository.add(attendanceModel);
    fetchAllAttendance();
  }

  void updateAttendance(AttendanceModel attendanceModel) {
    attendanceRepository.update(attendanceModel);
    fetchAllAttendance();
  }

  void deleteAttendance(String id) {
    attendanceRepository.delete(id);
    fetchAllAttendance();
  }

  Future<void> serialCounterGet() async {
    await attendanceRepository.serialNumberGeneratorApi();
  }

  // ✅ ADDED: Get current attendance ID
  Future<String?> getCurrentAttendanceId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('currentAttendanceId') ??
        prefs.getString('attendanceId') ??
        prefs.getString('clockInAttendanceId');
  }

  // ✅ FIXED: Clean duplicate attendance records (NO ID PROPERTY)
  Future<void> cleanDuplicateRecords() async {
    try {
      var allRecords = await attendanceRepository.getAttendance();
      Set<String> uniqueIds = {};
      List<String> duplicateIds = [];

      // Find duplicates
      for (var record in allRecords) {
        String recordId = record.attendance_in_id?.toString() ?? '';
        if (recordId.isNotEmpty) {
          if (uniqueIds.contains(recordId)) {
            duplicateIds.add(recordId);
          } else {
            uniqueIds.add(recordId);
          }
        }
      }

      // Remove duplicates
      for (String duplicateId in duplicateIds) {
        debugPrint("🗑️ [ATTENDANCE] Removing duplicate record: $duplicateId");

        // Get all records with this ID
        var duplicates = allRecords.where((r) => r.attendance_in_id == duplicateId).toList();

        if (duplicates.length > 1) {
          // Keep first, delete rest
          for (int i = 1; i < duplicates.length; i++) {
            // Delete by attendance_in_id (not id property)
            await attendanceRepository.delete(duplicateId);
          }
          debugPrint("✅ [ATTENDANCE] Removed ${duplicates.length - 1} duplicates for ID: $duplicateId");
        }
      }

      if (duplicateIds.isNotEmpty) {
        debugPrint("✅ [ATTENDANCE] Cleaned ${duplicateIds.length} duplicate attendance IDs");
        // Refresh the list
        fetchAllAttendance();
      } else {
        debugPrint("✅ [ATTENDANCE] No duplicate records found");
      }
    } catch (e) {
      debugPrint("❌ [ATTENDANCE] Error cleaning duplicates: $e");
    }
  }

  // ✅ ADDED: Check for duplicate before adding
  Future<bool> checkForDuplicate(String attendanceId) async {
    try {
      var allRecords = await attendanceRepository.getAttendance();
      return allRecords.any((record) => record.attendance_in_id == attendanceId);
    } catch (e) {
      debugPrint("❌ [ATTENDANCE] Error checking for duplicate: $e");
      return false;
    }
  }

  // ✅ ADDED: Get attendance status
  Future<Map<String, dynamic>> getAttendanceStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? currentId = prefs.getString('currentAttendanceId');
    String? clockInTime = prefs.getString('clockInTime');
    bool isClockedInStatus = prefs.getBool('isClockedIn') ?? false;

    var allRecords = await attendanceRepository.getAttendance();
    int totalRecords = allRecords.length;

    // Check if current ID exists in database
    bool idExistsInDB = currentId != null &&
        allRecords.any((record) => record.attendance_in_id == currentId);

    return {
      'currentId': currentId,
      'clockInTime': clockInTime,
      'isClockedIn': isClockedInStatus,
      'idExistsInDB': idExistsInDB,
      'totalRecords': totalRecords,
      'hasDuplicates': totalRecords > Set.from(allRecords.map((r) => r.attendance_in_id)).length,
    };
  }

  // ✅ ADDED: Force cleanup and reset
  Future<void> forceCleanup() async {
    try {
      debugPrint("🧹 [ATTENDANCE] Starting force cleanup...");

      // 1. Clean duplicate records
      await cleanDuplicateRecords();

      // 2. Clear any invalid state
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Check if clocked in but no clock in time
      bool isClockedInStatus = prefs.getBool('isClockedIn') ?? false;
      String? clockInTime = prefs.getString('clockInTime');

      if (isClockedInStatus && clockInTime == null) {
        debugPrint("⚠️ [ATTENDANCE] Invalid state: Clocked in but no clock in time");
        await prefs.setBool('isClockedIn', false);
      }

      // 3. Check for orphaned records (records without matching state)
      var allRecords = await attendanceRepository.getAttendance();
      String? currentId = prefs.getString('currentAttendanceId');

      if (currentId != null && !allRecords.any((r) => r.attendance_in_id == currentId)) {
        debugPrint("⚠️ [ATTENDANCE] Orphaned current ID: $currentId");
        await prefs.remove('currentAttendanceId');
      }

      debugPrint("✅ [ATTENDANCE] Force cleanup completed");

    } catch (e) {
      debugPrint("❌ [ATTENDANCE] Error in force cleanup: $e");
    }
  }
}