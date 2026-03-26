//
// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'dart:math';
// import 'package:flutter/services.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:get/get.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:gpx/gpx.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:order_booking_app/Repositories/location_services_repository.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:synchronized/synchronized.dart';
// import '../Databases/util.dart';
// import '../Models/location_model.dart';
// import '../Repositories/location_repository.dart';
// import 'package:geocoding/geocoding.dart';
// import '../Services/FirebaseServices/firebase_remote_config.dart';
// import '../Tracker/trac.dart';
//
// class LocationViewModel extends GetxController {
//   var allLocation = <LocationModel>[].obs;
//   LocationRepository locationRepository = LocationRepository();
//   var globalLatitude1 = 0.0.obs;
//   var globalLongitude1 = 0.0.obs;
//   var shopAddress = ''.obs;
//
//   var lastProcessedDate = ''.obs;
//   var isDailyProcessingComplete = false.obs;
//
//   RxInt secondsPassed = 0.obs;
//   Timer? _timer;
//   RxBool isClockedIn = false.obs;
//
//   // 🔥 YAHAN ADD KARO
//   bool _isAutoSyncing = false;
//   bool _isGpxAutoSyncing = false;
//   Timer? _gpxSyncTimer;
//
//   var isGPSEnabled = false.obs;
//   var newsecondpassed = 0.obs;
//   int locationSerialCounter = 1;
//   String locationCurrentMonth = DateFormat('MMM').format(DateTime.now());
//   String currentuser_id = '';
//
//   // ✅ ADDED: File read lock to coordinate with LocationService
//   final Lock _fileReadLock = Lock();
//
//   // ✅ ADDED: Cache for frequently accessed data
//   double? _cachedDistance;
//   DateTime? _lastDistanceCalculation;
//   static const Duration _distanceCacheValidity = Duration(seconds: 5);
//
//   @override
//   void onInit() {
//     super.onInit();
//     fetchAllLocation();
//     loadClockStatus();
//     startTimerIfClockedIn();
//     _initializeDailyProcessing();
//     // 🔥 NEW: Auto sync when app opens
//     // 🔥 AUTO SYNC GPX
//     Future.delayed(const Duration(seconds: 3), () {
//       _startGpxAutoSync();
//     });
//
//   }
//
//   @override
//   void dispose() {
//     _timer?.cancel();
//     super.dispose();
//   }
//
//   // ----------------------
//   // Timer Logic
//   // ----------------------
//   void startTimerIfClockedIn() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     isClockedIn.value = prefs.getBool('isClockedIn') ?? false;
//     if (isClockedIn.value) {
//       secondsPassed.value = prefs.getInt('secondsPassed') ?? 0;
//       _timer?.cancel();
//       _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
//         secondsPassed.value++;
//         _saveSecondsToPrefs(secondsPassed.value);
//       });
//     }
//   }
//
//   void startTimer() async {
//     _timer?.cancel();
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     secondsPassed.value = prefs.getInt('secondsPassed') ?? 0;
//     _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
//       secondsPassed.value++;
//       _saveSecondsToPrefs(secondsPassed.value);
//     });
//   }
//
//   void _saveSecondsToPrefs(int seconds) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     await prefs.setInt('secondsPassed', seconds);
//   }
//
//   Future<String> stopTimer() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     _timer?.cancel();
//
//     String totalTime = _formatDuration(secondsPassed.value);
//
//     secondsPassed.value = 0;
//     newsecondpassed.value = 0;
//
//     await prefs.setInt('secondsPassed', 0);
//     await prefs.setString('totalTime', totalTime);
//
//     return totalTime;
//   }
//
//   String _formatDuration(int seconds) {
//     Duration duration = Duration(seconds: seconds);
//     String twoDigits(int n) => n.toString().padLeft(2, '0');
//     String hours = twoDigits(duration.inHours);
//     String minutes = twoDigits(duration.inMinutes.remainder(60));
//     String secs = twoDigits(duration.inSeconds.remainder(60));
//     return '$hours:$minutes:$secs';
//   }
//
//   // ----------------------
//   // Daily GPX File Management
//   // ----------------------
//
//   String getDailyGPXFileName() {
//     final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
//     return 'track$date.gpx';
//   }
//
//   Future<String> getCurrentGPXFilePath() async {
//     final downloadDirectory = await getDownloadsDirectory();
//     return '${downloadDirectory!.path}/${getDailyGPXFileName()}';
//   }
//
//   // ✅ FIXED: With synchronization and caching
//   Future<double> getImmediateDistance() async {
//     try {
//       // Return cached value if recent
//       if (_cachedDistance != null &&
//           _lastDistanceCalculation != null &&
//           DateTime.now().difference(_lastDistanceCalculation!) < _distanceCacheValidity) {
//         debugPrint("📏 Returning cached distance: $_cachedDistance km");
//         return _cachedDistance!;
//       }
//
//       final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
//       final downloadDirectory = await getDownloadsDirectory();
//       final filePath = "${downloadDirectory!.path}/track_${user_id}_$date.gpx";
//
//       File file = File(filePath);
//
//       // ✅ Use async check instead of sync
//       bool exists = await file.exists();
//       if (!exists) {
//         return 0.0;
//       }
//
//       // ✅ CRITICAL: Use lock to prevent reading during write
//       double distance = await _fileReadLock.synchronized(() async {
//         return await calculateTotalDistance(filePath);
//       });
//
//       // ✅ Update cache
//       _cachedDistance = distance;
//       _lastDistanceCalculation = DateTime.now();
//
//       return distance;
//     } catch (e) {
//       debugPrint("❌ Error getting immediate distance: $e");
//       return 0.0;
//     }
//   }
//
//   // ✅ FIXED: All async operations, no sync calls
//   Future<Map<String, dynamic>> checkLocationServiceStatus() async {
//     try {
//       final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
//       final downloadDirectory = await getDownloadsDirectory();
//       final filePath = "${downloadDirectory!.path}/track_${user_id}_$date.gpx";
//
//       File file = File(filePath);
//
//       // ✅ Async operations only
//       bool fileExists = await file.exists();
//       int fileSize = fileExists ? await file.length() : 0;
//       int pointCount = 0;
//
//       if (fileExists) {
//         // ✅ Use lock when reading
//         String content = await _fileReadLock.synchronized(() async {
//           return await file.readAsString();
//         });
//
//         if (content.isNotEmpty) {
//           Gpx gpx = GpxReader().fromString(content);
//           pointCount = _getTotalPoints(gpx);
//         }
//       }
//
//       return {
//         'serviceActive': true,
//         'fileExists': fileExists,
//         'fileSize': fileSize,
//         'pointsRecorded': pointCount,
//         'filePath': filePath,
//       };
//     } catch (e) {
//       return {
//         'serviceActive': false,
//         'error': e.toString(),
//       };
//     }
//   }
//
//   int _getTotalPoints(Gpx gpx) {
//     int total = 0;
//     for (var track in gpx.trks) {
//       for (var segment in track.trksegs) {
//         total += segment.trkpts.length;
//       }
//     }
//     return total;
//   }
//
//   // ✅ HELPER METHOD: Check if point already exists in list (MOVED HERE to fix error)
//   bool _containsPoint(List<Wpt> points, Wpt newPoint) {
//     for (Wpt point in points) {
//       if (point.lat == newPoint.lat &&
//           point.lon == newPoint.lon &&
//           point.time == newPoint.time) {
//         return true;
//       }
//     }
//     return false;
//   }
//
//   // ----------------------
//   // ✅ NEW: Date-specific GPX Methods for Midnight Auto-Clockout Fix
//   // ----------------------
//
//   // ✅ NEW: Get GPX file path for specific date (not current date)
//   Future<String> getGPXFilePathForDate(DateTime date) async {
//     final dateStr = DateFormat('dd-MM-yyyy').format(date);
//     final downloadDirectory = await getDownloadsDirectory();
//     return "${downloadDirectory!.path}/track_${user_id}_$dateStr.gpx";
//   }
//
//   // ✅ NEW: Consolidate GPX for specific date (CRITICAL FIX for midnight auto-clockout)
//   Future<void> consolidateDailyGPXDataForDate(DateTime eventDate) async {
//     try {
//       final dateStr = DateFormat('dd-MM-yyyy').format(eventDate);
//       final downloadDirectory = await getDownloadsDirectory();
//       final dailyGPXFilePath = '${downloadDirectory!.path}/track$dateStr.gpx';
//
//       debugPrint("🔄 [DATE-SPECIFIC] Starting Daily GPX Consolidation for: $dateStr");
//       debugPrint("🔄 [DATE-SPECIFIC] File path: $dailyGPXFilePath");
//
//       // ✅ Use lock for entire consolidation process
//       await _fileReadLock.synchronized(() async {
//         File dailyFile = File(dailyGPXFilePath);
//
//         if (!await dailyFile.exists()) {
//           debugPrint("📄 [DATE-SPECIFIC] Daily file doesn't exist, creating new one");
//           String initialGPX = '''<?xml version="1.0" encoding="UTF-8"?>
// <gpx version="1.1" creator="OrderBookingApp">
//   <trk>
//     <name>Daily Track $dateStr</name>
//     <trkseg>
//     </trkseg>
//   </trk>
// </gpx>''';
//
//           await dailyFile.writeAsString(initialGPX, flush: true);
//         }
//
//         String dailyContent = await dailyFile.readAsString();
//         Gpx dailyGpx = GpxReader().fromString(dailyContent);
//
//         if (dailyGpx.trks.isEmpty) {
//           dailyGpx.trks.add(Trk());
//         }
//         if (dailyGpx.trks.first.trksegs.isEmpty) {
//           dailyGpx.trks.first.trksegs.add(Trkseg());
//         }
//
//         Trkseg mainSegment = dailyGpx.trks.first.trksegs.first;
//         int initialPoints = mainSegment.trkpts.length;
//
//         debugPrint("📊 [DATE-SPECIFIC] Initial points in daily file: $initialPoints");
//
//         List<File> allGPXFiles = await _findAllGPXFilesForDate(downloadDirectory, dateStr);
//         debugPrint("📁 [DATE-SPECIFIC] Found ${allGPXFiles.length} GPX files for date: $dateStr");
//
//         int totalMergedPoints = 0;
//
//         for (File tempFile in allGPXFiles) {
//           if (tempFile.path != dailyGPXFilePath) {
//             try {
//               String tempContent = await tempFile.readAsString();
//               Gpx tempGpx = GpxReader().fromString(tempContent);
//
//               for (var track in tempGpx.trks) {
//                 for (var segment in track.trksegs) {
//                   for (var point in segment.trkpts) {
//                     if (!_containsPoint(mainSegment.trkpts, point)) {
//                       mainSegment.trkpts.add(point);
//                       totalMergedPoints++;
//                     }
//                   }
//                 }
//               }
//
//               debugPrint("✅ [DATE-SPECIFIC] Merged ${tempFile.path}");
//             } catch (e) {
//               debugPrint("⚠️ [DATE-SPECIFIC] Error merging ${tempFile.path}: $e");
//             }
//           }
//         }
//
//         mainSegment.trkpts.sort((a, b) {
//           if (a.time == null || b.time == null) return 0;
//           return a.time!.compareTo(b.time!);
//         });
//
//         String consolidatedGPX = GpxWriter().asString(dailyGpx);
//         await dailyFile.writeAsString(consolidatedGPX, flush: true);
//
//         debugPrint("🎉 [DATE-SPECIFIC] DAILY CONSOLIDATION COMPLETED for: $dateStr");
//         debugPrint("📈 [DATE-SPECIFIC] Points: $initialPoints → ${mainSegment.trkpts.length}");
//         debugPrint("🔄 [DATE-SPECIFIC] Merged: $totalMergedPoints new points");
//       });
//
//     } catch (e) {
//       debugPrint("❌ [DATE-SPECIFIC] Error in daily consolidation for date: $e");
//     }
//   }
//
//   // ✅ NEW: Find all GPX files for specific date
//   Future<List<File>> _findAllGPXFilesForDate(Directory directory, String dateStr) async {
//     List<File> dateFiles = [];
//
//     try {
//       List<FileSystemEntity> entities = await directory.list().toList();
//
//       for (FileSystemEntity entity in entities) {
//         if (entity is File && entity.path.endsWith('.gpx')) {
//           String fileName = entity.path.split('/').last;
//
//           // Check if filename contains the specific date
//           if (fileName.contains(dateStr)) {
//             dateFiles.add(entity);
//           }
//         }
//       }
//     } catch (e) {
//       debugPrint("❌ [DATE-SPECIFIC] Error finding files for date $dateStr: $e");
//     }
//
//     return dateFiles;
//   }
//
//   // ✅ NEW: Save location data for specific date (CRITICAL FIX for midnight auto-clockout)
//   Future<void> saveLocationFromConsolidatedFileForDate(DateTime eventDate) async {
//     try {
//       final dateStr = DateFormat('dd-MM-yyyy').format(eventDate);
//       final downloadDirectory = await getDownloadsDirectory();
//       final consolidatedGPXFilePath = '${downloadDirectory!.path}/track$dateStr.gpx';
//       final consolidatedFile = File(consolidatedGPXFilePath);
//
//       debugPrint("💾 [DATE-SPECIFIC] Saving location data for date: $dateStr");
//       debugPrint("💾 [DATE-SPECIFIC] File path: $consolidatedGPXFilePath");
//
//       if (!await consolidatedFile.exists()) {
//         debugPrint('❌ [DATE-SPECIFIC] Consolidated GPX file does not exist: $consolidatedGPXFilePath');
//         return;
//       }
//
//       double totalDistance = await calculateTotalDistance(consolidatedGPXFilePath);
//
//       // ✅ Use lock for reading bytes
//       List<int> gpxBytesList = await _fileReadLock.synchronized(() async {
//         return await consolidatedFile.readAsBytes();
//       });
//
//       Uint8List gpxBytes = Uint8List.fromList(gpxBytesList);
//
//       await _loadCounter();
//       final orderSerial = generateNewOrderId(user_id);
//
//       await addLocation(LocationModel(
//         location_id: orderSerial.toString(),
//         user_id: user_id.toString(),
//         total_distance: totalDistance.toString(),
//         file_name: "$dateStr.gpx", // ✅ CRITICAL: Use event date for filename
//         booker_name: userName,
//         body: gpxBytes,
//       ));
//
//       await locationRepository.postDataFromDatabaseToAPI();
//
//       debugPrint("✅ [DATE-SPECIFIC] Location data saved from CONSOLIDATED file");
//       debugPrint("📁 [DATE-SPECIFIC] File: $dateStr.gpx");
//       debugPrint("📏 [DATE-SPECIFIC] Distance: $totalDistance km");
//
//     } catch (e) {
//       debugPrint("❌ [DATE-SPECIFIC] Error in saveLocationFromConsolidatedFileForDate: $e");
//     }
//   }
//
//   // ✅ NEW: Calculate distance for specific date file
//   Future<double> calculateTotalDistanceForDate(DateTime date) async {
//     try {
//       final dateStr = DateFormat('dd-MM-yyyy').format(date);
//       final downloadDirectory = await getDownloadsDirectory();
//       final filePath = "${downloadDirectory!.path}/track_${user_id}_$dateStr.gpx";
//
//       File file = File(filePath);
//
//       if (!await file.exists()) {
//         return 0.0;
//       }
//
//       double distance = await _fileReadLock.synchronized(() async {
//         return await calculateTotalDistance(filePath);
//       });
//
//       return distance;
//     } catch (e) {
//       debugPrint("❌ [DATE-SPECIFIC] Error calculating distance for date: $e");
//       return 0.0;
//     }
//   }
//
//   // ✅ FIXED: Original method - now delegates to date-specific method with current date
//   Future<void> consolidateDailyGPXData() async {
//     await consolidateDailyGPXDataForDate(DateTime.now());
//   }
//
//   // ✅ FIXED: Original method - now delegates to date-specific method with current date
//   Future<void> saveLocationFromConsolidatedFile() async {
//     await saveLocationFromConsolidatedFileForDate(DateTime.now());
//   }
//
//   // ----------------------
//   // Location Saving Methods (Original - Kept for compatibility)
//   // ----------------------
//
//   // ✅ FIXED: With proper async flow and error handling
//   Future<void> saveLocation() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
//     final downloadDirectory = await getDownloadsDirectory();
//     final gpxFilePath = '${downloadDirectory!.path}/track$date.gpx';
//     final maingpxFile = File(gpxFilePath);
//
//     // ✅ Async check
//     if (!await maingpxFile.exists()) {
//       debugPrint('❌ GPX file does not exist');
//       return;
//     }
//
//     try {
//       // ✅ Use lock for distance calculation
//       double totalDistance = await _fileReadLock.synchronized(() async {
//         return await calculateTotalDistance(gpxFilePath);
//       });
//
//       await prefs.setDouble('totalDistance', totalDistance);
//
//       // ✅ Read bytes with lock
//       List<int> gpxBytesList = await _fileReadLock.synchronized(() async {
//         return await maingpxFile.readAsBytes();
//       });
//
//       Uint8List gpxBytes = Uint8List.fromList(gpxBytesList);
//
//       await _loadCounter();
//       final orderSerial = generateNewOrderId(user_id);
//
//       await addLocation(LocationModel(
//         location_id: orderSerial.toString(),
//         user_id: user_id.toString(),
//         total_distance: totalDistance.toString(),
//         file_name: "$date.gpx",
//         booker_name: userName,
//         body: gpxBytes,
//       ));
//
//       await locationRepository.postDataFromDatabaseToAPI();
//
//       debugPrint("✅ Location data saved successfully");
//
//     } catch (e) {
//       debugPrint("❌ Error in saveLocation: $e");
//     }
//   }
//
//   // ----------------------
//   // Counter Logic
//   // ----------------------
//   Future<void> _loadCounter() async {
//     String currentMonth = DateFormat('MMM').format(DateTime.now());
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     locationSerialCounter = (prefs.getInt('locationSerialCounter') ?? locationHighestSerial ?? 1);
//     locationCurrentMonth =
//         prefs.getString('locationCurrentMonth') ?? currentMonth;
//     currentuser_id = prefs.getString('currentuser_id') ?? '';
//
//     if (locationCurrentMonth != currentMonth) {
//       locationSerialCounter = 1;
//       locationCurrentMonth = currentMonth;
//     }
//     debugPrint('SR: $locationSerialCounter');
//   }
//
//   Future<void> _saveCounter() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     await prefs.setInt('locationSerialCounter', locationSerialCounter);
//     await prefs.setString('locationCurrentMonth', locationCurrentMonth);
//     await prefs.setString('currentuser_id', currentuser_id);
//   }
//
//   String generateNewOrderId(String user_id) {
//     String currentMonth = DateFormat('MMM').format(DateTime.now());
//
//     if (currentuser_id != user_id) {
//       locationSerialCounter = locationHighestSerial ?? 1;
//       currentuser_id = user_id;
//     }
//
//     if (locationCurrentMonth != currentMonth) {
//       locationSerialCounter = 1;
//       locationCurrentMonth = currentMonth;
//     }
//
//     String orderId =
//         "LOC-$user_id-$currentMonth-${locationSerialCounter.toString().padLeft(3, '0')}";
//     locationSerialCounter++;
//     _saveCounter();
//     return orderId;
//   }
//
//   // ----------------------
//   // Location Logic
//   // ----------------------
//   Future<void> saveCurrentLocation() async {
//     PermissionStatus permission = await Permission.location.request();
//
//     if (permission.isGranted) {
//       try {
//         Position position = await Geolocator.getCurrentPosition(
//           desiredAccuracy: LocationAccuracy.high,
//         );
//         globalLatitude1.value = position.latitude;
//         globalLongitude1.value = position.longitude;
//
//         List<Placemark> placemarks = await placemarkFromCoordinates(
//             globalLatitude1.value, globalLongitude1.value);
//
//         if (placemarks.isNotEmpty) {
//           Placemark currentPlace = placemarks[0];
//           String address =
//               "${currentPlace.thoroughfare ?? ''} ${currentPlace.subLocality ?? ''}, ${currentPlace.locality ?? ''} ${currentPlace.postalCode ?? ''}, ${currentPlace.country ?? ''}";
//           shopAddress.value = address.trim().isEmpty ? "Not Verified" : address;
//         }
//
//         debugPrint('Latitude: ${globalLatitude1.value}, Longitude: ${globalLongitude1.value}');
//         debugPrint('Address is: ${shopAddress.value}');
//       } catch (e) {
//         debugPrint("Error getting location: $e");
//       }
//     }
//   }
//
//   loadClockStatus() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     isClockedIn.value = prefs.getBool('isClockedIn') ?? false;
//     if (!isClockedIn.value) {
//       prefs.setInt('secondsPassed', 0);
//     }
//   }
//
//   saveClockStatus(bool clockedIn) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     await prefs.setBool('isClockedIn', clockedIn);
//     isClockedIn.value = clockedIn;
//   }
//
//   saveCurrentTime() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     DateTime currentTime = DateTime.now();
//     String formattedTime = _formatDateTime(currentTime);
//     await prefs.setString('savedTime', formattedTime);
//     debugPrint("Save Current Time");
//   }
//
//   String _formatDateTime(DateTime dateTime) {
//     final formatter = DateFormat('HH:mm:ss');
//     return formatter.format(dateTime);
//   }
//
//   // ✅ FIXED: Better error handling and null safety
//   Future<double> calculateTotalDistance(String filePath) async {
//     try {
//       File file = File(filePath);
//
//       // ✅ Async check
//       if (!await file.exists()) {
//         return 0.0;
//       }
//
//       // ✅ Use lock for thread-safe reading
//       String gpxContent = await _fileReadLock.synchronized(() async {
//         return await file.readAsString();
//       });
//
//       if (gpxContent.isEmpty) {
//         return 0.0;
//       }
//
//       Gpx gpx;
//       try {
//         gpx = GpxReader().fromString(gpxContent);
//       } catch (e) {
//         debugPrint("❌ Error parsing GPX content: $e");
//         return 0.0;
//       }
//
//       double totalDistance = 0.0;
//
//       // ✅ Null safety checks
//       for (var track in gpx.trks) {
//         if (track.trksegs == null) continue;
//
//         for (var segment in track.trksegs) {
//           if (segment.trkpts == null || segment.trkpts.length < 2) continue;
//
//           for (int i = 0; i < segment.trkpts.length - 1; i++) {
//             var currentPoint = segment.trkpts[i];
//             var nextPoint = segment.trkpts[i + 1];
//
//             // ✅ Null checks for coordinates
//             if (currentPoint.lat == null || currentPoint.lon == null ||
//                 nextPoint.lat == null || nextPoint.lon == null) {
//               continue;
//             }
//
//             double distance = calculateDistance(
//               currentPoint.lat!.toDouble(),
//               currentPoint.lon!.toDouble(),
//               nextPoint.lat!.toDouble(),
//               nextPoint.lon!.toDouble(),
//             );
//             totalDistance += distance;
//           }
//         }
//       }
//
//       debugPrint("📏 Calculated distance: ${totalDistance.toStringAsFixed(3)} km");
//       return totalDistance;
//     } catch (e) {
//       debugPrint("❌ Error in calculateTotalDistance: $e");
//       return 0.0;
//     }
//   }
//
//   double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
//     double distanceInMeters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
//     return (distanceInMeters / 1000);
//   }
//
//   Future<double> calculateShiftDistance(DateTime shiftStartTime) async {
//     try {
//       final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
//       final downloadDirectory = await getDownloadsDirectory();
//       final gpxFilePath = '${downloadDirectory!.path}/track$date.gpx';
//
//       File file = File(gpxFilePath);
//       if (!file.existsSync()) return 0.0;
//
//       String gpxContent = await file.readAsString();
//       if (gpxContent.isEmpty) return 0.0;
//
//       Gpx gpx = GpxReader().fromString(gpxContent);
//       double shiftDistance = 0.0;
//
//       for (var track in gpx.trks) {
//         for (var segment in track.trksegs) {
//           List<Wpt> shiftPoints = [];
//           for (var point in segment.trkpts) {
//             if (point.time != null && point.time!.isAfter(shiftStartTime)) {
//               shiftPoints.add(point);
//             }
//           }
//
//           for (int i = 0; i < shiftPoints.length - 1; i++) {
//             double distance = calculateDistance(
//               shiftPoints[i].lat?.toDouble() ?? 0.0,
//               shiftPoints[i].lon?.toDouble() ?? 0.0,
//               shiftPoints[i + 1].lat?.toDouble() ?? 0.0,
//               shiftPoints[i + 1].lon?.toDouble() ?? 0.0,
//             );
//             shiftDistance += distance;
//           }
//         }
//       }
//
//       debugPrint("📍 Shift Distance: $shiftDistance km");
//       return shiftDistance;
//     } catch (e) {
//       debugPrint("❌ Error calculating shift distance: $e");
//       return 0.0;
//     }
//   }
//
//   // ----------------------
//   // Permissions Logic
//   // ----------------------
//   Future<void> requestPermissions() async {
//     if (await Permission.notification.request().isDenied) {
//       SystemChannels.platform.invokeMethod('SystemNavigator.pop');
//       return;
//     }
//
//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//     }
//
//     if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
//       _showLocationRequiredDialog();
//       return;
//     }
//
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       _showLocationRequiredDialog();
//       return;
//     }
//
//     if (await Permission.locationAlways.request().isDenied) {
//       SystemChannels.platform.invokeMethod('SystemNavigator.pop');
//       return;
//     }
//   }
//
//   void _showLocationRequiredDialog() {
//     Get.dialog(
//       WillPopScope(
//         onWillPop: () async => false,
//         child: AlertDialog(
//           title: const Text('Location Required', style: TextStyle(fontWeight: FontWeight.bold)),
//           content: const SingleChildScrollView(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text('For a better experience, your device will need to use Location Accuracy.', style: TextStyle(fontSize: 16)),
//                 SizedBox(height: 16),
//                 Text('The following settings should be on:', style: TextStyle(fontWeight: FontWeight.w600)),
//                 SizedBox(height: 8),
//                 Row(
//                   children: [
//                     Icon(Icons.radio_button_checked, size: 16, color: Colors.green),
//                     SizedBox(width: 8),
//                     Text('Device location'),
//                   ],
//                 ),
//                 Row(
//                   children: [
//                     Icon(Icons.radio_button_checked, size: 16, color: Colors.green),
//                     SizedBox(width: 8),
//                     Text('Location Accuracy'),
//                   ],
//                 ),
//                 SizedBox(height: 12),
//                 Text('Location Accuracy provides more accurate location for apps and services.', style: TextStyle(fontSize: 14, color: Colors.grey)),
//               ],
//             ),
//           ),
//           actions: [
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton(
//                 onPressed: () async {
//                   await Geolocator.openLocationSettings();
//                   Get.back();
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue,
//                   foregroundColor: Colors.white,
//                 ),
//                 child: const Text('TURN ON'),
//               ),
//             ),
//           ],
//         ),
//       ),
//       barrierDismissible: false,
//     );
//   }
//
//   // ----------------------
//   // Database CRUD
//   // ----------------------
//   Future<void> fetchAllLocation() async {
//     var location = await locationRepository.getLocation();
//     allLocation.value = location;
//   }
//
//   addLocation(LocationModel locationModel) {
//     locationRepository.add(locationModel);
//     fetchAllLocation();
//   }
//
//   void updateLocation(LocationModel locationModel) {
//     locationRepository.update(locationModel);
//     fetchAllLocation();
//   }
//
//   void deleteLocation(String id) {
//     locationRepository.delete(id);
//     fetchAllLocation();
//   }
//
//   serialCounterGet() async {
//     await locationRepository.serialNumberGeneratorApi();
//   }
//
//   void _initializeDailyProcessing() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     lastProcessedDate.value = prefs.getString('lastProcessedDate') ?? '';
//     isDailyProcessingComplete.value = prefs.getBool('isDailyProcessingComplete') ?? false;
//
//     String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
//
//     if (lastProcessedDate.value != today) {
//       isDailyProcessingComplete.value = false;
//       await prefs.setBool('isDailyProcessingComplete', false);
//     }
//   }
//
//   // ----------------------
//   // Utility Methods
//   // ----------------------
//
//   Future<double> calculateShiftDistanceFast(DateTime shiftStartTime) async {
//     try {
//       final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
//       final downloadDirectory = await getDownloadsDirectory();
//       final gpxFilePath = '${downloadDirectory!.path}/track$date.gpx';
//
//       File file = File(gpxFilePath);
//       if (!file.existsSync()) return 0.0;
//
//       String gpxContent = await file.readAsString();
//       if (gpxContent.isEmpty) return 0.0;
//
//       RegExp coordPattern = RegExp(r'lat="([^"]+)" lon="([^"]+)"');
//       List<RegExpMatch> matches = coordPattern.allMatches(gpxContent).toList();
//
//       if (matches.length < 2) return 0.0;
//
//       double totalDistance = 0.0;
//       double? prevLat, prevLon;
//
//       for (int i = 0; i < matches.length; i++) {
//         double lat = double.parse(matches[i].group(1)!);
//         double lon = double.parse(matches[i].group(2)!);
//
//         if (prevLat != null && prevLon != null) {
//           totalDistance += calculateDistance(prevLat, prevLon, lat, lon);
//         }
//
//         prevLat = lat;
//         prevLon = lon;
//       }
//
//       return totalDistance;
//     } catch (e) {
//       debugPrint("❌ Fast distance calculation error: $e");
//       return 0.0;
//     }
//   }
//
//   Future<Map<String, dynamic>> checkSyncStatus() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//
//     String syncStatus = prefs.getString('clockOutSyncStatus') ?? 'unknown';
//     String? lastClockOutTime = prefs.getString('lastClockOutTime');
//     double? lastDistance = prefs.getDouble('lastClockOutDistance');
//
//     return {
//       'syncStatus': syncStatus,
//       'lastClockOutTime': lastClockOutTime,
//       'lastDistance': lastDistance,
//       'hasPendingSync': syncStatus == 'pending' || syncStatus == 'pending_local' || syncStatus == 'retry_needed'
//     };
//   }
//
//   Future<void> clearSyncStatus() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     await prefs.remove('clockOutSyncStatus');
//     await prefs.remove('lastClockOutTime');
//     await prefs.remove('lastClockOutDistance');
//     await prefs.remove('pendingAttendanceOutId');
//     debugPrint("🧹 Sync status cleared");
//   }
//
//   // ===============================
// // 🔥 AUTO SYNC ALL LOCAL DB DATA
// // ===============================
//
//   Future<void> _autoSyncPendingLocalData() async {
//     if (_isAutoSyncing) return;
//
//     _isAutoSyncing = true;
//
//     try {
//       debugPrint("🚀 App Opened → Checking pending local data...");
//
//       final hasInternet = await _checkInternet();
//       if (!hasInternet) {
//         debugPrint("❌ No internet. Auto sync skipped.");
//         return;
//       }
//
//       // 👇 Ye method DB ke sab pending records API pe bhej dega
//       await locationRepository.postDataFromDatabaseToAPI();
//
//       debugPrint("✅ All pending local data synced successfully.");
//
//     } catch (e) {
//       debugPrint("❌ Auto sync error: $e");
//     } finally {
//       _isAutoSyncing = false;
//     }
//   }
//
//   Future<bool> _checkInternet() async {
//     try {
//       final result = await InternetAddress.lookup('google.com');
//       return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
//     } on SocketException catch (_) {
//       return false;
//     }
//   }
//
//   // ===============================
// // 🚀 START GPX AUTO SYNC TIMER
// // ===============================
//   void _startGpxAutoSync() {
//     debugPrint("🚀 GPX Auto Sync Started");
//
//     _gpxSyncTimer =
//         Timer.periodic(const Duration(minutes: 5), (timer) async {
//           await _syncGpxIfOnline();
//         });
//
//     // 🔥 Immediate Sync on App Open
//     _syncGpxIfOnline();
//   }
//
//   // ===============================
// // 🔄 SYNC GPX DATA IF INTERNET
// // ===============================
//   Future<void> _syncGpxIfOnline() async {
//     if (_isGpxAutoSyncing) return;
//
//     _isGpxAutoSyncing = true;
//
//     try {
//       debugPrint("🔍 Checking pending GPX data...");
//
//       final hasInternet = await _checkInternet();
//       if (!hasInternet) {
//         debugPrint("❌ No internet — GPX sync skipped");
//         return;
//       }
//
//       // 🔥 Yahan apka Location Repository sync call hoga
//       await locationRepository.postDataFromDatabaseToAPI();
//
//       debugPrint("✅ GPX local data synced successfully");
//
//     } catch (e) {
//       debugPrint("❌ GPX Sync Error: $e");
//     } finally {
//       _isGpxAutoSyncing = false;
//     }
//   }
// }
//
//
//
//

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:gpx/gpx.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:order_booking_app/Repositories/location_services_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';
import '../Databases/util.dart';
import '../Models/location_model.dart';
import '../Repositories/location_repository.dart';
import 'package:geocoding/geocoding.dart';
import '../Services/FirebaseServices/firebase_remote_config.dart';
import '../Tracker/trac.dart';

class LocationViewModel extends GetxController {
  var allLocation = <LocationModel>[].obs;
  LocationRepository locationRepository = LocationRepository();
  var globalLatitude1 = 0.0.obs;
  var globalLongitude1 = 0.0.obs;
  var shopAddress = ''.obs;

  var lastProcessedDate = ''.obs;
  var isDailyProcessingComplete = false.obs;

  RxInt secondsPassed = 0.obs;
  Timer? _timer;
  RxBool isClockedIn = false.obs;

  // 🔥 YAHAN ADD KARO
  bool _isAutoSyncing = false;
  bool _isGpxAutoSyncing = false;
  Timer? _gpxSyncTimer;

  var isGPSEnabled = false.obs;
  var newsecondpassed = 0.obs;
  int locationSerialCounter = 1;
  String locationCurrentMonth = DateFormat('MMM').format(DateTime.now());
  String currentuser_id = '';

  // ✅ ADDED: File read lock to coordinate with LocationService
  final Lock _fileReadLock = Lock();

  // ✅ ADDED: Cache for frequently accessed data
  double? _cachedDistance;
  DateTime? _lastDistanceCalculation;
  static const Duration _distanceCacheValidity = Duration(seconds: 5);

  @override
  void onInit() {
    super.onInit();
    fetchAllLocation();
    loadClockStatus();
    startTimerIfClockedIn();
    _initializeDailyProcessing();
    // 🔥 NEW: Auto sync when app opens
    // 🔥 AUTO SYNC GPX
    Future.delayed(const Duration(seconds: 3), () {
      _startGpxAutoSync();
    });

    // ✅ NEW: Restore location if app was force-killed right after clockout
    _restorePendingLocationIfNeeded();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ----------------------
  // Timer Logic
  // ----------------------
  void startTimerIfClockedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    isClockedIn.value = prefs.getBool('isClockedIn') ?? false;
    if (isClockedIn.value) {
      secondsPassed.value = prefs.getInt('secondsPassed') ?? 0;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
        secondsPassed.value++;
        _saveSecondsToPrefs(secondsPassed.value);
      });
    }
  }

  void startTimer() async {
    _timer?.cancel();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    secondsPassed.value = prefs.getInt('secondsPassed') ?? 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      secondsPassed.value++;
      _saveSecondsToPrefs(secondsPassed.value);
    });
  }

  void _saveSecondsToPrefs(int seconds) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('secondsPassed', seconds);
  }

  Future<String> stopTimer() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _timer?.cancel();

    String totalTime = _formatDuration(secondsPassed.value);

    secondsPassed.value = 0;
    newsecondpassed.value = 0;

    await prefs.setInt('secondsPassed', 0);
    await prefs.setString('totalTime', totalTime);

    return totalTime;
  }

  String _formatDuration(int seconds) {
    Duration duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String secs = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$secs';
  }

  // ----------------------
  // Daily GPX File Management
  // ----------------------

  String getDailyGPXFileName() {
    final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
    return 'track$date.gpx';
  }

  Future<String> getCurrentGPXFilePath() async {
    final downloadDirectory = await getDownloadsDirectory();
    return '${downloadDirectory!.path}/${getDailyGPXFileName()}';
  }

  // ✅ FIXED: With synchronization and caching
  Future<double> getImmediateDistance() async {
    try {
      // Return cached value if recent
      if (_cachedDistance != null &&
          _lastDistanceCalculation != null &&
          DateTime.now().difference(_lastDistanceCalculation!) < _distanceCacheValidity) {
        debugPrint("📏 Returning cached distance: $_cachedDistance km");
        return _cachedDistance!;
      }

      final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final downloadDirectory = await getDownloadsDirectory();
      final filePath = "${downloadDirectory!.path}/track_${user_id}_$date.gpx";

      File file = File(filePath);

      // ✅ Use async check instead of sync
      bool exists = await file.exists();
      if (!exists) {
        return 0.0;
      }

      // ✅ CRITICAL: Use lock to prevent reading during write
      double distance = await _fileReadLock.synchronized(() async {
        return await calculateTotalDistance(filePath);
      });

      // ✅ Update cache
      _cachedDistance = distance;
      _lastDistanceCalculation = DateTime.now();

      return distance;
    } catch (e) {
      debugPrint("❌ Error getting immediate distance: $e");
      return 0.0;
    }
  }

  // ✅ FIXED: All async operations, no sync calls
  Future<Map<String, dynamic>> checkLocationServiceStatus() async {
    try {
      final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final downloadDirectory = await getDownloadsDirectory();
      final filePath = "${downloadDirectory!.path}/track_${user_id}_$date.gpx";

      File file = File(filePath);

      // ✅ Async operations only
      bool fileExists = await file.exists();
      int fileSize = fileExists ? await file.length() : 0;
      int pointCount = 0;

      if (fileExists) {
        // ✅ Use lock when reading
        String content = await _fileReadLock.synchronized(() async {
          return await file.readAsString();
        });

        if (content.isNotEmpty) {
          Gpx gpx = GpxReader().fromString(content);
          pointCount = _getTotalPoints(gpx);
        }
      }

      return {
        'serviceActive': true,
        'fileExists': fileExists,
        'fileSize': fileSize,
        'pointsRecorded': pointCount,
        'filePath': filePath,
      };
    } catch (e) {
      return {
        'serviceActive': false,
        'error': e.toString(),
      };
    }
  }

  int _getTotalPoints(Gpx gpx) {
    int total = 0;
    for (var track in gpx.trks) {
      for (var segment in track.trksegs) {
        total += segment.trkpts.length;
      }
    }
    return total;
  }

  // ✅ HELPER METHOD: Check if point already exists in list (MOVED HERE to fix error)
  bool _containsPoint(List<Wpt> points, Wpt newPoint) {
    for (Wpt point in points) {
      if (point.lat == newPoint.lat &&
          point.lon == newPoint.lon &&
          point.time == newPoint.time) {
        return true;
      }
    }
    return false;
  }

  // ----------------------
  // ✅ NEW: Date-specific GPX Methods for Midnight Auto-Clockout Fix
  // ----------------------

  // ✅ NEW: Get GPX file path for specific date (not current date)
  Future<String> getGPXFilePathForDate(DateTime date) async {
    final dateStr = DateFormat('dd-MM-yyyy').format(date);
    final downloadDirectory = await getDownloadsDirectory();
    return "${downloadDirectory!.path}/track_${user_id}_$dateStr.gpx";
  }

  // ✅ NEW: Consolidate GPX for specific date (CRITICAL FIX for midnight auto-clockout)
  Future<void> consolidateDailyGPXDataForDate(DateTime eventDate) async {
    try {
      final dateStr = DateFormat('dd-MM-yyyy').format(eventDate);
      final downloadDirectory = await getDownloadsDirectory();
      final dailyGPXFilePath = '${downloadDirectory!.path}/track$dateStr.gpx';

      debugPrint("🔄 [DATE-SPECIFIC] Starting Daily GPX Consolidation for: $dateStr");
      debugPrint("🔄 [DATE-SPECIFIC] File path: $dailyGPXFilePath");

      // ✅ Use lock for entire consolidation process
      await _fileReadLock.synchronized(() async {
        File dailyFile = File(dailyGPXFilePath);

        if (!await dailyFile.exists()) {
          debugPrint("📄 [DATE-SPECIFIC] Daily file doesn't exist, creating new one");
          String initialGPX = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="OrderBookingApp">
  <trk>
    <name>Daily Track $dateStr</name>
    <trkseg>
    </trkseg>
  </trk>
</gpx>''';

          await dailyFile.writeAsString(initialGPX, flush: true);
        }

        String dailyContent = await dailyFile.readAsString();
        Gpx dailyGpx = GpxReader().fromString(dailyContent);

        if (dailyGpx.trks.isEmpty) {
          dailyGpx.trks.add(Trk());
        }
        if (dailyGpx.trks.first.trksegs.isEmpty) {
          dailyGpx.trks.first.trksegs.add(Trkseg());
        }

        Trkseg mainSegment = dailyGpx.trks.first.trksegs.first;
        int initialPoints = mainSegment.trkpts.length;

        debugPrint("📊 [DATE-SPECIFIC] Initial points in daily file: $initialPoints");

        List<File> allGPXFiles = await _findAllGPXFilesForDate(downloadDirectory, dateStr);
        debugPrint("📁 [DATE-SPECIFIC] Found ${allGPXFiles.length} GPX files for date: $dateStr");

        int totalMergedPoints = 0;

        for (File tempFile in allGPXFiles) {
          if (tempFile.path != dailyGPXFilePath) {
            try {
              String tempContent = await tempFile.readAsString();
              Gpx tempGpx = GpxReader().fromString(tempContent);

              for (var track in tempGpx.trks) {
                for (var segment in track.trksegs) {
                  for (var point in segment.trkpts) {
                    if (!_containsPoint(mainSegment.trkpts, point)) {
                      mainSegment.trkpts.add(point);
                      totalMergedPoints++;
                    }
                  }
                }
              }

              debugPrint("✅ [DATE-SPECIFIC] Merged ${tempFile.path}");
            } catch (e) {
              debugPrint("⚠️ [DATE-SPECIFIC] Error merging ${tempFile.path}: $e");
            }
          }
        }

        mainSegment.trkpts.sort((a, b) {
          if (a.time == null || b.time == null) return 0;
          return a.time!.compareTo(b.time!);
        });

        String consolidatedGPX = GpxWriter().asString(dailyGpx);
        await dailyFile.writeAsString(consolidatedGPX, flush: true);

        debugPrint("🎉 [DATE-SPECIFIC] DAILY CONSOLIDATION COMPLETED for: $dateStr");
        debugPrint("📈 [DATE-SPECIFIC] Points: $initialPoints → ${mainSegment.trkpts.length}");
        debugPrint("🔄 [DATE-SPECIFIC] Merged: $totalMergedPoints new points");
      });

    } catch (e) {
      debugPrint("❌ [DATE-SPECIFIC] Error in daily consolidation for date: $e");
    }
  }

  // ✅ NEW: Find all GPX files for specific date
  Future<List<File>> _findAllGPXFilesForDate(Directory directory, String dateStr) async {
    List<File> dateFiles = [];

    try {
      List<FileSystemEntity> entities = await directory.list().toList();

      for (FileSystemEntity entity in entities) {
        if (entity is File && entity.path.endsWith('.gpx')) {
          String fileName = entity.path.split('/').last;

          // Check if filename contains the specific date
          if (fileName.contains(dateStr)) {
            dateFiles.add(entity);
          }
        }
      }
    } catch (e) {
      debugPrint("❌ [DATE-SPECIFIC] Error finding files for date $dateStr: $e");
    }

    return dateFiles;
  }

  // ✅ NEW: Save location data for specific date (CRITICAL FIX for midnight auto-clockout)
  Future<void> saveLocationFromConsolidatedFileForDate(DateTime eventDate) async {
    try {
      final dateStr = DateFormat('dd-MM-yyyy').format(eventDate);
      final downloadDirectory = await getDownloadsDirectory();
      final consolidatedGPXFilePath = '${downloadDirectory!.path}/track$dateStr.gpx';
      final consolidatedFile = File(consolidatedGPXFilePath);

      debugPrint("💾 [DATE-SPECIFIC] Saving location data for date: $dateStr");
      debugPrint("💾 [DATE-SPECIFIC] File path: $consolidatedGPXFilePath");

      if (!await consolidatedFile.exists()) {
        debugPrint('❌ [DATE-SPECIFIC] Consolidated GPX file does not exist: $consolidatedGPXFilePath');
        return;
      }

      double totalDistance = await calculateTotalDistance(consolidatedGPXFilePath);

      // ✅ Use lock for reading bytes
      List<int> gpxBytesList = await _fileReadLock.synchronized(() async {
        return await consolidatedFile.readAsBytes();
      });

      Uint8List gpxBytes = Uint8List.fromList(gpxBytesList);

      await _loadCounter();
      final orderSerial = generateNewOrderId(user_id);

      await addLocation(LocationModel(
        location_id: orderSerial.toString(),
        user_id: user_id.toString(),
        total_distance: totalDistance.toString(),
        file_name: "$dateStr.gpx", // ✅ CRITICAL: Use event date for filename
        booker_name: userName,
        body: gpxBytes,
      ));

      await locationRepository.postDataFromDatabaseToAPI();

      debugPrint("✅ [DATE-SPECIFIC] Location data saved from CONSOLIDATED file");
      debugPrint("📁 [DATE-SPECIFIC] File: $dateStr.gpx");
      debugPrint("📏 [DATE-SPECIFIC] Distance: $totalDistance km");

    } catch (e) {
      debugPrint("❌ [DATE-SPECIFIC] Error in saveLocationFromConsolidatedFileForDate: $e");
    }
  }

  // ✅ NEW: Calculate distance for specific date file
  Future<double> calculateTotalDistanceForDate(DateTime date) async {
    try {
      final dateStr = DateFormat('dd-MM-yyyy').format(date);
      final downloadDirectory = await getDownloadsDirectory();
      final filePath = "${downloadDirectory!.path}/track_${user_id}_$dateStr.gpx";

      File file = File(filePath);

      if (!await file.exists()) {
        return 0.0;
      }

      double distance = await _fileReadLock.synchronized(() async {
        return await calculateTotalDistance(filePath);
      });

      return distance;
    } catch (e) {
      debugPrint("❌ [DATE-SPECIFIC] Error calculating distance for date: $e");
      return 0.0;
    }
  }

  // ✅ FIXED: Original method - now delegates to date-specific method with current date
  Future<void> consolidateDailyGPXData() async {
    await consolidateDailyGPXDataForDate(DateTime.now());
  }

  // ✅ FIXED: Original method - now delegates to date-specific method with current date
  Future<void> saveLocationFromConsolidatedFile() async {
    // ✅ Mark as pending BEFORE doing any work so we can restore if app is killed
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasPendingLocationSync', true);
    await prefs.setString(
        'pendingLocationSyncDate', DateFormat('dd-MM-yyyy').format(DateTime.now()));

    await saveLocationFromConsolidatedFileForDate(DateTime.now());

    // ✅ Clear flag after successful save
    await prefs.setBool('hasPendingLocationSync', false);
    await prefs.remove('pendingLocationSyncDate');
  }

  // ----------------------
  // Location Saving Methods (Original - Kept for compatibility)
  // ----------------------

  // ✅ FIXED: With proper async flow and error handling
  Future<void> saveLocation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final downloadDirectory = await getDownloadsDirectory();
    final gpxFilePath = '${downloadDirectory!.path}/track$date.gpx';
    final maingpxFile = File(gpxFilePath);

    // ✅ Async check
    if (!await maingpxFile.exists()) {
      debugPrint('❌ GPX file does not exist');
      return;
    }

    try {
      // ✅ Use lock for distance calculation
      double totalDistance = await _fileReadLock.synchronized(() async {
        return await calculateTotalDistance(gpxFilePath);
      });

      await prefs.setDouble('totalDistance', totalDistance);

      // ✅ Read bytes with lock
      List<int> gpxBytesList = await _fileReadLock.synchronized(() async {
        return await maingpxFile.readAsBytes();
      });

      Uint8List gpxBytes = Uint8List.fromList(gpxBytesList);

      await _loadCounter();
      final orderSerial = generateNewOrderId(user_id);

      await addLocation(LocationModel(
        location_id: orderSerial.toString(),
        user_id: user_id.toString(),
        total_distance: totalDistance.toString(),
        file_name: "$date.gpx",
        booker_name: userName,
        body: gpxBytes,
      ));

      await locationRepository.postDataFromDatabaseToAPI();

      debugPrint("✅ Location data saved successfully");

    } catch (e) {
      debugPrint("❌ Error in saveLocation: $e");
    }
  }

  // ----------------------
  // Counter Logic
  // ----------------------
  Future<void> _loadCounter() async {
    String currentMonth = DateFormat('MMM').format(DateTime.now());
    SharedPreferences prefs = await SharedPreferences.getInstance();
    locationSerialCounter = (prefs.getInt('locationSerialCounter') ?? locationHighestSerial ?? 1);
    locationCurrentMonth =
        prefs.getString('locationCurrentMonth') ?? currentMonth;
    currentuser_id = prefs.getString('currentuser_id') ?? '';

    if (locationCurrentMonth != currentMonth) {
      locationSerialCounter = 1;
      locationCurrentMonth = currentMonth;
    }
    debugPrint('SR: $locationSerialCounter');
  }

  Future<void> _saveCounter() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('locationSerialCounter', locationSerialCounter);
    await prefs.setString('locationCurrentMonth', locationCurrentMonth);
    await prefs.setString('currentuser_id', currentuser_id);
  }

  String generateNewOrderId(String user_id) {
    String currentMonth = DateFormat('MMM').format(DateTime.now());

    if (currentuser_id != user_id) {
      locationSerialCounter = locationHighestSerial ?? 1;
      currentuser_id = user_id;
    }

    if (locationCurrentMonth != currentMonth) {
      locationSerialCounter = 1;
      locationCurrentMonth = currentMonth;
    }

    String orderId =
        "LOC-$user_id-$currentMonth-${locationSerialCounter.toString().padLeft(3, '0')}";
    locationSerialCounter++;
    _saveCounter();
    return orderId;
  }

  // ----------------------
  // Location Logic
  // ----------------------
  Future<void> saveCurrentLocation() async {
    PermissionStatus permission = await Permission.location.request();

    if (permission.isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        globalLatitude1.value = position.latitude;
        globalLongitude1.value = position.longitude;

        List<Placemark> placemarks = await placemarkFromCoordinates(
            globalLatitude1.value, globalLongitude1.value);

        if (placemarks.isNotEmpty) {
          Placemark currentPlace = placemarks[0];
          String address =
              "${currentPlace.thoroughfare ?? ''} ${currentPlace.subLocality ?? ''}, ${currentPlace.locality ?? ''} ${currentPlace.postalCode ?? ''}, ${currentPlace.country ?? ''}";
          shopAddress.value = address.trim().isEmpty ? "Not Verified" : address;
        }

        debugPrint('Latitude: ${globalLatitude1.value}, Longitude: ${globalLongitude1.value}');
        debugPrint('Address is: ${shopAddress.value}');
      } catch (e) {
        debugPrint("Error getting location: $e");
      }
    }
  }

  loadClockStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    isClockedIn.value = prefs.getBool('isClockedIn') ?? false;
    if (!isClockedIn.value) {
      prefs.setInt('secondsPassed', 0);
    }
  }

  saveClockStatus(bool clockedIn) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isClockedIn', clockedIn);
    isClockedIn.value = clockedIn;
  }

  saveCurrentTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    DateTime currentTime = DateTime.now();
    String formattedTime = _formatDateTime(currentTime);
    await prefs.setString('savedTime', formattedTime);
    debugPrint("Save Current Time");
  }

  String _formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('HH:mm:ss');
    return formatter.format(dateTime);
  }

  // ✅ FIXED: Better error handling and null safety
  Future<double> calculateTotalDistance(String filePath) async {
    try {
      File file = File(filePath);

      // ✅ Async check
      if (!await file.exists()) {
        return 0.0;
      }

      // ✅ Use lock for thread-safe reading
      String gpxContent = await _fileReadLock.synchronized(() async {
        return await file.readAsString();
      });

      if (gpxContent.isEmpty) {
        return 0.0;
      }

      Gpx gpx;
      try {
        gpx = GpxReader().fromString(gpxContent);
      } catch (e) {
        debugPrint("❌ Error parsing GPX content: $e");
        return 0.0;
      }

      double totalDistance = 0.0;

      // ✅ Null safety checks
      for (var track in gpx.trks) {
        if (track.trksegs == null) continue;

        for (var segment in track.trksegs) {
          if (segment.trkpts == null || segment.trkpts.length < 2) continue;

          for (int i = 0; i < segment.trkpts.length - 1; i++) {
            var currentPoint = segment.trkpts[i];
            var nextPoint = segment.trkpts[i + 1];

            // ✅ Null checks for coordinates
            if (currentPoint.lat == null || currentPoint.lon == null ||
                nextPoint.lat == null || nextPoint.lon == null) {
              continue;
            }

            double distance = calculateDistance(
              currentPoint.lat!.toDouble(),
              currentPoint.lon!.toDouble(),
              nextPoint.lat!.toDouble(),
              nextPoint.lon!.toDouble(),
            );
            totalDistance += distance;
          }
        }
      }

      debugPrint("📏 Calculated distance: ${totalDistance.toStringAsFixed(3)} km");
      return totalDistance;
    } catch (e) {
      debugPrint("❌ Error in calculateTotalDistance: $e");
      return 0.0;
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    double distanceInMeters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return (distanceInMeters / 1000);
  }

  Future<double> calculateShiftDistance(DateTime shiftStartTime) async {
    try {
      final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final downloadDirectory = await getDownloadsDirectory();
      final gpxFilePath = '${downloadDirectory!.path}/track$date.gpx';

      File file = File(gpxFilePath);
      if (!file.existsSync()) return 0.0;

      String gpxContent = await file.readAsString();
      if (gpxContent.isEmpty) return 0.0;

      Gpx gpx = GpxReader().fromString(gpxContent);
      double shiftDistance = 0.0;

      for (var track in gpx.trks) {
        for (var segment in track.trksegs) {
          List<Wpt> shiftPoints = [];
          for (var point in segment.trkpts) {
            if (point.time != null && point.time!.isAfter(shiftStartTime)) {
              shiftPoints.add(point);
            }
          }

          for (int i = 0; i < shiftPoints.length - 1; i++) {
            double distance = calculateDistance(
              shiftPoints[i].lat?.toDouble() ?? 0.0,
              shiftPoints[i].lon?.toDouble() ?? 0.0,
              shiftPoints[i + 1].lat?.toDouble() ?? 0.0,
              shiftPoints[i + 1].lon?.toDouble() ?? 0.0,
            );
            shiftDistance += distance;
          }
        }
      }

      debugPrint("📍 Shift Distance: $shiftDistance km");
      return shiftDistance;
    } catch (e) {
      debugPrint("❌ Error calculating shift distance: $e");
      return 0.0;
    }
  }

  // ----------------------
  // Permissions Logic
  // ----------------------
  Future<void> requestPermissions() async {
    if (await Permission.notification.request().isDenied) {
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      _showLocationRequiredDialog();
      return;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationRequiredDialog();
      return;
    }

    if (await Permission.locationAlways.request().isDenied) {
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      return;
    }
  }

  void _showLocationRequiredDialog() {
    Get.dialog(
      WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Text('Location Required', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('For a better experience, your device will need to use Location Accuracy.', style: TextStyle(fontSize: 16)),
                SizedBox(height: 16),
                Text('The following settings should be on:', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.radio_button_checked, size: 16, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Device location'),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.radio_button_checked, size: 16, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Location Accuracy'),
                  ],
                ),
                SizedBox(height: 12),
                Text('Location Accuracy provides more accurate location for apps and services.', style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                  Get.back();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('TURN ON'),
              ),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }

  // ----------------------
  // Database CRUD
  // ----------------------
  Future<void> fetchAllLocation() async {
    var location = await locationRepository.getLocation();
    allLocation.value = location;
  }

  addLocation(LocationModel locationModel) {
    locationRepository.add(locationModel);
    fetchAllLocation();
  }

  void updateLocation(LocationModel locationModel) {
    locationRepository.update(locationModel);
    fetchAllLocation();
  }

  void deleteLocation(String id) {
    locationRepository.delete(id);
    fetchAllLocation();
  }

  serialCounterGet() async {
    await locationRepository.serialNumberGeneratorApi();
  }

  void _initializeDailyProcessing() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    lastProcessedDate.value = prefs.getString('lastProcessedDate') ?? '';
    isDailyProcessingComplete.value = prefs.getBool('isDailyProcessingComplete') ?? false;

    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (lastProcessedDate.value != today) {
      isDailyProcessingComplete.value = false;
      await prefs.setBool('isDailyProcessingComplete', false);
    }
  }

  // ----------------------
  // Utility Methods
  // ----------------------

  Future<double> calculateShiftDistanceFast(DateTime shiftStartTime) async {
    try {
      final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final downloadDirectory = await getDownloadsDirectory();
      final gpxFilePath = '${downloadDirectory!.path}/track$date.gpx';

      File file = File(gpxFilePath);
      if (!file.existsSync()) return 0.0;

      String gpxContent = await file.readAsString();
      if (gpxContent.isEmpty) return 0.0;

      RegExp coordPattern = RegExp(r'lat="([^"]+)" lon="([^"]+)"');
      List<RegExpMatch> matches = coordPattern.allMatches(gpxContent).toList();

      if (matches.length < 2) return 0.0;

      double totalDistance = 0.0;
      double? prevLat, prevLon;

      for (int i = 0; i < matches.length; i++) {
        double lat = double.parse(matches[i].group(1)!);
        double lon = double.parse(matches[i].group(2)!);

        if (prevLat != null && prevLon != null) {
          totalDistance += calculateDistance(prevLat, prevLon, lat, lon);
        }

        prevLat = lat;
        prevLon = lon;
      }

      return totalDistance;
    } catch (e) {
      debugPrint("❌ Fast distance calculation error: $e");
      return 0.0;
    }
  }

  Future<Map<String, dynamic>> checkSyncStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String syncStatus = prefs.getString('clockOutSyncStatus') ?? 'unknown';
    String? lastClockOutTime = prefs.getString('lastClockOutTime');
    double? lastDistance = prefs.getDouble('lastClockOutDistance');

    return {
      'syncStatus': syncStatus,
      'lastClockOutTime': lastClockOutTime,
      'lastDistance': lastDistance,
      'hasPendingSync': syncStatus == 'pending' || syncStatus == 'pending_local' || syncStatus == 'retry_needed'
    };
  }

  Future<void> clearSyncStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('clockOutSyncStatus');
    await prefs.remove('lastClockOutTime');
    await prefs.remove('lastClockOutDistance');
    await prefs.remove('pendingAttendanceOutId');
    debugPrint("🧹 Sync status cleared");
  }

  // ===============================
// 🔥 AUTO SYNC ALL LOCAL DB DATA
// ===============================

  Future<void> _autoSyncPendingLocalData() async {
    if (_isAutoSyncing) return;

    _isAutoSyncing = true;

    try {
      debugPrint("🚀 App Opened → Checking pending local data...");

      final hasInternet = await _checkInternet();
      if (!hasInternet) {
        debugPrint("❌ No internet. Auto sync skipped.");
        return;
      }

      // 👇 Ye method DB ke sab pending records API pe bhej dega
      await locationRepository.postDataFromDatabaseToAPI();

      debugPrint("✅ All pending local data synced successfully.");

    } catch (e) {
      debugPrint("❌ Auto sync error: $e");
    } finally {
      _isAutoSyncing = false;
    }
  }

  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  // ===============================
// 🔄 RESTORE PENDING LOCATION ON STARTUP
// ===============================

  /// ✅ NEW: If app was force-killed immediately after clockout before location
  /// could be saved/posted, this restores and posts it on next app open.
  Future<void> _restorePendingLocationIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool hasPending = prefs.getBool('hasPendingLocationSync') ?? false;

      if (!hasPending) return;

      debugPrint("🔄 [LOCATION RESTORE] Pending location sync found — restoring...");

      // Get the date on which clockout happened
      String? dateStr = prefs.getString('pendingLocationSyncDate');
      DateTime eventDate = dateStr != null
          ? DateFormat('dd-MM-yyyy').tryParse(dateStr) ?? DateTime.now()
          : DateTime.now();

      debugPrint("📅 [LOCATION RESTORE] Restoring for date: $dateStr");

      // Consolidate any GPX fragments for that date, then save + post
      await consolidateDailyGPXDataForDate(eventDate);
      await saveLocationFromConsolidatedFileForDate(eventDate);

      // Clear the pending flag
      await prefs.setBool('hasPendingLocationSync', false);
      await prefs.remove('pendingLocationSyncDate');

      debugPrint("✅ [LOCATION RESTORE] Completed for date: $dateStr");
    } catch (e) {
      debugPrint("❌ [LOCATION RESTORE] Error: $e");
      // Leave the flag set so we retry on next startup
    }
  }

// ===============================
// 🚀 START GPX AUTO SYNC TIMER
// ===============================
  void _startGpxAutoSync() {
    debugPrint("🚀 GPX Auto Sync Started");

    _gpxSyncTimer =
        Timer.periodic(const Duration(minutes: 5), (timer) async {
          await _syncGpxIfOnline();
        });

    // 🔥 Immediate Sync on App Open
    _syncGpxIfOnline();
  }

  // ===============================
// 🔄 SYNC GPX DATA IF INTERNET
// ===============================
  Future<void> _syncGpxIfOnline() async {
    if (_isGpxAutoSyncing) return;

    _isGpxAutoSyncing = true;

    try {
      debugPrint("🔍 Checking pending GPX data...");

      final hasInternet = await _checkInternet();
      if (!hasInternet) {
        debugPrint("❌ No internet — GPX sync skipped");
        return;
      }

      // 🔥 Yahan apka Location Repository sync call hoga
      await locationRepository.postDataFromDatabaseToAPI();

      debugPrint("✅ GPX local data synced successfully");

    } catch (e) {
      debugPrint("❌ GPX Sync Error: $e");
    } finally {
      _isGpxAutoSyncing = false;
    }
  }
}