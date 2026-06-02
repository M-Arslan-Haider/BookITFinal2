
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceTimelogApi {
  static const String _url =
      'https://cloud.metaxperts.net:8443/erp/valor_trading/autotimelogpost/post/';

  // SharedPreferences key jahan pending records list store hogi
  static const String _queueKey = 'timelog_offline_queue';

  // ── Offline queue mein ek record save karo ────────────────────────────────
  static Future<void> _saveToOfflineQueue(Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> queue = prefs.getStringList(_queueKey) ?? [];
      queue.add(jsonEncode(payload));
      await prefs.setStringList(_queueKey, queue);
      debugPrint('💾 [TIMELOG API] Saved to offline queue. Total pending: ${queue.length}');
    } catch (e) {
      debugPrint('❌ [TIMELOG API] Queue save error: $e');
    }
  }

  // ── Pending queue ko server pe sync karo ─────────────────────────────────
  static Future<void> syncOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> queue = prefs.getStringList(_queueKey) ?? [];

      if (queue.isEmpty) {
        debugPrint('✅ [TIMELOG SYNC] No pending records.');
        return;
      }

      debugPrint('🔄 [TIMELOG SYNC] Syncing ${queue.length} pending record(s)...');

      final List<String> failedItems = []; // jo post na ho saka woh rakhenge

      for (final item in queue) {
        try {
          final Map<String, dynamic> payload = jsonDecode(item);

          debugPrint('📤 [TIMELOG SYNC] Posting: $payload');

          final response = await http.post(
            Uri.parse(_url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          ).timeout(const Duration(seconds: 30));

          if (response.statusCode >= 200 && response.statusCode < 300) {
            debugPrint('✅ [TIMELOG SYNC] Posted successfully: ${payload['phone_time']}');
            // success — failedItems mein nahi daala, queue se hat jayega
          } else {
            debugPrint('⚠️ [TIMELOG SYNC] Server error ${response.statusCode} — will retry later');
            failedItems.add(item); // retry baad mein
          }
        } catch (e) {
          debugPrint('❌ [TIMELOG SYNC] Network error — will retry later: $e');
          failedItems.add(item); // abhi bhi offline, retry baad mein
        }
      }

      // Sirf failed items wapas queue mein rakho
      await prefs.setStringList(_queueKey, failedItems);

      final int synced = queue.length - failedItems.length;
      debugPrint('✅ [TIMELOG SYNC] Done. Synced: $synced, Still pending: ${failedItems.length}');
    } catch (e) {
      debugPrint('❌ [TIMELOG SYNC] Unexpected error: $e');
    }
  }

  // ── Pending count check (optional UI ke liye) ─────────────────────────────
  static Future<int> getPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_queueKey) ?? []).length;
  }

  // ── POST Clock-In ──────────────────────────────────────────────────────────
  static Future<AttendanceTimelogResult> postClockIn({
    required String userId,
    required String bookerName,
    required String designation,
    required String companyCode,
    required bool autoTimeEnabled,
    DateTime? clockInTime,
  }) async {
    final DateTime now = clockInTime ?? DateTime.now();
    final String phoneTime = DateFormat('dd-MMM-yyyy HH:mm:ss').format(now);
    final String autoTimeStr = autoTimeEnabled ? 'true' : 'false';

    final Map<String, dynamic> body = {
      'user_id':           userId,
      'booker_name':       bookerName,
      'designation':       designation,
      'company_code':      companyCode,
      'auto_time_enabled': autoTimeStr,
      'phone_time':        phoneTime,
    };

    debugPrint('📤 [TIMELOG API] POST → $_url');
    debugPrint('📤 [TIMELOG API] Payload → ${jsonEncode(body)}');

    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      debugPrint('📥 [TIMELOG API] Status  : ${response.statusCode}');
      debugPrint('📥 [TIMELOG API] Response: ${response.body}');

      final bool ok = response.statusCode >= 200 && response.statusCode < 300;

      return AttendanceTimelogResult(
        success:    ok,
        statusCode: response.statusCode,
        message:    ok
            ? 'Clock-in posted successfully.'
            : 'Server error ${response.statusCode}: ${response.body}',
        rawBody:    response.body,
        savedOffline: false,
      );
    } on http.ClientException catch (e) {
      // ✅ Offline — queue mein save karo
      debugPrint('📶 [TIMELOG API] Offline — saving to queue: $e');
      await _saveToOfflineQueue(body);
      return AttendanceTimelogResult(
        success:      false,
        statusCode:   0,
        message:      'Offline — saved to queue for later sync.',
        rawBody:      '',
        savedOffline: true,
      );
    } catch (e) {
      // ✅ Any other error — queue mein save karo
      debugPrint('❌ [TIMELOG API] Exception — saving to queue: $e');
      await _saveToOfflineQueue(body);
      return AttendanceTimelogResult(
        success:      false,
        statusCode:   0,
        message:      'Error — saved to queue: $e',
        rawBody:      '',
        savedOffline: true,
      );
    }
  }
}

// ── Result model ──────────────────────────────────────────────────────────────
class AttendanceTimelogResult {
  final bool   success;
  final int    statusCode;
  final String message;
  final String rawBody;
  final bool   savedOffline; // ✅ NEW: pata chale ke queue mein gaya

  const AttendanceTimelogResult({
    required this.success,
    required this.statusCode,
    required this.message,
    required this.rawBody,
    this.savedOffline = false,
  });

  @override
  String toString() =>
      'AttendanceTimelogResult(success=$success, '
          'status=$statusCode, savedOffline=$savedOffline, message=$message)';
}