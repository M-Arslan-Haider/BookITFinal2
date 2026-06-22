import 'dart:async';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BatteryMonitor {
  static const MethodChannel _channel =
  MethodChannel('com.metaxperts.order_booking_app/battery');

  static Timer? _locationUpdateTimer;

  /// Start battery monitor service (call this on clock-in)
  static Future<void> start() async {
    try {
      await _channel.invokeMethod('startBatteryMonitor');
      _startPeriodicLocationUpdate();
      print('✅ Battery monitor started');
    } catch (e) {
      print('❌ Failed to start battery monitor: $e');
    }
  }

  /// Stop battery monitor service (call this on clock-out)
  static Future<void> stop() async {
    try {
      _locationUpdateTimer?.cancel();
      _locationUpdateTimer = null;
      await _channel.invokeMethod('stopBatteryMonitor');
      print('✅ Battery monitor stopped');
    } catch (e) {
      print('❌ Failed to stop battery monitor: $e');
    }
  }

  /// Check if battery monitor is running
  static Future<bool> isRunning() async {
    try {
      return await _channel.invokeMethod('isBatteryMonitorRunning') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Update last known location to SharedPreferences (for battery service)
  static Future<void> updateLastLocation( Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('flutter.last_latitude', position.latitude.toString());
      await prefs.setString('flutter.last_longitude', position.longitude.toString());

      await _channel.invokeMethod('updateLastLocation', {
        'lat': position.latitude,
        'lng': position.longitude,
      });
    } catch (e) {
      print('⚠️ Failed to update last location: $e');
    }
  }

  /// Periodically update last location (every 30 seconds)
  static void _startPeriodicLocationUpdate() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 30),
          (_) async {
        try {
          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) return;

          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever) return;

          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          await updateLastLocation(position);
        } catch (e) {
          // Silently fail — location will be updated next cycle
        }
      },
    );
  }
}