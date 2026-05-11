
class LocationTrackingModel {
  final String locationtracking_id;
  final String locationtracking_date;
  final String locationtracking_time;
  final String user_id;
  final String lat_in;
  final String lng_in;
  final String booker_name;
  final String designation;
  final int posted;
  final String company_code;

  LocationTrackingModel({
    required this.locationtracking_id,
    required this.locationtracking_date,
    required this.locationtracking_time,
    required this.user_id,
    required this.lat_in,
    required this.lng_in,
    required this.booker_name,
    required this.designation,
    this.posted = 0,
    this.company_code = '',
  });

  Map<String, dynamic> toMap() => {
    'locationtracking_id': locationtracking_id,
    'locationtracking_date': locationtracking_date,
    'locationtracking_time': locationtracking_time,
    'user_id': user_id,
    'lat_in': lat_in,
    'lng_in': lng_in,
    'booker_name': booker_name,
    'designation': designation,
    'posted': posted,
    'company_code': company_code,
  };

  factory LocationTrackingModel.fromMap(Map<String, dynamic> map) =>
      LocationTrackingModel(
        locationtracking_id: map['locationtracking_id'],
        locationtracking_date: map['locationtracking_date'],
        locationtracking_time: map['locationtracking_time'],
        user_id: map['user_id'],
        lat_in: map['lat_in'],
        lng_in: map['lng_in'],
        booker_name: map['booker_name'],
        designation: map['designation'],
        posted: map['posted'] ?? 0,
        company_code: map['company_code'] ?? '',
      );
}