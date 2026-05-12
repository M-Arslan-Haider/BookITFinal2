//
// import 'package:intl/intl.dart';
//
// class AttendanceModel {
//   dynamic attendance_in_id;
//   String? user_id;
//   dynamic lat_in;
//   dynamic lng_in;
//   dynamic booker_name;
//   dynamic designation;
//   dynamic city;
//   dynamic address;
//   // FIX 1: Change to dynamic to safely hold stored strings from DB
//   dynamic attendance_in_date;
//   dynamic attendance_in_time;
//   int posted;
//
//   AttendanceModel({
//     this.attendance_in_id,
//     this.user_id,
//     this.lat_in,
//     this.lng_in,
//     this.booker_name,
//     this.city,
//     this.designation,
//     this.attendance_in_date,
//     this.attendance_in_time,
//     this.address,
//     this.posted = 0
//   });
//
//   factory AttendanceModel.fromMap(Map<dynamic, dynamic> json) {
//     return AttendanceModel(
//         attendance_in_id: json['attendance_in_id'],
//         user_id: json['user_id'],
//         lat_in: json['lat_in'],
//         lng_in: json['lng_in'],
//         booker_name: json['booker_name'],
//         city: json['city'],
//         designation: json['designation'],
//         address: json['address'],
//
//         // FIX 2: Load the actual stored date/time strings from the database map (json)
//         attendance_in_date: json['attendance_in_date'],
//         attendance_in_time: json['attendance_in_time'],
//
//         posted: json['posted']?? 0
//     );
//   }
//
//   Map<String, dynamic> toMap() {
//     // Determine the date string for the API call
//     String dateString;
//     if (attendance_in_date is DateTime) {
//       // For new records, format the DateTime object
//       dateString = DateFormat('dd-MMM-yyyy').format(attendance_in_date);
//     } else if (attendance_in_date is String) {
//       // For offline records, use the stored string
//       dateString = attendance_in_date;
//     } else {
//       // Fallback (e.g., if somehow still null)
//       dateString = DateFormat('dd-MMM-yyyy').format(DateTime.now());
//     }
//
//     // Determine the time string for the API call
//     String timeString;
//     if (attendance_in_time is DateTime) {
//       // For new records, format the DateTime object
//       timeString = DateFormat('HH:mm:ss').format(attendance_in_time);
//     } else if (attendance_in_time is String) {
//       // For offline records, use the stored string
//       timeString = attendance_in_time;
//     } else {
//       // Fallback
//       timeString = DateFormat('HH:mm:ss').format(DateTime.now());
//     }
//
//     return {
//       'attendance_in_id': attendance_in_id,
//       'user_id': user_id,
//       'lat_in': lat_in,
//       'lng_in': lng_in,
//       'booker_name': booker_name,
//       'city': city,
//       'designation': designation,
//       'address': address,
//       // FIX 3: Use the determined offline/online time strings
//       'attendance_in_date': dateString,
//       'attendance_in_time': timeString,
//       'posted': posted,
//     };
//   }
// }
// Add battery property to the class
import 'package:intl/intl.dart';

class AttendanceModel {
  dynamic attendance_in_id;
  String? user_id;
  dynamic lat_in;
  dynamic lng_in;
  dynamic booker_name;
  dynamic designation;
  dynamic city;
  dynamic address;
  dynamic attendance_in_date;
  dynamic attendance_in_time;
  int posted;
  int battery;  // ✅ ADD THIS LINE

  AttendanceModel({
    this.attendance_in_id,
    this.user_id,
    this.lat_in,
    this.lng_in,
    this.booker_name,
    this.city,
    this.designation,
    this.attendance_in_date,
    this.attendance_in_time,
    this.address,
    this.posted = 0,
    this.battery = 0,  // ✅ ADD THIS LINE
  });

  factory AttendanceModel.fromMap(Map<dynamic, dynamic> json) {
    return AttendanceModel(
      attendance_in_id: json['attendance_in_id'],
      user_id: json['user_id'],
      lat_in: json['lat_in'],
      lng_in: json['lng_in'],
      booker_name: json['booker_name'],
      city: json['city'],
      designation: json['designation'],
      address: json['address'],
      attendance_in_date: json['attendance_in_date'],
      attendance_in_time: json['attendance_in_time'],
      posted: json['posted'] ?? 0,
      battery: json['battery'] ?? 0,  // ✅ ADD THIS LINE
    );
  }

  Map<String, dynamic> toMap() {
    String dateString;
    if (attendance_in_date is DateTime) {
      dateString = DateFormat('dd-MMM-yyyy').format(attendance_in_date);
    } else if (attendance_in_date is String) {
      dateString = attendance_in_date;
    } else {
      dateString = DateFormat('dd-MMM-yyyy').format(DateTime.now());
    }

    String timeString;
    if (attendance_in_time is DateTime) {
      timeString = DateFormat('HH:mm:ss').format(attendance_in_time);
    } else if (attendance_in_time is String) {
      timeString = attendance_in_time;
    } else {
      timeString = DateFormat('HH:mm:ss').format(DateTime.now());
    }

    return {
      'attendance_in_id': attendance_in_id,
      'user_id': user_id,
      'lat_in': lat_in,
      'lng_in': lng_in,
      'booker_name': booker_name,
      'city': city,
      'designation': designation,
      'address': address,
      'attendance_in_date': dateString,
      'attendance_in_time': timeString,
      'posted': posted,
      'battery': battery,  // ✅ ADD THIS LINE
    };
  }
}