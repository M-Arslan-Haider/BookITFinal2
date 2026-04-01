

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:order_booking_app/ViewModels/attendance_view_model.dart';
import 'package:order_booking_app/ViewModels/location_view_model.dart';
import 'package:order_booking_app/ViewModels/attendance_out_view_model.dart';
import 'package:order_booking_app/ViewModels/update_function_view_model.dart';
import 'package:location/location.dart' as loc;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../Databases/util.dart';
import '../../LocatioPoints/ravelTimeViewModel.dart';
import '../../Tracker/location00.dart';
import '../../Tracker/trac.dart';
import '../../Utils/daily_work_time_manager.dart';
import '../../main.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class TimerCard extends StatefulWidget {
  const TimerCard({super.key});

  @override
  State<TimerCard> createState() => _TimerCardState();
}

class _TimerCardState extends State<TimerCard> with WidgetsBindingObserver {
  final locationViewModel = Get.find<LocationViewModel>();
  final attendanceViewModel = Get.find<AttendanceViewModel>();
  final attendanceOutViewModel = Get.find<AttendanceOutViewModel>();
  final updateFunctionViewModel = Get.find<UpdateFunctionViewModel>();
  final TravelTimeViewModel travelTimeViewModel = Get.put(TravelTimeViewModel());

  final loc.Location location = loc.Location();
  final Connectivity _connectivity = Connectivity();
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  Timer? _locationMonitorTimer;
  bool _wasLocationAvailable = true;
  bool _autoClockOutInProgress = false;

  Timer? _midnightClockOutTimer;
  Timer? _permissionCheckTimer;
  bool _isMidnightClockOutScheduled = false;

  Timer? _localBackupTimer;
  DateTime? _localClockInTime;
  String _localElapsedTime = '00:00:00';

  // Auto-sync variables
  Timer? _autoSyncTimer;
  bool _isOnline = false;
  bool _isSyncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Distance tracking
  double _currentDistance = 0.0;
  Timer? _distanceUpdateTimer;

  // Notification IDs
  int _notificationId = 0;

  // Method Channel for Native Service
  static const platform = MethodChannel('com.metaxperts.order_booking_app/location_monitor');

  // ✅ CRITICAL EVENT TIMESTAMP KEYS
  static const String KEY_EVENT_TIMESTAMP = 'critical_event_timestamp';
  static const String KEY_EVENT_REASON = 'critical_event_reason';
  static const String KEY_EVENT_DISTANCE = 'critical_event_distance';
  static const String KEY_HAS_CRITICAL_EVENT = 'has_critical_event_pending';
  static const String KEY_EVENT_LATITUDE = 'critical_event_latitude';
  static const String KEY_EVENT_LONGITUDE = 'critical_event_longitude';

  // ✅ NEW: Keys to freeze timer at event time
  static const String KEY_EVENT_ELAPSED_TIME = 'critical_event_elapsed_time';
  static const String KEY_IS_TIMER_FROZEN = 'is_timer_frozen';
  static const String KEY_FROZEN_DISPLAY_TIME = 'frozen_display_time';

  // ✅ NEW: Keys for GPX finalization tracking
  static const String KEY_GPX_FINALIZED = 'gpx_finalized_at';
  static const String KEY_GPX_FILE_PATH = 'currentGpxFilePath';
  static const String KEY_PENDING_GPX_CLOSE = 'pending_gpx_close';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initializeUrgentNotifications();
    _initializeFromPersistentState();
    _startAutoSyncMonitoring();
    _startDistanceUpdater();
    _scheduleMidnightClockOut();

    // ✅ START NATIVE MONITORING SERVICE
    _startNativeMonitoringService();

    // ✅ CRITICAL: Check immediately on init (handles killed app case)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndProcessCriticalEvent();
    });
  }

  // ✅ START NATIVE MONITORING SERVICE
  Future<void> _startNativeMonitoringService() async {
    try {
      if (Platform.isAndroid) {
        final bool result = await platform.invokeMethod('startMonitoring');
        debugPrint("✅ [NATIVE SERVICE] Started: $result");
      }
    } catch (e) {
      debugPrint("❌ [NATIVE SERVICE] Error starting: $e");
    }
  }

  // ✅ STOP NATIVE MONITORING SERVICE
  Future<void> _stopNativeMonitoringService() async {
    try {
      if (Platform.isAndroid) {
        final bool result = await platform.invokeMethod('stopMonitoring');
        debugPrint("🛑 [NATIVE SERVICE] Stopped: $result");
      }
    } catch (e) {
      debugPrint("❌ [NATIVE SERVICE] Error stopping: $e");
    }
  }

  // ✅ NEW: Finalize GPX file immediately on auto-clockout
  Future<void> _finalizeGPXFile({
    required DateTime eventTime,
    required double finalDistance,
    required double latitude,
    required double longitude,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? gpxFilePath = prefs.getString(KEY_GPX_FILE_PATH);

      if (gpxFilePath == null || gpxFilePath.isEmpty) {
        debugPrint("⚠️ [GPX FINALIZE] No GPX file path found");
        return;
      }

      File gpxFile = File(gpxFilePath);
      if (!await gpxFile.exists()) {
        debugPrint("⚠️ [GPX FINALIZE] GPX file does not exist: $gpxFilePath");
        return;
      }

      // Read current content
      String content = await gpxFile.readAsString();

      // Remove empty trkseg closing tag if present
      content = content.replaceAll('</trkseg>\n  </trk>\n</gpx>', '');
      content = content.replaceAll('</trkseg></trk></gpx>', '');

      // Add final trackpoint with event time
      String finalTrackPoint = '''
    <trkpt lat="$latitude" lon="$longitude">
      <time>${eventTime.toIso8601String()}</time>
      <desc>Auto-clockout: Location tracking stopped</desc>
    </trkpt>''';

      // Close the GPX file properly
      String finalContent = content.replaceAll('</trkseg>',
          '$finalTrackPoint\n    </trkseg>');

      // Ensure proper closing tags
      if (!finalContent.contains('</trk>')) {
        finalContent += '\n  </trk>\n</gpx>';
      }
      if (!finalContent.contains('</gpx>')) {
        finalContent += '\n</gpx>';
      }

      // Write atomically
      await gpxFile.writeAsString(finalContent, flush: true);

      // Mark as finalized with timestamp
      await prefs.setString(KEY_GPX_FINALIZED, eventTime.toIso8601String());
      await prefs.setBool(KEY_PENDING_GPX_CLOSE, false);

      // Save metadata for sync
      await prefs.setString('gpx_finalized_time', eventTime.toIso8601String());
      await prefs.setDouble('gpx_final_distance', finalDistance);
      await prefs.setString('gpx_final_file', gpxFilePath);
      await prefs.setBool('hasPendingGpxData', true);

      debugPrint("✅ [GPX FINALIZE] File finalized at $eventTime");
      debugPrint("✅ [GPX FINALIZE] Distance: $finalDistance km");
      debugPrint("✅ [GPX FINALIZE] File: $gpxFilePath");

    } catch (e) {
      debugPrint("❌ [GPX FINALIZE] Error: $e");
      // Mark as pending so we can retry
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(KEY_PENDING_GPX_CLOSE, true);
    }
  }

  // ✅ CHECK AND PROCESS CRITICAL EVENT ON APP START
  Future<void> _checkAndProcessCriticalEvent() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasCriticalEvent = prefs.getBool(KEY_HAS_CRITICAL_EVENT) ?? false;
    bool isTimerFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
    String? bgPayloadStr = prefs.getString('bg_clockout_payload');

    if (!hasCriticalEvent && !isTimerFrozen && (bgPayloadStr == null || bgPayloadStr.isEmpty)) {
      return;
    }

    debugPrint("🚨 [CRITICAL EVENT] Found pending critical event on startup");

    // ✅ Reset timer display ONCE (not multiple times)
    _localElapsedTime = "00:00:00";
    attendanceViewModel.elapsedTime.value = "00:00:00";
    _localBackupTimer?.cancel();
    _localBackupTimer = null;

    if (mounted) setState(() {});

    // ✅ Check if GPX needs finalization (app was killed before finalizing)
    bool needsGpxFinalization = prefs.getBool(KEY_PENDING_GPX_CLOSE) ?? false;
    String? gpxPath = prefs.getString('event_gpx_file_path') ?? prefs.getString(KEY_GPX_FILE_PATH);

    String? eventTimeStr = prefs.getString(KEY_EVENT_TIMESTAMP);
    String? eventReason = prefs.getString(KEY_EVENT_REASON);
    double? eventDistance = prefs.getDouble(KEY_EVENT_DISTANCE);
    double? eventLat = prefs.getDouble(KEY_EVENT_LATITUDE);
    double? eventLng = prefs.getDouble(KEY_EVENT_LONGITUDE);

    if (eventTimeStr != null) {
      DateTime eventTime = DateTime.parse(eventTimeStr);
      debugPrint("🚨 [CRITICAL EVENT] Event occurred at: $eventTime, Reason: $eventReason");

      if (needsGpxFinalization) {
        debugPrint("✅ [CRITICAL EVENT] GPX finalization needed — reason: $eventReason");
        await _finalizeGPXFile(
          eventTime: eventTime,
          finalDistance: eventDistance ?? 0.0,
          latitude: eventLat ?? 0.0,
          longitude: eventLng ?? 0.0,
        );
      }

      // ✅ Show notification ONCE
      Get.snackbar(
        '⚠️ Auto Clock-Out Occurred',
        'Event: ${_getReasonMessage(eventReason ?? 'unknown')}\nTime: ${DateFormat('HH:mm:ss').format(eventTime)}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        icon: const Icon(Icons.warning, color: Colors.white),
      );

      // ✅ Sync with server using REAL event time ONCE
      await _syncCriticalEventData(
        eventTime: eventTime,
        reason: eventReason ?? 'unknown',
        distance: eventDistance ?? 0.0,
        latitude: eventLat ?? 0.0,
        longitude: eventLng ?? 0.0,
      );

      await _clearCriticalEventData();

      await prefs.remove('bg_clockout_payload');

      _triggerAutoSync();

    } else if (bgPayloadStr != null && bgPayloadStr.isNotEmpty) {
      // ✅ Fallback for native background payload
      debugPrint("🚨 [CRITICAL EVENT] Processing native background payload");
      try {
        final ts = _extractJsonValue(bgPayloadStr, 'timestamp');
        final reason = _extractJsonValue(bgPayloadStr, 'reason');
        final distStr = _extractJsonValue(bgPayloadStr, 'distance');
        final latStr = _extractJsonValue(bgPayloadStr, 'latitude');
        final lngStr = _extractJsonValue(bgPayloadStr, 'longitude');

        if (ts != null) {
          DateTime eventTime = DateTime.parse(ts);
          double dist = double.tryParse(distStr ?? '0') ?? 0.0;
          double lat = double.tryParse(latStr ?? '0') ?? 0.0;
          double lng = double.tryParse(lngStr ?? '0') ?? 0.0;

          // Finalize GPX for background event
          if (gpxPath != null) {
            await _finalizeGPXFile(
              eventTime: eventTime,
              finalDistance: dist,
              latitude: lat,
              longitude: lng,
            );
          }

          await _syncCriticalEventData(
            eventTime: eventTime,
            reason: reason ?? 'unknown',
            distance: dist,
            latitude: lat,
            longitude: lng,
          );

          await prefs.remove('bg_clockout_payload');
          await prefs.remove(KEY_HAS_CRITICAL_EVENT);
          await prefs.remove(KEY_IS_TIMER_FROZEN);
          _triggerAutoSync();
        }
      } catch (e) {
        debugPrint("❌ [CRITICAL EVENT] Error parsing bg payload: $e");
      }
    }
  }

  // ✅ HELPER: Simple JSON string value extractor (no dart:convert needed)
  String? _extractJsonValue(String json, String key) {
    try {
      final pattern = '"$key":"';
      int start = json.indexOf(pattern);
      if (start == -1) return null;
      start += pattern.length;
      int end = json.indexOf('"', start);
      if (end == -1) return null;
      return json.substring(start, end);
    } catch (_) {
      return null;
    }
  }

  // ✅ SYNC CRITICAL EVENT DATA TO SERVER
  Future<void> _syncCriticalEventData({
    required DateTime eventTime,
    required String reason,
    required double distance,
    required double latitude,
    required double longitude,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Ensure fastClockOutTime is the REAL event time
      await prefs.setString('fastClockOutTime', eventTime.toIso8601String());
      await prefs.setDouble('fastClockOutDistance', distance);
      await prefs.setString('fastClockOutReason', reason);
      await prefs.setBool('hasFastClockOutData', true);
      await prefs.setBool('clockOutPending', true);

      // ✅ CRITICAL: Store the event date for GPX processing
      await prefs.setString('pendingGpxDate', DateFormat('dd-MM-yyyy').format(eventTime));

      debugPrint("✅ [SYNC] Using REAL event date: ${DateFormat('dd-MM-yyyy').format(eventTime)}");

      // Save attendance out
      await attendanceOutViewModel.fastSaveAttendanceOut(
        clockOutTime: eventTime,
        totalDistance: distance,
        isAuto: true,
        reason: reason,
      );

      debugPrint("✅ [SYNC] Critical event data synced with timestamp: $eventTime");

      _triggerAutoSync();

    } catch (e) {
      debugPrint("❌ [SYNC] Error: $e");
    }
  }

  // ✅ CLEAR CRITICAL EVENT DATA (but keep frozen time visible)
  Future<void> _clearCriticalEventData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(KEY_HAS_CRITICAL_EVENT);
    await prefs.remove(KEY_EVENT_TIMESTAMP);
    await prefs.remove(KEY_EVENT_REASON);
    await prefs.remove(KEY_EVENT_DISTANCE);
    await prefs.remove(KEY_EVENT_LATITUDE);
    await prefs.remove(KEY_EVENT_LONGITUDE);
    // Keep KEY_IS_TIMER_FROZEN and KEY_FROZEN_DISPLAY_TIME until next clock-in
    debugPrint("🧹 [CLEAR] Critical event data cleared (timer shows 00:00:00 until next clock-in)");
  }

  // ✅ SAVE CRITICAL EVENT DATA (Called when event happens in-app)
  Future<void> _saveCriticalEventData({
    required DateTime eventTime,
    required String reason,
    required double distance,
    required double latitude,
    required double longitude,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Capture current elapsed time for reference
    String elapsedAtEvent = _localElapsedTime;

    await prefs.setBool(KEY_HAS_CRITICAL_EVENT, true);
    await prefs.setBool(KEY_IS_TIMER_FROZEN, true);
    await prefs.setString(KEY_EVENT_TIMESTAMP, eventTime.toIso8601String());
    await prefs.setString(KEY_EVENT_REASON, reason);
    await prefs.setDouble(KEY_EVENT_DISTANCE, distance);
    await prefs.setDouble(KEY_EVENT_LATITUDE, latitude);
    await prefs.setDouble(KEY_EVENT_LONGITUDE, longitude);
    await prefs.setString(KEY_FROZEN_DISPLAY_TIME, "00:00:00");

    // ✅ CRITICAL: Mark GPX file as needing finalization IMMEDIATELY
    await prefs.setBool(KEY_PENDING_GPX_CLOSE, true);

    // ✅ CRITICAL: Save GPX file path for later finalization if needed
    String? gpxPath = prefs.getString(KEY_GPX_FILE_PATH);
    if (gpxPath != null) {
      await prefs.setString('event_gpx_file_path', gpxPath);
    }

    // Save fast clockout data with REAL event time
    await prefs.setString('fastClockOutTime', eventTime.toIso8601String());
    await prefs.setDouble('fastClockOutDistance', distance);
    await prefs.setString('fastClockOutReason', reason);
    await prefs.setBool('hasFastClockOutData', true);
    await prefs.setBool('clockOutPending', true);
    await prefs.setBool('isClockedIn', false);

    // Save background payload for app-killed scenarios
    await prefs.setString('bg_clockout_payload',
        '{"timestamp":"${eventTime.toIso8601String()}","reason":"$reason","elapsed_at_event":"$elapsedAtEvent","distance":$distance,"latitude":$latitude,"longitude":$longitude,"source":"flutter_foreground"}'
    );

    debugPrint("💾 [CRITICAL EVENT] Saved at: $eventTime");
    debugPrint("💾 [CRITICAL EVENT] GPX: $gpxPath");
  }

  // ✅ URGENT NOTIFICATION SETUP (IMMEDIATE)
  Future<void> _initializeUrgentNotifications() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel urgentChannel = AndroidNotificationChannel(
      'urgent_auto_clockout_channel',
      'URGENT Auto Clockout Notifications',
      description: 'High-priority channel for urgent auto clockout notifications',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      enableLights: true,
      ledColor: Colors.red,
    );

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(urgentChannel);
  }

  // ✅ SHOW URGENT NOTIFICATION METHOD (IMMEDIATE)
  Future<void> _showUrgentNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    _notificationId++;

    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'urgent_auto_clockout_channel',
      'URGENT Auto Clockout Notifications',
      channelDescription: 'High-priority channel for urgent auto clockout notifications',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      timeoutAfter: 5000,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      color: Colors.red,
      ledColor: Colors.red,
      ledOnMs: 1000,
      ledOffMs: 500,
      fullScreenIntent: true,
      ongoing: false,
      autoCancel: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const DarwinNotificationDetails iosDetails =
    DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      _notificationId,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    debugPrint("🔔 [URGENT NOTIFICATION] Sent: $title");

    if (mounted) {
      Get.snackbar(
        title,
        body,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        icon: const Icon(Icons.warning, color: Colors.white),
        shouldIconPulse: true,
        barBlur: 10,
        isDismissible: true,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restoreEverything();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLocationMonitoring();
    _localBackupTimer?.cancel();
    _autoSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _distanceUpdateTimer?.cancel();
    _midnightClockOutTimer?.cancel();
    _permissionCheckTimer?.cancel();
    // Don't stop native service here - it should keep running
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint("🔄 [LIFECYCLE] App state changed: $state");

    if (state == AppLifecycleState.resumed) {
      // ✅ CHECK CRITICAL EVENT FIRST (before restoring anything)
      _checkAndProcessCriticalEvent();

      // ✅ THEN restore everything
      _restoreEverything();
      _checkConnectivityAndSync();
      _rescheduleMidnightClockOut();

      // Restart native service if needed
      _startNativeMonitoringService();
    } else if (state == AppLifecycleState.paused) {
      debugPrint("✅ [LIFECYCLE] App paused - Native service continues monitoring");
    }
  }

  // ✅ SCHEDULE MIDNIGHT AUTO CLOCKOUT (11:58 PM)
  void _scheduleMidnightClockOut() {
    SharedPreferences.getInstance().then((prefs) {
      bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
      if (isFrozen) {
        debugPrint("⏰ [MIDNIGHT] Timer is frozen, not scheduling midnight clockout");
        return;
      }

      if (!attendanceViewModel.isClockedIn.value) {
        return;
      }

      _midnightClockOutTimer?.cancel();

      final now = DateTime.now();
      final scheduledTime = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        58,
      );

      Duration timeUntilMidnight;
      if (now.isAfter(scheduledTime)) {
        final tomorrow = scheduledTime.add(const Duration(days: 1));
        timeUntilMidnight = tomorrow.difference(now);
      } else {
        timeUntilMidnight = scheduledTime.difference(now);
      }

      _midnightClockOutTimer = Timer(timeUntilMidnight, () async {
        if (attendanceViewModel.isClockedIn.value) {
          debugPrint("⏰ [MIDNIGHT] Auto clockout triggered at 11:58 PM");

          DateTime eventTime = DateTime.now();
          double currentDist = await _getCurrentDistance();
          double lat = locationViewModel.globalLatitude1.value;
          double lng = locationViewModel.globalLongitude1.value;

          await _saveCriticalEventData(
            eventTime: eventTime,
            reason: 'midnight_auto',
            distance: currentDist,
            latitude: lat,
            longitude: lng,
          );

          await _showUrgentNotification(
            title: '⚠️ AUTO CLOCKOUT - 11:58 PM',
            body: 'You have been automatically clocked out at 11:58 PM\nDuration: $_localElapsedTime',
            payload: 'midnight_auto',
          );

          await _handleAutoClockOut(
            reason: 'midnight_auto',
            context: context,
            eventTime: eventTime,
          );
        }
      });

      _isMidnightClockOutScheduled = true;
      debugPrint("⏰ [MIDNIGHT] Auto clockout scheduled for ${scheduledTime.hour}:${scheduledTime.minute}");
    });
  }

  void _rescheduleMidnightClockOut() {
    SharedPreferences.getInstance().then((prefs) {
      bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
      if (!isFrozen && attendanceViewModel.isClockedIn.value) {
        _scheduleMidnightClockOut();
      }
    });
  }

  // ✅ START PERMISSION MONITORING (location off detection only)
  void _startPermissionMonitoring() {
    // Cancel any existing timer FIRST to prevent orphaned duplicate timers
    _permissionCheckTimer?.cancel();
    _permissionCheckTimer = null;

    _wasLocationAvailable = true;
    debugPrint("🔄 [MONITOR] Initial state: locationAvailable=$_wasLocationAvailable");

    _permissionCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      // Check if timer is frozen first
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
      if (isFrozen) {
        debugPrint("🔒 [MONITOR] Timer is frozen, stopping monitoring");
        timer.cancel();
        return;
      }

      if (!attendanceViewModel.isClockedIn.value) {
        return;
      }

      // Check location services
      bool locationEnabled = await attendanceViewModel.isLocationAvailable();
      if (_wasLocationAvailable && !locationEnabled) {
        debugPrint("📍 [LOCATION] Location turned OFF - URGENT auto clockout");

        DateTime eventTime = DateTime.now();
        double currentDist = await _getCurrentDistance();
        double lat = locationViewModel.globalLatitude1.value;
        double lng = locationViewModel.globalLongitude1.value;

        await _saveCriticalEventData(
          eventTime: eventTime,
          reason: 'location_off_auto',
          distance: currentDist,
          latitude: lat,
          longitude: lng,
        );

        await _showUrgentNotification(
          title: '⚠️ LOCATION TURNED OFF',
          body: 'Auto clockout triggered immediately because location was turned off',
          payload: 'location_off_auto',
        );

        await _handleAutoClockOut(
          reason: 'location_off_auto',
          context: context,
          eventTime: eventTime,
        );
        return;
      }
      _wasLocationAvailable = locationEnabled;
    });
  }

  Future<bool> _checkLocationPermission(BuildContext context) async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_off,
                  size: 50,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 15),
                const Text(
                  "Location Permission Required",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "We need location access to continue.\n"
                      "Please enable location permission from app settings.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await Geolocator.openAppSettings();
                        },
                        child: const Text(
                          "Open Settings",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      );
      return false;
    }

    return true;
  }

  // ✅ HANDLE AUTO CLOCKOUT (Modified to accept eventTime)
  Future<void> _handleAutoClockOut({
    required String reason,
    required BuildContext context,
    DateTime? eventTime,
  }) async {
    if (_autoClockOutInProgress || !attendanceViewModel.isClockedIn.value) {
      return;
    }
    _autoClockOutInProgress = true;

    DateTime clockOutTime = eventTime ?? DateTime.now();

    // ✅ CRITICAL: Capture location data immediately before any async operations
    double finalLat = locationViewModel.globalLatitude1.value;
    double finalLng = locationViewModel.globalLongitude1.value;
    double finalDistance = _currentDistance > 0 ? _currentDistance : 0.0;

    debugPrint("⚡ [AUTO CLOCKOUT] START - Reason: $reason");
    debugPrint("⚡ [AUTO CLOCKOUT] Time: $clockOutTime");
    debugPrint("⚡ [AUTO CLOCKOUT] Location: $finalLat, $finalLng");
    debugPrint("⚡ [AUTO CLOCKOUT] Distance: $finalDistance");

    try {
      _stopLocationMonitoring();
      _localBackupTimer?.cancel();
      _midnightClockOutTimer?.cancel();
      _permissionCheckTimer?.cancel();

      // ✅ STEP 2: Stop background service immediately
      final service = FlutterBackgroundService();
      service.invoke("stopService");

      // ✅ STEP 3: Stop native monitoring
      await _stopNativeMonitoringService();

      // ✅ STEP 4: Disable background location mode
      try {
        await location.enableBackgroundMode(enable: false);
      } catch (e) {
        debugPrint("⚠️ Background mode disable error: $e");
      }

      // ✅ STEP 5: Finalize GPX file with EXACT event data
      await _finalizeGPXFile(
        eventTime: clockOutTime,
        finalDistance: finalDistance,
        latitude: finalLat,
        longitude: finalLng,
      );

      // ✅ STEP 6: Save attendance out data locally
      SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setBool('isClockedIn', false);
      await prefs.setDouble('fastClockOutDistance', finalDistance);
      await prefs.setString('fastClockOutTime', clockOutTime.toIso8601String());
      await prefs.setBool('clockOutPending', true);
      await prefs.setBool('hasFastClockOutData', true);

      // ✅ Save location data for sync
      await prefs.setDouble('pendingLatOut', finalLat);
      await prefs.setDouble('pendingLngOut', finalLng);

      // ✅ STEP 7: Update UI state
      _localElapsedTime = '00:00:00';
      _localClockInTime = null;
      locationViewModel.isClockedIn.value = false;
      attendanceViewModel.isClockedIn.value = false;

      // ✅ STEP 8: Save to attendance out ViewModel
      await attendanceOutViewModel.fastSaveAttendanceOut(
        clockOutTime: clockOutTime,
        totalDistance: finalDistance,
        isAuto: true,
        reason: reason,
      );

      await DailyWorkTimeManager.recordClockOut(clockOutTime);

      await _clearCriticalEventData();
      SharedPreferences prefsClean = await SharedPreferences.getInstance();
      await prefsClean.remove('bg_clockout_payload');

      // ✅ STEP 9: Mark for immediate sync when online
      _triggerAutoSync();

      debugPrint("✅ [AUTO CLOCKOUT] COMPLETED at $clockOutTime");
      debugPrint("✅ [AUTO CLOCKOUT] All data saved locally");

    } catch (e) {
      debugPrint("❌ [AUTO CLOCKOUT] Error: $e");

      // Ensure state is cleared even on error
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isClockedIn', false);
      locationViewModel.isClockedIn.value = false;
      attendanceViewModel.isClockedIn.value = false;

      // Mark data as pending sync
      await prefs.setBool('clockOutPending', true);
    } finally {
      _autoClockOutInProgress = false;
    }
  }

  String _getReasonMessage(String reason) {
    switch (reason) {
      case 'midnight_auto':
        return 'You have been automatically clocked out at 11:58 PM';
      case 'location_off_auto':
        return 'Auto clockout because location services were turned off';
      default:
        return 'Auto clockout completed successfully';
    }
  }

  void _checkAndSyncPendingData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasPendingClockOut = prefs.getBool('hasPendingClockOutData') ?? false;
    bool clockOutPending = prefs.getBool('clockOutPending') ?? false;

    if (hasPendingClockOut || clockOutPending) {
      debugPrint("🔄 [PENDING SYNC] Found pending clock-out data - syncing...");
      _triggerAutoSync();
    }
  }

  void _startDistanceUpdater() {
    _distanceUpdateTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) async {
          // ✅ Check if timer is frozen
          SharedPreferences prefs = await SharedPreferences.getInstance();
          bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;

          if (isFrozen) {
            timer.cancel();
            return;
          }

          if (attendanceViewModel.isClockedIn.value) {
            await _updateCurrentDistance();
          }
        });
  }

  Future<void> _updateCurrentDistance() async {
    try {
      LocationService locationService = LocationService();
      await locationService.init();
      double distance = locationService.getCurrentDistance();

      if (mounted) {
        setState(() {
          _currentDistance = distance;
        });
      }
    } catch (e) {
      debugPrint("❌ Distance update error: $e");
    }
  }

  Future<double> _getCurrentDistance() async {
    if (_currentDistance > 0) {
      return _currentDistance;
    }

    try {
      LocationService locationService = LocationService();
      await locationService.init();
      return locationService.getCurrentDistance();
    } catch (e) {
      return 0.0;
    }
  }

  void _startAutoSyncMonitoring() async {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
        List<ConnectivityResult> results) {
      bool wasOnline = _isOnline;
      _isOnline = results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none);

      debugPrint("🌐 [CONNECTIVITY] Status: ${_isOnline ? 'ONLINE' : 'OFFLINE'}");

      if (_isOnline && !wasOnline && !_isSyncing) {
        debugPrint("🔄 [AUTO-SYNC] Internet connected - triggering auto-sync");
        _triggerAutoSync();
      }
    });

    _autoSyncTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (!_isSyncing) {
        _checkConnectivityAndSync();
      }
    });

    _checkConnectivityAndSync();
  }

  void _checkConnectivityAndSync() async {
    if (_isSyncing) {
      debugPrint('⏸️ Sync already in progress - skipping');
      return;
    }

    try {
      var results = await _connectivity.checkConnectivity();
      bool wasOnline = _isOnline;
      _isOnline = results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none);

      if (_isOnline && !wasOnline && !_isSyncing) {
        debugPrint("🔄 [AUTO-SYNC] Internet detected - triggering sync");
        _triggerAutoSync();
      }
    } catch (e) {
      debugPrint("❌ [CONNECTIVITY] Error checking connectivity: $e");
    }
  }

  // ✅ MODIFIED: Enhanced auto-sync to handle GPX with correct date
  void _triggerAutoSync() async {
    if (_isSyncing) {
      debugPrint('⏸️ Auto-sync already in progress - skipping');
      return;
    }

    _isSyncing = true;
    debugPrint('🔒 [AUTO-SYNC] Starting...');

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Check if we have GPX data to sync
      bool hasPendingGpx = prefs.getBool('hasPendingGpxData') ?? false;
      String? gpxFilePath = prefs.getString('gpx_final_file');

      // ✅ CRITICAL: Get the pending GPX date (the date when event occurred)
      String? pendingGpxDate = prefs.getString('pendingGpxDate');
      DateTime? eventDate;
      if (pendingGpxDate != null && pendingGpxDate.isNotEmpty) {
        try {
          eventDate = DateFormat('dd-MM-yyyy').parse(pendingGpxDate);
          debugPrint("📅 [AUTO-SYNC] Using pending GPX date: $pendingGpxDate");
        } catch (e) {
          debugPrint("⚠️ [AUTO-SYNC] Error parsing pendingGpxDate: $e");
        }
      }

      Get.snackbar(
        'Syncing Data',
        hasPendingGpx ? 'Syncing attendance & GPS data...' : 'Syncing attendance data...',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.blue.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      // ✅ First consolidate and save any pending GPX data with CORRECT DATE
      if (hasPendingGpx) {
        try {
          if (eventDate != null) {
            await locationViewModel.consolidateDailyGPXDataForDate(eventDate);
            await locationViewModel.saveLocationFromConsolidatedFileForDate(eventDate);
          } else {
            await locationViewModel.consolidateDailyGPXData();
            await locationViewModel.saveLocationFromConsolidatedFile();
          }
          debugPrint("✅ [AUTO-SYNC] GPX data processed");
        } catch (e) {
          debugPrint("⚠️ [AUTO-SYNC] GPX processing error: $e");
        }
      }

      // Sync all local data to server
      await updateFunctionViewModel.syncAllLocalDataToServer();

      // Clear pending flags
      await prefs.setBool('hasPendingClockOutData', false);
      await prefs.setBool('clockOutPending', false);
      await prefs.setBool('hasFastClockOutData', false);
      await prefs.setBool('hasPendingGpxData', false);
      await prefs.remove(KEY_PENDING_GPX_CLOSE);
      await prefs.remove('pendingGpxDate');

      debugPrint('✅ [AUTO-SYNC] Completed');

    } catch (e) {
      debugPrint('❌ [AUTO-SYNC FAILED] Error: $e');
    } finally {
      _isSyncing = false;
      debugPrint('🔓 [AUTO-SYNC UNLOCKED]');
    }
  }

  void _restoreEverything() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isClockedIn = prefs.getBool('isClockedIn') ?? false;
    bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;

    // ✅ If timer is frozen, show 00:00:00 (not elapsed time)
    if (isFrozen) {
      debugPrint("🔒 [RESTORE] Timer is frozen - showing 00:00:00");

      _localElapsedTime = "00:00:00";
      attendanceViewModel.elapsedTime.value = "00:00:00";

      locationViewModel.isClockedIn.value = false;
      attendanceViewModel.isClockedIn.value = false;

      if (mounted) {
        setState(() {});
      }
      return;
    }

    if (isClockedIn) {
      debugPrint("🎯 [BULLETPROOF] Restoring EVERYTHING...");

      locationViewModel.isClockedIn.value = true;
      attendanceViewModel.isClockedIn.value = true;

      _startLocalBackupTimer();
      _scheduleMidnightClockOut();
      _startPermissionMonitoring();

      if (mounted) {
        setState(() {});
      }

      debugPrint("✅ [BULLETPROOF] Everything restored successfully");
    }
  }

  void _startLocalBackupTimer() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // ✅ Check if timer is frozen before starting
    bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
    if (isFrozen) {
      debugPrint("🔒 [BACKUP TIMER] Timer is frozen, not starting backup timer");
      return;
    }

    String? clockInTimeString = prefs.getString('clockInTime');

    if (clockInTimeString == null) return;

    _localClockInTime = DateTime.parse(clockInTimeString);
    _localBackupTimer?.cancel();

    _localBackupTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // ✅ Check if frozen during timer execution
      SharedPreferences.getInstance().then((prefs) {
        bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
        if (isFrozen) {
          timer.cancel();
          debugPrint("🔒 [BACKUP TIMER] Frozen state detected, stopping timer");
          return;
        }
      });

      if (_localClockInTime == null) return;

      final now = DateTime.now();
      final duration = now.difference(_localClockInTime!);

      String twoDigits(int n) => n.toString().padLeft(2, '0');
      String hours = twoDigits(duration.inHours);
      String minutes = twoDigits(duration.inMinutes.remainder(60));
      String seconds = twoDigits(duration.inSeconds.remainder(60));

      _localElapsedTime = '$hours:$minutes:$seconds';
      attendanceViewModel.elapsedTime.value = _localElapsedTime;

      // ✅ SAVE ELAPSED TIME TO PREFERENCES (for native service to read)
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('elapsed_time', _localElapsedTime);
      });

      if (mounted) {
        setState(() {});
      }
    });

    debugPrint("✅ [BACKUP TIMER] Local backup timer started");
  }

  Future<void> _initializeFromPersistentState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isClockedIn = prefs.getBool('isClockedIn') ?? false;
    bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;

    debugPrint("🔄 [INIT] Restoring state: isClockedIn = $isClockedIn, isFrozen = $isFrozen");

    // ✅ Handle frozen state first - timer shows 00:00:00 (reset)
    if (isFrozen) {
      debugPrint("🔒 [INIT] Timer is frozen - resetting display to 00:00:00");

      _localElapsedTime = "00:00:00";
      attendanceViewModel.elapsedTime.value = "00:00:00";
      locationViewModel.isClockedIn.value = false;
      attendanceViewModel.isClockedIn.value = false;

      if (mounted) {
        setState(() {});
      }
      return;
    }

    locationViewModel.isClockedIn.value = isClockedIn;
    attendanceViewModel.isClockedIn.value = isClockedIn;

    if (isClockedIn) {
      debugPrint("✅ [INIT] User was clocked in - starting everything...");

      _startBackgroundServices();
      _startLocationMonitoring();
      _startLocalBackupTimer();
      _scheduleMidnightClockOut();
      _startPermissionMonitoring();

      debugPrint("✅ [INIT] Full clocked-in state restored");
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Obx(() {
                  String displayTime = _localElapsedTime;

                  if (displayTime == '00:00:00' &&
                      attendanceViewModel.isClockedIn.value) {
                    displayTime = attendanceViewModel.elapsedTime.value;
                  }

                  return Text(
                    displayTime,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: attendanceViewModel.isClockedIn.value
                          ? Colors.black87
                          : Colors.grey,
                    ),
                  );
                }),

                Obx(() {
                  if (attendanceViewModel.isClockedIn.value &&
                      _currentDistance > 0) {
                    return Text(
                      '${_currentDistance.toStringAsFixed(2)} km',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),
              ],
            ),

            const SizedBox(height: 5),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Obx(() {
                  return SizedBox(
                      width: 120,
                      height: 30,
                      child: ElevatedButton(
                        onPressed: attendanceViewModel.isClockedIn.value
                            ? null
                            : () async => _handleClockIn(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("Clock In", style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ))
                          ],
                        ),
                      )
                  );
                }),

                const SizedBox(width: 5),

                Obx(() {
                  return SizedBox(
                      width: 120,
                      height: 30,
                      child: ElevatedButton(
                        onPressed: attendanceViewModel.isClockedIn.value
                            ? () async => _handleClockOut(context)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("Clock Out", style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ))
                          ],
                        ),
                      )
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleClockOut(BuildContext context) async {
    debugPrint("🎯 [TIMERCARD] ===== FAST CLOCK-OUT STARTED =====");

    bool showLoadingDialog = true;
    DateTime startTime = DateTime.now();
    Timer? loadingTimer;

    if (showLoadingDialog) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            AlertDialog(
              backgroundColor: Colors.white.withOpacity(0.9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  SizedBox(height: 15),
                  Text(
                    "Processing clock-out...",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Please wait 3 seconds",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
      );

      loadingTimer = Timer(Duration(seconds: 3), () {});
    }

    try {
      _stopLocationMonitoring();
      _localBackupTimer?.cancel();
      _midnightClockOutTimer?.cancel();
      _permissionCheckTimer?.cancel();
      _permissionCheckTimer = null;

      double finalDistance = _currentDistance;
      if (finalDistance <= 0) {
        try {
          LocationService locationService = LocationService();
          await locationService.init();
          finalDistance = locationService.getCurrentDistance();
          if (finalDistance <= 0) finalDistance = 0.0;
        } catch (e) {
          finalDistance = 0.0;
        }
      }

      DateTime clockOutTime = DateTime.now();

      SharedPreferences prefs = await SharedPreferences.getInstance();

      // ✅ CLEAR FROZEN STATE ON MANUAL CLOCK OUT (new day started)
      await prefs.remove(KEY_IS_TIMER_FROZEN);
      await prefs.remove(KEY_FROZEN_DISPLAY_TIME);
      await prefs.remove(KEY_PENDING_GPX_CLOSE);
      await prefs.remove('hasPendingGpxData');
      await prefs.remove('gpx_final_file');
      await prefs.remove('event_gpx_file_path');

      await prefs.setBool('isClockedIn', false);
      await prefs.setDouble('fastClockOutDistance', finalDistance);
      await prefs.setString('fastClockOutTime', clockOutTime.toIso8601String());
      await prefs.setBool('clockOutPending', true);
      await prefs.setBool('hasFastClockOutData', true);

      await prefs.setBool('hasPendingGpxData', true);
      await prefs.setString('pendingGpxDate', DateFormat('dd-MM-yyyy').format(clockOutTime));

      locationViewModel.isClockedIn.value = false;
      attendanceViewModel.isClockedIn.value = false;

      _localElapsedTime = '00:00:00';
      _localClockInTime = null;

      await attendanceOutViewModel.fastSaveAttendanceOut(
        clockOutTime: clockOutTime,
        totalDistance: finalDistance,
        isAuto: false,
        reason: 'manual_clockout',
      );

      await DailyWorkTimeManager.recordClockOut(DateTime.now());

      final service = FlutterBackgroundService();
      service.invoke("stopService");

      // ✅ STOP NATIVE MONITORING
      await _stopNativeMonitoringService();

      try {
        await location.enableBackgroundMode(enable: false);
      } catch (e) {
        debugPrint("⚠️ Background mode disable error: $e");
      }

      DateTime endTime = DateTime.now();
      Duration elapsedTime = endTime.difference(startTime);

      if (elapsedTime.inSeconds < 3) {
        int remainingSeconds = 3 - elapsedTime.inSeconds;
        await Future.delayed(Duration(seconds: remainingSeconds));
      }

      if (loadingTimer != null) loadingTimer.cancel();
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();

      Get.snackbar(
        '✅ Clock Out Complete',
        'Data saved locally',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 2),
      );

      debugPrint("✅ [CLOCK-OUT] COMPLETED IN <3 SECONDS");

      _scheduleHeavyOperations(clockOutTime, finalDistance);
    } catch (e) {
      debugPrint("❌ [FAST CLOCK-OUT] Error: $e");

      DateTime endTime = DateTime.now();
      Duration elapsedTime = endTime.difference(startTime);

      if (elapsedTime.inSeconds < 3) {
        int remainingSeconds = 3 - elapsedTime.inSeconds;
        await Future.delayed(Duration(seconds: remainingSeconds));
      }

      if (loadingTimer != null) loadingTimer.cancel();
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();

      Get.snackbar(
        'Clock Out Complete',
        'Data saved locally',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: Duration(seconds: 2),
      );
    }
  }

  Future<void> _handleClockIn(BuildContext context) async {
    debugPrint("🎯 [TIMERCARD] ===== CLOCK-IN STARTED =====");

    // ✅ CLEAR all pending flags from previous session
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(KEY_IS_TIMER_FROZEN);
    await prefs.remove(KEY_FROZEN_DISPLAY_TIME);
    await prefs.remove(KEY_PENDING_GPX_CLOSE);
    await prefs.remove('hasPendingGpxData');
    await prefs.remove('gpx_final_file');
    await prefs.remove('event_gpx_file_path');
    _permissionCheckTimer?.cancel();
    _permissionCheckTimer = null;
    _localElapsedTime = '00:00:00';

    bool hasPermission = await _checkLocationPermission(context);
    if (!hasPermission) {
      debugPrint("🚫 [CLOCK-IN] Blocked — location permission not granted");
      return;
    }

    bool locationAvailable = await attendanceViewModel.isLocationAvailable();
    if (!locationAvailable) {
      Get.snackbar(
        'Location Required',
        'Please enable Location Services to clock in',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          AlertDialog(
            backgroundColor: Colors.white,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.green),
                SizedBox(height: 15),
                Text('Checking permissions...',
                    style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
    );

    try {
      LocationService locationService = LocationService();
      await locationService.init();
      await locationService.listenLocation();

      final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final downloadDirectory = await getDownloadsDirectory();
      final filePath = "${downloadDirectory!.path}/track_${user_id}_$date.gpx";
      File file = File(filePath);

      if (!file.existsSync()) {
        String initialGPX = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="OrderBookingApp">
  <trk>
    <name>Daily Track $date</name>
    <trkseg>
    </trkseg>
  </trk>
</gpx>''';
        await file.writeAsString(initialGPX);
        debugPrint("✅ Created empty GPX file for tracking");
      }

      double initialDistance = locationService.getCurrentDistance();
      if (initialDistance > 0.001) {
        locationService.resetDistance();
        initialDistance = 0.0;
      }

      await attendanceViewModel.saveFormAttendanceIn();
      _startBackgroundServices();

      locationViewModel.isClockedIn.value = true;
      attendanceViewModel.isClockedIn.value = true;

      await prefs.setBool('isClockedIn', true);
      await prefs.setString(KEY_GPX_FILE_PATH, filePath);
      await prefs.setString(
          'currentSessionStart', DateTime.now().toIso8601String());

      _startLocalBackupTimer();
      _startLocationMonitoring();
      _scheduleMidnightClockOut();
      _startPermissionMonitoring();

      // ✅ START NATIVE MONITORING SERVICE
      await _startNativeMonitoringService();

      travelTimeViewModel.startTracking();
      debugPrint("📍 [TRAVEL TIME] Travel tracking started");

      await _updateCurrentDistance();
      await DailyWorkTimeManager.recordClockIn(DateTime.now());

      debugPrint("✅ [CLOCK-IN] ===== COMPLETED SUCCESSFULLY =====");

      if (Navigator.of(context).canPop()) Navigator.of(context).pop();

      Get.snackbar(
        '✅ Clocked In Successfully',
        'GPS tracking started',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        icon: Icon(Icons.check_circle, color: Colors.white),
      );
    } catch (e) {
      debugPrint("❌ [CLOCK-IN] Error: $e");

      if (Navigator.of(context).canPop()) Navigator.of(context).pop();

      Get.snackbar(
        'Error',
        'Failed to clock in: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _startLocationMonitoring() {
    _wasLocationAvailable = true;
    _autoClockOutInProgress = false;

    _locationMonitorTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
          // ✅ Check if frozen
          SharedPreferences prefs = await SharedPreferences.getInstance();
          bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
          if (isFrozen) {
            timer.cancel();
            return;
          }

          if (!attendanceViewModel.isClockedIn.value) {
            _stopLocationMonitoring();
            return;
          }

          bool currentLocationAvailable = await attendanceViewModel
              .isLocationAvailable();

          if (_wasLocationAvailable && !currentLocationAvailable) {
            debugPrint("📍 [LOCATION] Location OFF - URGENT auto clock-out");

            DateTime eventTime = DateTime.now();
            double currentDist = await _getCurrentDistance();
            double lat = locationViewModel.globalLatitude1.value;
            double lng = locationViewModel.globalLongitude1.value;

            await _saveCriticalEventData(
              eventTime: eventTime,
              reason: 'location_off_auto',
              distance: currentDist,
              latitude: lat,
              longitude: lng,
            );

            await _showUrgentNotification(
              title: '⚠️ LOCATION TURNED OFF',
              body: 'Auto clockout triggered immediately because location was turned off',
              payload: 'location_off_auto',
            );

            await _handleAutoClockOut(
              reason: 'location_off_auto',
              context: context,
              eventTime: eventTime,
            );
            return;
          }
          _wasLocationAvailable = currentLocationAvailable;
        });
  }

  void _startBackgroundServices() async {
    try {
      debugPrint("🛰 [BACKGROUND] Starting services...");

      final service = FlutterBackgroundService();
      await location.enableBackgroundMode(enable: true);

      initializeServiceLocation().catchError((e) =>
          debugPrint("Service init error: $e"));
      service.startService().catchError((e) =>
          debugPrint("Service start error: $e"));
      location.changeSettings(
          interval: 300, accuracy: loc.LocationAccuracy.high)
          .catchError((e) => debugPrint("Location settings error: $e"));

      debugPrint("✅ [BACKGROUND] Services started");
    } catch (e) {
      debugPrint("⚠ [BACKGROUND] Services error: $e");
    }
  }

  void _stopLocationMonitoring() {
    _locationMonitorTimer?.cancel();
    _locationMonitorTimer = null;
    _autoClockOutInProgress = false;
  }

  void _scheduleHeavyOperations(DateTime clockOutTime, double distance) async {
    debugPrint("🔄 Scheduling background operations...");

    Timer(Duration(seconds: 5), () async {
      try {
        debugPrint("🔄 [BACKGROUND] Starting heavy operations...");
        debugPrint("🔄 [BACKGROUND] Using event date: ${DateFormat('dd-MM-yyyy').format(clockOutTime)}");

        await locationViewModel.consolidateDailyGPXDataForDate(clockOutTime);
        await locationViewModel.saveLocationFromConsolidatedFileForDate(clockOutTime);

        SharedPreferences prefs = await SharedPreferences.getInstance();

        await prefs.setDouble('fullClockOutDistance', distance);
        await prefs.setString('fullClockOutTime', clockOutTime.toIso8601String());
        await prefs.setDouble('pendingLatOut', locationViewModel.globalLatitude1.value);
        await prefs.setDouble('pendingLngOut', locationViewModel.globalLongitude1.value);
        await prefs.setString('pendingAddress', locationViewModel.shopAddress.value);

        debugPrint("✅ [BACKGROUND] Heavy operations completed for date: ${DateFormat('dd-MM-yyyy').format(clockOutTime)}");

        _triggerPostClockOutSync();
      } catch (e) {
        debugPrint("⚠️ [BACKGROUND] Error in heavy operations: $e");
      }
    });
  }

  void _triggerPostClockOutSync() async {
    debugPrint("🔄 [POST-CLOCKOUT] Starting background sync...");

    try {
      var results = await _connectivity.checkConnectivity();
      bool isOnline = results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none);

      if (isOnline && !_isSyncing) {
        _isSyncing = true;

        await updateFunctionViewModel.syncAllLocalDataToServer();

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasPendingClockOutData', false);
        await prefs.setBool('clockOutPending', false);
        await prefs.setBool('hasFastClockOutData', false);

        debugPrint("✅ [POST-CLOCKOUT] Sync completed successfully");

        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.snackbar(
            'Sync Complete',
            'All data synchronized to server',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
          );
        });
      } else {
        debugPrint(
            "🌐 [POST-CLOCKOUT] Offline - Will sync when connection available");

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('clockOutPending', true);
      }
    } catch (e) {
      debugPrint("❌ [POST-CLOCKOUT] Sync error: $e");

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('clockOutPending', true);
    } finally {
      _isSyncing = false;
    }
  }
}