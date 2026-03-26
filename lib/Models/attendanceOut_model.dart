
import 'package:intl/intl.dart';

class AttendanceOutModel {
  dynamic attendance_out_id;
  String? user_id;
  dynamic total_time;
  dynamic lat_out;
  dynamic lng_out;
  dynamic total_distance;
  dynamic address;
  dynamic attendance_out_date;
  dynamic attendance_out_time;
  int posted; // ✅ ADD THIS FIELD - 0 = not posted, 1 = posted
  String? reason;

  AttendanceOutModel({
    this.attendance_out_id,
    this.user_id,
    this.total_time,
    this.lat_out,
    this.lng_out,
    this.total_distance,
    this.attendance_out_date,
    this.attendance_out_time,
    this.address,
    this.posted = 0, // ✅ DEFAULT TO 0 (NOT POSTED)
    this.reason,           // 👈 ADD THIS
  });

  factory AttendanceOutModel.fromMap(Map<dynamic, dynamic> json) {
    return AttendanceOutModel(
      attendance_out_id: json['attendance_out_id'],
      user_id: json['user_id'],
      total_time: json['total_time'],
      lat_out: json['lat_out'],
      lng_out: json['lng_out'],
      total_distance: json['total_distance'],
      attendance_out_date: json['attendance_out_date'],
      attendance_out_time: json['attendance_out_time'],
      address: json['address'],
      posted: json['posted'] ?? 0 ,// ✅ READ POSTED FIELD FROM DB
      reason: json['reason'] ?? 'manual',    // 👈 ADD THIS
    );
  }

  Map<String, dynamic> toMap() {
    // Determine the date string for the API call
    // ✅ STRICT FIX: NEVER use DateTime.now() as fallback — yahi bug tha
    // attendance_out_date null hai to empty string — wrong date nahi jaayegi server ko
    String dateString;
    if (attendance_out_date is DateTime) {
      dateString = DateFormat('dd-MMM-yyyy').format(attendance_out_date as DateTime);
    } else if (attendance_out_date is String && (attendance_out_date as String).isNotEmpty) {
      dateString = attendance_out_date as String;
    } else {
      // ✅ FIX: DateTime.now() mat use karo — log karo taake pata chale
      assert(false, '⚠️ [MODEL] attendance_out_date is null/empty — check where model is created');
      dateString = ''; // Empty — server reject karega lekin wrong time nahi jayega
    }

    // Determine the time string for the API call
    // ✅ STRICT FIX: NEVER use DateTime.now() as fallback — app-open time server jaata tha isi se
    String timeString;
    if (attendance_out_time is DateTime) {
      timeString = DateFormat('HH:mm:ss').format(attendance_out_time as DateTime);
    } else if (attendance_out_time is String && (attendance_out_time as String).isNotEmpty) {
      timeString = attendance_out_time as String;
    } else {
      // ✅ FIX: DateTime.now() mat use karo — log karo taake pata chale
      assert(false, '⚠️ [MODEL] attendance_out_time is null/empty — check where model is created');
      timeString = ''; // Empty — server reject karega lekin wrong time nahi jayega
    }

    return {
      'attendance_out_id': attendance_out_id,
      'user_id': user_id,
      'total_time': total_time,
      'lat_out': lat_out,
      'lng_out': lng_out,
      'total_distance': total_distance,
      'attendance_out_date': dateString,
      'attendance_out_time': timeString,
      'address': address,
      'posted': posted, // ✅ INCLUDE POSTED FIELD IN API CALL
      'reason': reason ?? 'manual',    // 👈 ADD THIS
    };
  }
}