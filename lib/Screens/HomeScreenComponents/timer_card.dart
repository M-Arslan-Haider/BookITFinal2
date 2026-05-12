
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
import '../../Databases/dp_helper.dart';
import '../../Databases/util.dart';
import '../../Repositories/location_tracking_repository.dart';
import '../../Tracker/location_export_data.dart';
import '../../Tracker/location_tracking_service.dart';
import '../../Tracker/mqtt_work.dart';
import '../../Utils/daily_work_time_manager.dart';
import '../../main.dart';
import 'package:intl/intl.dart';

import '../clockout_alarm_service.dart';
import '../sync_notification_service.dart';

// ─────────────────────────────────────────────────────────────
//  FANCY SNACKBAR (Existing code - unchanged)
// ─────────────────────────────────────────────────────────────

enum _SnackType { success, error, warning, sync, info }

class _SnackCfg {
  final Color bg;
  final Color accent;
  final IconData icon;
  const _SnackCfg({required this.bg, required this.accent, required this.icon});
}

class FancySnack {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
      BuildContext context, {
        required String title,
        required String message,
        _SnackType type = _SnackType.info,
        Duration duration = const Duration(seconds: 4),
      }) {
    _timer?.cancel();
    try { _entry?.remove(); } catch (_) {}
    _entry = null;

    final overlay = Overlay.of(context);
    late OverlayEntry e;
    e = OverlayEntry(
      builder: (_) => _FancySnackWidget(
        title: title,
        message: message,
        type: type,
        onDismiss: () {
          _timer?.cancel();
          try { e.remove(); } catch (_) {}
          if (_entry == e) _entry = null;
        },
      ),
    );

    _entry = e;
    overlay.insert(e);
    _timer = Timer(duration, () {
      try { e.remove(); } catch (_) {}
      if (_entry == e) _entry = null;
    });
  }
}

class _FancySnackWidget extends StatefulWidget {
  final String title;
  final String message;
  final _SnackType type;
  final VoidCallback onDismiss;
  const _FancySnackWidget(
      {required this.title,
        required this.message,
        required this.type,
        required this.onDismiss});
  @override
  State<_FancySnackWidget> createState() => _FancySnackWidgetState();
}

class _FancySnackWidgetState extends State<_FancySnackWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _slide = Tween<Offset>(begin: const Offset(0, 1.8), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  _SnackCfg get _cfg {
    switch (widget.type) {
      case _SnackType.success:
        return const _SnackCfg(
            bg: Color(0xFF37474F),
            accent: Color(0xFF66BB6A),
            icon: Icons.check_circle_rounded);
      case _SnackType.error:
        return const _SnackCfg(
            bg: Color(0xFF37474F),
            accent: Color(0xFFEF5350),
            icon: Icons.cancel_rounded);
      case _SnackType.warning:
        return const _SnackCfg(
            bg: Color(0xFF37474F),
            accent: Color(0xFFFF9800),
            icon: Icons.warning_rounded);
      case _SnackType.sync:
        return const _SnackCfg(
            bg: Color(0xFF37474F),
            accent: Color(0xFF29B6F6),
            icon: Icons.cloud_sync_rounded);
      case _SnackType.info:
        return const _SnackCfg(
            bg: Color(0xFF455A64),
            accent: Color(0xFF90CAF9),
            icon: Icons.info_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: cfg.bg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 18,
                      offset: Offset(0, 6))
                ],
              ),
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cfg.accent.withOpacity(0.20)),
                      ),
                      Positioned(
                        top: 3,
                        left: 3,
                        child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cfg.accent.withOpacity(0.28))),
                      ),
                      Icon(cfg.icon, color: cfg.accent, size: 24),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(widget.message,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.80),
                                fontSize: 12.5,
                                height: 1.3)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white54, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TIMER CARD
// ─────────────────────────────────────────────────────────────

class TimerCard extends StatefulWidget {
  const TimerCard({super.key});

  @override
  State<TimerCard> createState() => _TimerCardState();
}

class _TimerCardState extends State<TimerCard> with WidgetsBindingObserver {

  final locationViewModel       = Get.find<LocationViewModel>();
  final attendanceViewModel     = Get.find<AttendanceViewModel>();
  final attendanceOutViewModel  = Get.find<AttendanceOutViewModel>();
  final updateFunctionViewModel = Get.find<UpdateFunctionViewModel>();

  final MqttTracker _mqttTracker = MqttTracker();
  final RxBool _mqttLive = false.obs;

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

  Timer? _autoSyncTimer;
  final RxBool _isOnline = false.obs;
  bool _isSyncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  double _currentDistance = 0.0;
  Timer? _distanceUpdateTimer;
  Timer? _mqttStatusTimer;
  int _notificationId = 0;

  final LocationExportService _exportService = LocationExportService();
  bool _isExporting = false;
  LocationExportStats _exportStats =
  const LocationExportStats(total: 0, posted: 0, pending: 0);

  static const platform =
  MethodChannel('com.metaxperts.order_booking_app/location_monitor');

  // ✅ NEW: Bubble channel
  static const bubbleChannel =
  MethodChannel('com.metaxperts.order_booking_app/floating_bubble');

  static const String KEY_IS_TIMER_FROZEN = 'is_timer_frozen';

  void _showSnack({
    required String title,
    required String message,
    _SnackType type = _SnackType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!mounted) return;
    FancySnack.show(context,
        title: title, message: message, type: type, duration: duration);
  }

  // ✅ NEW: Show floating bubble
  Future<void> _showFloatingBubble() async {
    try {
      await bubbleChannel.invokeMethod('showBubble');
      debugPrint('✅ Floating bubble shown');
    } catch (e) {
      debugPrint('❌ Failed to show bubble: $e');
    }
  }

  // ✅ NEW: Hide floating bubble
  Future<void> _hideFloatingBubble() async {
    try {
      await bubbleChannel.invokeMethod('hideBubble');
      debugPrint('✅ Floating bubble hidden');
    } catch (e) {
      debugPrint('❌ Failed to hide bubble: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  initState / dispose / lifecycle
  // ══════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeUrgentNotifications();
    _startAutoSyncMonitoring();
    _startDistanceUpdater();

    _mqttStatusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final live = _mqttTracker.isMqttConnected;
      if (_mqttLive.value != live) _mqttLive.value = live;
    });

    _mqttTracker.initialize().then((_) {
      debugPrint('✅ MQTT Tracker initialized | userId=${_mqttTracker.userId}');
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkForBackgroundClockout();
      await _initDailyState();
      await _initializeFromPersistentState();
      _scheduleMidnightClockOut();
      await _startNativeMonitoringService();
      _refreshExportStats();
    });
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
    _mqttStatusTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restoreEverything();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint("🔄 [LIFECYCLE] App state changed: $state");

    if (state == AppLifecycleState.paused) {
      // ✅ NEW: App minimize - show bubble
      if (attendanceViewModel.isClockedIn.value) {
        _showFloatingBubble();
      }
    } else if (state == AppLifecycleState.resumed) {
      // ✅ NEW: App resume - hide bubble
      _hideFloatingBubble();

      _checkForBackgroundClockout().then((__) {
        _restoreEverything();
        _checkConnectivityAndSync();
        _rescheduleMidnightClockOut();
        _startNativeMonitoringService();
      });
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  LOCATION CSV EXPORT (Existing - unchanged)
  // ══════════════════════════════════════════════════════════════

  Future<void> _refreshExportStats() async {
    final stats = await _exportService.getStats();
    if (mounted) setState(() => _exportStats = stats);
  }

  Future<void> _handleExport(BuildContext context) async {
    if (_isExporting) return;

    final permResult = await _exportService.checkAndRequestPermission();

    if (permResult == StoragePermissionResult.permanentlyDenied) {
      _showSnack(
        title: 'Storage Permission Denied',
        message:
        'Please enable "All files access" in App Settings to export data.',
        type: _SnackType.error,
        duration: const Duration(seconds: 6),
      );
      return;
    }

    setState(() => _isExporting = true);

    _showSnack(
      title: 'Exporting…',
      message: 'Building CSV from local database…',
      type: _SnackType.sync,
    );

    final result = await _exportService.exportToCSV();

    setState(() => _isExporting = false);

    if (result.success) {
      _showSnack(
        title: '✅ Export Successful',
        message:
        '${result.totalRows} rows  •  ${result.postedRows} synced  •  '
            '${result.pendingRows} pending\n📁 ${result.filePath}',
        type: _SnackType.success,
        duration: const Duration(seconds: 7),
      );
      await _refreshExportStats();
    } else {
      _showSnack(
        title: 'Export Failed',
        message: result.message,
        type: _SnackType.error,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  NATIVE SERVICE (Existing - unchanged)
  // ══════════════════════════════════════════════════════════════

  Future<void> _startNativeMonitoringService() async {
    try {
      if (Platform.isAndroid) {
        final prefs = await SharedPreferences.getInstance();

        if (!(prefs.getBool('flutter.isClockedIn') ?? false)) return;

        final userId      = prefs.getString('user_id')     ?? prefs.getString('emp_id')  ?? '';
        final bookerName  = prefs.getString('booker_name') ?? prefs.getString('emp_name') ?? '';
        final designation = prefs.getString('designation') ?? '';

        await platform.invokeMethod('startMonitoring', {
          'userId':      userId,
          'bookerName':  bookerName,
          'designation': designation,
          'companyCode': 'PK-PUN-SKT-MX01-VT001',
        });
        debugPrint("✅ [NATIVE SERVICE] Started with userId=$userId");
      }
    } catch (e) {
      debugPrint("❌ [NATIVE SERVICE] Error starting: $e");
    }
  }

  Future<void> _stopNativeMonitoringService() async {
    try {
      if (Platform.isAndroid) {
        await platform.invokeMethod('stopMonitoring');
        debugPrint("🛑 [NATIVE SERVICE] Stopped");
      }
    } catch (e) {
      debugPrint("❌ [NATIVE SERVICE] Error stopping: $e");
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  HANDLE CLOCK IN (✅ NEW: Added bubble show)
  // ══════════════════════════════════════════════════════════════

  Future<void> _handleClockIn(BuildContext context) async {
    debugPrint("🎯 [TIMERCARD] CLOCK-IN STARTED");

    final prefsCheck = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if ((prefsCheck.getString(_kLastDate) ?? '') != today) {
      await _initDailyState();
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();

    final String userId = prefs.getString('user_id')    ??
        prefs.getString('emp_id')   ??
        prefs.getString('userId')   ?? '';
    final String bookerName = prefs.getString('booker_name') ??
        prefs.getString('emp_name') ??
        prefs.getString('userName') ?? '';
    final String designation = prefs.getString('designation') ??
        prefs.getString('job')               ??
        prefs.getString('userDesignation')   ?? '';

    debugPrint('👤 [CLOCK-IN] userId=$userId bookerName=$bookerName');

    await prefs.remove(KEY_IS_TIMER_FROZEN);
    await prefs.remove('flutter.$KEY_IS_TIMER_FROZEN');
    _permissionCheckTimer?.cancel();
    _permissionCheckTimer = null;
    _localElapsedTime = '00:00:00';

    bool hasPermission = await _checkLocationPermission(context);
    if (!hasPermission) return;

    bool locationAvailable = await attendanceViewModel.isLocationAvailable();
    if (!locationAvailable) {
      _showSnack(
          title: 'Location Required',
          message: 'Please enable Location Services to clock in.',
          type: _SnackType.error,
          duration: const Duration(seconds: 5));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: Colors.white,
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: Colors.green),
          SizedBox(height: 15),
          Text('Starting GPS tracking…',
              style: TextStyle(fontWeight: FontWeight.w500)),
        ]),
      ),
    );

    try {
      await LocationTrackingService().startTracking();
      await attendanceViewModel.saveFormAttendanceIn();
      _startBackgroundServices();

      locationViewModel.isClockedIn.value   = true;
      attendanceViewModel.isClockedIn.value = true;

      await prefs.setBool('isClockedIn', true);
      await prefs.setString('currentSessionStart', DateTime.now().toIso8601String());

      final mqttStarted = await _mqttTracker.clockInMqtt(
        userId:      userId,
        bookerName:  bookerName,
        designation: designation,
      );
      _mqttLive.value = mqttStarted;
      debugPrint(mqttStarted
          ? '✅ [CLOCK-IN] MQTT tracking started'
          : '⚠️ [CLOCK-IN] MQTT start failed — Kotlin service may not have started');

      _startLocalBackupTimer();
      _startLocationMonitoring();
      _scheduleMidnightClockOut();
      _startPermissionMonitoring();

      // await LocationLogService.instance.startOnClockIn();
      await _updateCurrentDistance();
      await DailyWorkTimeManager.recordClockIn(DateTime.now());

      await SyncNotificationService.startPeriodicSyncReminder();
      debugPrint('✅ [CLOCK-IN] 15-min sync reminder started');

      // ✅ NEW: Show floating bubble after clock in
      await _showFloatingBubble();

      debugPrint("✅ [CLOCK-IN] COMPLETED");

      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      _showSnack(
          title: 'Clocked In',
          message: 'GPS + MQTT tracking started.',
          type: _SnackType.success,
          duration: const Duration(seconds: 3));
    } catch (e) {
      debugPrint("❌ [CLOCK-IN] Error: $e");
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      _showSnack(
          title: 'Clock In Failed',
          message: 'Failed to clock in: ${e.toString()}',
          type: _SnackType.error);
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  HANDLE CLOCK OUT (✅ NEW: Added bubble hide)
  // ══════════════════════════════════════════════════════════════

  Future<void> _handleClockOut(BuildContext context) async {
    debugPrint("🎯 [TIMERCARD] CLOCK-OUT STARTED");

    DateTime startTime = DateTime.now();
    Timer? loadingTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: const [
          CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green)),
          SizedBox(height: 15),
          Text("Processing clock-out…",
              style: TextStyle(fontWeight: FontWeight.w500)),
          SizedBox(height: 5),
          Text("Please wait", style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ),
    );
    loadingTimer = Timer(const Duration(seconds: 2), () {});

    try {
      _stopLocationMonitoring();
      await LocationTrackingService().stopTracking();

      _localBackupTimer?.cancel();
      _midnightClockOutTimer?.cancel();
      _permissionCheckTimer?.cancel();
      _permissionCheckTimer = null;

      final repo      = LocationTrackingRepository();
      final dbHelper  = DBHelper();

      final unpostedRows = await dbHelper.getUnpostedLocationTracking();
      final allRows      = await dbHelper.getAllLocationTracking();
      debugPrint("📊 [CLOCKOUT] Total: ${allRows.length}, Pending: ${unpostedRows.length}");

      double finalDistance = _currentDistance;
      if (finalDistance <= 0) {
        finalDistance = await _calculateDistanceFromTrackingPoints();
      }

      DateTime clockOutTime = DateTime.now();
      SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.remove(KEY_IS_TIMER_FROZEN);
      await prefs.remove('flutter.$KEY_IS_TIMER_FROZEN');
      await prefs.setBool('isClockedIn', false);
      await prefs.setDouble('fastClockOutDistance', finalDistance);
      await prefs.setString('fastClockOutTime', clockOutTime.toIso8601String());
      await prefs.setBool('clockOutPending', true);
      await prefs.setBool('hasFastClockOutData', true);

      locationViewModel.isClockedIn.value   = false;
      attendanceViewModel.isClockedIn.value = false;
      _localElapsedTime = '00:00:00';
      _localClockInTime = null;

      await attendanceOutViewModel.fastSaveAttendanceOut(
        clockOutTime:  clockOutTime,
        totalDistance: finalDistance,
        isAuto:        false,
        reason:        'User Clock Out',
      );

      await DailyWorkTimeManager.recordClockOut(DateTime.now());

      await _mqttTracker.clockOutMqtt();
      _mqttLive.value = false;
      debugPrint('🛑 [CLOCK-OUT] MQTT tracking stopped');

      await SyncNotificationService.stopPeriodicSyncReminder();
      debugPrint('🛑 [CLOCK-OUT] 15-min sync reminder stopped');

      // ✅ NEW: Hide bubble on clock out
      // ✅ NEW: Close bubble completely on clock out
      await _closeFloatingBubble();
      await _hideFloatingBubble();

      final service = FlutterBackgroundService();
      service.invoke("stopService");
      await _stopNativeMonitoringService();

      try {
        await location.enableBackgroundMode(enable: false);
      } catch (e) {
        debugPrint("⚠️ Background mode disable error: $e");
      }

      await repo.postDataFromDatabaseToAPI();
      await _hardResetAllTimerState();

      final elapsed = DateTime.now().difference(startTime);
      if (elapsed.inSeconds < 2) {
        await Future.delayed(Duration(seconds: 2 - elapsed.inSeconds));
      }

      loadingTimer.cancel();
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();

      _showSnack(
          title: 'Clocked Out',
          message: 'Your session has been saved successfully.',
          type: _SnackType.success,
          duration: const Duration(seconds: 4));

      debugPrint("✅ [CLOCK-OUT] COMPLETED");
    } catch (e) {
      debugPrint("❌ [CLOCK-OUT] Error: $e");
      loadingTimer?.cancel();
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      _showSnack(
          title: 'Saved Locally',
          message: 'Data saved. Will sync automatically when online.',
          type: _SnackType.warning,
          duration: const Duration(seconds: 4));
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  AUTO CLOCK-OUT (✅ NEW: Added bubble hide)
  // ══════════════════════════════════════════════════════════════

  Future<void> _handleAutoClockOut({
    required String reason,
    required BuildContext context,
    DateTime? eventTime,
  }) async {
    if (_autoClockOutInProgress || !attendanceViewModel.isClockedIn.value) return;
    _autoClockOutInProgress = true;

    final DateTime clockOutTime  = eventTime ?? DateTime.now();
    final double   finalDistance = _currentDistance;
    final double   finalLat      = locationViewModel.globalLatitude1.value;
    final double   finalLng      = locationViewModel.globalLongitude1.value;

    debugPrint("⚡ [AUTO CLOCKOUT] START — Reason: $reason");

    try {
      _localBackupTimer?.cancel();
      _localBackupTimer = null;
      _locationMonitorTimer?.cancel();
      _locationMonitorTimer = null;
      _midnightClockOutTimer?.cancel();
      _permissionCheckTimer?.cancel();
      _permissionCheckTimer = null;

      _localClockInTime = null;
      _localElapsedTime = '00:00:00';
      _accumulatedSeconds = 0;
      attendanceViewModel.elapsedTime.value = '00:00:00';
      locationViewModel.isClockedIn.value   = false;
      attendanceViewModel.isClockedIn.value = false;
      if (mounted) setState(() {});

      await LocationTrackingService().stopTracking();
      FlutterBackgroundService().invoke("stopService");
      await _stopNativeMonitoringService();

      await _mqttTracker.clockOutMqtt();
      _mqttLive.value = false;
      debugPrint('🛑 [AUTO CLOCKOUT] MQTT stopped');

      await SyncNotificationService.stopPeriodicSyncReminder();
      debugPrint('🛑 [CLOCK-OUT] 15-min sync reminder stopped');

      // ✅ NEW: Hide bubble on auto clock out
      // ✅ NEW: Close bubble completely on clock out
      await _closeFloatingBubble();
      await _hideFloatingBubble();

      // await LocationLogService.instance.stopOnClockOut();

      try { await location.enableBackgroundMode(enable: false); }
      catch (e) { debugPrint("⚠️ BG mode disable: $e"); }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isClockedIn', false);
      await prefs.setDouble('fastClockOutDistance', finalDistance);
      await prefs.setString('fastClockOutTime', clockOutTime.toIso8601String());
      await prefs.setBool('clockOutPending', true);
      await prefs.setBool('hasFastClockOutData', true);
      await prefs.setDouble('pendingLatOut', finalLat);
      await prefs.setDouble('pendingLngOut', finalLng);
      await prefs.setBool(KEY_IS_TIMER_FROZEN, true);
      await prefs.setBool('flutter.$KEY_IS_TIMER_FROZEN', true);

      await _hardResetAllTimerState();
      await attendanceOutViewModel.fastSaveAttendanceOut(
        clockOutTime:  clockOutTime,
        totalDistance: finalDistance,
        isAuto:        true,
        reason:        reason,
      );
      await DailyWorkTimeManager.recordClockOut(clockOutTime);
      _triggerAutoSync();

      debugPrint("✅ [AUTO CLOCKOUT] COMPLETED — Reason: $reason");
      if (mounted) {
        _showSnack(
          title: 'Auto Clock-Out',
          message: 'Timer stopped automatically.',
          type: _SnackType.error,
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      debugPrint("❌ [AUTO CLOCKOUT] Error: $e");
      _localBackupTimer?.cancel();
      _localBackupTimer = null;
      _localClockInTime = null;
      _localElapsedTime = '00:00:00';
      _accumulatedSeconds = 0;
      attendanceViewModel.elapsedTime.value = '00:00:00';
      locationViewModel.isClockedIn.value   = false;
      attendanceViewModel.isClockedIn.value = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isClockedIn', false);
      await prefs.setBool('clockOutPending', true);
      await _hardResetAllTimerState();
    } finally {
      _autoClockOutInProgress = false;
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  BACKGROUND CLOCKOUT CHECK (Existing - unchanged)
  // ══════════════════════════════════════════════════════════════

  Future<void> _checkForBackgroundClockout() async {
    final prefs = await SharedPreferences.getInstance();

    final hasCriticalEvent =
        (prefs.getBool('has_critical_event_pending') ?? false) ||
            (prefs.getBool('flutter.has_critical_event_pending') ?? false);

    if (!hasCriticalEvent) return;

    final reason = prefs.getString('critical_event_reason') ??
        prefs.getString('flutter.critical_event_reason') ??
        'System ClockOut';

    debugPrint('⚡ [BG CLOCKOUT] Detected: $reason');

    await prefs.remove('has_critical_event_pending');
    await prefs.remove('flutter.has_critical_event_pending');
    await prefs.remove('critical_event_reason');
    await prefs.remove('flutter.critical_event_reason');
    await prefs.remove(KEY_IS_TIMER_FROZEN);
    await prefs.remove('flutter.$KEY_IS_TIMER_FROZEN');

    _stopLocationMonitoring();
    _localBackupTimer?.cancel();
    _localBackupTimer = null;
    _midnightClockOutTimer?.cancel();
    _permissionCheckTimer?.cancel();
    _permissionCheckTimer = null;

    await _mqttTracker.clockOutMqtt();
    _mqttLive.value = false;

    await _hardResetAllTimerState();
    locationViewModel.isClockedIn.value   = false;
    attendanceViewModel.isClockedIn.value = false;

    if (mounted) {
      final snackTitle = reason.contains('Location Off')
          ? '📍 Location Turned Off'
          : reason.contains('Permission')
          ? '🔒 Location Permission Revoked'
          : '⚠️ Auto Clock-Out';

      _showSnack(
        title: snackTitle,
        message: 'You were automatically clocked out. Tap Clock In to start again.',
        type: _SnackType.error,
        duration: const Duration(seconds: 6),
      );
    }

    _triggerAutoSync();
    debugPrint('✅ [BG CLOCKOUT] Handled');
  }

  // ══════════════════════════════════════════════════════════════
  //  MIDNIGHT CLOCK-OUT (Existing - unchanged)
  // ══════════════════════════════════════════════════════════════

  void _scheduleMidnightClockOut() {
    SharedPreferences.getInstance().then((prefs) {
      bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
      if (isFrozen || !attendanceViewModel.isClockedIn.value) return;

      _midnightClockOutTimer?.cancel();

      final now           = DateTime.now();
      final scheduledTime = DateTime(now.year, now.month, now.day, 23, 58);
      final delay = now.isAfter(scheduledTime)
          ? scheduledTime.add(const Duration(days: 1)).difference(now)
          : scheduledTime.difference(now);

      _midnightClockOutTimer = Timer(delay, () async {
        if (attendanceViewModel.isClockedIn.value) {
          debugPrint("⏰ [MIDNIGHT] Auto clockout triggered");
          await _handleAutoClockOut(
              reason: 'System ClockOut - Midnight Time', context: context);
        }
      });
      _isMidnightClockOutScheduled = true;
      debugPrint("⏰ [MIDNIGHT] Auto clockout scheduled");
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

  // ══════════════════════════════════════════════════════════════
  //  PERMISSION MONITORING (Existing - unchanged)
  // ══════════════════════════════════════════════════════════════

  void _startPermissionMonitoring() {
    _permissionCheckTimer?.cancel();
    _permissionCheckTimer = null;
    _wasLocationAvailable = true;

    _permissionCheckTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
          if (isFrozen) { timer.cancel(); return; }
          if (!attendanceViewModel.isClockedIn.value) return;

          bool locationEnabled = await attendanceViewModel.isLocationAvailable();
          if (_wasLocationAvailable && !locationEnabled) {
            await _handleAutoClockOut(
                reason: 'System ClockOut - Location Off', context: context);
            return;
          }
          _wasLocationAvailable = locationEnabled;
        });
  }

  Future<bool> _checkLocationPermission(BuildContext context) async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        _showSnack(
          title: 'Permission Required',
          message: 'Location permission denied. Please enable it in Settings.',
          type: _SnackType.error,
          duration: const Duration(seconds: 5),
        );
      }
      return false;
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted && context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_off, size: 50, color: Colors.redAccent),
                  const SizedBox(height: 15),
                  const Text("Location Permission Required",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text(
                      "We need location access to continue.\nPlease enable location permission from app settings.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                        child: TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text("Cancel",
                                style: TextStyle(color: Colors.grey)))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await Geolocator.openAppSettings();
                          },
                          child: const Text("Open Settings",
                              style: TextStyle(color: Colors.white)),
                        )),
                  ]),
                ],
              ),
            ),
          ),
        );
      }
      return false;
    }
    return true;
  }

  // ══════════════════════════════════════════════════════════════
  //  DISTANCE (Existing - unchanged)
  // ══════════════════════════════════════════════════════════════

  void _startDistanceUpdater() {
    _distanceUpdateTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
          if (isFrozen) { timer.cancel(); return; }
          if (attendanceViewModel.isClockedIn.value) await _updateCurrentDistance();
        });
  }

  Future<void> _updateCurrentDistance() async {
    try {
      double distance = await _calculateDistanceFromTrackingPoints();
      if (mounted) setState(() { _currentDistance = distance; });
    } catch (e) {
      debugPrint("❌ Distance update error: $e");
    }
  }

  Future<double> _calculateDistanceFromTrackingPoints() async {
    try {
      final dbHelper  = DBHelper();
      final allPoints = await dbHelper.getAllLocationTracking();
      if (allPoints.length < 2) return 0.0;

      double totalDistance = 0.0;
      for (int i = 0; i < allPoints.length - 1; i++) {
        double lat1 = double.tryParse(allPoints[i]['lat_in']?.toString()       ?? '0') ?? 0;
        double lng1 = double.tryParse(allPoints[i]['lng_in']?.toString()       ?? '0') ?? 0;
        double lat2 = double.tryParse(allPoints[i+1]['lat_in']?.toString()     ?? '0') ?? 0;
        double lng2 = double.tryParse(allPoints[i+1]['lng_in']?.toString()     ?? '0') ?? 0;
        totalDistance += Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
      }
      return totalDistance / 1000;
    } catch (e) {
      debugPrint("❌ Error calculating distance: $e");
      return 0.0;
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  AUTO SYNC (Existing - unchanged)
  // ══════════════════════════════════════════════════════════════

  void _startAutoSyncMonitoring() async {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
          bool wasOnline = _isOnline.value;
          _isOnline.value = results.isNotEmpty &&
              results.any((r) => r != ConnectivityResult.none);
          if (_isOnline.value && !wasOnline && !_isSyncing) _triggerAutoSync();
        });

    _autoSyncTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!_isSyncing) _checkConnectivityAndSync();
    });
    _checkConnectivityAndSync();
  }

  void _checkConnectivityAndSync() async {
    if (_isSyncing) return;
    try {
      var results = await _connectivity.checkConnectivity();
      _isOnline.value = results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
      if (_isOnline.value && !_isSyncing) _triggerAutoSync();
    } catch (e) { debugPrint("❌ [CONNECTIVITY] Error: $e"); }
  }

  void _triggerAutoSync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      _showSnack(
          title: 'Syncing Data',
          message: 'Uploading location points to server…',
          type: _SnackType.sync,
          duration: const Duration(seconds: 3));

      final repo = LocationTrackingRepository();
      await repo.postDataFromDatabaseToAPI();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasPendingClockOutData', false);
      await prefs.setBool('clockOutPending', false);
      await prefs.setBool('hasFastClockOutData', false);
    } catch (e) {
      debugPrint('❌ [AUTO-SYNC] Error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  RESTORE EVERYTHING (Existing - unchanged)
  // ══════════════════════════════════════════════════════════════

  void _restoreEverything() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    final isFrozen = (prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false) ||
        (prefs.getBool('flutter.$KEY_IS_TIMER_FROZEN') ?? false);

    if (isFrozen) {
      await _hardResetAllTimerState();
      locationViewModel.isClockedIn.value   = false;
      attendanceViewModel.isClockedIn.value = false;
      await prefs.remove(KEY_IS_TIMER_FROZEN);
      await prefs.remove('flutter.$KEY_IS_TIMER_FROZEN');
      if (mounted) setState(() {});
      return;
    }

    final isClockedIn = prefs.getBool('isClockedIn') ?? false;
    if (isClockedIn) {
      final storedStr = prefs.getString('clockInTime');
      final today     = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final stored    = storedStr != null ? DateTime.tryParse(storedStr) : null;
      final isToday   = stored != null && DateFormat('yyyy-MM-dd').format(stored) == today;

      if (!isToday) {
        await _hardResetAllTimerState();
        await prefs.setBool('isClockedIn', false);
        locationViewModel.isClockedIn.value   = false;
        attendanceViewModel.isClockedIn.value = false;
        if (mounted) setState(() {});
        return;
      }

      _localClockInTime = stored;
      locationViewModel.isClockedIn.value   = true;
      attendanceViewModel.isClockedIn.value = true;
      _startLocalBackupTimer();
      _scheduleMidnightClockOut();
      _startPermissionMonitoring();
      if (mounted) setState(() {});
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  BACKUP TIMER (Existing - unchanged)
  // ══════════════════════════════════════════════════════════════

  void _startLocalBackupTimer() {
    if (_localClockInTime == null) return;

    final today      = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final clockInDay = DateFormat('yyyy-MM-dd').format(_localClockInTime!);
    if (clockInDay != today) {
      _localClockInTime = null;
      _localElapsedTime = '00:00:00';
      _accumulatedSeconds = 0;
      attendanceViewModel.elapsedTime.value = '00:00:00';
      if (mounted) setState(() {});
      return;
    }

    _localBackupTimer?.cancel();
    _localBackupTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_localClockInTime == null) { timer.cancel(); return; }
      final dur = DateTime.now().difference(_localClockInTime!);
      String pad(int n) => n.toString().padLeft(2, '0');
      _localElapsedTime =
      '${pad(dur.inHours)}:${pad(dur.inMinutes.remainder(60))}:${pad(dur.inSeconds.remainder(60))}';
      attendanceViewModel.elapsedTime.value = _localElapsedTime;
      if (mounted) setState(() {});
    });
  }

  // ══════════════════════════════════════════════════════════════
  //  INITIALIZE FROM PERSISTENT STATE (Existing - unchanged)
  // ══════════════════════════════════════════════════════════════

  Future<void> _initializeFromPersistentState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    final isFrozen = (prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false) ||
        (prefs.getBool('flutter.$KEY_IS_TIMER_FROZEN') ?? false);

    if (isFrozen) {
      await _hardResetAllTimerState();
      locationViewModel.isClockedIn.value   = false;
      attendanceViewModel.isClockedIn.value = false;
      if (mounted) setState(() {});
      return;
    }

    final isClockedIn = prefs.getBool('isClockedIn') ?? false;

    if (isClockedIn) {
      final storedStr = prefs.getString('clockInTime');
      if (storedStr != null) {
        final stored = DateTime.tryParse(storedStr);
        final today  = DateFormat('yyyy-MM-dd').format(DateTime.now());
        if (stored == null || DateFormat('yyyy-MM-dd').format(stored) != today) {
          await _hardResetAllTimerState();
          await prefs.setBool('isClockedIn', false);
          locationViewModel.isClockedIn.value   = false;
          attendanceViewModel.isClockedIn.value = false;
          if (mounted) setState(() {});
          return;
        }
      } else {
        await _hardResetAllTimerState();
        await prefs.setBool('isClockedIn', false);
        locationViewModel.isClockedIn.value   = false;
        attendanceViewModel.isClockedIn.value = false;
        if (mounted) setState(() {});
        return;
      }

      _localClockInTime = DateTime.parse(prefs.getString('clockInTime')!);
      locationViewModel.isClockedIn.value   = true;
      attendanceViewModel.isClockedIn.value = true;
      _startBackgroundServices();
      _startLocationMonitoring();
      _startLocalBackupTimer();
      _scheduleMidnightClockOut();
      _startPermissionMonitoring();
    } else {
      locationViewModel.isClockedIn.value   = false;
      attendanceViewModel.isClockedIn.value = false;
    }

    if (mounted) setState(() {});
  }

  // ══════════════════════════════════════════════════════════════
  //  DAILY STATE (Existing - unchanged)
  // ══════════════════════════════════════════════════════════════

  int    _accumulatedSeconds = 0;
  String _displayCheckIn     = '--:--';
  String _displayCheckOut    = '--:--';

  static const String _kAccumSec = 'daily_accum_seconds';
  static const String _kCheckIn  = 'daily_check_in';
  static const String _kCheckOut = 'daily_check_out';
  static const String _kLastDate = 'daily_last_date';

  Future<void> _initDailyState() async {
    final prefs    = await SharedPreferences.getInstance();
    final today    = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastDate = prefs.getString(_kLastDate) ?? '';

    if (lastDate != today) {
      await prefs.setString(_kLastDate, today);
      await prefs.setInt(_kAccumSec, 0);
      await prefs.remove(_kCheckIn);
      await prefs.remove(_kCheckOut);
      await prefs.remove('clockInTime');
      await prefs.remove('currentSessionStart');
      await prefs.setBool('isClockedIn', false);

      _accumulatedSeconds = 0;
      _localClockInTime   = null;
      _localElapsedTime   = '00:00:00';
      attendanceViewModel.elapsedTime.value = '00:00:00';
      _localBackupTimer?.cancel();
      _localBackupTimer = null;
    }

    _accumulatedSeconds = prefs.getInt(_kAccumSec)    ?? 0;
    _displayCheckIn     = prefs.getString(_kCheckIn)  ?? '--:--';
    _displayCheckOut    = prefs.getString(_kCheckOut) ?? '--:--';
    if (mounted) setState(() {});
  }

  Future<void> _saveCheckInTime() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setString(_kLastDate, today);
    if (prefs.getString(_kCheckIn) == null || prefs.getString(_kCheckIn) == '--:--') {
      await prefs.setString(_kCheckIn, DateFormat('HH:mm').format(DateTime.now()));
    }
    _displayCheckIn  = prefs.getString(_kCheckIn) ?? '--:--';
    _displayCheckOut = '--:--';
    await prefs.remove(_kCheckOut);
    if (mounted) setState(() {});
  }

  Future<void> _saveCheckOutTime() async {
    final prefs = await SharedPreferences.getInstance();
    if (_localClockInTime != null) {
      _accumulatedSeconds += DateTime.now().difference(_localClockInTime!).inSeconds;
      await prefs.setInt(_kAccumSec, _accumulatedSeconds);
    }
    _displayCheckOut = DateFormat('HH:mm').format(DateTime.now());
    await prefs.setString(_kCheckOut, _displayCheckOut);
    if (mounted) setState(() {});
  }

  String _buildDisplayTime() {
    int totalSec = _accumulatedSeconds;
    if (_localClockInTime != null && attendanceViewModel.isClockedIn.value) {
      final today      = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final clockInDay = DateFormat('yyyy-MM-dd').format(_localClockInTime!);
      if (clockInDay == today) {
        totalSec += DateTime.now().difference(_localClockInTime!).inSeconds;
      } else {
        _localClockInTime = null;
      }
    }
    if (totalSec < 0) totalSec = 0;
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(totalSec ~/ 3600)}:${pad((totalSec % 3600) ~/ 60)}:${pad(totalSec % 60)}';
  }

  // ══════════════════════════════════════════════════════════════
  //  HARD RESET (Existing - unchanged)
  // ══════════════════════════════════════════════════════════════

  Future<void> _hardResetAllTimerState() async {
    _localBackupTimer?.cancel();     _localBackupTimer = null;
    _locationMonitorTimer?.cancel(); _locationMonitorTimer = null;
    _midnightClockOutTimer?.cancel();
    _permissionCheckTimer?.cancel(); _permissionCheckTimer = null;

    _localClockInTime   = null;
    _localElapsedTime   = '00:00:00';
    _accumulatedSeconds = 0;
    _displayCheckIn     = '--:--';
    _displayCheckOut    = '--:--';
    attendanceViewModel.elapsedTime.value = '00:00:00';
    if (mounted) setState(() {});

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('clockInTime');
    await prefs.remove('currentSessionStart');
    await prefs.setInt(_kAccumSec, 0);
    await prefs.remove(_kCheckIn);
    await prefs.remove(_kCheckOut);
    await prefs.setString(_kLastDate, DateFormat('yyyy-MM-dd').format(DateTime.now()));
    await prefs.setBool(KEY_IS_TIMER_FROZEN, true);
    await prefs.setBool('flutter.$KEY_IS_TIMER_FROZEN', true);
  }

  // ══════════════════════════════════════════════════════════════
  //  LOCATION MONITORING (Existing - unchanged)
  // ══════════════════════════════════════════════════════════════

  void _startLocationMonitoring() {
    _wasLocationAvailable    = true;
    _autoClockOutInProgress  = false;

    _locationMonitorTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
          if (isFrozen) { timer.cancel(); return; }
          if (!attendanceViewModel.isClockedIn.value) {
            _stopLocationMonitoring();
            return;
          }
          bool currentLocationAvailable =
          await attendanceViewModel.isLocationAvailable();
          if (_wasLocationAvailable && !currentLocationAvailable) {
            await _handleAutoClockOut(
                reason: 'System ClockOut - Location Off', context: context);
            return;
          }
          _wasLocationAvailable = currentLocationAvailable;
        });
  }

  void _startBackgroundServices() async {
    try {
      final service = FlutterBackgroundService();
      await location.enableBackgroundMode(enable: true);
      initializeServiceLocation()
          .catchError((e) => debugPrint("Service init error: $e"));
      service.startService()
          .catchError((e) => debugPrint("Service start error: $e"));
    } catch (e) {
      debugPrint("⚠ [BACKGROUND] Services error: $e");
    }
  }

  void _stopLocationMonitoring() {
    _locationMonitorTimer?.cancel();
    _locationMonitorTimer   = null;
    _autoClockOutInProgress = false;
  }

  // ══════════════════════════════════════════════════════════════
  //  NOTIFICATIONS (Existing - unchanged)
  // ══════════════════════════════════════════════════════════════

  Future<void> _initializeUrgentNotifications() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidNotificationChannel urgentChannel = AndroidNotificationChannel(
      'urgent_auto_clockout_channel',
      'URGENT Auto Clockout Notifications',
      description: 'High-priority channel for urgent auto clockout notifications',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      ledColor: Colors.red,
    );
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(urgentChannel);
  }

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final String formattedDate =
    DateFormat('EEE, dd MMM yyyy').format(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.blueGrey.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.timer_outlined, size: 18, color: Colors.blueGrey.shade700),
                const SizedBox(width: 6),
                Text('Work Timer',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.blueGrey.shade800)),
              ]),
              Text(formattedDate,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey.shade400,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 14),

          // ── Timer circle + stats ─────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Obx(() {
                final bool clocked = attendanceViewModel.isClockedIn.value;
                String displayTime = _buildDisplayTime();
                if (_accumulatedSeconds == 0 && _localClockInTime == null && clocked) {
                  displayTime = attendanceViewModel.elapsedTime.value;
                }
                return SizedBox(
                  width: 90,
                  height: 90,
                  child: Stack(alignment: Alignment.center, children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: clocked
                            ? Colors.blueGrey.shade50
                            : Colors.grey.shade50,
                        border: Border.all(
                            color: clocked
                                ? Colors.blueGrey.shade300
                                : Colors.grey.shade300,
                            width: 2),
                      ),
                    ),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(displayTime,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: clocked
                                  ? Colors.blueGrey.shade800
                                  : Colors.blueGrey.shade400,
                              letterSpacing: -0.5)),
                      Text(clocked ? 'LIVE' : 'STOPPED',
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: clocked
                                  ? Colors.blueGrey.shade500
                                  : Colors.blueGrey.shade300,
                              letterSpacing: 1.0)),
                    ]),
                  ]),
                );
              }),
              const SizedBox(width: 20),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: _statItem(
                              label: 'Check In',
                              value: _displayCheckIn,
                              icon: Icons.login_rounded,
                              iconColor: Colors.green.shade600)),
                      Container(
                          width: 1,
                          height: 36,
                          color: Colors.blueGrey.shade100,
                          margin: const EdgeInsets.symmetric(horizontal: 10)),
                      Expanded(
                          child: _statItem(
                              label: 'Check Out',
                              value: _displayCheckOut,
                              icon: Icons.logout_rounded,
                              iconColor: Colors.red.shade400)),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          // ── Online / Offline status indicator ───────────────────
          Obx(() {
            final online = _isOnline.value;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: online ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: online ? Colors.green.shade200 : Colors.red.shade200,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: online
                          ? Colors.green.shade500
                          : Colors.red.shade400,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      online ? 'Online' : 'Offline',
                      key: ValueKey(online),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: online
                            ? Colors.green.shade700
                            : Colors.red.shade600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                      key: ValueKey(online),
                      size: 13,
                      color: online
                          ? Colors.green.shade500
                          : Colors.red.shade400,
                    ),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: 10,),

          // ── Buttons ─────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: Obx(() {
                final bool clocked = attendanceViewModel.isClockedIn.value;
                return SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: clocked
                        ? null
                        : () async {
                      await _handleClockIn(context);
                      if (attendanceViewModel.isClockedIn.value) {
                        await _saveCheckInTime();
                      }
                    },
                    icon: Icon(Icons.login_rounded,
                        size: 16,
                        color: clocked
                            ? Colors.grey.shade400
                            : Colors.blueGrey.shade700),
                    label: Text('Clock In',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: clocked
                                ? Colors.grey.shade400
                                : Colors.blueGrey.shade700)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: clocked
                              ? Colors.grey.shade300
                              : Colors.blueGrey.shade400,
                          width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Obx(() {
                final bool clocked = attendanceViewModel.isClockedIn.value;
                return SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: clocked
                        ? () async {
                      await _saveCheckOutTime();
                      await _handleClockOut(context);
                    }
                        : null,
                    icon: Icon(Icons.radio_button_checked,
                        size: 16,
                        color: clocked ? Colors.white : Colors.white54),
                    label: Text('Clock Out',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: clocked ? Colors.white : Colors.white54)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: clocked
                          ? Colors.blueGrey.shade700
                          : Colors.blueGrey.shade300,
                      disabledBackgroundColor: Colors.blueGrey.shade300,
                      elevation: clocked ? 3 : 0,
                      shadowColor: Colors.blueGrey.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                );
              }),
            ),
          ]),

        ],
      ),
    );
  }

  Widget _statItem({
    required String label,
    required String value,
    IconData? icon,
    Color? iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: iconColor ?? Colors.blueGrey),
            const SizedBox(width: 3)
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.blueGrey.shade400,
                  fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.blueGrey.shade800,
                letterSpacing: -0.3)),
      ],
    );
  }
  // Add this method
  Future<void> _closeFloatingBubble() async {
    try {
      const bubbleChannel = MethodChannel('com.metaxperts.order_booking_app/floating_bubble');
      await bubbleChannel.invokeMethod('closeBubble');
      debugPrint('✅ Floating bubble closed completely');
    } catch (e) {
      debugPrint('❌ Failed to close bubble: $e');
    }
  }
}