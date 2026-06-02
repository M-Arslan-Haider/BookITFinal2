//
//
// import 'dart:async';
// import 'dart:io';
// import 'dart:io' show Directory, InternetAddress, Platform, SocketException;
// import 'dart:ui';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:device_info_plus/device_info_plus.dart' show DeviceInfoPlugin;
// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:order_booking_app/Screens/PermissionScreens/camera_screen.dart';
// import 'package:order_booking_app/Screens/code_screen.dart';
// import 'package:order_booking_app/Screens/home_screen.dart';
// import 'package:order_booking_app/Screens/login_screen.dart';
// import 'package:order_booking_app/Screens/order_booking_screen.dart';
// import 'package:order_booking_app/Screens/order_booking_status_screen.dart';
// import 'package:order_booking_app/Screens/recovery_form_screen.dart';
// import 'package:order_booking_app/Screens/return_form_screen.dart';
// import 'package:order_booking_app/screens/code_screen.dart' hide CodeScreen;
// import 'package:order_booking_app/screens/splash_screen.dart';
// import 'package:package_info_plus/package_info_plus.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:workmanager/workmanager.dart';
// import 'Screens/sync_notification_service.dart';
// import 'Databases/dp_helper.dart';
// import 'Databases/util.dart';
// import 'Screens/Dispatcher/dispatcher_homepage.dart';
// import 'Screens/HomeScreenComponents/Bottom_Nav_Bar/bottom_nav_screen.dart';
// import 'Screens/NSM/nsm_homepage.dart';
// import 'Screens/RSMS_Views/RSM_HomePage.dart';
// import 'Screens/SM/sm_homepage.dart';
// import 'Screens/shop_visit_screen.dart';
// import 'Services/FirebaseServices/firebase_remote_config.dart';
// import 'Services/FirebaseServices/firebase_options.dart';
// import 'package:flutter_background_service_android/flutter_background_service_android.dart'
//     show AndroidServiceInstance;
// import 'package:flutter_background_service/flutter_background_service.dart'
//     show
//     AndroidConfiguration,
//     FlutterBackgroundService,
//     IosConfiguration,
//     ServiceInstance;
// import 'package:flutter_local_notifications/flutter_local_notifications.dart'
//     show
//     AndroidFlutterLocalNotificationsPlugin,
//     AndroidInitializationSettings,
//     AndroidNotificationChannel,
//     AndroidNotificationDetails,
//     DarwinInitializationSettings,
//     FlutterLocalNotificationsPlugin,
//     Importance,
//     InitializationSettings,
//     NotificationDetails;
// import 'package:geolocator/geolocator.dart';
// import 'package:intl/intl.dart';
// import 'Tracker/location_tracking_service.dart';
// import 'Tracker/fake_gps_logs.dart';
// import 'package:order_booking_app/ViewModels/login_view_model.dart';
// import 'package:android_intent_plus/android_intent.dart' as android_intent;
// import 'package:in_app_update/in_app_update.dart';
// import 'ViewModels/location_view_model.dart';
// import 'Repositories/location_tracking_repository.dart';
//
// // Global instances
// late LocationTrackingService locationTrackingService;
//
// // Flag to track if background services are initialized
// bool _backgroundServicesInitialized = false;
//
// // Method channel for sync trigger from notification
// const MethodChannel _syncChannel = MethodChannel('com.metaxperts.order_booking_app/sync_channel');
//
// // REMOVED: Bubble channel
//
// Future<void> main() async {
//   runZonedGuarded(() async {
//     final stopwatch = Stopwatch()..start();
//     WidgetsFlutterBinding.ensureInitialized();
//
//     debugPrint("═══════════════════════════════════════════════════════════");
//     debugPrint("🚀 APP STARTING - Optimized Cold Start");
//     debugPrint("═══════════════════════════════════════════════════════════");
//
//     // STEP 1: Load SharedPreferences FIRST
//     debugPrint("📦 Loading SharedPreferences...");
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.reload();
//     debugPrint("✅ SharedPreferences loaded (${stopwatch.elapsedMilliseconds}ms)");
//
//     // STEP 2: Determine authentication state
//     bool isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
//     pageName = prefs.getString('pageName') ?? '/cameraScreen';
//     newIsClockedIn = prefs.getBool('isClockedIn') ?? false;
//     user_id = prefs.getString('userId') ?? '';
//     userName = prefs.getString('userName') ?? '';
//     userCity = prefs.getString('userCity') ?? '';
//     userDesignation = prefs.getString('userDesignation') ?? '';
//     userBrand = prefs.getString('userBrand') ?? '';
//     userSM = prefs.getString('userSM') ?? '';
//     userNSM = prefs.getString('userNSM') ?? '';
//     userRSM = prefs.getString('userRSM') ?? '';
//     userDISPATCHER = prefs.getString('userDISPATCHER') ?? '';
//     userNameRSM = prefs.getString('userNameRSM') ?? '';
//     userNameNSM = prefs.getString('userNameNSM') ?? '';
//     userNameSM = prefs.getString('userNameSM') ?? '';
//     userNameDISPATCHER = prefs.getString('userNameDISPATCHER') ?? '';
//     companyCode = prefs.getString('companyCode') ?? '';
//
//     debugPrint("👤 Auth state: isAuthenticated=$isAuthenticated, clockedIn=$newIsClockedIn");
//
//     // STEP 3: Initialize Firebase
//     debugPrint("🔥 Initializing Firebase...");
//     await Firebase.initializeApp(
//       options: DefaultFirebaseOptions.currentPlatform,
//     );
//     debugPrint("✅ Firebase initialized (${stopwatch.elapsedMilliseconds}ms)");
//
//     // STEP 4: Initialize Config
//     debugPrint("⚙️ Initializing Config...");
//     await Config.initialize();
//     debugPrint("✅ Config initialized (${stopwatch.elapsedMilliseconds}ms)");
//
//     // STEP 5: WorkManager + 15-Minute Sync Notification
//     debugPrint("⏰ Initializing Workmanager...");
//     await Workmanager().initialize(
//       syncNotificationCallbackDispatcher,
//       isInDebugMode: false,
//     );
//     debugPrint("✅ Workmanager initialized");
//
//     // Notification service initialize
//     debugPrint("🔔 Initializing Sync Notification Service...");
//     await SyncNotificationService.initialize();
//     debugPrint("✅ Sync Notification Service initialized");
//
//     // ✅ IMPORTANT: Sirf tab start karein jab user authenticated ho aur clocked in ho
//     if (isAuthenticated && newIsClockedIn) {
//       debugPrint("✅ User is clocked in - Starting 15-minute sync reminder");
//       await SyncNotificationService.requestPermission();
//       await SyncNotificationService.startPeriodicSyncReminder();
//       debugPrint("✅ 15-minute sync reminder started successfully");
//     } else {
//       debugPrint("⏸️ User not clocked in - Sync reminder not started");
//     }
//
//     // STEP 6: FAKE GPS
//     if (isAuthenticated) {
//       debugPrint("🚨 [FakeGPS] Starting Fake GPS detection...");
//       FakeGpsLog.startConnectivityListener();
//       unawaited(FakeGpsLog.syncPending());
//       debugPrint("✅ [FakeGPS] Fake GPS detection initialized");
//     }
//
//     // STEP 7: GetX Controllers
//     Get.put(DBHelper(), permanent: true);
//     Get.put(LocationViewModel());
//
//     // STEP 8: Derive correct pageName if needed
//     if (isAuthenticated && (pageName.isEmpty || pageName == '/cameraScreen')) {
//       switch (userDesignation) {
//         case 'RSM':        pageName = '/RSMHomepage'; break;
//         case 'SM':         pageName = '/SMHomepage'; break;
//         case 'NSM':        pageName = '/NSMHomepage'; break;
//         case 'DISPATCHER': pageName = '/DispatcherHomepage'; break;
//         default:           pageName = '/home'; break;
//       }
//     }
//
//     // STEP 9: Setup Method Channel for Sync Trigger
//     _setupSyncChannel();
//
//     // ✅ FIX: Battery optimization whitelist
//     if (Platform.isAndroid) {
//       WidgetsBinding.instance.addPostFrameCallback((_) async {
//         await Future.delayed(const Duration(seconds: 2));
//         requestIgnoreBatteryOptimizations();
//       });
//     }
//
//     // STEP 10: Start UI immediately
//     debugPrint("🎨 Starting UI...");
//     runApp(MyApp(isAuthenticated));
//     debugPrint("✅ UI rendered (${stopwatch.elapsedMilliseconds}ms)");
//
//     // STEP 11: Launch heavy background services AFTER first frame
//     if (isAuthenticated && !_backgroundServicesInitialized && newIsClockedIn) {
//       WidgetsBinding.instance.addPostFrameCallback((_) async {
//         debugPrint("🔄 [LAZY] Starting background services...");
//         await _initializeBackgroundServices();
//         debugPrint("✅ [LAZY] Background services ready");
//       });
//     }
//
//     debugPrint("═══════════════════════════════════════════════════════════");
//     debugPrint("✅ APP START COMPLETE (${stopwatch.elapsedMilliseconds}ms)");
//     debugPrint("═══════════════════════════════════════════════════════════");
//
//   }, (error, stackTrace) {
//     debugPrint('❌ Error: $error');
//     debugPrint('📚 Stack Trace: $stackTrace');
//   });
// }
//
// /// Setup Method Channel for sync trigger from notification tap
// void _setupSyncChannel() {
//   _syncChannel.setMethodCallHandler((call) async {
//     debugPrint('📱 MethodChannel called: ${call.method}');
//     if (call.method == 'triggerSync') {
//       debugPrint('🔄 Sync triggered from notification tap!');
//       await _performDataSync();
//       return true;
//     }
//     return false;
//   });
// }
//
// /// Perform data sync when notification is tapped
// Future<void> _performDataSync() async {
//   debugPrint('🔄 Starting data sync...');
//   try {
//     final dbHelper = DBHelper();
//     final locationRepo = LocationTrackingRepository();
//     await locationRepo.postDataFromDatabaseToAPI();
//     debugPrint('✅ Location data synced');
//     await _syncUnpostedOrders(dbHelper);
//     debugPrint('✅ Orders data synced');
//     await _syncUnpostedAttendance(dbHelper);
//     debugPrint('✅ Attendance data synced');
//     await _syncUnpostedShopVisits(dbHelper);
//     debugPrint('✅ Shop visits data synced');
//     await _syncUnpostedFakeGpsLogs(dbHelper);
//     debugPrint('✅ Fake GPS logs synced');
//     Fluttertoast.showToast(
//       msg: "Data sync completed successfully",
//       toastLength: Toast.LENGTH_SHORT,
//       gravity: ToastGravity.BOTTOM,
//       backgroundColor: Colors.green,
//       textColor: Colors.white,
//     );
//     debugPrint('✅ All data sync completed successfully');
//   } catch (e) {
//     debugPrint('❌ Sync error: $e');
//     Fluttertoast.showToast(
//       msg: "Sync failed: $e",
//       toastLength: Toast.LENGTH_SHORT,
//       gravity: ToastGravity.BOTTOM,
//       backgroundColor: Colors.red,
//       textColor: Colors.white,
//     );
//   }
// }
//
// /// Sync unposted orders
// Future<void> _syncUnpostedOrders(DBHelper dbHelper) async {
//   try {
//     final db = await dbHelper.db;
//     final unpostedOrders = await db.query(
//       orderMasterTableName,
//       where: 'posted = ?',
//       whereArgs: [0],
//     );
//     if (unpostedOrders.isEmpty) {
//       debugPrint('📋 No unposted orders found');
//       return;
//     }
//     debugPrint('📦 Found ${unpostedOrders.length} unposted orders');
//     for (var order in unpostedOrders) {
//       final orderId = order['order_master_id'];
//       await db.update(
//         orderMasterTableName,
//         {'posted': 1},
//         where: 'order_master_id = ?',
//         whereArgs: [orderId],
//       );
//       debugPrint('✅ Order synced: $orderId');
//     }
//   } catch (e) {
//     debugPrint('❌ Error syncing orders: $e');
//   }
// }
//
// /// Sync unposted attendance records
// Future<void> _syncUnpostedAttendance(DBHelper dbHelper) async {
//   try {
//     final db = await dbHelper.db;
//     final unpostedAttendanceIn = await db.query(
//       attendanceTableName,
//       where: 'posted = ?',
//       whereArgs: [0],
//     );
//     if (unpostedAttendanceIn.isNotEmpty) {
//       debugPrint('📋 Found ${unpostedAttendanceIn.length} unposted attendance records');
//     }
//     final unpostedAttendanceOut = await db.query(
//       attendanceOutTableName,
//       where: 'posted = ?',
//       whereArgs: [0],
//     );
//     if (unpostedAttendanceOut.isNotEmpty) {
//       debugPrint('📋 Found ${unpostedAttendanceOut.length} unposted attendance out records');
//     }
//   } catch (e) {
//     debugPrint('❌ Error syncing attendance: $e');
//   }
// }
//
// /// Sync unposted shop visits
// Future<void> _syncUnpostedShopVisits(DBHelper dbHelper) async {
//   try {
//     final db = await dbHelper.db;
//     final unpostedVisits = await db.query(
//       shopVisitMasterTableName,
//       where: 'posted = ?',
//       whereArgs: [0],
//     );
//     if (unpostedVisits.isNotEmpty) {
//       debugPrint('📋 Found ${unpostedVisits.length} unposted shop visits');
//     }
//   } catch (e) {
//     debugPrint('❌ Error syncing shop visits: $e');
//   }
// }
//
// /// Sync unposted fake GPS logs
// Future<void> _syncUnpostedFakeGpsLogs(DBHelper dbHelper) async {
//   try {
//     final unpostedLogs = await dbHelper.getUnpostedFakeGpsLogs();
//     if (unpostedLogs.isEmpty) return;
//     debugPrint('🚨 Found ${unpostedLogs.length} unposted fake GPS logs');
//     final ids = unpostedLogs.map((log) => log['id'] as int).toList();
//     await dbHelper.markAllFakeGpsAsPosted(ids);
//     debugPrint('✅ Marked ${ids.length} fake GPS logs as posted');
//   } catch (e) {
//     debugPrint('❌ Error syncing fake GPS logs: $e');
//   }
// }
//
// /// Lazy initialization of background services
// Future<void> _initializeBackgroundServices() async {
//   if (_backgroundServicesInitialized) return;
//   _backgroundServicesInitialized = true;
//
//   debugPrint("🔧 [LAZY] Initializing Location Tracking Service...");
//   try {
//     locationTrackingService = LocationTrackingService();
//     await locationTrackingService.initialize();
//     await locationTrackingService.resumeIfNeeded();
//     debugPrint("✅ [LAZY] Location Tracking Service initialized");
//   } catch (e) {
//     debugPrint("❌ [LAZY] Location Tracking Service error: $e");
//   }
//
//   if (newIsClockedIn) {
//     debugPrint("🔧 [LAZY] Initializing Background Service Location...");
//     try {
//       await initializeServiceLocation();
//       final bgService = FlutterBackgroundService();
//       final isRunning = await bgService.isRunning();
//       if (!isRunning) {
//         await bgService.startService();
//         debugPrint("✅ [LAZY] Background service started");
//       } else {
//         debugPrint("ℹ️ [LAZY] Background service already running");
//       }
//       debugPrint("✅ [LAZY] Background Service Location initialized");
//     } catch (e) {
//       debugPrint("❌ [LAZY] Background Service Location error: $e");
//     }
//   }
// }
//
// // REMOVED: Bubble channel from MyApp
//
// class MyApp extends StatefulWidget {
//   final bool isAuthenticated;
//   const MyApp(this.isAuthenticated, {super.key});
//
//   @override
//   State<MyApp> createState() => _MyAppState();
// }
//
// class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//   }
//
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) async {
//     super.didChangeAppLifecycleState(state);
//     // REMOVED: All bubble-related code
//     // No bubble functionality
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return GetMaterialApp(
//       debugShowCheckedModeBanner: false,
//       initialRoute: widget.isAuthenticated ? pageName : '/CodeScreen',
//       getPages: [
//         GetPage(name: '/', page: () => const SplashScreen()),
//         GetPage(name: '/login', page: () => const LoginScreen()),
//         GetPage(name: '/home', page: () => const HomeScreen()),
//         GetPage(name: '/cameraScreen', page: () => const CameraScreen()),
//         GetPage(name: '/ShopVisitScreen', page: () => const ShopVisitScreen()),
//         GetPage(name: '/OrderBookingScreen', page: () => const OrderBookingScreen()),
//         GetPage(name: '/RecoveryFormScreen', page: () => RecoveryFormScreen()),
//         GetPage(name: '/ReturnFormScreen', page: () => ReturnFormScreen()),
//         GetPage(name: '/NSMHomepage', page: () => const NSMHomepage()),
//         GetPage(name: '/RSMHomepage', page: () => const RSMHomepage()),
//         GetPage(name: '/SMHomepage', page: () => const SMHomepage()),
//         GetPage(name: '/DispatcherHomepage', page: () => const DispatcherHomepage()),
//         GetPage(name: '/CodeScreen', page: () => const CodeScreen()),
//         GetPage(name: '/OrderBookingStatusScreen', page: () => OrderBookingStatusScreen()),
//       ],
//     );
//   }
// }
//
// void requestIgnoreBatteryOptimizations() {
//   if (Platform.isAndroid) {
//     const android_intent.AndroidIntent intent = android_intent.AndroidIntent(
//       action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
//       data: 'package:com.metaxperts.order_booking_app',
//     );
//     intent.launch();
//   }
// }
//
// Future<void> initializeServiceLocation() async {
//   final service = FlutterBackgroundService();
//
//   const AndroidNotificationChannel channel = AndroidNotificationChannel(
//     'my_foreground',
//     'MY FOREGROUND SERVICE',
//     description: 'This channel is used for important notifications.',
//     importance: Importance.low,
//   );
//
//   final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//   FlutterLocalNotificationsPlugin();
//
//   if (Platform.isIOS || Platform.isAndroid) {
//     await flutterLocalNotificationsPlugin.initialize(
//       const InitializationSettings(
//         iOS: DarwinInitializationSettings(),
//         android: AndroidInitializationSettings('ic_bg_service_small'),
//       ),
//     );
//   }
//
//   await flutterLocalNotificationsPlugin
//       .resolvePlatformSpecificImplementation<
//       AndroidFlutterLocalNotificationsPlugin>()
//       ?.createNotificationChannel(channel);
//
//   await service.configure(
//     androidConfiguration: AndroidConfiguration(
//       onStart: onStart,
//       autoStart: false,
//       autoStartOnBoot: false,
//       isForegroundMode: true,
//       notificationChannelId: 'my_foreground',
//       initialNotificationTitle: 'Location Service',
//       initialNotificationContent: 'Tracking location...',
//       foregroundServiceNotificationId: 888,
//     ),
//     iosConfiguration: IosConfiguration(
//       autoStart: false,
//       onForeground: onStart,
//     ),
//   );
// }
//
// // onStart — runs in its OWN isolate
// @pragma('vm:entry-point')
// void onStart(ServiceInstance service) async {
//   // ✅ FIX: Call setAsForegroundService() IMMEDIATELY — before ANY await.
//   // Android kills the app if startForeground() is not called within 5 seconds
//   // of startForegroundService(). Any async work before this call risks that deadline.
//   if (service is AndroidServiceInstance) {
//     service.setAsForegroundService();
//   }
//
//   // Now it is safe to do async initialization
//   DartPluginRegistrant.ensureInitialized();
//
//   if (service is AndroidServiceInstance) {
//     service.on('setAsForeground').listen((_) => service.setAsForegroundService());
//     service.on('setAsBackground').listen((_) => service.setAsBackgroundService());
//   }
//
//   service.on('stopService').listen((_) async {
//     Workmanager().cancelAll();
//     await service.stopSelf();
//     FlutterLocalNotificationsPlugin().cancelAll();
//     debugPrint('🛑 [BG] Service stopped');
//   });
//
//   final prefs = await SharedPreferences.getInstance();
//
//   String bgUserId          = prefs.getString('userId')          ?? '';
//   String bgUserName        = prefs.getString('userName')        ?? '';
//   String bgUserDesignation = prefs.getString('userDesignation') ?? '';
//   String bgCompanyCode     = prefs.getString('companyCode')     ?? 'PK-PUN-SKT-MX01-VT001';
//   bool   bgIsClockedIn     = prefs.getBool('isClockedIn')       ?? false;
//   int    serialCounter     = prefs.getInt('locationSerialCounter')    ?? 1;
//   String lastGeneratedDay  = prefs.getString('lastGeneratedLocationDay') ?? '';
//   String currentMonth      = prefs.getString('currentLocationMonth')     ?? '';
//
//   debugPrint('🚀 [BG onStart] user=$bgUserId | clockedIn=$bgIsClockedIn');
//
//   final repo = LocationTrackingRepository();
//   final dbHelper = DBHelper();
//   Position? lastKnownPosition;
//
//   try {
//     lastKnownPosition = await Geolocator.getLastKnownPosition();
//   } catch (_) {}
//
//   Future<String> generateId() async {
//     final now   = DateTime.now();
//     final mon   = DateFormat('MMM').format(now);
//     final day   = DateFormat('dd').format(now);
//     final today = DateFormat('yyyy-MM-dd').format(now);
//
//     final int? highest = await dbHelper.getHighestLocationSerial(day, mon);
//
//     if (lastGeneratedDay != today) {
//       serialCounter    = highest ?? 1;
//       currentMonth     = mon;
//       lastGeneratedDay = today;
//       await prefs.setString('lastGeneratedLocationDay', today);
//       await prefs.setString('currentLocationMonth', mon);
//     }
//     if (currentMonth != mon) {
//       serialCounter = 1;
//       currentMonth  = mon;
//       await prefs.setString('currentLocationMonth', mon);
//     }
//
//     final id = 'LT-$bgUserId-$day-$mon-${serialCounter.toString().padLeft(3, '0')}';
//     serialCounter++;
//     await prefs.setInt('locationSerialCounter', serialCounter);
//     return id;
//   }
//
//   Future<void> capturePoint() async {
//     final stillClockedIn = prefs.getBool('isClockedIn') ?? false;
//     if (!stillClockedIn) return;
//
//     bgUserId          = prefs.getString('userId')          ?? bgUserId;
//     bgUserName        = prefs.getString('userName')        ?? bgUserName;
//     bgUserDesignation = prefs.getString('userDesignation') ?? bgUserDesignation;
//     bgCompanyCode     = prefs.getString('companyCode')     ?? bgCompanyCode;
//
//     Position? pos;
//     bool usedFallback = false;
//
//     try {
//       pos = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       ).timeout(const Duration(seconds: 3));
//       lastKnownPosition = pos;
//     } on TimeoutException {
//       pos = lastKnownPosition;
//       usedFallback = true;
//       debugPrint('⏱️ [BG] GPS timeout — fallback used');
//     } catch (e) {
//       pos = lastKnownPosition;
//       usedFallback = true;
//       debugPrint('⚠️ [BG] GPS error: $e — fallback used');
//     }
//
//     if (pos == null) {
//       try {
//         pos = await Geolocator.getLastKnownPosition();
//         if (pos != null) {
//           lastKnownPosition = pos;
//           usedFallback = true;
//         }
//       } catch (_) {}
//     }
//
//     if (pos == null) {
//       debugPrint('❌ [BG] No position — tick skipped');
//       return;
//     }
//
//     final now = DateTime.now();
//     final id  = await generateId();
//
//     final rowData = {
//       'locationtracking_id':   id,
//       'locationtracking_date': DateFormat('yyyy-MM-dd').format(now),
//       'locationtracking_time': DateFormat('HH:mm:ss').format(now),
//       'user_id':               bgUserId,
//       'lat_in':                pos.latitude.toString(),
//       'lng_in':                pos.longitude.toString(),
//       'booker_name':           bgUserName,
//       'designation':           bgUserDesignation,
//       'company_code':          bgCompanyCode.isNotEmpty
//           ? bgCompanyCode
//           : 'PK-PUN-SKT-MX01-VT001',
//       'posted': 0,
//     };
//
//     await repo.insertAndSync(rowData);
//     debugPrint('📍 [BG] $id | ${pos.latitude}, ${pos.longitude} | '
//         '${usedFallback ? "⚠️ FALLBACK" : "✅ FRESH"}');
//   }
//
//   if (bgIsClockedIn) {
//     // ── Policy-based exact interval timer ─────────────────────────────────────
//     // 1. Policy SharedPreferences se load karo (Kotlin GpsPolicyManager wahi keys use karta hai)
//     // 2. Anchor-based scheduling: Timer.periodic NAHI — woh drift karta hai
//     //    (kaam karne ka waqt bhi interval mein count ho jaata tha → 15s + 3s GPS = 18s gap)
//     // 3. Sirf 1 record per interval — duplicate saves bilkul nahi
//
//     int bgIntervalSec = prefs.getInt('gps_policy_interval_sec') ?? 60;
//     // Safety: minimum 30s, maximum 300s
//     if (bgIntervalSec < 30) bgIntervalSec = 30;
//     if (bgIntervalSec > 300) bgIntervalSec = 300;
//
//     debugPrint('📋 [BG] Policy interval loaded: ${bgIntervalSec}s');
//
//     // Anchor = jab ye timer shuru hua
//     final DateTime bgAnchor = DateTime.now();
//
//     void scheduleBgTick(void Function() tick) {
//       // Next exact boundary compute karo
//       final now      = DateTime.now();
//       final elapsed  = now.difference(bgAnchor).inMilliseconds;
//       final intervalMs = bgIntervalSec * 1000;
//       final ticksDone  = elapsed ~/ intervalMs;
//       final nextMs     = (ticksDone + 1) * intervalMs;
//       final delayMs    = nextMs - elapsed;
//       final safeDelay  = delayMs > 0 ? delayMs : 200;
//
//       debugPrint('⏱️ [BG] Next tick in ${safeDelay}ms (interval=${bgIntervalSec}s)');
//
//       Future.delayed(Duration(milliseconds: safeDelay), () {
//         tick();
//       });
//     }
//
//     // Self-rescheduling tick function
//     late void Function() bgTick;
//     bgTick = () async {
//       // Policy interval refresh — shayad admin ne change kiya ho
//       await prefs.reload();
//       final updatedInterval = prefs.getInt('gps_policy_interval_sec') ?? bgIntervalSec;
//       if (updatedInterval != bgIntervalSec && updatedInterval >= 30) {
//         bgIntervalSec = updatedInterval;
//         debugPrint('🔄 [BG] Policy interval updated: ${bgIntervalSec}s');
//       }
//
//       // Agle tick schedule karo PEHLE — taake kaam ka waqt interval mein count na ho
//       scheduleBgTick(bgTick);
//
//       final stillClockedIn = prefs.getBool('isClockedIn') ?? false;
//       if (!stillClockedIn) {
//         debugPrint('⏸️ [BG] Not clocked in — skipping tick');
//         return;
//       }
//
//       bgUserId          = prefs.getString('userId')          ?? bgUserId;
//       bgUserName        = prefs.getString('userName')        ?? bgUserName;
//       bgUserDesignation = prefs.getString('userDesignation') ?? bgUserDesignation;
//       bgCompanyCode     = prefs.getString('companyCode')     ?? bgCompanyCode;
//
//       Position? pos;
//       bool usedFallback = false;
//
//       try {
//         pos = await Geolocator.getCurrentPosition(
//           locationSettings: LocationSettings(
//             accuracy: _parseBgAccuracy(prefs.getString('gps_policy_accuracy')),
//             timeLimit: const Duration(seconds: 10),
//           ),
//         );
//         lastKnownPosition = pos;
//       } on TimeoutException {
//         pos = lastKnownPosition;
//         usedFallback = true;
//         debugPrint('⏱️ [BG] GPS timeout — using last known');
//       } catch (e) {
//         pos = lastKnownPosition;
//         usedFallback = true;
//         debugPrint('⚠️ [BG] GPS error: $e — using last known');
//       }
//
//       if (pos == null) {
//         try {
//           pos = await Geolocator.getLastKnownPosition();
//           if (pos != null) usedFallback = true;
//         } catch (_) {}
//       }
//
//       if (pos == null) {
//         debugPrint('❌ [BG] No position — tick skipped');
//         return;
//       }
//
//       final now = DateTime.now();
//       final id  = await generateId();
//
//       final rowData = {
//         'locationtracking_id':   id,
//         'locationtracking_date': DateFormat('yyyy-MM-dd').format(now),
//         'locationtracking_time': DateFormat('HH:mm:ss').format(now),
//         'user_id':               bgUserId,
//         'lat_in':                pos.latitude.toString(),
//         'lng_in':                pos.longitude.toString(),
//         'booker_name':           bgUserName,
//         'designation':           bgUserDesignation,
//         'company_code':          bgCompanyCode.isNotEmpty
//             ? bgCompanyCode
//             : 'PK-PUN-SKT-MX01-VT001',
//         'posted': 0,
//       };
//
//       await repo.insertAndSync(rowData);
//       debugPrint('📍 [BG ${bgIntervalSec}s] $id | ${pos.latitude}, ${pos.longitude} | ${usedFallback ? "⚠️ FALLBACK" : "✅ FRESH"}');
//     };
//
//     // Pehla tick schedule karo
//     scheduleBgTick(bgTick);
//
//     // Sync loop — har interval mein ek baar (location save ke saath hi sync hota hai via insertAndSync,
//     // yeh sirf safety net hai unposted rows ke liye)
//     Timer.periodic(Duration(seconds: bgIntervalSec * 2), (_) async {
//       debugPrint('🔄 [BG] Periodic sync...');
//       await repo.postDataFromDatabaseToAPI();
//     });
//   }
//
//   // ✅ "Working" notification ab Kotlin LocationMonitorService handle karta hai
//   // (setForegroundNotificationInfo yahan se hata diya — Vivo/Oppo/Samsung pe Flutter isolate
//   //  kill hone ke baad notification gayab ho jaati thi — Kotlin foreground service survive karta hai)
//
//   int secondsPassed = 0;
//   String savedTotalTime = prefs.getString('totalWorkTime') ?? '00:00:00';
//   List<String> parts = savedTotalTime.split(':');
//   if (parts.length == 3) {
//     secondsPassed = int.parse(parts[0]) * 3600 +
//         int.parse(parts[1]) * 60 +
//         int.parse(parts[2]);
//   }
//
//   // Timer sirf invoke ke liye — notification update Kotlin karega
//   Timer.periodic(const Duration(seconds: 1), (timer) async {
//     secondsPassed++;
//
//     final deviceInfo = DeviceInfoPlugin();
//     String? device;
//     if (Platform.isAndroid) {
//       final androidInfo = await deviceInfo.androidInfo;
//       device = androidInfo.model;
//     } else if (Platform.isIOS) {
//       final iosInfo = await deviceInfo.iosInfo;
//       device = iosInfo.model;
//     }
//
//     service.invoke('update', {
//       "current_date": DateTime.now().toLocal().toIso8601String(),
//       "device": device,
//       "total_seconds": secondsPassed,
//     });
//   });
// }
//
// String _formatDuration(String secondsString) {
//   int seconds = int.parse(secondsString);
//   Duration duration = Duration(seconds: seconds);
//   String twoDigits(int n) => n.toString().padLeft(2, '0');
//   String hours = twoDigits(duration.inHours);
//   String minutes = twoDigits(duration.inMinutes.remainder(60));
//   String secondsFormatted = twoDigits(duration.inSeconds.remainder(60));
//   return '$hours:$minutes:$secondsFormatted';
// }
//
// // Background service ke liye policy accuracy string → LocationAccuracy
// LocationAccuracy _parseBgAccuracy(String? value) {
//   switch (value?.toLowerCase()) {
//     case 'best':   return LocationAccuracy.best;
//     case 'high':   return LocationAccuracy.high;
//     case 'medium': return LocationAccuracy.medium;
//     case 'low':    return LocationAccuracy.low;
//     case 'lowest': return LocationAccuracy.lowest;
//     default:       return LocationAccuracy.high;
//   }
// }

import 'dart:async';
import 'dart:io';
import 'dart:io' show Directory, InternetAddress, Platform, SocketException;
import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart' show DeviceInfoPlugin;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:order_booking_app/Screens/PermissionScreens/camera_screen.dart';
import 'package:order_booking_app/Screens/code_screen.dart';
import 'package:order_booking_app/Screens/home_screen.dart';
import 'package:order_booking_app/Screens/login_screen.dart';
import 'package:order_booking_app/Screens/order_booking_screen.dart';
import 'package:order_booking_app/Screens/order_booking_status_screen.dart';
import 'package:order_booking_app/Screens/recovery_form_screen.dart';
import 'package:order_booking_app/Screens/return_form_screen.dart';
import 'package:order_booking_app/screens/code_screen.dart' hide CodeScreen;
import 'package:order_booking_app/screens/splash_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'Screens/sync_notification_service.dart';
import 'Databases/dp_helper.dart';
import 'Databases/util.dart';
import 'Screens/Dispatcher/dispatcher_homepage.dart';
import 'Screens/HomeScreenComponents/Bottom_Nav_Bar/bottom_nav_screen.dart';
import 'Screens/NSM/nsm_homepage.dart';
import 'Screens/RSMS_Views/RSM_HomePage.dart';
import 'Screens/SM/sm_homepage.dart';
import 'Screens/shop_visit_screen.dart';
import 'Services/FirebaseServices/firebase_remote_config.dart';
import 'Services/FirebaseServices/firebase_options.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart'
    show AndroidServiceInstance;
import 'package:flutter_background_service/flutter_background_service.dart'
    show
    AndroidConfiguration,
    FlutterBackgroundService,
    IosConfiguration,
    ServiceInstance;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show
    AndroidFlutterLocalNotificationsPlugin,
    AndroidInitializationSettings,
    AndroidNotificationChannel,
    AndroidNotificationDetails,
    DarwinInitializationSettings,
    FlutterLocalNotificationsPlugin,
    Importance,
    InitializationSettings,
    NotificationDetails;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'Tracker/location_tracking_service.dart';
import 'Tracker/fake_gps_logs.dart';
import 'package:order_booking_app/ViewModels/login_view_model.dart';
import 'package:android_intent_plus/android_intent.dart' as android_intent;
import 'package:in_app_update/in_app_update.dart';
import 'ViewModels/location_view_model.dart';
import 'Repositories/location_tracking_repository.dart';

// Global instances
late LocationTrackingService locationTrackingService;

// Flag to track if background services are initialized
bool _backgroundServicesInitialized = false;

// Method channel for sync trigger from notification
const MethodChannel _syncChannel = MethodChannel('com.metaxperts.order_booking_app/sync_channel');

// REMOVED: Bubble channel

Future<void> main() async {
  runZonedGuarded(() async {
    final stopwatch = Stopwatch()..start();
    WidgetsFlutterBinding.ensureInitialized();

    debugPrint("═══════════════════════════════════════════════════════════");
    debugPrint("🚀 APP STARTING - Optimized Cold Start");
    debugPrint("═══════════════════════════════════════════════════════════");

    // STEP 1: Load SharedPreferences FIRST
    debugPrint("📦 Loading SharedPreferences...");
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    debugPrint("✅ SharedPreferences loaded (${stopwatch.elapsedMilliseconds}ms)");

    // STEP 2: Determine authentication state
    bool isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
    pageName = prefs.getString('pageName') ?? '/cameraScreen';
    newIsClockedIn = prefs.getBool('isClockedIn') ?? false;
    user_id = prefs.getString('userId') ?? '';
    userName = prefs.getString('userName') ?? '';
    userCity = prefs.getString('userCity') ?? '';
    userDesignation = prefs.getString('userDesignation') ?? '';
    userBrand = prefs.getString('userBrand') ?? '';
    userSM = prefs.getString('userSM') ?? '';
    userNSM = prefs.getString('userNSM') ?? '';
    userRSM = prefs.getString('userRSM') ?? '';
    userDISPATCHER = prefs.getString('userDISPATCHER') ?? '';
    userNameRSM = prefs.getString('userNameRSM') ?? '';
    userNameNSM = prefs.getString('userNameNSM') ?? '';
    userNameSM = prefs.getString('userNameSM') ?? '';
    userNameDISPATCHER = prefs.getString('userNameDISPATCHER') ?? '';
    companyCode = prefs.getString('companyCode') ?? '';

    debugPrint("👤 Auth state: isAuthenticated=$isAuthenticated, clockedIn=$newIsClockedIn");

    // STEP 3: Initialize Firebase
    debugPrint("🔥 Initializing Firebase...");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("✅ Firebase initialized (${stopwatch.elapsedMilliseconds}ms)");

    // STEP 4: Initialize Config
    debugPrint("⚙️ Initializing Config...");
    await Config.initialize();
    debugPrint("✅ Config initialized (${stopwatch.elapsedMilliseconds}ms)");

    // STEP 5: WorkManager + 15-Minute Sync Notification
    debugPrint("⏰ Initializing Workmanager...");
    await Workmanager().initialize(
      syncNotificationCallbackDispatcher,
      isInDebugMode: false,
    );
    debugPrint("✅ Workmanager initialized");

    // Notification service initialize
    debugPrint("🔔 Initializing Sync Notification Service...");
    await SyncNotificationService.initialize();
    debugPrint("✅ Sync Notification Service initialized");

    // ✅ IMPORTANT: Sirf tab start karein jab user authenticated ho aur clocked in ho
    if (isAuthenticated && newIsClockedIn) {
      debugPrint("✅ User is clocked in - Starting 15-minute sync reminder");
      await SyncNotificationService.requestPermission();
      await SyncNotificationService.startPeriodicSyncReminder();
      debugPrint("✅ 15-minute sync reminder started successfully");
    } else {
      debugPrint("⏸️ User not clocked in - Sync reminder not started");
    }

    // STEP 6: FAKE GPS
    if (isAuthenticated) {
      debugPrint("🚨 [FakeGPS] Starting Fake GPS detection...");
      FakeGpsLog.startConnectivityListener();
      unawaited(FakeGpsLog.syncPending());
      debugPrint("✅ [FakeGPS] Fake GPS detection initialized");
    }

    // STEP 7: GetX Controllers
    Get.put(DBHelper(), permanent: true);
    Get.put(LocationViewModel());

    // STEP 8: Derive correct pageName if needed
    if (isAuthenticated && (pageName.isEmpty || pageName == '/cameraScreen')) {
      switch (userDesignation) {
        case 'RSM':        pageName = '/RSMHomepage'; break;
        case 'SM':         pageName = '/SMHomepage'; break;
        case 'NSM':        pageName = '/NSMHomepage'; break;
        case 'DISPATCHER': pageName = '/DispatcherHomepage'; break;
        default:           pageName = '/home'; break;
      }
    }

    // STEP 9: Setup Method Channel for Sync Trigger
    _setupSyncChannel();

    // ✅ FIX: Battery optimization whitelist
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(seconds: 2));
        requestIgnoreBatteryOptimizations();
      });
    }

    // STEP 10: Start UI immediately
    debugPrint("🎨 Starting UI...");
    runApp(MyApp(isAuthenticated));
    debugPrint("✅ UI rendered (${stopwatch.elapsedMilliseconds}ms)");

    // STEP 11: Launch heavy background services AFTER first frame
    if (isAuthenticated && !_backgroundServicesInitialized && newIsClockedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        debugPrint("🔄 [LAZY] Starting background services...");
        await _initializeBackgroundServices();
        debugPrint("✅ [LAZY] Background services ready");
      });
    }

    debugPrint("═══════════════════════════════════════════════════════════");
    debugPrint("✅ APP START COMPLETE (${stopwatch.elapsedMilliseconds}ms)");
    debugPrint("═══════════════════════════════════════════════════════════");

  }, (error, stackTrace) {
    debugPrint('❌ Error: $error');
    debugPrint('📚 Stack Trace: $stackTrace');
  });
}

/// Setup Method Channel for sync trigger from notification tap
void _setupSyncChannel() {
  _syncChannel.setMethodCallHandler((call) async {
    debugPrint('📱 MethodChannel called: ${call.method}');
    if (call.method == 'triggerSync') {
      debugPrint('🔄 Sync triggered from notification tap!');
      await _performDataSync();
      return true;
    }
    return false;
  });
}

/// Perform data sync when notification is tapped
Future<void> _performDataSync() async {
  debugPrint('🔄 Starting data sync...');
  try {
    final dbHelper = DBHelper();
    final locationRepo = LocationTrackingRepository();
    await locationRepo.postDataFromDatabaseToAPI();
    debugPrint('✅ Location data synced');
    await _syncUnpostedOrders(dbHelper);
    debugPrint('✅ Orders data synced');
    await _syncUnpostedAttendance(dbHelper);
    debugPrint('✅ Attendance data synced');
    await _syncUnpostedShopVisits(dbHelper);
    debugPrint('✅ Shop visits data synced');
    await _syncUnpostedFakeGpsLogs(dbHelper);
    debugPrint('✅ Fake GPS logs synced');
    Fluttertoast.showToast(
      msg: "Data sync completed successfully",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
    debugPrint('✅ All data sync completed successfully');
  } catch (e) {
    debugPrint('❌ Sync error: $e');
    Fluttertoast.showToast(
      msg: "Sync failed: $e",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }
}

/// Sync unposted orders
Future<void> _syncUnpostedOrders(DBHelper dbHelper) async {
  try {
    final db = await dbHelper.db;
    final unpostedOrders = await db.query(
      orderMasterTableName,
      where: 'posted = ?',
      whereArgs: [0],
    );
    if (unpostedOrders.isEmpty) {
      debugPrint('📋 No unposted orders found');
      return;
    }
    debugPrint('📦 Found ${unpostedOrders.length} unposted orders');
    for (var order in unpostedOrders) {
      final orderId = order['order_master_id'];
      await db.update(
        orderMasterTableName,
        {'posted': 1},
        where: 'order_master_id = ?',
        whereArgs: [orderId],
      );
      debugPrint('✅ Order synced: $orderId');
    }
  } catch (e) {
    debugPrint('❌ Error syncing orders: $e');
  }
}

/// Sync unposted attendance records
Future<void> _syncUnpostedAttendance(DBHelper dbHelper) async {
  try {
    final db = await dbHelper.db;
    final unpostedAttendanceIn = await db.query(
      attendanceTableName,
      where: 'posted = ?',
      whereArgs: [0],
    );
    if (unpostedAttendanceIn.isNotEmpty) {
      debugPrint('📋 Found ${unpostedAttendanceIn.length} unposted attendance records');
    }
    final unpostedAttendanceOut = await db.query(
      attendanceOutTableName,
      where: 'posted = ?',
      whereArgs: [0],
    );
    if (unpostedAttendanceOut.isNotEmpty) {
      debugPrint('📋 Found ${unpostedAttendanceOut.length} unposted attendance out records');
    }
  } catch (e) {
    debugPrint('❌ Error syncing attendance: $e');
  }
}

/// Sync unposted shop visits
Future<void> _syncUnpostedShopVisits(DBHelper dbHelper) async {
  try {
    final db = await dbHelper.db;
    final unpostedVisits = await db.query(
      shopVisitMasterTableName,
      where: 'posted = ?',
      whereArgs: [0],
    );
    if (unpostedVisits.isNotEmpty) {
      debugPrint('📋 Found ${unpostedVisits.length} unposted shop visits');
    }
  } catch (e) {
    debugPrint('❌ Error syncing shop visits: $e');
  }
}

/// Sync unposted fake GPS logs
Future<void> _syncUnpostedFakeGpsLogs(DBHelper dbHelper) async {
  try {
    final unpostedLogs = await dbHelper.getUnpostedFakeGpsLogs();
    if (unpostedLogs.isEmpty) return;
    debugPrint('🚨 Found ${unpostedLogs.length} unposted fake GPS logs');
    final ids = unpostedLogs.map((log) => log['id'] as int).toList();
    await dbHelper.markAllFakeGpsAsPosted(ids);
    debugPrint('✅ Marked ${ids.length} fake GPS logs as posted');
  } catch (e) {
    debugPrint('❌ Error syncing fake GPS logs: $e');
  }
}

/// Lazy initialization of background services
Future<void> _initializeBackgroundServices() async {
  if (_backgroundServicesInitialized) return;
  _backgroundServicesInitialized = true;

  debugPrint("🔧 [LAZY] Initializing Location Tracking Service...");
  try {
    locationTrackingService = LocationTrackingService();
    await locationTrackingService.initialize();
    await locationTrackingService.resumeIfNeeded();
    debugPrint("✅ [LAZY] Location Tracking Service initialized");
  } catch (e) {
    debugPrint("❌ [LAZY] Location Tracking Service error: $e");
  }

  if (newIsClockedIn) {
    debugPrint("🔧 [LAZY] Initializing Background Service Location...");
    try {
      await initializeServiceLocation();
      final bgService = FlutterBackgroundService();
      final isRunning = await bgService.isRunning();
      if (!isRunning) {
        await bgService.startService();
        debugPrint("✅ [LAZY] Background service started");
      } else {
        debugPrint("ℹ️ [LAZY] Background service already running");
      }
      debugPrint("✅ [LAZY] Background Service Location initialized");
    } catch (e) {
      debugPrint("❌ [LAZY] Background Service Location error: $e");
    }
  }
}

// REMOVED: Bubble channel from MyApp

class MyApp extends StatefulWidget {
  final bool isAuthenticated;
  const MyApp(this.isAuthenticated, {super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    // REMOVED: All bubble-related code
    // No bubble functionality
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: widget.isAuthenticated ? pageName : '/CodeScreen',
      getPages: [
        GetPage(name: '/', page: () => const SplashScreen()),
        GetPage(name: '/login', page: () => const LoginScreen()),
        GetPage(name: '/home', page: () => const HomeScreen()),
        GetPage(name: '/cameraScreen', page: () => const CameraScreen()),
        GetPage(name: '/ShopVisitScreen', page: () => const ShopVisitScreen()),
        GetPage(name: '/OrderBookingScreen', page: () => const OrderBookingScreen()),
        GetPage(name: '/RecoveryFormScreen', page: () => RecoveryFormScreen()),
        GetPage(name: '/ReturnFormScreen', page: () => ReturnFormScreen()),
        GetPage(name: '/NSMHomepage', page: () => const NSMHomepage()),
        GetPage(name: '/RSMHomepage', page: () => const RSMHomepage()),
        GetPage(name: '/SMHomepage', page: () => const SMHomepage()),
        GetPage(name: '/DispatcherHomepage', page: () => const DispatcherHomepage()),
        GetPage(name: '/CodeScreen', page: () => const CodeScreen()),
        GetPage(name: '/OrderBookingStatusScreen', page: () => OrderBookingStatusScreen()),
      ],
    );
  }
}

void requestIgnoreBatteryOptimizations() {
  if (Platform.isAndroid) {
    const android_intent.AndroidIntent intent = android_intent.AndroidIntent(
      action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
      data: 'package:com.metaxperts.order_booking_app',
    );
    intent.launch();
  }
}

Future<void> initializeServiceLocation() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground',
    'MY FOREGROUND SERVICE',
    description: 'This channel is used for important notifications.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  if (Platform.isIOS || Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        iOS: DarwinInitializationSettings(),
        android: AndroidInitializationSettings('ic_bg_service_small'),
      ),
    );
  }

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'Location Service',
      initialNotificationContent: 'Tracking location...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
    ),
  );
}

// onStart — runs in its OWN isolate
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // ✅ FIX: Call setAsForegroundService() IMMEDIATELY — before ANY await.
  // Android kills the app if startForeground() is not called within 5 seconds
  // of startForegroundService(). Any async work before this call risks that deadline.
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  // Now it is safe to do async initialization
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) => service.setAsForegroundService());
    service.on('setAsBackground').listen((_) => service.setAsBackgroundService());
  }

  service.on('stopService').listen((_) async {
    Workmanager().cancelAll();
    await service.stopSelf();
    FlutterLocalNotificationsPlugin().cancelAll();
    debugPrint('🛑 [BG] Service stopped');
  });

  final prefs = await SharedPreferences.getInstance();

  String bgUserId          = prefs.getString('userId')          ?? '';
  String bgUserName        = prefs.getString('userName')        ?? '';
  String bgUserDesignation = prefs.getString('userDesignation') ?? '';
  String bgCompanyCode     = prefs.getString('companyCode')     ?? 'PK-PUN-SKT-MX01-VT001';
  bool   bgIsClockedIn     = prefs.getBool('isClockedIn')       ?? false;
  int    serialCounter     = prefs.getInt('locationSerialCounter')    ?? 1;
  String lastGeneratedDay  = prefs.getString('lastGeneratedLocationDay') ?? '';
  String currentMonth      = prefs.getString('currentLocationMonth')     ?? '';

  debugPrint('🚀 [BG onStart] user=$bgUserId | clockedIn=$bgIsClockedIn');

  final repo = LocationTrackingRepository();
  final dbHelper = DBHelper();
  Position? lastKnownPosition;

  try {
    lastKnownPosition = await Geolocator.getLastKnownPosition();
  } catch (_) {}

  Future<String> generateId() async {
    final now   = DateTime.now();
    final mon   = DateFormat('MMM').format(now);
    final day   = DateFormat('dd').format(now);
    final today = DateFormat('yyyy-MM-dd').format(now);

    final int? highest = await dbHelper.getHighestLocationSerial(day, mon);

    if (lastGeneratedDay != today) {
      serialCounter    = highest ?? 1;
      currentMonth     = mon;
      lastGeneratedDay = today;
      await prefs.setString('lastGeneratedLocationDay', today);
      await prefs.setString('currentLocationMonth', mon);
    }
    if (currentMonth != mon) {
      serialCounter = 1;
      currentMonth  = mon;
      await prefs.setString('currentLocationMonth', mon);
    }

    final id = 'LT-$bgUserId-$day-$mon-${serialCounter.toString().padLeft(3, '0')}';
    serialCounter++;
    await prefs.setInt('locationSerialCounter', serialCounter);
    return id;
  }

  Future<void> capturePoint() async {
    final stillClockedIn = prefs.getBool('isClockedIn') ?? false;
    if (!stillClockedIn) return;

    bgUserId          = prefs.getString('userId')          ?? bgUserId;
    bgUserName        = prefs.getString('userName')        ?? bgUserName;
    bgUserDesignation = prefs.getString('userDesignation') ?? bgUserDesignation;
    bgCompanyCode     = prefs.getString('companyCode')     ?? bgCompanyCode;

    Position? pos;
    bool usedFallback = false;

    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 3));
      lastKnownPosition = pos;
    } on TimeoutException {
      pos = lastKnownPosition;
      usedFallback = true;
      debugPrint('⏱️ [BG] GPS timeout — fallback used');
    } catch (e) {
      pos = lastKnownPosition;
      usedFallback = true;
      debugPrint('⚠️ [BG] GPS error: $e — fallback used');
    }

    if (pos == null) {
      try {
        pos = await Geolocator.getLastKnownPosition();
        if (pos != null) {
          lastKnownPosition = pos;
          usedFallback = true;
        }
      } catch (_) {}
    }

    if (pos == null) {
      debugPrint('❌ [BG] No position — tick skipped');
      return;
    }

    final now = DateTime.now();
    final id  = await generateId();

    final rowData = {
      'locationtracking_id':   id,
      'locationtracking_date': DateFormat('yyyy-MM-dd').format(now),
      'locationtracking_time': DateFormat('HH:mm:ss').format(now),
      'user_id':               bgUserId,
      'lat_in':                pos.latitude.toString(),
      'lng_in':                pos.longitude.toString(),
      'booker_name':           bgUserName,
      'designation':           bgUserDesignation,
      'company_code':          bgCompanyCode.isNotEmpty
          ? bgCompanyCode
          : 'PK-PUN-SKT-MX01-VT001',
      'posted': 0,
    };

    await repo.insertAndSync(rowData);
    debugPrint('📍 [BG] $id | ${pos.latitude}, ${pos.longitude} | '
        '${usedFallback ? "⚠️ FALLBACK" : "✅ FRESH"}');
  }

  if (bgIsClockedIn) {
    // ── Policy-based exact interval timer ─────────────────────────────────────
    // 1. Policy SharedPreferences se load karo (Kotlin GpsPolicyManager wahi keys use karta hai)
    // 2. Anchor-based scheduling: Timer.periodic NAHI — woh drift karta hai
    //    (kaam karne ka waqt bhi interval mein count ho jaata tha → 15s + 3s GPS = 18s gap)
    // 3. Sirf 1 record per interval — duplicate saves bilkul nahi

    int bgIntervalSec = prefs.getInt('gps_policy_interval_sec') ?? 60;
    // Safety: minimum 30s, maximum 300s
    if (bgIntervalSec < 30) bgIntervalSec = 30;
    if (bgIntervalSec > 300) bgIntervalSec = 300;

    debugPrint('📋 [BG] Policy interval loaded: ${bgIntervalSec}s');

    // Anchor = jab ye timer shuru hua
    final DateTime bgAnchor = DateTime.now();

    void scheduleBgTick(void Function() tick) {
      // Next exact boundary compute karo
      final now      = DateTime.now();
      final elapsed  = now.difference(bgAnchor).inMilliseconds;
      final intervalMs = bgIntervalSec * 1000;
      final ticksDone  = elapsed ~/ intervalMs;
      final nextMs     = (ticksDone + 1) * intervalMs;
      final delayMs    = nextMs - elapsed;
      final safeDelay  = delayMs > 0 ? delayMs : 200;

      debugPrint('⏱️ [BG] Next tick in ${safeDelay}ms (interval=${bgIntervalSec}s)');

      Future.delayed(Duration(milliseconds: safeDelay), () {
        tick();
      });
    }

    // Self-rescheduling tick function
    late void Function() bgTick;
    bgTick = () async {
      // Policy interval refresh — shayad admin ne change kiya ho
      await prefs.reload();
      final updatedInterval = prefs.getInt('gps_policy_interval_sec') ?? bgIntervalSec;
      if (updatedInterval != bgIntervalSec && updatedInterval >= 30) {
        bgIntervalSec = updatedInterval;
        debugPrint('🔄 [BG] Policy interval updated: ${bgIntervalSec}s');
      }

      // Agle tick schedule karo PEHLE — taake kaam ka waqt interval mein count na ho
      scheduleBgTick(bgTick);

      final stillClockedIn = prefs.getBool('isClockedIn') ?? false;
      if (!stillClockedIn) {
        debugPrint('⏸️ [BG] Not clocked in — skipping tick');
        return;
      }

      // ✅ FIX: Agar Kotlin service chal rahi hai toh Flutter loop skip kare.
      // Kotlin LocationMonitorService khud data save aur post karti hai.
      // Jab Kotlin service kill ho jaye tab Flutter automatically fallback karta hai.
      final kotlinIsMaster = prefs.getBool('flutter.kotlin_service_is_master') ?? false;
      if (kotlinIsMaster) {
        debugPrint('⏭️ [BG] Kotlin is master — Flutter tick skipped (no double posting)');
        return;
      }

      bgUserId          = prefs.getString('userId')          ?? bgUserId;
      bgUserName        = prefs.getString('userName')        ?? bgUserName;
      bgUserDesignation = prefs.getString('userDesignation') ?? bgUserDesignation;
      bgCompanyCode     = prefs.getString('companyCode')     ?? bgCompanyCode;

      Position? pos;
      bool usedFallback = false;

      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: _parseBgAccuracy(prefs.getString('gps_policy_accuracy')),
            timeLimit: const Duration(seconds: 10),
          ),
        );
        lastKnownPosition = pos;
      } on TimeoutException {
        pos = lastKnownPosition;
        usedFallback = true;
        debugPrint('⏱️ [BG] GPS timeout — using last known');
      } catch (e) {
        pos = lastKnownPosition;
        usedFallback = true;
        debugPrint('⚠️ [BG] GPS error: $e — using last known');
      }

      if (pos == null) {
        try {
          pos = await Geolocator.getLastKnownPosition();
          if (pos != null) usedFallback = true;
        } catch (_) {}
      }

      if (pos == null) {
        debugPrint('❌ [BG] No position — tick skipped');
        return;
      }

      final now = DateTime.now();
      final id  = await generateId();

      final rowData = {
        'locationtracking_id':   id,
        'locationtracking_date': DateFormat('yyyy-MM-dd').format(now),
        'locationtracking_time': DateFormat('HH:mm:ss').format(now),
        'user_id':               bgUserId,
        'lat_in':                pos.latitude.toString(),
        'lng_in':                pos.longitude.toString(),
        'booker_name':           bgUserName,
        'designation':           bgUserDesignation,
        'company_code':          bgCompanyCode.isNotEmpty
            ? bgCompanyCode
            : 'PK-PUN-SKT-MX01-VT001',
        'posted': 0,
      };

      await repo.insertAndSync(rowData);
      debugPrint('📍 [BG ${bgIntervalSec}s] $id | ${pos.latitude}, ${pos.longitude} | ${usedFallback ? "⚠️ FALLBACK" : "✅ FRESH"}');
    };

    // Pehla tick schedule karo
    scheduleBgTick(bgTick);

    // Sync loop — har interval mein ek baar (location save ke saath hi sync hota hai via insertAndSync,
    // yeh sirf safety net hai unposted rows ke liye)
    Timer.periodic(Duration(seconds: bgIntervalSec * 2), (_) async {
      debugPrint('🔄 [BG] Periodic sync...');
      await repo.postDataFromDatabaseToAPI();
    });
  }

  // ✅ "Working" notification ab Kotlin LocationMonitorService handle karta hai
  // (setForegroundNotificationInfo yahan se hata diya — Vivo/Oppo/Samsung pe Flutter isolate
  //  kill hone ke baad notification gayab ho jaati thi — Kotlin foreground service survive karta hai)

  int secondsPassed = 0;
  String savedTotalTime = prefs.getString('totalWorkTime') ?? '00:00:00';
  List<String> parts = savedTotalTime.split(':');
  if (parts.length == 3) {
    secondsPassed = int.parse(parts[0]) * 3600 +
        int.parse(parts[1]) * 60 +
        int.parse(parts[2]);
  }

  // Timer sirf invoke ke liye — notification update Kotlin karega
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    secondsPassed++;

    final deviceInfo = DeviceInfoPlugin();
    String? device;
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      device = androidInfo.model;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      device = iosInfo.model;
    }

    service.invoke('update', {
      "current_date": DateTime.now().toLocal().toIso8601String(),
      "device": device,
      "total_seconds": secondsPassed,
    });
  });
}

String _formatDuration(String secondsString) {
  int seconds = int.parse(secondsString);
  Duration duration = Duration(seconds: seconds);
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  String hours = twoDigits(duration.inHours);
  String minutes = twoDigits(duration.inMinutes.remainder(60));
  String secondsFormatted = twoDigits(duration.inSeconds.remainder(60));
  return '$hours:$minutes:$secondsFormatted';
}

// Background service ke liye policy accuracy string → LocationAccuracy
LocationAccuracy _parseBgAccuracy(String? value) {
  switch (value?.toLowerCase()) {
    case 'best':   return LocationAccuracy.best;
    case 'high':   return LocationAccuracy.high;
    case 'medium': return LocationAccuracy.medium;
    case 'low':    return LocationAccuracy.low;
    case 'lowest': return LocationAccuracy.lowest;
    default:       return LocationAccuracy.high;
  }
}