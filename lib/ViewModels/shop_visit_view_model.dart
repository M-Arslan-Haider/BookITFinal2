import 'dart:io';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:order_booking_app/Screens/home_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:order_booking_app/ViewModels/shop_visit_details_view_model.dart';
import '../Databases/util.dart';
import '../Models/HeadsShopVistModels.dart';
import '../Models/add_shop_model.dart';
import '../Models/shop_visit_model.dart';
import '../Repositories/ScreenRepositories/products_repository.dart';
import '../Repositories/shop_visit_repository.dart';
import '../Repositories/add_shop_repository.dart';
import '../Screens/HomeScreenComponents/Today Stats/daily_counter.dart';
import '../Screens/order_booking_screen.dart';
import '../Services/ApiServices/api_service.dart';
import '../Services/FirebaseServices/firebase_remote_config.dart';
import 'location_view_model.dart';

class ShopVisitViewModel extends GetxController {
  var allShopVisit = <ShopVisitModel>[].obs;
  ShopVisitRepository shopvisitRepository = ShopVisitRepository();
  ProductsRepository productsRepository = Get.put(ProductsRepository());
  late ShopVisitDetailsViewModel shopVisitDetailsViewModel =
  Get.put(ShopVisitDetailsViewModel());
  AddShopRepository addShopRepository = Get.put(AddShopRepository());

  final ImagePicker picker = ImagePicker();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final locationViewModel = Get.put(LocationViewModel());

  final TextEditingController shopAddressController = TextEditingController();
  final TextEditingController ownerNameController = TextEditingController();
  final TextEditingController bookerNameController = TextEditingController();
  final feedBackController = TextEditingController();

  var shop_address = ''.obs;
  var owner_name = ''.obs;
  var booker_name = userName.obs;
  var phone_number = ''.obs;
  var city = ''.obs;
  var feedBack = ''.obs;
  var selectedBrand = ''.obs;
  var selectedShop = ''.obs;
  var selectedImage = Rx<XFile?>(null);
  var checklistState = List<bool>.filled(4, false).obs;
  var rows = <DataRow>[].obs;
  ValueNotifier<List<Map<String, dynamic>>> rowsNotifier =
  ValueNotifier<List<Map<String, dynamic>>>([]);
  var brands = <String?>[].obs;
  var shops = <String?>[].obs;
  var shopDetails = <AddShopModel>[].obs;
  final List<String> checklistLabels = [
    'Performed Store walk_through',
    'Updated Store Planogram',
    'Checked Shelf Tags and Price Signage',
    'Reviewed Expiry Dates on Products',
  ];

  int shopVisitsSerialCounter = 1;
  int shopVisitsHeadsSerialCounter = 1;
  String shopVisitCurrentMonth = DateFormat('MMM').format(DateTime.now());
  String shopVisitHeadsCurrentMonth = DateFormat('MMM').format(DateTime.now());
  String currentuser_id = '';


  var apiShopVisitsCount = 0.obs;
  var isLoading = false.obs;
  var isOrderFormLoading = false.obs;
  var isOnlyVisitLoading = false.obs;

  // Variables to control button state
  var isOrderButtonEnabled = false.obs;
  var isOnlyVisitButtonEnabled = false.obs;


  @override
  void onInit() {
    super.onInit();
    fetchTotalShopVisit();
    updateButtonReadiness();
  }

  ///====19-10-2025////
  // @override
  //
  // void onClose() {
  //   feedBackController.dispose();
  //   super.onClose();
  // }

  // ====================================================================
  // Core Utility Methods
  // ====================================================================

  Future<void> fetchTotalShopVisit() async {
    try {
      isLoading(true);
      await Config.fetchLatestConfig();
      final monthYear = DateFormat('MMM-yyyy').format(DateTime.now());
      final url = '${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.getApiUrlShopVisitTotal}$user_id/$monthYear';
      debugPrint('API URL: $url');

      List<dynamic> data = await ApiService.getData(url);

      if (data.isNotEmpty) {
        apiShopVisitsCount.value = data[0]['count(shop_name)'];
      }
    } catch (e) {
      //  Get.snackbar('Error', 'Failed to fetch visits: $e');
    } finally {
      isLoading(false);
    }
  }

  Future<void> fetchBrands() async {
    try {
      var savedBrands = await productsRepository.getProductsModel();
      brands.value =
          savedBrands.map((product) => product.brand).toSet().toList();
    } catch (e) {
      debugPrint('Failed to fetch Brands: $e');
    }
  }

  Future<void> fetchShops() async {
    try {
      var savedShops = await addShopRepository.getAddShop();
      shops.value = savedShops.map((shop) => shop.shop_name).toList();
      shopDetails.value =
          savedShops; // Update this line to store full shop details
    } catch (e) {
      debugPrint('Failed to fetch shops: $e');
    }
  }

  Future<void> _loadCounter() async {
    String currentMonth = DateFormat('MMM').format(DateTime.now());
    SharedPreferences prefs = await SharedPreferences.getInstance();
    shopVisitsSerialCounter = (prefs.getInt('shopVisitsSerialCounter') ??
        shopVisitHighestSerial ??
        1);
    shopVisitCurrentMonth =
        prefs.getString('shopVisitCurrentMonth') ?? currentMonth;
    currentuser_id = prefs.getString('currentuser_id') ?? '';

    if (shopVisitCurrentMonth != currentMonth) {
      shopVisitsSerialCounter = 1;
      shopVisitCurrentMonth = currentMonth;
    }

    debugPrint('SR: $shopVisitsSerialCounter');
  }

  Future<void> _saveCounter() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('shopVisitsSerialCounter', shopVisitsSerialCounter);
    await prefs.setString('shopVisitCurrentMonth', shopVisitCurrentMonth);
    await prefs.setString('currentuser_id', currentuser_id);
  }

  String generateNewOrderId(String user_id) {
    String currentMonth = DateFormat('MMM').format(DateTime.now());

    if (currentuser_id != user_id) {
      shopVisitsSerialCounter = shopVisitHighestSerial ?? 1;
      currentuser_id = user_id;
    }

    if (shopVisitCurrentMonth != currentMonth) {
      shopVisitsSerialCounter = 1;
      shopVisitCurrentMonth = currentMonth;
    }

    String orderId =
        "SV-$user_id-$currentMonth-${shopVisitsSerialCounter.toString().padLeft(3, '0')}";
    shopVisitsSerialCounter++;
    _saveCounter();
    return orderId;
  }

  Future<void> saveImage() async {
    try {
      if (selectedImage.value == null) return;
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/captured_image.jpg';

      Uint8List? compressedImageBytes = await FlutterImageCompress.compressWithFile(
        selectedImage.value!.path,
        minWidth: 400,
        minHeight: 600,
        quality: 40,
      );

      if (compressedImageBytes != null) {
        await File(filePath).writeAsBytes(compressedImageBytes);
        debugPrint('Compressed image saved successfully at $filePath');
      } else {
        debugPrint('Image compression failed.');
      }
    } catch (e) {
      debugPrint('Error compressing and saving image: $e');
    }
  }

  // ====================================================================
  // Validation and Setters
  // ====================================================================

  // Check shared required fields
  String? _getSharedRequiredFieldsError() {
    if (selectedBrand.value.isEmpty || selectedBrand.value == " Select a Brand") {
      return "Please select a Brand.";
    }
    if (selectedShop.value.isEmpty || selectedShop.value == " Select a Shop") {
      return "Please select a Shop.";
    }
    if (owner_name.value.isEmpty) {
      return "Please enter the Owner Name.";
    }
    if (selectedImage.value == null) {
      return "Please capture or select a shop image.";
    }
    // GPS Check (required for both)
    if (locationViewModel.isGPSEnabled.value != true ||
        locationViewModel.globalLatitude1.value == 0.0 ||
        locationViewModel.globalLongitude1.value == 0.0) {
      return "Please enable GPS and ensure location is acquired.";
    }
    return null;
  }

  // Validation for Order Form (Requires ALL 4 checklist items)
  String? getOrderFormErrorMessage() {
    String? sharedError = _getSharedRequiredFieldsError();
    if (sharedError != null) return sharedError;

    // Check ALL 4 checklist items
    if (checklistState.contains(false) || checklistState.length != 4) {
      return "Please ensure ALL 4 checklist items are checked for Order Form.";
    }

    // Feedback is not required for Order Form

    return null; // All checks passed for Order Form
  }

  // Validation for Only Visit (Requires ALL 4 checklist items AND Feedback)
  String? getOnlyVisitErrorMessage() {
    String? sharedError = _getSharedRequiredFieldsError();
    if (sharedError != null) return sharedError;

    // NEW: Check ALL 4 checklist items (as requested by user)
    if (checklistState.contains(false) || checklistState.length != 4) {
      return "Please ensure ALL 4 checklist items are checked for Only Visit.";
    }

    // Feedback Check (Required for Only Visit)


    return null; // All checks passed for Only Visit
  }

  // Updates the button enabled states for both buttons
  void updateButtonReadiness() {
    // Buttons are disabled/enabled based on their own, independent validation results.
    isOrderButtonEnabled.value = getOrderFormErrorMessage() == null;
    isOnlyVisitButtonEnabled.value = getOnlyVisitErrorMessage() == null;
    debugPrint("Order Button Enabled: ${isOrderButtonEnabled.value}");
    debugPrint("Only Visit Button Enabled: ${isOnlyVisitButtonEnabled.value}");
  }

  void setBrand(String brand) {
    selectedBrand.value = brand;
    updateButtonReadiness();
  }

  void setSelectedShop(String shopName) {
    selectedShop.value = shopName;
    updateShopDetails(shopName);
  }

  void setOwnerName(String value) {
    ownerNameController.text = value;
    owner_name.value = value;
    updateButtonReadiness();
  }

  void setShopAddress(String value) {
    shopAddressController.text = value;
    shop_address.value = value;
    updateButtonReadiness();
  }

  void updateChecklistState(int index, bool value) {
    checklistState[index] = value;
    checklistState.refresh();
    updateButtonReadiness();
  }

  void setFeedBack(String value) {
    feedBack.value = value;
    updateButtonReadiness();
  }

  Future<void> pickImage() async {
    final image =
    await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
    selectedImage.value = image;
    await saveImage();
    updateButtonReadiness();
  }

  Future<void> takePicture() async {
    final image =
    await picker.pickImage(source: ImageSource.camera, imageQuality: 40);
    selectedImage.value = image;
    await saveImage();
    updateButtonReadiness();
  }

  updateShopDetails(String shopName) {
    var shop = shopDetails.firstWhere((shop) => shop.shop_name == shopName);
    shop_address.value = shop.shop_address!;
    owner_name.value = shop.owner_name!;
    phone_number.value = shop.phone_no!;
    shopAddressController.text = shop.shop_address!;
    ownerNameController.text = shop.owner_name!;
    bookerNameController.text = userName;
    city.value = shop.city!;
    updateButtonReadiness();
  }

  // ====================================================================
  // Persistence and Save Methods
  // ====================================================================

  Future<void> _saveShopVisitData({bool isOrder = true}) async {
    bool isReadyToSave = isOrder ? isOrderButtonEnabled.value : isOnlyVisitButtonEnabled.value;

    if (isReadyToSave) {
      String imagePath = selectedImage.value!.path;
      List<int> imageBytesList = await File(imagePath).readAsBytes();

      Uint8List? compressedImageBytes = Uint8List.fromList(imageBytesList);

      await _loadCounter();
      final orderSerial = generateNewOrderId(user_id);
      shop_visit_master_id = orderSerial;

      await addShopVisit(ShopVisitModel(
        shop_name: selectedShop.value,
        shop_address: shop_address.value,
        owner_name: owner_name.value,
        brand: selectedBrand.value,
        booker_name: booker_name.value,
        walk_through: checklistState[0],
        planogram: checklistState[1],
        signage: checklistState[2],
        product_reviewed: checklistState[3],
        body: compressedImageBytes,
        feedback: feedBack.value,
        user_id: user_id.toString(),
        latitude: locationViewModel.globalLatitude1.value,
        longitude: locationViewModel.globalLongitude1.value,
        address: locationViewModel.shopAddress.value,
        city: city.value,
        shop_visit_master_id: shop_visit_master_id.toString(),
      ));

      // await shopvisitRepository.getShopVisit();
      // await shopVisitDetailsViewModel.saveFilteredProducts();
      // await shopvisitRepository.postDataFromDatabaseToAPI();
      //
      // Get.snackbar("Success", "Form submitted successfully!",
      //     snackPosition: SnackPosition.BOTTOM);
      await shopvisitRepository.getShopVisit();
      await shopVisitDetailsViewModel.saveFilteredProducts();
      await shopvisitRepository.postDataFromDatabaseToAPI();

      ///Daily count
      await DailyCounter.increaseShopVisit();
      int visits = await DailyCounter.getTodayShopVisits();



      Get.snackbar("Success", "Form submitted successfully!",
          snackPosition: SnackPosition.BOTTOM);


      if (isOrder) {
        Get.to(() => const OrderBookingScreen());
      } else {
        await clearFilters();
        Get.to(() => const HomeScreen());
      }
    } else {
      Get.snackbar("Error", "Validation failed. Please fill all required fields.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    }
  }

  Future<void> saveForm() async {
    if (isOrderButtonEnabled.value && !isOrderFormLoading.value) {
      isOrderFormLoading.value = true;
      await _saveShopVisitData(isOrder: true);
      isOrderFormLoading.value = false;
    }
  }

  Future<void> saveFormNoOrder() async {
    if (isOnlyVisitButtonEnabled.value && !isOnlyVisitLoading.value) {
      isOnlyVisitLoading.value = true;
      await _saveShopVisitData(isOrder: false);
      isOnlyVisitLoading.value = false;
    }
  }

  fetchAllShopVisit() async {
    var shopvisit = await shopvisitRepository.getShopVisit();
    allShopVisit.value = shopvisit;
  }

  addShopVisit(ShopVisitModel shopvisitModel) {
    shopvisitRepository.add(shopvisitModel);
    fetchAllShopVisit();
  }

  updateShopVisit(ShopVisitModel shopvisitModel) {
    shopvisitRepository.update(shopvisitModel);
    fetchAllShopVisit();
  }

  addHeadsShopVisit(HeadsShopVisitModel headsShopVisitModel){
    shopvisitRepository.addHeasdsShopVisits(headsShopVisitModel);
    fetchAllShopVisit();
  }
  updateHeadsShopVisit(HeadsShopVisitModel headsShopVisitModel){
    shopvisitRepository.updateheads(headsShopVisitModel);
    fetchAllShopVisit();
  }
  deleteShopVisit(String id) {
    shopvisitRepository.delete(id);
    fetchAllShopVisit();
  }

  clearFilters() {
    formKey.currentState?.reset();

    locationViewModel.isGPSEnabled.value = false;
    selectedBrand.value = '';
    selectedShop.value = '';
    shop_address.value = '';
    owner_name.value = '';
    booker_name.value = userName;
    feedBack.value = '';
    selectedImage.value = null;
    checklistState.value = List<bool>.filled(4, false);
    shopAddressController.clear();
    ownerNameController.clear();
    bookerNameController.clear();
    updateButtonReadiness();
  }

  bool validateForm() {
    return true;
  }

  serialCounterGet()async{ await shopvisitRepository.serialNumberGeneratorApi(); }
  serialCounterGetHeads()async{ await shopvisitRepository.serialNumberGeneratorApiHeads(); }

  Future<void> loadCounterHeads() async {
    String currentMonth = DateFormat('MMM').format(DateTime.now());
    SharedPreferences prefs = await SharedPreferences.getInstance();
    shopVisitsHeadsSerialCounter = (prefs.getInt('shopVisitsHeadsSerialCounter') ?? shopVisitHeadsHighestSerial ?? 1);
    shopVisitHeadsCurrentMonth = prefs.getString('shopVisitHeadsCurrentMonth') ?? currentMonth;
    currentuser_id = prefs.getString('currentuser_id') ?? '';
    if (shopVisitHeadsCurrentMonth != currentMonth) {
      shopVisitsHeadsSerialCounter = 1;
      shopVisitHeadsCurrentMonth = currentMonth;
    }
    debugPrint('SR: $shopVisitsHeadsSerialCounter');
  }
  Future<void> _saveCounterHeads() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('shopVisitsHeadsSerialCounter', shopVisitsHeadsSerialCounter);
    await prefs.setString('shopVisitCurrentMonth', shopVisitHeadsCurrentMonth);
    await prefs.setString('currentuser_id', currentuser_id);
  }
  String generateNewOrderIdHeads(String user_id) {
    String currentMonth = DateFormat('MMM').format(DateTime.now());
    if (currentuser_id != user_id) {
      shopVisitsHeadsSerialCounter = shopVisitHeadsHighestSerial ?? 1;
      currentuser_id = user_id;
    }
    if (shopVisitHeadsCurrentMonth != currentMonth) {
      shopVisitsHeadsSerialCounter = 1;
      shopVisitHeadsCurrentMonth = currentMonth;
    }
    String orderId = "SV-$user_id-$currentMonth-${shopVisitsHeadsSerialCounter.toString().padLeft(3, '0')}";
    shopVisitsHeadsSerialCounter++;
    _saveCounterHeads();
    return orderId;
  }
  Future<void> postHeadsShopVisit() async {
    await shopvisitRepository.postDataFromDatabaseToAPIHeads();
  }
}



