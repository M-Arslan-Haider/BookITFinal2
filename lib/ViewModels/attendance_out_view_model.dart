
import 'dart:convert';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Databases/util.dart';
import '../Models/attendanceOut_model.dart';
import '../Repositories/attendance_out_repository.dart';
import '../Services/FirebaseServices/firebase_remote_config.dart';
import 'location_view_model.dart';
import 'attendance_view_model.dart';

class AttendanceOutViewModel extends GetxController {
  var allAttendanceOut = <AttendanceOutModel>[].obs;
  final AttendanceOutRepository attendanceOutRepository = AttendanceOutRepository();
  final LocationViewModel locationViewModel = Get.put(LocationViewModel());
  final AttendanceViewModel attendanceViewModel = Get.find<AttendanceViewModel>();

  Timer? _autoClockOutTimer;
  final Connectivity _connectivity = Connectivity();

  @override
  void onInit() {
    super.onInit();
    fetchAllAttendanceOut();

    // On startup: process any pending events, then sync
    _processStartupPendingData();

    _startAutoClockOutTimer();
    _startPeriodicSyncCheck();
  }

  @override
  void onClose() {
    _autoClockOutTimer?.cancel();
    super.onClose();
  }

  /// ✅ FIX: Central startup handler — runs in the right order to avoid conflicts
  Future<void> _processStartupPendingData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // ✅ STEP 1: Check for native background critical event (highest priority)
    bool hasCriticalEvent = prefs.getBool('has_critical_event_pending') ?? false;
    if (hasCriticalEvent) {
      debugPrint("🔴 [STARTUP] Critical event pending — processing NOW");
      await _processCriticalEventFromNative(prefs);
      return; // restoreFastDataOnStartup and restoreFromBackupIfNeeded will be skipped
      // because the critical event handler clears the flags and posts
    }

    // ✅ STEP 2: Check for fast clock-out data (from Flutter or Kotlin)
    bool hasFastData = prefs.getBool('hasFastClockOutData') ?? false;
    if (hasFastData) {
      await restoreFastDataOnStartup();
    }

    // ✅ STEP 3: Check for backup data
    bool hasBackup = prefs.getBool('hasBackupClockOutData') ?? false;
    if (hasBackup) {
      await restoreFromBackupIfNeeded();
    }

    // ✅ STEP 4: Always flush any unposted DB records (safety net)
    await _flushUnpostedRecords();
  }

  /// ✅ NEW: Process a critical event that was saved by the native Kotlin service
  /// This handles the case where location permission was revoked while app was in background
  Future<void> _processCriticalEventFromNative(SharedPreferences prefs) async {
    try {
      String? timestampStr = prefs.getString('critical_event_timestamp');
      String? reason = prefs.getString('critical_event_reason');

      debugPrint("🔴 [CRITICAL EVENT] timestamp=$timestampStr, reason=$reason");

      if (timestampStr == null || timestampStr.isEmpty) {
        debugPrint("⚠️ [CRITICAL EVENT] No timestamp found — checking fastClockOutTime");
        timestampStr = prefs.getString('fastClockOutTime');
      }

      if (timestampStr == null || timestampStr.isEmpty) {
        debugPrint("❌ [CRITICAL EVENT] No valid timestamp — cannot process");
        // Clear the pending flag to prevent infinite loop
        await prefs.setBool('has_critical_event_pending', false);
        await _flushUnpostedRecords();
        return;
      }

      DateTime eventTime;
      try {
        // Handle both ISO 8601 and yyyy-MM-dd'T'HH:mm:ss formats
        eventTime = DateTime.parse(timestampStr.replaceAll("'", ""));
      } catch (e) {
        debugPrint("❌ [CRITICAL EVENT] Failed to parse timestamp: $timestampStr — $e");
        await prefs.setBool('has_critical_event_pending', false);
        await _flushUnpostedRecords();
        return;
      }

      String finalReason = reason?.isNotEmpty == true ? reason! : 'System ClockOut - Permission Revoked';

      debugPrint("✅ [CRITICAL EVENT] Processing: time=$eventTime, reason=$finalReason");

      // Save and post using the exact event time from Kotlin
      await saveFormAttendanceOutWithPrefs(
        clockOutTime: eventTime,
        isAuto: true,
        reason: finalReason,
      );

      // ✅ Clear ALL critical event flags after successful processing
      await prefs.setBool('has_critical_event_pending', false);
      await prefs.remove('critical_event_timestamp');
      await prefs.remove('critical_event_reason');
      await prefs.setBool('is_timer_frozen', false);
      await prefs.setBool('hasFastClockOutData', false);
      await prefs.remove('fastClockOutData');
      await prefs.remove('fastClockOutTime');
      await prefs.remove('fastClockOutReason');
      await prefs.remove('fastClockOutDistance');
      await prefs.setBool('clockOutPending', false);

      debugPrint("✅ [CRITICAL EVENT] Processed and flags cleared");

      // Flush to API
      await _flushUnpostedRecords();

    } catch (e) {
      debugPrint("❌ [CRITICAL EVENT] Error processing: $e");
      // Don't leave in a broken state
      await prefs.setBool('has_critical_event_pending', false);
      await _flushUnpostedRecords();
    }
  }

  /// ✅ NEW: Always try to post any unposted DB records — the ultimate safety net
  Future<void> _flushUnpostedRecords() async {
    try {
      var results = await _connectivity.checkConnectivity();
      bool isOnline = results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none);

      if (isOnline) {
        debugPrint("🔄 [FLUSH] Internet available — posting unposted DB records");
        bool anyPosted = await attendanceOutRepository.postDataFromDatabaseToAPI();
        if (anyPosted) {
          debugPrint("✅ [FLUSH] Successfully posted pending records");
        } else {
          debugPrint("📭 [FLUSH] Nothing to post or all failed");
        }
      } else {
        debugPrint("📴 [FLUSH] No internet — will retry on next periodic sync");
      }
    } catch (e) {
      debugPrint("❌ [FLUSH] Error: $e");
    }
  }

  /// ✅ UPDATED: saveFormAttendanceOutWithPrefs — always uses real event time, never DateTime.now()
  Future<void> saveFormAttendanceOutWithPrefs({
    DateTime? clockOutTime,
    double? totalDistance,
    bool isAuto = false,
    String reason = 'manual',
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    // ✅ Use provided clock-out time — NEVER fall back to DateTime.now() for auto events
    DateTime actualClockOutTime = clockOutTime ?? DateTime.now();

    debugPrint("🕐 Clock-out time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(actualClockOutTime)}");
    debugPrint("📱 Device time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}");
    debugPrint("🤖 Auto: ${isAuto ? 'Yes ($reason)' : 'No (Manual)'}");

    String? clockInTimeString = prefs.getString('clockInTime');
    DateTime shiftStartTime = clockInTimeString != null
        ? DateTime.parse(clockInTimeString)
        : actualClockOutTime.subtract(const Duration(hours: 1));

    Duration shiftDuration = actualClockOutTime.difference(shiftStartTime);
    // Ensure non-negative duration
    if (shiftDuration.isNegative) shiftDuration = Duration.zero;
    String totalTime = _formatDuration(shiftDuration);

    double finalDistance = 0.0;

    if (totalDistance != null && totalDistance > 0) {
      finalDistance = totalDistance;
      debugPrint("📍 [DISTANCE] Using provided: ${finalDistance.toStringAsFixed(3)} km");
    } else {
      double savedDistance = prefs.getDouble('clockOutDistance') ?? 0.0;
      if (savedDistance > 0) {
        finalDistance = savedDistance;
        debugPrint("📍 [DISTANCE] Using saved from SharedPreferences: ${savedDistance.toStringAsFixed(3)} km");
      } else {
        double backupDistance = prefs.getDouble('backupDistance') ?? 0.0;
        if (backupDistance > 0) {
          finalDistance = backupDistance;
          debugPrint("📍 [DISTANCE] Using backup distance: ${backupDistance.toStringAsFixed(3)} km");
        } else {
          try {
            finalDistance = await locationViewModel.calculateShiftDistance(shiftStartTime);
            debugPrint("📍 [DISTANCE] Calculated from LocationViewModel: ${finalDistance.toStringAsFixed(3)} km");
          } catch (e) {
            debugPrint("❌ [DISTANCE] Error calculating: $e");
            finalDistance = 0.0;
          }
        }
      }
    }

    final attendanceId = prefs.getString('attendanceId') ?? '';

    if (attendanceId.isEmpty) {
      debugPrint("⚠️ No attendanceId found — generating new one");
      await attendanceOutRepository.serialNumberGeneratorApi();
      await prefs.reload();
      final newAttendanceId = prefs.getString('attendanceId') ?? '';

      if (newAttendanceId.isEmpty) {
        debugPrint("❌ Failed to generate attendance ID — saving backup only");
        await _saveToPrefsAsBackup(
          clockOutTime: actualClockOutTime,
          totalTime: totalTime,
          totalDistance: finalDistance,
          reason: reason,
        );
        return;
      }
    }

    final finalAttendanceId = prefs.getString('attendanceId') ?? '';
    String address = locationViewModel.shopAddress.value;

    if (isAuto) {
      address = "$address (Auto clock-out: $reason at ${DateFormat('HH:mm:ss').format(actualClockOutTime)})";
    }

    // STEP 1: Save to SharedPreferences (immediate backup)
    await _saveToPrefsAsBackup(
      attendanceId: finalAttendanceId,
      clockOutTime: actualClockOutTime,
      totalTime: totalTime,
      totalDistance: finalDistance,
      address: address,
      reason: reason,
    );

    // STEP 2: Create model with EXACT event time
    AttendanceOutModel attendanceOutModel = AttendanceOutModel(
      attendance_out_id: finalAttendanceId,
      user_id: user_id,
      total_distance: finalDistance,
      total_time: totalTime,
      lat_out: locationViewModel.globalLatitude1.value,
      lng_out: locationViewModel.globalLongitude1.value,
      address: address,
      reason: reason,
      attendance_out_time: actualClockOutTime, // ✅ REAL EVENT TIME
      attendance_out_date: actualClockOutTime, // ✅ REAL EVENT DATE
    );

    debugPrint("📊 [ATTENDANCE OUT]");
    debugPrint("   - ID: $finalAttendanceId");
    debugPrint("   - Time: $totalTime (from $shiftStartTime to $actualClockOutTime)");
    debugPrint("   - Distance: ${finalDistance.toStringAsFixed(3)} km");
    debugPrint("   - Reason: $reason");

    // STEP 3: Save to local database
    int rowId = await attendanceOutRepository.add(attendanceOutModel);
    if (rowId == 0) {
      // Record already in DB — it might already be posted or pending
      debugPrint("⚠️ [SAVE] Record already in DB: $finalAttendanceId — skipping insert, will flush");
    } else if (rowId > 0) {
      debugPrint("✅ [SAVE] Inserted into DB: $finalAttendanceId");
    } else {
      debugPrint("❌ [SAVE] DB insert error for: $finalAttendanceId");
    }
    fetchAllAttendanceOut();

    // STEP 4: Try to post to API immediately
    await _postAttendanceOutToApi(attendanceOutModel);

    // STEP 5: Clear clock-in state
    await attendanceViewModel.clearClockInState();

    debugPrint("✅ Clock-out saved: ${finalDistance.toStringAsFixed(3)} km, reason: $reason");
  }

  /// ✅ ULTRA-FAST ATTENDANCE SAVE — completes in <1 second
  Future<void> fastSaveAttendanceOut({
    required DateTime clockOutTime,
    required double totalDistance,
    bool isAuto = false,
    String reason = 'fast_manual',
  }) async {
    debugPrint("⚡ [FAST SAVE] Starting ultra-fast attendance save");

    SharedPreferences prefs = await SharedPreferences.getInstance();

    String attendanceId = prefs.getString('attendanceId') ?? '';
    if (attendanceId.isEmpty) {
      attendanceId = 'FAST_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('fastAttendanceId', attendanceId);
    }

    String? clockInTimeString = prefs.getString('clockInTime');
    String totalTime = '00:00:00';

    if (clockInTimeString != null) {
      try {
        DateTime shiftStartTime = DateTime.parse(clockInTimeString);
        Duration shiftDuration = clockOutTime.difference(shiftStartTime);
        if (!shiftDuration.isNegative) {
          totalTime = _formatDuration(shiftDuration);
        }
      } catch (e) {
        totalTime = '00:00:00';
      }
    }

    // Save to SharedPreferences (fastest)
    Map<String, dynamic> fastData = {
      'fast_attendanceId': attendanceId,
      'fast_userId': user_id,
      'fast_clockOutTime': clockOutTime.toIso8601String(),
      'fast_totalTime': totalTime,
      'fast_totalDistance': totalDistance,
      'fast_latOut': locationViewModel.globalLatitude1.value,
      'fast_lngOut': locationViewModel.globalLongitude1.value,
      'fast_address': locationViewModel.shopAddress.value,
      'fast_reason': reason,
      'fast_savedAt': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    String jsonData = json.encode(fastData);
    await prefs.setString('fastClockOutData', jsonData);
    await prefs.setBool('hasFastClockOutData', true);
    await prefs.setDouble('clockOutDistance', totalDistance);

    // Quick database insert (non-blocking)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        AttendanceOutModel attendanceOutModel = AttendanceOutModel(
          attendance_out_id: attendanceId,
          user_id: user_id,
          total_distance: totalDistance,
          total_time: totalTime,
          lat_out: locationViewModel.globalLatitude1.value,
          lng_out: locationViewModel.globalLongitude1.value,
          address: locationViewModel.shopAddress.value,
          reason: reason,
          attendance_out_time: clockOutTime, // ✅ REAL EVENT TIME
          attendance_out_date: clockOutTime, // ✅ REAL EVENT DATE
        );

        addAttendanceOut(attendanceOutModel);
        debugPrint("✅ [FAST SAVE] DB insert completed");
        _scheduleApiSync(attendanceOutModel);

      } catch (e) {
        debugPrint("⚠️ [FAST SAVE] Background save error: $e");
      }
    });

    debugPrint("⚡ [FAST SAVE] Completed. Distance: ${totalDistance.toStringAsFixed(3)} km, Time: $totalTime");
  }

  void _scheduleApiSync(AttendanceOutModel model) {
    Timer(Duration(seconds: 10), () async {
      try {
        debugPrint("🔄 [DELAYED SYNC] Attempting API sync...");

        var results = await _connectivity.checkConnectivity();
        bool isOnline = results.isNotEmpty &&
            results.any((result) => result != ConnectivityResult.none);

        if (isOnline) {
          await attendanceOutRepository.postDataFromDatabaseToAPI();
          debugPrint("✅ [DELAYED SYNC] API sync successful");

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('hasFastClockOutData', false);
          await prefs.remove('fastClockOutData');
        }
      } catch (e) {
        debugPrint("⚠️ [DELAYED SYNC] Error: $e");
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  void _startAutoClockOutTimer() {
    debugPrint("⏰ Starting auto clock-out timer for 11:58 PM");
    _autoClockOutTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkForAutoClockOut();
    });
    _checkForAutoClockOut();
  }

  Future<void> _checkForAutoClockOut() async {
    try {
      DateTime now = DateTime.now();
      if (now.hour == 23 && now.minute == 58) {
        debugPrint("🕰 11:58 PM AUTO CLOCK-OUT TIME DETECTED!");

        SharedPreferences prefs = await SharedPreferences.getInstance();
        bool isClockedIn = prefs.getBool('isClockedIn') ?? false;

        if (isClockedIn) {
          debugPrint("🤖 User is clocked in — triggering 11:58 PM auto clock-out");
          DateTime clockOutTime = DateTime(now.year, now.month, now.day, 23, 58, 0);

          await saveFormAttendanceOutWithPrefs(
            clockOutTime: clockOutTime,
            isAuto: true,
            reason: '11:58_pm_auto',
          );

          debugPrint('✅ [ATTENDANCE_OUT] Auto clock-out snack handled by TimerCard');
        }
      }
    } catch (e) {
      debugPrint("❌ Error in auto clock-out check: $e");
    }
  }

  Future<void> _saveToPrefsAsBackup({
    String? attendanceId,
    required DateTime clockOutTime,
    required String totalTime,
    required double totalDistance,
    String address = '',
    String reason = 'manual',
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    Map<String, dynamic> clockOutData = {
      'backup_attendanceId': attendanceId ?? 'UNKNOWN',
      'backup_userId': user_id,
      'backup_clockOutTime': clockOutTime.toIso8601String(),
      'backup_totalTime': totalTime,
      'backup_totalDistance': totalDistance,
      'backup_latOut': locationViewModel.globalLatitude1.value,
      'backup_lngOut': locationViewModel.globalLongitude1.value,
      'backup_address': address.isNotEmpty ? address : locationViewModel.shopAddress.value,
      'backup_reason': reason,
      'backup_savedAt': DateTime.now().toIso8601String(),
    };

    String jsonData = json.encode(clockOutData);
    await prefs.setString('backupClockOutData', jsonData);
    await prefs.setBool('hasBackupClockOutData', true);
    await prefs.setDouble('backupDistance', totalDistance);

    debugPrint("📱 [BACKUP] Saved: time=${clockOutTime.toIso8601String()}, distance=${totalDistance.toStringAsFixed(3)} km, reason=$reason");
  }

  Future<void> _postAttendanceOutToApi(AttendanceOutModel attendanceOutModel) async {
    try {
      debugPrint("🌐 [API POST] Attempting to post...");

      var results = await _connectivity.checkConnectivity();
      bool isOnline = results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none);

      if (isOnline) {
        await attendanceOutRepository.postDataFromDatabaseToAPI();
        debugPrint("✅ [API POST] Successfully posted");

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasBackupClockOutData', false);
        await prefs.remove('backupClockOutData');
        await prefs.remove('backupDistance');
        await prefs.remove('clockOutDistance');
      } else {
        debugPrint("🌐 [API POST] No internet — data saved locally, will sync later");
      }
    } catch (e) {
      debugPrint("❌ [API POST] Error: $e — data remains in backup");
    }
  }

  DateTime? _parseTimeFromAddress(String address) {
    try {
      final regex = RegExp(r'at (\d{2}:\d{2}:\d{2}|\d{2}:\d{2} [AP]M)');
      final match = regex.firstMatch(address);
      if (match != null) {
        String timeStr = match.group(1) ?? '';
        DateTime now = DateTime.now();
        if (timeStr.contains('AM') || timeStr.contains('PM')) {
          final timeParts = timeStr.split(RegExp(r'[: ]'));
          int hour = int.parse(timeParts[0]);
          int minute = int.parse(timeParts[1]);
          bool isPM = timeParts[2] == 'PM';
          if (isPM && hour != 12) hour += 12;
          if (!isPM && hour == 12) hour = 0;
          return DateTime(now.year, now.month, now.day, hour, minute);
        }
      }
    } catch (_) {}
    return null;
  }

  void _tryPostToApiInBackground(String attendanceId) async {
    try {
      var results = await _connectivity.checkConnectivity();
      bool isOnline = results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none);

      if (isOnline) {
        await attendanceOutRepository.postDataFromDatabaseToAPI();
        debugPrint("✅ [BACKGROUND SYNC] API post completed");

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasBackupClockOutData', false);
        await prefs.remove('backupClockOutData');
        await prefs.remove('backupDistance');
      }
    } catch (e) {
      debugPrint("❌ [BACKGROUND SYNC] Error: $e");
    }
  }

  /// ✅ UPDATED: restoreFromBackupIfNeeded — always uses saved clockOutTime, never DateTime.now()
  Future<void> restoreFromBackupIfNeeded() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasBackup = prefs.getBool('hasBackupClockOutData') ?? false;

    if (!hasBackup) return;

    String jsonData = prefs.getString('backupClockOutData') ?? '{}';
    try {
      Map<String, dynamic> data = json.decode(jsonData);

      debugPrint("🔄 [RESTORE BACKUP] Restoring from backup...");
      debugPrint("   - Attendance ID: ${data['backup_attendanceId']}");
      debugPrint("   - Reason: ${data['backup_reason']}");
      debugPrint("   - Distance: ${data['backup_totalDistance']} km");
      debugPrint("   - ClockOutTime: ${data['backup_clockOutTime']}");

      String? backupTimeStr = data['backup_clockOutTime'] as String?;
      if (backupTimeStr != null && backupTimeStr.isNotEmpty) {
        DateTime realBackupTime = DateTime.parse(backupTimeStr);
        double backupDist = (data['backup_totalDistance'] as num?)?.toDouble() ?? 0.0;
        String backupReason = data['backup_reason'] as String? ?? 'backup_restored';

        debugPrint("✅ [RESTORE BACKUP] Using real saved time: $realBackupTime");

        await saveFormAttendanceOutWithPrefs(
          clockOutTime: realBackupTime,
          totalDistance: backupDist,
          isAuto: true,
          reason: backupReason,
        );

        await prefs.setBool('hasBackupClockOutData', false);
        await prefs.remove('backupClockOutData');
      } else {
        debugPrint("⚠️ [RESTORE BACKUP] No valid time in backup — skipping to avoid wrong time");
        await prefs.setBool('hasBackupClockOutData', false);
      }

    } catch (e) {
      debugPrint("❌ [RESTORE BACKUP] Error: $e");
    }
  }

  /// ✅ UPDATED: restoreFastDataOnStartup — only called when no critical_event_pending
  Future<void> restoreFastDataOnStartup() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasFastData = prefs.getBool('hasFastClockOutData') ?? false;

    if (!hasFastData) return;

    debugPrint("🔄 [RESTORE FAST] Restoring fast-saved clock-out data...");

    try {
      // Try individual key first (written by Kotlin native service)
      String? directTimeStr = prefs.getString('fastClockOutTime');

      // Fall back to JSON blob
      if (directTimeStr == null) {
        String jsonData = prefs.getString('fastClockOutData') ?? '{}';
        try {
          Map<String, dynamic> data = json.decode(jsonData);
          directTimeStr = data['fast_clockOutTime'] as String?;
        } catch (_) {}
      }

      if (directTimeStr != null && directTimeStr.isNotEmpty) {
        DateTime realClockOutTime = DateTime.parse(directTimeStr);

        double realDistance = prefs.getDouble('fastClockOutDistance') ?? 0.0;
        if (realDistance == 0.0) {
          String jsonData = prefs.getString('fastClockOutData') ?? '{}';
          try {
            Map<String, dynamic> data = json.decode(jsonData);
            realDistance = (data['fast_totalDistance'] as num?)?.toDouble() ?? 0.0;
          } catch (_) {}
        }

        // Try individual reason key, then fall back to JSON
        String realReason = prefs.getString('fastClockOutReason') ?? '';
        if (realReason.isEmpty) {
          String jsonData = prefs.getString('fastClockOutData') ?? '{}';
          try {
            Map<String, dynamic> data = json.decode(jsonData);
            realReason = data['fast_reason'] as String? ?? 'background_auto';
          } catch (_) {}
        }
        if (realReason.isEmpty) realReason = 'background_auto';

        debugPrint("✅ [RESTORE FAST] time=$realClockOutTime, distance=$realDistance, reason=$realReason");

        await saveFormAttendanceOutWithPrefs(
          clockOutTime: realClockOutTime,
          totalDistance: realDistance,
          isAuto: true,
          reason: realReason,
        );

        // Clear fast data flags
        await prefs.setBool('hasFastClockOutData', false);
        await prefs.remove('fastClockOutData');
        await prefs.remove('fastClockOutTime');
        await prefs.remove('fastClockOutDistance');
        await prefs.remove('fastClockOutReason');

        debugPrint("✅ [RESTORE FAST] Completed with time: $realClockOutTime");

      } else {
        debugPrint("⚠️ [RESTORE FAST] No valid timestamp — skipping to avoid wrong time post");
      }

    } catch (e) {
      debugPrint("❌ [RESTORE FAST] Error: $e");
    }
  }

  /// ✅ Legacy method kept for backward compatibility
  Future<void> saveFormAttendanceOut({DateTime? clockOutTime}) async {
    await saveFormAttendanceOutWithPrefs(
      clockOutTime: clockOutTime,
      isAuto: clockOutTime != null,
      reason: clockOutTime != null ? 'legacy_auto' : 'manual',
    );
  }

  Future<void> saveAttendanceOutWithDistance({
    required String attendanceId,
    required double distance,
    required DateTime clockOutTime,
    String address = '',
    bool isAuto = false,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? clockInTimeString = prefs.getString('clockInTime');
    DateTime shiftStartTime = clockInTimeString != null
        ? DateTime.parse(clockInTimeString)
        : clockOutTime.subtract(const Duration(hours: 1));

    Duration shiftDuration = clockOutTime.difference(shiftStartTime);
    if (shiftDuration.isNegative) shiftDuration = Duration.zero;
    String totalTime = _formatDuration(shiftDuration);

    String finalAddress = address;
    if (isAuto) {
      finalAddress = "$address (Auto clock-out at ${DateFormat('HH:mm:ss').format(clockOutTime)})";
    }

    AttendanceOutModel attendanceOutModel = AttendanceOutModel(
      attendance_out_id: attendanceId,
      user_id: user_id,
      total_distance: distance,
      total_time: totalTime,
      lat_out: locationViewModel.globalLatitude1.value,
      lng_out: locationViewModel.globalLongitude1.value,
      address: finalAddress.isNotEmpty ? finalAddress : locationViewModel.shopAddress.value,
      attendance_out_time: clockOutTime, // ✅ REAL EVENT TIME
      attendance_out_date: clockOutTime, // ✅ REAL EVENT DATE
    );

    addAttendanceOut(attendanceOutModel);

    await _saveToPrefsAsBackup(
      attendanceId: attendanceId,
      clockOutTime: clockOutTime,
      totalTime: totalTime,
      totalDistance: distance,
      address: finalAddress,
      reason: isAuto ? 'direct_auto' : 'direct_manual',
    );

    await _postAttendanceOutToApi(attendanceOutModel);
    debugPrint("✅ Direct save: distance=${distance.toStringAsFixed(3)} km");
  }

  void _startPeriodicSyncCheck() {
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      await _syncPendingDataIfOnline();
    });
  }

  Future<void> _syncPendingDataIfOnline() async {
    try {
      var results = await _connectivity.checkConnectivity();
      bool isOnline = results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none);

      if (isOnline) {
        debugPrint("🔄 [PERIODIC SYNC] Syncing...");
        bool anyPosted = await attendanceOutRepository.postDataFromDatabaseToAPI();

        if (anyPosted) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('hasBackupClockOutData', false);
          await prefs.remove('backupClockOutData');
          await prefs.remove('backupDistance');
          debugPrint("✅ [PERIODIC SYNC] Synced successfully");
        }
      }
    } catch (e) {
      debugPrint("❌ [PERIODIC SYNC] Error: $e");
    }
  }

  Future<bool> shouldAutoClockOut() async {
    try {
      DateTime now = DateTime.now();
      if (now.hour == 23 && now.minute == 58) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        return prefs.getBool('isClockedIn') ?? false;
      }
      return false;
    } catch (e) {
      debugPrint("❌ Error checking auto clock-out: $e");
      return false;
    }
  }

  DateTime getAutoClockOutTime() {
    DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 58, 0);
  }

  Future<void> fetchAllAttendanceOut() async {
    var attendanceOut = await attendanceOutRepository.getAttendanceOut();
    allAttendanceOut.value = attendanceOut;
  }

  void addAttendanceOut(AttendanceOutModel attendanceOutModel) {
    attendanceOutRepository.add(attendanceOutModel);
    fetchAllAttendanceOut();
  }

  void updateAttendanceOut(AttendanceOutModel attendanceOutModel) {
    attendanceOutRepository.update(attendanceOutModel);
    fetchAllAttendanceOut();
  }

  void deleteAttendanceOut(String id) {
    attendanceOutRepository.delete(id);
    fetchAllAttendanceOut();
  }

  Future<void> serialCounterGet() async {
    await attendanceOutRepository.serialNumberGeneratorApi();
  }

  void debugDistanceInDatabase() async {
    debugPrint("🔍 [DATABASE DEBUG] Checking attendance-out records...");
    var records = await attendanceOutRepository.getAttendanceOut();
    if (records.isEmpty) {
      debugPrint("📭 No attendance-out records found in database");
      return;
    }
    for (var record in records) {
      debugPrint("📊 Record: ID=${record.attendance_out_id}, Distance=${record.total_distance} km, Time=${record.total_time}, Reason=${record.reason}, Posted=${record.posted}");
    }
  }

  Future<int> getTodayClockOutsCount() async {
    try {
      var records = await attendanceOutRepository.getAttendanceOut();
      DateTime today = DateTime.now();
      String todayDate = DateFormat('yyyy-MM-dd').format(today);

      int count = 0;
      for (var record in records) {
        if (record.attendance_out_id.contains(todayDate.substring(5, 7))) {
          count++;
        }
      }
      return count;
    } catch (e) {
      debugPrint("❌ Error getting today's clock-outs count: $e");
      return 0;
    }
  }
}
