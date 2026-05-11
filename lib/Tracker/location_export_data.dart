import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../Databases/dp_helper.dart';
import '../Databases/util.dart';

/// Result returned by [LocationExportService.exportToCSV].
class ExportResult {
  final bool success;
  final String? filePath;
  final String message;
  final int totalRows;
  final int postedRows;
  final int pendingRows;

  const ExportResult({
    required this.success,
    this.filePath,
    required this.message,
    this.totalRows = 0,
    this.postedRows = 0,
    this.pendingRows = 0,
  });
}

class LocationExportService {
  static final LocationExportService _instance =
  LocationExportService._internal();
  factory LocationExportService() => _instance;
  LocationExportService._internal();

  final DBHelper _dbHelper = DBHelper();

  // ── Folder: Internal Storage / Downloads / LocationData ──────────────────
  static const String _folderName = 'LocationData';

  // ══════════════════════════════════════════════════════════════════════════
  //  PERMISSION HANDLING
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns true when the app has enough storage permission to write a file.
  ///
  /// Android 10 (Q) and below  → needs [Permission.storage]
  /// Android 11 (R) and above  → needs [Permission.manageExternalStorage]
  ///                             OR we fall back to app-scoped Downloads via
  ///                             [getExternalStorageDirectory] which never
  ///                             needs special permissions.
  Future<StoragePermissionResult> checkAndRequestPermission() async {
    if (!Platform.isAndroid) {
      return StoragePermissionResult.granted; // iOS: no extra perms needed
    }

    // Determine Android SDK version
    final sdkInt = await _getAndroidSdkVersion();
    debugPrint('📱 [EXPORT] Android SDK: $sdkInt');

    if (sdkInt >= 30) {
      // Android 11+ ─ try MANAGE_EXTERNAL_STORAGE for Downloads access
      final status = await Permission.manageExternalStorage.status;
      if (status.isGranted) return StoragePermissionResult.granted;

      if (status.isPermanentlyDenied) {
        return StoragePermissionResult.permanentlyDenied;
      }

      final requested = await Permission.manageExternalStorage.request();
      if (requested.isGranted) return StoragePermissionResult.granted;

      // Fallback: use app-scoped directory (no permission needed)
      return StoragePermissionResult.fallbackAppDir;
    } else {
      // Android 10 and below ─ classic READ/WRITE storage
      final status = await Permission.storage.status;
      if (status.isGranted) return StoragePermissionResult.granted;

      if (status.isPermanentlyDenied) {
        return StoragePermissionResult.permanentlyDenied;
      }

      final requested = await Permission.storage.request();
      if (requested.isGranted) return StoragePermissionResult.granted;

      return StoragePermissionResult.denied;
    }
  }

  Future<int> _getAndroidSdkVersion() async {
    try {
      // Read /proc/version or use a safe default
      final result = await Process.run('getprop', ['ro.build.version.sdk']);
      return int.tryParse(result.stdout.toString().trim()) ?? 30;
    } catch (_) {
      return 30; // default to Android 11 behaviour
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  EXPORT
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetches ALL rows from [locationTrackingTable], builds a CSV, and saves
  /// it to [Downloads/LocationData/].
  ///
  /// [dateFilter] — optional. Pass 'yyyy-MM-dd' to export only that day.
  Future<ExportResult> exportToCSV({String? dateFilter}) async {
    try {
      // 1. Fetch rows ─────────────────────────────────────────────────────
      final rows = await _fetchRows(dateFilter: dateFilter);

      if (rows.isEmpty) {
        return const ExportResult(
          success: false,
          message: 'No location data found to export.',
        );
      }

      final int total = rows.length;
      final int posted = rows.where((r) => (r['posted'] as int? ?? 0) == 1).length;
      final int pending = total - posted;

      // 2. Build CSV ───────────────────────────────────────────────────────
      final csv = _buildCsv(rows);

      // 3. Resolve folder ──────────────────────────────────────────────────
      final folder = await _resolveExportFolder();
      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
        debugPrint('📁 [EXPORT] Created folder: ${folder.path}');
      }

      // 4. Write file ──────────────────────────────────────────────────────
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final suffix = dateFilter != null ? '_${dateFilter.replaceAll('-', '')}' : '';
      final fileName = 'LocationTracking$suffix\_$timestamp.csv';
      final file = File('${folder.path}/$fileName');

      await file.writeAsString(csv, flush: true);

      debugPrint('✅ [EXPORT] Saved ${rows.length} rows → ${file.path}');

      return ExportResult(
        success: true,
        filePath: file.path,
        message: 'Exported $total rows ($posted synced, $pending pending)\n'
            '📁 ${file.path}',
        totalRows: total,
        postedRows: posted,
        pendingRows: pending,
      );
    } catch (e, st) {
      debugPrint('❌ [EXPORT] Error: $e\n$st');
      return ExportResult(
        success: false,
        message: 'Export failed: $e',
      );
    }
  }

  // ── Fetch from SQLite ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchRows({String? dateFilter}) async {
    final db = await _dbHelper.db;
    if (dateFilter != null && dateFilter.isNotEmpty) {
      return db.query(
        locationTrackingTable,
        where: 'locationtracking_date = ?',
        whereArgs: [dateFilter],
        orderBy: 'locationtracking_date ASC, locationtracking_time ASC',
      );
    }
    return db.query(
      locationTrackingTable,
      orderBy: 'locationtracking_date ASC, locationtracking_time ASC',
    );
  }

  // ── CSV builder ───────────────────────────────────────────────────────────

  String _buildCsv(List<Map<String, dynamic>> rows) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln(
      'locationtracking_id,locationtracking_date,locationtracking_time,'
          'user_id,booker_name,designation,lat_in,lng_in,company_code,posted,sync_status',
    );

    for (final row in rows) {
      final isPosted = (row['posted'] as int? ?? 0) == 1;
      buffer.writeln(
        '${_escape(row['locationtracking_id'])},'
            '${_escape(row['locationtracking_date'])},'
            '${_escape(row['locationtracking_time'])},'
            '${_escape(row['user_id'])},'
            '${_escape(row['booker_name'])},'
            '${_escape(row['designation'])},'
            '${_escape(row['lat_in'])},'
            '${_escape(row['lng_in'])},'
            '${_escape(row['company_code'])},'
            '${isPosted ? 1 : 0},'
            '${isPosted ? 'SYNCED' : 'PENDING'}',
      );
    }

    return buffer.toString();
  }

  /// Wraps a cell in quotes if it contains commas, quotes, or newlines.
  String _escape(dynamic value) {
    final str = value?.toString() ?? '';
    if (str.contains(',') || str.contains('"') || str.contains('\n')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  // ── Folder resolution ─────────────────────────────────────────────────────

  /// Tries to return [Downloads/LocationData]. Falls back to the app's
  /// external storage scoped folder (no permission required on Android 11+).
  Future<Directory> _resolveExportFolder() async {
    try {
      // Primary: real Downloads folder (works when permission is granted)
      final downloadsDir = Directory('/storage/emulated/0/Downloads/$_folderName');
      return downloadsDir;
    } catch (e) {
      debugPrint('⚠️ [EXPORT] Downloads not accessible, using app dir: $e');
    }

    // Fallback: app-scoped external storage (always accessible, shows in
    // Android/data/<package>/files/LocationData/)
    final appDir = await getExternalStorageDirectory();
    return Directory('${appDir!.path}/$_folderName');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STATS (used by the export button badge)
  // ══════════════════════════════════════════════════════════════════════════

  Future<LocationExportStats> getStats() async {
    try {
      final db = await _dbHelper.db;
      final totalRes = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM $locationTrackingTable');
      final postedRes = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM $locationTrackingTable WHERE posted = 1');
      final total = totalRes.first['cnt'] as int? ?? 0;
      final posted = postedRes.first['cnt'] as int? ?? 0;
      return LocationExportStats(
          total: total, posted: posted, pending: total - posted);
    } catch (e) {
      debugPrint('❌ [EXPORT] getStats error: $e');
      return const LocationExportStats(total: 0, posted: 0, pending: 0);
    }
  }
}

// ── Supporting types ──────────────────────────────────────────────────────────

enum StoragePermissionResult {
  granted,
  denied,
  permanentlyDenied,
  fallbackAppDir, // permission not granted but we use app-scoped dir
}

class LocationExportStats {
  final int total;
  final int posted;
  final int pending;
  const LocationExportStats(
      {required this.total, required this.posted, required this.pending});
}