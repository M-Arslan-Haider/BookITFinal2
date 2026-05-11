// class LoginTrackingModel {
//   String? id;
//   String? bookerName;
//   String? userId;
//   String? loginTime;
//   String? loginDate;
//   String? designation;
//   String? companyCode;
//   int? posted;
//
//   LoginTrackingModel({
//     this.id,
//     this.bookerName,
//     this.userId,
//     this.loginTime,
//     this.loginDate,
//     this.designation,
//     this.companyCode,
//     this.posted,
//   });
//
//   factory LoginTrackingModel.fromMap(Map<String, dynamic> json) {
//     return LoginTrackingModel(
//       id: json['id'],
//       bookerName: json['booker_name'],
//       userId: json['user_id'],
//       loginTime: json['login_time'],
//       loginDate: json['login_date'],
//       designation: json['designation'],
//       companyCode: json['company_code'],
//       posted: json['posted'],
//     );
//   }
//
//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'booker_name': bookerName,
//       'user_id': userId,
//       'login_time': loginTime,
//       'login_date': loginDate,
//       'designation': designation,
//       'company_code': companyCode,
//       'posted': posted ?? 0,
//     };
//   }
//
//   Map<String, dynamic> toApiPayload() {
//     return {
//       'id': id,
//       'booker_name': bookerName,
//       'user_id': userId,
//       'login_time': loginTime,
//       'login_date': loginDate,
//       'designation': designation,
//       'company_code': companyCode,
//     };
//   }
// }

// login_tracking_model.dart
class LoginTrackingModel {
  String? id;
  String? bookerName;
  String? userId;
  String? loginTime;
  String? loginDate;
  String? designation;
  String? companyCode;
  int? posted;
  String? deviceInfo;       // NEW: combined device info (e.g., "Samsung SM-G998B")
  String? androidVersion;   // NEW: e.g., "13"
  String? deviceId;         // NEW: unique device ID

  LoginTrackingModel({
    this.id,
    this.bookerName,
    this.userId,
    this.loginTime,
    this.loginDate,
    this.designation,
    this.companyCode,
    this.posted,
    this.deviceInfo,
    this.androidVersion,
    this.deviceId,
  });

  factory LoginTrackingModel.fromMap(Map<String, dynamic> json) {
    return LoginTrackingModel(
      id: json['id'],
      bookerName: json['booker_name'],
      userId: json['user_id'],
      loginTime: json['login_time'],
      loginDate: json['login_date'],
      designation: json['designation'],
      companyCode: json['company_code'],
      posted: json['posted'],
      deviceInfo: json['device_info'],
      androidVersion: json['android_version'],
      deviceId: json['device_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'booker_name': bookerName,
      'user_id': userId,
      'login_time': loginTime,
      'login_date': loginDate,
      'designation': designation,
      'company_code': companyCode,
      'posted': posted ?? 0,
      'device_info': deviceInfo,
      'android_version': androidVersion,
      'device_id': deviceId,
    };
  }

  Map<String, dynamic> toApiPayload() {
    return {
      'id': id,
      'booker_name': bookerName,
      'user_id': userId,
      'login_time': loginTime,
      'login_date': loginDate,
      'designation': designation,
      'company_code': companyCode,
      'device_info': deviceInfo,
      'android_version': androidVersion,
      'device_id': deviceId,
    };
  }
}