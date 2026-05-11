//
// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:order_booking_app/Screens/home_screen.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../../Models/LoginModels/login_models.dart';
// import '../Databases/dp_helper.dart';
// import '../Databases/util.dart';
// import '../Repositories/LoginRepositories/login_repository.dart';
// import '../Repositories/LoginRepositories/login_tracking_repository.dart';
// import '../Screens/Dispatcher/dispatcher_homepage.dart';
// import '../Screens/NSM/nsm_homepage.dart';
// import '../Screens/RSMS_Views/RSM_HomePage.dart';
// import '../Screens/SM/sm_homepage.dart';
//
//
// class LoginViewModel extends GetxController {
//
//   var allLogin = <LoginModels>[].obs;
//   LoginRepository loginRepository = LoginRepository();
//
//   // ✅ FIX: Repository directly yahan banao — koi GetX dependency nahi
//   final LoginTrackingRepository _loginTrackingRepository = LoginTrackingRepository();
//
//   DBHelper dbHelper = Get.put(DBHelper());
//   var isAuthenticated = false.obs;
//   var bookers = <dynamic>[].obs;
//   var bookersId = <LoginModels>[].obs;
//
//
//   @override
//   void onInit() {
//     super.onInit();
//   }
//
//   fetchBookerNamesBySMDesignation() async {
//     var smnames = await loginRepository.getBookerNamesBySMDesignation();
//     bookers.value = smnames;
//   }
//
//   Future<void> fetchBookerIds(String columnName) async {
//     try {
//       debugPrint('Fetching booker IDs...');
//       var savedShops = await loginRepository.getBookerNamesByDesignation(columnName, user_id);
//       debugPrint('Fetched booker IDs: ${savedShops.map((e) => e.user_id).toList()}');
//
//       bookers.value = savedShops.map((userIds) => userIds.user_id).toList();
//       bookersId.value = savedShops;
//
//       debugPrint('Bookers list for dropdown: ${bookers.value}');
//     } catch (e) {
//       debugPrint('Failed to fetch bookers: $e');
//     }
//   }
//
//   Future<void> checkInternetBeforeNavigation() async {
//     bool hasInternet = await isNetworkAvailable();
//
//     if (!hasInternet) {
//       await Future.delayed(const Duration(seconds: 5));
//       exit(0);
//     } else {
//       await fetchAndSaveLoginData();
//     }
//   }
//
//   Future<void> checkAuthentication() async {
//     final prefs = await SharedPreferences.getInstance();
//     isAuthenticated.value = prefs.getBool('isAuthenticated') ?? false;
//   }
//
//   Future<bool> login(String userId, String password) async {
//     try {
//       // Step 1: Authenticate user
//       final user = await loginRepository.getUserByCredentials(userId, password);
//
//       if (user == null) {
//         isAuthenticated.value = false;
//         return false;
//       }
//
//       // Step 2: Fetch user details
//       var userDetails = await loginRepository.getUserDetailsById(userId);
//       if (userDetails == null) {
//         isAuthenticated.value = false;
//         return false;
//       }
//
//       // Step 3: Extract and store user details
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.reload();
//
//       await prefs.setString('userName', userDetails['user_name'] ?? "");
//       await prefs.setString('userCity', userDetails['city'] ?? "");
//       await prefs.setString('userDesignation', userDetails['designation'] ?? "");
//       await prefs.setString('userBrand', userDetails['brand'] ?? "");
//       await prefs.setString('userRSM', userDetails['rsm_id'] ?? "");
//       await prefs.setString('userSM', userDetails['sm_id'] ?? "");
//       await prefs.setString('userNSM', userDetails['nsm_id'] ?? "");
//       await prefs.setString('userDISPATCHER', userDetails['dispatcher_id'] ?? "");
//       await prefs.setString('userNameNSM', userDetails['nsm'] ?? "");
//       await prefs.setString('userNameRSM', userDetails['rsm'] ?? "");
//       await prefs.setString('userNameSM', userDetails['sm'] ?? "");
//       await prefs.setString('userNameDISPATCHER', userDetails['dispatcher'] ?? "");
//
//       await _loginRetrieveSavedValues();
//
//       // ✅ FIX: GetX ke chakkar se bilkul bahar — directly repository call karo
//       // Koi Get.put / Get.find nahi — yeh 100% kaam karega
//       try {
//         debugPrint('🚀 [LoginVM] Login tracking shuru kar raha hai...');
//         await _loginTrackingRepository.createAndPostLoginRecord(
//           userId: userId,
//           bookerName: userDetails['user_name'] ?? '',
//           designation: userDetails['designation'] ?? '',
//           companyCode: userDetails['brand'] ?? '',
//         );
//         debugPrint('✅ [LoginVM] Login tracking complete');
//       } catch (trackingError) {
//         // Tracking fail ho toh bhi login hone do — critical nahi hai
//         debugPrint('⚠️ [LoginVM] Login tracking error (login phir bhi hoga): $trackingError');
//       }
//
//       // Step 4: Set authentication state
//       isAuthenticated.value = true;
//       await prefs.setBool('isAuthenticated', true);
//
//       return true;
//     } catch (e) {
//       debugPrint("Login failed with error: $e");
//       isAuthenticated.value = false;
//       return false;
//     }
//   }
//
//   navigateToHomePage() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     userDesignation = prefs.getString('userDesignation') ?? '';
//
//     switch (userDesignation) {
//       case 'RSM':
//         pageName = "/RSMHomepage";
//         Get.to(() => const RSMHomepage());
//         break;
//       case 'SM':
//         pageName = "/SMHomepage";
//         Get.to(() => const SMHomepage());
//         break;
//       case 'NSM':
//         pageName = "/NSMHomepage";
//         Get.to(() => const NSMHomepage());
//         break;
//       case 'DISPATCHER':
//         pageName = "/DispatcherHomepage";
//         Get.to(() => const DispatcherHomepage());
//         break;
//       default:
//         pageName = "/home";
//         Get.to(() => const HomeScreen());
//         break;
//     }
//
//     await prefs.setString('pageName', pageName);
//   }
//
//   _loginRetrieveSavedValues() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//
//     user_id = prefs.getString('userId') ?? '';
//     userName = prefs.getString('userName') ?? '';
//     userCity = prefs.getString('userCity') ?? '';
//     userDesignation = prefs.getString('userDesignation') ?? '';
//     userBrand = prefs.getString('userBrand') ?? '';
//     userSM = prefs.getString('userSM') ?? '';
//     userNSM = prefs.getString('userNSM') ?? '';
//     userRSM = prefs.getString('userRSM') ?? '';
//     userDISPATCHER = prefs.getString('userDISPATCHER') ?? '';
//   }
//
//   logout() async {
//     isAuthenticated.value = false;
//
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool('isAuthenticated', false);
//     await prefs.remove("userId");
//
//     await dbHelper.clearData();
//   }
//
//   fetchAllLogin() async {
//     var login = await loginRepository.getLogin();
//     allLogin.value = login;
//   }
//
//   getBookerNamesByRSMDesignation() async {
//     var bookers = await loginRepository.getBookerNamesByDesignation('rsm_id', user_id);
//   }
//
//   fetchAndSaveLoginData() async {
//     await loginRepository.fetchAndSaveLogin();
//     fetchAllLogin();
//   }
//
//   addLogin(LoginModels loginModels) {
//     loginRepository.add(loginModels);
//   }
//
//   updateLogin(LoginModels loginModels) {
//     loginRepository.update(loginModels);
//     fetchAllLogin();
//   }
//
//   deleteLogin(int id) {
//     loginRepository.delete(id);
//     fetchAllLogin();
//   }
// }
//


import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:order_booking_app/Screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Models/LoginModels/login_models.dart';
import '../Databases/dp_helper.dart';
import '../Databases/util.dart';
import '../Repositories/LoginRepositories/login_repository.dart';
import '../Repositories/LoginRepositories/login_tracking_repository.dart';
import '../Screens/Dispatcher/dispatcher_homepage.dart';
import '../Screens/NSM/nsm_homepage.dart';
import '../Screens/RSMS_Views/RSM_HomePage.dart';
import '../Screens/SM/sm_homepage.dart';
import '../Services/Biometric/biometric_services.dart';

class LoginViewModel extends GetxController {

  var allLogin = <LoginModels>[].obs;
  LoginRepository loginRepository = LoginRepository();

  final LoginTrackingRepository _loginTrackingRepository =
  LoginTrackingRepository();

  DBHelper dbHelper = Get.put(DBHelper());
  var isAuthenticated = false.obs;
  var bookers    = <dynamic>[].obs;
  var bookersId  = <LoginModels>[].obs;

  @override
  void onInit() {
    super.onInit();
  }

  // ── Existing helpers ───────────────────────────────────────────────────────

  fetchBookerNamesBySMDesignation() async {
    var smnames = await loginRepository.getBookerNamesBySMDesignation();
    bookers.value = smnames;
  }

  Future<void> fetchBookerIds(String columnName) async {
    try {
      debugPrint('Fetching booker IDs...');
      var savedShops =
      await loginRepository.getBookerNamesByDesignation(columnName, user_id);
      bookers.value = savedShops.map((u) => u.user_id).toList();
      bookersId.value = savedShops;
    } catch (e) {
      debugPrint('Failed to fetch bookers: $e');
    }
  }

  Future<void> checkInternetBeforeNavigation() async {
    bool hasInternet = await isNetworkAvailable();
    if (!hasInternet) {
      await Future.delayed(const Duration(seconds: 5));
      exit(0);
    } else {
      await fetchAndSaveLoginData();
    }
  }

  Future<void> checkAuthentication() async {
    final prefs = await SharedPreferences.getInstance();
    isAuthenticated.value = prefs.getBool('isAuthenticated') ?? false;
  }

  // ── Normal password login ─────────────────────────────────────────────────

  Future<bool> login(String userId, String password) async {
    try {
      final user = await loginRepository.getUserByCredentials(userId, password);
      if (user == null) { isAuthenticated.value = false; return false; }

      var userDetails = await loginRepository.getUserDetailsById(userId);
      if (userDetails == null) { isAuthenticated.value = false; return false; }

      await _saveUserDetails(userId, userDetails);
      await _loginRetrieveSavedValues();

      // FIX 3: Fire-and-forget — don't await tracking, it should never block login
      unawaited(_postLoginTracking(userId, userDetails));

      isAuthenticated.value = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAuthenticated', true);
      return true;
    } catch (e) {
      debugPrint("Login failed with error: $e");
      isAuthenticated.value = false;
      return false;
    }
  }

  // ── Biometric login ────────────────────────────────────────────────────────
  //
  //  Returns the userId + userDetails map so the screen can run
  //  data-sync tasks (same as normal login) before navigating.
  //  Returns null on any failure.
  //
  Future<Map<String, dynamic>?> loginWithBiometric() async {
    try {
      final bio = BiometricService.instance;

      // FIX 1: Check enabled (SharedPrefs, fast) AND available (3 platform
      //         calls) in PARALLEL — not sequential.
      final checks = await Future.wait([
        bio.isEnabled(),
        bio.isAvailable(),
      ]);
      final bool enabled   = checks[0] as bool;
      final bool available = checks[1] as bool;

      if (!enabled) {
        debugPrint('⚠️ [Biometric] Not enabled for any user');
        return null;
      }
      if (!available) {
        debugPrint('⚠️ [Biometric] Hardware not available');
        return null;
      }

      // Prompt fingerprint scan
      final authenticated = await bio.authenticate();
      if (!authenticated) {
        debugPrint('❌ [Biometric] Fingerprint rejected or cancelled');
        return null;
      }

      final registeredId = await bio.registeredUserId();
      if (registeredId.isEmpty) {
        debugPrint('⚠️ [Biometric] No registered userId found');
        return null;
      }

      debugPrint('✅ [Biometric] Fingerprint OK for userId=$registeredId');

      var userDetails = await loginRepository.getUserDetailsById(registeredId);
      if (userDetails == null) {
        debugPrint('⚠️ [Biometric] User not found in DB for $registeredId');
        return null;
      }

      // Save session
      await _saveUserDetails(registeredId, userDetails);
      await _loginRetrieveSavedValues();

      // FIX 3: Non-blocking tracking
      unawaited(_postLoginTracking(registeredId, userDetails));

      isAuthenticated.value = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAuthenticated', true);

      debugPrint('✅ [Biometric] Login complete for ${userDetails['user_name']}');

      // Return userId so the screen can run the same data-sync as normal login
      return {'userId': registeredId, ...Map<String, dynamic>.from(userDetails)};
    } catch (e) {
      debugPrint('❌ [Biometric] loginWithBiometric error: $e');
      return null;
    }
  }

  // ── Enable / disable biometric ────────────────────────────────────────────

  Future<bool> enableBiometric() async {
    return BiometricService.instance.enable(user_id, userName);
  }

  Future<void> disableBiometric() async {
    await BiometricService.instance.disable();
  }

  // ── Navigation after login ────────────────────────────────────────────────

  navigateToHomePage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userDesignation = prefs.getString('userDesignation') ?? '';

    switch (userDesignation) {
      case 'RSM':
        pageName = "/RSMHomepage";
        Get.to(() => const RSMHomepage());
        break;
      case 'SM':
        pageName = "/SMHomepage";
        Get.to(() => const SMHomepage());
        break;
      case 'NSM':
        pageName = "/NSMHomepage";
        Get.to(() => const NSMHomepage());
        break;
      case 'DISPATCHER':
        pageName = "/DispatcherHomepage";
        Get.to(() => const DispatcherHomepage());
        break;
      default:
        pageName = "/home";
        Get.to(() => const HomeScreen());
        break;
    }

    await prefs.setString('pageName', pageName);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _saveUserDetails(String userId, Map userDetails) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    await Future.wait([
      prefs.setString('userId',              userId),
      prefs.setString('userName',            userDetails['user_name']      ?? ""),
      prefs.setString('userCity',            userDetails['city']           ?? ""),
      prefs.setString('userDesignation',     userDetails['designation']    ?? ""),
      prefs.setString('userBrand',           userDetails['brand']          ?? ""),
      prefs.setString('userRSM',             userDetails['rsm_id']         ?? ""),
      prefs.setString('userSM',              userDetails['sm_id']          ?? ""),
      prefs.setString('userNSM',             userDetails['nsm_id']         ?? ""),
      prefs.setString('userDISPATCHER',      userDetails['dispatcher_id']  ?? ""),
      prefs.setString('userNameNSM',         userDetails['nsm']            ?? ""),
      prefs.setString('userNameRSM',         userDetails['rsm']            ?? ""),
      prefs.setString('userNameSM',          userDetails['sm']             ?? ""),
      prefs.setString('userNameDISPATCHER',  userDetails['dispatcher']     ?? ""),
    ]);
  }

  /// Fire-and-forget — failure is swallowed, never blocks login.
  Future<void> _postLoginTracking(String userId, Map userDetails) async {
    try {
      debugPrint('🚀 [LoginVM] Login tracking...');
      await _loginTrackingRepository.createAndPostLoginRecord(
        userId:      userId,
        bookerName:  userDetails['user_name']   ?? '',
        designation: userDetails['designation'] ?? '',
        companyCode: userDetails['brand']       ?? '',
      );
      debugPrint('✅ [LoginVM] Login tracking complete');
    } catch (e) {
      debugPrint('⚠️ [LoginVM] Login tracking error (login still proceeds): $e');
    }
  }

  _loginRetrieveSavedValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    user_id         = prefs.getString('userId')          ?? '';
    userName        = prefs.getString('userName')        ?? '';
    userCity        = prefs.getString('userCity')        ?? '';
    userDesignation = prefs.getString('userDesignation') ?? '';
    userBrand       = prefs.getString('userBrand')       ?? '';
    userSM          = prefs.getString('userSM')          ?? '';
    userNSM         = prefs.getString('userNSM')         ?? '';
    userRSM         = prefs.getString('userRSM')         ?? '';
    userDISPATCHER  = prefs.getString('userDISPATCHER')  ?? '';
  }

  logout() async {
    isAuthenticated.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAuthenticated', false);
    await prefs.remove("userId");
    await dbHelper.clearData();
  }

  fetchAllLogin() async {
    var login = await loginRepository.getLogin();
    allLogin.value = login;
  }

  getBookerNamesByRSMDesignation() async {
    await loginRepository.getBookerNamesByDesignation('rsm_id', user_id);
  }

  fetchAndSaveLoginData() async {
    await loginRepository.fetchAndSaveLogin();
    fetchAllLogin();
  }

  addLogin(LoginModels loginModels) {
    loginRepository.add(loginModels);
  }

  updateLogin(LoginModels loginModels) {
    loginRepository.update(loginModels);
    fetchAllLogin();
  }

  deleteLogin(int id) {
    loginRepository.delete(id);
    fetchAllLogin();
  }
}