//
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../../Models/add_shop_model.dart';
// import '../../Repositories/add_shop_repository.dart';
// import '../Databases/util.dart';
// import '../LocatioPoints/ravelTimeViewModel.dart';
// import 'location_view_model.dart';
//
// class AddShopViewModel extends GetxController {
//   final AddShopRepository _shopRepository = Get.put(AddShopRepository());
//   final _shop = AddShopModel().obs;
//   var allAddShop = <AddShopModel>[].obs;
//   final locationViewModel = Get.put(LocationViewModel());
//   final TravelTimeViewModel travelTimeViewModel = Get.find<TravelTimeViewModel>();
//   final _formKey = GlobalKey<FormState>();
//
//   // Add loading state
//   RxBool isLoading = false.obs;
//
//   // Add debounce flag
//   bool _isProcessing = false;
//
//   GlobalKey<FormState> get formKey => _formKey;
//   var cities = <String>[].obs;
//   var country = <String>[].obs;
//
//   // New reactive variable for button state
//   var isFormReadyToSave = false.obs;
//
//   int shopSerialCounter = 1;
//   String shopCurrentMonth = DateFormat('MMM').format(DateTime.now());
//   String currentuser_id = '';
//   String user_id = ''; // Make sure this is initialized
//
//   ///added code
//   @override
//   void onReady() {
//     super.onReady();
//     travelTimeViewModel.setWorkingScreenStatus(true);
//   }
//
//   @override
//   void onClose() {
//     travelTimeViewModel.setWorkingScreenStatus(false);
//     super.onClose();
//   }
//
//   @override
//   Future<void> onInit() async {
//     super.onInit();
//     // fetchAndSaveShop();
//     fetchCities();
//     await _loadUserId(); // Load user_id on init
//   }
//
//   // Helper to load user_id
//   Future<void> _loadUserId() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     user_id = prefs.getString('currentuser_id') ?? '';
//   }
//
//   // Helper function to clean the city string format
//   String _cleanCityString(String cityString) {
//     // Expected format: "{city: City Name}"
//     // This regex will find and replace "{city: " and the closing "}"
//     // It is case-insensitive and trims whitespace.
//     return cityString.replaceAll(RegExp(r'\{city:\s*|\}$', caseSensitive: false), '').trim();
//   }
//
//   // void fetchCities() async {
//   //   try {
//   //     print('🔄 Starting to fetch cities...');
//   //     var fetchedCities = await _shopRepository.fetchCities();
//   //
//   //     print('✅ Cities fetched successfully: ${fetchedCities.length}');
//   //     print('📊 Cities sample: ${fetchedCities.take(10).toList()}');
//   //
//   //     // Observable list کو اپ ڈیٹ کریں
//   //     cities.value = fetchedCities;
//   //
//   //     print('🎉 Cities list updated in ViewModel');
//   //
//   //   } catch (e) {
//   //     print('❌ Failed to fetch cities: $e');
//   //     // فیل بیک کے طور پر Shared Preferences سے ڈیٹا لوڈ کریں
//   //     var storedCities = await _shopRepository.getCitiesFromSharedPreferences();
//   //     cities.value = storedCities;
//   //     print('📦 Loaded ${storedCities.length} cities from storage');
//   //   }
//   // }
//
//   void fetchCities() async {
//     try {
//       print('🔄 Starting to fetch cities...');
//       var fetchedCities = await _shopRepository.fetchCities();
//
//       cities.clear(); // 👈 purani list hatao
//       cities.assignAll(fetchedCities); // 👈 nayi list daalo
//
//       print("📦 Cities now in VM: ${cities.length}");
//     } catch (e) {
//       print('❌ Failed: $e');
//
//       var storedCities = await _shopRepository.getCitiesFromSharedPreferences();
//       cities.clear();
//       cities.assignAll(storedCities);
//
//       print("📦 Loaded from cache: ${cities.length}");
//     }
//   }
//
//
//   var selectedCity = ''.obs;
//   var selectedCountry = ''.obs;
//
//   // New method to check and update the save button state
//   void updateSaveButtonState() {
//     // Note: The validator is not run here, only a check for non-empty values
//     final areRequiredFieldsFilled =
//         (_shop.value.shop_name?.isNotEmpty ?? false) &&
//             (_shop.value.shop_address?.isNotEmpty ?? false) &&
//             (_shop.value.owner_name?.isNotEmpty ?? false) &&
//             (_shop.value.owner_cnic?.isNotEmpty ?? false) &&
//             (_shop.value.phone_no?.isNotEmpty ?? false) &&
//             (_shop.value.city?.isNotEmpty ?? false);
//
//     final isGpsEnabled = locationViewModel.isGPSEnabled.value == true;
//
//     isFormReadyToSave.value = areRequiredFieldsFilled && isGpsEnabled && !isLoading.value;
//     debugPrint('Is Form Ready to Save: ${isFormReadyToSave.value}');
//   }
//
//   void setShopField(String field, dynamic value) {
//     switch (field) {
//       case 'shop_name':
//         _shop.update((shop) {
//           shop!.shop_name = value;
//         });
//         break;
//       case 'shop_address':
//         _shop.update((shop) {
//           shop!.shop_address = value;
//         });
//         break;
//       case 'owner_name':
//         _shop.update((shop) {
//           shop!.owner_name = value;
//         });
//         break;
//       case 'owner_cnic':
//         _shop.update((shop) {
//           shop!.owner_cnic = value;
//         });
//         break;
//       case 'phone_no':
//         _shop.update((shop) {
//           shop!.phone_no = value;
//         });
//         break;
//       case 'alternative_phone_no':
//         _shop.update((shop) {
//           shop!.alternative_phone_no = value;
//         });
//         break;
//       case 'city':
//         _shop.update((shop) {
//           selectedCity.value = value;
//           shop!.city = value;
//         });
//         break;
//       case 'isGPSEnabled':
//         _shop.update((shop) {
//           shop!.isGPSEnabled = value;
//         });
//         break;
//       default:
//         break;
//     }
//     // Update button state after any field change
//     updateSaveButtonState();
//   }
//
//   Future<void> _loadCounter() async {
//     String currentMonth = DateFormat('MMM').format(DateTime.now());
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     // NOTE: shopHighestSerial is undefined in the provided file.
//     // Assuming a default value of 1 if it cannot be fetched.
//     const int shopHighestSerial = 1;
//     shopSerialCounter =
//     (prefs.getInt('shopSerialCounter') ?? shopHighestSerial ?? 1);
//     shopCurrentMonth = prefs.getString('shopCurrentMonth') ?? currentMonth;
//     currentuser_id = prefs.getString('currentuser_id') ?? '';
//
//     if (shopCurrentMonth != currentMonth) {
//       shopSerialCounter = 1;
//       shopCurrentMonth = currentMonth;
//     }
//
//     debugPrint('SRRRRRRRRRRR: $shopSerialCounter');
//   }
//
//   Future<void> _saveCounter() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     await prefs.setInt('shopSerialCounter', shopSerialCounter);
//     await prefs.setString('shopCurrentMonth', shopCurrentMonth);
//     await prefs.setString('currentuser_id', currentuser_id);
//   }
//
//   String generateNewOrderId(String user_id) {
//     String currentMonth = DateFormat('MMM').format(DateTime.now());
//
//     // NOTE: shopHighestSerial is undefined in the provided file.
//     // Assuming a default value of 1 if it cannot be fetched.
//     const int shopHighestSerial = 1;
//
//     if (currentuser_id != user_id) {
//       shopSerialCounter = shopHighestSerial ?? 1;
//       currentuser_id = user_id;
//     }
//
//     if (shopCurrentMonth != currentMonth) {
//       shopSerialCounter = 1;
//       shopCurrentMonth = currentMonth;
//     }
//
//     String orderId = "S-$user_id-$currentMonth-${shopSerialCounter
//         .toString()
//         .padLeft(3, '0')}";
//     shopSerialCounter++;
//     _saveCounter();
//     return orderId;
//   }
//
//   // Clear filters
//   clearFilters() {
//     _shop.value = AddShopModel();
//     locationViewModel.isGPSEnabled.value = false;
//     _shop.value.isGPSEnabled = false;
//     selectedCity.value = ''; // Reset selected city
//     _formKey.currentState?.reset();
//     updateSaveButtonState(); // Ensure button is disabled after clearing
//   }
//
//   bool validateForm() {
//     return _formKey.currentState?.validate() ?? false;
//   }
//
//   void saveForm() async {
//     // Prevent multiple saves
//     if (isLoading.value || _isProcessing) {
//       debugPrint('⚠️ Save already in progress, ignoring duplicate tap');
//       return;
//     }
//
//     // Set loading and processing flags
//     isLoading.value = true;
//     _isProcessing = true;
//
//     try {
//       // We already check if the form is ready to save via isFormReadyToSave
//       // but the final validation check should still be here.
//       final isFormValid = validateForm();
//       final isGpsEnabled = locationViewModel.isGPSEnabled.value == true;
//       debugPrint('Form valid: $isFormValid, GPS enabled: $isGpsEnabled');
//
//       if (isFormValid && isGpsEnabled) {
//         // Logic for saving (your existing logic)
//         await _loadCounter();
//
//         // Generate shop ID
//         final shopSerial = generateNewOrderId(user_id);
//
//         // Save shop to repository
//         await _shopRepository.addAddShop(AddShopModel(
//           shop_id: shopSerial,
//           shop_name: _shop.value.shop_name,
//           shop_address: _shop.value.shop_address,
//           owner_name: _shop.value.owner_name,
//           owner_cnic: _shop.value.owner_cnic,
//           phone_no: _shop.value.phone_no,
//           alternative_phone_no: _shop.value.alternative_phone_no,
//           city: _shop.value.city,
//           user_id: user_id,
//           longitude: locationViewModel.globalLatitude1.value,
//           latitude: locationViewModel.globalLongitude1.value,
//           shop_live_address: locationViewModel.shopAddress.value,
//           isGPSEnabled: _shop.value.isGPSEnabled,
//         ), allAddShop);
//
//         // ✅ Show success snackbar
//         Get.snackbar(
//           'Success',
//           'Shop saved successfully!',
//           snackPosition: SnackPosition.BOTTOM,
//           backgroundColor: Colors.blueGrey,
//           colorText: Colors.white,
//           margin: const EdgeInsets.all(10),
//           duration: const Duration(seconds: 2),
//         );
//
//         // 👉 Clear the form fields after saving
//         await clearFilters();
//       } else {
//         // ❌ Show error
//         Get.snackbar(
//           'Error',
//           'Please fill all required fields and enable GPS.',
//           snackPosition: SnackPosition.BOTTOM,
//           backgroundColor: Colors.red,
//           colorText: Colors.white,
//           margin: const EdgeInsets.all(10),
//           duration: const Duration(seconds: 2),
//         );
//       }
//     } catch (e) {
//       // Handle any errors
//       Get.snackbar(
//         'Error',
//         'Failed to save shop: $e',
//         snackPosition: SnackPosition.BOTTOM,
//         backgroundColor: Colors.red,
//         colorText: Colors.white,
//         margin: const EdgeInsets.all(10),
//         duration: const Duration(seconds: 3),
//       );
//       debugPrint('Error saving shop: $e');
//     } finally {
//       // Reset loading state after a delay to prevent immediate re-taps
//       Future.delayed(Duration(milliseconds: 500), () {
//         isLoading.value = false;
//         _isProcessing = false;
//         updateSaveButtonState(); // Update button state
//       });
//     }
//   }
//
//   fetchAllAddShop() async {
//     var addShop = await _shopRepository.getAddShop();
//     allAddShop.value = addShop;
//   }
//
//   fetchAndSaveShop() async {
//     await _shopRepository.fetchAndSaveShops();
//     // await fetchAllAddShop();
//   }
//
//   fetchAndSaveHeadsShop() async {
//     await _shopRepository.fetchAndSaveShopsForHeads();
//     // await fetchAllAddShop();
//   }
//
//   addAddShop(AddShopModel addShopModel) async {
//     await _shopRepository.addAddShop(addShopModel, allAddShop);
//   }
//
//   updateAddShop(AddShopModel addShopModel) async {
//     await _shopRepository.updateAddShop(addShopModel, allAddShop);
//   }
//
//   deleteAddShop(String? id) async {
//     await _shopRepository.deleteAddShop(id, allAddShop);
//   }
//
//   serialCounterGet() async {
//     await _shopRepository.serialNumberGeneratorApi();
//   }
// }


import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Models/add_shop_model.dart';
import '../../Repositories/add_shop_repository.dart';
import '../Databases/util.dart';
import 'location_view_model.dart';

class AddShopViewModel extends GetxController {
  final AddShopRepository _shopRepository = Get.put(AddShopRepository());
  final _shop = AddShopModel().obs;
  var allAddShop = <AddShopModel>[].obs;
  final locationViewModel = Get.put(LocationViewModel());
  final _formKey = GlobalKey<FormState>();

  // Loading state
  RxBool isLoading = false.obs;

  // Debounce flag
  bool _isProcessing = false;

  GlobalKey<FormState> get formKey => _formKey;
  var cities = <String>[].obs;
  var country = <String>[].obs;

  // Reactive variable for button state
  var isFormReadyToSave = false.obs;

  String user_id = '';


  @override
  Future<void> onInit() async {
    super.onInit();
    fetchCities();
    await _loadUserId();
  }

  Future<void> _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    user_id = prefs.getString('currentuser_id') ?? '';
  }

  String _cleanCityString(String cityString) {
    return cityString.replaceAll(RegExp(r'\{city:\s*|\}$', caseSensitive: false), '').trim();
  }

  void fetchCities() async {
    try {
      print('🔄 Starting to fetch cities...');
      var fetchedCities = await _shopRepository.fetchCities();

      cities.clear();
      cities.assignAll(fetchedCities);

      print("📦 Cities now in VM: ${cities.length}");
    } catch (e) {
      print('❌ Failed: $e');

      var storedCities = await _shopRepository.getCitiesFromSharedPreferences();
      cities.clear();
      cities.assignAll(storedCities);

      print("📦 Loaded from cache: ${cities.length}");
    }
  }

  var selectedCity = ''.obs;
  var selectedCountry = ''.obs;

  void updateSaveButtonState() {
    final areRequiredFieldsFilled =
        (_shop.value.shop_name?.isNotEmpty ?? false) &&
            (_shop.value.shop_address?.isNotEmpty ?? false) &&
            (_shop.value.owner_name?.isNotEmpty ?? false) &&
            (_shop.value.owner_cnic?.isNotEmpty ?? false) &&
            (_shop.value.phone_no?.isNotEmpty ?? false) &&
            (_shop.value.city?.isNotEmpty ?? false);

    final isGpsEnabled = locationViewModel.isGPSEnabled.value == true;

    isFormReadyToSave.value = areRequiredFieldsFilled && isGpsEnabled && !isLoading.value;
    debugPrint('Is Form Ready to Save: ${isFormReadyToSave.value}');
  }

  void setShopField(String field, dynamic value) {
    switch (field) {
      case 'shop_name':
        _shop.update((shop) {
          shop!.shop_name = value;
        });
        break;
      case 'shop_address':
        _shop.update((shop) {
          shop!.shop_address = value;
        });
        break;
      case 'owner_name':
        _shop.update((shop) {
          shop!.owner_name = value;
        });
        break;
      case 'owner_cnic':
        _shop.update((shop) {
          shop!.owner_cnic = value;
        });
        break;
      case 'phone_no':
        _shop.update((shop) {
          shop!.phone_no = value;
        });
        break;
      case 'alternative_phone_no':
        _shop.update((shop) {
          shop!.alternative_phone_no = value;
        });
        break;
      case 'city':
        _shop.update((shop) {
          selectedCity.value = value;
          shop!.city = value;
        });
        break;
      case 'isGPSEnabled':
        _shop.update((shop) {
          shop!.isGPSEnabled = value;
        });
        break;
      default:
        break;
    }
    updateSaveButtonState();
  }

  // Clear filters
  clearFilters() {
    _shop.value = AddShopModel();
    locationViewModel.isGPSEnabled.value = false;
    _shop.value.isGPSEnabled = false;
    selectedCity.value = '';
    _formKey.currentState?.reset();
    updateSaveButtonState();
  }

  bool validateForm() {
    return _formKey.currentState?.validate() ?? false;
  }

  void saveForm() async {
    // Prevent multiple saves
    if (isLoading.value || _isProcessing) {
      debugPrint('⚠️ Save already in progress, ignoring duplicate tap');
      return;
    }

    isLoading.value = true;
    _isProcessing = true;

    try {
      final isFormValid = validateForm();
      final isGpsEnabled = locationViewModel.isGPSEnabled.value == true;
      debugPrint('Form valid: $isFormValid, GPS enabled: $isGpsEnabled');

      if (isFormValid && isGpsEnabled) {
        // ✅ FIX 3: Generate shop ID directly from DB (no counter, no duplicates)
        final shopSerial = await _shopRepository.generateUniqueShopId(user_id);
        debugPrint('🆔 Generated shop ID: $shopSerial');

        // Save shop to repository
        await _shopRepository.addAddShop(AddShopModel(
          shop_id: shopSerial,
          shop_name: _shop.value.shop_name,
          shop_address: _shop.value.shop_address,
          owner_name: _shop.value.owner_name,
          owner_cnic: _shop.value.owner_cnic,
          phone_no: _shop.value.phone_no,
          alternative_phone_no: _shop.value.alternative_phone_no,
          city: _shop.value.city,
          user_id: user_id,
          longitude: locationViewModel.globalLatitude1.value,
          latitude: locationViewModel.globalLongitude1.value,
          shop_live_address: locationViewModel.shopAddress.value,
          isGPSEnabled: _shop.value.isGPSEnabled,
        ), allAddShop);

        // ✅ Show success snackbar
        Get.snackbar(
          'Success',
          'Shop saved successfully!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.blueGrey,
          colorText: Colors.white,
          margin: const EdgeInsets.all(10),
          duration: const Duration(seconds: 2),
        );

        // Clear the form fields after saving
        await clearFilters();
      } else {
        Get.snackbar(
          'Error',
          'Please fill all required fields and enable GPS.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          margin: const EdgeInsets.all(10),
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to save shop: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 3),
      );
      debugPrint('Error saving shop: $e');
    } finally {
      Future.delayed(Duration(milliseconds: 500), () {
        isLoading.value = false;
        _isProcessing = false;
        updateSaveButtonState();
      });
    }
  }

  fetchAllAddShop() async {
    var addShop = await _shopRepository.getAddShop();
    allAddShop.value = addShop;
  }

  fetchAndSaveShop() async {
    await _shopRepository.fetchAndSaveShops();
  }

  fetchAndSaveHeadsShop() async {
    await _shopRepository.fetchAndSaveShopsForHeads();
  }

  addAddShop(AddShopModel addShopModel) async {
    await _shopRepository.addAddShop(addShopModel, allAddShop);
  }

  updateAddShop(AddShopModel addShopModel) async {
    await _shopRepository.updateAddShop(addShopModel, allAddShop);
  }

  deleteAddShop(String? id) async {
    await _shopRepository.deleteAddShop(id, allAddShop);
  }

  serialCounterGet() async {
    await _shopRepository.serialNumberGeneratorApi();
  }
}