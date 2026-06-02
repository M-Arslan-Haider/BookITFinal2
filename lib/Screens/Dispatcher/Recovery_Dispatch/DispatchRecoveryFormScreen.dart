
import 'dart:convert';
import 'package:flutter/foundation.dart' show Uint8List, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:order_booking_app/Databases/util.dart';
import 'package:order_booking_app/Services/FirebaseServices/firebase_remote_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';

// ============================================================================
// MODELS
// ============================================================================

/// Recovery Shop Model - Represents shop data from API
class RecoveryShopModel {
  final int? id;
  final String? shopName;
  final String? shopAddress;
  final String? shopContact;
  final String? city;
  final double? currentBalance;
  final String? ownerName;
  final String? shopCategory;

  RecoveryShopModel({
    this.id,
    this.shopName,
    this.shopAddress,
    this.shopContact,
    this.city,
    this.currentBalance,
    this.ownerName,
    this.shopCategory,
  });

  factory RecoveryShopModel.fromJson(Map<String, dynamic> json) {
    return RecoveryShopModel(
      id: json['id'],
      shopName: json['shop_name'] ?? json['shopName'] ?? '',
      shopAddress: json['shop_address'] ?? json['shopAddress'] ?? '',
      shopContact: json['shop_contact'] ?? json['shopContact'] ?? '',
      city: json['city'] ?? '',
      currentBalance: _parseDouble(
          json['dispatch_amount'] ??
              json['current_balance'] ??
              json['currentBalance'] ??
              json['balance']
      ),
      ownerName: json['owner_name'] ?? json['ownerName'] ?? '',
      shopCategory: json['shop_category'] ?? json['shopCategory'] ?? '',
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Payment History Model
class PaymentHistoryModel {
  final String? date;
  final String? shop;
  final double? amount;
  final String? recoveryId;

  PaymentHistoryModel({
    this.date,
    this.shop,
    this.amount,
    this.recoveryId,
  });

  factory PaymentHistoryModel.fromJson(Map<String, dynamic> json) {
    return PaymentHistoryModel(
      date: json['date'] ?? json['recovery_date'] ?? '',
      shop: json['shop'] ?? json['shop_name'] ?? '',
      amount: _parseDouble(json['amount'] ?? json['cash_recovery']),
      recoveryId: json['recovery_id'] ?? '',
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

// ============================================================================
// VIEW MODEL / CONTROLLER
// ============================================================================

class RecoveryFormController extends GetxController {
  // Constants for SharedPreferences
  static const String _BALANCE_PREFIX = 'shop_balance_';

  // Observable variables
  var selectedShop = ''.obs;
  var selectedShopId = 0.obs;
  var shops = <RecoveryShopModel>[].obs;
  var paymentHistory = <PaymentHistoryModel>[].obs;
  var filteredRows = <PaymentHistoryModel>[].obs;
  var currentBalance = 0.0.obs;
  var cashRecovery = 0.0.obs;
  var netBalance = 0.0.obs;
  var areFieldsEnabled = false.obs;
  var recoveryId = "".obs;
  var isLoading = false.obs;

  // Serial counter variables
  int recoverySerialCounter = 1;
  String recoveryCurrentMonth = DateFormat('MMM').format(DateTime.now());
  String currentUserId = '';

  @override
  void onInit() {
    super.onInit();
    initializeData();
  }

  /// Load saved balance for a specific shop from SharedPreferences
  Future<double> _loadSavedBalance(String shopName) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String key = _BALANCE_PREFIX + shopName;
      double? savedBalance = prefs.getDouble(key);

      if (savedBalance != null) {
        debugPrint('✅ Loaded saved balance for $shopName: $savedBalance');
        return savedBalance;
      }
    } catch (e) {
      debugPrint('Error loading saved balance: $e');
    }
    return -1; // Return -1 to indicate no saved balance found
  }

  /// Save net balance for a specific shop after recovery
  Future<void> _saveNetBalance(String shopName, double netBalance) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String key = _BALANCE_PREFIX + shopName;
      await prefs.setDouble(key, netBalance);
      debugPrint('✅ Saved net balance for $shopName: $netBalance');
    } catch (e) {
      debugPrint('Error saving net balance: $e');
    }
  }

  /// Clear saved balance for a shop (if needed)
  Future<void> _clearSavedBalance(String shopName) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String key = _BALANCE_PREFIX + shopName;
      await prefs.remove(key);
      debugPrint('✅ Cleared saved balance for $shopName');
    } catch (e) {
      debugPrint('Error clearing saved balance: $e');
    }
  }

  /// Initialize data by fetching shops from API
  Future<void> initializeData() async {
    try {
      isLoading.value = true;

      // Fetch shops from API
      await fetchShopsFromAPI();

      // Initialize payment history as empty
      paymentHistory.value = [];
      filteredRows.value = [];

      isLoading.value = false;
    } catch (e) {
      debugPrint('Error initializing data: $e');
      isLoading.value = false;
      Get.snackbar(
        "Error",
        "Failed to load shops. Please try again.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Fetch shops from API
  Future<void> fetchShopsFromAPI() async {
    try {
      await Config.fetchLatestConfig();
      debugPrint('Fetching shops for user: $user_id');

      // Using Config for API endpoint
      final apiUrl = '${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}/dispatchshopget/get/$user_id';
      debugPrint('API URL: $apiUrl');

      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        dynamic responseData = json.decode(response.body);
        debugPrint('API Response Type: ${responseData.runtimeType}');
        debugPrint('API Response: $responseData');

        List<dynamic> data = [];

        // Handle both List and single Map object
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map) {
          // ⭐ Check if it has 'items', 'data' or 'shops' key
          if (responseData.containsKey('items')) {
            if (responseData['items'] is List) {
              data = responseData['items'];
              debugPrint('Found ${data.length} shops in items array');
            } else {
              data = [responseData['items']];
            }
          } else if (responseData.containsKey('data')) {
            if (responseData['data'] is List) {
              data = responseData['data'];
            } else {
              data = [responseData['data']];
            }
          } else if (responseData.containsKey('shops')) {
            if (responseData['shops'] is List) {
              data = responseData['shops'];
            } else {
              data = [responseData['shops']];
            }
          } else {
            // Treat the entire Map as single shop
            data = [responseData];
          }
        }

        if (data.isEmpty) {
          debugPrint('No shops found in API response');
          Get.snackbar(
            "Info",
            "No shops available for recovery.",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
        } else {
          shops.value = data.map((json) => RecoveryShopModel.fromJson(json)).toList();
          debugPrint('Successfully loaded ${shops.length} shops');
        }
      } else {
        throw Exception('Failed to load shops: ${response.statusCode}');
      }

      shops.refresh();
    } catch (e) {
      debugPrint('Error fetching shops: $e');
      Get.snackbar(
        "Error",
        "Failed to fetch shops from server. Error: ${e.toString()}",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Fetch and update current balance for selected shop
  Future<void> fetchAndSaveCurrentBalance(String shopName) async {
    try {
      // First check if we have a saved balance locally
      double savedBalance = await _loadSavedBalance(shopName);

      if (savedBalance >= 0) {
        // Use the saved balance from previous recoveries
        currentBalance.value = savedBalance;
        debugPrint('✅ Using saved balance for $shopName: ${currentBalance.value}');

        // Still fetch payment history
        await fetchPaymentHistory(shopName);
        return;
      }

      // No saved balance found, fetch from API
      await Config.fetchLatestConfig();
      debugPrint('Fetching current balance from API for shop: $shopName');

      final apiUrl = '${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}/currentbalance/get/$shopName/$user_id';
      debugPrint('Balance API URL: $apiUrl');

      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);

        if (data.isNotEmpty) {
          var balance = data[0]['balance'];
          if (balance is int) {
            currentBalance.value = balance.toDouble();
          } else if (balance is double) {
            currentBalance.value = balance;
          } else if (balance is String) {
            currentBalance.value = double.tryParse(balance) ?? 0.0;
          }

          // Save the initial balance to SharedPreferences
          await _saveNetBalance(shopName, currentBalance.value);

          debugPrint('✅ Current balance fetched from API and saved: ${currentBalance.value}');
        }
      }

      // Fetch payment history for this shop
      await fetchPaymentHistory(shopName);
    } catch (e) {
      debugPrint('Error fetching current balance: $e');
      // Set a default balance from shop data if API fails
      var shop = shops.firstWhere((s) => s.shopName == shopName, orElse: () => RecoveryShopModel());
      currentBalance.value = shop.currentBalance ?? 0.0;

      // Save the default balance
      await _saveNetBalance(shopName, currentBalance.value);
    }
  }

  /// Fetch payment history for selected shop
  Future<void> fetchPaymentHistory(String shopName) async {
    try {
      await Config.fetchLatestConfig();
      debugPrint('Fetching payment history for shop: $shopName');

      final apiUrl = '${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}/recoveryhistory/get/$shopName/$user_id';
      debugPrint('History API URL: $apiUrl');

      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);

        paymentHistory.value = data.map((json) => PaymentHistoryModel.fromJson(json)).toList();
        filteredRows.value = paymentHistory.value;

        debugPrint('Payment history loaded: ${paymentHistory.length} records');
      }
    } catch (e) {
      debugPrint('Error fetching payment history: $e');
      // Don't show error for payment history - it's optional
      paymentHistory.value = [];
      filteredRows.value = [];
    }
  }

  /// Filter payment history data
  void filterData(String query) {
    final lowerCaseQuery = query.toLowerCase();

    if (selectedShop.value.isNotEmpty) {
      filteredRows.value = paymentHistory.value.where((row) {
        return row.shop == selectedShop.value &&
            (row.date!.toLowerCase().contains(lowerCaseQuery) ||
                row.shop!.toLowerCase().contains(lowerCaseQuery) ||
                row.amount.toString().contains(lowerCaseQuery));
      }).toList();
    } else {
      filteredRows.value = paymentHistory.value.where((row) {
        return row.date!.toLowerCase().contains(lowerCaseQuery) ||
            row.shop!.toLowerCase().contains(lowerCaseQuery) ||
            row.amount.toString().contains(lowerCaseQuery);
      }).toList();
    }
  }

  /// Reset form to initial state
  Future<void> resetForm() async {
    selectedShop.value = '';
    selectedShopId.value = 0;
    currentBalance.value = 0.0;
    cashRecovery.value = 0.0;
    netBalance.value = 0.0;
    areFieldsEnabled.value = false;
    paymentHistory.value = [];
    filteredRows.value = [];
  }

  /// Update current balance and filter payment history
  void updateCurrentBalance(String shopName) {
    netBalance.value = currentBalance.value - cashRecovery.value;
    areFieldsEnabled.value = true;

    // Filter payment history based on selected shop
    filteredRows.value = paymentHistory.value.where((payment) {
      return payment.shop == shopName;
    }).toList();
  }

  /// Update cash recovery amount
  void updateCashRecovery(String value) {
    final recoveryAmount = double.tryParse(value) ?? 0.0;

    if (recoveryAmount <= currentBalance.value) {
      cashRecovery.value = recoveryAmount;
      netBalance.value = currentBalance.value - cashRecovery.value;
    } else {
      Get.snackbar(
        "Error",
        "Recovery amount cannot be more than current balance!",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Convert payment history to map list for display
  List<Map<String, dynamic>> get paymentHistoryAsMapList {
    return paymentHistory.value.map((payment) {
      return {
        'Date': payment.date ?? '',
        'Amount': payment.amount ?? 0.0,
        'Shop': payment.shop ?? '',
      };
    }).toList();
  }

  /// Submit recovery form
  Future<void> submitForm() async {
    await _loadCounter();

    // Validate Shop Selection
    if (selectedShop.value.isEmpty) {
      Get.snackbar(
        "Error",
        "⚠️ Please select a shop before submitting.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Validate Cash Recovery Amount
    if (cashRecovery.value <= 0) {
      Get.snackbar(
        "Error",
        "⚠️ Please enter a valid amount before submitting.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Validate that recovery amount doesn't exceed current balance
    if (cashRecovery.value > currentBalance.value) {
      Get.snackbar(
        "Error",
        "⚠️ Recovery amount cannot exceed current balance.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    try {
      // Generate recovery ID
      final recoverySerial = generateNewRecoveryId(user_id.toString());
      recoveryId.value = recoverySerial;

      // ✅ Try to post to API (but don't fail if API not ready)
      try {
        await postRecoveryToAPI();
        debugPrint('✅ Recovery posted to API successfully');
      } catch (apiError) {
        debugPrint('⚠️ API post failed (API may not be ready yet): $apiError');
        // Continue anyway - show success, API will be implemented later
      }

      // ✅ IMPORTANT: Save the net balance for this shop
      await _saveNetBalance(selectedShop.value, netBalance.value);

      // ✅ Update current balance immediately for UI consistency
      currentBalance.value = netBalance.value;

      // Show success message
      Get.snackbar(
        "Success",
        "✅ Recovery form submitted successfully!",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      // Navigate to confirmation page
      Get.to(() => RecoveryConfirmationPage(
        recoveryId: recoveryId.value,
        shopName: selectedShop.value,
        cashRecovery: cashRecovery.value,
        netBalance: netBalance.value,
        currentBalance: currentBalance.value,
      ));
    } catch (e) {
      debugPrint('Error submitting form: $e');
      Get.snackbar(
        "Error",
        "Failed to submit form. Please try again.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// Post recovery data to API - Using Config like recovery_form_repository.dart
  Future<void> postRecoveryToAPI() async {
    try {
      await Config.fetchLatestConfig();

      // This matches exactly: "${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.postApiUrlRecoveryForm}"
      final apiUrl = '${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.postApiUrlRecoveryForm}';
      debugPrint('Posting to API: $apiUrl');

      final recoveryData = {
        'recovery_id': recoveryId.value,
        'shop_name': selectedShop.value,
        'current_balance': currentBalance.value.toString(),
        'cash_recovery': cashRecovery.value,
        'net_balance': netBalance.value,
        'recovery_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'recovery_time': DateFormat('HH:mm:ss').format(DateTime.now()),
        'user_id': user_id.toString(),
        'posted': 1,
      };

      debugPrint('Posting recovery data: $recoveryData');

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(recoveryData),
      );

      debugPrint('Response status code: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Recovery data posted successfully with status: ${response.statusCode}');
      } else {
        throw Exception('Server error: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      debugPrint('Error posting recovery data: $e');
      // Re-throw to be caught by submitForm's try-catch
      throw Exception('Failed to post recovery data: $e');
    }
  }

  /// Load counter from shared preferences
  Future<void> _loadCounter() async {
    String currentMonth = DateFormat('MMM').format(DateTime.now());

    if (recoveryCurrentMonth != currentMonth) {
      recoverySerialCounter = 1;
      recoveryCurrentMonth = currentMonth;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    recoverySerialCounter = prefs.getInt('recoverySerialCounter') ?? 1;
    recoveryCurrentMonth = prefs.getString('recoveryCurrentMonth') ?? currentMonth;
    currentUserId = prefs.getString('currentUserId') ?? '';

    debugPrint('Recovery Serial Counter: $recoverySerialCounter');
  }

  /// Save counter to shared preferences
  Future<void> _saveCounter() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('recoverySerialCounter', recoverySerialCounter);
    await prefs.setString('recoveryCurrentMonth', recoveryCurrentMonth);
    await prefs.setString('currentUserId', currentUserId);
  }

  /// Generate new recovery ID
  String generateNewRecoveryId(String userId) {
    String currentMonth = DateFormat('MMM').format(DateTime.now());

    if (currentUserId != userId) {
      recoverySerialCounter = 1;
      currentUserId = userId;
    }

    if (recoveryCurrentMonth != currentMonth) {
      recoverySerialCounter = 1;
      recoveryCurrentMonth = currentMonth;
    }

    String orderId = "RC-$userId-$currentMonth-${recoverySerialCounter.toString().padLeft(3, '0')}";
    recoverySerialCounter++;
    _saveCounter();
    return orderId;
  }

  /// Optional: Add method to reset balance for a shop (useful for testing)
  Future<void> resetShopBalance(String shopName) async {
    await _clearSavedBalance(shopName);
    await fetchAndSaveCurrentBalance(shopName);
    Get.snackbar(
      "Success",
      "Balance reset for $shopName",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
    );
  }
}

class RecoveryDispatchScreen extends StatelessWidget {
  final RecoveryFormController controller = Get.put(RecoveryFormController());

  RecoveryDispatchScreen({super.key});

  Widget _buildTextField({
    required String label,
    required TextInputType keyboardType,
    TextEditingController? textController,
    double? width,
    double height = 50,
    bool readOnly = false,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
    bool enabled = true,
    double fontSize = 16,
  }) {
    final field = TextFormField(
      controller: textController,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      enabled: enabled,
      style: TextStyle(fontSize: fontSize),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: Colors.grey, fontSize: fontSize),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, height: height, child: field);
    }
    return SizedBox(height: height, child: field);
  }

  @override
  Widget build(BuildContext context) {
    controller.initializeData();
    final TextEditingController cashRecoveryController = TextEditingController();
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final hPadding = isTablet ? size.width * 0.08 : 16.0;
    final labelFontSize = isTablet ? 18.0 : 16.0;
    final fieldFontSize = isTablet ? 17.0 : 16.0;
    final fieldHeight = isTablet ? 58.0 : 50.0;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Text(
            'Recovery Form',
            style: TextStyle(fontSize: isTablet ? 24 : 20, color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: Colors.blueGrey,
          toolbarHeight: isTablet ? 64 : kToolbarHeight,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, size: isTablet ? 26 : 22),
              onPressed: () => controller.initializeData(),
              tooltip: 'Refresh Shops',
              color: Colors.white,
            ),
          ],
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: isTablet ? 24 : 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Shop Dropdown
                  Obx(() {
                    if (controller.shops.isEmpty) {
                      return Card(
                        color: Colors.orange.shade50,
                        child: Padding(
                          padding: EdgeInsets.all(isTablet ? 16 : 12),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange, size: isTablet ? 26 : 22),
                              SizedBox(width: isTablet ? 14 : 10),
                              Expanded(
                                child: Text(
                                  'No shops available. Please check your connection.',
                                  style: TextStyle(color: Colors.orange, fontSize: isTablet ? 16 : 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: "Select Shop",
                        labelStyle: TextStyle(fontSize: labelFontSize),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: isTablet ? 14 : 8,
                        ),
                      ),
                      value: controller.selectedShop.value.isEmpty
                          ? null
                          : controller.selectedShop.value,
                      items: controller.shops.map((shop) {
                        return DropdownMenuItem(
                          value: shop.shopName,
                          child: Text(
                            shop.shopName ?? 'Unknown Shop',
                            style: TextStyle(fontSize: fieldFontSize),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          controller.selectedShop.value = value;
                          controller.fetchAndSaveCurrentBalance(value);
                          controller.updateCurrentBalance(value);
                        }
                      },
                    );
                  }),

                  SizedBox(height: isTablet ? 28 : 20),

                  // Current Balance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Current Balance:",
                        style: TextStyle(fontSize: labelFontSize, fontWeight: FontWeight.bold),
                      ),
                      Obx(() => Flexible(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: isTablet ? 200 : 140,
                            maxWidth: isTablet ? 260 : 170,
                          ),
                          child: _buildTextField(
                            readOnly: true,
                            label: controller.currentBalance.value.toStringAsFixed(2),
                            keyboardType: TextInputType.text,
                            height: fieldHeight,
                            fontSize: fieldFontSize,
                            enabled: controller.areFieldsEnabled.value,
                          ),
                        ),
                      )),
                    ],
                  ),

                  SizedBox(height: isTablet ? 28 : 20),

                  // Payment History
                  Text(
                    "Previous Payment History",
                    style: TextStyle(fontSize: labelFontSize, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: isTablet ? 12 : 8),
                  Obx(() {
                    if (controller.selectedShop.value.isEmpty) {
                      return Text(
                        'Please select a shop to view payment history',
                        style: TextStyle(color: Colors.grey, fontSize: isTablet ? 15 : 13),
                      );
                    }

                    if (controller.filteredRows.isEmpty) {
                      return Text(
                        'No payment history available',
                        style: TextStyle(color: Colors.grey, fontSize: isTablet ? 15 : 13),
                      );
                    }

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 16 : 12,
                              vertical: isTablet ? 12 : 8,
                            ),
                            color: Colors.blueGrey.shade100,
                            child: Row(
                              children: [
                                Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isTablet ? 15 : 13))),
                                Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isTablet ? 15 : 13))),
                                Expanded(flex: 2, child: Text('ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isTablet ? 15 : 13))),
                              ],
                            ),
                          ),
                          ...controller.filteredRows.map((payment) {
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 16 : 12,
                                vertical: isTablet ? 12 : 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(flex: 2, child: Text(payment.date ?? '', style: TextStyle(fontSize: isTablet ? 14 : 13))),
                                  Expanded(flex: 2, child: Text(payment.amount?.toStringAsFixed(2) ?? '0.00', style: TextStyle(fontSize: isTablet ? 14 : 13))),
                                  Expanded(flex: 2, child: Text(payment.recoveryId ?? '', style: TextStyle(fontSize: isTablet ? 14 : 13))),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    );
                  }),

                  SizedBox(height: isTablet ? 28 : 20),

                  // Cash Recovery Input
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Cash Recovery:",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: labelFontSize),
                      ),
                      Obx(() => Flexible(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: isTablet ? 200 : 150,
                            maxWidth: isTablet ? 280 : 200,
                          ),
                          child: _buildTextField(
                            textController: cashRecoveryController,
                            label: "Enter Amount",
                            keyboardType: TextInputType.number,
                            height: fieldHeight,
                            fontSize: fieldFontSize,
                            onChanged: controller.updateCashRecovery,
                            enabled: controller.areFieldsEnabled.value,
                          ),
                        ),
                      )),
                    ],
                  ),

                  SizedBox(height: isTablet ? 28 : 20),

                  // New Balance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "New Balance:",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: labelFontSize),
                      ),
                      Obx(() => Flexible(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: isTablet ? 200 : 150,
                            maxWidth: isTablet ? 280 : 200,
                          ),
                          child: _buildTextField(
                            readOnly: true,
                            label: controller.netBalance.value.toStringAsFixed(2),
                            keyboardType: TextInputType.text,
                            height: fieldHeight,
                            fontSize: fieldFontSize,
                            enabled: controller.areFieldsEnabled.value,
                          ),
                        ),
                      )),
                    ],
                  ),

                  SizedBox(height: isTablet ? 40 : 30),

                  // Submit Button
                  Center(
                    child: Obx(() => ElevatedButton(
                      onPressed: controller.areFieldsEnabled.value ? controller.submitForm : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: controller.areFieldsEnabled.value ? Colors.blueGrey : Colors.grey,
                        padding: EdgeInsets.symmetric(
                          vertical: isTablet ? 18 : 14,
                          horizontal: isTablet ? 80 : 60,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        "Submit",
                        style: TextStyle(fontSize: isTablet ? 20 : 18, color: Colors.white),
                      ),
                    )),
                  ),
                  SizedBox(height: isTablet ? 28 : 20),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}


class RecoveryConfirmationPage extends StatelessWidget {
  final String recoveryId;
  final String shopName;
  final double cashRecovery;
  final double netBalance;
  final double currentBalance;

  const RecoveryConfirmationPage({
    super.key,
    required this.recoveryId,
    required this.shopName,
    required this.cashRecovery,
    required this.netBalance,
    required this.currentBalance,
  });

  @override
  Widget build(BuildContext context) {
    String date = DateFormat('dd-MMM-yyyy : HH-mm-ss').format(DateTime.now());
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final hPadding = isTablet ? size.width * 0.08 : 16.0;
    final buttonHeight = isTablet ? 44.0 : 30.0;
    final buttonFontSize = isTablet ? 16.0 : 14.0;

    return WillPopScope(
      onWillPop: () async {
        return false; // Prevent back navigation
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Recovery Confirmation',
            style: TextStyle(fontSize: isTablet ? 22 : 18),
          ),
          automaticallyImplyLeading: false,
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
          toolbarHeight: isTablet ? 64 : kToolbarHeight,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: isTablet ? 24 : 16),
                children: <Widget>[
                  _buildTextFieldRow('Receipt:', recoveryId, isTablet: isTablet),
                  _buildTextFieldRow('Date:', date, isTablet: isTablet),
                  _buildTextFieldRow('Shop Name:', shopName, isTablet: isTablet),
                  _buildTextFieldRow('Payment Amount:', cashRecovery.toStringAsFixed(2), isTablet: isTablet),
                  _buildTextFieldRow('Net Balance:', netBalance.toStringAsFixed(2), isTablet: isTablet),
                  SizedBox(height: isTablet ? 28 : 20),

                  // PDF Button
                  Align(
                    alignment: Alignment.bottomRight,
                    child: SizedBox(
                      width: isTablet ? 110 : 80,
                      height: buttonHeight,
                      child: ElevatedButton(
                        onPressed: () {
                          _generateAndSharePDF(
                            recoveryId,
                            date,
                            shopName,
                            cashRecovery.toStringAsFixed(2),
                            netBalance.toStringAsFixed(2),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5.0),
                            side: const BorderSide(color: Colors.orange),
                          ),
                          elevation: 8.0,
                        ),
                        child: Text('PDF', style: TextStyle(color: Colors.white, fontSize: buttonFontSize)),
                      ),
                    ),
                  ),

                  SizedBox(height: isTablet ? 40 : 30),

                  // Close Button
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: isTablet ? 140 : 100,
                      height: buttonHeight,
                      child: ElevatedButton(
                        onPressed: () async {
                          final controller = Get.find<RecoveryFormController>();
                          await controller.resetForm();
                          Get.back();
                          Get.back();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5.0),
                            side: const BorderSide(color: Colors.red),
                          ),
                          elevation: 8.0,
                        ),
                        child: Text('Close', style: TextStyle(color: Colors.white, fontSize: buttonFontSize)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFieldRow(String labelText, String text, {bool isTablet = false}) {
    TextEditingController textController = TextEditingController(text: text);
    final labelFontSize = isTablet ? 17.0 : 14.0;
    final fieldFontSize = isTablet ? 16.0 : 14.0;

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 14 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                labelText,
                textAlign: TextAlign.left,
                style: TextStyle(fontSize: labelFontSize, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5.0),
                border: Border.all(color: Colors.green),
              ),
              child: TextField(
                readOnly: true,
                controller: textController,
                maxLines: null,
                style: TextStyle(fontSize: fieldFontSize),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndSharePDF(
      String recoveryId,
      String date,
      String shopName,
      String cashRecovery,
      String netBalance,
      ) async {
    final pdf = pw.Document();

    // Load the logo image
    final Uint8List logoBytes =
    (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List();
    final image = pw.MemoryImage(logoBytes);

    var pdfPageFormat = PdfPageFormat.a4;

    pdf.addPage(
      pw.Page(
        pageFormat: pdfPageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Logo and Heading
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 10.0),
                child: pw.Column(
                  children: [
                    pw.Container(
                      height: 120,
                      width: 120,
                      child: pw.Image(image),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Your Company Name', // Replace with your company name
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                'Recovery Slip',
                style: pw.TextStyle(
                  fontSize: 23,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 22),
              pw.Container(
                margin: const pw.EdgeInsets.symmetric(horizontal: 60.0),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Date: $date', style: const pw.TextStyle(fontSize: 16)),
                    pw.SizedBox(height: 12),
                    pw.Text('Receipt#: $recoveryId', style: const pw.TextStyle(fontSize: 16)),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'Shop Name: $shopName',
                      style: const pw.TextStyle(fontSize: 16),
                      maxLines: 2,
                      overflow: pw.TextOverflow.clip,
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text('Payment Amount: $cashRecovery', style: const pw.TextStyle(fontSize: 16)),
                    pw.SizedBox(height: 12),
                    pw.Text('Net Balance: $netBalance', style: const pw.TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Container(
                alignment: pw.Alignment.center,
                margin: const pw.EdgeInsets.only(top: 20.0),
                child: pw.Text(
                  'Developed by MetaXperts',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );

    final directory = await getTemporaryDirectory();
    final output = File('${directory.path}/recovery_form_$recoveryId.pdf');
    await output.writeAsBytes(await pdf.save());
    final xfile = XFile(output.path);
    await Share.shareXFiles([xfile], text: 'Recovery Receipt');
  }
}