

import 'dart:io';
import 'package:auto_route/annotations.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:order_booking_app/ViewModels/ProductsViewModel.dart';
import 'package:order_booking_app/ViewModels/add_shop_view_model.dart';
import 'package:order_booking_app/ViewModels/attendance_out_view_model.dart';
import 'package:order_booking_app/ViewModels/attendance_view_model.dart';
import 'package:order_booking_app/ViewModels/location_view_model.dart';
import 'package:order_booking_app/ViewModels/login_view_model.dart';
import 'package:order_booking_app/ViewModels/order_details_view_model.dart';
import 'package:order_booking_app/ViewModels/order_master_view_model.dart';
import 'package:order_booking_app/ViewModels/recovery_form_view_model.dart';
import 'package:order_booking_app/ViewModels/shop_visit_details_view_model.dart';
import 'package:order_booking_app/ViewModels/shop_visit_view_model.dart';
import 'package:order_booking_app/ViewModels/update_function_view_model.dart';
import 'package:order_booking_app/widgets/bookit_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Databases/util.dart';
import '../Models/returnform_details_model.dart';
import '../Services/Biometric/biometric_services.dart';
import '../ViewModels/return_form_details_view_model.dart';
import '../ViewModels/return_form_view_model.dart';
import '../widgets/color.dart';

@RoutePage()
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late final addShopViewModel           = Get.put(AddShopViewModel());
  late final productsViewModel          = Get.put(ProductsViewModel());
  late final shopVisitViewModel         = Get.put(ShopVisitViewModel());
  late final shopVisitDetailsViewModel  = Get.put(ShopVisitDetailsViewModel());
  late final orderMasterViewModel       = Get.put(OrderMasterViewModel());
  late final orderDetailsViewModel      = Get.put(OrderDetailsViewModel());
  late final recoveryFormViewModel      = Get.put(RecoveryFormViewModel());
  late final returnFormViewModel        = Get.put(ReturnFormViewModel());
  late final ReturnFormDetailsViewModel returnFormDetailsViewModel =
  Get.put(ReturnFormDetailsViewModel());
  late final attendanceViewModel        = Get.put(AttendanceViewModel());
  late final attendanceOutViewModel     = Get.put(AttendanceOutViewModel());
  final LocationViewModel locationViewModel = Get.put(LocationViewModel());
  late final updateFunctionViewModel    = Get.put(UpdateFunctionViewModel());
  final LoginViewModel loginViewModel   = Get.put(LoginViewModel());

  final _formKey = GlobalKey<FormState>();
  bool isChecked           = true;
  bool isLoading           = false;
  bool isPasswordVisible   = false;
  bool isButtonDisabled    = false;
  bool _biometricEnabled   = false;

  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0.0);

  // ── lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyLoggedIn = prefs.getBool('isAuthenticated') ?? false;
    if (alreadyLoggedIn) return;

    // FIX 1: Run both checks in parallel — isAvailable() itself now also
    //         runs its 3 internal platform calls in parallel (see biometric_services.dart)
    final results = await Future.wait([
      BiometricService.instance.isEnabled(),
      BiometricService.instance.isAvailable(),
    ]);
    final bool enabled   = results[0] as bool;
    final bool available = results[1] as bool;

    if (enabled && available) {
      if (mounted) setState(() => _biometricEnabled = true);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _biometricLogin();
    }
  }

  // ── Biometric login ───────────────────────────────────────────────────────

  Future<void> _biometricLogin() async {
    if (!mounted) return;
    setState(() { isLoading = true; isButtonDisabled = true; _progressNotifier.value = 0.0; });

    // loginWithBiometric() now returns the user map on success, null on failure
    final userMap = await loginViewModel.loginWithBiometric();

    if (userMap == null) {
      // Failure — reset spinner and show error
      if (mounted) {
        setState(() { isLoading = false; isButtonDisabled = false; });
        Get.snackbar(
          'Biometric Failed',
          'Could not verify fingerprint. Use password instead.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.blueGrey,
          colorText: Colors.white,
        );
      }
      return;
    }

    // FIX 2: Run the SAME data-sync tasks as normal _login(), so the app
    //         has fresh data after biometric login too.
    final String userId = userMap['userId'] as String? ?? user_id;
    await _prefs_setUserId(userId);

    try {
      final bool isManager =
      ['RSM', 'SM', 'NSM', 'DISPATCHER'].contains(userDesignation);
      final int totalTasks = isManager ? 4 : 17;
      int completedTasks = 0;

      void updateProgress() {
        completedTasks++;
        _progressNotifier.value = completedTasks / totalTasks;
      }

      Future<void> trackedTask(Future<void> task) async {
        await task;
        updateProgress();
      }

      if (isManager) {
        await trackedTask(addShopViewModel.fetchAndSaveHeadsShop());
        await trackedTask(shopVisitViewModel.serialCounterGetHeads());
        await trackedTask(attendanceViewModel.serialCounterGet());
        await trackedTask(locationViewModel.serialCounterGet());
      } else {
        await trackedTask(addShopViewModel.fetchAndSaveShop());
        await trackedTask(shopVisitViewModel.serialCounterGet());
        await trackedTask(addShopViewModel.serialCounterGet());
        await trackedTask(shopVisitDetailsViewModel.serialCounterGet());
        await trackedTask(recoveryFormViewModel.serialCounterGet());
        await trackedTask(returnFormViewModel.serialCounterGet());
        await trackedTask(returnFormDetailsViewModel.serialCounterGet());
        await trackedTask(attendanceViewModel.serialCounterGet());
        await trackedTask(orderMasterViewModel.serialCounterGet());
        await trackedTask(orderDetailsViewModel.serialCounterGet());
        await trackedTask(locationViewModel.serialCounterGet());

        await Future.wait([
          trackedTask(productsViewModel.fetchAndSaveProducts()),
          trackedTask(orderMasterViewModel.fetchAndSaveOrderMaster()),
          trackedTask(orderDetailsViewModel.fetchAndSaveOrderDetails()),
          trackedTask(shopVisitDetailsViewModel.initializeProductData()),
          trackedTask(updateFunctionViewModel.checkAndSetInitializationDateTime()),
        ]);
      }

      await loginViewModel.navigateToHomePage();
    } catch (e) {
      debugPrint('Biometric data-sync error: $e');
      Get.snackbar('Error', 'Data sync failed: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      // FIX 2: Always reset the spinner — was missing in the original
      if (mounted) setState(() { isLoading = false; isButtonDisabled = false; });
    }
  }

  Future<void> _prefs_setUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    await prefs.reload();
    user_id = prefs.getString('userId')!;
  }

  // ── Password login (unchanged logic) ─────────────────────────────────────

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading        = true;
      isButtonDisabled = true;
      _progressNotifier.value = 0.0;
    });

    final prefs = await SharedPreferences.getInstance();

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Get.snackbar('Location Required', 'Please enable location services to continue.',
          snackPosition: SnackPosition.BOTTOM);
      setState(() { isLoading = false; isButtonDisabled = false; });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        Get.snackbar('Permission Denied', 'Location permission is required.',
            snackPosition: SnackPosition.BOTTOM);
        setState(() { isLoading = false; isButtonDisabled = false; });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      Get.snackbar('Permission Permanently Denied',
          'Enable location from Settings.', snackPosition: SnackPosition.BOTTOM);
      setState(() { isLoading = false; isButtonDisabled = false; });
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      Get.snackbar('Error', 'No internet connection',
          snackPosition: SnackPosition.BOTTOM);
      setState(() { isLoading = false; isButtonDisabled = false; });
      return;
    }

    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) throw Exception();
    } catch (_) {
      Get.snackbar('Error', 'No internet connection',
          snackPosition: SnackPosition.BOTTOM);
      setState(() { isLoading = false; isButtonDisabled = false; });
      return;
    }

    final success = await loginViewModel.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!success) {
      Get.snackbar('Error', 'Invalid user ID or password',
          snackPosition: SnackPosition.BOTTOM);
      setState(() { isLoading = false; isButtonDisabled = false; });
      return;
    }

    await prefs.setString('userId', _emailController.text.trim());
    await prefs.reload();
    user_id = prefs.getString('userId')!;

    try {
      final bool isManager =
      ['RSM', 'SM', 'NSM', 'DISPATCHER'].contains(userDesignation);
      final int totalTasks = isManager ? 4 : 17;
      int completedTasks = 0;

      void updateProgress() {
        completedTasks++;
        _progressNotifier.value = completedTasks / totalTasks;
      }

      Future<void> trackedTask(Future<void> task) async {
        await task;
        updateProgress();
      }

      if (isManager) {
        await trackedTask(addShopViewModel.fetchAndSaveHeadsShop());
        await trackedTask(shopVisitViewModel.serialCounterGetHeads());
        await trackedTask(attendanceViewModel.serialCounterGet());
        await trackedTask(locationViewModel.serialCounterGet());
      } else {
        await trackedTask(addShopViewModel.fetchAndSaveShop());
        await trackedTask(shopVisitViewModel.serialCounterGet());
        await trackedTask(addShopViewModel.serialCounterGet());
        await trackedTask(shopVisitDetailsViewModel.serialCounterGet());
        await trackedTask(recoveryFormViewModel.serialCounterGet());
        await trackedTask(returnFormViewModel.serialCounterGet());
        await trackedTask(returnFormDetailsViewModel.serialCounterGet());
        await trackedTask(attendanceViewModel.serialCounterGet());
        await trackedTask(orderMasterViewModel.serialCounterGet());
        await trackedTask(orderDetailsViewModel.serialCounterGet());
        await trackedTask(locationViewModel.serialCounterGet());

        await Future.wait([
          trackedTask(productsViewModel.fetchAndSaveProducts()),
          trackedTask(orderMasterViewModel.fetchAndSaveOrderMaster()),
          trackedTask(orderDetailsViewModel.fetchAndSaveOrderDetails()),
          trackedTask(shopVisitDetailsViewModel.initializeProductData()),
          trackedTask(updateFunctionViewModel.checkAndSetInitializationDateTime()),
        ]);
      }

      await loginViewModel.navigateToHomePage();
    } catch (e) {
      debugPrint('Data fetch error: $e');
      Get.snackbar('Error', 'Data sync failed: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() { isLoading = false; isButtonDisabled = false; });
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColor.bgColor,
      body: Stack(
        children: [
          Positioned(
            top: -100, right: -50,
            child: Transform.rotate(
              angle: -0.2,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(80),
                  gradient: LinearGradient(
                    colors: [
                      Colors.blueGrey.withOpacity(0.4),
                      Colors.blueGrey.withOpacity(0.1)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 50, left: -30,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueGrey.withOpacity(0.05),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: size.height - 56),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      BookITHeader(),
                      const SizedBox(height: 26),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColor.darkText.withOpacity(0.04),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            )
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sign in',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColor.darkText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Enter your credentials to continue',
                                style: TextStyle(
                                    color: AppColor.subText, fontSize: 13),
                              ),
                              const SizedBox(height: 20),

                              // User ID field
                              TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: 'User ID',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty)
                                    return 'Please enter user ID';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // Password field
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !isPasswordVisible,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(isPasswordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility),
                                    onPressed: () => setState(
                                            () => isPasswordVisible = !isPasswordVisible),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                style: TextStyle(
                                    color: AppColor.darkText, fontSize: 15),
                                validator: (value) {
                                  if (value == null || value.isEmpty)
                                    return 'Please enter password';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: isChecked,
                                        onChanged: (v) =>
                                            setState(() => isChecked = v ?? true),
                                      ),
                                      Text(
                                        'Remember me',
                                        style: TextStyle(
                                            color: AppColor.subText,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Get.snackbar(
                                        'Forgot Password',
                                        'Contact your administrator to reset password',
                                        snackPosition: SnackPosition.BOTTOM,
                                        backgroundColor: AppColor.darkText,
                                        colorText: Colors.white,
                                      );
                                    },
                                    child: Text('Forgot Password?',
                                        style: TextStyle(
                                            color: AppColor.darkText,
                                            fontSize: 13)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // SIGN IN button
                              ValueListenableBuilder<double>(
                                valueListenable: _progressNotifier,
                                builder: (context, progress, _) {
                                  return SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed:
                                      isButtonDisabled ? null : _login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColor.darkText,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(12)),
                                      ),
                                      child: isLoading
                                          ? Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: [
                                          const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child:
                                            CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.2),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'LOGGING IN ${(progress * 100).toStringAsFixed(0)}%',
                                            style: const TextStyle(
                                                fontWeight:
                                                FontWeight.w700),
                                          ),
                                        ],
                                      )
                                          : const Text('SIGN IN',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  );
                                },
                              ),

                              // Fingerprint button
                              if (_biometricEnabled) ...[
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                        child: Divider(
                                            color: Colors.blueGrey.shade100)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      child: Text(
                                        'or',
                                        style: TextStyle(
                                            color: AppColor.subText,
                                            fontSize: 13),
                                      ),
                                    ),
                                    Expanded(
                                        child: Divider(
                                            color: Colors.blueGrey.shade100)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: Column(
                                    children: [
                                      GestureDetector(
                                        onTap: isButtonDisabled
                                            ? null
                                            : _biometricLogin,
                                        child: Container(
                                          width: 64,
                                          height: 64,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.blueGrey.shade50,
                                            border: Border.all(
                                                color:
                                                Colors.blueGrey.shade200,
                                                width: 1.5),
                                          ),
                                          child: Icon(
                                            Icons.fingerprint,
                                            size: 36,
                                            color: isButtonDisabled
                                                ? Colors.blueGrey.shade200
                                                : Colors.blueGrey.shade700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Login with Fingerprint',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColor.subText,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      TextButton(
                        onPressed: () {
                          Get.snackbar(
                            "Help",
                            "Contact your administrator for support",
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: AppColor.darkText,
                            colorText: Colors.white,
                          );
                        },
                        child: Text('Need help?',
                            style: TextStyle(
                                color: AppColor.subText,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}