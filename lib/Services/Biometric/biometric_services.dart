// lib/Services/Biometric/biometric_services.dart

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  // ── SharedPreferences keys ────────────────────────────────────────────────
  static const String _keyEnabled  = 'biometric_enabled';
  static const String _keyUserId   = 'biometric_user_id';
  static const String _keyUserName = 'biometric_user_name';

  // ── Availability ──────────────────────────────────────────────────────────

  /// FIX 1: Run all 3 platform-bridge calls in PARALLEL with Future.wait.
  /// Previously they were sequential → ~3× slower on cold check.
  Future<bool> isAvailable() async {
    try {
      // All three calls fired at the same time — total wait = slowest one, not sum.
      final results = await Future.wait([
        _auth.canCheckBiometrics,
        _auth.isDeviceSupported(),
        _auth.getAvailableBiometrics(),
      ]);

      final bool canCheck    = results[0] as bool;
      final bool isSupported = results[1] as bool;
      final List<BiometricType> available =
      results[2] as List<BiometricType>;

      return canCheck && isSupported && available.isNotEmpty;
    } on PlatformException catch (e) {
      debugBiometric('⚠️ BiometricService.isAvailable error: $e');
      return false;
    }
  }

  // ── Enabled state (per user) ───────────────────────────────────────────────

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  Future<String> registeredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId) ?? '';
  }

  Future<String> registeredUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName) ?? '';
  }

  Future<bool> enable(String userId, String userName) async {
    final authenticated = await _promptAuth(
      reason: 'Scan your fingerprint to enable biometric login',
    );
    if (!authenticated) return false;

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool(_keyEnabled, true),
      prefs.setString(_keyUserId, userId),
      prefs.setString(_keyUserName, userName),
    ]);
    return true;
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool(_keyEnabled, false),
      prefs.remove(_keyUserId),
      prefs.remove(_keyUserName),
    ]);
  }

  // ── Authentication ─────────────────────────────────────────────────────────

  Future<bool> authenticate() async {
    return _promptAuth(reason: 'Scan your fingerprint to log in');
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<bool> _promptAuth({required String reason}) async {
    try {
      return await _auth.authenticate(localizedReason: reason);
    } on PlatformException catch (e) {
      debugBiometric('⚠️ BiometricService._promptAuth error: $e');
      return false;
    }
  }

  void debugBiometric(String msg) {
    // ignore: avoid_print
    print(msg);
  }
}