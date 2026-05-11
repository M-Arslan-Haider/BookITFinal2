// // lib/Screens/clockout_alarm_service.dart
// //
// // ══════════════════════════════════════════════════════════════════════════════
// // ClockoutAlarmService — Flutter Side
// //
// // KYA KARTA HAI:
// //   ✅ Clock-IN hone par → Kotlin ko bol do ke kal 8 PM alarm set karo
// //   ✅ Clock-OUT hone par → Kotlin ko bol do ke sab kuch band karo
// //   ✅ App open hone par bhi check karta hai (agar 8 PM guzar gayi)
// //   ✅ Flutter timer bhi rakhta hai app-open state ke liye
// //
// // USAGE:
// //   ClockIn  → await ClockoutAlarmService.onClockIn();
// //   ClockOut → await ClockoutAlarmService.onClockOut();
// //   main()   → await ClockoutAlarmService.initialize();
// // ══════════════════════════════════════════════════════════════════════════════
//
// import 'dart:async';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// // ─── MethodChannel — Flutter → Kotlin ────────────────────────────────────────
// const _clockoutAlarmChannel = MethodChannel(
//   'com.metaxperts.order_booking_app/clockout_alarm',
// );
//
// class ClockoutAlarmService {
//   ClockoutAlarmService._();
//
//   // Foreground check timer (app open hone par har minute check karo)
//   static Timer? _checkTimer;
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // INITIALIZE — main() mein call karo, runApp se pehle
//   // ─────────────────────────────────────────────────────────────────────────
//   static Future<void> initialize() async {
//     debugPrint('✅ ClockoutAlarmService initialized');
//
//     // App open hone par check karo: agar clocked in hai aur 8 PM guzar gayi
//     await _checkOnAppStart();
//
//     // Foreground timer: har minute check karo 8 PM cross hua ya nahi
//     _startForegroundCheckTimer();
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // CLOCK-IN hone par yeh call karo
//   // ─────────────────────────────────────────────────────────────────────────
//   static Future<void> onClockIn() async {
//     debugPrint('⏰ [ClockoutAlarm] ClockIn — scheduling 8PM alarm...');
//
//     if (!Platform.isAndroid) return;
//
//     try {
//       await _clockoutAlarmChannel.invokeMethod('schedule8PMAlarm');
//       debugPrint('✅ [ClockoutAlarm] 8PM alarm scheduled via Kotlin');
//     } catch (e) {
//       debugPrint('⚠️ [ClockoutAlarm] schedule error: $e');
//     }
//
//     // Foreground timer bhi shuru karo
//     _startForegroundCheckTimer();
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // CLOCK-OUT hone par yeh call karo — sab kuch band hoga
//   // ─────────────────────────────────────────────────────────────────────────
//   static Future<void> onClockOut() async {
//     debugPrint('🛑 [ClockoutAlarm] ClockOut — stopping everything...');
//
//     // Foreground timer band karo
//     _checkTimer?.cancel();
//     _checkTimer = null;
//
//     if (!Platform.isAndroid) return;
//
//     try {
//       // Kotlin side: alarm + ringtone service + notification sab band
//       await _clockoutAlarmChannel.invokeMethod('stopEverything');
//       debugPrint('✅ [ClockoutAlarm] All stopped via Kotlin');
//     } catch (e) {
//       debugPrint('⚠️ [ClockoutAlarm] stop error: $e');
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // App open hone par check: clocked in hai + 8 PM guzar gayi = immediately ring
//   // ─────────────────────────────────────────────────────────────────────────
//   static Future<void> _checkOnAppStart() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final isClockedIn = prefs.getBool('isClockedIn') ?? false;
//
//       if (!isClockedIn) return;
//
//       final now = DateTime.now();
//       final is8PMPassed = now.hour >= 20; // 8 PM = 20:00
//
//       if (is8PMPassed && Platform.isAndroid) {
//         debugPrint('⚠️ [ClockoutAlarm] App opened after 8PM and still clocked in!');
//         // Kotlin se ringtone shuru karo
//         try {
//           await _clockoutAlarmChannel.invokeMethod('startRingtoneNow');
//           debugPrint('✅ [ClockoutAlarm] Ringtone started immediately');
//         } catch (e) {
//           debugPrint('⚠️ [ClockoutAlarm] Ringtone start error: $e');
//         }
//       }
//     } catch (e) {
//       debugPrint('⚠️ [ClockoutAlarm] checkOnAppStart error: $e');
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // Foreground timer: 8 PM cross hone par immediately flutter side se bhi trigger
//   // ─────────────────────────────────────────────────────────────────────────
//   static void _startForegroundCheckTimer() {
//     _checkTimer?.cancel();
//
//     _checkTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
//       try {
//         final prefs = await SharedPreferences.getInstance();
//         final isClockedIn = prefs.getBool('isClockedIn') ?? false;
//
//         if (!isClockedIn) {
//           _checkTimer?.cancel();
//           _checkTimer = null;
//           debugPrint('⏸️ [ClockoutAlarm] Not clocked in — foreground timer stopped');
//           return;
//         }
//
//         final now = DateTime.now();
//         // Exactly 8 PM (hour == 20, minute == 0) ya phir already past
//         if (now.hour == 20 && now.minute == 0) {
//           debugPrint('🔔 [ClockoutAlarm] 8PM reached! Triggering from Flutter foreground timer');
//           if (Platform.isAndroid) {
//             try {
//               await _clockoutAlarmChannel.invokeMethod('startRingtoneNow');
//             } catch (e) {
//               debugPrint('⚠️ $e');
//             }
//           }
//         }
//       } catch (e) {
//         debugPrint('⚠️ [ClockoutAlarm] timer check error: $e');
//       }
//     });
//
//     debugPrint('✅ [ClockoutAlarm] Foreground check timer started');
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // Manual test ke liye — sirf debug mein use karo
//   // ─────────────────────────────────────────────────────────────────────────
//   static Future<void> testRingNow() async {
//     debugPrint('🧪 [ClockoutAlarm] TEST: Starting ringtone now');
//     if (Platform.isAndroid) {
//       try {
//         await _clockoutAlarmChannel.invokeMethod('startRingtoneNow');
//       } catch (e) {
//         debugPrint('⚠️ $e');
//       }
//     }
//   }
// }