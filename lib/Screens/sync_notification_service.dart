// lib/Screens/sync_notification_service.dart
//
// ✅ FINAL SOLUTION:
//   App open   → dart:async Timer (exact 15 min)
//   App bg/kill → AlarmManager via Kotlin (exact 15 min, phone off par bhi)
//   Screen popup → Full Screen Intent notification (Kotlin side)
//   ClockOut   → Sab kuch band

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── WorkManager task names ───────────────────────────────────────────────────
const String kSyncReminderTask     = 'syncReminderTask';
const String kSyncReminderTaskName = 'periodicSyncReminder';

// ─── MethodChannel — Flutter → Kotlin alarm control ──────────────────────────
const _alarmChannel = MethodChannel('com.metaxperts.order_booking_app/sync_alarm');

// ─── WorkManager background callback ─────────────────────────────────────────
@pragma('vm:entry-point')
void syncNotificationCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    DartPluginRegistrant.ensureInitialized();
    debugPrint('⚙️ [WorkManager] Task: $task');

    if (task == kSyncReminderTask) {
      try {
        final prefs       = await SharedPreferences.getInstance();
        final isClockedIn = prefs.getBool('isClockedIn') ?? false;

        if (isClockedIn) {
          await SyncNotificationService.showNotificationFromBackground();
          debugPrint('✅ [WorkManager] Notification shown');
        } else {
          await Workmanager().cancelByUniqueName(kSyncReminderTaskName);
          debugPrint('⏸️ [WorkManager] Not clocked in — cancelled');
        }
      } catch (e) {
        debugPrint('❌ [WorkManager] Error: $e');
      }
    }
    return Future.value(true);
  });
}

// ─────────────────────────────────────────────────────────────────────────────
class SyncNotificationService {
  SyncNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static const int    _notifId     = 8877;
  static const String _channelId   = 'sync_reminder_channel';
  static const String _channelName = 'Data Sync Reminder';

  // Foreground-only timer (when app is open)
  static Timer? _foregroundTimer;

  // ─────────────────────────────────────────────────────────────────────────
  // INITIALIZE — call once in main() before runApp
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> initialize() async {
    await _createChannels();

    const AndroidInitializationSettings android =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse:           _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onNotificationTapBackground,
    );

    debugPrint('✅ SyncNotificationService initialized');
  }

  static Future<void> _createChannels() async {
    if (!Platform.isAndroid) return;

    const AndroidNotificationChannel ch = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'ہر 15 منٹ بعد ڈیٹا سنک کی یاددہانی',
      importance: Importance.high,
      playSound:       true,
      enableVibration: true,
      showBadge:       true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(ch);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REQUEST PERMISSION
  // ─────────────────────────────────────────────────────────────────────────
  static Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null && await android.areNotificationsEnabled() == false) {
      await android.requestNotificationsPermission();
    }
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ✅ START — Call on CLOCK-IN
  //   1. Kotlin AlarmManager → app kill/bg par bhi kaam karta hai (popup bhi)
  //   2. WorkManager          → backup (OS manage karta hai)
  //   3. Dart Timer           → app open hone par exact 15 min
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> startPeriodicSyncReminder() async {
    debugPrint('⏰ [SyncReminder] Starting...');

    await requestPermission();

    // 1️⃣ Kotlin AlarmManager (most reliable — app kill par bhi)
    await _startKotlinAlarm();

    // 2️⃣ WorkManager (backup)
    await _startWorkManager();

    // 3️⃣ Dart foreground timer (app open par exact timing)
    _startForegroundTimer();

    debugPrint('✅ [SyncReminder] All 3 methods started');
  }

  // ─── Kotlin AlarmManager via MethodChannel ────────────────────────────────
  static Future<void> _startKotlinAlarm() async {
    try {
      await _alarmChannel.invokeMethod('startAlarm');
      debugPrint('✅ [KotlinAlarm] Started');
    } catch (e) {
      debugPrint('⚠️ [KotlinAlarm] Error: $e');
    }
  }

  static Future<void> _stopKotlinAlarm() async {
    try {
      await _alarmChannel.invokeMethod('stopAlarm');
      debugPrint('🛑 [KotlinAlarm] Stopped');
    } catch (e) {
      debugPrint('⚠️ [KotlinAlarm] Error: $e');
    }
  }

  // ─── WorkManager ──────────────────────────────────────────────────────────
  static Future<void> _startWorkManager() async {
    await Workmanager().cancelByUniqueName(kSyncReminderTaskName);

    await Workmanager().registerPeriodicTask(
      kSyncReminderTaskName,
      kSyncReminderTask,
      frequency:    const Duration(minutes: 15),
      initialDelay: const Duration(minutes: 15),
      constraints: Constraints(
        networkType:           NetworkType.notRequired,
        requiresBatteryNotLow: false,
        requiresCharging:      false,
        requiresDeviceIdle:    false,
        requiresStorageNotLow: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      backoffPolicy:      BackoffPolicy.linear,
    );
    debugPrint('✅ [WorkManager] Registered');
  }

  // ─── Dart foreground timer ────────────────────────────────────────────────
  static void _startForegroundTimer() {
    _foregroundTimer?.cancel();

    _foregroundTimer = Timer.periodic(const Duration(minutes: 15), (_) async {
      final prefs       = await SharedPreferences.getInstance();
      final isClockedIn = prefs.getBool('isClockedIn') ?? false;

      if (isClockedIn) {
        debugPrint('🔔 [ForegroundTimer] Showing notification');
        await showImmediateNotification();
      } else {
        _foregroundTimer?.cancel();
        _foregroundTimer = null;
        debugPrint('⏸️ [ForegroundTimer] Stopped');
      }
    });

    debugPrint('✅ [ForegroundTimer] Started');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ✅ STOP — Call on CLOCK-OUT
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> stopPeriodicSyncReminder() async {
    debugPrint('🛑 [SyncReminder] Stopping all...');

    await _stopKotlinAlarm();
    await Workmanager().cancelByUniqueName(kSyncReminderTaskName);
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    await _plugin.cancel(_notifId);

    debugPrint('🛑 [SyncReminder] All stopped');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHOW NOTIFICATION
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> showImmediateNotification() async {
    await _showNotification(
      title: '⏰ ڈیٹا سنک کریں',
      body:  'اپنی BookIT ایپلیکیشن کھولیں اور ڈیٹا سنک کریں',
    );
  }

  static Future<void> _showNotification({
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      _notifId, title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: 'ہر 15 منٹ بعد ڈیٹا سنک کی یاددہانی',
          importance:       Importance.high,
          priority:         Priority.high,
          playSound:        true,
          enableVibration:  true,
          autoCancel:       true,
          icon:             '@mipmap/ic_launcher',
          styleInformation: const BigTextStyleInformation(
            'براہ کرم اپنی BookIT ایپلیکیشن کھولیں اور ڈیٹا سنک کریں تاکہ آپ کا کام محفوظ رہے۔',
            contentTitle: '⏰ ڈیٹا سنک کریں - BookIT',
            summaryText:  'ہر 15 منٹ بعد سنک کریں',
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
        ),
      ),
      payload: 'sync_reminder',
    );
    debugPrint('🔔 [Flutter] Notification shown');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Background (WorkManager) notification
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> showNotificationFromBackground() async {
    await _createChannels();
    const AndroidInitializationSettings android =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse:           _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onNotificationTapBackground,
    );
    await _showNotification(
      title: '⏰ ڈیٹا سنک کریں',
      body:  'BookIT ایپ کھولیں اور ڈیٹا سنک کریں',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tap handlers
  // ─────────────────────────────────────────────────────────────────────────
  @pragma('vm:entry-point')
  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
  }

  @pragma('vm:entry-point')
  static void _onNotificationTapBackground(NotificationResponse response) {
    debugPrint('🔔 BG Notification tapped: ${response.payload}');
  }
}