//
//
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import '../../Databases/util.dart';
// import 'package:intl/intl.dart';
//
// import '../../Services/FirebaseServices/firebase_remote_config.dart';
//
// class AttendanceRecordScreen extends StatefulWidget {
//   const AttendanceRecordScreen({Key? key}) : super(key: key);
//
//   @override
//   _AttendanceRecordScreenState createState() => _AttendanceRecordScreenState();
// }
//
// class _AttendanceRecordScreenState extends State<AttendanceRecordScreen> {
//   List<Map<String, dynamic>> attendanceRecords = [];
//   List<GroupedAttendance> groupedRecords = [];
//   bool isLoading = true;
//   String errorMessage = '';
//   String searchQuery = '';
//   DateTime? selectedDate;
//   String selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());
//
//   @override
//   void initState() {
//     super.initState();
//     fetchAttendanceRecords();
//   }
//
//   // Helper method to format date
//   String formatDate(String dateString) {
//     try {
//       if (dateString.isEmpty || dateString == 'N/A' || dateString == 'null') {
//         return 'N/A';
//       }
//
//       dateString = dateString.trim();
//
//       try {
//         if (dateString.contains('-')) {
//           final parts = dateString.split('-');
//           if (parts.length >= 3) {
//             final day = parts[0];
//             final month = parts[1];
//             final year = parts[2];
//
//             Map<String, String> monthMap = {
//               'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04',
//               'May': '05', 'Jun': '06', 'Jul': '07', 'Aug': '08',
//               'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12'
//             };
//
//             final monthNumber = monthMap[month] ?? '01';
//             final formattedDate = DateTime.parse('$year-$monthNumber-${day.padLeft(2, '0')}');
//             return DateFormat('dd-MMM-yyyy').format(formattedDate);
//           }
//         }
//
//         if (dateString.contains('T')) {
//           final dateTime = DateTime.parse(dateString);
//           return DateFormat('dd-MMM-yyyy').format(dateTime);
//         }
//
//         return dateString;
//       } catch (e) {
//         return dateString;
//       }
//     } catch (e) {
//       return dateString;
//     }
//   }
//
//   // Helper method to format time
//   String formatTime(String timeString) {
//     try {
//       if (timeString.isEmpty || timeString == 'N/A' || timeString == 'null') return 'N/A';
//
//       timeString = timeString.trim();
//
//       final timeParts = timeString.split(':');
//       if (timeParts.length >= 2) {
//         final hour = int.tryParse(timeParts[0]) ?? 0;
//         final minute = int.tryParse(timeParts[1]) ?? 0;
//
//         final period = hour >= 12 ? 'PM' : 'AM';
//         final hour12 = hour % 12;
//         final hourDisplay = hour12 == 0 ? 12 : hour12;
//
//         return '$hourDisplay:${minute.toString().padLeft(2, '0')} $period';
//       }
//
//       return timeString;
//     } catch (e) {
//       return timeString;
//     }
//   }
//
//   Future<void> fetchAttendanceRecords() async {
//     try {
//       setState(() {
//         isLoading = true;
//         errorMessage = '';
//       });
//
//       final baseUrl = Config.getApiUrlAttendenceScreenReport;
//       final url = '$baseUrl$user_id';
//       debugPrint('🔗 Fetching attendance from: $url');
//
//       final response = await http.get(
//           Uri.parse(url),
//           headers: {
//             'Content-Type': 'application/json',
//             'Accept': 'application/json',
//           }
//       );
//
//       debugPrint('📊 Attendance API Status: ${response.statusCode}');
//
//       if (response.statusCode == 200) {
//         final dynamic responseData = json.decode(response.body);
//         debugPrint('📊 Response Type: ${responseData.runtimeType}');
//
//         List<Map<String, dynamic>> processedData = [];
//
//         if (responseData is List) {
//           debugPrint('✅ Response is a List with ${responseData.length} items');
//
//           for (var item in responseData) {
//             if (item is Map) {
//               final Map<String, dynamic> convertedItem = {};
//               item.forEach((key, value) {
//                 convertedItem[key.toString()] = value;
//               });
//               processedData.add(_processAttendanceItem(convertedItem));
//             }
//           }
//         } else if (responseData is Map) {
//           debugPrint('✅ Response is a Map with keys: ${responseData.keys}');
//
//           final Map<String, dynamic> convertedResponse = {};
//           responseData.forEach((key, value) {
//             convertedResponse[key.toString()] = value;
//           });
//
//           bool foundList = false;
//
//           convertedResponse.forEach((key, value) {
//             if (value is List && !foundList) {
//               debugPrint('✅ Found list in key: "$key" with ${value.length} items');
//               final dataList = value;
//               for (var item in dataList) {
//                 if (item is Map) {
//                   final Map<String, dynamic> convertedItem = {};
//                   item.forEach((k, v) {
//                     convertedItem[k.toString()] = v;
//                   });
//                   processedData.add(_processAttendanceItem(convertedItem));
//                 }
//               }
//               foundList = true;
//             }
//           });
//
//           if (!foundList && convertedResponse.isNotEmpty) {
//             processedData.add(_processAttendanceItem(convertedResponse));
//           }
//         }
//
//         // Group records by date
//         groupedRecords = _groupRecordsByDate(processedData);
//
//         setState(() {
//           attendanceRecords = processedData;
//           groupedRecords = _groupRecordsByDate(processedData);
//           isLoading = false;
//         });
//
//         debugPrint('✅ Successfully loaded ${attendanceRecords.length} attendance records');
//         debugPrint('✅ Grouped into ${groupedRecords.length} days');
//       } else {
//         throw Exception('HTTP ${response.statusCode}: ${response.body}');
//       }
//     } catch (e) {
//       debugPrint('❌ Attendance API Error: $e');
//       setState(() {
//         errorMessage = e.toString();
//         isLoading = false;
//       });
//       Get.snackbar(
//         'Error',
//         'Failed to load attendance records: $e',
//         snackPosition: SnackPosition.BOTTOM,
//         backgroundColor: Colors.red,
//         colorText: Colors.white,
//       );
//     }
//   }
//
//   // Group records by date
//   List<GroupedAttendance> _groupRecordsByDate(List<Map<String, dynamic>> records) {
//     Map<String, List<Map<String, dynamic>>> groupedMap = {};
//
//     for (var record in records) {
//       String dateKey = record['formatted_date']?.toString() ?? 'N/A';
//       if (!groupedMap.containsKey(dateKey)) {
//         groupedMap[dateKey] = [];
//       }
//       groupedMap[dateKey]!.add(record);
//     }
//
//     List<GroupedAttendance> grouped = [];
//     groupedMap.forEach((date, records) {
//       // Sort records by check-in time
//       records.sort((a, b) {
//         String timeA = a['check_in_time']?.toString() ?? '';
//         String timeB = b['check_in_time']?.toString() ?? '';
//         return timeA.compareTo(timeB);
//       });
//
//       // Calculate total work hours for the day
//       String totalWorkHours = _calculateTotalWorkHours(records);
//
//       grouped.add(GroupedAttendance(
//         date: date,
//         records: records,
//         recordCount: records.length,
//         totalWorkHours: totalWorkHours,
//       ));
//     });
//
//     // Sort by date (most recent first)
//     grouped.sort((a, b) {
//       try {
//         DateTime dateA = _parseDate(a.date);
//         DateTime dateB = _parseDate(b.date);
//         return dateB.compareTo(dateA);
//       } catch (e) {
//         return 0;
//       }
//     });
//
//     return grouped;
//   }
//
//   // Calculate total work hours from multiple entries
//   String _calculateTotalWorkHours(List<Map<String, dynamic>> records) {
//     int totalMinutes = 0;
//
//     for (var record in records) {
//       String checkIn = record['check_in_time']?.toString() ?? '';
//       String checkOut = record['check_out_time']?.toString() ?? '';
//
//       if (checkIn != 'N/A' && checkOut != 'N/A' && checkIn.isNotEmpty && checkOut.isNotEmpty) {
//         try {
//           DateTime checkInTime = _parseTime(checkIn);
//           DateTime checkOutTime = _parseTime(checkOut);
//
//           if (checkOutTime.isAfter(checkInTime)) {
//             totalMinutes += checkOutTime.difference(checkInTime).inMinutes;
//           }
//         } catch (e) {
//           debugPrint('Error parsing time: $e');
//         }
//       }
//     }
//
//     int hours = totalMinutes ~/ 60;
//     int minutes = totalMinutes % 60;
//
//     if (hours > 0) {
//       return minutes > 0 ? '$hours hr $minutes min' : '$hours hr';
//     } else {
//       return minutes > 0 ? '$minutes min' : 'N/A';
//     }
//   }
//
//   DateTime _parseTime(String timeString) {
//     try {
//       // Handle format like "10:15:29"
//       final parts = timeString.split(':');
//       if (parts.length >= 2) {
//         int hour = int.parse(parts[0]);
//         int minute = int.parse(parts[1]);
//         int second = parts.length > 2 ? int.parse(parts[2]) : 0;
//
//         return DateTime(2000, 1, 1, hour, minute, second);
//       }
//       return DateTime(2000, 1, 1);
//     } catch (e) {
//       return DateTime(2000, 1, 1);
//     }
//   }
//
//   DateTime _parseDate(String dateString) {
//     try {
//       if (dateString.isEmpty || dateString == 'N/A' || dateString == 'null') {
//         return DateTime.now();
//       }
//
//       if (dateString.contains('-') && dateString.length >= 9) {
//         final parts = dateString.split('-');
//         if (parts.length >= 3) {
//           final day = parts[0];
//           final month = parts[1];
//           final year = parts[2];
//
//           Map<String, String> monthMap = {
//             'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04',
//             'May': '05', 'Jun': '06', 'Jul': '07', 'Aug': '08',
//             'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12'
//           };
//
//           final monthNumber = monthMap[month] ?? '01';
//           return DateTime.parse('$year-$monthNumber-${day.padLeft(2, '0')}');
//         }
//       }
//
//       return DateTime.now();
//     } catch (e) {
//       return DateTime.now();
//     }
//   }
//
//   Map<String, dynamic> _processAttendanceItem(Map<String, dynamic> item) {
//     debugPrint('📋 Processing attendance item: $item');
//
//     Map<String, dynamic> processedItem = {};
//
//     processedItem['attendance_id'] = item['attendance_in_id'] ??
//         item['attendance_id'] ??
//         item['Attendance_Id'] ??
//         item['id'] ??
//         'N/A';
//
//     final dateValue = item['attendance_in_date'] ??
//         item['attendance_date'] ??
//         item['Attendance_Date'] ??
//         item['date'] ??
//         'N/A';
//
//     processedItem['attendance_date'] = dateValue.toString();
//     processedItem['formatted_date'] = formatDate(dateValue.toString());
//
//     final checkInValue = item['attendance_in_time'] ??
//         item['check_in_time'] ??
//         item['Check_In_Time'] ??
//         item['punch_in_time'] ??
//         'N/A';
//
//     processedItem['check_in_time'] = checkInValue.toString();
//     processedItem['formatted_check_in'] = formatTime(checkInValue.toString());
//
//     final checkOutValue = item['attendance_out_time'] ??
//         item['check_out_time'] ??
//         item['Check_Out_Time'] ??
//         item['punch_out_time'] ??
//         'N/A';
//
//     processedItem['check_out_time'] = checkOutValue.toString();
//     processedItem['formatted_check_out'] = formatTime(checkOutValue.toString());
//
//     processedItem['booker_name'] = item['booker_name'] ?? 'N/A';
//     processedItem['designation'] = item['designation'] ?? 'N/A';
//     processedItem['city'] = item['city'] ?? 'N/A';
//     processedItem['address'] = item['address'] ?? 'N/A';
//     processedItem['remarks'] = item['remarks'] ?? '';
//     processedItem['user_id'] = item['user_id'] ?? user_id;
//     processedItem['_raw_data'] = item;
//
//     debugPrint('📋 Processed item: $processedItem');
//     return processedItem;
//   }
//
//   List<GroupedAttendance> get filteredGroupedRecords {
//     if (searchQuery.isEmpty && selectedDate == null) return groupedRecords;
//
//     return groupedRecords.where((group) {
//       // Date filter
//       bool dateMatch = true;
//       if (selectedDate != null) {
//         String formattedSelectedDate = DateFormat('dd-MMM-yyyy').format(selectedDate!);
//         dateMatch = group.date.contains(formattedSelectedDate);
//       }
//
//       // Search filter - check if any record in the group matches
//       bool searchMatch = searchQuery.isEmpty;
//       if (!searchMatch) {
//         searchMatch = group.records.any((record) {
//           return (record['status']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
//               (record['booker_name']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
//               (record['city']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
//               (record['designation']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
//               (group.date.toLowerCase().contains(searchQuery.toLowerCase()));
//         });
//       }
//
//       return dateMatch && searchMatch;
//     }).toList();
//   }
//
//   Future<void> _selectDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: DateTime.now(),
//       firstDate: DateTime(2020),
//       lastDate: DateTime.now(),
//     );
//     if (picked != null) {
//       setState(() {
//         selectedDate = picked;
//       });
//     }
//   }
//
//   void _showAttendanceDetails(Map<String, dynamic> record) {
//     Get.bottomSheet(
//       Container(
//         height: MediaQuery.of(context).size.height * 0.8,
//         padding: const EdgeInsets.all(16),
//         decoration: const BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.only(
//             topLeft: Radius.circular(20),
//             topRight: Radius.circular(20),
//           ),
//         ),
//         child: Column(
//           children: [
//             Container(
//               width: 40,
//               height: 4,
//               margin: const EdgeInsets.only(bottom: 16),
//               decoration: BoxDecoration(
//                 color: Colors.grey[300],
//                 borderRadius: BorderRadius.circular(2),
//               ),
//             ),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   'Attendance Details',
//                   style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.blueGrey[800],
//                   ),
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.close),
//                   onPressed: () => Get.back(),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             Expanded(
//               child: SingleChildScrollView(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Card(
//                       margin: const EdgeInsets.only(bottom: 16),
//                       child: Padding(
//                         padding: const EdgeInsets.all(12),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             _buildDetailRow('Attendance ID:', record['attendance_id']?.toString() ?? 'N/A'),
//                             _buildDetailRow('Date:', record['formatted_date']?.toString() ?? 'N/A'),
//                             _buildDetailRow('Check-in Time:', record['formatted_check_in']?.toString() ?? 'N/A'),
//                             _buildDetailRow('Check-out Time:', record['formatted_check_out']?.toString() ?? 'N/A'),
//                           ],
//                         ),
//                       ),
//                     ),
//                     Card(
//                       margin: const EdgeInsets.only(bottom: 16),
//                       child: Padding(
//                         padding: const EdgeInsets.all(12),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             const Text(
//                               'Employee Info',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 16,
//                                 color: Colors.blueGrey,
//                               ),
//                             ),
//                             const SizedBox(height: 8),
//                             _buildDetailRow('User ID:', record['user_id']?.toString() ?? 'N/A'),
//                             _buildDetailRow('Booker Name:', record['booker_name']?.toString() ?? 'N/A'),
//                             _buildDetailRow('Designation:', record['designation']?.toString() ?? 'N/A'),
//                             if (record['remarks']?.toString().isNotEmpty == true)
//                               _buildDetailRow('Remarks:', record['remarks']?.toString() ?? ''),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             const SizedBox(height: 16),
//             Center(
//               child: TextButton(
//                 onPressed: () => Get.back(),
//                 child: const Text('Close'),
//               ),
//             ),
//           ],
//         ),
//       ),
//       isScrollControlled: true,
//     );
//   }
//
//   Widget _buildDetailRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 10),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 100,
//             child: Text(
//               label,
//               style: const TextStyle(
//                 fontWeight: FontWeight.w500,
//                 color: Colors.grey,
//               ),
//             ),
//           ),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               value,
//               style: const TextStyle(fontSize: 15),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // Build grouped attendance card
//   Widget _buildGroupedAttendanceCard(GroupedAttendance group) {
//     final date = _parseDate(group.date);
//     final isToday = date.year == DateTime.now().year &&
//         date.month == DateTime.now().month &&
//         date.day == DateTime.now().day;
//
//     return Card(
//       margin: const EdgeInsets.only(bottom: 12),
//       elevation: 3,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//         side: isToday
//             ? BorderSide(color: Colors.blue.shade100, width: 1.5)
//             : BorderSide(color: Colors.grey.shade200, width: 1),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Date Header
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: isToday ? Colors.blue.shade50 : Colors.grey.shade100,
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(12),
//                 topRight: Radius.circular(12),
//               ),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Row(
//                   children: [
//                     Container(
//                       width: 45,
//                       height: 45,
//                       decoration: BoxDecoration(
//                         color: isToday ? Colors.blue : Colors.blueGrey,
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: Center(
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Text(
//                               DateFormat('dd').format(date),
//                               style: const TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.white,
//                               ),
//                             ),
//                             Text(
//                               DateFormat('MMM').format(date),
//                               style: const TextStyle(
//                                 fontSize: 10,
//                                 color: Colors.white70,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           group.date,
//                           style: TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                             color: isToday ? Colors.blue[800] : Colors.blueGrey[800],
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           '${group.recordCount} ${group.recordCount == 1 ? 'Entry' : 'Entries'} • Total: ${group.totalWorkHours}',
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: isToday ? Colors.blue[600] : Colors.grey[600],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//                 Icon(
//                   Icons.keyboard_arrow_down,
//                   color: Colors.grey[600],
//                 ),
//               ],
//             ),
//           ),
//
//           // List of entries for this date
//           ListView.separated(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             itemCount: group.records.length,
//             separatorBuilder: (context, index) => Divider(
//               height: 1,
//               color: Colors.grey.shade200,
//             ),
//             itemBuilder: (context, index) {
//               final record = group.records[index];
//               return ListTile(
//                 contentPadding: const EdgeInsets.symmetric(
//                   horizontal: 16,
//                   vertical: 4,
//                 ),
//                 leading: CircleAvatar(
//                   radius: 18,
//                   backgroundColor: Colors.blueGrey.shade100,
//                   child: Icon(
//                     Icons.access_time,
//                     size: 20,
//                     color: Colors.blueGrey[700],
//                   ),
//                 ),
//                 title: Row(
//                   children: [
//                     Icon(
//                       Icons.login,
//                       size: 14,
//                       color: Colors.green[600],
//                     ),
//                     const SizedBox(width: 4),
//                     Text(
//                       record['formatted_check_in']?.toString() ?? 'N/A',
//                       style: const TextStyle(
//                         fontSize: 13,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                     const SizedBox(width: 16),
//                     Icon(
//                       Icons.logout,
//                       size: 14,
//                       color: Colors.red[600],
//                     ),
//                     const SizedBox(width: 4),
//                     Text(
//                       record['formatted_check_out']?.toString() ?? 'N/A',
//                       style: const TextStyle(
//                         fontSize: 13,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ],
//                 ),
//                 subtitle: Row(
//                   children: [
//                     Icon(
//                       Icons.person,
//                       size: 12,
//                       color: Colors.grey[500],
//                     ),
//                     const SizedBox(width: 4),
//                     Text(
//                       record['booker_name']?.toString() ?? 'N/A',
//                       style: TextStyle(
//                         fontSize: 11,
//                         color: Colors.grey[600],
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Icon(
//                       Icons.location_on,
//                       size: 12,
//                       color: Colors.grey[500],
//                     ),
//                     const SizedBox(width: 4),
//                     Text(
//                       record['city']?.toString() ?? 'N/A',
//                       style: TextStyle(
//                         fontSize: 11,
//                         color: Colors.grey[600],
//                       ),
//                     ),
//                   ],
//                 ),
//                 onTap: () => _showAttendanceDetails(record),
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           'Attendance Records',
//           style: TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         backgroundColor: Colors.blueGrey,
//         centerTitle: true,
//         iconTheme: const IconThemeData(
//           color: Colors.white,
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh, color: Colors.white),
//             onPressed: fetchAttendanceRecords,
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Search and Filter Section
//           Container(
//             padding: const EdgeInsets.all(12),
//             color: Colors.grey[50],
//             child: Column(
//               children: [
//                 TextField(
//                   decoration: InputDecoration(
//                     hintText: 'Search by date, name, city, designation...',
//                     prefixIcon: const Icon(Icons.search),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     contentPadding: const EdgeInsets.symmetric(horizontal: 12),
//                   ),
//                   onChanged: (value) {
//                     setState(() {
//                       searchQuery = value;
//                     });
//                   },
//                 ),
//                 const SizedBox(height: 12),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: ElevatedButton.icon(
//                         onPressed: () => _selectDate(context),
//                         icon: const Icon(Icons.calendar_today, size: 18),
//                         label: Text(
//                           selectedDate != null
//                               ? DateFormat('dd-MMM-yyyy').format(selectedDate!)
//                               : 'Select Date',
//                           style: const TextStyle(fontSize: 14),
//                         ),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.white,
//                           foregroundColor: Colors.blueGrey,
//                           elevation: 1,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(8),
//                             side: BorderSide(color: Colors.grey.shade300),
//                           ),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     if (selectedDate != null)
//                       IconButton(
//                         icon: const Icon(Icons.clear, color: Colors.red),
//                         onPressed: () {
//                           setState(() {
//                             selectedDate = null;
//                           });
//                         },
//                         tooltip: 'Clear date filter',
//                       ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           Expanded(
//             child: _buildContent(),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildContent() {
//     if (isLoading) {
//       return const Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             CircularProgressIndicator(),
//             SizedBox(height: 16),
//             Text('Loading attendance records...'),
//           ],
//         ),
//       );
//     }
//
//     if (errorMessage.isNotEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.error, size: 64, color: Colors.red),
//             const SizedBox(height: 16),
//             const Text(
//               'Failed to load attendance',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 8),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 32),
//               child: Text(
//                 errorMessage,
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(color: Colors.grey),
//               ),
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: fetchAttendanceRecords,
//               child: const Text('Try Again'),
//             ),
//           ],
//         ),
//       );
//     }
//
//     if (groupedRecords.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
//             const SizedBox(height: 16),
//             const Text(
//               'No attendance records found',
//               style: TextStyle(fontSize: 16, color: Colors.grey),
//             ),
//             const SizedBox(height: 8),
//             ElevatedButton(
//               onPressed: fetchAttendanceRecords,
//               child: const Text('Refresh'),
//             ),
//           ],
//         ),
//       );
//     }
//
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(12),
//       child: Column(
//         children: [
//           // Records Count
//           Padding(
//             padding: const EdgeInsets.symmetric(vertical: 8),
//             child: Text(
//               'Showing ${filteredGroupedRecords.length} ${filteredGroupedRecords.length == 1 ? 'day' : 'days'} with attendance records',
//               style: const TextStyle(
//                 color: Colors.grey,
//                 fontSize: 12,
//               ),
//             ),
//           ),
//           // Grouped Attendance List
//           ...filteredGroupedRecords.map((group) => _buildGroupedAttendanceCard(group)),
//         ],
//       ),
//     );
//   }
// }
//
// // Model class for grouped attendance
// class GroupedAttendance {
//   final String date;
//   final List<Map<String, dynamic>> records;
//   final int recordCount;
//   final String totalWorkHours;
//
//   GroupedAttendance({
//     required this.date,
//     required this.records,
//     required this.recordCount,
//     required this.totalWorkHours,
//   });
// }


import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../Databases/util.dart';
import 'package:intl/intl.dart';

import '../../Services/FirebaseServices/firebase_remote_config.dart';

class AttendanceRecordScreen extends StatefulWidget {
  const AttendanceRecordScreen({Key? key}) : super(key: key);

  @override
  _AttendanceRecordScreenState createState() => _AttendanceRecordScreenState();
}

class _AttendanceRecordScreenState extends State<AttendanceRecordScreen> {
  List<Map<String, dynamic>> attendanceRecords = [];
  List<GroupedAttendance> groupedRecords = [];
  bool isLoading = true;
  String errorMessage = '';
  String searchQuery = '';
  DateTime? selectedDate;
  String selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    fetchAttendanceRecords();
  }

  // Helper method to format date
  String formatDate(String dateString) {
    try {
      if (dateString.isEmpty || dateString == 'N/A' || dateString == 'null') {
        return 'N/A';
      }

      dateString = dateString.trim();

      try {
        // Handle format like "24-APR-26" or "24-APR-2026"
        if (dateString.contains('-')) {
          final parts = dateString.split('-');
          if (parts.length >= 3) {
            String day = parts[0];
            String month = parts[1].toUpperCase();
            String year = parts[2];

            // Handle 2-digit year (e.g., "26" -> "2026")
            if (year.length == 2) {
              year = '20$year';
            }

            Map<String, String> monthMap = {
              'JAN': '01', 'FEB': '02', 'MAR': '03', 'APR': '04',
              'MAY': '05', 'JUN': '06', 'JUL': '07', 'AUG': '08',
              'SEP': '09', 'OCT': '10', 'NOV': '11', 'DEC': '12'
            };

            final monthNumber = monthMap[month] ?? '01';
            final formattedDate = DateTime.parse('$year-$monthNumber-${day.padLeft(2, '0')}');
            return DateFormat('dd-MMM-yyyy').format(formattedDate);
          }
        }

        // Handle format like "21-Jan-2026"
        if (dateString.contains('-')) {
          final parts = dateString.split('-');
          if (parts.length >= 3) {
            final day = parts[0];
            final month = parts[1];
            final year = parts[2];

            Map<String, String> monthMap = {
              'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04',
              'May': '05', 'Jun': '06', 'Jul': '07', 'Aug': '08',
              'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12'
            };

            final monthNumber = monthMap[month] ?? '01';
            final formattedDate = DateTime.parse('$year-$monthNumber-${day.padLeft(2, '0')}');
            return DateFormat('dd-MMM-yyyy').format(formattedDate);
          }
        }

        if (dateString.contains('T')) {
          final dateTime = DateTime.parse(dateString);
          return DateFormat('dd-MMM-yyyy').format(dateTime);
        }

        return dateString;
      } catch (e) {
        return dateString;
      }
    } catch (e) {
      return dateString;
    }
  }

  // Helper method to format time
  String formatTime(String timeString) {
    try {
      if (timeString.isEmpty || timeString == 'N/A' || timeString == 'null') return 'N/A';

      timeString = timeString.trim();

      final timeParts = timeString.split(':');
      if (timeParts.length >= 2) {
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = int.tryParse(timeParts[1]) ?? 0;

        final period = hour >= 12 ? 'PM' : 'AM';
        final hour12 = hour % 12;
        final hourDisplay = hour12 == 0 ? 12 : hour12;

        return '$hourDisplay:${minute.toString().padLeft(2, '0')} $period';
      }

      return timeString;
    } catch (e) {
      return timeString;
    }
  }

  Future<void> fetchAttendanceRecords() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      // Get URL from Firebase Remote Config
      final baseUrl = Config.getApiUrlAttendenceScreenReport;
      final url = '$baseUrl$user_id';
      debugPrint('🔗 Fetching attendance from: $url');

      final response = await http.get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          }
      );

      debugPrint('📊 Attendance API Status: ${response.statusCode}');
      debugPrint('📊 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);
        debugPrint('📊 Response Type: ${responseData.runtimeType}');

        List<Map<String, dynamic>> processedData = [];

        // Handle different response formats
        if (responseData is List) {
          debugPrint('✅ Response is a List with ${responseData.length} items');
          for (var item in responseData) {
            if (item is Map) {
              // Convert Map<dynamic, dynamic> to Map<String, dynamic>
              Map<String, dynamic> convertedItem = {};
              item.forEach((key, value) {
                convertedItem[key.toString()] = value;
              });
              processedData.add(_processAttendanceItem(convertedItem));
            }
          }
        } else if (responseData is Map) {
          debugPrint('✅ Response is a Map with keys: ${responseData.keys}');

          // Check if there's a data array in the response
          bool foundList = false;

          responseData.forEach((key, value) {
            if (value is List && !foundList) {
              debugPrint('✅ Found list in key: "$key" with ${value.length} items');
              for (var item in value) {
                if (item is Map) {
                  // Convert Map<dynamic, dynamic> to Map<String, dynamic>
                  Map<String, dynamic> convertedItem = {};
                  item.forEach((k, v) {
                    convertedItem[k.toString()] = v;
                  });
                  processedData.add(_processAttendanceItem(convertedItem));
                }
              }
              foundList = true;
            }
          });

          // If no list found but map has attendance data directly
          if (!foundList && responseData.isNotEmpty) {
            if (responseData.containsKey('ATTENDANCE_DATE') ||
                responseData.containsKey('TIME_IN')) {
              // Convert Map<dynamic, dynamic> to Map<String, dynamic>
              Map<String, dynamic> convertedItem = {};
              responseData.forEach((key, value) {
                convertedItem[key.toString()] = value;
              });
              processedData.add(_processAttendanceItem(convertedItem));
            }
          }
        }

        // Filter out records with null/empty attendance date
        processedData = processedData.where((record) {
          return record['attendance_date'] != 'N/A' &&
              record['attendance_date'] != 'null' &&
              record['attendance_date'].toString().isNotEmpty;
        }).toList();

        // Sort by date (most recent first)
        if (processedData.isNotEmpty) {
          processedData.sort((a, b) {
            try {
              final dateA = _parseDate(a['attendance_date']?.toString() ?? '');
              final dateB = _parseDate(b['attendance_date']?.toString() ?? '');
              return dateB.compareTo(dateA);
            } catch (e) {
              return 0;
            }
          });
        }

        setState(() {
          attendanceRecords = processedData;
          groupedRecords = _groupRecordsByDate(processedData);
          isLoading = false;
        });

        debugPrint('✅ Successfully loaded ${attendanceRecords.length} attendance records');
        debugPrint('✅ Grouped into ${groupedRecords.length} days');

        if (attendanceRecords.isEmpty) {
          Get.snackbar(
            'Info',
            'No attendance records found for this user',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.blue,
            colorText: Colors.white,
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Attendance API Error: $e');
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
      Get.snackbar(
        'Error',
        'Failed to load attendance records: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
  // Group records by date
  List<GroupedAttendance> _groupRecordsByDate(List<Map<String, dynamic>> records) {
    Map<String, List<Map<String, dynamic>>> groupedMap = {};

    for (var record in records) {
      String dateKey = record['formatted_date']?.toString() ?? 'N/A';
      if (!groupedMap.containsKey(dateKey)) {
        groupedMap[dateKey] = [];
      }
      groupedMap[dateKey]!.add(record);
    }

    List<GroupedAttendance> grouped = [];
    groupedMap.forEach((date, records) {
      // Sort records by check-in time
      records.sort((a, b) {
        String timeA = a['check_in_time']?.toString() ?? '';
        String timeB = b['check_in_time']?.toString() ?? '';
        return timeA.compareTo(timeB);
      });

      // Calculate total work hours for the day
      String totalWorkHours = _calculateTotalWorkHours(records);

      grouped.add(GroupedAttendance(
        date: date,
        records: records,
        recordCount: records.length,
        totalWorkHours: totalWorkHours,
      ));
    });

    // Sort by date (most recent first)
    grouped.sort((a, b) {
      try {
        DateTime dateA = _parseDate(a.date);
        DateTime dateB = _parseDate(b.date);
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });

    return grouped;
  }

  // Calculate total work hours from multiple entries
  String _calculateTotalWorkHours(List<Map<String, dynamic>> records) {
    int totalMinutes = 0;

    for (var record in records) {
      String checkIn = record['check_in_time']?.toString() ?? '';
      String checkOut = record['check_out_time']?.toString() ?? '';

      if (checkIn != 'N/A' && checkOut != 'N/A' && checkIn.isNotEmpty && checkOut.isNotEmpty) {
        try {
          DateTime checkInTime = _parseTime(checkIn);
          DateTime checkOutTime = _parseTime(checkOut);

          if (checkOutTime.isAfter(checkInTime)) {
            totalMinutes += checkOutTime.difference(checkInTime).inMinutes;
          }
        } catch (e) {
          debugPrint('Error parsing time: $e');
        }
      }
    }

    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;

    if (hours > 0) {
      return minutes > 0 ? '$hours hr $minutes min' : '$hours hr';
    } else {
      return minutes > 0 ? '$minutes min' : 'N/A';
    }
  }

  DateTime _parseTime(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        int second = parts.length > 2 ? int.parse(parts[2]) : 0;
        return DateTime(2000, 1, 1, hour, minute, second);
      }
      return DateTime(2000, 1, 1);
    } catch (e) {
      return DateTime(2000, 1, 1);
    }
  }

  DateTime _parseDate(String dateString) {
    try {
      if (dateString.isEmpty || dateString == 'N/A' || dateString == 'null') {
        return DateTime.now();
      }

      // Handle format like "24-APR-26" or "24-APR-2026"
      if (dateString.contains('-')) {
        final parts = dateString.split('-');
        if (parts.length >= 3) {
          String day = parts[0];
          String month = parts[1].toUpperCase();
          String year = parts[2];

          // Handle 2-digit year (e.g., "26" -> "2026")
          if (year.length == 2) {
            year = '20$year';
          }

          Map<String, String> monthMap = {
            'JAN': '01', 'FEB': '02', 'MAR': '03', 'APR': '04',
            'MAY': '05', 'JUN': '06', 'JUL': '07', 'AUG': '08',
            'SEP': '09', 'OCT': '10', 'NOV': '11', 'DEC': '12'
          };

          final monthNumber = monthMap[month] ?? '01';
          return DateTime.parse('$year-$monthNumber-${day.padLeft(2, '0')}');
        }
      }

      // Handle format like "21-Jan-2026"
      if (dateString.contains('-') && dateString.length >= 9) {
        final parts = dateString.split('-');
        if (parts.length >= 3) {
          final day = parts[0];
          final month = parts[1];
          final year = parts[2];

          Map<String, String> monthMap = {
            'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04',
            'May': '05', 'Jun': '06', 'Jul': '07', 'Aug': '08',
            'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12'
          };

          final monthNumber = monthMap[month] ?? '01';
          return DateTime.parse('$year-$monthNumber-${day.padLeft(2, '0')}');
        }
      }

      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  Map<String, dynamic> _processAttendanceItem(Map<String, dynamic> item) {
    debugPrint('📋 Processing attendance item: $item');

    Map<String, dynamic> processedItem = {};

    // Map attendance ID
    processedItem['attendance_id'] = item['ID'] ??
        item['attendance_in_id'] ??
        item['attendance_id'] ??
        'N/A';

    // Get date value - using ATTENDANCE_DATE from API
    final dateValue = item['ATTENDANCE_DATE'] ??
        item['attendance_in_date'] ??
        item['attendance_date'] ??
        item['date'] ??
        'N/A';

    processedItem['attendance_date'] = dateValue.toString();
    processedItem['formatted_date'] = formatDate(dateValue.toString());

    // Get check-in time - using TIME_IN from API
    final checkInValue = item['TIME_IN'] ??
        item['attendance_in_time'] ??
        item['check_in_time'] ??
        item['punch_in_time'] ??
        'N/A';

    processedItem['check_in_time'] = checkInValue.toString();
    processedItem['formatted_check_in'] = formatTime(checkInValue.toString());

    // Get check-out time - using TIME_OUT from API
    final checkOutValue = item['TIME_OUT'] ??
        item['attendance_out_time'] ??
        item['check_out_time'] ??
        item['punch_out_time'] ??
        'N/A';

    processedItem['check_out_time'] = checkOutValue.toString();
    processedItem['formatted_check_out'] = formatTime(checkOutValue.toString());

    // Get employee info - using USER_NAME from API
    processedItem['booker_name'] = item['USER_NAME'] ??
        item['booker_name'] ??
        item['name'] ??
        'N/A';

    processedItem['designation'] = item['DESIGNATION'] ??
        item['designation'] ??
        item['role'] ??
        'N/A';

    processedItem['city'] = item['CITY'] ??
        item['city'] ??
        item['location'] ??
        'N/A';

    processedItem['address'] = item['ADDRESS'] ??
        item['address'] ??
        'N/A';

    processedItem['remarks'] = item['REMARKS'] ??
        item['remarks'] ??
        item['note'] ??
        '';

    processedItem['user_id'] = item['USER_ID'] ??
        item['user_id'] ??
        item['USERID'] ??
        user_id;

    // Store total time and distance if needed
    processedItem['total_time'] = item['TOTAL_TIME'] ?? 'N/A';
    processedItem['total_distance'] = item['TOTAL_DISTANCE'] ?? 'N/A';

    processedItem['_raw_data'] = item;

    debugPrint('📋 Processed item - Date: ${processedItem['formatted_date']}, '
        'Check-in: ${processedItem['formatted_check_in']}, '
        'Check-out: ${processedItem['formatted_check_out']}, '
        'User: ${processedItem['booker_name']}');
    return processedItem;
  }

  List<GroupedAttendance> get filteredGroupedRecords {
    if (searchQuery.isEmpty && selectedDate == null) return groupedRecords;

    return groupedRecords.where((group) {
      // Date filter
      bool dateMatch = true;
      if (selectedDate != null) {
        String formattedSelectedDate = DateFormat('dd-MMM-yyyy').format(selectedDate!);
        dateMatch = group.date.contains(formattedSelectedDate);
      }

      // Search filter
      bool searchMatch = searchQuery.isEmpty;
      if (!searchMatch) {
        searchMatch = group.records.any((record) {
          return (record['status']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
              (record['booker_name']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
              (record['city']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
              (record['designation']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
              (group.date.toLowerCase().contains(searchQuery.toLowerCase()));
        });
      }

      return dateMatch && searchMatch;
    }).toList();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  void _showAttendanceDetails(Map<String, dynamic> record) {
    Get.bottomSheet(
      Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Attendance Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Attendance ID:', record['attendance_id']?.toString() ?? 'N/A'),
                            _buildDetailRow('Date:', record['formatted_date']?.toString() ?? 'N/A'),
                            _buildDetailRow('Check-in Time:', record['formatted_check_in']?.toString() ?? 'N/A'),
                            _buildDetailRow('Check-out Time:', record['formatted_check_out']?.toString() ?? 'N/A'),
                            if (record['total_time'] != 'N/A')
                              _buildDetailRow('Total Time:', record['total_time']?.toString() ?? 'N/A'),
                            if (record['total_distance'] != 'N/A' && record['total_distance'] != '0.0')
                              _buildDetailRow('Total Distance:', '${record['total_distance']} km'),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Employee Info',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blueGrey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow('User ID:', record['user_id']?.toString() ?? 'N/A'),
                            _buildDetailRow('Booker Name:', record['booker_name']?.toString() ?? 'N/A'),
                            _buildDetailRow('Designation:', record['designation']?.toString() ?? 'N/A'),
                            if (record['remarks']?.toString().isNotEmpty == true)
                              _buildDetailRow('Remarks:', record['remarks']?.toString() ?? ''),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => Get.back(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedAttendanceCard(GroupedAttendance group) {
    final date = _parseDate(group.date);
    final isToday = date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isToday
            ? BorderSide(color: Colors.blue.shade100, width: 1.5)
            : BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isToday ? Colors.blue.shade50 : Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: isToday ? Colors.blue : Colors.blueGrey,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('dd').format(date),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              DateFormat('MMM').format(date),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.date,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isToday ? Colors.blue[800] : Colors.blueGrey[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${group.recordCount} ${group.recordCount == 1 ? 'Entry' : 'Entries'} • Total: ${group.totalWorkHours}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isToday ? Colors.blue[600] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
          // List of entries for this date
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: group.records.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey.shade200,
            ),
            itemBuilder: (context, index) {
              final record = group.records[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.blueGrey.shade100,
                  child: Icon(
                    Icons.access_time,
                    size: 20,
                    color: Colors.blueGrey[700],
                  ),
                ),
                title: Row(
                  children: [
                    Icon(
                      Icons.login,
                      size: 14,
                      color: Colors.green[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      record['formatted_check_in']?.toString() ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.logout,
                      size: 14,
                      color: Colors.red[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      record['formatted_check_out']?.toString() ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                subtitle: Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 12,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      record['booker_name']?.toString() ?? 'N/A',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.location_on,
                      size: 12,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      record['city']?.toString() ?? 'N/A',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                onTap: () => _showAttendanceDetails(record),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Attendance Records',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.blueGrey,
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchAttendanceRecords,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[50],
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by date, name, city, designation...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _selectDate(context),
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          selectedDate != null
                              ? DateFormat('dd-MMM-yyyy').format(selectedDate!)
                              : 'Select Date',
                          style: const TextStyle(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blueGrey,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (selectedDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            selectedDate = null;
                          });
                        },
                        tooltip: 'Clear date filter',
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading attendance records...'),
          ],
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Failed to load attendance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: fetchAttendanceRecords,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (groupedRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No attendance records found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: fetchAttendanceRecords,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Records Count
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Showing ${filteredGroupedRecords.length} ${filteredGroupedRecords.length == 1 ? 'day' : 'days'} with attendance records',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
          // Grouped Attendance List
          ...filteredGroupedRecords.map((group) => _buildGroupedAttendanceCard(group)),
        ],
      ),
    );
  }
}

// Model class for grouped attendance
class GroupedAttendance {
  final String date;
  final List<Map<String, dynamic>> records;
  final int recordCount;
  final String totalWorkHours;

  GroupedAttendance({
    required this.date,
    required this.records,
    required this.recordCount,
    required this.totalWorkHours,
  });
}