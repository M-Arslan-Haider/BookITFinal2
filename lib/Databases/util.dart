
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Services/FirebaseServices/firebase_remote_config.dart';


String globalselectedbrand="";
String userBrand="";
double totalDistance=0.0;
String user_id= "";
String userName="";
String userCity="";
String userDesignation="";
String? shop_visit_master_id = "";
String? returnMasterId = "";
String? order_master_id = "";
String userSM="";
String userNSM="";
String userRSM="";
String userDISPATCHER="";
String userNameRSM="";
String userNameNSM="";
String userNameSM="";
String userNameDISPATCHER="";


bool newIsClockedIn= false;
String pageName="";
String companyName="";
String companyCode="";  // ✅ ADD THIS
String? erpWorkSpace;


String? recoverySavedMonthCounter;
int? recoveryHighestSerial;
int? shopVisitHighestSerial;
int? shopVisitHeadsHighestSerial;
int? shopVisitDetailsHighestSerial;
int? orderMasterHighestSerial;
int? orderDetailsHighestSerial;
int? returnDetailsHighestSerial;
int? returnMasterHighestSerial;
int? attendanceInHighestSerial;
int? attendanceOutHighestSerial;
int? locationHighestSerial;
int? shopHighestSerial;

// bool newIsClockedIn = false;
// late Timer timer;
// int secondsPassed=0;

const addShopTableName = "addShop";
const shopVisitMasterTableName = "shopMasterVisit";
const shopVisitDetailsTableName = "shopVisitDetails";
const orderMasterTableName = "orderMaster";
const orderMasterStatusTableName = "orderMasterStatus";
const orderDetailsTableName = "orderDetails";
const returnFormMasterTableName = "reConfirmOrder";
const returnFormDetailsTableName = "returnFormDetails";
const recoveryFormTableName = "recoveryForm";
const attendanceTableName = "attendance";
const attendanceOutTableName = "attendanceOut";
const locationTableName = "location";
const productsTableName = "products";
const tableNameLogin ='login';
const headsShopVisitsTableName = 'HeadsShopVisits';

const travelTimeData = 'travelTimeData';
const travelDataMasterTable = 'travelTimeData';
const centralPointsTableName = 'central_points_table';
const locationClusters = 'locationClusters';

const String centralPoints = 'centralPoints';
const String leaveTable = 'leaveTable';
const String locationTrackingTable = 'location_tracking';
const String loginTrackingTable = 'loginTrackingTable';  // ✅ ADD THIS LINE
const String fakeGpsTable = 'fake_gps_logs';
// const String fakeGpsTable = "fake_gps_logs";
// const visit_logs = 'visit_logs';


// Future<bool> isNetworkAvailable() async {
//   var connectivityResult = await (Connectivity().checkConnectivity());
//   return connectivityResult != ConnectivityResult.none;
// }

// Function to check internet connection
// Future<bool> isNetworkAvailable() async {
//   var connectivityResult = await (Connectivity().checkConnectivity());
//
//   if (connectivityResult == ConnectivityResult.none) {
//     return false; // No internet connection
//   } else {
//     try {
//       // Test a network request to verify if internet access is available
//       // final result = await InternetAddress.lookup('google.com');
//       final result = await InternetAddress.lookup('https://cloud.metaxperts.net:8443/erp/test1/ordermasterget/get/B02');
//       if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
//         return true; // Internet connection is working
//       }
//     } catch (e) {
//       return false; // No internet connection
//     }
//   }
//   return false;
String  version="v0.3.5";
dynamic shopAddress = "";

Future<bool> isNetworkAvailable() async {
  var connectivityResult = await (Connectivity().checkConnectivity());

  if (connectivityResult == ConnectivityResult.none) {
    return false; // No internet connection
  } else {
    try {
      await Config.fetchLatestConfig();
      debugPrint( "${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.getApiUrlServer}");
      // Replace with your server URL
      final url = Uri.parse(
          "${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.getApiUrlServer}");
      // 'https://cloud.metaxperts.net:8443/erp/test1/loginget/get/');

      // Make an HTTP GET request to your server
      final response = await http.get(url).timeout(Duration(seconds: 10));

      // Check if the response status code is 200 (OK)
      if (response.statusCode == 200) {
        return true; // Server is reachable
      } else {
        return false; // Server returned an error
      }
    } on SocketException catch (_) {
      return false; // No internet connection or server unreachable
    } on TimeoutException catch (_) {
      return false; // Request timed out
    } catch (e) {
      return false; // Other errors
    }
  }
}
Future<bool> isNetworkAvailableForFirebase() async {
  var connectivityResult = await (Connectivity().checkConnectivity());

  if (connectivityResult == ConnectivityResult.none) {
    return false; // No internet connection
  } else {
    try {
      // await Config.fetchLatestConfig();
      // Replace with your server URL
      final url = Uri.parse(
        // Config.getApiUrlServerIP}{Config.getApiUrlERPCompanyName}{Config.getApiUrlServer
          "https://google.com"
      );
      // 'https://cloud.metaxperts.net:8443/erp/test1/loginget/get/');

      // Make an HTTP GET request to your server
      final response = await http.get(url).timeout(Duration(seconds: 5));

      // Check if the response status code is 200 (OK)
      if (response.statusCode == 200) {
        return true; // Server is reachable
      } else {
        return false; // Server returned an error
      }
    } on SocketException catch (_) {
      return false; // No internet connection or server unreachable
    } on TimeoutException catch (_) {
      return false; // Request timed out
    } catch (e) {
      return false; // Other errors
    }
  }
}
void checkForUpdate() async {
  try {
    final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
    if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
      await InAppUpdate.performImmediateUpdate();
    }
  } catch (e) {
    if (e is PlatformException && e.code == 'TASK_FAILURE' && e.message?.contains('Install Error(-10)') == true) {
      if (kDebugMode) {
        print("The app is not owned by any user on this device. Update check skipped.");
      }
    } else {
      if (kDebugMode) {
        print("Failed to check for updates: $e");
      }
    }
  }
}
// Future<void> checkAndSetInitializationDateTime() async {
//   SharedPreferences prefs = await SharedPreferences.getInstance();
//
//   // Check if 'lastInitializationDateTime' is already stored
//   String? lastInitDateTime = prefs.getString('lastInitializationDateTime');
//
//   if (lastInitDateTime == null) {
//     // If not, set the current date and time
//     DateTime now = DateTime.now();
//     String formattedDateTime = DateFormat('dd-MMM-yyyy-HH:mm:ss').format(now);
//     await prefs.setString('lastInitializationDateTime', formattedDateTime);
//
//       debugPrint('lastInitializationDateTime was not set, initializing to: $formattedDateTime');
//
//   } else {
//
//     debugPrint('lastInitializationDateTime is already set to: $lastInitDateTime');
//
//   }

