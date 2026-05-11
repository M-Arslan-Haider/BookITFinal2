
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:order_booking_app/Databases/util.dart';
import 'package:order_booking_app/Screens/PermissionScreens/camera_screen.dart';
import 'package:order_booking_app/ViewModels/login_view_model.dart';
import 'package:order_booking_app/constants.dart';
import 'package:order_booking_app/widgets/color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/bookit_header.dart';

class CodeScreen extends StatefulWidget {
  const CodeScreen({super.key});

  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> with SingleTickerProviderStateMixin {
  late final TextEditingController companyCodeController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _formKey = GlobalKey<FormState>();
  final LoginViewModel loginViewModel = Get.put(LoginViewModel());

  bool isLoading = false;
  bool isButtonDisabled = false;
  bool isOffline = false;

  // API URL for company codes - DIRECT API URL instead of Firebase
  final String companyApiUrl = "https://cloud.metaxperts.net:8443/erp/beauty_pro_solutions/registeredcompanies/get/";

  StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;

  @override
  void initState() {
    super.initState();
    companyCodeController = TextEditingController();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _animationController.forward();

    // Listen to internet connectivity changes
    connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) async {
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;

      if (result == ConnectivityResult.none) {
        setState(() => isOffline = true);
        _showCenteredSnackBar('No internet connection.', isError: true);
      } else {
        bool hasNet = await _hasInternet(showSnack: false);
        if (!hasNet) {
          _showCenteredSnackBar('Internet is slow or unstable.', isError: true);
        } else if (isOffline) {
          setState(() => isOffline = false);
          _showCenteredSnackBar('Back online! You can continue.');
        }
      }
    });
  }

  @override
  void dispose() {
    companyCodeController.dispose();
    connectivitySubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  /// Shows custom centered snackbar
  void _showCenteredSnackBar(String message, {bool isError = false}) {
    final snackBar = SnackBar(
      content: Center(
        child: Text(
          message,
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
      backgroundColor: Colors.blueGrey,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: const EdgeInsets.only(
        bottom: 20,
        left: 20,
        right: 20,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Check actual internet access
  Future<bool> _hasInternet({bool showSnack = true}) async {
    var connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      if (showSnack) {
        _showCenteredSnackBar('No internet connection detected.', isError: true);
      }
      return false;
    }

    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      } else {
        if (showSnack) {
          _showCenteredSnackBar('Internet seems unavailable or very slow.', isError: true);
        }
        return false;
      }
    } on SocketException {
      if (showSnack) {
        _showCenteredSnackBar('Internet not reachable. Please check your connection.', isError: true);
      }
      return false;
    } on TimeoutException {
      if (showSnack) {
        _showCenteredSnackBar('Internet connection is very slow. Please try again.', isError: true);
      }
      return false;
    } catch (e) {
      if (showSnack) {
        _showCenteredSnackBar('Error checking internet: $e', isError: true);
      }
      return false;
    }
  }

  /// Save company details logic - DIRECT API CALL WITHOUT FIREBASE
  Future<void> _saveCompanyDetails(String companyCode) async {
    _showCenteredSnackBar('Please wait...');
    setState(() {
      isLoading = true;
      isButtonDisabled = true;
    });

    if (!await _hasInternet()) {
      setState(() {
        isLoading = false;
        isButtonDisabled = false;
      });
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final isAuthenticated = prefs.getBool('isAuthenticated') ?? false;

      // DIRECT API CALL - NO FIREBASE
      final response = await http
          .get(Uri.parse(companyApiUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        _showCenteredSnackBar('Failed to fetch company details', isError: true);
        setState(() {
          isLoading = false;
          isButtonDisabled = false;
        });
        return;
      }

      final data = json.decode(response.body);

      // Handle different response structures
      List<dynamic> items = [];
      if (data is Map && data.containsKey('items')) {
        items = data['items'] as List;
      } else if (data is List) {
        items = data;
      } else if (data is Map && data.containsKey('data')) {
        items = data['data'] as List;
      } else {
        _showCenteredSnackBar('Unexpected API response format', isError: true);
        setState(() {
          isLoading = false;
          isButtonDisabled = false;
        });
        return;
      }

      // Find the company by code
      final company = items.firstWhere(
            (item) =>
        item['company_code'] == companyCode ||
            item['code'] == companyCode ||
            item['companyCode'] == companyCode,
        orElse: () => null,
      );

      if (company == null) {
        _showCenteredSnackBar('Company code not found', isError: true);
        setState(() {
          isLoading = false;
          isButtonDisabled = false;
        });
        return;
      }

      // Extract company details with fallback keys
      String companyName = company['company_name'] ??
          company['name'] ??
          company['companyName'] ??
          'Unknown Company';

      String workspaceName = company['workspace_name'] ??
          company['workspace'] ??
          company['workspaceName'] ??
          'default';

      await prefs.setString('company_name', companyName);
      await prefs.setString('workspace_name', workspaceName);
      await prefs.setString('company_code', companyCode);

      // Set ERP workspace name
      erpWorkSpace = workspaceName;

      if (!isAuthenticated) {
        try {
          _showCenteredSnackBar('Setting up your account...');

          // Set company name for further API calls
          companyName = companyName;
          debugPrint("Company Name: $companyName");

          // Check internet before navigation
          await loginViewModel.checkInternetBeforeNavigation();
        } catch (e) {
          debugPrint("Authentication error: $e");
          _showCenteredSnackBar('Setup failed: ${e.toString()}', isError: true);
          setState(() {
            isLoading = false;
            isButtonDisabled = false;
          });
          return;
        }
      }

      _showCenteredSnackBar('Setup complete!');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAll(() => const CameraScreen());
      });
    } on SocketException {
      _showCenteredSnackBar('No internet. Please connect and try again.', isError: true);
    } on TimeoutException {
      _showCenteredSnackBar('Request timed out. Please try again.', isError: true);
    } on http.ClientException {
      _showCenteredSnackBar('Connection failed. Check your internet and try again.', isError: true);
    } catch (e) {
      debugPrint('Error in _saveCompanyDetails: $e');
      _showCenteredSnackBar('Something went wrong. Please try again later.', isError: true);
    } finally {
      setState(() {
        isLoading = false;
        isButtonDisabled = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // Elegant background circles
            Positioned(
              top: -100,
              right: -50,
              child: Transform.rotate(
                angle: -0.2,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(80),
                    gradient: LinearGradient(
                      colors: [
                        Colors.blueGrey.withOpacity(0.4),
                        Colors.blueGrey.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),

            // Secondary accent circle
            Positioned(
              top: 50,
              left: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueGrey.withOpacity(0.05),
                ),
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 40),
                          _buildMainCard(),
                          const SizedBox(height: 30),
                          _buildFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        BookITHeader(),
      ],
    );
  }

  Widget _buildMainCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: darkText.withOpacity(0.09),
            blurRadius: 20,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Company Code',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColor.darkText),
            ),
            const SizedBox(height: 10),
            Text(
              'Enter your unique company code to continue this application.',
              style: TextStyle(fontSize: 14, color: AppColor.subText, height: 1.4),
            ),
            const SizedBox(height: 30),
            TextFormField(
              controller: companyCodeController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0),
              decoration: InputDecoration(
                hintText: 'Enter your company code',
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: darkText, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter company code';
                }
                return null;
              },
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: isButtonDisabled
                    ? null
                    : () {
                  if (_formKey.currentState!.validate()) {
                    _saveCompanyDetails(companyCodeController.text.trim());
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: isLoading
                    ? const Text('Please wait...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                    : const Text('Continue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Please contact admin to reset your access code'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          },
          child: Text(
            'Forget your access code?',
            style: TextStyle(
              color: AppColor.subText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 14, color: Colors.grey[400]),
            const SizedBox(width: 5),
            Text(
              'SECURED END-TO-END',
              style: TextStyle(fontSize: 10, color: AppColor.subText, letterSpacing: 1),
            ),
          ],
        ),
      ],
    );
  }
}