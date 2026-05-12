//
//
//
//
//
//
// import 'dart:convert';
// import 'package:flutter/cupertino.dart';
// import 'package:get/get.dart';
// import 'package:order_booking_app/Databases/util.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:path/path.dart' show join;
// import 'package:sqflite/sqflite.dart';
// import 'dart:io' as io;
// import 'dart:typed_data';
// import '../Models/leave_model.dart';
//
// class DBHelper extends GetxService {
//   static Database? _db;
//
//   Future<Database> get db async {
//     if (_db != null) return _db!;
//     _db = await initDatabase();
//     return _db!;
//   }
//
//   initDatabase() async {
//     io.Directory documentDirectory = await getApplicationDocumentsDirectory();
//     String path = join(documentDirectory.path, 'bookIt.db');
//
//     var db = openDatabase(
//       path,
//       version: 25, // Bumped to 23 for fake_gps_logs table
//       onCreate: _onCreate,
//       onUpgrade: _onUpgrade,
//     );
//
//     return db;
//   }
//
//   _onCreate(Database db, int version) async {
//     List<String> tableQueries = [
//       "CREATE TABLE IF NOT EXISTS $tableNameLogin(user_id TEXT , password TEXT ,user_name TEXT, city TEXT, designation TEXT,brand TEXT,rsm TEXT,sm TEXT,nsm TEXT,rsm_id TEXT,sm_id TEXT,nsm_id TEXT, dispatcher TEXT, dispatcher_id TEXT, images BLOB)",
//       "CREATE TABLE IF NOT EXISTS $addShopTableName(shop_id TEXT PRIMARY KEY, shop_date TEXT, shop_time TEXT, shop_name TEXT,city TEXT,shop_address TEXT,owner_name TEXT,owner_cnic TEXT,phone_no TEXT,address TEXT, alternative_phone_no TEXT,latitude TEXT, longitude TEXT, user_id TEXT, posted INTEGER DEFAULT 0 )",
//       "CREATE TABLE IF NOT EXISTS $shopVisitMasterTableName(shop_visit_master_id TEXT PRIMARY KEY, shop_visit_date TEXT, shop_visit_time TEXT, brand TEXT, shop_address TEXT,user_id TEXT, shop_name TEXT, address TEXT, latitude TEXT, longitude TEXT, city TEXT,owner_name TEXT,posted INTEGER DEFAULT 0, booker_name TEXT,walk_through TEXT,planogram TEXT,signage TEXT,product_reviewed TEXT,feedback TEXT,body BLOB)",
//       "CREATE TABLE IF NOT EXISTS $shopVisitDetailsTableName(shop_visit_details_id TEXT PRIMARY KEY, shop_visit_details_date TEXT, shop_visit_details_time TEXT,user_id TEXT, shop_visit_master_id TEXT, product TEXT, quantity TEXT,posted INTEGER DEFAULT 0, FOREIGN KEY(shop_visit_master_id) REFERENCES $shopVisitMasterTableName(shop_visit_master_id))",
//       "CREATE TABLE IF NOT EXISTS $orderMasterTableName(order_master_id TEXT PRIMARY KEY,order_status TEXT, order_master_date TEXT, order_master_time TEXT,user_id TEXT,user_name TEXT,shop_name TEXT,owner_name TEXT, phone_no TEXT,brand TEXT,total TEXT, credit_limit TEXT,city TEXT, posted INTEGER DEFAULT 0,required_delivery_date TEXT,rsm TEXT,sm TEXT,nsm TEXT,rsm_id TEXT,sm_id TEXT,nsm_id TEXT)",
//       "CREATE TABLE IF NOT EXISTS $orderMasterStatusTableName(order_master_id TEXT PRIMARY KEY,order_status TEXT, order_master_date TEXT, order_master_time TEXT,user_id TEXT,shop_name TEXT,owner_name TEXT, phone_no TEXT,brand TEXT,total TEXT, credit_limit TEXT, posted INTEGER DEFAULT 0,required_delivery_date TEXT)",
//       "CREATE TABLE IF NOT EXISTS $orderDetailsTableName (order_details_id TEXT PRIMARY KEY, order_details_date TEXT, order_details_time TEXT,user_id TEXT, order_master_id TEXT, product TEXT, quantity TEXT, in_stock TEXT, rate TEXT,posted INTEGER DEFAULT 0, amount TEXT, FOREIGN KEY(order_master_id) REFERENCES $orderMasterTableName(order_master_id))",
//       "CREATE TABLE IF NOT EXISTS $returnFormMasterTableName(return_master_id TEXT PRIMARY KEY, return_amount TEXT,return_master_date TEXT,user_id TEXT, return_master_time TEXT, posted INTEGER DEFAULT 0,select_shop TEXT)",
//       "CREATE TABLE IF NOT EXISTS $returnFormDetailsTableName(return_details_id TEXT PRIMARY KEY, return_details_date TEXT, return_details_time TEXT,user_id TEXT, return_master_id TEXT, item TEXT, quantity TEXT, reason TEXT,posted INTEGER DEFAULT 0, FOREIGN KEY(return_master_id) REFERENCES $returnFormMasterTableName(return_master_id))",
//       "CREATE TABLE IF NOT EXISTS $recoveryFormTableName(recovery_id TEXT PRIMARY KEY, recovery_date TEXT, recovery_time TEXT, shop_name TEXT,user_id TEXT,current_balance TEXT,cash_recovery TEXT,net_balance TEXT,posted INTEGER DEFAULT 0)",
//       // Replace with:
//       "CREATE TABLE IF NOT EXISTS $attendanceTableName(attendance_in_id TEXT PRIMARY KEY, attendance_in_date TEXT, attendance_in_time TEXT,user_id TEXT, lat_in TEXT, lng_in TEXT, booker_name TEXT,designation, city TEXT,posted INTEGER DEFAULT 0, address TEXT, battery INTEGER DEFAULT 0)","CREATE TABLE IF NOT EXISTS $attendanceOutTableName(attendance_out_id TEXT PRIMARY KEY, attendance_out_date TEXT, attendance_out_time TEXT,  total_time TEXT, user_id TEXT, lat_out TEXT, lng_out TEXT, total_distance TEXT,posted INTEGER DEFAULT 0, address TEXT, reason TEXT DEFAULT 'manual')",
//       "CREATE TABLE IF NOT EXISTS $locationTableName(location_id TEXT PRIMARY KEY, location_date TEXT, location_time TEXT, file_name TEXT, user_id TEXT, total_distance TEXT, booker_name TEXT, posted INTEGER DEFAULT 0, body BLOB)",
//       "CREATE TABLE IF NOT EXISTS $productsTableName(id NUMBER, product_code TEXT, product_name TEXT, uom TEXT ,price TEXT, brand TEXT, quantity TEXT, in_stock TEXT)",
//       "CREATE TABLE IF NOT EXISTS $headsShopVisitsTableName(shop_visit_master_id TEXT PRIMARY KEY, shop_visit_date TEXT,shop_visit_time TEXT,posted INTEGER DEFAULT 0, shop_name TEXT, user_id TEXT, city TEXT, booker_name TEXT, feedback TEXT, shop_address TEXT, booker_id TEXT)",
//       'CREATE TABLE IF NOT EXISTS $travelTimeData (id TEXT PRIMARY KEY, user_id TEXT,  travel_date TEXT, start_time TEXT, end_time TEXT, travel_distance REAL, travel_time REAL, average_speed REAL, working_time REAL, idle_time REAL, travel_type TEXT, latitude REAL, longitude REAL, address TEXT, posted INTEGER DEFAULT 0)',
//       '''CREATE TABLE $centralPoints(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         central_point_id TEXT UNIQUE,
//         user_id TEXT,
//         overall_center_lat REAL,
//         overall_center_lng REAL,
//         total_clusters INTEGER,
//         total_coordinates INTEGER,
//         processing_date TEXT,
//         booker_name TEXT,
//         cluster_data TEXT,
//         created_at TEXT,
//         cluster_area TEXT,
//         address_district TEXT,
//         stay_time_in_cluster REAL
//       )''',
//
//       // ✅ FAKE GPS TABLE
//       "CREATE TABLE IF NOT EXISTS $fakeGpsTable("
//           "id INTEGER PRIMARY KEY AUTOINCREMENT, "
//           "user_id TEXT NOT NULL, "
//           "booker_name TEXT, "
//           "designation TEXT, "
//           "real_latitude REAL, "
//           "real_longitude REAL, "
//           "real_address TEXT, "
//           "fake_latitude REAL, "
//           "fake_longitude REAL, "
//           "fake_address TEXT, "
//           "distance_km REAL, "
//           "detected_at TEXT NOT NULL, "
//           "posted INTEGER DEFAULT 0"
//           ")",
//
//       '''CREATE TABLE IF NOT EXISTS $leaveTable(
//           id TEXT PRIMARY KEY,
//           leave_id TEXT UNIQUE,
//           booker_id TEXT,
//           booker_name TEXT,
//           leave_type TEXT,
//           start_date TEXT,
//           end_date TEXT,
//           total_days INTEGER,
//           is_half_day INTEGER DEFAULT 0,
//           reason TEXT,
//           attachment_data BLOB,
//           attachment_image TEXT,
//           application_date TEXT,
//           application_time TEXT,
//           status TEXT DEFAULT 'pending',
//           posted INTEGER DEFAULT 0,
//           has_attachment INTEGER DEFAULT 0
//         )''',
//       "CREATE TABLE IF NOT EXISTS $locationTrackingTable(locationtracking_id TEXT PRIMARY KEY, locationtracking_date TEXT, locationtracking_time TEXT, user_id TEXT, lat_in TEXT, lng_in TEXT, booker_name TEXT, designation TEXT, company_code TEXT, posted INTEGER DEFAULT 0)",
//
//       // ✅ Login Tracking Table with device info columns (NO sim_number)
//       "CREATE TABLE IF NOT EXISTS $loginTrackingTable("
//           "id TEXT PRIMARY KEY, "
//           "booker_name TEXT, "
//           "user_id TEXT, "
//           "login_time TEXT, "
//           "login_date TEXT, "
//           "designation TEXT, "
//           "company_code TEXT, "
//           "posted INTEGER DEFAULT 0, "
//           "android_version TEXT, "
//           "device_id TEXT, "
//           "device_info TEXT"
//           ")"
//     ];
//
//     debugPrint('✅ All tables created successfully - Version 23');
//
//     for (var query in tableQueries) {
//       await db.execute(query);
//     }
//   }
//
//   _onUpgrade(Database db, int oldVersion, int newVersion) async {
//     debugPrint('🔄 Upgrading database from version $oldVersion to $newVersion');
//
//     // Leave table migration (v15)
//     if (oldVersion < 15) {
//       try {
//         final columns = await db.rawQuery("PRAGMA table_info($leaveTable)");
//         final columnNames = columns.map((c) => c['name'] as String).toList();
//
//         if (!columnNames.contains('attachment_image')) {
//           await db.execute("ALTER TABLE $leaveTable ADD COLUMN attachment_image TEXT");
//           debugPrint('✅ Added attachment_image column');
//         }
//
//         if (!columnNames.contains('has_attachment')) {
//           await db.execute("ALTER TABLE $leaveTable ADD COLUMN has_attachment INTEGER DEFAULT 0");
//           debugPrint('✅ Added has_attachment column');
//         }
//
//         if (columns.isEmpty) {
//           await db.execute('''
//           CREATE TABLE IF NOT EXISTS $leaveTable(
//             id TEXT PRIMARY KEY,
//             leave_id TEXT UNIQUE,
//             booker_id TEXT,
//             booker_name TEXT,
//             leave_type TEXT,
//             start_date TEXT,
//             end_date TEXT,
//             total_days INTEGER,
//             is_half_day INTEGER DEFAULT 0,
//             reason TEXT,
//             attachment_data BLOB,
//             attachment_image TEXT,
//             application_date TEXT,
//             application_time TEXT,
//             status TEXT DEFAULT 'pending',
//             posted INTEGER DEFAULT 0,
//             has_attachment INTEGER DEFAULT 0
//           )
//         ''');
//           debugPrint('✅ Created fresh leaveTable');
//         }
//       } catch (e) {
//         debugPrint('❌ Leave table migration error: $e');
//       }
//     }
//
//     // Attendance table migration
//     try {
//       final attendanceColumns = await db.rawQuery("PRAGMA table_info($attendanceTableName)");
//       final attendanceColumnNames = attendanceColumns.map((c) => c['name'] as String).toList();
//
//       if (!attendanceColumnNames.contains('reason')) {
//         await db.execute("ALTER TABLE $attendanceTableName ADD COLUMN reason TEXT");
//         debugPrint('✅ Added reason column to attendance table');
//       }
//     } catch (e) {
//       debugPrint('❌ Attendance table migration error: $e');
//     }
//
//     // Location tracking table creation (v16)
//     if (oldVersion < 16) {
//       try {
//         await db.execute(
//           "CREATE TABLE IF NOT EXISTS $locationTrackingTable("
//               "locationtracking_id TEXT PRIMARY KEY, "
//               "locationtracking_date TEXT, "
//               "locationtracking_time TEXT, "
//               "user_id TEXT, "
//               "lat_in TEXT, "
//               "lng_in TEXT, "
//               "booker_name TEXT, "
//               "designation TEXT, "
//               "company_code TEXT, "
//               "posted INTEGER DEFAULT 0"
//               ")",
//         );
//         debugPrint('✅ location_tracking table created (v16 migration)');
//       } catch (e) {
//         debugPrint('❌ location_tracking table migration error: $e');
//       }
//     }
//
//     // Company code column for location tracking (v17)
//     if (oldVersion < 17) {
//       try {
//         final columns = await db.rawQuery("PRAGMA table_info($locationTrackingTable)");
//         final columnNames = columns.map((c) => c['name'] as String).toList();
//
//         if (!columnNames.contains('company_code')) {
//           await db.execute("ALTER TABLE $locationTrackingTable ADD COLUMN company_code TEXT DEFAULT ''");
//           debugPrint('✅ Added company_code column to locationTrackingTable');
//         }
//       } catch (e) {
//         debugPrint('❌ Error adding company_code column: $e');
//       }
//     }
//
//     // Login tracking table creation (v18)
//     if (oldVersion < 18) {
//       try {
//         final columns = await db.rawQuery("PRAGMA table_info($loginTrackingTable)");
//         if (columns.isEmpty) {
//           await db.execute(
//               "CREATE TABLE IF NOT EXISTS $loginTrackingTable("
//                   "id TEXT PRIMARY KEY, "
//                   "booker_name TEXT, "
//                   "user_id TEXT, "
//                   "login_time TEXT, "
//                   "login_date TEXT, "
//                   "designation TEXT, "
//                   "company_code TEXT, "
//                   "posted INTEGER DEFAULT 0"
//                   ")"
//           );
//           debugPrint('✅ loginTrackingTable created (v18 migration)');
//         }
//       } catch (e) {
//         debugPrint('❌ loginTrackingTable migration error: $e');
//       }
//     }
//
//     // Add device info columns to loginTrackingTable (v19)
//     if (oldVersion < 19) {
//       try {
//         final columns = await db.rawQuery("PRAGMA table_info($loginTrackingTable)");
//         final columnNames = columns.map((c) => c['name'] as String).toList();
//
//         if (!columnNames.contains('android_version')) {
//           await db.execute("ALTER TABLE $loginTrackingTable ADD COLUMN android_version TEXT");
//           debugPrint('✅ Added android_version column to loginTrackingTable');
//         }
//         if (!columnNames.contains('device_id')) {
//           await db.execute("ALTER TABLE $loginTrackingTable ADD COLUMN device_id TEXT");
//           debugPrint('✅ Added device_id column to loginTrackingTable');
//         }
//         if (!columnNames.contains('sim_info')) {
//           await db.execute("ALTER TABLE $loginTrackingTable ADD COLUMN sim_info TEXT");
//           debugPrint('✅ Added sim_info column to loginTrackingTable');
//         }
//       } catch (e) {
//         debugPrint('❌ Error adding device info columns to loginTrackingTable: $e');
//       }
//     }
//
//     // Remove sim_number column if it exists (v21)
//     if (oldVersion < 21) {
//       try {
//         final columns = await db.rawQuery("PRAGMA table_info($loginTrackingTable)");
//         final columnNames = columns.map((c) => c['name'] as String).toList();
//
//         if (columnNames.contains('sim_number')) {
//           debugPrint('🔄 Removing sim_number column from loginTrackingTable...');
//           await db.execute('''
//             CREATE TABLE ${loginTrackingTable}_new (
//               id TEXT PRIMARY KEY,
//               booker_name TEXT,
//               user_id TEXT,
//               login_time TEXT,
//               login_date TEXT,
//               designation TEXT,
//               company_code TEXT,
//               posted INTEGER DEFAULT 0,
//               android_version TEXT,
//               device_id TEXT,
//               sim_info TEXT
//             )
//           ''');
//           await db.execute('''
//             INSERT INTO ${loginTrackingTable}_new (
//               id, booker_name, user_id, login_time, login_date,
//               designation, company_code, posted, android_version, device_id, sim_info
//             )
//             SELECT
//               id, booker_name, user_id, login_time, login_date,
//               designation, company_code, posted, android_version, device_id, sim_info
//             FROM $loginTrackingTable
//           ''');
//           await db.execute('DROP TABLE $loginTrackingTable');
//           await db.execute('ALTER TABLE ${loginTrackingTable}_new RENAME TO $loginTrackingTable');
//           debugPrint('✅ Removed sim_number column from loginTrackingTable');
//         }
//       } catch (e) {
//         debugPrint('❌ Error removing sim_number column: $e');
//       }
//     }
//
//     // Migrate sim_info to device_info (v22)
//     if (oldVersion < 22) {
//       try {
//         final columns = await db.rawQuery("PRAGMA table_info($loginTrackingTable)");
//         final columnNames = columns.map((c) => c['name'] as String).toList();
//
//         if (columnNames.contains('sim_info')) {
//           await db.execute('''
//             CREATE TABLE ${loginTrackingTable}_new (
//               id TEXT PRIMARY KEY,
//               booker_name TEXT,
//               user_id TEXT,
//               login_time TEXT,
//               login_date TEXT,
//               designation TEXT,
//               company_code TEXT,
//               posted INTEGER DEFAULT 0,
//               android_version TEXT,
//               device_id TEXT,
//               device_info TEXT
//             )
//           ''');
//           await db.execute('''
//             INSERT INTO ${loginTrackingTable}_new (
//               id, booker_name, user_id, login_time, login_date,
//               designation, company_code, posted, android_version, device_id, device_info
//             )
//             SELECT
//               id, booker_name, user_id, login_time, login_date,
//               designation, company_code, posted, android_version, device_id, sim_info
//             FROM $loginTrackingTable
//           ''');
//           await db.execute('DROP TABLE $loginTrackingTable');
//           await db.execute('ALTER TABLE ${loginTrackingTable}_new RENAME TO $loginTrackingTable');
//           debugPrint('✅ Migrated loginTrackingTable: removed sim_info, added device_info');
//         } else if (!columnNames.contains('device_info')) {
//           await db.execute("ALTER TABLE $loginTrackingTable ADD COLUMN device_info TEXT");
//           debugPrint('✅ Added device_info column');
//         }
//       } catch (e) {
//         debugPrint('❌ LoginTracking migration error: $e');
//       }
//     }
//
//     // Create fake_gps_logs table if missing (v23)
//     if (oldVersion < 23) {
//       try {
//         await db.execute('''
//           CREATE TABLE IF NOT EXISTS $fakeGpsTable(
//             id INTEGER PRIMARY KEY AUTOINCREMENT,
//             user_id TEXT NOT NULL,
//             booker_name TEXT,
//             designation TEXT,
//             real_latitude REAL,
//             real_longitude REAL,
//             real_address TEXT,
//             fake_latitude REAL,
//             fake_longitude REAL,
//             fake_address TEXT,
//             distance_km REAL,
//             detected_at TEXT NOT NULL,
//             posted INTEGER DEFAULT 0
//           )
//         ''');
//         debugPrint('✅ fake_gps_logs table created (v23 migration)');
//       } catch (e) {
//         debugPrint('❌ Error creating fake_gps_logs table: $e');
//       }
//     }
//
//     _onUpgrade(Database db, int oldVersion, int newVersion) async {
//       debugPrint('🔄 Upgrading database from version $oldVersion to $newVersion');
//
//       // ✅ ADD THIS BLOCK — migrate battery column
//       if (oldVersion < 25) {  // use your current version number
//         try {
//           final columns = await db.rawQuery("PRAGMA table_info($attendanceTableName)");
//           final columnNames = columns.map((c) => c['name'] as String).toList();
//
//           if (!columnNames.contains('battery')) {
//             await db.execute(
//                 "ALTER TABLE $attendanceTableName ADD COLUMN battery INTEGER DEFAULT 0"
//             );
//             debugPrint('✅ Added battery column to $attendanceTableName');
//           }
//         } catch (e) {
//           debugPrint('❌ Battery column migration error: $e');
//         }
//       }
//     }
//
//     debugPrint('✅ Database upgrade finished');
//   }
//
//   // =====================================================================
//   // LOCATION TRACKING CRUD
//   // =====================================================================
//
//   Future<int> insertLocationTracking(Map<String, dynamic> data) async {
//     try {
//       final db = await this.db;
//       final result = await db.insert(
//         locationTrackingTable,
//         data,
//         conflictAlgorithm: ConflictAlgorithm.replace,
//       );
//       debugPrint('📍 [GPS] Inserted tracking row: ${data['locationtracking_id']}');
//       return result;
//     } catch (e) {
//       debugPrint('❌ [GPS] Error inserting location tracking: $e');
//       return 0;
//     }
//   }
//
//   Future<List<Map<String, dynamic>>> getUnpostedLocationTracking() async {
//     try {
//       final db = await this.db;
//       final result = await db.query(
//         locationTrackingTable,
//         where: 'posted = ?',
//         whereArgs: [0],
//         orderBy: 'locationtracking_date ASC, locationtracking_time ASC',
//       );
//       debugPrint('📋 [GPS] Unposted tracking rows: ${result.length}');
//       return result;
//     } catch (e) {
//       debugPrint('❌ [GPS] Error fetching unposted tracking rows: $e');
//       return [];
//     }
//   }
//
//   Future<List<Map<String, dynamic>>> getUnpostedLocationTrackingByCompany(String companyCode) async {
//     try {
//       final db = await this.db;
//       final result = await db.query(
//         locationTrackingTable,
//         where: 'posted = ? AND company_code = ?',
//         whereArgs: [0, companyCode],
//         orderBy: 'locationtracking_date ASC, locationtracking_time ASC',
//       );
//       debugPrint('📋 [GPS] Unposted tracking rows for company $companyCode: ${result.length}');
//       return result;
//     } catch (e) {
//       debugPrint('❌ [GPS] Error fetching unposted tracking rows by company: $e');
//       return [];
//     }
//   }
//
//   Future<List<Map<String, dynamic>>> getLocationTrackingByUserAndDate(
//       String userId, String date, {String? companyCode}) async {
//     try {
//       final db = await this.db;
//       String where = 'user_id = ? AND locationtracking_date = ?';
//       List<dynamic> whereArgs = [userId, date];
//
//       if (companyCode != null && companyCode.isNotEmpty) {
//         where += ' AND company_code = ?';
//         whereArgs.add(companyCode);
//       }
//
//       final result = await db.query(
//         locationTrackingTable,
//         where: where,
//         whereArgs: whereArgs,
//         orderBy: 'locationtracking_time ASC',
//       );
//       debugPrint('📋 [GPS] Rows for user $userId on $date: ${result.length}');
//       return result;
//     } catch (e) {
//       debugPrint('❌ [GPS] Error fetching tracking by user/date: $e');
//       return [];
//     }
//   }
//
//   Future<void> markLocationTrackingAsPosted(List<String> ids) async {
//     if (ids.isEmpty) return;
//     try {
//       final db = await this.db;
//       final placeholders = ids.map((_) => '?').join(', ');
//       await db.rawUpdate(
//         "UPDATE $locationTrackingTable SET posted = 1 WHERE locationtracking_id IN ($placeholders)",
//         ids,
//       );
//       debugPrint('✅ [GPS] Marked ${ids.length} rows as posted');
//     } catch (e) {
//       debugPrint('❌ [GPS] Error marking rows as posted: $e');
//     }
//   }
//
//   Future<int> backfillCompanyCode(String companyCode) async {
//     if (companyCode.isEmpty) return 0;
//     try {
//       final db = await this.db;
//       final count = await db.rawUpdate(
//         "UPDATE $locationTrackingTable SET company_code = ? "
//             "WHERE (company_code IS NULL OR company_code = '') AND posted = 0",
//         [companyCode],
//       );
//       if (count > 0) {
//         debugPrint('🔄 [GPS] Backfilled company_code on $count unposted rows');
//       }
//       return count;
//     } catch (e) {
//       debugPrint('❌ [GPS] Error backfilling company_code: $e');
//       return 0;
//     }
//   }
//
//   Future<void> deleteLocationTrackingByDate(String date) async {
//     try {
//       final db = await this.db;
//       final deleted = await db.delete(
//         locationTrackingTable,
//         where: 'locationtracking_date = ?',
//         whereArgs: [date],
//       );
//       debugPrint('🗑️ [GPS] Deleted $deleted rows for date $date');
//     } catch (e) {
//       debugPrint('❌ [GPS] Error deleting tracking rows: $e');
//     }
//   }
//
//   Future<int> countTodayLocationTracking(String userId, String date) async {
//     try {
//       final db = await this.db;
//       final result = await db.rawQuery(
//         "SELECT COUNT(*) as cnt FROM $locationTrackingTable WHERE user_id = ? AND locationtracking_date = ?",
//         [userId, date],
//       );
//       return result.first['cnt'] as int? ?? 0;
//     } catch (e) {
//       debugPrint('❌ [GPS] Error counting today rows: $e');
//       return 0;
//     }
//   }
//
//   Future<int?> getHighestLocationSerial(String day, String month, {String? companyCode}) async {
//     final dbClient = await this.db;
//
//     if (companyCode != null && companyCode.isNotEmpty) {
//       final result = await dbClient.rawQuery(
//           'SELECT MAX(CAST(SUBSTR(locationtracking_id, -3) AS INTEGER)) as max_serial '
//               'FROM $locationTrackingTable '
//               'WHERE locationtracking_id LIKE ? AND company_code = ?',
//           ['%$day-$month-%', companyCode]
//       );
//       if (result.isNotEmpty && result.first['max_serial'] != null) {
//         return result.first['max_serial'] as int;
//       }
//     } else {
//       final result = await dbClient.rawQuery(
//           'SELECT MAX(CAST(SUBSTR(locationtracking_id, -3) AS INTEGER)) as max_serial '
//               'FROM $locationTrackingTable '
//               'WHERE locationtracking_id LIKE ?',
//           ['%$day-$month-%']
//       );
//       if (result.isNotEmpty && result.first['max_serial'] != null) {
//         return result.first['max_serial'] as int;
//       }
//     }
//     return null;
//   }
//
//   Future<List<Map<String, dynamic>>> getAllLocationTracking() async {
//     try {
//       final db = await this.db;
//       final result = await db.query(
//         locationTrackingTable,
//         orderBy: 'locationtracking_date ASC, locationtracking_time ASC',
//       );
//       debugPrint('📋 [GPS] All tracking rows: ${result.length}');
//       return result;
//     } catch (e) {
//       debugPrint('❌ [GPS] Error fetching all tracking rows: $e');
//       return [];
//     }
//   }
//
//   Future<List<Map<String, dynamic>>> getPostedLocationTracking() async {
//     try {
//       final db = await this.db;
//       final result = await db.query(
//         locationTrackingTable,
//         where: 'posted = ?',
//         whereArgs: [1],
//         orderBy: 'locationtracking_date ASC, locationtracking_time ASC',
//       );
//       debugPrint('📋 [GPS] Posted tracking rows: ${result.length}');
//       return result;
//     } catch (e) {
//       debugPrint('❌ [GPS] Error fetching posted tracking rows: $e');
//       return [];
//     }
//   }
//
//   Future<Map<String, int>> getLocationTrackingStats() async {
//     try {
//       final db = await this.db;
//       final totalResult = await db.rawQuery("SELECT COUNT(*) as total FROM $locationTrackingTable");
//       int total = totalResult.first['total'] as int? ?? 0;
//       final postedResult = await db.rawQuery("SELECT COUNT(*) as posted FROM $locationTrackingTable WHERE posted = 1");
//       int posted = postedResult.first['posted'] as int? ?? 0;
//       final pendingResult = await db.rawQuery("SELECT COUNT(*) as pending FROM $locationTrackingTable WHERE posted = 0");
//       int pending = pendingResult.first['pending'] as int? ?? 0;
//       debugPrint('📊 [GPS] Stats - Total: $total, Posted: $posted, Pending: $pending');
//       return {'total': total, 'posted': posted, 'pending': pending};
//     } catch (e) {
//       debugPrint('❌ [GPS] Error getting stats: $e');
//       return {'total': 0, 'posted': 0, 'pending': 0};
//     }
//   }
//
//   // =====================================================================
//   // LOGIN TRACKING CRUD (with device info - NO sim_number)
//   // =====================================================================
//
//   Future<int> insertLoginTracking(Map<String, dynamic> data) async {
//     try {
//       final db = await this.db;
//       final result = await db.insert(
//         loginTrackingTable,
//         data,
//         conflictAlgorithm: ConflictAlgorithm.replace,
//       );
//       debugPrint('✅ [LoginTracking] Inserted: ${data['id']}');
//       if (data.containsKey('android_version')) {
//         debugPrint('   📱 Android Version: ${data['android_version']}');
//         debugPrint('   🆔 Device ID: ${data['device_id']}');
//       }
//       return result;
//     } catch (e) {
//       debugPrint('❌ [LoginTracking] Error inserting: $e');
//       return 0;
//     }
//   }
//
//   Future<List<Map<String, dynamic>>> getUnpostedLoginTracking() async {
//     try {
//       final db = await this.db;
//       final result = await db.query(
//         loginTrackingTable,
//         where: 'posted = ?',
//         whereArgs: [0],
//         orderBy: 'login_date ASC, login_time ASC',
//       );
//       debugPrint('📋 [LoginTracking] Unposted rows: ${result.length}');
//       return result;
//     } catch (e) {
//       debugPrint('❌ [LoginTracking] Error fetching unposted: $e');
//       return [];
//     }
//   }
//
//   Future<List<Map<String, dynamic>>> getAllLoginTracking() async {
//     try {
//       final db = await this.db;
//       final result = await db.query(
//         loginTrackingTable,
//         orderBy: 'login_date DESC, login_time DESC',
//       );
//       debugPrint('📋 [LoginTracking] All rows: ${result.length}');
//       return result;
//     } catch (e) {
//       debugPrint('❌ [LoginTracking] Error fetching all: $e');
//       return [];
//     }
//   }
//
//   Future<void> markLoginTrackingAsPosted(List<String> ids) async {
//     if (ids.isEmpty) return;
//     try {
//       final db = await this.db;
//       final placeholders = ids.map((_) => '?').join(', ');
//       await db.rawUpdate(
//         "UPDATE $loginTrackingTable SET posted = 1 WHERE id IN ($placeholders)",
//         ids,
//       );
//       debugPrint('✅ [LoginTracking] Marked ${ids.length} rows as posted');
//     } catch (e) {
//       debugPrint('❌ [LoginTracking] Error marking as posted: $e');
//     }
//   }
//
//   Future<List<Map<String, dynamic>>> getLoginTrackingByUserAndDate(
//       String userId, String date) async {
//     try {
//       final db = await this.db;
//       final result = await db.query(
//         loginTrackingTable,
//         where: 'user_id = ? AND login_date = ?',
//         whereArgs: [userId, date],
//         orderBy: 'login_time ASC',
//       );
//       debugPrint('📋 [LoginTracking] Rows for user $userId on $date: ${result.length}');
//       return result;
//     } catch (e) {
//       debugPrint('❌ [LoginTracking] Error fetching by user/date: $e');
//       return [];
//     }
//   }
//
//   Future<List<Map<String, dynamic>>> getLoginTrackingByCompany(String companyCode) async {
//     try {
//       final db = await this.db;
//       final result = await db.query(
//         loginTrackingTable,
//         where: 'company_code = ?',
//         whereArgs: [companyCode],
//         orderBy: 'login_date DESC, login_time DESC',
//       );
//       debugPrint('📋 [LoginTracking] Rows for company $companyCode: ${result.length}');
//       return result;
//     } catch (e) {
//       debugPrint('❌ [LoginTracking] Error fetching by company: $e');
//       return [];
//     }
//   }
//
//   Future<void> deleteLoginTrackingByDate(String date) async {
//     try {
//       final db = await this.db;
//       final deleted = await db.delete(
//         loginTrackingTable,
//         where: 'login_date = ?',
//         whereArgs: [date],
//       );
//       debugPrint('🗑️ [LoginTracking] Deleted $deleted rows for date $date');
//     } catch (e) {
//       debugPrint('❌ [LoginTracking] Error deleting: $e');
//     }
//   }
//
//   Future<void> deleteAllLoginTracking() async {
//     try {
//       final db = await this.db;
//       final deleted = await db.delete(loginTrackingTable);
//       debugPrint('🗑️ [LoginTracking] Deleted all $deleted rows');
//     } catch (e) {
//       debugPrint('❌ [LoginTracking] Error deleting all: $e');
//     }
//   }
//
//   Future<Map<String, dynamic>> getLoginTrackingStats() async {
//     try {
//       final db = await this.db;
//       final totalResult = await db.rawQuery("SELECT COUNT(*) as total FROM $loginTrackingTable");
//       int total = totalResult.first['total'] as int? ?? 0;
//       final postedResult = await db.rawQuery("SELECT COUNT(*) as posted FROM $loginTrackingTable WHERE posted = 1");
//       int posted = postedResult.first['posted'] as int? ?? 0;
//       final pendingResult = await db.rawQuery("SELECT COUNT(*) as pending FROM $loginTrackingTable WHERE posted = 0");
//       int pending = pendingResult.first['pending'] as int? ?? 0;
//       final devicesResult = await db.rawQuery(
//           "SELECT device_id, COUNT(*) as count FROM $loginTrackingTable WHERE device_id IS NOT NULL GROUP BY device_id"
//       );
//       final androidVersionsResult = await db.rawQuery(
//           "SELECT android_version, COUNT(*) as count FROM $loginTrackingTable WHERE android_version IS NOT NULL GROUP BY android_version"
//       );
//       debugPrint('📊 [LoginTracking] Stats - Total: $total, Posted: $posted, Pending: $pending');
//       debugPrint('📊 [LoginTracking] Unique devices: ${devicesResult.length}');
//       debugPrint('📊 [LoginTracking] Android versions: ${androidVersionsResult.length}');
//       return {
//         'total': total,
//         'posted': posted,
//         'pending': pending,
//         'uniqueDevices': devicesResult.length,
//         'androidVersionsCount': androidVersionsResult.length,
//       };
//     } catch (e) {
//       debugPrint('❌ [LoginTracking] Error getting stats: $e');
//       return {'total': 0, 'posted': 0, 'pending': 0};
//     }
//   }
//
//   Future<Map<String, dynamic>?> getDeviceInfoForLogin(String loginId) async {
//     try {
//       final db = await this.db;
//       final result = await db.query(
//         loginTrackingTable,
//         columns: ['android_version', 'device_id'],
//         where: 'id = ?',
//         whereArgs: [loginId],
//       );
//       if (result.isNotEmpty) {
//         return result.first;
//       }
//       return null;
//     } catch (e) {
//       debugPrint('❌ [LoginTracking] Error getting device info: $e');
//       return null;
//     }
//   }
//
//   // =====================================================================
//   // GENERAL UTILITIES
//   // =====================================================================
//
//   Future<void> clearData() async {
//     final db = await this.db;
//     List<String> tableNames = [productsTableName];
//     for (var tableName in tableNames) {
//       await db.execute("DELETE FROM $tableName");
//     }
//   }
//
//   // =====================================================================
//   // LEAVE TABLE CRUD
//   // =====================================================================
//
//   Future<int> insertLeave(LeaveModel leave) async {
//     try {
//       final db = await this.db;
//       DateTime now = DateTime.now();
//       String day = now.day.toString().padLeft(2, '0');
//       String monthAbbrev = _getMonthAbbreviation(now.month);
//       int sequence = await _getLeaveSequenceForDay(now);
//       String sequenceStr = sequence.toString().padLeft(3, '0');
//       String leaveId = 'LV-${leave.bookerId}-$day-$monthAbbrev-$sequenceStr';
//
//       String? attachmentImage;
//       if (leave.attachmentData != null) {
//         attachmentImage = 'leave_${leave.bookerId}_${now.millisecondsSinceEpoch}.jpg';
//       }
//
//       final data = {
//         'id': now.millisecondsSinceEpoch.toString(),
//         'leave_id': leaveId,
//         'booker_id': leave.bookerId,
//         'booker_name': leave.bookerName ?? '',
//         'leave_type': leave.leaveType,
//         'start_date': leave.startDate,
//         'end_date': leave.endDate,
//         'total_days': leave.totalDays,
//         'is_half_day': leave.isHalfDay ? 1 : 0,
//         'reason': leave.reason,
//         'attachment_data': leave.attachmentData,
//         'attachment_image': attachmentImage,
//         'application_date': now.toIso8601String().split('T')[0],
//         'application_time': "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}",
//         'status': leave.status ?? 'pending',
//         'posted': 0,
//         'has_attachment': leave.attachmentData != null ? 1 : 0,
//       };
//
//       final result = await db.insert(leaveTable, data, conflictAlgorithm: ConflictAlgorithm.replace);
//       debugPrint('✅ Leave inserted with ID: $result, Leave ID: $leaveId');
//       return result;
//     } catch (e) {
//       debugPrint('❌ Error inserting leave: $e');
//       return 0;
//     }
//   }
//
//   String _getMonthAbbreviation(int month) {
//     switch (month) {
//       case 1: return 'Jan';
//       case 2: return 'Feb';
//       case 3: return 'Mar';
//       case 4: return 'Apr';
//       case 5: return 'May';
//       case 6: return 'Jun';
//       case 7: return 'Jul';
//       case 8: return 'Aug';
//       case 9: return 'Sep';
//       case 10: return 'Oct';
//       case 11: return 'Nov';
//       case 12: return 'Dec';
//       default: return '---';
//     }
//   }
//
//   Future<int> _getLeaveSequenceForDay(DateTime date) async {
//     try {
//       final db = await this.db;
//       String dateStr = date.toIso8601String().split('T')[0];
//       final result = await db.rawQuery('''
//         SELECT COUNT(*) as count FROM $leaveTable
//         WHERE application_date = ?
//       ''', [dateStr]);
//       int count = result.first['count'] as int? ?? 0;
//       return count + 1;
//     } catch (e) {
//       debugPrint('❌ Error getting leave sequence: $e');
//       return 1;
//     }
//   }
//
//   Future<int> markLeaveAsPosted(String leaveId) async {
//     try {
//       final db = await this.db;
//       final result = await db.update(
//         leaveTable,
//         {'posted': 1},
//         where: 'leave_id = ?',
//         whereArgs: [leaveId],
//       );
//       if (result > 0) {
//         debugPrint('✅ Leave marked as posted successfully');
//       }
//       return result;
//     } catch (e) {
//       debugPrint('❌ Error marking leave as posted: $e');
//       return 0;
//     }
//   }
//
//   Future<List<Map<String, dynamic>>> getLeavesByBookerId(String bookerId) async {
//     try {
//       final db = await this.db;
//       final leaves = await db.query(
//         leaveTable,
//         columns: [
//           'id', 'leave_id', 'booker_id', 'booker_name', 'leave_type',
//           'start_date', 'end_date', 'total_days', 'is_half_day', 'reason',
//           'attachment_image', 'application_date', 'application_time', 'status', 'posted', 'has_attachment'
//         ],
//         where: 'booker_id = ?',
//         whereArgs: [bookerId],
//         orderBy: 'application_date DESC, application_time DESC',
//       );
//       return leaves;
//     } catch (e) {
//       debugPrint('❌ Error fetching leaves: $e');
//       return [];
//     }
//   }
//
//   Future<Uint8List?> getLeaveAttachment(String leaveId) async {
//     try {
//       final db = await this.db;
//       final result = await db.query(
//         leaveTable,
//         columns: ['attachment_data'],
//         where: 'leave_id = ?',
//         whereArgs: [leaveId],
//         limit: 1,
//       );
//       if (result.isNotEmpty && result.first['attachment_data'] != null) {
//         final blobData = result.first['attachment_data'];
//         if (blobData is Uint8List) {
//           return blobData;
//         } else if (blobData is List<int>) {
//           return Uint8List.fromList(blobData);
//         }
//       }
//       return null;
//     } catch (e) {
//       debugPrint('❌ Error fetching attachment: $e');
//       return null;
//     }
//   }
//
//   Future<List<Map<String, dynamic>>> getPendingLeaves() async {
//     try {
//       final db = await this.db;
//       final leaves = await db.query(
//         leaveTable,
//         columns: [
//           'id', 'leave_id', 'booker_id', 'booker_name', 'leave_type',
//           'start_date', 'end_date', 'total_days', 'is_half_day', 'reason',
//           'attachment_image', 'application_date', 'application_time', 'status', 'posted', 'has_attachment'
//         ],
//         where: 'posted = ?',
//         whereArgs: [0],
//         orderBy: 'application_date DESC, application_time DESC',
//       );
//       return leaves;
//     } catch (e) {
//       debugPrint('❌ Error fetching pending leaves: $e');
//       return [];
//     }
//   }
//
//   Future<List<Map<String, dynamic>>> getPendingLeavesWithAttachments() async {
//     try {
//       final db = await this.db;
//       final leaves = await db.query(
//         leaveTable,
//         where: 'posted = ?',
//         whereArgs: [0],
//         orderBy: 'application_date DESC, application_time DESC',
//       );
//       for (var leave in leaves) {
//         if (leave['attachment_data'] != null && leave['attachment_data'] is List<int>) {
//           leave['attachment_data'] = Uint8List.fromList(leave['attachment_data'] as List<int>);
//         }
//       }
//       return leaves;
//     } catch (e) {
//       debugPrint('❌ Error fetching pending leaves with attachments: $e');
//       return [];
//     }
//   }
//
//   // =====================================================================
//   // FAKE GPS LOGS CRUD
//   // =====================================================================
//
//   Future<int> insertFakeGpsLog(Map<String, dynamic> data) async {
//     try {
//       final db = await this.db;
//       final result = await db.insert(
//         fakeGpsTable,
//         data,
//         conflictAlgorithm: ConflictAlgorithm.replace,
//       );
//       debugPrint('🚨 [FakeGPS] Inserted log at: ${data['detected_at']}');
//       return result;
//     } catch (e) {
//       debugPrint('❌ [FakeGPS] Error inserting log: $e');
//       return 0;
//     }
//   }
//
//   Future<List<Map<String, dynamic>>> getUnpostedFakeGpsLogs() async {
//     try {
//       final db = await this.db;
//       final result = await db.query(
//         fakeGpsTable,
//         where: 'posted = ?',
//         whereArgs: [0],
//         orderBy: 'detected_at ASC',
//       );
//       debugPrint('📋 [FakeGPS] Unposted logs: ${result.length}');
//       return result;
//     } catch (e) {
//       debugPrint('❌ [FakeGPS] Error fetching unposted logs: $e');
//       return [];
//     }
//   }
//
//   Future<List<Map<String, dynamic>>> getAllFakeGpsLogs() async {
//     try {
//       final db = await this.db;
//       final result = await db.query(
//         fakeGpsTable,
//         orderBy: 'detected_at DESC',
//       );
//       debugPrint('📋 [FakeGPS] All logs: ${result.length}');
//       return result;
//     } catch (e) {
//       debugPrint('❌ [FakeGPS] Error fetching all logs: $e');
//       return [];
//     }
//   }
//
//   Future<List<Map<String, dynamic>>> getFakeGpsLogsByUser(String userId) async {
//     try {
//       final db = await this.db;
//       final result = await db.query(
//         fakeGpsTable,
//         where: 'user_id = ?',
//         whereArgs: [userId],
//         orderBy: 'detected_at DESC',
//       );
//       debugPrint('📋 [FakeGPS] Logs for user $userId: ${result.length}');
//       return result;
//     } catch (e) {
//       debugPrint('❌ [FakeGPS] Error fetching logs by user: $e');
//       return [];
//     }
//   }
//
//   Future<int> markFakeGpsAsPosted(int id) async {
//     try {
//       final db = await this.db;
//       final result = await db.update(
//         fakeGpsTable,
//         {'posted': 1},
//         where: 'id = ?',
//         whereArgs: [id],
//       );
//       debugPrint('✅ [FakeGPS] Marked id $id as posted');
//       return result;
//     } catch (e) {
//       debugPrint('❌ [FakeGPS] Error marking as posted: $e');
//       return 0;
//     }
//   }
//
//   Future<int> markAllFakeGpsAsPosted(List<int> ids) async {
//     if (ids.isEmpty) return 0;
//     try {
//       final db = await this.db;
//       final placeholders = ids.map((_) => '?').join(',');
//       final result = await db.rawUpdate(
//         'UPDATE $fakeGpsTable SET posted = 1 WHERE id IN ($placeholders)',
//         ids,
//       );
//       debugPrint('✅ [FakeGPS] Marked $result logs as posted');
//       return result;
//     } catch (e) {
//       debugPrint('❌ [FakeGPS] Error marking multiple as posted: $e');
//       return 0;
//     }
//   }
//
//   Future<int> deleteOldFakeGpsLogs(int daysOld) async {
//     try {
//       final db = await this.db;
//       final cutoffDate = DateTime.now().subtract(Duration(days: daysOld)).toIso8601String();
//       final deleted = await db.delete(
//         fakeGpsTable,
//         where: 'detected_at < ?',
//         whereArgs: [cutoffDate],
//       );
//       debugPrint('🗑️ [FakeGPS] Deleted $deleted old logs (>{daysOld} days)');
//       return deleted;
//     } catch (e) {
//       debugPrint('❌ [FakeGPS] Error deleting old logs: $e');
//       return 0;
//     }
//   }
//
//   Future<Map<String, dynamic>> getFakeGpsStats() async {
//     try {
//       final db = await this.db;
//       final totalResult = await db.rawQuery("SELECT COUNT(*) as total FROM $fakeGpsTable");
//       int total = totalResult.first['total'] as int? ?? 0;
//       final postedResult = await db.rawQuery("SELECT COUNT(*) as posted FROM $fakeGpsTable WHERE posted = 1");
//       int posted = postedResult.first['posted'] as int? ?? 0;
//       final pendingResult = await db.rawQuery("SELECT COUNT(*) as pending FROM $fakeGpsTable WHERE posted = 0");
//       int pending = pendingResult.first['pending'] as int? ?? 0;
//       final uniqueUsersResult = await db.rawQuery("SELECT COUNT(DISTINCT user_id) as users FROM $fakeGpsTable");
//       int uniqueUsers = uniqueUsersResult.first['users'] as int? ?? 0;
//
//       debugPrint('📊 [FakeGPS] Stats - Total: $total, Posted: $posted, Pending: $pending, Users: $uniqueUsers');
//       return {
//         'total': total,
//         'posted': posted,
//         'pending': pending,
//         'uniqueUsers': uniqueUsers,
//       };
//     } catch (e) {
//       debugPrint('❌ [FakeGPS] Error getting stats: $e');
//       return {'total': 0, 'posted': 0, 'pending': 0, 'uniqueUsers': 0};
//     }
//   }
//
// }
//
//


import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:order_booking_app/Databases/util.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' show join;
import 'package:sqflite/sqflite.dart';
import 'dart:io' as io;
import 'dart:typed_data';
import '../Models/leave_model.dart';

class DBHelper extends GetxService {
  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDatabase();
    return _db!;
  }

  initDatabase() async {
    io.Directory documentDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentDirectory.path, 'bookIt.db');

    var db = openDatabase(
      path,
      version: 26, // ✅ Bumped to 26 for battery column migration
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    return db;
  }

  _onCreate(Database db, int version) async {
    List<String> tableQueries = [
      "CREATE TABLE IF NOT EXISTS $tableNameLogin(user_id TEXT , password TEXT ,user_name TEXT, city TEXT, designation TEXT,brand TEXT,rsm TEXT,sm TEXT,nsm TEXT,rsm_id TEXT,sm_id TEXT,nsm_id TEXT, dispatcher TEXT, dispatcher_id TEXT, images BLOB)",
      "CREATE TABLE IF NOT EXISTS $addShopTableName(shop_id TEXT PRIMARY KEY, shop_date TEXT, shop_time TEXT, shop_name TEXT,city TEXT,shop_address TEXT,owner_name TEXT,owner_cnic TEXT,phone_no TEXT,address TEXT, alternative_phone_no TEXT,latitude TEXT, longitude TEXT, user_id TEXT, posted INTEGER DEFAULT 0 )",
      "CREATE TABLE IF NOT EXISTS $shopVisitMasterTableName(shop_visit_master_id TEXT PRIMARY KEY, shop_visit_date TEXT, shop_visit_time TEXT, brand TEXT, shop_address TEXT,user_id TEXT, shop_name TEXT, address TEXT, latitude TEXT, longitude TEXT, city TEXT,owner_name TEXT,posted INTEGER DEFAULT 0, booker_name TEXT,walk_through TEXT,planogram TEXT,signage TEXT,product_reviewed TEXT,feedback TEXT,body BLOB)",
      "CREATE TABLE IF NOT EXISTS $shopVisitDetailsTableName(shop_visit_details_id TEXT PRIMARY KEY, shop_visit_details_date TEXT, shop_visit_details_time TEXT,user_id TEXT, shop_visit_master_id TEXT, product TEXT, quantity TEXT,posted INTEGER DEFAULT 0, FOREIGN KEY(shop_visit_master_id) REFERENCES $shopVisitMasterTableName(shop_visit_master_id))",
      "CREATE TABLE IF NOT EXISTS $orderMasterTableName(order_master_id TEXT PRIMARY KEY,order_status TEXT, order_master_date TEXT, order_master_time TEXT,user_id TEXT,user_name TEXT,shop_name TEXT,owner_name TEXT, phone_no TEXT,brand TEXT,total TEXT, credit_limit TEXT,city TEXT, posted INTEGER DEFAULT 0,required_delivery_date TEXT,rsm TEXT,sm TEXT,nsm TEXT,rsm_id TEXT,sm_id TEXT,nsm_id TEXT)",
      "CREATE TABLE IF NOT EXISTS $orderMasterStatusTableName(order_master_id TEXT PRIMARY KEY,order_status TEXT, order_master_date TEXT, order_master_time TEXT,user_id TEXT,shop_name TEXT,owner_name TEXT, phone_no TEXT,brand TEXT,total TEXT, credit_limit TEXT, posted INTEGER DEFAULT 0,required_delivery_date TEXT)",
      "CREATE TABLE IF NOT EXISTS $orderDetailsTableName (order_details_id TEXT PRIMARY KEY, order_details_date TEXT, order_details_time TEXT,user_id TEXT, order_master_id TEXT, product TEXT, quantity TEXT, in_stock TEXT, rate TEXT,posted INTEGER DEFAULT 0, amount TEXT, FOREIGN KEY(order_master_id) REFERENCES $orderMasterTableName(order_master_id))",
      "CREATE TABLE IF NOT EXISTS $returnFormMasterTableName(return_master_id TEXT PRIMARY KEY, return_amount TEXT,return_master_date TEXT,user_id TEXT, return_master_time TEXT, posted INTEGER DEFAULT 0,select_shop TEXT)",
      "CREATE TABLE IF NOT EXISTS $returnFormDetailsTableName(return_details_id TEXT PRIMARY KEY, return_details_date TEXT, return_details_time TEXT,user_id TEXT, return_master_id TEXT, item TEXT, quantity TEXT, reason TEXT,posted INTEGER DEFAULT 0, FOREIGN KEY(return_master_id) REFERENCES $returnFormMasterTableName(return_master_id))",
      "CREATE TABLE IF NOT EXISTS $recoveryFormTableName(recovery_id TEXT PRIMARY KEY, recovery_date TEXT, recovery_time TEXT, shop_name TEXT,user_id TEXT,current_balance TEXT,cash_recovery TEXT,net_balance TEXT,posted INTEGER DEFAULT 0)",
      "CREATE TABLE IF NOT EXISTS $attendanceTableName(attendance_in_id TEXT PRIMARY KEY, attendance_in_date TEXT, attendance_in_time TEXT,user_id TEXT, lat_in TEXT, lng_in TEXT, booker_name TEXT,designation, city TEXT,posted INTEGER DEFAULT 0, address TEXT, battery INTEGER DEFAULT 0)",
      "CREATE TABLE IF NOT EXISTS $attendanceOutTableName(attendance_out_id TEXT PRIMARY KEY, attendance_out_date TEXT, attendance_out_time TEXT,  total_time TEXT, user_id TEXT, lat_out TEXT, lng_out TEXT, total_distance TEXT,posted INTEGER DEFAULT 0, address TEXT, reason TEXT DEFAULT 'manual')",
      "CREATE TABLE IF NOT EXISTS $locationTableName(location_id TEXT PRIMARY KEY, location_date TEXT, location_time TEXT, file_name TEXT, user_id TEXT, total_distance TEXT, booker_name TEXT, posted INTEGER DEFAULT 0, body BLOB)",
      "CREATE TABLE IF NOT EXISTS $productsTableName(id NUMBER, product_code TEXT, product_name TEXT, uom TEXT ,price TEXT, brand TEXT, quantity TEXT, in_stock TEXT)",
      "CREATE TABLE IF NOT EXISTS $headsShopVisitsTableName(shop_visit_master_id TEXT PRIMARY KEY, shop_visit_date TEXT,shop_visit_time TEXT,posted INTEGER DEFAULT 0, shop_name TEXT, user_id TEXT, city TEXT, booker_name TEXT, feedback TEXT, shop_address TEXT, booker_id TEXT)",
      'CREATE TABLE IF NOT EXISTS $travelTimeData (id TEXT PRIMARY KEY, user_id TEXT,  travel_date TEXT, start_time TEXT, end_time TEXT, travel_distance REAL, travel_time REAL, average_speed REAL, working_time REAL, idle_time REAL, travel_type TEXT, latitude REAL, longitude REAL, address TEXT, posted INTEGER DEFAULT 0)',
      '''CREATE TABLE $centralPoints(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        central_point_id TEXT UNIQUE,
        user_id TEXT,
        overall_center_lat REAL,
        overall_center_lng REAL,
        total_clusters INTEGER,
        total_coordinates INTEGER,
        processing_date TEXT,
        booker_name TEXT,
        cluster_data TEXT,
        created_at TEXT,
        cluster_area TEXT,
        address_district TEXT,
        stay_time_in_cluster REAL
      )''',

      // ✅ FAKE GPS TABLE
      "CREATE TABLE IF NOT EXISTS $fakeGpsTable("
          "id INTEGER PRIMARY KEY AUTOINCREMENT, "
          "user_id TEXT NOT NULL, "
          "booker_name TEXT, "
          "designation TEXT, "
          "real_latitude REAL, "
          "real_longitude REAL, "
          "real_address TEXT, "
          "fake_latitude REAL, "
          "fake_longitude REAL, "
          "fake_address TEXT, "
          "distance_km REAL, "
          "detected_at TEXT NOT NULL, "
          "posted INTEGER DEFAULT 0"
          ")",

      '''CREATE TABLE IF NOT EXISTS $leaveTable(
          id TEXT PRIMARY KEY,
          leave_id TEXT UNIQUE,
          booker_id TEXT,
          booker_name TEXT,
          leave_type TEXT,
          start_date TEXT,
          end_date TEXT,
          total_days INTEGER,
          is_half_day INTEGER DEFAULT 0,
          reason TEXT,
          attachment_data BLOB,
          attachment_image TEXT,
          application_date TEXT,
          application_time TEXT,
          status TEXT DEFAULT 'pending',
          posted INTEGER DEFAULT 0,
          has_attachment INTEGER DEFAULT 0
        )''',
      "CREATE TABLE IF NOT EXISTS $locationTrackingTable(locationtracking_id TEXT PRIMARY KEY, locationtracking_date TEXT, locationtracking_time TEXT, user_id TEXT, lat_in TEXT, lng_in TEXT, booker_name TEXT, designation TEXT, company_code TEXT, posted INTEGER DEFAULT 0)",

      // ✅ Login Tracking Table with device info columns (NO sim_number)
      "CREATE TABLE IF NOT EXISTS $loginTrackingTable("
          "id TEXT PRIMARY KEY, "
          "booker_name TEXT, "
          "user_id TEXT, "
          "login_time TEXT, "
          "login_date TEXT, "
          "designation TEXT, "
          "company_code TEXT, "
          "posted INTEGER DEFAULT 0, "
          "android_version TEXT, "
          "device_id TEXT, "
          "device_info TEXT"
          ")"
    ];

    debugPrint('✅ All tables created successfully - Version 26');

    for (var query in tableQueries) {
      await db.execute(query);
    }
  }

  _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('🔄 Upgrading database from version $oldVersion to $newVersion');

    // Leave table migration (v15)
    if (oldVersion < 15) {
      try {
        final columns = await db.rawQuery("PRAGMA table_info($leaveTable)");
        final columnNames = columns.map((c) => c['name'] as String).toList();

        if (!columnNames.contains('attachment_image')) {
          await db.execute("ALTER TABLE $leaveTable ADD COLUMN attachment_image TEXT");
          debugPrint('✅ Added attachment_image column');
        }

        if (!columnNames.contains('has_attachment')) {
          await db.execute("ALTER TABLE $leaveTable ADD COLUMN has_attachment INTEGER DEFAULT 0");
          debugPrint('✅ Added has_attachment column');
        }

        if (columns.isEmpty) {
          await db.execute('''
          CREATE TABLE IF NOT EXISTS $leaveTable(
            id TEXT PRIMARY KEY,
            leave_id TEXT UNIQUE,
            booker_id TEXT,
            booker_name TEXT,
            leave_type TEXT,
            start_date TEXT,
            end_date TEXT,
            total_days INTEGER,
            is_half_day INTEGER DEFAULT 0,
            reason TEXT,
            attachment_data BLOB,
            attachment_image TEXT,
            application_date TEXT,
            application_time TEXT,
            status TEXT DEFAULT 'pending',
            posted INTEGER DEFAULT 0,
            has_attachment INTEGER DEFAULT 0
          )
        ''');
          debugPrint('✅ Created fresh leaveTable');
        }
      } catch (e) {
        debugPrint('❌ Leave table migration error: $e');
      }
    }

    // Attendance table migration (reason column)
    try {
      final attendanceColumns = await db.rawQuery("PRAGMA table_info($attendanceTableName)");
      final attendanceColumnNames = attendanceColumns.map((c) => c['name'] as String).toList();

      if (!attendanceColumnNames.contains('reason')) {
        await db.execute("ALTER TABLE $attendanceTableName ADD COLUMN reason TEXT");
        debugPrint('✅ Added reason column to attendance table');
      }
    } catch (e) {
      debugPrint('❌ Attendance table migration error: $e');
    }

    // Location tracking table creation (v16)
    if (oldVersion < 16) {
      try {
        await db.execute(
          "CREATE TABLE IF NOT EXISTS $locationTrackingTable("
              "locationtracking_id TEXT PRIMARY KEY, "
              "locationtracking_date TEXT, "
              "locationtracking_time TEXT, "
              "user_id TEXT, "
              "lat_in TEXT, "
              "lng_in TEXT, "
              "booker_name TEXT, "
              "designation TEXT, "
              "company_code TEXT, "
              "posted INTEGER DEFAULT 0"
              ")",
        );
        debugPrint('✅ location_tracking table created (v16 migration)');
      } catch (e) {
        debugPrint('❌ location_tracking table migration error: $e');
      }
    }

    // Company code column for location tracking (v17)
    if (oldVersion < 17) {
      try {
        final columns = await db.rawQuery("PRAGMA table_info($locationTrackingTable)");
        final columnNames = columns.map((c) => c['name'] as String).toList();

        if (!columnNames.contains('company_code')) {
          await db.execute("ALTER TABLE $locationTrackingTable ADD COLUMN company_code TEXT DEFAULT ''");
          debugPrint('✅ Added company_code column to locationTrackingTable');
        }
      } catch (e) {
        debugPrint('❌ Error adding company_code column: $e');
      }
    }

    // Login tracking table creation (v18)
    if (oldVersion < 18) {
      try {
        final columns = await db.rawQuery("PRAGMA table_info($loginTrackingTable)");
        if (columns.isEmpty) {
          await db.execute(
              "CREATE TABLE IF NOT EXISTS $loginTrackingTable("
                  "id TEXT PRIMARY KEY, "
                  "booker_name TEXT, "
                  "user_id TEXT, "
                  "login_time TEXT, "
                  "login_date TEXT, "
                  "designation TEXT, "
                  "company_code TEXT, "
                  "posted INTEGER DEFAULT 0"
                  ")"
          );
          debugPrint('✅ loginTrackingTable created (v18 migration)');
        }
      } catch (e) {
        debugPrint('❌ loginTrackingTable migration error: $e');
      }
    }

    // Add device info columns to loginTrackingTable (v19)
    if (oldVersion < 19) {
      try {
        final columns = await db.rawQuery("PRAGMA table_info($loginTrackingTable)");
        final columnNames = columns.map((c) => c['name'] as String).toList();

        if (!columnNames.contains('android_version')) {
          await db.execute("ALTER TABLE $loginTrackingTable ADD COLUMN android_version TEXT");
          debugPrint('✅ Added android_version column to loginTrackingTable');
        }
        if (!columnNames.contains('device_id')) {
          await db.execute("ALTER TABLE $loginTrackingTable ADD COLUMN device_id TEXT");
          debugPrint('✅ Added device_id column to loginTrackingTable');
        }
        if (!columnNames.contains('sim_info')) {
          await db.execute("ALTER TABLE $loginTrackingTable ADD COLUMN sim_info TEXT");
          debugPrint('✅ Added sim_info column to loginTrackingTable');
        }
      } catch (e) {
        debugPrint('❌ Error adding device info columns to loginTrackingTable: $e');
      }
    }

    // Remove sim_number column if it exists (v21)
    if (oldVersion < 21) {
      try {
        final columns = await db.rawQuery("PRAGMA table_info($loginTrackingTable)");
        final columnNames = columns.map((c) => c['name'] as String).toList();

        if (columnNames.contains('sim_number')) {
          debugPrint('🔄 Removing sim_number column from loginTrackingTable...');
          await db.execute('''
            CREATE TABLE ${loginTrackingTable}_new (
              id TEXT PRIMARY KEY,
              booker_name TEXT,
              user_id TEXT,
              login_time TEXT,
              login_date TEXT,
              designation TEXT,
              company_code TEXT,
              posted INTEGER DEFAULT 0,
              android_version TEXT,
              device_id TEXT,
              sim_info TEXT
            )
          ''');
          await db.execute('''
            INSERT INTO ${loginTrackingTable}_new (
              id, booker_name, user_id, login_time, login_date,
              designation, company_code, posted, android_version, device_id, sim_info
            )
            SELECT
              id, booker_name, user_id, login_time, login_date,
              designation, company_code, posted, android_version, device_id, sim_info
            FROM $loginTrackingTable
          ''');
          await db.execute('DROP TABLE $loginTrackingTable');
          await db.execute('ALTER TABLE ${loginTrackingTable}_new RENAME TO $loginTrackingTable');
          debugPrint('✅ Removed sim_number column from loginTrackingTable');
        }
      } catch (e) {
        debugPrint('❌ Error removing sim_number column: $e');
      }
    }

    // Migrate sim_info to device_info (v22)
    if (oldVersion < 22) {
      try {
        final columns = await db.rawQuery("PRAGMA table_info($loginTrackingTable)");
        final columnNames = columns.map((c) => c['name'] as String).toList();

        if (columnNames.contains('sim_info')) {
          await db.execute('''
            CREATE TABLE ${loginTrackingTable}_new (
              id TEXT PRIMARY KEY,
              booker_name TEXT,
              user_id TEXT,
              login_time TEXT,
              login_date TEXT,
              designation TEXT,
              company_code TEXT,
              posted INTEGER DEFAULT 0,
              android_version TEXT,
              device_id TEXT,
              device_info TEXT
            )
          ''');
          await db.execute('''
            INSERT INTO ${loginTrackingTable}_new (
              id, booker_name, user_id, login_time, login_date,
              designation, company_code, posted, android_version, device_id, device_info
            )
            SELECT
              id, booker_name, user_id, login_time, login_date,
              designation, company_code, posted, android_version, device_id, sim_info
            FROM $loginTrackingTable
          ''');
          await db.execute('DROP TABLE $loginTrackingTable');
          await db.execute('ALTER TABLE ${loginTrackingTable}_new RENAME TO $loginTrackingTable');
          debugPrint('✅ Migrated loginTrackingTable: removed sim_info, added device_info');
        } else if (!columnNames.contains('device_info')) {
          await db.execute("ALTER TABLE $loginTrackingTable ADD COLUMN device_info TEXT");
          debugPrint('✅ Added device_info column');
        }
      } catch (e) {
        debugPrint('❌ LoginTracking migration error: $e');
      }
    }

    // Create fake_gps_logs table if missing (v23)
    if (oldVersion < 23) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $fakeGpsTable(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            booker_name TEXT,
            designation TEXT,
            real_latitude REAL,
            real_longitude REAL,
            real_address TEXT,
            fake_latitude REAL,
            fake_longitude REAL,
            fake_address TEXT,
            distance_km REAL,
            detected_at TEXT NOT NULL,
            posted INTEGER DEFAULT 0
          )
        ''');
        debugPrint('✅ fake_gps_logs table created (v23 migration)');
      } catch (e) {
        debugPrint('❌ Error creating fake_gps_logs table: $e');
      }
    }

    // ✅ Add battery column to attendance table (v26)
    if (oldVersion < 26) {
      try {
        final cols = await db.rawQuery("PRAGMA table_info($attendanceTableName)");
        final names = cols.map((c) => c['name'] as String).toList();
        if (!names.contains('battery')) {
          await db.execute(
              "ALTER TABLE $attendanceTableName ADD COLUMN battery INTEGER DEFAULT 0"
          );
          debugPrint('✅ Added battery column to $attendanceTableName');
        }
      } catch (e) {
        debugPrint('❌ Battery column migration error: $e');
      }
    }

    debugPrint('✅ Database upgrade finished');
  }

  // =====================================================================
  // LOCATION TRACKING CRUD
  // =====================================================================

  Future<int> insertLocationTracking(Map<String, dynamic> data) async {
    try {
      final db = await this.db;
      final result = await db.insert(
        locationTrackingTable,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('📍 [GPS] Inserted tracking row: ${data['locationtracking_id']}');
      return result;
    } catch (e) {
      debugPrint('❌ [GPS] Error inserting location tracking: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getUnpostedLocationTracking() async {
    try {
      final db = await this.db;
      final result = await db.query(
        locationTrackingTable,
        where: 'posted = ?',
        whereArgs: [0],
        orderBy: 'locationtracking_date ASC, locationtracking_time ASC',
      );
      debugPrint('📋 [GPS] Unposted tracking rows: ${result.length}');
      return result;
    } catch (e) {
      debugPrint('❌ [GPS] Error fetching unposted tracking rows: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUnpostedLocationTrackingByCompany(String companyCode) async {
    try {
      final db = await this.db;
      final result = await db.query(
        locationTrackingTable,
        where: 'posted = ? AND company_code = ?',
        whereArgs: [0, companyCode],
        orderBy: 'locationtracking_date ASC, locationtracking_time ASC',
      );
      debugPrint('📋 [GPS] Unposted tracking rows for company $companyCode: ${result.length}');
      return result;
    } catch (e) {
      debugPrint('❌ [GPS] Error fetching unposted tracking rows by company: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getLocationTrackingByUserAndDate(
      String userId, String date, {String? companyCode}) async {
    try {
      final db = await this.db;
      String where = 'user_id = ? AND locationtracking_date = ?';
      List<dynamic> whereArgs = [userId, date];

      if (companyCode != null && companyCode.isNotEmpty) {
        where += ' AND company_code = ?';
        whereArgs.add(companyCode);
      }

      final result = await db.query(
        locationTrackingTable,
        where: where,
        whereArgs: whereArgs,
        orderBy: 'locationtracking_time ASC',
      );
      debugPrint('📋 [GPS] Rows for user $userId on $date: ${result.length}');
      return result;
    } catch (e) {
      debugPrint('❌ [GPS] Error fetching tracking by user/date: $e');
      return [];
    }
  }

  Future<void> markLocationTrackingAsPosted(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final db = await this.db;
      final placeholders = ids.map((_) => '?').join(', ');
      await db.rawUpdate(
        "UPDATE $locationTrackingTable SET posted = 1 WHERE locationtracking_id IN ($placeholders)",
        ids,
      );
      debugPrint('✅ [GPS] Marked ${ids.length} rows as posted');
    } catch (e) {
      debugPrint('❌ [GPS] Error marking rows as posted: $e');
    }
  }

  Future<int> backfillCompanyCode(String companyCode) async {
    if (companyCode.isEmpty) return 0;
    try {
      final db = await this.db;
      final count = await db.rawUpdate(
        "UPDATE $locationTrackingTable SET company_code = ? "
            "WHERE (company_code IS NULL OR company_code = '') AND posted = 0",
        [companyCode],
      );
      if (count > 0) {
        debugPrint('🔄 [GPS] Backfilled company_code on $count unposted rows');
      }
      return count;
    } catch (e) {
      debugPrint('❌ [GPS] Error backfilling company_code: $e');
      return 0;
    }
  }

  Future<void> deleteLocationTrackingByDate(String date) async {
    try {
      final db = await this.db;
      final deleted = await db.delete(
        locationTrackingTable,
        where: 'locationtracking_date = ?',
        whereArgs: [date],
      );
      debugPrint('🗑️ [GPS] Deleted $deleted rows for date $date');
    } catch (e) {
      debugPrint('❌ [GPS] Error deleting tracking rows: $e');
    }
  }

  Future<int> countTodayLocationTracking(String userId, String date) async {
    try {
      final db = await this.db;
      final result = await db.rawQuery(
        "SELECT COUNT(*) as cnt FROM $locationTrackingTable WHERE user_id = ? AND locationtracking_date = ?",
        [userId, date],
      );
      return result.first['cnt'] as int? ?? 0;
    } catch (e) {
      debugPrint('❌ [GPS] Error counting today rows: $e');
      return 0;
    }
  }

  Future<int?> getHighestLocationSerial(String day, String month, {String? companyCode}) async {
    final dbClient = await this.db;

    if (companyCode != null && companyCode.isNotEmpty) {
      final result = await dbClient.rawQuery(
          'SELECT MAX(CAST(SUBSTR(locationtracking_id, -3) AS INTEGER)) as max_serial '
              'FROM $locationTrackingTable '
              'WHERE locationtracking_id LIKE ? AND company_code = ?',
          ['%$day-$month-%', companyCode]
      );
      if (result.isNotEmpty && result.first['max_serial'] != null) {
        return result.first['max_serial'] as int;
      }
    } else {
      final result = await dbClient.rawQuery(
          'SELECT MAX(CAST(SUBSTR(locationtracking_id, -3) AS INTEGER)) as max_serial '
              'FROM $locationTrackingTable '
              'WHERE locationtracking_id LIKE ?',
          ['%$day-$month-%']
      );
      if (result.isNotEmpty && result.first['max_serial'] != null) {
        return result.first['max_serial'] as int;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllLocationTracking() async {
    try {
      final db = await this.db;
      final result = await db.query(
        locationTrackingTable,
        orderBy: 'locationtracking_date ASC, locationtracking_time ASC',
      );
      debugPrint('📋 [GPS] All tracking rows: ${result.length}');
      return result;
    } catch (e) {
      debugPrint('❌ [GPS] Error fetching all tracking rows: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPostedLocationTracking() async {
    try {
      final db = await this.db;
      final result = await db.query(
        locationTrackingTable,
        where: 'posted = ?',
        whereArgs: [1],
        orderBy: 'locationtracking_date ASC, locationtracking_time ASC',
      );
      debugPrint('📋 [GPS] Posted tracking rows: ${result.length}');
      return result;
    } catch (e) {
      debugPrint('❌ [GPS] Error fetching posted tracking rows: $e');
      return [];
    }
  }

  Future<Map<String, int>> getLocationTrackingStats() async {
    try {
      final db = await this.db;
      final totalResult = await db.rawQuery("SELECT COUNT(*) as total FROM $locationTrackingTable");
      int total = totalResult.first['total'] as int? ?? 0;
      final postedResult = await db.rawQuery("SELECT COUNT(*) as posted FROM $locationTrackingTable WHERE posted = 1");
      int posted = postedResult.first['posted'] as int? ?? 0;
      final pendingResult = await db.rawQuery("SELECT COUNT(*) as pending FROM $locationTrackingTable WHERE posted = 0");
      int pending = pendingResult.first['pending'] as int? ?? 0;
      debugPrint('📊 [GPS] Stats - Total: $total, Posted: $posted, Pending: $pending');
      return {'total': total, 'posted': posted, 'pending': pending};
    } catch (e) {
      debugPrint('❌ [GPS] Error getting stats: $e');
      return {'total': 0, 'posted': 0, 'pending': 0};
    }
  }

  // =====================================================================
  // LOGIN TRACKING CRUD (with device info - NO sim_number)
  // =====================================================================

  Future<int> insertLoginTracking(Map<String, dynamic> data) async {
    try {
      final db = await this.db;
      final result = await db.insert(
        loginTrackingTable,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('✅ [LoginTracking] Inserted: ${data['id']}');
      if (data.containsKey('android_version')) {
        debugPrint('   📱 Android Version: ${data['android_version']}');
        debugPrint('   🆔 Device ID: ${data['device_id']}');
      }
      return result;
    } catch (e) {
      debugPrint('❌ [LoginTracking] Error inserting: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getUnpostedLoginTracking() async {
    try {
      final db = await this.db;
      final result = await db.query(
        loginTrackingTable,
        where: 'posted = ?',
        whereArgs: [0],
        orderBy: 'login_date ASC, login_time ASC',
      );
      debugPrint('📋 [LoginTracking] Unposted rows: ${result.length}');
      return result;
    } catch (e) {
      debugPrint('❌ [LoginTracking] Error fetching unposted: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllLoginTracking() async {
    try {
      final db = await this.db;
      final result = await db.query(
        loginTrackingTable,
        orderBy: 'login_date DESC, login_time DESC',
      );
      debugPrint('📋 [LoginTracking] All rows: ${result.length}');
      return result;
    } catch (e) {
      debugPrint('❌ [LoginTracking] Error fetching all: $e');
      return [];
    }
  }

  Future<void> markLoginTrackingAsPosted(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final db = await this.db;
      final placeholders = ids.map((_) => '?').join(', ');
      await db.rawUpdate(
        "UPDATE $loginTrackingTable SET posted = 1 WHERE id IN ($placeholders)",
        ids,
      );
      debugPrint('✅ [LoginTracking] Marked ${ids.length} rows as posted');
    } catch (e) {
      debugPrint('❌ [LoginTracking] Error marking as posted: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getLoginTrackingByUserAndDate(
      String userId, String date) async {
    try {
      final db = await this.db;
      final result = await db.query(
        loginTrackingTable,
        where: 'user_id = ? AND login_date = ?',
        whereArgs: [userId, date],
        orderBy: 'login_time ASC',
      );
      debugPrint('📋 [LoginTracking] Rows for user $userId on $date: ${result.length}');
      return result;
    } catch (e) {
      debugPrint('❌ [LoginTracking] Error fetching by user/date: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getLoginTrackingByCompany(String companyCode) async {
    try {
      final db = await this.db;
      final result = await db.query(
        loginTrackingTable,
        where: 'company_code = ?',
        whereArgs: [companyCode],
        orderBy: 'login_date DESC, login_time DESC',
      );
      debugPrint('📋 [LoginTracking] Rows for company $companyCode: ${result.length}');
      return result;
    } catch (e) {
      debugPrint('❌ [LoginTracking] Error fetching by company: $e');
      return [];
    }
  }

  Future<void> deleteLoginTrackingByDate(String date) async {
    try {
      final db = await this.db;
      final deleted = await db.delete(
        loginTrackingTable,
        where: 'login_date = ?',
        whereArgs: [date],
      );
      debugPrint('🗑️ [LoginTracking] Deleted $deleted rows for date $date');
    } catch (e) {
      debugPrint('❌ [LoginTracking] Error deleting: $e');
    }
  }

  Future<void> deleteAllLoginTracking() async {
    try {
      final db = await this.db;
      final deleted = await db.delete(loginTrackingTable);
      debugPrint('🗑️ [LoginTracking] Deleted all $deleted rows');
    } catch (e) {
      debugPrint('❌ [LoginTracking] Error deleting all: $e');
    }
  }

  Future<Map<String, dynamic>> getLoginTrackingStats() async {
    try {
      final db = await this.db;
      final totalResult = await db.rawQuery("SELECT COUNT(*) as total FROM $loginTrackingTable");
      int total = totalResult.first['total'] as int? ?? 0;
      final postedResult = await db.rawQuery("SELECT COUNT(*) as posted FROM $loginTrackingTable WHERE posted = 1");
      int posted = postedResult.first['posted'] as int? ?? 0;
      final pendingResult = await db.rawQuery("SELECT COUNT(*) as pending FROM $loginTrackingTable WHERE posted = 0");
      int pending = pendingResult.first['pending'] as int? ?? 0;
      final devicesResult = await db.rawQuery(
          "SELECT device_id, COUNT(*) as count FROM $loginTrackingTable WHERE device_id IS NOT NULL GROUP BY device_id"
      );
      final androidVersionsResult = await db.rawQuery(
          "SELECT android_version, COUNT(*) as count FROM $loginTrackingTable WHERE android_version IS NOT NULL GROUP BY android_version"
      );
      debugPrint('📊 [LoginTracking] Stats - Total: $total, Posted: $posted, Pending: $pending');
      debugPrint('📊 [LoginTracking] Unique devices: ${devicesResult.length}');
      debugPrint('📊 [LoginTracking] Android versions: ${androidVersionsResult.length}');
      return {
        'total': total,
        'posted': posted,
        'pending': pending,
        'uniqueDevices': devicesResult.length,
        'androidVersionsCount': androidVersionsResult.length,
      };
    } catch (e) {
      debugPrint('❌ [LoginTracking] Error getting stats: $e');
      return {'total': 0, 'posted': 0, 'pending': 0};
    }
  }

  Future<Map<String, dynamic>?> getDeviceInfoForLogin(String loginId) async {
    try {
      final db = await this.db;
      final result = await db.query(
        loginTrackingTable,
        columns: ['android_version', 'device_id'],
        where: 'id = ?',
        whereArgs: [loginId],
      );
      if (result.isNotEmpty) {
        return result.first;
      }
      return null;
    } catch (e) {
      debugPrint('❌ [LoginTracking] Error getting device info: $e');
      return null;
    }
  }

  // =====================================================================
  // GENERAL UTILITIES
  // =====================================================================

  Future<void> clearData() async {
    final db = await this.db;
    List<String> tableNames = [productsTableName];
    for (var tableName in tableNames) {
      await db.execute("DELETE FROM $tableName");
    }
  }

  // =====================================================================
  // LEAVE TABLE CRUD
  // =====================================================================

  Future<int> insertLeave(LeaveModel leave) async {
    try {
      final db = await this.db;
      DateTime now = DateTime.now();
      String day = now.day.toString().padLeft(2, '0');
      String monthAbbrev = _getMonthAbbreviation(now.month);
      int sequence = await _getLeaveSequenceForDay(now);
      String sequenceStr = sequence.toString().padLeft(3, '0');
      String leaveId = 'LV-${leave.bookerId}-$day-$monthAbbrev-$sequenceStr';

      String? attachmentImage;
      if (leave.attachmentData != null) {
        attachmentImage = 'leave_${leave.bookerId}_${now.millisecondsSinceEpoch}.jpg';
      }

      final data = {
        'id': now.millisecondsSinceEpoch.toString(),
        'leave_id': leaveId,
        'booker_id': leave.bookerId,
        'booker_name': leave.bookerName ?? '',
        'leave_type': leave.leaveType,
        'start_date': leave.startDate,
        'end_date': leave.endDate,
        'total_days': leave.totalDays,
        'is_half_day': leave.isHalfDay ? 1 : 0,
        'reason': leave.reason,
        'attachment_data': leave.attachmentData,
        'attachment_image': attachmentImage,
        'application_date': now.toIso8601String().split('T')[0],
        'application_time': "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}",
        'status': leave.status ?? 'pending',
        'posted': 0,
        'has_attachment': leave.attachmentData != null ? 1 : 0,
      };

      final result = await db.insert(leaveTable, data, conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint('✅ Leave inserted with ID: $result, Leave ID: $leaveId');
      return result;
    } catch (e) {
      debugPrint('❌ Error inserting leave: $e');
      return 0;
    }
  }

  String _getMonthAbbreviation(int month) {
    switch (month) {
      case 1: return 'Jan';
      case 2: return 'Feb';
      case 3: return 'Mar';
      case 4: return 'Apr';
      case 5: return 'May';
      case 6: return 'Jun';
      case 7: return 'Jul';
      case 8: return 'Aug';
      case 9: return 'Sep';
      case 10: return 'Oct';
      case 11: return 'Nov';
      case 12: return 'Dec';
      default: return '---';
    }
  }

  Future<int> _getLeaveSequenceForDay(DateTime date) async {
    try {
      final db = await this.db;
      String dateStr = date.toIso8601String().split('T')[0];
      final result = await db.rawQuery('''
        SELECT COUNT(*) as count FROM $leaveTable
        WHERE application_date = ?
      ''', [dateStr]);
      int count = result.first['count'] as int? ?? 0;
      return count + 1;
    } catch (e) {
      debugPrint('❌ Error getting leave sequence: $e');
      return 1;
    }
  }

  Future<int> markLeaveAsPosted(String leaveId) async {
    try {
      final db = await this.db;
      final result = await db.update(
        leaveTable,
        {'posted': 1},
        where: 'leave_id = ?',
        whereArgs: [leaveId],
      );
      if (result > 0) {
        debugPrint('✅ Leave marked as posted successfully');
      }
      return result;
    } catch (e) {
      debugPrint('❌ Error marking leave as posted: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getLeavesByBookerId(String bookerId) async {
    try {
      final db = await this.db;
      final leaves = await db.query(
        leaveTable,
        columns: [
          'id', 'leave_id', 'booker_id', 'booker_name', 'leave_type',
          'start_date', 'end_date', 'total_days', 'is_half_day', 'reason',
          'attachment_image', 'application_date', 'application_time', 'status', 'posted', 'has_attachment'
        ],
        where: 'booker_id = ?',
        whereArgs: [bookerId],
        orderBy: 'application_date DESC, application_time DESC',
      );
      return leaves;
    } catch (e) {
      debugPrint('❌ Error fetching leaves: $e');
      return [];
    }
  }

  Future<Uint8List?> getLeaveAttachment(String leaveId) async {
    try {
      final db = await this.db;
      final result = await db.query(
        leaveTable,
        columns: ['attachment_data'],
        where: 'leave_id = ?',
        whereArgs: [leaveId],
        limit: 1,
      );
      if (result.isNotEmpty && result.first['attachment_data'] != null) {
        final blobData = result.first['attachment_data'];
        if (blobData is Uint8List) {
          return blobData;
        } else if (blobData is List<int>) {
          return Uint8List.fromList(blobData);
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching attachment: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingLeaves() async {
    try {
      final db = await this.db;
      final leaves = await db.query(
        leaveTable,
        columns: [
          'id', 'leave_id', 'booker_id', 'booker_name', 'leave_type',
          'start_date', 'end_date', 'total_days', 'is_half_day', 'reason',
          'attachment_image', 'application_date', 'application_time', 'status', 'posted', 'has_attachment'
        ],
        where: 'posted = ?',
        whereArgs: [0],
        orderBy: 'application_date DESC, application_time DESC',
      );
      return leaves;
    } catch (e) {
      debugPrint('❌ Error fetching pending leaves: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPendingLeavesWithAttachments() async {
    try {
      final db = await this.db;
      final leaves = await db.query(
        leaveTable,
        where: 'posted = ?',
        whereArgs: [0],
        orderBy: 'application_date DESC, application_time DESC',
      );
      for (var leave in leaves) {
        if (leave['attachment_data'] != null && leave['attachment_data'] is List<int>) {
          leave['attachment_data'] = Uint8List.fromList(leave['attachment_data'] as List<int>);
        }
      }
      return leaves;
    } catch (e) {
      debugPrint('❌ Error fetching pending leaves with attachments: $e');
      return [];
    }
  }

  // =====================================================================
  // FAKE GPS LOGS CRUD
  // =====================================================================

  Future<int> insertFakeGpsLog(Map<String, dynamic> data) async {
    try {
      final db = await this.db;
      final result = await db.insert(
        fakeGpsTable,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('🚨 [FakeGPS] Inserted log at: ${data['detected_at']}');
      return result;
    } catch (e) {
      debugPrint('❌ [FakeGPS] Error inserting log: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getUnpostedFakeGpsLogs() async {
    try {
      final db = await this.db;
      final result = await db.query(
        fakeGpsTable,
        where: 'posted = ?',
        whereArgs: [0],
        orderBy: 'detected_at ASC',
      );
      debugPrint('📋 [FakeGPS] Unposted logs: ${result.length}');
      return result;
    } catch (e) {
      debugPrint('❌ [FakeGPS] Error fetching unposted logs: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllFakeGpsLogs() async {
    try {
      final db = await this.db;
      final result = await db.query(
        fakeGpsTable,
        orderBy: 'detected_at DESC',
      );
      debugPrint('📋 [FakeGPS] All logs: ${result.length}');
      return result;
    } catch (e) {
      debugPrint('❌ [FakeGPS] Error fetching all logs: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getFakeGpsLogsByUser(String userId) async {
    try {
      final db = await this.db;
      final result = await db.query(
        fakeGpsTable,
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'detected_at DESC',
      );
      debugPrint('📋 [FakeGPS] Logs for user $userId: ${result.length}');
      return result;
    } catch (e) {
      debugPrint('❌ [FakeGPS] Error fetching logs by user: $e');
      return [];
    }
  }

  Future<int> markFakeGpsAsPosted(int id) async {
    try {
      final db = await this.db;
      final result = await db.update(
        fakeGpsTable,
        {'posted': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('✅ [FakeGPS] Marked id $id as posted');
      return result;
    } catch (e) {
      debugPrint('❌ [FakeGPS] Error marking as posted: $e');
      return 0;
    }
  }

  Future<int> markAllFakeGpsAsPosted(List<int> ids) async {
    if (ids.isEmpty) return 0;
    try {
      final db = await this.db;
      final placeholders = ids.map((_) => '?').join(',');
      final result = await db.rawUpdate(
        'UPDATE $fakeGpsTable SET posted = 1 WHERE id IN ($placeholders)',
        ids,
      );
      debugPrint('✅ [FakeGPS] Marked $result logs as posted');
      return result;
    } catch (e) {
      debugPrint('❌ [FakeGPS] Error marking multiple as posted: $e');
      return 0;
    }
  }

  Future<int> deleteOldFakeGpsLogs(int daysOld) async {
    try {
      final db = await this.db;
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld)).toIso8601String();
      final deleted = await db.delete(
        fakeGpsTable,
        where: 'detected_at < ?',
        whereArgs: [cutoffDate],
      );
      debugPrint('🗑️ [FakeGPS] Deleted $deleted old logs (>$daysOld days)');
      return deleted;
    } catch (e) {
      debugPrint('❌ [FakeGPS] Error deleting old logs: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>> getFakeGpsStats() async {
    try {
      final db = await this.db;
      final totalResult = await db.rawQuery("SELECT COUNT(*) as total FROM $fakeGpsTable");
      int total = totalResult.first['total'] as int? ?? 0;
      final postedResult = await db.rawQuery("SELECT COUNT(*) as posted FROM $fakeGpsTable WHERE posted = 1");
      int posted = postedResult.first['posted'] as int? ?? 0;
      final pendingResult = await db.rawQuery("SELECT COUNT(*) as pending FROM $fakeGpsTable WHERE posted = 0");
      int pending = pendingResult.first['pending'] as int? ?? 0;
      final uniqueUsersResult = await db.rawQuery("SELECT COUNT(DISTINCT user_id) as users FROM $fakeGpsTable");
      int uniqueUsers = uniqueUsersResult.first['users'] as int? ?? 0;

      debugPrint('📊 [FakeGPS] Stats - Total: $total, Posted: $posted, Pending: $pending, Users: $uniqueUsers');
      return {
        'total': total,
        'posted': posted,
        'pending': pending,
        'uniqueUsers': uniqueUsers,
      };
    } catch (e) {
      debugPrint('❌ [FakeGPS] Error getting stats: $e');
      return {'total': 0, 'posted': 0, 'pending': 0, 'uniqueUsers': 0};
    }
  }
}