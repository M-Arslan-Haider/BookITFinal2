//
// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:order_booking_app/ViewModels/attendance_view_model.dart';
// import 'package:order_booking_app/ViewModels/location_view_model.dart';
// import 'package:order_booking_app/ViewModels/attendance_out_view_model.dart';
// import 'package:order_booking_app/ViewModels/update_function_view_model.dart';
// import 'package:location/location.dart' as loc;
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import '../../Databases/dp_helper.dart';
// import '../../Databases/util.dart';
// import '../../Repositories/location_tracking_repository.dart';
// import '../../Tracker/attendance_timelog_api.dart';
// import '../../Tracker/location_export_data.dart';
// import '../../Tracker/location_tracking_service.dart';
// import '../../Tracker/mqtt_work.dart';
// import '../../Utils/daily_work_time_manager.dart';
// import '../../main.dart';
// import 'package:intl/intl.dart';
// import '../clockout_alarm_service.dart';
// import '../sync_notification_service.dart';
// import '../../Tracker/fake_gps_logs.dart';
//
//
// // ─────────────────────────────────────────────────────────────
// //  FANCY SNACKBAR
// // ─────────────────────────────────────────────────────────────
//
// enum _SnackType { success, error, warning, sync, info }
//
// class _SnackCfg {
//   final Color bg;
//   final Color accent;
//   final IconData icon;
//   const _SnackCfg({required this.bg, required this.accent, required this.icon});
// }
//
// class FancySnack {
//   static OverlayEntry? _entry;
//   static Timer? _timer;
//
//   static void show(
//       BuildContext context, {
//         required String title,
//         required String message,
//         _SnackType type = _SnackType.info,
//         Duration duration = const Duration(seconds: 4),
//       }) {
//     _timer?.cancel();
//     try { _entry?.remove(); } catch (_) {}
//     _entry = null;
//
//     final overlay = Overlay.of(context);
//     late OverlayEntry e;
//     e = OverlayEntry(
//       builder: (_) => _FancySnackWidget(
//         title: title,
//         message: message,
//         type: type,
//         onDismiss: () {
//           _timer?.cancel();
//           try { e.remove(); } catch (_) {}
//           if (_entry == e) _entry = null;
//         },
//       ),
//     );
//
//     _entry = e;
//     overlay.insert(e);
//     _timer = Timer(duration, () {
//       try { e.remove(); } catch (_) {}
//       if (_entry == e) _entry = null;
//     });
//   }
// }
//
// class _FancySnackWidget extends StatefulWidget {
//   final String title;
//   final String message;
//   final _SnackType type;
//   final VoidCallback onDismiss;
//   const _FancySnackWidget(
//       {required this.title,
//         required this.message,
//         required this.type,
//         required this.onDismiss});
//   @override
//   State<_FancySnackWidget> createState() => _FancySnackWidgetState();
// }
//
// class _FancySnackWidgetState extends State<_FancySnackWidget>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _ctrl;
//   late Animation<Offset> _slide;
//   late Animation<double> _fade;
//
//   @override
//   void initState() {
//     super.initState();
//     _ctrl = AnimationController(
//         vsync: this, duration: const Duration(milliseconds: 380));
//     _slide = Tween<Offset>(begin: const Offset(0, 1.8), end: Offset.zero)
//         .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
//     _fade = Tween<double>(begin: 0, end: 1)
//         .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
//     _ctrl.forward();
//   }
//
//   @override
//   void dispose() {
//     _ctrl.dispose();
//     super.dispose();
//   }
//
//   _SnackCfg get _cfg {
//     switch (widget.type) {
//       case _SnackType.success:
//         return const _SnackCfg(
//             bg: Color(0xFF37474F),
//             accent: Color(0xFF66BB6A),
//             icon: Icons.check_circle_rounded);
//       case _SnackType.error:
//         return const _SnackCfg(
//             bg: Color(0xFF37474F),
//             accent: Color(0xFFEF5350),
//             icon: Icons.cancel_rounded);
//       case _SnackType.warning:
//         return const _SnackCfg(
//             bg: Color(0xFF37474F),
//             accent: Color(0xFFFF9800),
//             icon: Icons.warning_rounded);
//       case _SnackType.sync:
//         return const _SnackCfg(
//             bg: Color(0xFF37474F),
//             accent: Color(0xFF29B6F6),
//             icon: Icons.cloud_sync_rounded);
//       case _SnackType.info:
//         return const _SnackCfg(
//             bg: Color(0xFF455A64),
//             accent: Color(0xFF90CAF9),
//             icon: Icons.info_rounded);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final cfg = _cfg;
//     return Positioned(
//       bottom: MediaQuery.of(context).padding.bottom + 16,
//       left: 16,
//       right: 16,
//       child: SlideTransition(
//         position: _slide,
//         child: FadeTransition(
//           opacity: _fade,
//           child: Material(
//             color: Colors.transparent,
//             child: Container(
//               decoration: BoxDecoration(
//                 color: cfg.bg,
//                 borderRadius: BorderRadius.circular(20),
//                 boxShadow: const [
//                   BoxShadow(
//                       color: Colors.black26,
//                       blurRadius: 18,
//                       offset: Offset(0, 6))
//                 ],
//               ),
//               padding:
//               const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//               child: Row(
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                   Stack(
//                     alignment: Alignment.center,
//                     children: [
//                       Container(
//                         width: 50,
//                         height: 50,
//                         decoration: BoxDecoration(
//                             shape: BoxShape.circle,
//                             color: cfg.accent.withOpacity(0.20)),
//                       ),
//                       Positioned(
//                         top: 3,
//                         left: 3,
//                         child: Container(
//                             width: 13,
//                             height: 13,
//                             decoration: BoxDecoration(
//                                 shape: BoxShape.circle,
//                                 color: cfg.accent.withOpacity(0.28))),
//                       ),
//                       Icon(cfg.icon, color: cfg.accent, size: 24),
//                     ],
//                   ),
//                   const SizedBox(width: 14),
//                   Expanded(
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(widget.title,
//                             style: const TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.w700)),
//                         const SizedBox(height: 3),
//                         Text(widget.message,
//                             style: TextStyle(
//                                 color: Colors.white.withOpacity(0.80),
//                                 fontSize: 12.5,
//                                 height: 1.3)),
//                       ],
//                     ),
//                   ),
//                   GestureDetector(
//                     onTap: widget.onDismiss,
//                     child: const Icon(Icons.close_rounded,
//                         color: Colors.white54, size: 18),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────
// //  TIMER CARD
// // ─────────────────────────────────────────────────────────────
//
// class TimerCard extends StatefulWidget {
//   const TimerCard({super.key});
//
//   @override
//   State<TimerCard> createState() => _TimerCardState();
// }
//
// class _TimerCardState extends State<TimerCard> with WidgetsBindingObserver {
//
//   final locationViewModel       = Get.find<LocationViewModel>();
//   final attendanceViewModel     = Get.find<AttendanceViewModel>();
//   final attendanceOutViewModel  = Get.find<AttendanceOutViewModel>();
//   final updateFunctionViewModel = Get.find<UpdateFunctionViewModel>();
//
//   final MqttTracker _mqttTracker = MqttTracker();
//   final RxBool _mqttLive = false.obs;
//
//   final loc.Location location = loc.Location();
//   final Connectivity _connectivity = Connectivity();
//   late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
//
//   Timer? _locationMonitorTimer;
//   bool _wasLocationAvailable = true;
//   bool _autoClockOutInProgress = false;
//
//   Timer? _midnightClockOutTimer;
//   Timer? _permissionCheckTimer;
//   bool _isMidnightClockOutScheduled = false;
//
//   Timer? _localBackupTimer;
//   DateTime? _localClockInTime;
//   String _localElapsedTime = '00:00:00';
//
//   Timer? _autoSyncTimer;
//   final RxBool _isOnline = false.obs;
//   bool _isSyncing = false;
//   StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
//
//   double _currentDistance = 0.0;
//   Timer? _distanceUpdateTimer;
//   Timer? _mqttStatusTimer;
//   int _notificationId = 0;
//
//   final LocationExportService _exportService = LocationExportService();
//   bool _isExporting = false;
//   LocationExportStats _exportStats =
//   const LocationExportStats(total: 0, posted: 0, pending: 0);
//
//   static const platform =
//   MethodChannel('com.metaxperts.order_booking_app/location_monitor');
//
//   static const String KEY_IS_TIMER_FROZEN = 'is_timer_frozen';
//
//   // Auto Date & Time channel
//   static const _autoTimeChannel =
//   MethodChannel('com.metaxperts.order_booking_app/auto_time');
//
//   // OEM Settings Channel
//   static const _oemSettingsChannel =
//   MethodChannel('com.metaxperts.order_booking_app/oem_settings');
//
//   // Android Automatic Date & Time check
//   Future<bool> _isAutoTimeEnabled() async {
//     try {
//       if (!Platform.isAndroid) return true;
//       final bool enabled =
//           await _autoTimeChannel.invokeMethod<bool>('isAutoTimeEnabled') ?? true;
//       return enabled;
//     } catch (e) {
//       debugPrint('⚠️ [AUTO TIME] Check failed: $e');
//       return true;
//     }
//   }
//
//   // Android Date & Time settings screen open karo
//   Future<void> _openDateTimeSettings() async {
//     try {
//       await _autoTimeChannel.invokeMethod('openDateTimeSettings');
//     } catch (e) {
//       debugPrint('⚠️ [AUTO TIME] openDateTimeSettings: $e');
//     }
//   }
//
//   // ✅ OEM Setup Methods
//   Future<String> _getOemBrand() async {
//     try {
//       final brand = await _oemSettingsChannel.invokeMethod<String>('getOemBrand');
//       return brand ?? '';
//     } catch (e) {
//       debugPrint('⚠️ [OEM] getOemBrand failed: $e');
//       return '';
//     }
//   }
//
//   Future<void> _openOemAutoStartSettings() async {
//     try {
//       await _oemSettingsChannel.invokeMethod('openOemAutoStartSettings');
//     } catch (e) {
//       debugPrint('⚠️ [OEM] openOemAutoStartSettings failed: $e');
//     }
//   }
//
//   bool _needsOemSetup(String brand) {
//     final oemBrands = ['xiaomi', 'oppo', 'vivo', 'realme', 'huawei',
//       'honor', 'samsung', 'oneplus', 'tecno', 'infinix', 'itel'];
//     return oemBrands.any((b) => brand.contains(b));
//   }
//
//   Future<void> _showOemSetupDialogIfNeeded(BuildContext context) async {
//     final brand = await _getOemBrand();
//     if (!_needsOemSetup(brand)) return;
//
//     final prefs = await SharedPreferences.getInstance();
//     if (prefs.getBool('oem_setup_shown_$brand') == true) return;
//
//     if (!mounted) return;
//     await showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: Row(children: [
//           Icon(Icons.android, color: Colors.green.shade700),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Text('$brand Setup Required',
//                 style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
//           ),
//         ]),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.amber.shade50,
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: Colors.amber.shade200, width: 1),
//               ),
//               child: const Text(
//                 'To ensure GPS tracking works even when app is closed:',
//                 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
//               ),
//             ),
//             const SizedBox(height: 12),
//             const Text('1. Tap "Open Settings" below',
//                 style: TextStyle(fontSize: 12)),
//             const Text('2. Find and enable "Auto-start" or "Background Start"',
//                 style: TextStyle(fontSize: 12)),
//             const Text('3. Also allow "Run in background" if available',
//                 style: TextStyle(fontSize: 12)),
//             const SizedBox(height: 8),
//             Text('Device: $brand',
//                 style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Skip', style: TextStyle(color: Colors.grey)),
//           ),
//           ElevatedButton.icon(
//             onPressed: () async {
//               Navigator.pop(context);
//               await _openOemAutoStartSettings();
//               await prefs.setBool('oem_setup_shown_$brand', true);
//             },
//             icon: const Icon(Icons.settings, size: 16),
//             label: const Text('Open Settings'),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.blueGrey.shade700,
//               foregroundColor: Colors.white,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _showSnack({
//     required String title,
//     required String message,
//     _SnackType type = _SnackType.info,
//     Duration duration = const Duration(seconds: 4),
//   }) {
//     if (!mounted) return;
//     FancySnack.show(context,
//         title: title, message: message, type: type, duration: duration);
//   }
//
//   // ══════════════════════════════════════════════════════════════
//   //  initState / dispose / lifecycle
//   // ══════════════════════════════════════════════════════════════
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _initializeUrgentNotifications();
//     _startAutoSyncMonitoring();
//     _startDistanceUpdater();
//
//     _mqttStatusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
//       final live = _mqttTracker.isMqttConnected;
//       if (_mqttLive.value != live) _mqttLive.value = live;
//     });
//
//     _mqttTracker.initialize().then((_) {
//       debugPrint('✅ MQTT Tracker initialized | userId=${_mqttTracker.userId}');
//     });
//
//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       await _checkForBackgroundClockout();
//       await _checkForMissedClockout();
//       await _checkForMultiDayMissed();
//       await _initDailyState();
//       await _initializeFromPersistentState();
//       _scheduleMidnightClockOut();
//       await _startNativeMonitoringService();
//       _refreshExportStats();
//     });
//   }
//
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _stopLocationMonitoring();
//     _localBackupTimer?.cancel();
//     _autoSyncTimer?.cancel();
//     _connectivitySubscription?.cancel();
//     _distanceUpdateTimer?.cancel();
//     _midnightClockOutTimer?.cancel();
//     _permissionCheckTimer?.cancel();
//     _mqttStatusTimer?.cancel();
//     super.dispose();
//   }
//
//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     _restoreEverything();
//   }
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     debugPrint("🔄 [LIFECYCLE] App state changed: $state");
//
//     if (state == AppLifecycleState.paused) {
//       // App minimized - no bubble
//     } else if (state == AppLifecycleState.resumed) {
//       _checkForBackgroundClockout().then((_) async {
//         await _checkForMissedClockout();
//         await _checkForMultiDayMissed();
//         _restoreEverything();
//         _checkConnectivityAndSync();
//         _rescheduleMidnightClockOut();
//         _startNativeMonitoringService();
//       });
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════
//   //  LOCATION CSV EXPORT
//   // ══════════════════════════════════════════════════════════════
//
//   Future<void> _refreshExportStats() async {
//     final stats = await _exportService.getStats();
//     if (mounted) setState(() => _exportStats = stats);
//   }
//
//   Future<void> _handleExport(BuildContext context) async {
//     if (_isExporting) return;
//
//     final permResult = await _exportService.checkAndRequestPermission();
//
//     if (permResult == StoragePermissionResult.permanentlyDenied) {
//       _showSnack(
//         title: 'Storage Permission Denied',
//         message:
//         'Please enable "All files access" in App Settings to export data.',
//         type: _SnackType.error,
//         duration: const Duration(seconds: 6),
//       );
//       return;
//     }
//
//     setState(() => _isExporting = true);
//
//     _showSnack(
//       title: 'Exporting…',
//       message: 'Building CSV from local database…',
//       type: _SnackType.sync,
//     );
//
//     final result = await _exportService.exportToCSV();
//
//     setState(() => _isExporting = false);
//
//     if (result.success) {
//       _showSnack(
//         title: '✅ Export Successful',
//         message:
//         '${result.totalRows} rows  •  ${result.postedRows} synced  •  '
//             '${result.pendingRows} pending\n📁 ${result.filePath}',
//         type: _SnackType.success,
//         duration: const Duration(seconds: 7),
//       );
//       await _refreshExportStats();
//     } else {
//       _showSnack(
//         title: 'Export Failed',
//         message: result.message,
//         type: _SnackType.error,
//       );
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════
//   //  NATIVE SERVICE
//   // ══════════════════════════════════════════════════════════════
//
//   Future<void> _startNativeMonitoringService() async {
//     try {
//       if (Platform.isAndroid) {
//         final prefs = await SharedPreferences.getInstance();
//
//         // Check either key: 'isClockedIn' (Flutter-written) or direct guard
//         final isClockedIn = prefs.getBool('isClockedIn') ?? false;
//         if (!isClockedIn) return;
//
//         final userId      = prefs.getString('user_id')      ?? prefs.getString('emp_id')   ?? '';
//         final bookerName  = prefs.getString('booker_name')  ?? prefs.getString('emp_name')  ?? '';
//         final designation = prefs.getString('designation')  ?? prefs.getString('userDesignation') ?? '';
//         final companyCode = prefs.getString('company_code') ?? prefs.getString('companyCode') ?? '';
//
//         if (userId.isEmpty) {
//           debugPrint("⚠️ [NATIVE SERVICE] userId empty — skipping start");
//           return;
//         }
//
//         await platform.invokeMethod('startMonitoring', {
//           'userId':      userId,
//           'bookerName':  bookerName,
//           'designation': designation,
//           'companyCode': companyCode.isNotEmpty ? companyCode : 'PK-PUN-SKT-MX01-VT001',
//         });
//         debugPrint("✅ [NATIVE SERVICE] Started with userId=$userId");
//       }
//     } catch (e) {
//       debugPrint("❌ [NATIVE SERVICE] Error starting: $e");
//     }
//   }
//
//   Future<void> _stopNativeMonitoringService() async {
//     try {
//       if (Platform.isAndroid) {
//         await platform.invokeMethod('stopMonitoring');
//         debugPrint("🛑 [NATIVE SERVICE] Stopped");
//       }
//     } catch (e) {
//       debugPrint("❌ [NATIVE SERVICE] Error stopping: $e");
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════
//   //  HANDLE CLOCK IN  ✅ UPDATED with OEM Dialog
//   // ══════════════════════════════════════════════════════════════
//
//   Future<void> _handleClockIn(BuildContext context) async {
//     debugPrint("🎯 [TIMERCARD] CLOCK-IN STARTED");
//
//     // ── STEP 0: OEM Setup Dialog (Xiaomi/Vivo/Samsung etc.) ──────
//     await _showOemSetupDialogIfNeeded(context);
//
//     // ── STEP 1: Android Automatic Date & Time check ──────────────
//     final bool autoTimeOn = await _isAutoTimeEnabled();
//     if (!autoTimeOn) {
//       debugPrint("⛔ [CLOCK-IN] Auto Date & Time DISABLED — blocking");
//
//       final prefsForApi = await SharedPreferences.getInstance();
//       final String apiUserId = prefsForApi.getString('user_id') ??
//           prefsForApi.getString('emp_id')   ??
//           prefsForApi.getString('userId')   ?? '';
//       final String apiBookerName = prefsForApi.getString('booker_name') ??
//           prefsForApi.getString('emp_name') ??
//           prefsForApi.getString('userName') ?? '';
//       final String apiDesignation = prefsForApi.getString('designation') ??
//           prefsForApi.getString('job')              ??
//           prefsForApi.getString('userDesignation')  ?? '';
//       final String apiCompanyCode = prefsForApi.getString('company_code') ??
//           prefsForApi.getString('companyCode')       ?? '';
//
//       final apiResult = await AttendanceTimelogApi.postClockIn(
//         userId:          apiUserId,
//         bookerName:      apiBookerName,
//         designation:     apiDesignation,
//         companyCode:     apiCompanyCode,
//         autoTimeEnabled: false,
//         clockInTime:     DateTime.now(),
//       );
//
//       debugPrint(apiResult.success
//           ? '✅ [CLOCK-IN API] Logged to AUTO_TIME_LOG (auto_time=false)'
//           : '⚠️ [CLOCK-IN API] Failed: ${apiResult.message}');
//
//       if (!mounted) return;
//       await showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (ctx) => AlertDialog(
//           shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(16)),
//           backgroundColor: Colors.white,
//           title: Row(children: [
//             Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: Colors.orange.shade50,
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Icon(Icons.access_time_filled_rounded,
//                   color: Colors.orange.shade700, size: 22),
//             ),
//             const SizedBox(width: 12),
//             const Expanded(
//               child: Text('Auto Time Required',
//                   style: TextStyle(
//                       fontSize: 15, fontWeight: FontWeight.w700)),
//             ),
//           ]),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.orange.shade50,
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(
//                       color: Colors.orange.shade200, width: 1),
//                 ),
//                 child: const Text(
//                   'Please enable Automatic Date & Time to mark attendance.',
//                   style: TextStyle(
//                       fontSize: 13.5,
//                       height: 1.5,
//                       fontWeight: FontWeight.w500),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               Text('Settings path:',
//                   style: TextStyle(
//                       fontSize: 11,
//                       color: Colors.blueGrey.shade400,
//                       fontWeight: FontWeight.w600)),
//               const SizedBox(height: 4),
//               Text(
//                 'Settings → General Management\n'
//                     '→ Date and Time\n'
//                     '→ Enable "Automatic date and time"',
//                 style: TextStyle(
//                     fontSize: 12,
//                     color: Colors.blueGrey.shade600,
//                     height: 1.6),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(ctx).pop(),
//               child: Text('Cancel',
//                   style:
//                   TextStyle(color: Colors.blueGrey.shade400)),
//             ),
//             ElevatedButton.icon(
//               onPressed: () async {
//                 Navigator.of(ctx).pop();
//                 await _openDateTimeSettings();
//               },
//               icon: const Icon(Icons.settings_rounded, size: 16),
//               label: const Text('Open Settings'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blueGrey.shade700,
//                 foregroundColor: Colors.white,
//                 shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10)),
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 16, vertical: 10),
//               ),
//             ),
//           ],
//         ),
//       );
//       return;
//     }
//
//     // ── STEP 2: Daily state init ──────────────────────────────────
//     final prefsCheck = await SharedPreferences.getInstance();
//     final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
//     if ((prefsCheck.getString(_kLastDate) ?? '') != today) {
//       await _initDailyState();
//     }
//
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//
//     final String userId = prefs.getString('user_id')    ??
//         prefs.getString('emp_id')   ??
//         prefs.getString('userId')   ?? '';
//     final String bookerName = prefs.getString('booker_name') ??
//         prefs.getString('emp_name') ??
//         prefs.getString('userName') ?? '';
//     final String designation = prefs.getString('designation') ??
//         prefs.getString('job')               ??
//         prefs.getString('userDesignation')   ?? '';
//     final String companyCode = prefs.getString('company_code') ??
//         prefs.getString('companyCode')        ?? '';
//
//     debugPrint('👤 [CLOCK-IN] userId=$userId bookerName=$bookerName');
//
//     await prefs.remove(KEY_IS_TIMER_FROZEN);
//     await prefs.remove('flutter.$KEY_IS_TIMER_FROZEN');
//     _permissionCheckTimer?.cancel();
//     _permissionCheckTimer = null;
//     _localElapsedTime = '00:00:00';
//
//     // ── STEP 3: Location permission ───────────────────────────────
//     bool hasPermission = await _checkLocationPermission(context);
//     if (!hasPermission) return;
//
//     bool locationAvailable = await attendanceViewModel.isLocationAvailable();
//     if (!locationAvailable) {
//       _showSnack(
//           title: 'Location Required',
//           message: 'Please enable Location Services to clock in.',
//           type: _SnackType.error,
//           duration: const Duration(seconds: 5));
//       return;
//     }
//
//     // ── STEP 4: Progress dialog ───────────────────────────────────
//     if (!mounted) return;
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => const AlertDialog(
//         backgroundColor: Colors.white,
//         content: Column(mainAxisSize: MainAxisSize.min, children: [
//           CircularProgressIndicator(color: Colors.green),
//           SizedBox(height: 15),
//           Text('Starting GPS tracking…',
//               style: TextStyle(fontWeight: FontWeight.w500)),
//         ]),
//       ),
//     );
//
//     try {
//       final DateTime clockInTime = DateTime.now();
//
//       await LocationTrackingService().startTracking();
//       await attendanceViewModel.saveFormAttendanceIn();
//       _startBackgroundServices();
//
//       locationViewModel.isClockedIn.value   = true;
//       attendanceViewModel.isClockedIn.value = true;
//
//       // Register Fake-GPS auto clock-out callback
//       FakeGpsLog.registerClockOutCallback((DateTime eventTime) async {
//         await _handleAutoClockOut(
//           reason:    'System ClockOut - Fake GPS Detected',
//           context:   context,
//           eventTime: eventTime,
//         );
//       });
//       debugPrint('✅ [CLOCK-IN] FakeGPS clock-out callback registered');
//
//       await prefs.setBool('isClockedIn', true);
//       await prefs.setString('currentSessionStart', clockInTime.toIso8601String());
//
//       // ── START NATIVE LocationMonitorService ───────────────────────────────
//       // This MUST be called here (not just in initState) so the Kotlin service
//       // starts in sync with every clock-in button press — app open, background,
//       // or after kill/restart. The service holds a WakeLock + saves lat/lng to
//       // SQLite every interval, independent of Flutter's lifecycle.
//       try {
//         await platform.invokeMethod('startMonitoring', {
//           'userId':      userId,
//           'bookerName':  bookerName,
//           'designation': designation,
//           'companyCode': companyCode.isNotEmpty ? companyCode : 'PK-PUN-SKT-MX01-VT001',
//         });
//         debugPrint("✅ [CLOCK-IN] Native LocationMonitorService started");
//       } catch (e) {
//         debugPrint("❌ [CLOCK-IN] Native service start failed: $e");
//       }
//
//       final mqttStarted = await _mqttTracker.clockInMqtt(
//         userId:      userId,
//         bookerName:  bookerName,
//         designation: designation,
//       );
//       _mqttLive.value = mqttStarted;
//       debugPrint(mqttStarted
//           ? '✅ [CLOCK-IN] MQTT tracking started'
//           : '⚠️ [CLOCK-IN] MQTT start failed — Kotlin service may not have started');
//
//       _startLocalBackupTimer();
//       _startLocationMonitoring();
//       _scheduleMidnightClockOut();
//       _startPermissionMonitoring();
//
//       await _updateCurrentDistance();
//       await DailyWorkTimeManager.recordClockIn(clockInTime);
//
//       await SyncNotificationService.startPeriodicSyncReminder();
//       debugPrint('✅ [CLOCK-IN] 15-min sync reminder started');
//
//       // ── STEP 5: POST to Apex AUTO_TIME_LOG ───────────────────────
//       final apiResult = await AttendanceTimelogApi.postClockIn(
//         userId:          userId,
//         bookerName:      bookerName,
//         designation:     designation,
//         companyCode:     companyCode,
//         autoTimeEnabled: true,
//         clockInTime:     clockInTime,
//       );
//
//       if (apiResult.success) {
//         debugPrint('✅ [CLOCK-IN API] Record posted to AUTO_TIME_LOG');
//       } else if (apiResult.savedOffline) {
//         debugPrint('💾 [CLOCK-IN API] Offline — queued for sync when internet returns');
//       } else {
//         debugPrint('⚠️ [CLOCK-IN API] Failed (${apiResult.statusCode}): ${apiResult.message}');
//       }
//
//       debugPrint("✅ [CLOCK-IN] COMPLETED");
//
//       if (Navigator.of(context).canPop()) Navigator.of(context).pop();
//       _showSnack(
//           title: 'Clocked In',
//           message: 'GPS + MQTT tracking started.',
//           type: _SnackType.success,
//           duration: const Duration(seconds: 3));
//     } catch (e) {
//       debugPrint("❌ [CLOCK-IN] Error: $e");
//       if (Navigator.of(context).canPop()) Navigator.of(context).pop();
//       _showSnack(
//           title: 'Clock In Failed',
//           message: 'Failed to clock in: ${e.toString()}',
//           type: _SnackType.error);
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════
//   //  HANDLE CLOCK OUT
//   // ══════════════════════════════════════════════════════════════
//
//   Future<void> _handleClockOut(BuildContext context) async {
//     debugPrint("🎯 [TIMERCARD] CLOCK-OUT STARTED");
//
//     DateTime startTime = DateTime.now();
//     Timer? loadingTimer;
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => AlertDialog(
//         backgroundColor: Colors.white.withOpacity(0.9),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
//         content: Column(mainAxisSize: MainAxisSize.min, children: const [
//           CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.green)),
//           SizedBox(height: 15),
//           Text("Processing clock-out…",
//               style: TextStyle(fontWeight: FontWeight.w500)),
//           SizedBox(height: 5),
//           Text("Please wait", style: TextStyle(fontSize: 12, color: Colors.grey)),
//         ]),
//       ),
//     );
//     loadingTimer = Timer(const Duration(seconds: 2), () {});
//
//     try {
//       _stopLocationMonitoring();
//       await LocationTrackingService().stopTracking();
//
//       _localBackupTimer?.cancel();
//       _midnightClockOutTimer?.cancel();
//       _permissionCheckTimer?.cancel();
//       _permissionCheckTimer = null;
//
//       final repo      = LocationTrackingRepository();
//       final dbHelper  = DBHelper();
//
//       final unpostedRows = await dbHelper.getUnpostedLocationTracking();
//       final allRows      = await dbHelper.getAllLocationTracking();
//       debugPrint("📊 [CLOCKOUT] Total: ${allRows.length}, Pending: ${unpostedRows.length}");
//
//       double finalDistance = _currentDistance;
//       if (finalDistance <= 0) {
//         finalDistance = await _calculateDistanceFromTrackingPoints();
//       }
//
//       DateTime clockOutTime = DateTime.now();
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//
//       await prefs.remove(KEY_IS_TIMER_FROZEN);
//       await prefs.remove('flutter.$KEY_IS_TIMER_FROZEN');
//       await prefs.setBool('isClockedIn', false);
//       await prefs.setDouble('fastClockOutDistance', finalDistance);
//       await prefs.setString('fastClockOutTime', clockOutTime.toIso8601String());
//       await prefs.setBool('clockOutPending', true);
//       await prefs.setBool('hasFastClockOutData', true);
//
//       locationViewModel.isClockedIn.value   = false;
//       attendanceViewModel.isClockedIn.value = false;
//       _localElapsedTime = '00:00:00';
//       _localClockInTime = null;
//
//       await attendanceOutViewModel.fastSaveAttendanceOut(
//         clockOutTime:  clockOutTime,
//         totalDistance: finalDistance,
//         isAuto:        false,
//         reason:        'User Clock Out',
//       );
//
//       await DailyWorkTimeManager.recordClockOut(DateTime.now());
//
//       await _mqttTracker.clockOutMqtt();
//       _mqttLive.value = false;
//       debugPrint('🛑 [CLOCK-OUT] MQTT tracking stopped');
//
//       // Unregister Fake-GPS callback
//       FakeGpsLog.unregisterClockOutCallback();
//       debugPrint('🛑 [CLOCK-OUT] FakeGPS clock-out callback unregistered');
//
//       await SyncNotificationService.stopPeriodicSyncReminder();
//       debugPrint('🛑 [CLOCK-OUT] 15-min sync reminder stopped');
//
//       final service = FlutterBackgroundService();
//       service.invoke("stopService");
//
//       // ── STOP NATIVE LocationMonitorService ───────────────────────────────
//       // Must set isClockedIn=false BEFORE stopping the service so that
//       // onDestroy() skips the critical-event save path (permission/location check).
//       // stopMonitoring also cancels WorkManager + MidnightAlarm on Kotlin side.
//       await _stopNativeMonitoringService();
//
//       try {
//         await location.enableBackgroundMode(enable: false);
//       } catch (e) {
//         debugPrint("⚠️ Background mode disable error: $e");
//       }
//
//       await repo.postDataFromDatabaseToAPI();
//       await _hardResetAllTimerState();
//
//       final elapsed = DateTime.now().difference(startTime);
//       if (elapsed.inSeconds < 2) {
//         await Future.delayed(Duration(seconds: 2 - elapsed.inSeconds));
//       }
//
//       loadingTimer.cancel();
//       if (Navigator.of(context).canPop()) Navigator.of(context).pop();
//
//       _showSnack(
//           title: 'Clocked Out',
//           message: 'Your session has been saved successfully.',
//           type: _SnackType.success,
//           duration: const Duration(seconds: 4));
//
//       debugPrint("✅ [CLOCK-OUT] COMPLETED");
//     } catch (e) {
//       debugPrint("❌ [CLOCK-OUT] Error: $e");
//       loadingTimer?.cancel();
//       if (Navigator.of(context).canPop()) Navigator.of(context).pop();
//       _showSnack(
//           title: 'Saved Locally',
//           message: 'Data saved. Will sync automatically when online.',
//           type: _SnackType.warning,
//           duration: const Duration(seconds: 4));
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════
//   //  AUTO CLOCK-OUT
//   // ══════════════════════════════════════════════════════════════
//
//   Future<void> _handleAutoClockOut({
//     required String reason,
//     required BuildContext context,
//     DateTime? eventTime,
//   }) async {
//     if (_autoClockOutInProgress || !attendanceViewModel.isClockedIn.value) return;
//     _autoClockOutInProgress = true;
//
//     final DateTime clockOutTime  = eventTime ?? DateTime.now();
//     final double   finalDistance = _currentDistance;
//     final double   finalLat      = locationViewModel.globalLatitude1.value;
//     final double   finalLng      = locationViewModel.globalLongitude1.value;
//
//     debugPrint("⚡ [AUTO CLOCKOUT] START — Reason: $reason");
//
//     try {
//       _localBackupTimer?.cancel();
//       _localBackupTimer = null;
//       _locationMonitorTimer?.cancel();
//       _locationMonitorTimer = null;
//       _midnightClockOutTimer?.cancel();
//       _permissionCheckTimer?.cancel();
//       _permissionCheckTimer = null;
//
//       _localClockInTime = null;
//       _localElapsedTime = '00:00:00';
//       _accumulatedSeconds = 0;
//       attendanceViewModel.elapsedTime.value = '00:00:00';
//       locationViewModel.isClockedIn.value   = false;
//       attendanceViewModel.isClockedIn.value = false;
//       if (mounted) setState(() {});
//
//       await LocationTrackingService().stopTracking();
//       FlutterBackgroundService().invoke("stopService");
//       await _stopNativeMonitoringService();
//
//       await _mqttTracker.clockOutMqtt();
//       _mqttLive.value = false;
//       debugPrint('🛑 [AUTO CLOCKOUT] MQTT stopped');
//
//       // Unregister Fake-GPS callback
//       FakeGpsLog.unregisterClockOutCallback();
//
//       await SyncNotificationService.stopPeriodicSyncReminder();
//       debugPrint('🛑 [CLOCK-OUT] 15-min sync reminder stopped');
//
//       try { await location.enableBackgroundMode(enable: false); }
//       catch (e) { debugPrint("⚠️ BG mode disable: $e"); }
//
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setBool('isClockedIn', false);
//       await prefs.setBool('flutter.isClockedIn', false);
//       await prefs.setDouble('fastClockOutDistance', finalDistance);
//       await prefs.setString('fastClockOutTime', clockOutTime.toIso8601String());
//       await prefs.setBool('clockOutPending', true);
//       await prefs.setBool('hasFastClockOutData', true);
//       await prefs.setDouble('pendingLatOut', finalLat);
//       await prefs.setDouble('pendingLngOut', finalLng);
//       await prefs.setBool(KEY_IS_TIMER_FROZEN, true);
//       await prefs.setBool('flutter.$KEY_IS_TIMER_FROZEN', true);
//
//       await _hardResetAllTimerState();
//       await attendanceOutViewModel.fastSaveAttendanceOut(
//         clockOutTime:  clockOutTime,
//         totalDistance: finalDistance,
//         isAuto:        true,
//         reason:        reason,
//       );
//       await DailyWorkTimeManager.recordClockOut(clockOutTime);
//       _triggerAutoSync();
//
//       debugPrint("✅ [AUTO CLOCKOUT] COMPLETED — Reason: $reason");
//       if (mounted) {
//         _showSnack(
//           title: reason.contains('Fake GPS') ? '🚨 Fake GPS Detected' : 'Auto Clock-Out',
//           message: reason.contains('Fake GPS')
//               ? 'Mock location detected. Timer stopped automatically.'
//               : 'Timer stopped automatically.',
//           type: _SnackType.error,
//           duration: const Duration(seconds: 5),
//         );
//       }
//     } catch (e) {
//       debugPrint("❌ [AUTO CLOCKOUT] Error: $e");
//       _localBackupTimer?.cancel();
//       _localBackupTimer = null;
//       _localClockInTime = null;
//       _localElapsedTime = '00:00:00';
//       _accumulatedSeconds = 0;
//       attendanceViewModel.elapsedTime.value = '00:00:00';
//       locationViewModel.isClockedIn.value   = false;
//       attendanceViewModel.isClockedIn.value = false;
//
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setBool('isClockedIn', false);
//       await prefs.setBool('flutter.isClockedIn', false);
//       await prefs.setBool('clockOutPending', true);
//       await _hardResetAllTimerState();
//     } finally {
//       _autoClockOutInProgress = false;
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════
//   //  BACKGROUND CLOCKOUT CHECK
//   // ══════════════════════════════════════════════════════════════
//
//   Future<void> _checkForBackgroundClockout() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     final hasCriticalEvent =
//         (prefs.getBool('has_critical_event_pending') ?? false) ||
//             (prefs.getBool('flutter.has_critical_event_pending') ?? false);
//
//     if (!hasCriticalEvent) return;
//
//     final reason = prefs.getString('critical_event_reason') ??
//         prefs.getString('flutter.critical_event_reason') ??
//         'System ClockOut - Midnight Time';
//
//     final clockOutTimeStr =
//         prefs.getString('flutter.fastClockOutTime') ??
//             prefs.getString('flutter.critical_event_timestamp');
//
//     final clockOutTime = (clockOutTimeStr != null)
//         ? (DateTime.tryParse(clockOutTimeStr) ?? DateTime.now())
//         : DateTime.now();
//
//     final distance = prefs.getDouble('flutter.fastClockOutDistance') ?? 0.0;
//
//     debugPrint('⚡ [BG CLOCKOUT] Detected: $reason | time=$clockOutTime');
//
//     // Clear flags
//     await prefs.remove('has_critical_event_pending');
//     await prefs.remove('flutter.has_critical_event_pending');
//     await prefs.remove('critical_event_reason');
//     await prefs.remove('flutter.critical_event_reason');
//     await prefs.remove(KEY_IS_TIMER_FROZEN);
//     await prefs.remove('flutter.$KEY_IS_TIMER_FROZEN');
//
//     _stopLocationMonitoring();
//     _localBackupTimer?.cancel();
//     _localBackupTimer = null;
//     _midnightClockOutTimer?.cancel();
//     _permissionCheckTimer?.cancel();
//     _permissionCheckTimer = null;
//
//     await _mqttTracker.clockOutMqtt();
//     _mqttLive.value = false;
//
//     try {
//       await attendanceOutViewModel.fastSaveAttendanceOut(
//         clockOutTime:  clockOutTime,
//         totalDistance: distance,
//         isAuto:        true,
//         reason:        reason,
//       );
//       await DailyWorkTimeManager.recordClockOut(clockOutTime);
//       await prefs.setBool('clockOutPending', false);
//       await prefs.setBool('hasFastClockOutData', false);
//       debugPrint('✅ [BG CLOCKOUT] Attendance saved successfully');
//
//       if (reason.contains('Fake GPS')) {
//         debugPrint('🔄 [BG CLOCKOUT] Syncing pending fake GPS records via SQLite...');
//         await FakeGpsLog.syncPending();
//         debugPrint('✅ [BG CLOCKOUT] Fake GPS sync complete');
//       }
//
//     } catch (e) {
//       debugPrint('❌ [BG CLOCKOUT] Attendance save failed: $e');
//     }
//
//     await _hardResetAllTimerState();
//
//     locationViewModel.isClockedIn.value   = false;
//     attendanceViewModel.isClockedIn.value = false;
//
//     await prefs.setBool('isClockedIn', false);
//     await prefs.setBool('flutter.isClockedIn', false);
//     await prefs.remove('clockInTime');
//     await prefs.remove('currentSessionStart');
//
//     _triggerAutoSync();
//
//     if (mounted) {
//       final snackTitle = reason.contains('Fake GPS')
//           ? '🚨 Fake GPS Detected'
//           : reason.contains('Location Off')
//           ? '📍 Location Turned Off'
//           : reason.contains('Permission')
//           ? '🔒 Location Permission Revoked'
//           : '⏰ Auto Clock-Out (10:00 PM)';
//
//       final snackMessage = reason.contains('Fake GPS')
//           ? 'Mock location detected. You have been auto clocked out.'
//           : 'You were auto clocked out. Data saved.';
//
//       _showSnack(
//         title: snackTitle,
//         message: snackMessage,
//         type: _SnackType.warning,
//         duration: const Duration(seconds: 6),
//       );
//     }
//
//     debugPrint('✅ [BG CLOCKOUT] Complete');
//   }
//
//   // ══════════════════════════════════════════════════════════════
//   //  MIDNIGHT CLOCK-OUT
//   // ══════════════════════════════════════════════════════════════
//
//   void _scheduleMidnightClockOut() {
//     SharedPreferences.getInstance().then((prefs) {
//       bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
//       if (isFrozen || !attendanceViewModel.isClockedIn.value) return;
//
//       _midnightClockOutTimer?.cancel();
//
//       final now           = DateTime.now();
//       final scheduledTime = DateTime(now.year, now.month, now.day, 23, 58);
//       final delay = now.isAfter(scheduledTime)
//           ? scheduledTime.add(const Duration(days: 1)).difference(now)
//           : scheduledTime.difference(now);
//
//       _midnightClockOutTimer = Timer(delay, () async {
//         if (attendanceViewModel.isClockedIn.value) {
//           debugPrint("⏰ [MIDNIGHT] Auto clockout triggered");
//           await _handleAutoClockOut(
//               reason: 'System ClockOut - Midnight Time', context: context);
//         }
//       });
//       _isMidnightClockOutScheduled = true;
//       debugPrint("⏰ [MIDNIGHT] Auto clockout scheduled");
//     });
//   }
//
//   void _rescheduleMidnightClockOut() {
//     SharedPreferences.getInstance().then((prefs) {
//       bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
//       if (!isFrozen && attendanceViewModel.isClockedIn.value) {
//         _scheduleMidnightClockOut();
//       }
//     });
//   }
//
//   // ══════════════════════════════════════════════════════════════
//   //  PERMISSION MONITORING
//   // ══════════════════════════════════════════════════════════════
//
//   void _startPermissionMonitoring() {
//     _permissionCheckTimer?.cancel();
//     _permissionCheckTimer = null;
//     _wasLocationAvailable = true;
//
//     _permissionCheckTimer =
//         Timer.periodic(const Duration(seconds: 2), (timer) async {
//           SharedPreferences prefs = await SharedPreferences.getInstance();
//           bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
//           if (isFrozen) { timer.cancel(); return; }
//           if (!attendanceViewModel.isClockedIn.value) return;
//
//           bool locationEnabled = await attendanceViewModel.isLocationAvailable();
//           if (_wasLocationAvailable && !locationEnabled) {
//             await _handleAutoClockOut(
//                 reason: 'System ClockOut - Location Off', context: context);
//             return;
//           }
//           _wasLocationAvailable = locationEnabled;
//         });
//   }
//
//   Future<bool> _checkLocationPermission(BuildContext context) async {
//     LocationPermission permission = await Geolocator.checkPermission();
//
//     if (permission == LocationPermission.deniedForever) {
//       if (mounted) {
//         _showSnack(
//           title: 'Permission Required',
//           message: 'Location permission denied. Please enable it in Settings.',
//           type: _SnackType.error,
//           duration: const Duration(seconds: 5),
//         );
//       }
//       return false;
//     }
//
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//     }
//
//     if (permission == LocationPermission.denied ||
//         permission == LocationPermission.deniedForever) {
//       if (mounted && context.mounted) {
//         await showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (ctx) => Dialog(
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//             child: Padding(
//               padding: const EdgeInsets.all(20),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   const Icon(Icons.location_off, size: 50, color: Colors.redAccent),
//                   const SizedBox(height: 15),
//                   const Text("Location Permission Required",
//                       style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                   const SizedBox(height: 10),
//                   const Text(
//                       "We need location access to continue.\nPlease enable location permission from app settings.",
//                       textAlign: TextAlign.center,
//                       style: TextStyle(color: Colors.grey)),
//                   const SizedBox(height: 20),
//                   Row(children: [
//                     Expanded(
//                         child: TextButton(
//                             onPressed: () => Navigator.of(ctx).pop(),
//                             child: const Text("Cancel",
//                                 style: TextStyle(color: Colors.grey)))),
//                     const SizedBox(width: 10),
//                     Expanded(
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
//                           onPressed: () async {
//                             Navigator.of(ctx).pop();
//                             await Geolocator.openAppSettings();
//                           },
//                           child: const Text("Open Settings",
//                               style: TextStyle(color: Colors.white)),
//                         )),
//                   ]),
//                 ],
//               ),
//             ),
//           ),
//         );
//       }
//       return false;
//     }
//     return true;
//   }
//
//   // ══════════════════════════════════════════════════════════════
//   //  DISTANCE
//   // ══════════════════════════════════════════════════════════════
//
//   void _startDistanceUpdater() {
//     _distanceUpdateTimer =
//         Timer.periodic(const Duration(seconds: 5), (timer) async {
//           SharedPreferences prefs = await SharedPreferences.getInstance();
//           bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
//           if (isFrozen) { timer.cancel(); return; }
//           if (attendanceViewModel.isClockedIn.value) await _updateCurrentDistance();
//         });
//   }
//
//   Future<void> _updateCurrentDistance() async {
//     try {
//       double distance = await _calculateDistanceFromTrackingPoints();
//       if (mounted) setState(() { _currentDistance = distance; });
//     } catch (e) {
//       debugPrint("❌ Distance update error: $e");
//     }
//   }
//
//   Future<double> _calculateDistanceFromTrackingPoints() async {
//     try {
//       final dbHelper  = DBHelper();
//       final allPoints = await dbHelper.getAllLocationTracking();
//       if (allPoints.length < 2) return 0.0;
//
//       double totalDistance = 0.0;
//       for (int i = 0; i < allPoints.length - 1; i++) {
//         double lat1 = double.tryParse(allPoints[i]['lat_in']?.toString()       ?? '0') ?? 0;
//         double lng1 = double.tryParse(allPoints[i]['lng_in']?.toString()       ?? '0') ?? 0;
//         double lat2 = double.tryParse(allPoints[i+1]['lat_in']?.toString()     ?? '0') ?? 0;
//         double lng2 = double.tryParse(allPoints[i+1]['lng_in']?.toString()     ?? '0') ?? 0;
//         totalDistance += Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
//       }
//       return totalDistance / 1000;
//     } catch (e) {
//       debugPrint("❌ Error calculating distance: $e");
//       return 0.0;
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════
//   //  AUTO SYNC
//   // ══════════════════════════════════════════════════════════════
//
//   void _startAutoSyncMonitoring() async {
//     _connectivitySubscription =
//         _connectivity.onConnectivityChanged.listen((results) {
//           bool wasOnline = _isOnline.value;
//           _isOnline.value = results.isNotEmpty &&
//               results.any((r) => r != ConnectivityResult.none);
//           if (_isOnline.value && !wasOnline && !_isSyncing) {
//             _triggerAutoSync();
//             debugPrint('🌐 [CONNECTIVITY] Internet aaya — timelog queue sync ho raha hai...');
//             AttendanceTimelogApi.syncOfflineQueue();
//           }
//         });
//
//     _autoSyncTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
//       if (!_isSyncing) _checkConnectivityAndSync();
//     });
//     _checkConnectivityAndSync();
//   }
//
//   void _checkConnectivityAndSync() async {
//     if (_isSyncing) return;
//     try {
//       var results = await _connectivity.checkConnectivity();
//       _isOnline.value = results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
//       if (_isOnline.value && !_isSyncing) _triggerAutoSync();
//     } catch (e) { debugPrint("❌ [CONNECTIVITY] Error: $e"); }
//   }
//
//   void _triggerAutoSync() async {
//     if (_isSyncing) return;
//     _isSyncing = true;
//     try {
//       _showSnack(
//           title: 'Syncing Data',
//           message: 'Uploading location points to server…',
//           type: _SnackType.sync,
//           duration: const Duration(seconds: 3));
//
//       final repo = LocationTrackingRepository();
//       await repo.postDataFromDatabaseToAPI();
//
//       await FakeGpsLog.syncPending();
//       debugPrint('✅ [AUTO-SYNC] FakeGPS logs sync complete');
//
//       await AttendanceTimelogApi.syncOfflineQueue();
//       debugPrint('✅ [AUTO-SYNC] Timelog offline queue sync complete');
//
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setBool('hasPendingClockOutData', false);
//       await prefs.setBool('clockOutPending', false);
//       await prefs.setBool('hasFastClockOutData', false);
//     } catch (e) {
//       debugPrint('❌ [AUTO-SYNC] Error: $e');
//     } finally {
//       _isSyncing = false;
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════
//   //  RESTORE EVERYTHING
//   // ══════════════════════════════════════════════════════════════
//
//   void _restoreEverything() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//
//     final isFrozen = (prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false) ||
//         (prefs.getBool('flutter.$KEY_IS_TIMER_FROZEN') ?? false);
//
//     if (isFrozen) {
//       await _hardResetAllTimerState();
//       locationViewModel.isClockedIn.value   = false;
//       attendanceViewModel.isClockedIn.value = false;
//       await prefs.remove(KEY_IS_TIMER_FROZEN);
//       await prefs.remove('flutter.$KEY_IS_TIMER_FROZEN');
//       if (mounted) setState(() {});
//       return;
//     }
//
//     final isClockedIn = prefs.getBool('isClockedIn') ?? false;
//     if (isClockedIn) {
//       final storedStr = prefs.getString('clockInTime');
//       final today     = DateFormat('yyyy-MM-dd').format(DateTime.now());
//       final stored    = storedStr != null ? DateTime.tryParse(storedStr) : null;
//       final isToday   = stored != null && DateFormat('yyyy-MM-dd').format(stored) == today;
//
//       if (!isToday) {
//         await _hardResetAllTimerState();
//         await prefs.setBool('isClockedIn', false);
//         locationViewModel.isClockedIn.value   = false;
//         attendanceViewModel.isClockedIn.value = false;
//         if (mounted) setState(() {});
//         return;
//       }
//
//       _localClockInTime = stored;
//       locationViewModel.isClockedIn.value   = true;
//       attendanceViewModel.isClockedIn.value = true;
//       _startLocalBackupTimer();
//       _scheduleMidnightClockOut();
//       _startPermissionMonitoring();
//       if (mounted) setState(() {});
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════
//   //  BACKUP TIMER
//   // ══════════════════════════════════════════════════════════════
//
//   void _startLocalBackupTimer() {
//     if (_localClockInTime == null) return;
//
//     final today      = DateFormat('yyyy-MM-dd').format(DateTime.now());
//     final clockInDay = DateFormat('yyyy-MM-dd').format(_localClockInTime!);
//     if (clockInDay != today) {
//       _localClockInTime = null;
//       _localElapsedTime = '00:00:00';
//       _accumulatedSeconds = 0;
//       attendanceViewModel.elapsedTime.value = '00:00:00';
//       if (mounted) setState(() {});
//       return;
//     }
//
//     _localBackupTimer?.cancel();
//     _localBackupTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (_localClockInTime == null) { timer.cancel(); return; }
//       final dur = DateTime.now().difference(_localClockInTime!);
//       String pad(int n) => n.toString().padLeft(2, '0');
//       _localElapsedTime =
//       '${pad(dur.inHours)}:${pad(dur.inMinutes.remainder(60))}:${pad(dur.inSeconds.remainder(60))}';
//       attendanceViewModel.elapsedTime.value = _localElapsedTime;
//       if (mounted) setState(() {});
//     });
//   }
//
//   // ══════════════════════════════════════════════════════════════
//   //  INITIALIZE FROM PERSISTENT STATE
//   // ══════════════════════════════════════════════════════════════
//
//   Future<void> _initializeFromPersistentState() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//
//     final isFrozen = (prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false) ||
//         (prefs.getBool('flutter.$KEY_IS_TIMER_FROZEN') ?? false);
//
//     if (isFrozen) {
//       await _hardResetAllTimerState();
//       locationViewModel.isClockedIn.value   = false;
//       attendanceViewModel.isClockedIn.value = false;
//       if (mounted) setState(() {});
//       return;
//     }
//
//     final isClockedIn = prefs.getBool('isClockedIn') ?? false;
//
//     if (isClockedIn) {
//       final storedStr = prefs.getString('clockInTime');
//       if (storedStr != null) {
//         final stored = DateTime.tryParse(storedStr);
//         final today  = DateFormat('yyyy-MM-dd').format(DateTime.now());
//         if (stored == null || DateFormat('yyyy-MM-dd').format(stored) != today) {
//           await _hardResetAllTimerState();
//           await prefs.setBool('isClockedIn', false);
//           locationViewModel.isClockedIn.value   = false;
//           attendanceViewModel.isClockedIn.value = false;
//           if (mounted) setState(() {});
//           return;
//         }
//       } else {
//         await _hardResetAllTimerState();
//         await prefs.setBool('isClockedIn', false);
//         locationViewModel.isClockedIn.value   = false;
//         attendanceViewModel.isClockedIn.value = false;
//         if (mounted) setState(() {});
//         return;
//       }
//
//       _localClockInTime = DateTime.parse(prefs.getString('clockInTime')!);
//       locationViewModel.isClockedIn.value   = true;
//       attendanceViewModel.isClockedIn.value = true;
//       _startBackgroundServices();
//       _startLocationMonitoring();
//       _startLocalBackupTimer();
//       _scheduleMidnightClockOut();
//       _startPermissionMonitoring();
//     } else {
//       locationViewModel.isClockedIn.value   = false;
//       attendanceViewModel.isClockedIn.value = false;
//     }
//
//     if (mounted) setState(() {});
//   }
//
//   // ══════════════════════════════════════════════════════════════
//   //  DAILY STATE
//   // ══════════════════════════════════════════════════════════════
//
//   int    _accumulatedSeconds = 0;
//   String _displayCheckIn     = '--:--';
//   String _displayCheckOut    = '--:--';
//
//   static const String _kAccumSec = 'daily_accum_seconds';
//   static const String _kCheckIn  = 'daily_check_in';
//   static const String _kCheckOut = 'daily_check_out';
//   static const String _kLastDate = 'daily_last_date';
//
//   Future<void> _initDailyState() async {
//     final prefs    = await SharedPreferences.getInstance();
//     final today    = DateFormat('yyyy-MM-dd').format(DateTime.now());
//     final lastDate = prefs.getString(_kLastDate) ?? '';
//
//     if (lastDate != today) {
//       await prefs.setString(_kLastDate, today);
//       await prefs.setInt(_kAccumSec, 0);
//       await prefs.remove(_kCheckIn);
//       await prefs.remove(_kCheckOut);
//       await prefs.remove('clockInTime');
//       await prefs.remove('currentSessionStart');
//       await prefs.setBool('isClockedIn', false);
//
//       _accumulatedSeconds = 0;
//       _localClockInTime   = null;
//       _localElapsedTime   = '00:00:00';
//       attendanceViewModel.elapsedTime.value = '00:00:00';
//       _localBackupTimer?.cancel();
//       _localBackupTimer = null;
//     }
//
//     _accumulatedSeconds = prefs.getInt(_kAccumSec)    ?? 0;
//     _displayCheckIn     = prefs.getString(_kCheckIn)  ?? '--:--';
//     _displayCheckOut    = prefs.getString(_kCheckOut) ?? '--:--';
//     if (mounted) setState(() {});
//   }
//
//   Future<void> _saveCheckInTime() async {
//     final prefs = await SharedPreferences.getInstance();
//     final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
//     await prefs.setString(_kLastDate, today);
//     if (prefs.getString(_kCheckIn) == null || prefs.getString(_kCheckIn) == '--:--') {
//       await prefs.setString(_kCheckIn, DateFormat('HH:mm').format(DateTime.now()));
//     }
//     _displayCheckIn  = prefs.getString(_kCheckIn) ?? '--:--';
//     _displayCheckOut = '--:--';
//     await prefs.remove(_kCheckOut);
//     if (mounted) setState(() {});
//   }
//
//   Future<void> _saveCheckOutTime() async {
//     final prefs = await SharedPreferences.getInstance();
//     if (_localClockInTime != null) {
//       _accumulatedSeconds += DateTime.now().difference(_localClockInTime!).inSeconds;
//       await prefs.setInt(_kAccumSec, _accumulatedSeconds);
//     }
//     _displayCheckOut = DateFormat('HH:mm').format(DateTime.now());
//     await prefs.setString(_kCheckOut, _displayCheckOut);
//     if (mounted) setState(() {});
//   }
//
//   String _buildDisplayTime() {
//     int totalSec = _accumulatedSeconds;
//     if (_localClockInTime != null && attendanceViewModel.isClockedIn.value) {
//       final today      = DateFormat('yyyy-MM-dd').format(DateTime.now());
//       final clockInDay = DateFormat('yyyy-MM-dd').format(_localClockInTime!);
//       if (clockInDay == today) {
//         totalSec += DateTime.now().difference(_localClockInTime!).inSeconds;
//       } else {
//         _localClockInTime = null;
//       }
//     }
//     if (totalSec < 0) totalSec = 0;
//     String pad(int n) => n.toString().padLeft(2, '0');
//     return '${pad(totalSec ~/ 3600)}:${pad((totalSec % 3600) ~/ 60)}:${pad(totalSec % 60)}';
//   }
//
//   // ══════════════════════════════════════════════════════════════
//   //  HARD RESET
//   // ══════════════════════════════════════════════════════════════
//
//   Future<void> _hardResetAllTimerState() async {
//     _localBackupTimer?.cancel();     _localBackupTimer = null;
//     _locationMonitorTimer?.cancel(); _locationMonitorTimer = null;
//     _midnightClockOutTimer?.cancel();
//     _permissionCheckTimer?.cancel(); _permissionCheckTimer = null;
//
//     _localClockInTime   = null;
//     _localElapsedTime   = '00:00:00';
//     _accumulatedSeconds = 0;
//     _displayCheckIn     = '--:--';
//     _displayCheckOut    = '--:--';
//     attendanceViewModel.elapsedTime.value = '00:00:00';
//     if (mounted) setState(() {});
//
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove('clockInTime');
//     await prefs.remove('currentSessionStart');
//     await prefs.setInt(_kAccumSec, 0);
//     await prefs.remove(_kCheckIn);
//     await prefs.remove(_kCheckOut);
//     await prefs.setString(_kLastDate, DateFormat('yyyy-MM-dd').format(DateTime.now()));
//     await prefs.setBool(KEY_IS_TIMER_FROZEN, true);
//     await prefs.setBool('flutter.$KEY_IS_TIMER_FROZEN', true);
//   }
//
//   // ══════════════════════════════════════════════════════════════
//   //  LOCATION MONITORING
//   // ══════════════════════════════════════════════════════════════
//
//   void _startLocationMonitoring() {
//     _wasLocationAvailable    = true;
//     _autoClockOutInProgress  = false;
//
//     _locationMonitorTimer =
//         Timer.periodic(const Duration(seconds: 3), (timer) async {
//           SharedPreferences prefs = await SharedPreferences.getInstance();
//           bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
//           if (isFrozen) { timer.cancel(); return; }
//           if (!attendanceViewModel.isClockedIn.value) {
//             _stopLocationMonitoring();
//             return;
//           }
//           bool currentLocationAvailable =
//           await attendanceViewModel.isLocationAvailable();
//           if (_wasLocationAvailable && !currentLocationAvailable) {
//             await _handleAutoClockOut(
//                 reason: 'System ClockOut - Location Off', context: context);
//             return;
//           }
//           _wasLocationAvailable = currentLocationAvailable;
//         });
//   }
//
//   void _startBackgroundServices() async {
//     try {
//       final service = FlutterBackgroundService();
//       await location.enableBackgroundMode(enable: true);
//       initializeServiceLocation()
//           .catchError((e) => debugPrint("Service init error: $e"));
//       service.startService()
//           .catchError((e) => debugPrint("Service start error: $e"));
//     } catch (e) {
//       debugPrint("⚠ [BACKGROUND] Services error: $e");
//     }
//   }
//
//   void _stopLocationMonitoring() {
//     _locationMonitorTimer?.cancel();
//     _locationMonitorTimer   = null;
//     _autoClockOutInProgress = false;
//   }
//
//   // ══════════════════════════════════════════════════════════════
//   //  NOTIFICATIONS
//   // ══════════════════════════════════════════════════════════════
//
//   Future<void> _initializeUrgentNotifications() async {
//     flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
//     const AndroidNotificationChannel urgentChannel = AndroidNotificationChannel(
//       'urgent_auto_clockout_channel',
//       'URGENT Auto Clockout Notifications',
//       description: 'High-priority channel for urgent auto clockout notifications',
//       importance: Importance.max,
//       enableVibration: true,
//       playSound: true,
//       enableLights: true,
//       ledColor: Colors.red,
//     );
//     const AndroidInitializationSettings androidSettings =
//     AndroidInitializationSettings('@mipmap/ic_launcher');
//     const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
//       requestAlertPermission: true,
//       requestBadgePermission: true,
//       requestSoundPermission: true,
//     );
//     await flutterLocalNotificationsPlugin.initialize(
//       const InitializationSettings(android: androidSettings, iOS: iosSettings),
//     );
//     await flutterLocalNotificationsPlugin
//         .resolvePlatformSpecificImplementation<
//         AndroidFlutterLocalNotificationsPlugin>()
//         ?.createNotificationChannel(urgentChannel);
//   }
//
//   // ══════════════════════════════════════════════════════════════
//   //  BUILD
//   // ══════════════════════════════════════════════════════════════
//
//   @override
//   Widget build(BuildContext context) {
//     final String formattedDate =
//     DateFormat('EEE, dd MMM yyyy').format(DateTime.now());
//
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//               color: Colors.blueGrey.withOpacity(0.12),
//               blurRadius: 16,
//               offset: const Offset(0, 4))
//         ],
//       ),
//       padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // ── Header ──────────────────────────────────────────────
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Row(children: [
//                 Icon(Icons.timer_outlined, size: 18, color: Colors.blueGrey.shade700),
//                 const SizedBox(width: 6),
//                 Text('Work Timer',
//                     style: TextStyle(
//                         fontSize: 15,
//                         fontWeight: FontWeight.w700,
//                         color: Colors.blueGrey.shade800)),
//               ]),
//               Text(formattedDate,
//                   style: TextStyle(
//                       fontSize: 12,
//                       color: Colors.blueGrey.shade400,
//                       fontWeight: FontWeight.w500)),
//             ],
//           ),
//           const SizedBox(height: 14),
//
//           // ── Timer circle + stats ─────────────────────────────────
//           Row(
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               Obx(() {
//                 final bool clocked = attendanceViewModel.isClockedIn.value;
//                 String displayTime = _buildDisplayTime();
//                 if (_accumulatedSeconds == 0 && _localClockInTime == null && clocked) {
//                   displayTime = attendanceViewModel.elapsedTime.value;
//                 }
//                 return SizedBox(
//                   width: 90,
//                   height: 90,
//                   child: Stack(alignment: Alignment.center, children: [
//                     Container(
//                       width: 90,
//                       height: 90,
//                       decoration: BoxDecoration(
//                         shape: BoxShape.circle,
//                         color: clocked
//                             ? Colors.blueGrey.shade50
//                             : Colors.grey.shade50,
//                         border: Border.all(
//                             color: clocked
//                                 ? Colors.blueGrey.shade300
//                                 : Colors.grey.shade300,
//                             width: 2),
//                       ),
//                     ),
//                     Column(mainAxisSize: MainAxisSize.min, children: [
//                       Text(displayTime,
//                           style: TextStyle(
//                               fontSize: 14,
//                               fontWeight: FontWeight.w800,
//                               color: clocked
//                                   ? Colors.blueGrey.shade800
//                                   : Colors.blueGrey.shade400,
//                               letterSpacing: -0.5)),
//                       Text(clocked ? 'LIVE' : 'STOPPED',
//                           style: TextStyle(
//                               fontSize: 8,
//                               fontWeight: FontWeight.w700,
//                               color: clocked
//                                   ? Colors.blueGrey.shade500
//                                   : Colors.blueGrey.shade300,
//                               letterSpacing: 1.0)),
//                     ]),
//                   ]),
//                 );
//               }),
//               const SizedBox(width: 20),
//
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(children: [
//                       Expanded(
//                           child: _statItem(
//                               label: 'Check In',
//                               value: _displayCheckIn,
//                               icon: Icons.login_rounded,
//                               iconColor: Colors.green.shade600)),
//                       Container(
//                           width: 1,
//                           height: 36,
//                           color: Colors.blueGrey.shade100,
//                           margin: const EdgeInsets.symmetric(horizontal: 10)),
//                       Expanded(
//                           child: _statItem(
//                               label: 'Check Out',
//                               value: _displayCheckOut,
//                               icon: Icons.logout_rounded,
//                               iconColor: Colors.red.shade400)),
//                     ]),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           // ── Online / Offline status indicator ───────────────────
//           Obx(() {
//             final online = _isOnline.value;
//             return AnimatedContainer(
//               duration: const Duration(milliseconds: 500),
//               curve: Curves.easeInOut,
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
//               decoration: BoxDecoration(
//                 color: online ? Colors.green.shade50 : Colors.red.shade50,
//                 borderRadius: BorderRadius.circular(20),
//                 border: Border.all(
//                   color: online ? Colors.green.shade200 : Colors.red.shade200,
//                   width: 1,
//                 ),
//               ),
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   AnimatedContainer(
//                     duration: const Duration(milliseconds: 500),
//                     width: 7,
//                     height: 7,
//                     decoration: BoxDecoration(
//                       shape: BoxShape.circle,
//                       color: online
//                           ? Colors.green.shade500
//                           : Colors.red.shade400,
//                     ),
//                   ),
//                   const SizedBox(width: 6),
//                   AnimatedSwitcher(
//                     duration: const Duration(milliseconds: 300),
//                     child: Text(
//                       online ? 'Online' : 'Offline',
//                       key: ValueKey(online),
//                       style: TextStyle(
//                         fontSize: 11,
//                         fontWeight: FontWeight.w600,
//                         color: online
//                             ? Colors.green.shade700
//                             : Colors.red.shade600,
//                         letterSpacing: 0.2,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 6),
//                   AnimatedSwitcher(
//                     duration: const Duration(milliseconds: 300),
//                     child: Icon(
//                       online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
//                       key: ValueKey(online),
//                       size: 13,
//                       color: online
//                           ? Colors.green.shade500
//                           : Colors.red.shade400,
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           }),
//           const SizedBox(height: 10),
//
//           // ── Buttons ─────────────────────────────────────────────
//           Row(children: [
//             Expanded(
//               child: Obx(() {
//                 final bool clocked = attendanceViewModel.isClockedIn.value;
//                 return SizedBox(
//                   height: 44,
//                   child: OutlinedButton.icon(
//                     onPressed: clocked
//                         ? null
//                         : () async {
//                       await _handleClockIn(context);
//                       if (attendanceViewModel.isClockedIn.value) {
//                         await _saveCheckInTime();
//                       }
//                     },
//                     icon: Icon(Icons.login_rounded,
//                         size: 16,
//                         color: clocked
//                             ? Colors.grey.shade400
//                             : Colors.blueGrey.shade700),
//                     label: Text('Clock In',
//                         style: TextStyle(
//                             fontSize: 13,
//                             fontWeight: FontWeight.w700,
//                             color: clocked
//                                 ? Colors.grey.shade400
//                                 : Colors.blueGrey.shade700)),
//                     style: OutlinedButton.styleFrom(
//                       side: BorderSide(
//                           color: clocked
//                               ? Colors.grey.shade300
//                               : Colors.blueGrey.shade400,
//                           width: 1.5),
//                       shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12)),
//                       backgroundColor: Colors.transparent,
//                     ),
//                   ),
//                 );
//               }),
//             ),
//             const SizedBox(width: 10),
//             Expanded(
//               child: Obx(() {
//                 final bool clocked = attendanceViewModel.isClockedIn.value;
//                 return SizedBox(
//                   height: 44,
//                   child: ElevatedButton.icon(
//                     onPressed: clocked
//                         ? () async {
//                       await _saveCheckOutTime();
//                       await _handleClockOut(context);
//                     }
//                         : null,
//                     icon: Icon(Icons.radio_button_checked,
//                         size: 16,
//                         color: clocked ? Colors.white : Colors.white54),
//                     label: Text('Clock Out',
//                         style: TextStyle(
//                             fontSize: 13,
//                             fontWeight: FontWeight.w700,
//                             color: clocked ? Colors.white : Colors.white54)),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: clocked
//                           ? Colors.blueGrey.shade700
//                           : Colors.blueGrey.shade300,
//                       disabledBackgroundColor: Colors.blueGrey.shade300,
//                       elevation: clocked ? 3 : 0,
//                       shadowColor: Colors.blueGrey.withOpacity(0.4),
//                       shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12)),
//                     ),
//                   ),
//                 );
//               }),
//             ),
//           ]),
//         ],
//       ),
//     );
//   }
//
//   Widget _statItem({
//     required String label,
//     required String value,
//     IconData? icon,
//     Color? iconColor,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(children: [
//           if (icon != null) ...[
//             Icon(icon, size: 12, color: iconColor ?? Colors.blueGrey),
//             const SizedBox(width: 3)
//           ],
//           Text(label,
//               style: TextStyle(
//                   fontSize: 10,
//                   color: Colors.blueGrey.shade400,
//                   fontWeight: FontWeight.w500)),
//         ]),
//         const SizedBox(height: 2),
//         Text(value,
//             style: TextStyle(
//                 fontSize: 17,
//                 fontWeight: FontWeight.w800,
//                 color: Colors.blueGrey.shade800,
//                 letterSpacing: -0.3)),
//       ],
//     );
//   }
//
//   // Missing method to check for missed clockout (multi-day)
//   Future<void> _checkForMissedClockout() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     final hasCriticalEvent =
//         (prefs.getBool('has_critical_event_pending') ?? false) ||
//             (prefs.getBool('flutter.has_critical_event_pending') ?? false);
//     if (hasCriticalEvent) return;
//
//     final isClockedIn =
//         (prefs.getBool('isClockedIn') ?? false) ||
//             (prefs.getBool('flutter.isClockedIn') ?? false);
//     if (!isClockedIn) return;
//
//     final clockInTimeStr =
//         prefs.getString('clockInTime') ??
//             prefs.getString('flutter.clockInTime');
//     if (clockInTimeStr == null) return;
//
//     final clockInTime = DateTime.tryParse(clockInTimeStr);
//     if (clockInTime == null) return;
//
//     final today      = DateFormat('yyyy-MM-dd').format(DateTime.now());
//     final clockInDay = DateFormat('yyyy-MM-dd').format(clockInTime);
//
//     if (clockInDay == today) return;
//
//     final daysDiff = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
//         .difference(DateTime(clockInTime.year, clockInTime.month, clockInTime.day))
//         .inDays;
//     if (daysDiff > 1) return;
//
//     final missedClockoutTime = DateTime(
//       clockInTime.year, clockInTime.month, clockInTime.day, 23, 58, 0,
//     );
//     const reason = 'System ClockOut - Midnight Time';
//
//     debugPrint('⚡ [MISSED CLOCKOUT] clockIn=$clockInTime → clockout=$missedClockoutTime');
//
//     try {
//       await attendanceOutViewModel.fastSaveAttendanceOut(
//         clockOutTime:  missedClockoutTime,
//         totalDistance: 0.0,
//         isAuto:        true,
//         reason:        reason,
//       );
//       await DailyWorkTimeManager.recordClockOut(missedClockoutTime);
//       debugPrint('✅ [MISSED CLOCKOUT] Saved for ${DateFormat('dd MMM').format(clockInTime)}');
//     } catch (e) {
//       debugPrint('❌ [MISSED CLOCKOUT] Failed: $e');
//     }
//
//     await prefs.setBool('isClockedIn', false);
//     await prefs.setBool('flutter.isClockedIn', false);
//     await prefs.remove('clockInTime');
//     await prefs.remove('flutter.clockInTime');
//     await prefs.remove(KEY_IS_TIMER_FROZEN);
//     await prefs.remove('flutter.$KEY_IS_TIMER_FROZEN');
//     await prefs.setBool('clockOutPending', false);
//     await prefs.setBool('hasFastClockOutData', false);
//
//     _stopLocationMonitoring();
//     _localBackupTimer?.cancel();
//     _localBackupTimer = null;
//     _midnightClockOutTimer?.cancel();
//     _permissionCheckTimer?.cancel();
//     _permissionCheckTimer = null;
//
//     await _mqttTracker.clockOutMqtt();
//     _mqttLive.value = false;
//
//     await _hardResetAllTimerState();
//     locationViewModel.isClockedIn.value   = false;
//     attendanceViewModel.isClockedIn.value = false;
//
//     _triggerAutoSync();
//
//     if (mounted) {
//       _showSnack(
//         title: '⚡ Missed Clock-Out Recover Hua',
//         message:
//         '${DateFormat('dd MMM').format(clockInTime)} ka clock-out 10:00 PM par record hua.',
//         type: _SnackType.warning,
//         duration: const Duration(seconds: 7),
//       );
//     }
//   }
//
//   Future<void> _checkForMultiDayMissed() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     final hasCriticalEvent =
//         (prefs.getBool('has_critical_event_pending') ?? false) ||
//             (prefs.getBool('flutter.has_critical_event_pending') ?? false);
//     if (hasCriticalEvent) return;
//
//     final isClockedIn =
//         (prefs.getBool('isClockedIn') ?? false) ||
//             (prefs.getBool('flutter.isClockedIn') ?? false);
//     if (!isClockedIn) return;
//
//     final clockInTimeStr =
//         prefs.getString('clockInTime') ??
//             prefs.getString('flutter.clockInTime');
//     if (clockInTimeStr == null) return;
//
//     final clockInTime = DateTime.tryParse(clockInTimeStr);
//     if (clockInTime == null) return;
//
//     final todayDay   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
//     final clockInDay = DateTime(clockInTime.year, clockInTime.month, clockInTime.day);
//
//     final daysDiff = todayDay.difference(clockInDay).inDays;
//     if (daysDiff <= 1) return;
//
//     final missedClockoutTime = DateTime(
//       clockInTime.year, clockInTime.month, clockInTime.day, 23, 58, 0,
//     );
//     const reason = 'System ClockOut - Midnight Time';
//
//     debugPrint('⚡ [MULTI-DAY] $daysDiff din miss — clockIn=$clockInTime → clockout=$missedClockoutTime');
//
//     try {
//       await attendanceOutViewModel.fastSaveAttendanceOut(
//         clockOutTime:  missedClockoutTime,
//         totalDistance: 0.0,
//         isAuto:        true,
//         reason:        reason,
//       );
//       await DailyWorkTimeManager.recordClockOut(missedClockoutTime);
//       debugPrint('✅ [MULTI-DAY] Saved for ${DateFormat('dd MMM').format(clockInTime)}');
//     } catch (e) {
//       debugPrint('❌ [MULTI-DAY] Failed: $e');
//     }
//
//     await prefs.setBool('isClockedIn', false);
//     await prefs.setBool('flutter.isClockedIn', false);
//     await prefs.remove('clockInTime');
//     await prefs.remove('flutter.clockInTime');
//     await prefs.remove(KEY_IS_TIMER_FROZEN);
//     await prefs.remove('flutter.$KEY_IS_TIMER_FROZEN');
//     await prefs.setBool('clockOutPending', false);
//     await prefs.setBool('hasFastClockOutData', false);
//
//     _stopLocationMonitoring();
//     _localBackupTimer?.cancel();
//     _localBackupTimer = null;
//     _midnightClockOutTimer?.cancel();
//     _permissionCheckTimer?.cancel();
//     _permissionCheckTimer = null;
//
//     await _mqttTracker.clockOutMqtt();
//     _mqttLive.value = false;
//
//     await _hardResetAllTimerState();
//     locationViewModel.isClockedIn.value   = false;
//     attendanceViewModel.isClockedIn.value = false;
//
//     _triggerAutoSync();
//
//     if (mounted) {
//       _showSnack(
//         title: '📅 $daysDiff Din Ka Data Recover Hua',
//         message:
//         '${DateFormat('dd MMM').format(clockInTime)} ka clock-out 10:00 PM par record hua.',
//         type: _SnackType.warning,
//         duration: const Duration(seconds: 7),
//       );
//     }
//   }
//
//   // Helper method to send fake GPS data to server
//   Future<void> _sendFakeGpsDataToServer(SharedPreferences prefs, DateTime eventTime) async {
//     // This method already exists in your code, keeping as is
//     debugPrint('📤 [FAKE GPS] Sending fake GPS data to server...');
//     // Your existing implementation
//   }
//
//   Future<String> _getAddressFromCoords(double lat, double lon) async {
//     try {
//       final marks = await placemarkFromCoordinates(lat, lon).timeout(const Duration(seconds: 8));
//       if (marks.isEmpty) return '$lat, $lon';
//       final p = marks.first;
//       final parts = [
//         p.thoroughfare,
//         p.subLocality,
//         p.locality,
//         p.administrativeArea,
//         p.country,
//       ].where((s) => s != null && s.isNotEmpty).join(', ');
//       return parts.isEmpty ? '$lat, $lon' : parts;
//     } catch (e) {
//       debugPrint('⚠️ [FAKE GPS] Geocoding failed: $e');
//       return '$lat, $lon';
//     }
//   }
//
//   Future<void> _saveFakeGpsToLocalDb(Map<String, dynamic> model) async {
//     try {
//       final dbHelper = DBHelper();
//       await dbHelper.insertFakeGpsLog(model);
//       debugPrint('💾 [FAKE GPS] Saved to local DB for later sync');
//     } catch (e) {
//       debugPrint('❌ [FAKE GPS] Failed to save to local DB: $e');
//     }
//   }
//
//   Future<void> _saveFakeGpsToLocalDbFromPrefs(SharedPreferences prefs, DateTime eventTime) async {
//     try {
//       final fakeLat = prefs.getDouble('flutter.fake_gps_lat') ?? 0.0;
//       final fakeLon = prefs.getDouble('flutter.fake_gps_lon') ?? 0.0;
//       final realLat = prefs.getDouble('flutter.real_gps_lat') ?? 0.0;
//       final realLon = prefs.getDouble('flutter.real_gps_lon') ?? 0.0;
//
//       if (fakeLat == 0.0 && fakeLon == 0.0) return;
//
//       final userId = prefs.getString('user_id') ?? prefs.getString('userId') ?? '';
//       final bookerName = prefs.getString('booker_name') ?? prefs.getString('userName') ?? '';
//       final designation = prefs.getString('designation') ?? prefs.getString('userDesignation') ?? '';
//
//       final fakeAddress = await _getAddressFromCoords(fakeLat, fakeLon);
//       final realAddress = await _getAddressFromCoords(realLat, realLon);
//       final distanceKm = Geolocator.distanceBetween(realLat, realLon, fakeLat, fakeLon) / 1000.0;
//
//       final model = {
//         'user_id': userId,
//         'booker_name': bookerName,
//         'designation': designation,
//         'real_latitude': realLat,
//         'real_longitude': realLon,
//         'real_address': realAddress,
//         'fake_latitude': fakeLat,
//         'fake_longitude': fakeLon,
//         'fake_address': fakeAddress,
//         'distance_km': distanceKm.toStringAsFixed(3),
//         'detected_at': eventTime.toIso8601String(),
//       };
//
//       final dbHelper = DBHelper();
//       await dbHelper.insertFakeGpsLog(model);
//       debugPrint('💾 [FAKE GPS] Saved to local DB (from prefs)');
//     } catch (e) {
//       debugPrint('❌ [FAKE GPS] Failed to save to local DB from prefs: $e');
//     }
//   }
// }



import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
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
import '../../Tracker/attendance_timelog_api.dart';
import '../../Tracker/location_export_data.dart';
import '../../Tracker/location_tracking_service.dart';
import '../../Tracker/mqtt_work.dart';
import '../../Utils/daily_work_time_manager.dart';
import '../../main.dart';
import 'package:intl/intl.dart';
import '../clockout_alarm_service.dart';
import '../sync_notification_service.dart';
import '../../Tracker/fake_gps_logs.dart';


// ─────────────────────────────────────────────────────────────
//  FANCY SNACKBAR
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

  static const String KEY_IS_TIMER_FROZEN = 'is_timer_frozen';

  // Auto Date & Time channel
  static const _autoTimeChannel =
  MethodChannel('com.metaxperts.order_booking_app/auto_time');

  // OEM Settings Channel
  static const _oemSettingsChannel =
  MethodChannel('com.metaxperts.order_booking_app/oem_settings');

  // Android Automatic Date & Time check
  Future<bool> _isAutoTimeEnabled() async {
    try {
      if (!Platform.isAndroid) return true;
      final bool enabled =
          await _autoTimeChannel.invokeMethod<bool>('isAutoTimeEnabled') ?? true;
      return enabled;
    } catch (e) {
      debugPrint('⚠️ [AUTO TIME] Check failed: $e');
      return true;
    }
  }

  // Android Date & Time settings screen open karo
  Future<void> _openDateTimeSettings() async {
    try {
      await _autoTimeChannel.invokeMethod('openDateTimeSettings');
    } catch (e) {
      debugPrint('⚠️ [AUTO TIME] openDateTimeSettings: $e');
    }
  }

  // ✅ OEM Setup Methods
  Future<String> _getOemBrand() async {
    try {
      final brand = await _oemSettingsChannel.invokeMethod<String>('getOemBrand');
      return brand ?? '';
    } catch (e) {
      debugPrint('⚠️ [OEM] getOemBrand failed: $e');
      return '';
    }
  }

  Future<void> _openOemAutoStartSettings() async {
    try {
      await _oemSettingsChannel.invokeMethod('openOemAutoStartSettings');
    } catch (e) {
      debugPrint('⚠️ [OEM] openOemAutoStartSettings failed: $e');
    }
  }

  bool _needsOemSetup(String brand) {
    final oemBrands = ['xiaomi', 'oppo', 'vivo', 'realme', 'huawei',
      'honor', 'samsung', 'oneplus', 'tecno', 'infinix', 'itel'];
    return oemBrands.any((b) => brand.contains(b));
  }

  Future<void> _showOemSetupDialogIfNeeded(BuildContext context) async {
    final brand = await _getOemBrand();
    if (!_needsOemSetup(brand)) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('oem_setup_shown_$brand') == true) return;

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.android, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text('$brand Setup Required',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200, width: 1),
              ),
              child: const Text(
                'To ensure GPS tracking works even when app is closed:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            const Text('1. Tap "Open Settings" below',
                style: TextStyle(fontSize: 12)),
            const Text('2. Find and enable "Auto-start" or "Background Start"',
                style: TextStyle(fontSize: 12)),
            const Text('3. Also allow "Run in background" if available',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Text('Device: $brand',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _openOemAutoStartSettings();
              await prefs.setBool('oem_setup_shown_$brand', true);
            },
            icon: const Icon(Icons.settings, size: 16),
            label: const Text('Open Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

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
      await _checkForMissedClockout();
      await _checkForMultiDayMissed();
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
      // App minimized - no bubble
    } else if (state == AppLifecycleState.resumed) {
      _checkForBackgroundClockout().then((_) async {
        await _checkForMissedClockout();
        await _checkForMultiDayMissed();
        _restoreEverything();
        _checkConnectivityAndSync();
        _rescheduleMidnightClockOut();
        _startNativeMonitoringService();
      });
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  LOCATION CSV EXPORT
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
  //  NATIVE SERVICE
  // ══════════════════════════════════════════════════════════════

  Future<void> _startNativeMonitoringService() async {
    try {
      if (Platform.isAndroid) {
        final prefs = await SharedPreferences.getInstance();

        // Check either key: 'isClockedIn' (Flutter-written) or direct guard
        final isClockedIn = prefs.getBool('isClockedIn') ?? false;
        if (!isClockedIn) return;

        final userId      = prefs.getString('user_id')      ?? prefs.getString('emp_id')   ?? '';
        final bookerName  = prefs.getString('booker_name')  ?? prefs.getString('emp_name')  ?? '';
        final designation = prefs.getString('designation')  ?? prefs.getString('userDesignation') ?? '';
        final companyCode = prefs.getString('company_code') ?? prefs.getString('companyCode') ?? '';

        if (userId.isEmpty) {
          debugPrint("⚠️ [NATIVE SERVICE] userId empty — skipping start");
          return;
        }

        await platform.invokeMethod('startMonitoring', {
          'userId':      userId,
          'bookerName':  bookerName,
          'designation': designation,
          'companyCode': companyCode.isNotEmpty ? companyCode : 'PK-PUN-SKT-MX01-VT001',
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
  //  HANDLE CLOCK IN  ✅ UPDATED with OEM Dialog
  // ══════════════════════════════════════════════════════════════

  Future<void> _handleClockIn(BuildContext context) async {
    debugPrint("🎯 [TIMERCARD] CLOCK-IN STARTED");

    // ── STEP 0: OEM Setup Dialog (Xiaomi/Vivo/Samsung etc.) ──────
    await _showOemSetupDialogIfNeeded(context);

    // ── STEP 1: Android Automatic Date & Time check ──────────────
    final bool autoTimeOn = await _isAutoTimeEnabled();
    if (!autoTimeOn) {
      debugPrint("⛔ [CLOCK-IN] Auto Date & Time DISABLED — blocking");

      final prefsForApi = await SharedPreferences.getInstance();
      final String apiUserId = prefsForApi.getString('user_id') ??
          prefsForApi.getString('emp_id')   ??
          prefsForApi.getString('userId')   ?? '';
      final String apiBookerName = prefsForApi.getString('booker_name') ??
          prefsForApi.getString('emp_name') ??
          prefsForApi.getString('userName') ?? '';
      final String apiDesignation = prefsForApi.getString('designation') ??
          prefsForApi.getString('job')              ??
          prefsForApi.getString('userDesignation')  ?? '';
      final String apiCompanyCode = prefsForApi.getString('company_code') ??
          prefsForApi.getString('companyCode')       ?? '';

      final apiResult = await AttendanceTimelogApi.postClockIn(
        userId:          apiUserId,
        bookerName:      apiBookerName,
        designation:     apiDesignation,
        companyCode:     apiCompanyCode,
        autoTimeEnabled: false,
        clockInTime:     DateTime.now(),
      );

      debugPrint(apiResult.success
          ? '✅ [CLOCK-IN API] Logged to AUTO_TIME_LOG (auto_time=false)'
          : '⚠️ [CLOCK-IN API] Failed: ${apiResult.message}');

      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.access_time_filled_rounded,
                  color: Colors.orange.shade700, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Auto Time Required',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.orange.shade200, width: 1),
                ),
                child: const Text(
                  'Please enable Automatic Date & Time to mark attendance.',
                  style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 12),
              Text('Settings path:',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.blueGrey.shade400,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                'Settings → General Management\n'
                    '→ Date and Time\n'
                    '→ Enable "Automatic date and time"',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey.shade600,
                    height: 1.6),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel',
                  style:
                  TextStyle(color: Colors.blueGrey.shade400)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _openDateTimeSettings();
              },
              icon: const Icon(Icons.settings_rounded, size: 16),
              label: const Text('Open Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      );
      return;
    }

    // ── STEP 2: Daily state init ──────────────────────────────────
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
    final String companyCode = prefs.getString('company_code') ??
        prefs.getString('companyCode')        ?? '';

    debugPrint('👤 [CLOCK-IN] userId=$userId bookerName=$bookerName');

    await prefs.remove(KEY_IS_TIMER_FROZEN);
    await prefs.remove('flutter.$KEY_IS_TIMER_FROZEN');
    _permissionCheckTimer?.cancel();
    _permissionCheckTimer = null;
    _localElapsedTime = '00:00:00';

    // ── STEP 3: Location permission ───────────────────────────────
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

    // ── STEP 4: Progress dialog ───────────────────────────────────
    if (!mounted) return;
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
      final DateTime clockInTime = DateTime.now();

      await LocationTrackingService().startTracking();
      await attendanceViewModel.saveFormAttendanceIn();
      _startBackgroundServices();

      locationViewModel.isClockedIn.value   = true;
      attendanceViewModel.isClockedIn.value = true;

      // Register Fake-GPS auto clock-out callback
      FakeGpsLog.registerClockOutCallback((DateTime eventTime) async {
        await _handleAutoClockOut(
          reason:    'System ClockOut - Fake GPS Detected',
          context:   context,
          eventTime: eventTime,
        );
      });
      debugPrint('✅ [CLOCK-IN] FakeGPS clock-out callback registered');

      await prefs.setBool('isClockedIn', true);
      await prefs.setString('currentSessionStart', clockInTime.toIso8601String());

      // ── START NATIVE LocationMonitorService ───────────────────────────────
      // This MUST be called here (not just in initState) so the Kotlin service
      // starts in sync with every clock-in button press — app open, background,
      // or after kill/restart. The service holds a WakeLock + saves lat/lng to
      // SQLite every interval, independent of Flutter's lifecycle.
      try {
        await platform.invokeMethod('startMonitoring', {
          'userId':      userId,
          'bookerName':  bookerName,
          'designation': designation,
          'companyCode': companyCode.isNotEmpty ? companyCode : 'PK-PUN-SKT-MX01-VT001',
        });
        debugPrint("✅ [CLOCK-IN] Native LocationMonitorService started");
      } catch (e) {
        debugPrint("❌ [CLOCK-IN] Native service start failed: $e");
      }

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

      await _updateCurrentDistance();
      await DailyWorkTimeManager.recordClockIn(clockInTime);

      await SyncNotificationService.startPeriodicSyncReminder();
      debugPrint('✅ [CLOCK-IN] 15-min sync reminder started');

      // ── STEP 5: POST to Apex AUTO_TIME_LOG ───────────────────────
      final apiResult = await AttendanceTimelogApi.postClockIn(
        userId:          userId,
        bookerName:      bookerName,
        designation:     designation,
        companyCode:     companyCode,
        autoTimeEnabled: true,
        clockInTime:     clockInTime,
      );

      if (apiResult.success) {
        debugPrint('✅ [CLOCK-IN API] Record posted to AUTO_TIME_LOG');
      } else if (apiResult.savedOffline) {
        debugPrint('💾 [CLOCK-IN API] Offline — queued for sync when internet returns');
      } else {
        debugPrint('⚠️ [CLOCK-IN API] Failed (${apiResult.statusCode}): ${apiResult.message}');
      }

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
  //  HANDLE CLOCK OUT
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

      // Unregister Fake-GPS callback
      FakeGpsLog.unregisterClockOutCallback();
      debugPrint('🛑 [CLOCK-OUT] FakeGPS clock-out callback unregistered');

      await SyncNotificationService.stopPeriodicSyncReminder();
      debugPrint('🛑 [CLOCK-OUT] 15-min sync reminder stopped');

      final service = FlutterBackgroundService();
      service.invoke("stopService");

      // ── STOP NATIVE LocationMonitorService ───────────────────────────────
      // Must set isClockedIn=false BEFORE stopping the service so that
      // onDestroy() skips the critical-event save path (permission/location check).
      // stopMonitoring also cancels WorkManager + MidnightAlarm on Kotlin side.
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
  //  AUTO CLOCK-OUT
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

      // Unregister Fake-GPS callback
      FakeGpsLog.unregisterClockOutCallback();

      await SyncNotificationService.stopPeriodicSyncReminder();
      debugPrint('🛑 [CLOCK-OUT] 15-min sync reminder stopped');

      try { await location.enableBackgroundMode(enable: false); }
      catch (e) { debugPrint("⚠️ BG mode disable: $e"); }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isClockedIn', false);
      await prefs.setBool('flutter.isClockedIn', false);
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
          title: reason.contains('Fake GPS') ? '🚨 Fake GPS Detected' : 'Auto Clock-Out',
          message: reason.contains('Fake GPS')
              ? 'Mock location detected. Timer stopped automatically.'
              : 'Timer stopped automatically.',
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
      await prefs.setBool('flutter.isClockedIn', false);
      await prefs.setBool('clockOutPending', true);
      await _hardResetAllTimerState();
    } finally {
      _autoClockOutInProgress = false;
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  BACKGROUND CLOCKOUT CHECK
  // ══════════════════════════════════════════════════════════════

  Future<void> _checkForBackgroundClockout() async {
    final prefs = await SharedPreferences.getInstance();

    final hasCriticalEvent =
        (prefs.getBool('has_critical_event_pending') ?? false) ||
            (prefs.getBool('flutter.has_critical_event_pending') ?? false);

    if (!hasCriticalEvent) return;

    final reason = prefs.getString('critical_event_reason') ??
        prefs.getString('flutter.critical_event_reason') ??
        'System ClockOut - Midnight Time';

    final clockOutTimeStr =
        prefs.getString('flutter.fastClockOutTime') ??
            prefs.getString('flutter.critical_event_timestamp');

    final clockOutTime = (clockOutTimeStr != null)
        ? (DateTime.tryParse(clockOutTimeStr) ?? DateTime.now())
        : DateTime.now();

    final distance = prefs.getDouble('flutter.fastClockOutDistance') ?? 0.0;

    debugPrint('⚡ [BG CLOCKOUT] Detected: $reason | time=$clockOutTime');

    // Clear flags
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

    try {
      await attendanceOutViewModel.fastSaveAttendanceOut(
        clockOutTime:  clockOutTime,
        totalDistance: distance,
        isAuto:        true,
        reason:        reason,
      );
      await DailyWorkTimeManager.recordClockOut(clockOutTime);
      await prefs.setBool('clockOutPending', false);
      await prefs.setBool('hasFastClockOutData', false);
      debugPrint('✅ [BG CLOCKOUT] Attendance saved successfully');

      if (reason.contains('Fake GPS')) {
        debugPrint('🔄 [BG CLOCKOUT] Syncing pending fake GPS records via SQLite...');
        await FakeGpsLog.syncPending();
        debugPrint('✅ [BG CLOCKOUT] Fake GPS sync complete');
      }

    } catch (e) {
      debugPrint('❌ [BG CLOCKOUT] Attendance save failed: $e');
    }

    await _hardResetAllTimerState();

    locationViewModel.isClockedIn.value   = false;
    attendanceViewModel.isClockedIn.value = false;

    await prefs.setBool('isClockedIn', false);
    await prefs.setBool('flutter.isClockedIn', false);
    await prefs.remove('clockInTime');
    await prefs.remove('currentSessionStart');

    _triggerAutoSync();

    if (mounted) {
      final snackTitle = reason.contains('Fake GPS')
          ? '🚨 Fake GPS Detected'
          : reason.contains('Location Off')
          ? '📍 Location Turned Off'
          : reason.contains('Permission')
          ? '🔒 Location Permission Revoked'
          : '⏰ Auto Clock-Out (10:00 PM)';

      final snackMessage = reason.contains('Fake GPS')
          ? 'Mock location detected. You have been auto clocked out.'
          : 'You were auto clocked out. Data saved.';

      _showSnack(
        title: snackTitle,
        message: snackMessage,
        type: _SnackType.warning,
        duration: const Duration(seconds: 6),
      );
    }

    debugPrint('✅ [BG CLOCKOUT] Complete');
  }

  // ══════════════════════════════════════════════════════════════
  //  MIDNIGHT CLOCK-OUT
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
  //  PERMISSION MONITORING
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
  //  DISTANCE
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
  //  AUTO SYNC
  // ══════════════════════════════════════════════════════════════

  void _startAutoSyncMonitoring() async {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
          bool wasOnline = _isOnline.value;
          _isOnline.value = results.isNotEmpty &&
              results.any((r) => r != ConnectivityResult.none);
          if (_isOnline.value && !wasOnline && !_isSyncing) {
            _triggerAutoSync();
            debugPrint('🌐 [CONNECTIVITY] Internet aaya — timelog queue sync ho raha hai...');
            AttendanceTimelogApi.syncOfflineQueue();
          }
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

      await FakeGpsLog.syncPending();
      debugPrint('✅ [AUTO-SYNC] FakeGPS logs sync complete');

      await AttendanceTimelogApi.syncOfflineQueue();
      debugPrint('✅ [AUTO-SYNC] Timelog offline queue sync complete');

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
  //  RESTORE EVERYTHING
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
  //  BACKUP TIMER
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
  //  INITIALIZE FROM PERSISTENT STATE
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
  //  DAILY STATE
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
  //  HARD RESET
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
  //  LOCATION MONITORING
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
  //  NOTIFICATIONS
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
          const SizedBox(height: 10),

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

  // Missing method to check for missed clockout (multi-day)
  Future<void> _checkForMissedClockout() async {
    final prefs = await SharedPreferences.getInstance();

    final hasCriticalEvent =
        (prefs.getBool('has_critical_event_pending') ?? false) ||
            (prefs.getBool('flutter.has_critical_event_pending') ?? false);
    if (hasCriticalEvent) return;

    final isClockedIn =
        (prefs.getBool('isClockedIn') ?? false) ||
            (prefs.getBool('flutter.isClockedIn') ?? false);
    if (!isClockedIn) return;

    final clockInTimeStr =
        prefs.getString('clockInTime') ??
            prefs.getString('flutter.clockInTime');
    if (clockInTimeStr == null) return;

    final clockInTime = DateTime.tryParse(clockInTimeStr);
    if (clockInTime == null) return;

    final today      = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final clockInDay = DateFormat('yyyy-MM-dd').format(clockInTime);

    if (clockInDay == today) return;

    final daysDiff = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
        .difference(DateTime(clockInTime.year, clockInTime.month, clockInTime.day))
        .inDays;
    if (daysDiff > 1) return;

    final missedClockoutTime = DateTime(
      clockInTime.year, clockInTime.month, clockInTime.day, 23, 58, 0,
    );
    const reason = 'System ClockOut - Midnight Time';

    debugPrint('⚡ [MISSED CLOCKOUT] clockIn=$clockInTime → clockout=$missedClockoutTime');

    try {
      await attendanceOutViewModel.fastSaveAttendanceOut(
        clockOutTime:  missedClockoutTime,
        totalDistance: 0.0,
        isAuto:        true,
        reason:        reason,
      );
      await DailyWorkTimeManager.recordClockOut(missedClockoutTime);
      debugPrint('✅ [MISSED CLOCKOUT] Saved for ${DateFormat('dd MMM').format(clockInTime)}');
    } catch (e) {
      debugPrint('❌ [MISSED CLOCKOUT] Failed: $e');
    }

    await prefs.setBool('isClockedIn', false);
    await prefs.setBool('flutter.isClockedIn', false);
    await prefs.remove('clockInTime');
    await prefs.remove('flutter.clockInTime');
    await prefs.remove(KEY_IS_TIMER_FROZEN);
    await prefs.remove('flutter.$KEY_IS_TIMER_FROZEN');
    await prefs.setBool('clockOutPending', false);
    await prefs.setBool('hasFastClockOutData', false);

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

    _triggerAutoSync();

    if (mounted) {
      _showSnack(
        title: '⚡ Missed Clock-Out Recover Hua',
        message:
        '${DateFormat('dd MMM').format(clockInTime)} ka clock-out 10:00 PM par record hua.',
        type: _SnackType.warning,
        duration: const Duration(seconds: 7),
      );
    }
  }

  Future<void> _checkForMultiDayMissed() async {
    final prefs = await SharedPreferences.getInstance();

    final hasCriticalEvent =
        (prefs.getBool('has_critical_event_pending') ?? false) ||
            (prefs.getBool('flutter.has_critical_event_pending') ?? false);
    if (hasCriticalEvent) return;

    final isClockedIn =
        (prefs.getBool('isClockedIn') ?? false) ||
            (prefs.getBool('flutter.isClockedIn') ?? false);
    if (!isClockedIn) return;

    final clockInTimeStr =
        prefs.getString('clockInTime') ??
            prefs.getString('flutter.clockInTime');
    if (clockInTimeStr == null) return;

    final clockInTime = DateTime.tryParse(clockInTimeStr);
    if (clockInTime == null) return;

    final todayDay   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final clockInDay = DateTime(clockInTime.year, clockInTime.month, clockInTime.day);

    final daysDiff = todayDay.difference(clockInDay).inDays;
    if (daysDiff <= 1) return;

    final missedClockoutTime = DateTime(
      clockInTime.year, clockInTime.month, clockInTime.day, 23, 58, 0,
    );
    const reason = 'System ClockOut - Midnight Time';

    debugPrint('⚡ [MULTI-DAY] $daysDiff din miss — clockIn=$clockInTime → clockout=$missedClockoutTime');

    try {
      await attendanceOutViewModel.fastSaveAttendanceOut(
        clockOutTime:  missedClockoutTime,
        totalDistance: 0.0,
        isAuto:        true,
        reason:        reason,
      );
      await DailyWorkTimeManager.recordClockOut(missedClockoutTime);
      debugPrint('✅ [MULTI-DAY] Saved for ${DateFormat('dd MMM').format(clockInTime)}');
    } catch (e) {
      debugPrint('❌ [MULTI-DAY] Failed: $e');
    }

    await prefs.setBool('isClockedIn', false);
    await prefs.setBool('flutter.isClockedIn', false);
    await prefs.remove('clockInTime');
    await prefs.remove('flutter.clockInTime');
    await prefs.remove(KEY_IS_TIMER_FROZEN);
    await prefs.remove('flutter.$KEY_IS_TIMER_FROZEN');
    await prefs.setBool('clockOutPending', false);
    await prefs.setBool('hasFastClockOutData', false);

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

    _triggerAutoSync();

    if (mounted) {
      _showSnack(
        title: '📅 $daysDiff Din Ka Data Recover Hua',
        message:
        '${DateFormat('dd MMM').format(clockInTime)} ka clock-out 10:00 PM par record hua.',
        type: _SnackType.warning,
        duration: const Duration(seconds: 7),
      );
    }
  }

  // Helper method to send fake GPS data to server
  Future<void> _sendFakeGpsDataToServer(SharedPreferences prefs, DateTime eventTime) async {
    // This method already exists in your code, keeping as is
    debugPrint('📤 [FAKE GPS] Sending fake GPS data to server...');
    // Your existing implementation
  }

  Future<String> _getAddressFromCoords(double lat, double lon) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lon).timeout(const Duration(seconds: 8));
      if (marks.isEmpty) return '$lat, $lon';
      final p = marks.first;
      final parts = [
        p.thoroughfare,
        p.subLocality,
        p.locality,
        p.administrativeArea,
        p.country,
      ].where((s) => s != null && s.isNotEmpty).join(', ');
      return parts.isEmpty ? '$lat, $lon' : parts;
    } catch (e) {
      debugPrint('⚠️ [FAKE GPS] Geocoding failed: $e');
      return '$lat, $lon';
    }
  }

  Future<void> _saveFakeGpsToLocalDb(Map<String, dynamic> model) async {
    try {
      final dbHelper = DBHelper();
      await dbHelper.insertFakeGpsLog(model);
      debugPrint('💾 [FAKE GPS] Saved to local DB for later sync');
    } catch (e) {
      debugPrint('❌ [FAKE GPS] Failed to save to local DB: $e');
    }
  }

  Future<void> _saveFakeGpsToLocalDbFromPrefs(SharedPreferences prefs, DateTime eventTime) async {
    try {
      final fakeLat = prefs.getDouble('flutter.fake_gps_lat') ?? 0.0;
      final fakeLon = prefs.getDouble('flutter.fake_gps_lon') ?? 0.0;
      final realLat = prefs.getDouble('flutter.real_gps_lat') ?? 0.0;
      final realLon = prefs.getDouble('flutter.real_gps_lon') ?? 0.0;

      if (fakeLat == 0.0 && fakeLon == 0.0) return;

      final userId = prefs.getString('user_id') ?? prefs.getString('userId') ?? '';
      final bookerName = prefs.getString('booker_name') ?? prefs.getString('userName') ?? '';
      final designation = prefs.getString('designation') ?? prefs.getString('userDesignation') ?? '';

      final fakeAddress = await _getAddressFromCoords(fakeLat, fakeLon);
      final realAddress = await _getAddressFromCoords(realLat, realLon);
      final distanceKm = Geolocator.distanceBetween(realLat, realLon, fakeLat, fakeLon) / 1000.0;

      final model = {
        'user_id': userId,
        'booker_name': bookerName,
        'designation': designation,
        'real_latitude': realLat,
        'real_longitude': realLon,
        'real_address': realAddress,
        'fake_latitude': fakeLat,
        'fake_longitude': fakeLon,
        'fake_address': fakeAddress,
        'distance_km': distanceKm.toStringAsFixed(3),
        'detected_at': eventTime.toIso8601String(),
      };

      final dbHelper = DBHelper();
      await dbHelper.insertFakeGpsLog(model);
      debugPrint('💾 [FAKE GPS] Saved to local DB (from prefs)');
    } catch (e) {
      debugPrint('❌ [FAKE GPS] Failed to save to local DB from prefs: $e');
    }
  }
}