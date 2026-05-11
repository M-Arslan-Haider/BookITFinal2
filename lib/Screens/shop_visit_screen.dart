// // // // import 'package:flutter/material.dart';
// // // // import 'package:get/get.dart';
// // // // import 'package:order_booking_app/ViewModels/ProductsViewModel.dart';
// // // // import '../LocatioPoints/ravelTimeViewModel.dart';
// // // // import '../ViewModels/location_view_model.dart';
// // // // import '../ViewModels/shop_visit_details_view_model.dart';
// // // // import '../ViewModels/shop_visit_view_model.dart';
// // // // // ✅✅ ABDULLAH: Added import for TravelTimeViewModel
// // // //
// // // // import 'Components/custom_button.dart';
// // // // import 'Components/custom_dropdown.dart';
// // // // import 'Components/custom_editable_menu_option.dart' hide IconPosition;
// // // // import 'Components/custom_switch.dart';
// // // // import 'ShopVisitScreenComponents/check_list_section.dart';
// // // // import 'ShopVisitScreenComponents/feedback_section.dart';
// // // // import 'ShopVisitScreenComponents/photo_picker.dart';
// // // // import 'ShopVisitScreenComponents/product_search_card.dart';
// // // //
// // // // class ShopVisitScreen extends StatefulWidget {
// // // //   const ShopVisitScreen({super.key});
// // // //
// // // //   @override
// // // //   _StateShopVisitScreen createState() => _StateShopVisitScreen();
// // // // }
// // // //
// // // // class _StateShopVisitScreen extends State<ShopVisitScreen> {
// // // //   final ShopVisitViewModel shopVisitViewModel = Get.put(ShopVisitViewModel());
// // // //   final ShopVisitDetailsViewModel shopVisitDetailsViewModel =
// // // //   Get.put(ShopVisitDetailsViewModel());
// // // //   final ProductsViewModel productsViewModel = Get.put(ProductsViewModel());
// // // //   final LocationViewModel locationViewModel = Get.find<LocationViewModel>(); // ✅ Use Find instead of Put
// // // //   final feedBackController = TextEditingController();
// // // //
// // // //   @override
// // // //   void initState() {
// // // //     super.initState();
// // // //     // ✅✅ ABDULLAH: Set working status when entering Shop Visit screen
// // // //     WidgetsBinding.instance.addPostFrameCallback((_) {
// // // //       final travelTimeViewModel = Get.find<TravelTimeViewModel>();
// // // //       travelTimeViewModel.setWorkingScreenStatus(true);
// // // //       debugPrint("📍 [WORKING STATUS] Shop Visit Screen - Working time ACTIVE");
// // // //     });
// // // //
// // // //     feedBackController.text = shopVisitViewModel.feedBack.value;
// // // //     shopVisitViewModel.selectedShop.value = "";
// // // //     shopVisitViewModel.selectedBrand.value = "";
// // // //     shopVisitViewModel.fetchBrands();
// // // //     shopVisitViewModel.fetchShops();
// // // //     shopVisitViewModel.updateButtonReadiness();
// // // //
// // // //     ever(shopVisitViewModel.feedBack, (value) {
// // // //       feedBackController.text = value;
// // // //       feedBackController.selection = TextSelection.fromPosition(
// // // //         TextPosition(offset: feedBackController.text.length),
// // // //       );
// // // //     });
// // // //   }
// // // //   @override
// // // //   void dispose() {
// // // //     // ✅✅ ABDULLAH: Reset working status when leaving Shop Visit screen
// // // //     final travelTimeViewModel = Get.find<TravelTimeViewModel>();
// // // //     travelTimeViewModel.setWorkingScreenStatus(false);
// // // //     debugPrint("📍 [WORKING STATUS] Shop Visit Screen - Working time INACTIVE");
// // // //
// // // //     super.dispose();
// // // //   }
// // // //
// // // //   String? requiredDropdownValidator(String? value, String placeholder) {
// // // //     if (value == null || value.isEmpty || value == placeholder) {
// // // //       return null;
// // // //     }
// // // //     return null;
// // // //   }
// // // //
// // // //   @override
// // // //   Widget build(BuildContext context) {
// // // //     final size = MediaQuery.of(context).size;
// // // //     final width = size.width;
// // // //     final isTablet = width > 600;
// // // //
// // // //     final double fontSize = isTablet ? 18 : 14;
// // // //     final double buttonWidth = isTablet ? width * 0.3 : width * 0.4;
// // // //     final double buttonHeight = isTablet ? 55 : 45;
// // // //
// // // //     return SafeArea(
// // // //       child: Scaffold(
// // // //         backgroundColor: Colors.white,
// // // //         appBar: _buildAppBar(),
// // // //         body: SingleChildScrollView(
// // // //           physics: const BouncingScrollPhysics(),
// // // //           child: Padding(
// // // //             padding: EdgeInsets.only(
// // // //               left: 20,
// // // //               right: 20,
// // // //               top: 30,
// // // //               bottom: MediaQuery.of(context).padding.bottom + 40,
// // // //             ),
// // // //             child: Form(
// // // //               key: shopVisitViewModel.formKey,
// // // //               child: Column(
// // // //                 mainAxisSize: MainAxisSize.min,
// // // //                 crossAxisAlignment: CrossAxisAlignment.center,
// // // //                 children: [
// // // //                   Column(
// // // //                     children: [
// // // //                       Obx(
// // // //                             () => CustomDropdown(
// // // //                           label: "Brand",
// // // //                           icon: Icons.branding_watermark,
// // // //                           items: shopVisitViewModel.brands
// // // //                               .where((brand) => brand != null)
// // // //                               .cast<String>()
// // // //                               .toList(),
// // // //                           selectedValue: shopVisitViewModel
// // // //                               .selectedBrand.value.isNotEmpty
// // // //                               ? shopVisitViewModel.selectedBrand.value
// // // //                               : " Select a Brand",
// // // //                           onChanged: (value) async {
// // // //                             shopVisitDetailsViewModel.filteredRows.refresh();
// // // //                             shopVisitViewModel.setBrand(value!);
// // // //                             shopVisitDetailsViewModel
// // // //                                 .filterProductsByBrand(value);
// // // //                           },
// // // //                           useBoxShadow: false,
// // // //                           validator: (value) => requiredDropdownValidator(value, " Select a Brand"),
// // // //                           inputBorder: const UnderlineInputBorder(
// // // //                             borderSide:
// // // //                             BorderSide(color: Colors.blue, width: 1.0),
// // // //                           ),
// // // //                           iconSize: 22.0,
// // // //                           contentPadding:
// // // //                           MediaQuery.of(context).size.height * 0.005,
// // // //                           iconColor: Colors.blue,
// // // //                           textStyle: const TextStyle(
// // // //                               fontSize: 13,
// // // //                               fontWeight: FontWeight.bold,
// // // //                               color: Colors.black),
// // // //                         ),
// // // //                       ),
// // // //                       Obx(
// // // //                             () => CustomDropdown(
// // // //                           label: "Shop",
// // // //                           icon: Icons.store,
// // // //                           items: shopVisitViewModel.shops.value
// // // //                               .where((shop) => shop != null)
// // // //                               .cast<String>()
// // // //                               .toList(),
// // // //                           selectedValue: shopVisitViewModel
// // // //                               .selectedShop.value.isNotEmpty
// // // //                               ? shopVisitViewModel.selectedShop.value
// // // //                               : " Select a Shop",
// // // //                           onChanged: (value) {
// // // //                             shopVisitViewModel.setSelectedShop(value!);
// // // //                             debugPrint(shopVisitViewModel.shop_address.value);
// // // //                             debugPrint(shopVisitViewModel.city.value);
// // // //                           },
// // // //                           validator: (value) => requiredDropdownValidator(value, " Select a Shop"),
// // // //                           useBoxShadow: false,
// // // //                           inputBorder: const UnderlineInputBorder(
// // // //                             borderSide:
// // // //                             BorderSide(color: Colors.blue, width: 1.0),
// // // //                           ),
// // // //                           maxHeight: 50.0,
// // // //                           maxWidth: 385.0,
// // // //                           iconSize: 23.0,
// // // //                           contentPadding: 0.0,
// // // //                           iconColor: Colors.blue,
// // // //                         ),
// // // //                       ),
// // // //                       Obx(() => _buildTextField(
// // // //                         initialValue:
// // // //                         shopVisitViewModel.shop_address.value,
// // // //                         label: "Shop Address",
// // // //                         icon: Icons.location_on,
// // // //                         validator: (value) =>
// // // //                         value == null || value.isEmpty
// // // //                             ? 'Please enter the shop address'
// // // //                             : null,
// // // //                         onChanged: (value) =>
// // // //                             shopVisitViewModel.setShopAddress(value),
// // // //                       )),
// // // //                       Obx(() => _buildTextField(
// // // //                         initialValue: shopVisitViewModel.owner_name.value,
// // // //                         label: "Owner Name",
// // // //                         icon: Icons.person,
// // // //                         validator: (value) =>
// // // //                         value == null || value.isEmpty
// // // //                             ? 'Please enter owner name'
// // // //                             : null,
// // // //                         onChanged: (value) =>
// // // //                             shopVisitViewModel.setOwnerName(value),
// // // //                       )),
// // // //                       _buildTextField(
// // // //                         label: "Booker Name",
// // // //                         initialValue: shopVisitViewModel.booker_name.value,
// // // //                         icon: Icons.person,
// // // //                         validator: (value) =>
// // // //                         value == null || value.isEmpty
// // // //                             ? 'Please enter the booker name'
// // // //                             : null,
// // // //                         onChanged: (value) =>
// // // //                         shopVisitViewModel.booker_name.value = value,
// // // //                       ),
// // // //                     ],
// // // //                   ),
// // // //                   const SizedBox(height: 20),
// // // //                   const SectionHeader(title: "Stock Check"),
// // // //                   const SizedBox(height: 10),
// // // //                   ProductSearchCard(
// // // //                     filterData: shopVisitDetailsViewModel.filterData,
// // // //                     rowsNotifier: shopVisitDetailsViewModel.rowsNotifier,
// // // //                     filteredRows: shopVisitDetailsViewModel.filteredRows,
// // // //                     shopVisitDetailsViewModel: shopVisitDetailsViewModel,
// // // //                   ),
// // // //                   const SizedBox(height: 20),
// // // //                   ChecklistSection(
// // // //                     labels: shopVisitViewModel.checklistLabels,
// // // //                     checklistState: shopVisitViewModel.checklistState,
// // // //                     onStateChanged: (index, value) {
// // // //                       shopVisitViewModel.updateChecklistState(index, value);
// // // //                     },
// // // //                   ),
// // // //                   const SizedBox(height: 20),
// // // //                   PhotoPicker(
// // // //                     selectedImage: shopVisitViewModel.selectedImage,
// // // //                     onTakePicture: shopVisitViewModel.takePicture,
// // // //                   ),
// // // //                   const SizedBox(height: 20),
// // // //                   // FeedbackSection(
// // // //                   //   feedBackController: feedBackController,
// // // //                   //   onChanged: (value) =>
// // // //                   //       shopVisitViewModel.setFeedBack(value),
// // // //                   // ),
// // // //                   Obx(() => CustomSwitch(
// // // //                     label: "GPS Enabled",
// // // //                     value: locationViewModel.isGPSEnabled.value,
// // // //                     onChanged: (value) async {
// // // //                       locationViewModel.isGPSEnabled.value = value;
// // // //                       if (value) {
// // // //                         await locationViewModel.saveCurrentLocation();
// // // //                       }
// // // //                       shopVisitViewModel.updateButtonReadiness();
// // // //                     },
// // // //                   )),
// // // //                   SizedBox(height: MediaQuery.of(context).size.height * 0.03),
// // // //                   Row(
// // // //                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
// // // //                     children: [
// // // //                       Obx(() {
// // // //                         bool isButtonDisabled = !shopVisitViewModel.isOnlyVisitButtonEnabled.value;
// // // //                         bool isLoading = shopVisitViewModel.isOnlyVisitLoading.value;
// // // //
// // // //                         return CustomButton(
// // // //                           textSize: fontSize,
// // // //                           iconSize: isTablet ? 22 : 18,
// // // //                           height: buttonHeight,
// // // //                           width: buttonWidth,
// // // //                           icon: Icons.arrow_back_ios_new_rounded,
// // // //                           iconColor: Colors.white,
// // // //                           iconPosition: IconPosition.left,
// // // //                           spacing: 4,
// // // //                           buttonText: isLoading
// // // //                               ? "Processing..."
// // // //                               : "Only Visit",
// // // //                           gradientColors: isButtonDisabled || isLoading
// // // //                               ? [Colors.grey, Colors.grey]
// // // //                               : [Colors.red, Colors.red],
// // // //                           onTap: isButtonDisabled
// // // //                               ? () {
// // // //                             String? errorMessage = shopVisitViewModel.getOnlyVisitErrorMessage();
// // // //                             if (errorMessage != null) {
// // // //                               Get.snackbar("Action Required", errorMessage,
// // // //                                   snackPosition: SnackPosition.BOTTOM,
// // // //                                   backgroundColor: Colors.red.shade700,
// // // //                                   colorText: Colors.white);
// // // //                             }
// // // //                           }
// // // //                               : () {
// // // //                             if (!isLoading) {
// // // //                               debugPrint("Only Visit tapped ✅ (Proceeding)");
// // // //                               shopVisitViewModel.saveFormNoOrder();
// // // //                             }
// // // //                           },
// // // //                         );
// // // //                       }),
// // // //
// // // //                       Obx(() {
// // // //                         bool isButtonDisabled = !shopVisitViewModel.isOrderButtonEnabled.value;
// // // //                         bool isLoading = shopVisitViewModel.isOrderFormLoading.value;
// // // //
// // // //                         return CustomButton(
// // // //                           textSize: fontSize,
// // // //                           iconSize: isTablet ? 22 : 18,
// // // //                           height: buttonHeight,
// // // //                           width: buttonWidth,
// // // //                           buttonText: isLoading
// // // //                               ? "Processing..."
// // // //                               : "Order Form",
// // // //                           icon: Icons.arrow_forward_ios_outlined,
// // // //                           iconColor: Colors.white,
// // // //                           iconPosition: IconPosition.right,
// // // //                           gradientColors: isButtonDisabled || isLoading
// // // //                               ? [Colors.grey, Colors.grey]
// // // //                               : [Colors.blue.shade900, Colors.blue],
// // // //                           onTap: isButtonDisabled
// // // //                               ? () {
// // // //                             String? errorMessage = shopVisitViewModel.getOrderFormErrorMessage();
// // // //                             if (errorMessage != null) {
// // // //                               Get.snackbar("Action Required", errorMessage,
// // // //                                   snackPosition: SnackPosition.BOTTOM,
// // // //                                   backgroundColor: Colors.red.shade400,
// // // //                                   colorText: Colors.white);
// // // //                             }
// // // //                           }
// // // //                               : () {
// // // //                             if (!isLoading) {
// // // //                               debugPrint("Order Form tapped ✅ (Proceeding)");
// // // //                               shopVisitViewModel.saveForm();
// // // //                             }
// // // //                           },
// // // //                         );
// // // //                       }),
// // // //                     ],
// // // //                   )
// // // //                 ],
// // // //               ),
// // // //             ),
// // // //           ),
// // // //         ),
// // // //       ),
// // // //     );
// // // //   }
// // // //
// // // //   AppBar _buildAppBar() {
// // // //     return AppBar(
// // // //       title: const Text(
// // // //         'Shop Visit',
// // // //         style: TextStyle(color: Colors.white, fontSize: 24),
// // // //       ),
// // // //       centerTitle: true,
// // // //       leading: IconButton(
// // // //         icon: const Icon(Icons.arrow_back, color: Colors.white),
// // // //         onPressed: () {
// // // //           Get.back(); // ✅ FIXED: Use Get.back() instead of Get.offAllNamed
// // // //         },
// // // //       ),
// // // //       actions: [
// // // //         IconButton(
// // // //           icon: const Icon(Icons.refresh, color: Colors.white),
// // // //           onPressed: () {
// // // //             shopVisitViewModel.fetchAllShopVisit();
// // // //             productsViewModel.fetchAllProductsModel();
// // // //           },
// // // //         ),
// // // //       ],
// // // //       backgroundColor: Colors.blue,
// // // //     );
// // // //   }
// // // //
// // // //   Widget _buildTextField({
// // // //     required String label,
// // // //     required IconData icon,
// // // //     required String initialValue,
// // // //     required String? Function(String?) validator,
// // // //     required Function(String) onChanged,
// // // //     TextInputType keyboardType = TextInputType.text,
// // // //     bool obscureText = false,
// // // //   }) {
// // // //     return CustomEditableMenuOption(
// // // //       readOnly: true,
// // // //       label: label,
// // // //       initialValue: initialValue,
// // // //       onChanged: onChanged,
// // // //       inputBorder: const UnderlineInputBorder(
// // // //         borderSide: BorderSide(color: Colors.blue, width: 1.0),
// // // //       ),
// // // //       iconColor: Colors.blue,
// // // //       useBoxShadow: false,
// // // //       icon: icon,
// // // //       validator: validator,
// // // //       keyboardType: keyboardType,
// // // //       obscureText: obscureText,
// // // //     );
// // // //   }
// // // // }
// // // //
// // // // class SectionHeader extends StatelessWidget {
// // // //   final String title;
// // // //
// // // //   const SectionHeader({required this.title, Key? key}) : super(key: key);
// // // //
// // // //   @override
// // // //   Widget build(BuildContext context) {
// // // //     return Align(
// // // //       alignment: Alignment.centerLeft,
// // // //       child: Text(
// // // //         title,
// // // //         style: Theme.of(context)
// // // //             .textTheme
// // // //             .titleLarge
// // // //             ?.copyWith(fontWeight: FontWeight.bold),
// // // //       ),
// // // //     );
// // // //   }
// // // // }
// // //
// // // import 'package:flutter/material.dart';
// // // import 'package:get/get.dart';
// // // import 'package:order_booking_app/ViewModels/ProductsViewModel.dart';
// // // import '../LocatioPoints/ravelTimeViewModel.dart';
// // // import '../ViewModels/location_view_model.dart';
// // // import '../ViewModels/shop_visit_details_view_model.dart';
// // // import '../ViewModels/shop_visit_view_model.dart';
// // // import 'Components/custom_button.dart';
// // // import 'Components/custom_dropdown.dart';
// // // import 'Components/custom_editable_menu_option.dart' hide IconPosition;
// // // import 'Components/custom_switch.dart';
// // // import 'ShopVisitScreenComponents/check_list_section.dart';
// // // import 'ShopVisitScreenComponents/feedback_section.dart';
// // // import 'ShopVisitScreenComponents/photo_picker.dart';
// // // import 'ShopVisitScreenComponents/product_search_card.dart';
// // //
// // // class ShopVisitScreen extends StatefulWidget {
// // //   const ShopVisitScreen({super.key});
// // //
// // //   @override
// // //   _StateShopVisitScreen createState() => _StateShopVisitScreen();
// // // }
// // //
// // // class _StateShopVisitScreen extends State<ShopVisitScreen> {
// // //   final ShopVisitViewModel shopVisitViewModel = Get.put(ShopVisitViewModel());
// // //   final ShopVisitDetailsViewModel shopVisitDetailsViewModel =
// // //   Get.put(ShopVisitDetailsViewModel());
// // //   final ProductsViewModel productsViewModel = Get.put(ProductsViewModel());
// // //   final LocationViewModel locationViewModel = Get.find<LocationViewModel>();
// // //   final feedBackController = TextEditingController();
// // //
// // //   @override
// // //   void initState() {
// // //     super.initState();
// // //     WidgetsBinding.instance.addPostFrameCallback((_) {
// // //       final travelTimeViewModel = Get.find<TravelTimeViewModel>();
// // //       travelTimeViewModel.setWorkingScreenStatus(true);
// // //       debugPrint("📍 [WORKING STATUS] Shop Visit Screen - Working time ACTIVE");
// // //     });
// // //
// // //     feedBackController.text = shopVisitViewModel.feedBack.value;
// // //     shopVisitViewModel.selectedShop.value = "";
// // //     shopVisitViewModel.selectedBrand.value = "";
// // //     shopVisitViewModel.fetchBrands();
// // //     shopVisitViewModel.fetchShops();
// // //     shopVisitViewModel.updateButtonReadiness();
// // //
// // //     ever(shopVisitViewModel.feedBack, (value) {
// // //       feedBackController.text = value;
// // //       feedBackController.selection = TextSelection.fromPosition(
// // //         TextPosition(offset: feedBackController.text.length),
// // //       );
// // //     });
// // //   }
// // //
// // //   @override
// // //   void dispose() {
// // //     final travelTimeViewModel = Get.find<TravelTimeViewModel>();
// // //     travelTimeViewModel.setWorkingScreenStatus(false);
// // //     debugPrint("📍 [WORKING STATUS] Shop Visit Screen - Working time INACTIVE");
// // //     super.dispose();
// // //   }
// // //
// // //   String? requiredDropdownValidator(String? value, String placeholder) {
// // //     if (value == null || value.isEmpty || value == placeholder) {
// // //       return null;
// // //     }
// // //     return null;
// // //   }
// // //
// // //   @override
// // //   Widget build(BuildContext context) {
// // //     final size = MediaQuery.of(context).size;
// // //     final width = size.width;
// // //     final isTablet = width > 600;
// // //     final bool isSmallScreen = width < 600;
// // //     final bool isLargeScreen = width >= 1200;
// // //     final double responsivePadding = isSmallScreen ? 16 : 24;
// // //
// // //     return Scaffold(
// // //       backgroundColor: const Color(0xFFF5F7FA),
// // //       appBar: AppBar(
// // //         elevation: 0,
// // //         title: Text(
// // //           'Shop Visit',
// // //           style: TextStyle(
// // //             fontSize: isSmallScreen ? 18 : 20,
// // //             fontWeight: FontWeight.w600,
// // //             color: Colors.white,
// // //             letterSpacing: 0.5,
// // //           ),
// // //         ),
// // //         centerTitle: true,
// // //         backgroundColor: const Color(0xFF2196F3),
// // //         iconTheme: const IconThemeData(color: Colors.white),
// // //         leading: IconButton(
// // //           icon: const Icon(Icons.arrow_back),
// // //           onPressed: () => Get.back(),
// // //         ),
// // //         actions: [
// // //           IconButton(
// // //             icon: const Icon(Icons.refresh),
// // //             onPressed: () {
// // //               shopVisitViewModel.fetchAllShopVisit();
// // //               productsViewModel.fetchAllProductsModel();
// // //             },
// // //           ),
// // //         ],
// // //       ),
// // //       body: LayoutBuilder(
// // //         builder: (context, constraints) {
// // //           return SingleChildScrollView(
// // //             physics: const BouncingScrollPhysics(),
// // //             child: Container(
// // //               constraints: BoxConstraints(
// // //                 minHeight: constraints.maxHeight,
// // //               ),
// // //               child: Column(
// // //                 children: [
// // //                   // Header Card with Icon
// // //                   Container(
// // //                     width: size.width,
// // //                     decoration: const BoxDecoration(
// // //                       gradient: LinearGradient(
// // //                         colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
// // //                         begin: Alignment.topLeft,
// // //                         end: Alignment.bottomRight,
// // //                       ),
// // //                     ),
// // //                     padding: EdgeInsets.symmetric(
// // //                       vertical: isSmallScreen ? 20 : 28,
// // //                       horizontal: responsivePadding,
// // //                     ),
// // //                     child: Column(
// // //                       children: [
// // //                         Container(
// // //                           padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
// // //                           decoration: BoxDecoration(
// // //                             color: Colors.white.withOpacity(0.2),
// // //                             shape: BoxShape.circle,
// // //                           ),
// // //                           child: Icon(
// // //                             Icons.store_mall_directory_rounded,
// // //                             size: isSmallScreen ? 42 : 52,
// // //                             color: Colors.white,
// // //                           ),
// // //                         ),
// // //                         const SizedBox(height: 12),
// // //                         Text(
// // //                           'Shop Visit Information',
// // //                           style: TextStyle(
// // //                             color: Colors.white,
// // //                             fontSize: isSmallScreen ? 15 : 17,
// // //                             fontWeight: FontWeight.w500,
// // //                           ),
// // //                         ),
// // //                       ],
// // //                     ),
// // //                   ),
// // //
// // //                   // Form Card
// // //                   Container(
// // //                     margin: EdgeInsets.all(responsivePadding),
// // //                     constraints: BoxConstraints(
// // //                       maxWidth: isLargeScreen ? 800 : double.infinity,
// // //                     ),
// // //                     width: double.infinity,
// // //                     child: Center(
// // //                       child: Container(
// // //                         width: isLargeScreen ? 800 : double.infinity,
// // //                         decoration: BoxDecoration(
// // //                           color: Colors.white,
// // //                           borderRadius:
// // //                           BorderRadius.circular(isSmallScreen ? 12 : 16),
// // //                           boxShadow: [
// // //                             BoxShadow(
// // //                               color: Colors.black.withOpacity(0.08),
// // //                               blurRadius: 20,
// // //                               offset: const Offset(0, 4),
// // //                             ),
// // //                           ],
// // //                         ),
// // //                         child: Form(
// // //                           key: shopVisitViewModel.formKey,
// // //                           child: Padding(
// // //                             padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
// // //                             child: Column(
// // //                               crossAxisAlignment: CrossAxisAlignment.start,
// // //                               children: [
// // //                                 // Shop Information Section
// // //                                 _buildSectionHeader(
// // //                                     'Shop Information', Icons.info_outline),
// // //                                 const SizedBox(height: 16),
// // //
// // //                                 Obx(
// // //                                       () => _buildDropdownCard(
// // //                                     label: "Brand",
// // //                                     icon: Icons.branding_watermark,
// // //                                     value: shopVisitViewModel
// // //                                         .selectedBrand.value.isNotEmpty
// // //                                         ? shopVisitViewModel.selectedBrand.value
// // //                                         : "Select a Brand",
// // //                                     onChanged: (value) async {
// // //                                       shopVisitDetailsViewModel.filteredRows
// // //                                           .refresh();
// // //                                       shopVisitViewModel.setBrand(value!);
// // //                                       shopVisitDetailsViewModel
// // //                                           .filterProductsByBrand(value);
// // //                                     },
// // //                                     items: shopVisitViewModel.brands
// // //                                         .where((brand) => brand != null)
// // //                                         .cast<String>()
// // //                                         .toList(),
// // //                                     validator: (value) =>
// // //                                         requiredDropdownValidator(
// // //                                             value, "Select a Brand"),
// // //                                   ),
// // //                                 ),
// // //
// // //                                 Obx(
// // //                                       () => _buildDropdownCard(
// // //                                     label: "Shop",
// // //                                     icon: Icons.store,
// // //                                     value: shopVisitViewModel
// // //                                         .selectedShop.value.isNotEmpty
// // //                                         ? shopVisitViewModel.selectedShop.value
// // //                                         : "Select a Shop",
// // //                                     onChanged: (value) {
// // //                                       shopVisitViewModel.setSelectedShop(value!);
// // //                                       debugPrint(
// // //                                           shopVisitViewModel.shop_address.value);
// // //                                       debugPrint(
// // //                                           shopVisitViewModel.city.value);
// // //                                     },
// // //                                     items: shopVisitViewModel.shops.value
// // //                                         .where((shop) => shop != null)
// // //                                         .cast<String>()
// // //                                         .toList(),
// // //                                     validator: (value) =>
// // //                                         requiredDropdownValidator(
// // //                                             value, "Select a Shop"),
// // //                                   ),
// // //                                 ),
// // //
// // //                                 Obx(() => _buildTextFieldCard(
// // //                                   label: "Shop Address",
// // //                                   icon: Icons.location_on,
// // //                                   initialValue:
// // //                                   shopVisitViewModel.shop_address.value,
// // //                                   validator: (value) => value == null ||
// // //                                       value.isEmpty
// // //                                       ? 'Please enter the shop address'
// // //                                       : null,
// // //                                   onChanged: (value) =>
// // //                                       shopVisitViewModel.setShopAddress(value),
// // //                                 )),
// // //
// // //                                 Obx(() => _buildTextFieldCard(
// // //                                   label: "Owner Name",
// // //                                   icon: Icons.person,
// // //                                   initialValue:
// // //                                   shopVisitViewModel.owner_name.value,
// // //                                   validator: (value) =>
// // //                                   value == null || value.isEmpty
// // //                                       ? 'Please enter owner name'
// // //                                       : null,
// // //                                   onChanged: (value) =>
// // //                                       shopVisitViewModel.setOwnerName(value),
// // //                                 )),
// // //
// // //                                 _buildTextFieldCard(
// // //                                   label: "Booker Name",
// // //                                   icon: Icons.person,
// // //                                   initialValue:
// // //                                   shopVisitViewModel.booker_name.value,
// // //                                   validator: (value) =>
// // //                                   value == null || value.isEmpty
// // //                                       ? 'Please enter the booker name'
// // //                                       : null,
// // //                                   onChanged: (value) => shopVisitViewModel
// // //                                       .booker_name.value = value,
// // //                                 ),
// // //
// // //                                 const SizedBox(height: 24),
// // //
// // //                                 // Stock Check Section
// // //                                 _buildSectionHeader(
// // //                                     'Stock Check', Icons.inventory),
// // //                                 const SizedBox(height: 16),
// // //
// // //                                 Container(
// // //                                   decoration: BoxDecoration(
// // //                                     borderRadius: BorderRadius.circular(
// // //                                         isSmallScreen ? 10 : 12),
// // //                                     border: Border.all(
// // //                                       color: const Color(0xFFE0E0E0),
// // //                                       width: 1,
// // //                                     ),
// // //                                     color: const Color(0xFFF8F9FA),
// // //                                   ),
// // //                                   child: ProductSearchCard(
// // //                                     filterData:
// // //                                     shopVisitDetailsViewModel.filterData,
// // //                                     rowsNotifier: shopVisitDetailsViewModel
// // //                                         .rowsNotifier,
// // //                                     filteredRows: shopVisitDetailsViewModel
// // //                                         .filteredRows,
// // //                                     shopVisitDetailsViewModel:
// // //                                     shopVisitDetailsViewModel,
// // //                                   ),
// // //                                 ),
// // //
// // //                                 const SizedBox(height: 24),
// // //
// // //                                 // Checklist Section
// // //                                 _buildSectionHeader(
// // //                                     'Checklist', Icons.checklist),
// // //                                 const SizedBox(height: 16),
// // //
// // //                                 Container(
// // //                                   decoration: BoxDecoration(
// // //                                     borderRadius: BorderRadius.circular(
// // //                                         isSmallScreen ? 10 : 12),
// // //                                     border: Border.all(
// // //                                       color: const Color(0xFFE0E0E0),
// // //                                       width: 1,
// // //                                     ),
// // //                                     color: const Color(0xFFF8F9FA),
// // //                                   ),
// // //                                   padding: const EdgeInsets.all(16),
// // //                                   child: ChecklistSection(
// // //                                     labels: shopVisitViewModel.checklistLabels,
// // //                                     checklistState:
// // //                                     shopVisitViewModel.checklistState,
// // //                                     onStateChanged: (index, value) {
// // //                                       shopVisitViewModel
// // //                                           .updateChecklistState(index, value);
// // //                                     },
// // //                                   ),
// // //                                 ),
// // //
// // //                                 const SizedBox(height: 24),
// // //
// // //                                 // Photo Section
// // //                                 _buildSectionHeader('Photos', Icons.photo),
// // //                                 const SizedBox(height: 16),
// // //
// // //                                 Container(
// // //                                   decoration: BoxDecoration(
// // //                                     borderRadius: BorderRadius.circular(
// // //                                         isSmallScreen ? 10 : 12),
// // //                                     border: Border.all(
// // //                                       color: const Color(0xFFE0E0E0),
// // //                                       width: 1,
// // //                                     ),
// // //                                     color: const Color(0xFFF8F9FA),
// // //                                   ),
// // //                                   padding: const EdgeInsets.all(16),
// // //                                   child: PhotoPicker(
// // //                                     selectedImage:
// // //                                     shopVisitViewModel.selectedImage,
// // //                                     onTakePicture:
// // //                                     shopVisitViewModel.takePicture,
// // //                                   ),
// // //                                 ),
// // //
// // //                                 const SizedBox(height: 24),
// // //
// // //                                 // Location Section
// // //                                 _buildSectionHeader(
// // //                                     'Location Settings', Icons.location_on),
// // //                                 const SizedBox(height: 16),
// // //
// // //                                 Container(
// // //                                   width: double.infinity,
// // //                                   padding: EdgeInsets.symmetric(
// // //                                     horizontal: isSmallScreen ? 0 : 8,
// // //                                   ),
// // //                                   child: Obx(() => CustomSwitch(
// // //                                     label: "GPS Enabled",
// // //                                     value: locationViewModel.isGPSEnabled.value,
// // //                                     onChanged: (value) async {
// // //                                       locationViewModel.isGPSEnabled.value =
// // //                                           value;
// // //                                       if (value) {
// // //                                         await locationViewModel
// // //                                             .saveCurrentLocation();
// // //                                       }
// // //                                       shopVisitViewModel.updateButtonReadiness();
// // //                                     },
// // //                                   )),
// // //                                 ),
// // //
// // //                                 SizedBox(height: isSmallScreen ? 24 : 32),
// // //
// // //                                 // Action Buttons
// // //                                 Container(
// // //                                   width: double.infinity,
// // //                                   child: Row(
// // //                                     mainAxisAlignment:
// // //                                     MainAxisAlignment.spaceEvenly,
// // //                                     children: [
// // //                                       Obx(() {
// // //                                         bool isButtonDisabled =
// // //                                         !shopVisitViewModel
// // //                                             .isOnlyVisitButtonEnabled.value;
// // //                                         bool isLoading = shopVisitViewModel
// // //                                             .isOnlyVisitLoading.value;
// // //
// // //                                         return Container(
// // //                                           width: isTablet
// // //                                               ? size.width * 0.3
// // //                                               : size.width * 0.4,
// // //                                           child: CustomButton(
// // //                                             buttonText: isLoading
// // //                                                 ? "Processing..."
// // //                                                 : "Only Visit",
// // //                                             icon:
// // //                                             Icons.arrow_back_ios_new_rounded,
// // //                                             iconPosition: IconPosition.left,
// // //                                             onTap: isButtonDisabled || isLoading
// // //                                                 ? null
// // //                                                 : () {
// // //                                               debugPrint(
// // //                                                   "Only Visit tapped ✅ (Proceeding)");
// // //                                               shopVisitViewModel
// // //                                                   .saveFormNoOrder();
// // //                                             },
// // //                                             gradientColors: isButtonDisabled ||
// // //                                                 isLoading
// // //                                                 ? const [
// // //                                               Color(0xFFBDBDBD),
// // //                                               Color(0xFF9E9E9E)
// // //                                             ]
// // //                                                 : const [
// // //                                               Color(0xFFEF5350),
// // //                                               Color(0xFFE53935)
// // //                                             ],
// // //                                           ),
// // //                                         );
// // //                                       }),
// // //                                       Obx(() {
// // //                                         bool isButtonDisabled =
// // //                                         !shopVisitViewModel
// // //                                             .isOrderButtonEnabled.value;
// // //                                         bool isLoading = shopVisitViewModel
// // //                                             .isOrderFormLoading.value;
// // //
// // //                                         return Container(
// // //                                           width: isTablet
// // //                                               ? size.width * 0.3
// // //                                               : size.width * 0.4,
// // //                                           child: CustomButton(
// // //                                             buttonText: isLoading
// // //                                                 ? "Processing..."
// // //                                                 : "Order Form",
// // //                                             icon: Icons
// // //                                                 .arrow_forward_ios_outlined,
// // //                                             iconPosition: IconPosition.right,
// // //                                             onTap: isButtonDisabled || isLoading
// // //                                                 ? null
// // //                                                 : () {
// // //                                               debugPrint(
// // //                                                   "Order Form tapped ✅ (Proceeding)");
// // //                                               shopVisitViewModel
// // //                                                   .saveForm();
// // //                                             },
// // //                                             gradientColors: isButtonDisabled ||
// // //                                                 isLoading
// // //                                                 ? const [
// // //                                               Color(0xFFBDBDBD),
// // //                                               Color(0xFF9E9E9E)
// // //                                             ]
// // //                                                 : const [
// // //                                               Color(0xFF2196F3),
// // //                                               Color(0xFF1976D2)
// // //                                             ],
// // //                                           ),
// // //                                         );
// // //                                       }),
// // //                                     ],
// // //                                   ),
// // //                                 ),
// // //                               ],
// // //                             ),
// // //                           ),
// // //                         ),
// // //                       ),
// // //                     ),
// // //                   ),
// // //                   SizedBox(height: responsivePadding),
// // //                 ],
// // //               ),
// // //             ),
// // //           );
// // //         },
// // //       ),
// // //     );
// // //   }
// // //
// // //   Widget _buildSectionHeader(String title, IconData icon) {
// // //     final isSmallScreen = MediaQuery.of(context).size.width < 600;
// // //     return Row(
// // //       children: [
// // //         Container(
// // //           padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
// // //           decoration: BoxDecoration(
// // //             color: const Color(0xFF2196F3).withOpacity(0.1),
// // //             borderRadius: BorderRadius.circular(8),
// // //           ),
// // //           child: Icon(
// // //             icon,
// // //             size: isSmallScreen ? 18 : 20,
// // //             color: const Color(0xFF2196F3),
// // //           ),
// // //         ),
// // //         SizedBox(width: isSmallScreen ? 8 : 12),
// // //         Expanded(
// // //           child: Text(
// // //             title,
// // //             style: TextStyle(
// // //               fontSize: isSmallScreen ? 15 : 16,
// // //               fontWeight: FontWeight.w600,
// // //               color: const Color(0xFF212121),
// // //               letterSpacing: 0.3,
// // //             ),
// // //           ),
// // //         ),
// // //       ],
// // //     );
// // //   }
// // //
// // //   Widget _buildTextFieldCard({
// // //     required String label,
// // //     required IconData icon,
// // //     required String initialValue,
// // //     required String? Function(String?) validator,
// // //     required Function(String) onChanged,
// // //     TextInputType keyboardType = TextInputType.text,
// // //     bool obscureText = false,
// // //   }) {
// // //     final isSmallScreen = MediaQuery.of(context).size.width < 600;
// // //     return Padding(
// // //       padding: const EdgeInsets.only(bottom: 16),
// // //       child: Column(
// // //         crossAxisAlignment: CrossAxisAlignment.start,
// // //         children: [
// // //           Text(
// // //             label,
// // //             style: TextStyle(
// // //               color: const Color(0xFF757575),
// // //               fontSize: isSmallScreen ? 13 : 14,
// // //               fontWeight: FontWeight.w500,
// // //             ),
// // //           ),
// // //           const SizedBox(height: 6),
// // //           TextFormField(
// // //             initialValue: initialValue,
// // //             decoration: InputDecoration(
// // //               prefixIcon: Icon(
// // //                 icon,
// // //                 color: const Color(0xFF2196F3),
// // //                 size: isSmallScreen ? 20 : 22,
// // //               ),
// // //               filled: true,
// // //               fillColor: const Color(0xFFF8F9FA),
// // //               border: OutlineInputBorder(
// // //                 borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
// // //                 borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
// // //               ),
// // //               enabledBorder: OutlineInputBorder(
// // //                 borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
// // //                 borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
// // //               ),
// // //               focusedBorder: OutlineInputBorder(
// // //                 borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
// // //                 borderSide:
// // //                 const BorderSide(color: Color(0xFF2196F3), width: 2),
// // //               ),
// // //               errorBorder: OutlineInputBorder(
// // //                 borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
// // //                 borderSide: const BorderSide(color: Color(0xFFEF5350), width: 1),
// // //               ),
// // //               focusedErrorBorder: OutlineInputBorder(
// // //                 borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
// // //                 borderSide: const BorderSide(color: Color(0xFFEF5350), width: 2),
// // //               ),
// // //               contentPadding: EdgeInsets.symmetric(
// // //                 horizontal: 16,
// // //                 vertical: isSmallScreen ? 14 : 16,
// // //               ),
// // //             ),
// // //             style: TextStyle(
// // //               fontSize: isSmallScreen ? 15 : 16,
// // //               fontWeight: FontWeight.w500,
// // //               color: const Color(0xFF212121),
// // //             ),
// // //             onChanged: onChanged,
// // //             keyboardType: keyboardType,
// // //             obscureText: obscureText,
// // //             validator: validator,
// // //             cursorColor: const Color(0xFF2196F3),
// // //           ),
// // //         ],
// // //       ),
// // //     );
// // //   }
// // //
// // //   Widget _buildDropdownCard({
// // //     required String label,
// // //     required IconData icon,
// // //     required String value,
// // //     required Function(String?) onChanged,
// // //     required List<String> items,
// // //     required String? Function(String?) validator,
// // //   }) {
// // //     final isSmallScreen = MediaQuery.of(context).size.width < 600;
// // //     return Padding(
// // //       padding: const EdgeInsets.only(bottom: 16),
// // //       child: Column(
// // //         crossAxisAlignment: CrossAxisAlignment.start,
// // //         children: [
// // //           Text(
// // //             label,
// // //             style: TextStyle(
// // //               color: const Color(0xFF757575),
// // //               fontSize: isSmallScreen ? 13 : 14,
// // //               fontWeight: FontWeight.w500,
// // //             ),
// // //           ),
// // //           const SizedBox(height: 6),
// // //           Container(
// // //             decoration: BoxDecoration(
// // //               borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
// // //               border: Border.all(
// // //                 color: const Color(0xFFE0E0E0),
// // //                 width: 1,
// // //               ),
// // //               color: const Color(0xFFF8F9FA),
// // //             ),
// // //             child: CustomDropdown(
// // //               label: label,
// // //               icon: icon,
// // //               items: items,
// // //               selectedValue: value,
// // //               onChanged: onChanged,
// // //               validator: validator,
// // //               useBoxShadow: false,
// // //               inputBorder: InputBorder.none,
// // //               iconSize: isSmallScreen ? 20 : 22,
// // //               contentPadding: 0,
// // //               iconColor: const Color(0xFF2196F3),
// // //               textStyle: TextStyle(
// // //                 fontSize: isSmallScreen ? 15 : 16,
// // //                 fontWeight: FontWeight.w500,
// // //                 color: const Color(0xFF424242),
// // //               ),
// // //             ),
// // //           ),
// // //         ],
// // //       ),
// // //     );
// // //   }
// // // }
// // //
// // // class SectionHeader extends StatelessWidget {
// // //   final String title;
// // //
// // //   const SectionHeader({required this.title, Key? key}) : super(key: key);
// // //
// // //   @override
// // //   Widget build(BuildContext context) {
// // //     return Align(
// // //       alignment: Alignment.centerLeft,
// // //       child: Text(
// // //         title,
// // //         style: Theme.of(context)
// // //             .textTheme
// // //             .titleLarge
// // //             ?.copyWith(fontWeight: FontWeight.bold),
// // //       ),
// // //     );
// // //   }
// // // }
// //
// // import 'package:flutter/material.dart';
// // import 'package:get/get.dart';
// // import 'package:order_booking_app/ViewModels/ProductsViewModel.dart';
// // import '../LocatioPoints/ravelTimeViewModel.dart';
// // import '../ViewModels/location_view_model.dart';
// // import '../ViewModels/shop_visit_details_view_model.dart';
// // import '../ViewModels/shop_visit_view_model.dart';
// // import 'Components/custom_button.dart';
// // import 'Components/custom_dropdown.dart';
// // import 'Components/custom_editable_menu_option.dart' hide IconPosition;
// // import 'Components/custom_switch.dart';
// // import 'ShopVisitScreenComponents/check_list_section.dart';
// // import 'ShopVisitScreenComponents/feedback_section.dart';
// // import 'ShopVisitScreenComponents/photo_picker.dart';
// // import 'ShopVisitScreenComponents/product_search_card.dart';
// //
// // class ShopVisitScreen extends StatefulWidget {
// //   const ShopVisitScreen({super.key});
// //
// //   @override
// //   _StateShopVisitScreen createState() => _StateShopVisitScreen();
// // }
// //
// // class _StateShopVisitScreen extends State<ShopVisitScreen> {
// //   final ShopVisitViewModel shopVisitViewModel = Get.put(ShopVisitViewModel());
// //   final ShopVisitDetailsViewModel shopVisitDetailsViewModel =
// //   Get.put(ShopVisitDetailsViewModel());
// //   final ProductsViewModel productsViewModel = Get.put(ProductsViewModel());
// //   final LocationViewModel locationViewModel = Get.find<LocationViewModel>();
// //   final feedBackController = TextEditingController();
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     WidgetsBinding.instance.addPostFrameCallback((_) {
// //       final travelTimeViewModel = Get.find<TravelTimeViewModel>();
// //       travelTimeViewModel.setWorkingScreenStatus(true);
// //       debugPrint("📍 [WORKING STATUS] Shop Visit Screen - Working time ACTIVE");
// //     });
// //
// //     feedBackController.text = shopVisitViewModel.feedBack.value;
// //     shopVisitViewModel.selectedShop.value = "";
// //     shopVisitViewModel.selectedBrand.value = "";
// //     shopVisitViewModel.fetchBrands();
// //     shopVisitViewModel.fetchShops();
// //     shopVisitViewModel.updateButtonReadiness();
// //
// //     ever(shopVisitViewModel.feedBack, (value) {
// //       feedBackController.text = value;
// //       feedBackController.selection = TextSelection.fromPosition(
// //         TextPosition(offset: feedBackController.text.length),
// //       );
// //     });
// //   }
// //
// //   @override
// //   void dispose() {
// //     final travelTimeViewModel = Get.find<TravelTimeViewModel>();
// //     travelTimeViewModel.setWorkingScreenStatus(false);
// //     debugPrint("📍 [WORKING STATUS] Shop Visit Screen - Working time INACTIVE");
// //     super.dispose();
// //   }
// //
// //   String? requiredDropdownValidator(String? value, String placeholder) {
// //     if (value == null || value.isEmpty || value == placeholder) {
// //       return null;
// //     }
// //     return null;
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final size = MediaQuery.of(context).size;
// //     final width = size.width;
// //     final bool isSmallScreen = width < 600;
// //     final bool isMediumScreen = width >= 600 && width < 1200;
// //     final bool isLargeScreen = width >= 1200;
// //     final double responsivePadding = isSmallScreen ? 16 : isMediumScreen ? 20 : 24;
// //
// //     return Scaffold(
// //       backgroundColor: const Color(0xFFF5F7FA),
// //       appBar: AppBar(
// //         elevation: 0,
// //         title: Text(
// //           'Shop Visit',
// //           style: TextStyle(
// //             fontSize: isSmallScreen ? 18 : isMediumScreen ? 20 : 22,
// //             fontWeight: FontWeight.w600,
// //             color: Colors.white,
// //             letterSpacing: 0.5,
// //           ),
// //         ),
// //         centerTitle: true,
// //         backgroundColor: const Color(0xFF2196F3),
// //         iconTheme: const IconThemeData(color: Colors.white),
// //         leading: IconButton(
// //           icon: const Icon(Icons.arrow_back),
// //           onPressed: () => Get.back(),
// //         ),
// //         actions: [
// //           IconButton(
// //             icon: const Icon(Icons.refresh),
// //             onPressed: () {
// //               shopVisitViewModel.fetchAllShopVisit();
// //               productsViewModel.fetchAllProductsModel();
// //             },
// //           ),
// //         ],
// //       ),
// //       body: LayoutBuilder(
// //         builder: (context, constraints) {
// //           return SingleChildScrollView(
// //             physics: const BouncingScrollPhysics(),
// //             child: Container(
// //               constraints: BoxConstraints(
// //                 minHeight: constraints.maxHeight,
// //               ),
// //               child: Column(
// //                 children: [
// //                   // Header Card with Icon
// //                   Container(
// //                     width: size.width,
// //                     decoration: const BoxDecoration(
// //                       gradient: LinearGradient(
// //                         colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
// //                         begin: Alignment.topLeft,
// //                         end: Alignment.bottomRight,
// //                       ),
// //                     ),
// //                     padding: EdgeInsets.symmetric(
// //                       vertical: isSmallScreen ? 20 : isMediumScreen ? 24 : 28,
// //                       horizontal: responsivePadding,
// //                     ),
// //                     child: Column(
// //                       children: [
// //                         Container(
// //                           padding: EdgeInsets.all(isSmallScreen ? 14 : isMediumScreen ? 16 : 18),
// //                           decoration: BoxDecoration(
// //                             color: Colors.white.withOpacity(0.2),
// //                             shape: BoxShape.circle,
// //                           ),
// //                           child: Icon(
// //                             Icons.store_mall_directory_rounded,
// //                             size: isSmallScreen ? 42 : isMediumScreen ? 48 : 52,
// //                             color: Colors.white,
// //                           ),
// //                         ),
// //                         const SizedBox(height: 12),
// //                         Text(
// //                           'Shop Visit Information',
// //                           style: TextStyle(
// //                             color: Colors.white,
// //                             fontSize: isSmallScreen ? 15 : isMediumScreen ? 16 : 17,
// //                             fontWeight: FontWeight.w500,
// //                           ),
// //                         ),
// //                       ],
// //                     ),
// //                   ),
// //
// //                   // Main Content Container
// //                   Container(
// //                     margin: EdgeInsets.all(responsivePadding),
// //                     constraints: BoxConstraints(
// //                       maxWidth: isLargeScreen ? 1000 : double.infinity,
// //                     ),
// //                     child: Center(
// //                       child: ConstrainedBox(
// //                         constraints: BoxConstraints(
// //                           maxWidth: isLargeScreen ? 1000 : 800,
// //                         ),
// //                         child: Container(
// //                           decoration: BoxDecoration(
// //                             color: Colors.white,
// //                             borderRadius: BorderRadius.circular(isSmallScreen ? 12 : isMediumScreen ? 14 : 16),
// //                             boxShadow: [
// //                               BoxShadow(
// //                                 color: Colors.black.withOpacity(0.08),
// //                                 blurRadius: 20,
// //                                 offset: const Offset(0, 4),
// //                               ),
// //                             ],
// //                           ),
// //                           child: _buildFormContent(context),
// //                         ),
// //                       ),
// //                     ),
// //                   ),
// //                   SizedBox(height: responsivePadding),
// //                 ],
// //               ),
// //             ),
// //           );
// //         },
// //       ),
// //     );
// //   }
// //
// //   Widget _buildFormContent(BuildContext context) {
// //     final size = MediaQuery.of(context).size;
// //     final width = size.width;
// //     final bool isSmallScreen = width < 600;
// //     final bool isMediumScreen = width >= 600 && width < 1200;
// //
// //     return Form(
// //       key: shopVisitViewModel.formKey,
// //       child: Padding(
// //         padding: EdgeInsets.all(isSmallScreen ? 16 : isMediumScreen ? 20 : 24),
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             // Shop Information Section
// //             _buildSectionHeader(context, 'Shop Information', Icons.info_outline),
// //             const SizedBox(height: 16),
// //
// //             // Responsive layout for form fields
// //             if (width >= 1200) ...[
// //               // Large screen: Two-column layout for form fields
// //               Row(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   Expanded(
// //                     child: Column(
// //                       children: [
// //                         _buildBrandDropdown(context),
// //                         const SizedBox(height: 16),
// //                         _buildShopDropdown(context),
// //                       ],
// //                     ),
// //                   ),
// //                   SizedBox(width: isMediumScreen ? 16 : 20),
// //                   Expanded(
// //                     child: Column(
// //                       children: [
// //                         _buildShopAddressField(context),
// //                         const SizedBox(height: 16),
// //                         _buildOwnerNameField(context),
// //                       ],
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //               const SizedBox(height: 16),
// //               _buildBookerNameField(context),
// //             ] else ...[
// //               // Small/Medium screen: Single column layout
// //               _buildBrandDropdown(context),
// //               const SizedBox(height: 16),
// //               _buildShopDropdown(context),
// //               const SizedBox(height: 16),
// //               _buildShopAddressField(context),
// //               const SizedBox(height: 16),
// //               _buildOwnerNameField(context),
// //               const SizedBox(height: 16),
// //               _buildBookerNameField(context),
// //             ],
// //
// //             const SizedBox(height: 24),
// //
// //             // Stock Check Section
// //             _buildSectionHeader(context, 'Stock Check', Icons.inventory),
// //             const SizedBox(height: 16),
// //
// //             Container(
// //               decoration: BoxDecoration(
// //                 borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
// //                 border: Border.all(
// //                   color: const Color(0xFFE0E0E0),
// //                   width: 1,
// //                 ),
// //                 color: const Color(0xFFF8F9FA),
// //               ),
// //               child: ProductSearchCard(
// //                 filterData: shopVisitDetailsViewModel.filterData,
// //                 rowsNotifier: shopVisitDetailsViewModel.rowsNotifier,
// //                 filteredRows: shopVisitDetailsViewModel.filteredRows,
// //                 shopVisitDetailsViewModel: shopVisitDetailsViewModel,
// //               ),
// //             ),
// //
// //             const SizedBox(height: 24),
// //
// //             // Checklist Section
// //             _buildSectionHeader(context, 'Checklist', Icons.checklist),
// //             const SizedBox(height: 16),
// //
// //             Container(
// //               decoration: BoxDecoration(
// //                 borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
// //                 border: Border.all(
// //                   color: const Color(0xFFE0E0E0),
// //                   width: 1,
// //                 ),
// //                 color: const Color(0xFFF8F9FA),
// //               ),
// //               padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
// //               child: ChecklistSection(
// //                 labels: shopVisitViewModel.checklistLabels,
// //                 checklistState: shopVisitViewModel.checklistState,
// //                 onStateChanged: (index, value) {
// //                   shopVisitViewModel.updateChecklistState(index, value);
// //                 },
// //               ),
// //             ),
// //
// //             const SizedBox(height: 24),
// //
// //             // Photo Section
// //             _buildSectionHeader(context, 'Photos', Icons.photo),
// //             const SizedBox(height: 16),
// //
// //             Container(
// //               decoration: BoxDecoration(
// //                 borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
// //                 border: Border.all(
// //                   color: const Color(0xFFE0E0E0),
// //                   width: 1,
// //                 ),
// //                 color: const Color(0xFFF8F9FA),
// //               ),
// //               padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
// //               child: PhotoPicker(
// //                 selectedImage: shopVisitViewModel.selectedImage,
// //                 onTakePicture: shopVisitViewModel.takePicture,
// //               ),
// //             ),
// //
// //             const SizedBox(height: 24),
// //
// //             // Location Section
// //             _buildSectionHeader(context, 'Location Settings', Icons.location_on),
// //             const SizedBox(height: 16),
// //
// //             Container(
// //               width: double.infinity,
// //               padding: EdgeInsets.symmetric(
// //                 horizontal: isSmallScreen ? 0 : 8,
// //               ),
// //               child: Obx(() => CustomSwitch(
// //                 label: "GPS Enabled",
// //                 value: locationViewModel.isGPSEnabled.value,
// //                 onChanged: (value) async {
// //                   locationViewModel.isGPSEnabled.value = value;
// //                   if (value) {
// //                     await locationViewModel.saveCurrentLocation();
// //                   }
// //                   shopVisitViewModel.updateButtonReadiness();
// //                 },
// //               )),
// //             ),
// //
// //             SizedBox(height: isSmallScreen ? 24 : 32),
// //
// //             // Action Buttons - Responsive layout
// //             _buildActionButtons(context),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //   Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
// //     final size = MediaQuery.of(context).size;
// //     final isSmallScreen = size.width < 600;
// //     final isMediumScreen = size.width >= 600 && size.width < 1200;
// //
// //     return Row(
// //       children: [
// //         Container(
// //           padding: EdgeInsets.all(isSmallScreen ? 6 : isMediumScreen ? 7 : 8),
// //           decoration: BoxDecoration(
// //             color: const Color(0xFF2196F3).withOpacity(0.1),
// //             borderRadius: BorderRadius.circular(8),
// //           ),
// //           child: Icon(
// //             icon,
// //             size: isSmallScreen ? 18 : isMediumScreen ? 19 : 20,
// //             color: const Color(0xFF2196F3),
// //           ),
// //         ),
// //         SizedBox(width: isSmallScreen ? 8 : isMediumScreen ? 10 : 12),
// //         Expanded(
// //           child: Text(
// //             title,
// //             style: TextStyle(
// //               fontSize: isSmallScreen ? 15 : isMediumScreen ? 15.5 : 16,
// //               fontWeight: FontWeight.w600,
// //               color: const Color(0xFF212121),
// //               letterSpacing: 0.3,
// //             ),
// //           ),
// //         ),
// //       ],
// //     );
// //   }
// //
// //   Widget _buildBrandDropdown(BuildContext context) {
// //     return Obx(
// //           () => _buildDropdownCard(
// //         context,
// //         label: "Brand",
// //         icon: Icons.branding_watermark,
// //         value: shopVisitViewModel.selectedBrand.value.isNotEmpty
// //             ? shopVisitViewModel.selectedBrand.value
// //             : "Select a Brand",
// //         onChanged: (value) async {
// //           shopVisitDetailsViewModel.filteredRows.refresh();
// //           shopVisitViewModel.setBrand(value!);
// //           shopVisitDetailsViewModel.filterProductsByBrand(value);
// //         },
// //         items: shopVisitViewModel.brands
// //             .where((brand) => brand != null)
// //             .cast<String>()
// //             .toList(),
// //         validator: (value) => requiredDropdownValidator(value, "Select a Brand"),
// //       ),
// //     );
// //   }
// //
// //   Widget _buildShopDropdown(BuildContext context) {
// //     return Obx(
// //           () => _buildDropdownCard(
// //         context,
// //         label: "Shop",
// //         icon: Icons.store,
// //         value: shopVisitViewModel.selectedShop.value.isNotEmpty
// //             ? shopVisitViewModel.selectedShop.value
// //             : "Select a Shop",
// //         onChanged: (value) {
// //           shopVisitViewModel.setSelectedShop(value!);
// //           debugPrint(shopVisitViewModel.shop_address.value);
// //           debugPrint(shopVisitViewModel.city.value);
// //         },
// //         items: shopVisitViewModel.shops.value
// //             .where((shop) => shop != null)
// //             .cast<String>()
// //             .toList(),
// //         validator: (value) => requiredDropdownValidator(value, "Select a Shop"),
// //       ),
// //     );
// //   }
// //
// //   Widget _buildShopAddressField(BuildContext context) {
// //     return Obx(() => _buildTextFieldCard(
// //       context,
// //       label: "Shop Address",
// //       icon: Icons.location_on,
// //       initialValue: shopVisitViewModel.shop_address.value,
// //       validator: (value) => value == null || value.isEmpty
// //           ? 'Please enter the shop address'
// //           : null,
// //       onChanged: (value) => shopVisitViewModel.setShopAddress(value),
// //     ));
// //   }
// //
// //   Widget _buildOwnerNameField(BuildContext context) {
// //     return Obx(() => _buildTextFieldCard(
// //       context,
// //       label: "Owner Name",
// //       icon: Icons.person,
// //       initialValue: shopVisitViewModel.owner_name.value,
// //       validator: (value) => value == null || value.isEmpty
// //           ? 'Please enter owner name'
// //           : null,
// //       onChanged: (value) => shopVisitViewModel.setOwnerName(value),
// //     ));
// //   }
// //
// //   Widget _buildBookerNameField(BuildContext context) {
// //     return _buildTextFieldCard(
// //       context,
// //       label: "Booker Name",
// //       icon: Icons.person,
// //       initialValue: shopVisitViewModel.booker_name.value,
// //       validator: (value) => value == null || value.isEmpty
// //           ? 'Please enter the booker name'
// //           : null,
// //       onChanged: (value) => shopVisitViewModel.booker_name.value = value,
// //     );
// //   }
// //
// //   Widget _buildActionButtons(BuildContext context) {
// //     final size = MediaQuery.of(context).size;
// //     final isSmallScreen = size.width < 600;
// //
// //     return Container(
// //       width: double.infinity,
// //       child: isSmallScreen
// //           ? Column(
// //         mainAxisAlignment: MainAxisAlignment.center,
// //         children: [
// //           _buildOnlyVisitButton(context),
// //           const SizedBox(height: 16),
// //           _buildOrderFormButton(context),
// //         ],
// //       )
// //           : Row(
// //         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
// //         children: [
// //           _buildOnlyVisitButton(context),
// //           _buildOrderFormButton(context),
// //         ],
// //       ),
// //     );
// //   }
// //
// //   Widget _buildOnlyVisitButton(BuildContext context) {
// //     final size = MediaQuery.of(context).size;
// //     final isSmallScreen = size.width < 600;
// //     final isMediumScreen = size.width >= 600 && size.width < 1200;
// //
// //     return Obx(() {
// //       bool isButtonDisabled = !shopVisitViewModel.isOnlyVisitButtonEnabled.value;
// //       bool isLoading = shopVisitViewModel.isOnlyVisitLoading.value;
// //
// //       return Container(
// //         width: isSmallScreen
// //             ? size.width * 0.8
// //             : isMediumScreen
// //             ? size.width * 0.35
// //             : size.width * 0.25,
// //         constraints: const BoxConstraints(
// //           maxWidth: 300,
// //           minWidth: 150,
// //         ),
// //         child: CustomButton(
// //           buttonText: isLoading ? "Processing..." : "Only Visit",
// //           icon: Icons.arrow_back_ios_new_rounded,
// //           iconPosition: IconPosition.left,
// //           onTap: isButtonDisabled || isLoading
// //               ? null
// //               : () {
// //             debugPrint("Only Visit tapped ✅ (Proceeding)");
// //             shopVisitViewModel.saveFormNoOrder();
// //           },
// //           gradientColors: isButtonDisabled || isLoading
// //               ? const [Color(0xFFBDBDBD), Color(0xFF9E9E9E)]
// //               : const [Color(0xFFEF5350), Color(0xFFE53935)],
// //         ),
// //       );
// //     });
// //   }
// //
// //   Widget _buildOrderFormButton(BuildContext context) {
// //     final size = MediaQuery.of(context).size;
// //     final isSmallScreen = size.width < 600;
// //     final isMediumScreen = size.width >= 600 && size.width < 1200;
// //
// //     return Obx(() {
// //       bool isButtonDisabled = !shopVisitViewModel.isOrderButtonEnabled.value;
// //       bool isLoading = shopVisitViewModel.isOrderFormLoading.value;
// //
// //       return Container(
// //         width: isSmallScreen
// //             ? size.width * 0.8
// //             : isMediumScreen
// //             ? size.width * 0.35
// //             : size.width * 0.25,
// //         constraints: const BoxConstraints(
// //           maxWidth: 300,
// //           minWidth: 150,
// //         ),
// //         child: CustomButton(
// //           buttonText: isLoading ? "Processing..." : "Order Form",
// //           icon: Icons.arrow_forward_ios_outlined,
// //           iconPosition: IconPosition.right,
// //           onTap: isButtonDisabled || isLoading
// //               ? null
// //               : () {
// //             debugPrint("Order Form tapped ✅ (Proceeding)");
// //             shopVisitViewModel.saveForm();
// //           },
// //           gradientColors: isButtonDisabled || isLoading
// //               ? const [Color(0xFFBDBDBD), Color(0xFF9E9E9E)]
// //               : const [Color(0xFF2196F3), Color(0xFF1976D2)],
// //         ),
// //       );
// //     });
// //   }
// //
// //   Widget _buildTextFieldCard(
// //       BuildContext context, {
// //         required String label,
// //         required IconData icon,
// //         required String initialValue,
// //         required String? Function(String?) validator,
// //         required Function(String) onChanged,
// //         TextInputType keyboardType = TextInputType.text,
// //         bool obscureText = false,
// //       }) {
// //     final size = MediaQuery.of(context).size;
// //     final isSmallScreen = size.width < 600;
// //     final isMediumScreen = size.width >= 600 && size.width < 1200;
// //
// //     return Padding(
// //       padding: const EdgeInsets.only(bottom: 16),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           Text(
// //             label,
// //             style: TextStyle(
// //               color: const Color(0xFF757575),
// //               fontSize: isSmallScreen ? 13 : isMediumScreen ? 13.5 : 14,
// //               fontWeight: FontWeight.w500,
// //             ),
// //           ),
// //           const SizedBox(height: 6),
// //           TextFormField(
// //             initialValue: initialValue,
// //             decoration: InputDecoration(
// //               prefixIcon: Icon(
// //                 icon,
// //                 color: const Color(0xFF2196F3),
// //                 size: isSmallScreen ? 20 : isMediumScreen ? 21 : 22,
// //               ),
// //               filled: true,
// //               fillColor: const Color(0xFFF8F9FA),
// //               border: OutlineInputBorder(
// //                 borderRadius: BorderRadius.circular(isSmallScreen ? 10 : isMediumScreen ? 11 : 12),
// //                 borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
// //               ),
// //               enabledBorder: OutlineInputBorder(
// //                 borderRadius: BorderRadius.circular(isSmallScreen ? 10 : isMediumScreen ? 11 : 12),
// //                 borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
// //               ),
// //               focusedBorder: OutlineInputBorder(
// //                 borderRadius: BorderRadius.circular(isSmallScreen ? 10 : isMediumScreen ? 11 : 12),
// //                 borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
// //               ),
// //               errorBorder: OutlineInputBorder(
// //                 borderRadius: BorderRadius.circular(isSmallScreen ? 10 : isMediumScreen ? 11 : 12),
// //                 borderSide: const BorderSide(color: Color(0xFFEF5350), width: 1),
// //               ),
// //               focusedErrorBorder: OutlineInputBorder(
// //                 borderRadius: BorderRadius.circular(isSmallScreen ? 10 : isMediumScreen ? 11 : 12),
// //                 borderSide: const BorderSide(color: Color(0xFFEF5350), width: 2),
// //               ),
// //               contentPadding: EdgeInsets.symmetric(
// //                 horizontal: 16,
// //                 vertical: isSmallScreen ? 14 : isMediumScreen ? 15 : 16,
// //               ),
// //             ),
// //             style: TextStyle(
// //               fontSize: isSmallScreen ? 15 : isMediumScreen ? 15.5 : 16,
// //               fontWeight: FontWeight.w500,
// //               color: const Color(0xFF212121),
// //             ),
// //             onChanged: onChanged,
// //             keyboardType: keyboardType,
// //             obscureText: obscureText,
// //             validator: validator,
// //             cursorColor: const Color(0xFF2196F3),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// //
// //   Widget _buildDropdownCard(
// //       BuildContext context, {
// //         required String label,
// //         required IconData icon,
// //         required String value,
// //         required Function(String?) onChanged,
// //         required List<String> items,
// //         required String? Function(String?) validator,
// //       }) {
// //     final size = MediaQuery.of(context).size;
// //     final isSmallScreen = size.width < 600;
// //     final isMediumScreen = size.width >= 600 && size.width < 1200;
// //
// //     return Padding(
// //       padding: const EdgeInsets.only(bottom: 16),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           Text(
// //             label,
// //             style: TextStyle(
// //               color: const Color(0xFF757575),
// //               fontSize: isSmallScreen ? 13 : isMediumScreen ? 13.5 : 14,
// //               fontWeight: FontWeight.w500,
// //             ),
// //           ),
// //           const SizedBox(height: 6),
// //           Container(
// //             decoration: BoxDecoration(
// //               borderRadius: BorderRadius.circular(isSmallScreen ? 10 : isMediumScreen ? 11 : 12),
// //               border: Border.all(
// //                 color: const Color(0xFFE0E0E0),
// //                 width: 1,
// //               ),
// //               color: const Color(0xFFF8F9FA),
// //             ),
// //             child: CustomDropdown(
// //               label: label,
// //               icon: icon,
// //               items: items,
// //               selectedValue: value,
// //               onChanged: onChanged,
// //               validator: validator,
// //               useBoxShadow: false,
// //               inputBorder: InputBorder.none,
// //               iconSize: isSmallScreen ? 20 : isMediumScreen ? 21 : 22,
// //               contentPadding: 0,
// //               iconColor: const Color(0xFF2196F3),
// //               textStyle: TextStyle(
// //                 fontSize: isSmallScreen ? 15 : isMediumScreen ? 15.5 : 16,
// //                 fontWeight: FontWeight.w500,
// //                 color: const Color(0xFF424242),
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
// //
// // class SectionHeader extends StatelessWidget {
// //   final String title;
// //
// //   const SectionHeader({required this.title, Key? key}) : super(key: key);
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final size = MediaQuery.of(context).size;
// //     final isSmallScreen = size.width < 600;
// //
// //     return Align(
// //       alignment: Alignment.centerLeft,
// //       child: Text(
// //         title,
// //         style: TextStyle(
// //           fontSize: isSmallScreen ? 18 : 20,
// //           fontWeight: FontWeight.bold,
// //           color: const Color(0xFF212121),
// //         ),
// //       ),
// //     );
// //   }
// // }
//
//
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:order_booking_app/ViewModels/ProductsViewModel.dart';
// import '../LocatioPoints/ravelTimeViewModel.dart';
// import '../ViewModels/location_view_model.dart';
// import '../ViewModels/shop_visit_details_view_model.dart';
// import '../ViewModels/shop_visit_view_model.dart';
// import 'Components/custom_button.dart';
// import 'Components/custom_dropdown.dart';
// import 'Components/custom_editable_menu_option.dart' hide IconPosition;
// import 'Components/custom_switch.dart';
// import 'ShopVisitScreenComponents/check_list_section.dart';
// import 'ShopVisitScreenComponents/feedback_section.dart';
// import 'ShopVisitScreenComponents/photo_picker.dart';
// import 'ShopVisitScreenComponents/product_search_card.dart';
//
// class ShopVisitScreen extends StatefulWidget {
//   const ShopVisitScreen({super.key});
//
//   @override
//   _StateShopVisitScreen createState() => _StateShopVisitScreen();
// }
//
// class _StateShopVisitScreen extends State<ShopVisitScreen> {
//   final ShopVisitViewModel shopVisitViewModel = Get.put(ShopVisitViewModel());
//   final ShopVisitDetailsViewModel shopVisitDetailsViewModel =
//   Get.put(ShopVisitDetailsViewModel());
//   final ProductsViewModel productsViewModel = Get.put(ProductsViewModel());
//   final LocationViewModel locationViewModel = Get.find<LocationViewModel>();
//   final feedBackController = TextEditingController();
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       final travelTimeViewModel = Get.find<TravelTimeViewModel>();
//       travelTimeViewModel.setWorkingScreenStatus(true);
//       debugPrint("📍 [WORKING STATUS] Shop Visit Screen - Working time ACTIVE");
//     });
//
//     feedBackController.text = shopVisitViewModel.feedBack.value;
//     shopVisitViewModel.selectedShop.value = "";
//     shopVisitViewModel.selectedBrand.value = "";
//     shopVisitViewModel.fetchBrands();
//     shopVisitViewModel.fetchShops();
//     shopVisitViewModel.updateButtonReadiness();
//
//     ever(shopVisitViewModel.feedBack, (value) {
//       feedBackController.text = value;
//       feedBackController.selection = TextSelection.fromPosition(
//         TextPosition(offset: feedBackController.text.length),
//       );
//     });
//   }
//
//   @override
//   void dispose() {
//     final travelTimeViewModel = Get.find<TravelTimeViewModel>();
//     travelTimeViewModel.setWorkingScreenStatus(false);
//     debugPrint("📍 [WORKING STATUS] Shop Visit Screen - Working time INACTIVE");
//     super.dispose();
//   }
//
//   String? requiredDropdownValidator(String? value, String placeholder) {
//     if (value == null || value.isEmpty || value == placeholder) {
//       return null;
//     }
//     return null;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final width = size.width;
//     final bool isSmallScreen = width < 600;
//     final bool isMediumScreen = width >= 600 && width < 1200;
//     final bool isLargeScreen = width >= 1200;
//     final double responsivePadding = isSmallScreen ? 16 : isMediumScreen ? 20 : 24;
//
//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F7FA),
//       appBar: AppBar(
//         elevation: 0,
//         title: Text(
//           'Shop Visit',
//           style: TextStyle(
//             fontSize: isSmallScreen ? 18 : isMediumScreen ? 20 : 22,
//             fontWeight: FontWeight.w600,
//             color: Colors.white,
//             letterSpacing: 0.5,
//           ),
//         ),
//         centerTitle: true,
//         backgroundColor: const Color(0xFF2196F3),
//         iconTheme: const IconThemeData(color: Colors.white),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () => Get.back(),
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             onPressed: () {
//               shopVisitViewModel.fetchAllShopVisit();
//               productsViewModel.fetchAllProductsModel();
//             },
//           ),
//         ],
//       ),
//       body: LayoutBuilder(
//         builder: (context, constraints) {
//           return SingleChildScrollView(
//             physics: const BouncingScrollPhysics(),
//             child: Container(
//               constraints: BoxConstraints(
//                 minHeight: constraints.maxHeight,
//               ),
//               child: Column(
//                 children: [
//                   // Header Card with Icon
//                   Container(
//                     width: size.width,
//                     decoration: const BoxDecoration(
//                       gradient: LinearGradient(
//                         colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                       ),
//                     ),
//                     padding: EdgeInsets.symmetric(
//                       vertical: isSmallScreen ? 20 : isMediumScreen ? 24 : 28,
//                       horizontal: responsivePadding,
//                     ),
//                     child: Column(
//                       children: [
//                         Container(
//                           padding: EdgeInsets.all(isSmallScreen ? 14 : isMediumScreen ? 16 : 18),
//                           decoration: BoxDecoration(
//                             color: Colors.white.withOpacity(0.2),
//                             shape: BoxShape.circle,
//                           ),
//                           child: Icon(
//                             Icons.store_mall_directory_rounded,
//                             size: isSmallScreen ? 42 : isMediumScreen ? 48 : 52,
//                             color: Colors.white,
//                           ),
//                         ),
//                         const SizedBox(height: 12),
//                         Text(
//                           'Shop Visit Information',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: isSmallScreen ? 15 : isMediumScreen ? 16 : 17,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   // Main Content Container
//                   Container(
//                     margin: EdgeInsets.all(responsivePadding),
//                     constraints: BoxConstraints(
//                       maxWidth: isLargeScreen ? 1000 : double.infinity,
//                     ),
//                     child: Center(
//                       child: ConstrainedBox(
//                         constraints: BoxConstraints(
//                           maxWidth: isLargeScreen ? 1000 : 800,
//                         ),
//                         child: Container(
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(isSmallScreen ? 12 : isMediumScreen ? 14 : 16),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black.withOpacity(0.08),
//                                 blurRadius: 20,
//                                 offset: const Offset(0, 4),
//                               ),
//                             ],
//                           ),
//                           child: _buildFormContent(context),
//                         ),
//                       ),
//                     ),
//                   ),
//                   SizedBox(height: responsivePadding),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _buildFormContent(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final width = size.width;
//     final bool isSmallScreen = width < 600;
//     final bool isMediumScreen = width >= 600 && width < 1200;
//
//     return Form(
//       key: shopVisitViewModel.formKey,
//       child: Padding(
//         padding: EdgeInsets.all(isSmallScreen ? 16 : isMediumScreen ? 20 : 24),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Shop Information Section
//             _buildSectionHeader(context, 'Shop Information', Icons.info_outline),
//             const SizedBox(height: 16),
//
//             // Responsive layout for form fields
//             if (width >= 1200) ...[
//               // Large screen: Two-column layout for form fields
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Expanded(
//                     child: Column(
//                       children: [
//                         _buildBrandDropdown(context),
//                         const SizedBox(height: 16),
//                         _buildShopDropdown(context),
//                       ],
//                     ),
//                   ),
//                   SizedBox(width: isMediumScreen ? 16 : 20),
//                   Expanded(
//                     child: Column(
//                       children: [
//                         _buildShopAddressField(context),
//                         const SizedBox(height: 16),
//                         _buildOwnerNameField(context),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 16),
//               _buildBookerNameField(context),
//             ] else ...[
//               // Small/Medium screen: Single column layout
//               _buildBrandDropdown(context),
//               const SizedBox(height: 16),
//               _buildShopDropdown(context),
//               const SizedBox(height: 16),
//               _buildShopAddressField(context),
//               const SizedBox(height: 16),
//               _buildOwnerNameField(context),
//               const SizedBox(height: 16),
//               _buildBookerNameField(context),
//             ],
//
//             const SizedBox(height: 24),
//
//             // Stock Check Section
//             _buildSectionHeader(context, 'Stock Check', Icons.inventory),
//             const SizedBox(height: 16),
//
//             Container(
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
//                 border: Border.all(
//                   color: const Color(0xFFE0E0E0),
//                   width: 1,
//                 ),
//                 color: const Color(0xFFF8F9FA),
//               ),
//               child: ProductSearchCard(
//                 filterData: shopVisitDetailsViewModel.filterData,
//                 rowsNotifier: shopVisitDetailsViewModel.rowsNotifier,
//                 filteredRows: shopVisitDetailsViewModel.filteredRows,
//                 shopVisitDetailsViewModel: shopVisitDetailsViewModel,
//               ),
//             ),
//
//             const SizedBox(height: 24),
//
//             // Checklist Section
//             _buildSectionHeader(context, 'Checklist', Icons.checklist),
//             const SizedBox(height: 16),
//
//             Container(
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
//                 border: Border.all(
//                   color: const Color(0xFFE0E0E0),
//                   width: 1,
//                 ),
//                 color: const Color(0xFFF8F9FA),
//               ),
//               padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
//               child: ChecklistSection(
//                 labels: shopVisitViewModel.checklistLabels,
//                 checklistState: shopVisitViewModel.checklistState,
//                 onStateChanged: (index, value) {
//                   shopVisitViewModel.updateChecklistState(index, value);
//                 },
//               ),
//             ),
//
//             const SizedBox(height: 24),
//
//             // Photo Section
//             _buildSectionHeader(context, 'Photos', Icons.photo),
//             const SizedBox(height: 16),
//
//             Container(
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
//                 border: Border.all(
//                   color: const Color(0xFFE0E0E0),
//                   width: 1,
//                 ),
//                 color: const Color(0xFFF8F9FA),
//               ),
//               padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
//               child: PhotoPicker(
//                 selectedImage: shopVisitViewModel.selectedImage,
//                 onTakePicture: shopVisitViewModel.takePicture,
//               ),
//             ),
//
//             const SizedBox(height: 24),
//
//             // Location Section
//             _buildSectionHeader(context, 'Location Settings', Icons.location_on),
//             const SizedBox(height: 16),
//
//             Container(
//               width: double.infinity,
//               padding: EdgeInsets.symmetric(
//                 horizontal: isSmallScreen ? 0 : 8,
//               ),
//               child: Obx(() => CustomSwitch(
//                 label: "GPS Enabled",
//                 value: locationViewModel.isGPSEnabled.value,
//                 onChanged: (value) async {
//                   locationViewModel.isGPSEnabled.value = value;
//                   if (value) {
//                     await locationViewModel.saveCurrentLocation();
//                   }
//                   shopVisitViewModel.updateButtonReadiness();
//                 },
//               )),
//             ),
//
//             SizedBox(height: isSmallScreen ? 24 : 32),
//
//             // Action Buttons - Responsive layout
//             _buildActionButtons(context),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
//     final size = MediaQuery.of(context).size;
//     final isSmallScreen = size.width < 600;
//     final isMediumScreen = size.width >= 600 && size.width < 1200;
//
//     return Row(
//       children: [
//         Container(
//           padding: EdgeInsets.all(isSmallScreen ? 6 : isMediumScreen ? 7 : 8),
//           decoration: BoxDecoration(
//             color: const Color(0xFF2196F3).withOpacity(0.1),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Icon(
//             icon,
//             size: isSmallScreen ? 18 : isMediumScreen ? 19 : 20,
//             color: const Color(0xFF2196F3),
//           ),
//         ),
//         SizedBox(width: isSmallScreen ? 8 : isMediumScreen ? 10 : 12),
//         Expanded(
//           child: Text(
//             title,
//             style: TextStyle(
//               fontSize: isSmallScreen ? 15 : isMediumScreen ? 15.5 : 16,
//               fontWeight: FontWeight.w600,
//               color: const Color(0xFF212121),
//               letterSpacing: 0.3,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildBrandDropdown(BuildContext context) {
//     return Obx(
//           () => _buildDropdownCard(
//         context,
//         label: "Brand",
//         icon: Icons.branding_watermark,
//         value: shopVisitViewModel.selectedBrand.value.isNotEmpty
//             ? shopVisitViewModel.selectedBrand.value
//             : "Select a Brand",
//         onChanged: (value) async {
//           shopVisitDetailsViewModel.filteredRows.refresh();
//           shopVisitViewModel.setBrand(value!);
//           shopVisitDetailsViewModel.filterProductsByBrand(value);
//         },
//         items: shopVisitViewModel.brands
//             .where((brand) => brand != null)
//             .cast<String>()
//             .toList(),
//         validator: (value) => requiredDropdownValidator(value, "Select a Brand"),
//       ),
//     );
//   }
//
//   Widget _buildShopDropdown(BuildContext context) {
//     return Obx(
//           () => _buildDropdownCard(
//         context,
//         label: "Shop",
//         icon: Icons.store,
//         value: shopVisitViewModel.selectedShop.value.isNotEmpty
//             ? shopVisitViewModel.selectedShop.value
//             : "Select a Shop",
//         onChanged: (value) {
//           shopVisitViewModel.setSelectedShop(value!);
//           // Shop address and owner name will be automatically fetched
//           // in the setSelectedShop method of ShopVisitViewModel
//         },
//         items: shopVisitViewModel.shops.value
//             .where((shop) => shop != null)
//             .cast<String>()
//             .toList(),
//         validator: (value) => requiredDropdownValidator(value, "Select a Shop"),
//       ),
//     );
//   }
//
//   Widget _buildShopAddressField(BuildContext context) {
//     return Obx(() => _buildReadOnlyTextFieldCard(
//       context,
//       label: "Shop Address",
//       icon: Icons.location_on,
//       value: shopVisitViewModel.shop_address.value,
//     ));
//   }
//
//   Widget _buildOwnerNameField(BuildContext context) {
//     return Obx(() => _buildReadOnlyTextFieldCard(
//       context,
//       label: "Owner Name",
//       icon: Icons.person,
//       value: shopVisitViewModel.owner_name.value,
//     ));
//   }
//
//   Widget _buildBookerNameField(BuildContext context) {
//     return _buildTextFieldCard(
//       context,
//       label: "Booker Name",
//       icon: Icons.person,
//       initialValue: shopVisitViewModel.booker_name.value,
//       validator: (value) => value == null || value.isEmpty
//           ? 'Please enter the booker name'
//           : null,
//       onChanged: (value) => shopVisitViewModel.booker_name.value = value,
//     );
//   }
//
//   Widget _buildActionButtons(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final isSmallScreen = size.width < 600;
//
//     return Container(
//       width: double.infinity,
//       child: isSmallScreen
//           ? Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           _buildOnlyVisitButton(context),
//           const SizedBox(height: 16),
//           _buildOrderFormButton(context),
//         ],
//       )
//           : Row(
//         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//         children: [
//           _buildOnlyVisitButton(context),
//           _buildOrderFormButton(context),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildOnlyVisitButton(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final isSmallScreen = size.width < 600;
//     final isMediumScreen = size.width >= 600 && size.width < 1200;
//
//     return Obx(() {
//       bool isButtonDisabled = !shopVisitViewModel.isOnlyVisitButtonEnabled.value;
//       bool isLoading = shopVisitViewModel.isOnlyVisitLoading.value;
//
//       return Container(
//         width: isSmallScreen
//             ? size.width * 0.8
//             : isMediumScreen
//             ? size.width * 0.35
//             : size.width * 0.25,
//         constraints: const BoxConstraints(
//           maxWidth: 300,
//           minWidth: 150,
//         ),
//         child: CustomButton(
//           buttonText: isLoading ? "Processing..." : "Only Visit",
//           icon: Icons.arrow_back_ios_new_rounded,
//           iconPosition: IconPosition.left,
//           onTap: isButtonDisabled || isLoading
//               ? null
//               : () {
//             debugPrint("Only Visit tapped ✅ (Proceeding)");
//             shopVisitViewModel.saveFormNoOrder();
//           },
//           gradientColors: isButtonDisabled || isLoading
//               ? const [Color(0xFFBDBDBD), Color(0xFF9E9E9E)]
//               : const [Color(0xFFEF5350), Color(0xFFE53935)],
//         ),
//       );
//     });
//   }
//
//   Widget _buildOrderFormButton(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final isSmallScreen = size.width < 600;
//     final isMediumScreen = size.width >= 600 && size.width < 1200;
//
//     return Obx(() {
//       bool isButtonDisabled = !shopVisitViewModel.isOrderButtonEnabled.value;
//       bool isLoading = shopVisitViewModel.isOrderFormLoading.value;
//
//       return Container(
//         width: isSmallScreen
//             ? size.width * 0.8
//             : isMediumScreen
//             ? size.width * 0.35
//             : size.width * 0.25,
//         constraints: const BoxConstraints(
//           maxWidth: 300,
//           minWidth: 150,
//         ),
//         child: CustomButton(
//           buttonText: isLoading ? "Processing..." : "Order Form",
//           icon: Icons.arrow_forward_ios_outlined,
//           iconPosition: IconPosition.right,
//           onTap: isButtonDisabled || isLoading
//               ? null
//               : () {
//             debugPrint("Order Form tapped ✅ (Proceeding)");
//             shopVisitViewModel.saveForm();
//           },
//           gradientColors: isButtonDisabled || isLoading
//               ? const [Color(0xFFBDBDBD), Color(0xFF9E9E9E)]
//               : const [Color(0xFF2196F3), Color(0xFF1976D2)],
//         ),
//       );
//     });
//   }
//
//   Widget _buildTextFieldCard(
//       BuildContext context, {
//         required String label,
//         required IconData icon,
//         required String initialValue,
//         required String? Function(String?) validator,
//         required Function(String) onChanged,
//         TextInputType keyboardType = TextInputType.text,
//         bool obscureText = false,
//       }) {
//     final size = MediaQuery.of(context).size;
//     final isSmallScreen = size.width < 600;
//     final isMediumScreen = size.width >= 600 && size.width < 1200;
//
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               color: const Color(0xFF757575),
//               fontSize: isSmallScreen ? 13 : isMediumScreen ? 13.5 : 14,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           const SizedBox(height: 6),
//           TextFormField(
//             initialValue: initialValue,
//             decoration: InputDecoration(
//               prefixIcon: Icon(
//                 icon,
//                 color: const Color(0xFF2196F3),
//                 size: isSmallScreen ? 20 : isMediumScreen ? 21 : 22,
//               ),
//               filled: true,
//               fillColor: const Color(0xFFF8F9FA),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(isSmallScreen ? 10 : isMediumScreen ? 11 : 12),
//                 borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
//               ),
//               enabledBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(isSmallScreen ? 10 : isMediumScreen ? 11 : 12),
//                 borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
//               ),
//               focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(isSmallScreen ? 10 : isMediumScreen ? 11 : 12),
//                 borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
//               ),
//               errorBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(isSmallScreen ? 10 : isMediumScreen ? 11 : 12),
//                 borderSide: const BorderSide(color: Color(0xFFEF5350), width: 1),
//               ),
//               focusedErrorBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(isSmallScreen ? 10 : isMediumScreen ? 11 : 12),
//                 borderSide: const BorderSide(color: Color(0xFFEF5350), width: 2),
//               ),
//               contentPadding: EdgeInsets.symmetric(
//                 horizontal: 16,
//                 vertical: isSmallScreen ? 14 : isMediumScreen ? 15 : 16,
//               ),
//             ),
//             style: TextStyle(
//               fontSize: isSmallScreen ? 15 : isMediumScreen ? 15.5 : 16,
//               fontWeight: FontWeight.w500,
//               color: const Color(0xFF212121),
//             ),
//             onChanged: onChanged,
//             keyboardType: keyboardType,
//             obscureText: obscureText,
//             validator: validator,
//             cursorColor: const Color(0xFF2196F3),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildReadOnlyTextFieldCard(
//       BuildContext context, {
//         required String label,
//         required IconData icon,
//         required String value,
//       }) {
//     final size = MediaQuery.of(context).size;
//     final isSmallScreen = size.width < 600;
//     final isMediumScreen = size.width >= 600 && size.width < 1200;
//
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               color: const Color(0xFF757575),
//               fontSize: isSmallScreen ? 13 : isMediumScreen ? 13.5 : 14,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           const SizedBox(height: 6),
//           Container(
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(isSmallScreen ? 10 : isMediumScreen ? 11 : 12),
//               border: Border.all(
//                 color: const Color(0xFFE0E0E0),
//                 width: 1,
//               ),
//               color: const Color(0xFFF5F5F5),
//             ),
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
//               child: Row(
//                 children: [
//                   Icon(
//                     icon,
//                     color: const Color(0xFF757575),
//                     size: isSmallScreen ? 20 : isMediumScreen ? 21 : 22,
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Text(
//                       value.isEmpty ? "Select a shop to see details" : value,
//                       style: TextStyle(
//                         fontSize: isSmallScreen ? 15 : isMediumScreen ? 15.5 : 16,
//                         fontWeight: FontWeight.w500,
//                         color: value.isEmpty ? const Color(0xFFBDBDBD) : const Color(0xFF212121),
//                       ),
//                     ),
//                   ),
//                   if (value.isNotEmpty)
//                     Icon(
//                       Icons.lock_outline,
//                       size: isSmallScreen ? 16 : 18,
//                       color: const Color(0xFF757575),
//                     ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDropdownCard(
//       BuildContext context, {
//         required String label,
//         required IconData icon,
//         required String value,
//         required Function(String?) onChanged,
//         required List<String> items,
//         required String? Function(String?) validator,
//       }) {
//     final size = MediaQuery.of(context).size;
//     final isSmallScreen = size.width < 600;
//     final isMediumScreen = size.width >= 600 && size.width < 1200;
//
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               color: const Color(0xFF757575),
//               fontSize: isSmallScreen ? 13 : isMediumScreen ? 13.5 : 14,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           const SizedBox(height: 6),
//           Container(
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(isSmallScreen ? 10 : isMediumScreen ? 11 : 12),
//               border: Border.all(
//                 color: const Color(0xFFE0E0E0),
//                 width: 1,
//               ),
//               color: const Color(0xFFF8F9FA),
//             ),
//             child: CustomDropdown(
//               label: label,
//               icon: icon,
//               items: items,
//               selectedValue: value,
//               onChanged: onChanged,
//               validator: validator,
//               useBoxShadow: false,
//               inputBorder: InputBorder.none,
//               iconSize: isSmallScreen ? 20 : isMediumScreen ? 21 : 22,
//               contentPadding: 0,
//               iconColor: const Color(0xFF2196F3),
//               textStyle: TextStyle(
//                 fontSize: isSmallScreen ? 15 : isMediumScreen ? 15.5 : 16,
//                 fontWeight: FontWeight.w500,
//                 color: const Color(0xFF424242),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class SectionHeader extends StatelessWidget {
//   final String title;
//
//   const SectionHeader({required this.title, Key? key}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final isSmallScreen = size.width < 600;
//
//     return Align(
//       alignment: Alignment.centerLeft,
//       child: Text(
//         title,
//         style: TextStyle(
//           fontSize: isSmallScreen ? 18 : 20,
//           fontWeight: FontWeight.bold,
//           color: const Color(0xFF212121),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:order_booking_app/ViewModels/ProductsViewModel.dart';
import '../ViewModels/location_view_model.dart';
import '../ViewModels/shop_visit_details_view_model.dart';
import '../ViewModels/shop_visit_view_model.dart';
import 'Components/custom_button.dart';
import 'Components/custom_dropdown.dart';
import 'Components/custom_switch.dart';
import 'ShopVisitScreenComponents/check_list_section.dart';
import 'ShopVisitScreenComponents/photo_picker.dart';
import 'ShopVisitScreenComponents/product_search_card.dart';

class ShopVisitScreen extends StatefulWidget {
  const ShopVisitScreen({super.key});

  @override
  _StateShopVisitScreen createState() => _StateShopVisitScreen();
}

class _StateShopVisitScreen extends State<ShopVisitScreen> {
  final ShopVisitViewModel shopVisitViewModel = Get.put(ShopVisitViewModel());
  final ShopVisitDetailsViewModel shopVisitDetailsViewModel =
  Get.put(ShopVisitDetailsViewModel());
  final ProductsViewModel productsViewModel = Get.put(ProductsViewModel());
  final LocationViewModel locationViewModel = Get.find<LocationViewModel>();

  // For responsive design
  bool get isSmallScreen => MediaQuery.of(context).size.width < 600;
  bool get isMediumScreen =>
      MediaQuery.of(context).size.width >= 600 &&
          MediaQuery.of(context).size.width < 1200;
  bool get isLargeScreen => MediaQuery.of(context).size.width >= 1200;
  double get responsivePadding => isSmallScreen ? 16 : 24;

  @override
  void initState() {
    super.initState();

    shopVisitViewModel.selectedShop.value = "";
    shopVisitViewModel.selectedBrand.value = "";
    shopVisitViewModel.fetchBrands();
    shopVisitViewModel.fetchShops();
    shopVisitViewModel.updateButtonReadiness();
  }


  String? requiredDropdownValidator(String? value, String placeholder) {
    if (value == null || value.isEmpty || value == placeholder) {
      return null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.blueGrey.shade50,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Shop Visit',
          style: TextStyle(
            fontSize: isSmallScreen ? 18 : 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueGrey,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              shopVisitViewModel.fetchAllShopVisit();
              productsViewModel.fetchAllProductsModel();
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Column(
                children: [
                  // Header Card with Icon
                  Container(
                    width: size.width,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blueGrey.shade700,
                          Colors.blueGrey.shade500,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 20 : 28,
                      horizontal: responsivePadding,
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.store_mall_directory_rounded,
                            size: isSmallScreen ? 42 : 52,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Shop Visit Information',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 15 : 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Form Card
                  Container(
                    margin: EdgeInsets.all(responsivePadding),
                    constraints: BoxConstraints(
                      maxWidth: isLargeScreen ? 800 : double.infinity,
                    ),
                    width: double.infinity,
                    child: Center(
                      child: Container(
                        width: isLargeScreen ? 800 : double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                          BorderRadius.circular(isSmallScreen ? 12 : 16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Form(
                          key: shopVisitViewModel.formKey,
                          child: Padding(
                            padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Shop Information Section
                                _buildSectionHeader(
                                    'Shop Information', Icons.info_outline),
                                const SizedBox(height: 16),

                                // Responsive layout for form fields
                                if (isLargeScreen)
                                  _buildTwoColumnLayout(
                                    children: [
                                      Expanded(
                                        child: Obx(() => _buildDropdownCard(
                                          label: "Brand",
                                          icon: Icons.branding_watermark,
                                          value: shopVisitViewModel
                                              .selectedBrand.value.isNotEmpty
                                              ? shopVisitViewModel
                                              .selectedBrand.value
                                              : "Select a Brand",
                                          onChanged: (value) async {
                                            shopVisitDetailsViewModel
                                                .filteredRows.refresh();
                                            shopVisitViewModel.setBrand(value!);
                                            shopVisitDetailsViewModel
                                                .filterProductsByBrand(value);
                                          },
                                          items: shopVisitViewModel.brands
                                              .where((brand) => brand != null)
                                              .cast<String>()
                                              .toList(),
                                          validator: (value) =>
                                              requiredDropdownValidator(
                                                  value, "Select a Brand"),
                                        )),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Obx(() => _buildDropdownCard(
                                          label: "Shop",
                                          icon: Icons.store,
                                          value: shopVisitViewModel
                                              .selectedShop.value.isNotEmpty
                                              ? shopVisitViewModel
                                              .selectedShop.value
                                              : "Select a Shop",
                                          onChanged: (value) {
                                            shopVisitViewModel
                                                .setSelectedShop(value!);
                                          },
                                          items: shopVisitViewModel.shops.value
                                              .where((shop) => shop != null)
                                              .cast<String>()
                                              .toList(),
                                          validator: (value) =>
                                              requiredDropdownValidator(
                                                  value, "Select a Shop"),
                                        )),
                                      ),
                                    ],
                                  )
                                else
                                  Column(
                                    children: [
                                      Obx(() => _buildDropdownCard(
                                        label: "Brand",
                                        icon: Icons.branding_watermark,
                                        value: shopVisitViewModel
                                            .selectedBrand.value.isNotEmpty
                                            ? shopVisitViewModel
                                            .selectedBrand.value
                                            : "Select a Brand",
                                        onChanged: (value) async {
                                          shopVisitDetailsViewModel.filteredRows
                                              .refresh();
                                          shopVisitViewModel.setBrand(value!);
                                          shopVisitDetailsViewModel
                                              .filterProductsByBrand(value);
                                        },
                                        items: shopVisitViewModel.brands
                                            .where((brand) => brand != null)
                                            .cast<String>()
                                            .toList(),
                                        validator: (value) =>
                                            requiredDropdownValidator(
                                                value, "Select a Brand"),
                                      )),
                                      Obx(() => _buildDropdownCard(
                                        label: "Shop",
                                        icon: Icons.store,
                                        value: shopVisitViewModel
                                            .selectedShop.value.isNotEmpty
                                            ? shopVisitViewModel
                                            .selectedShop.value
                                            : "Select a Shop",
                                        onChanged: (value) {
                                          shopVisitViewModel
                                              .setSelectedShop(value!);
                                        },
                                        items: shopVisitViewModel.shops.value
                                            .where((shop) => shop != null)
                                            .cast<String>()
                                            .toList(),
                                        validator: (value) =>
                                            requiredDropdownValidator(
                                                value, "Select a Shop"),
                                      )),
                                    ],
                                  ),

                                Obx(() => _buildReadOnlyTextFieldCard(
                                  label: "Shop Address",
                                  icon: Icons.location_on,
                                  value: shopVisitViewModel.shop_address.value,
                                )),

                                Obx(() => _buildReadOnlyTextFieldCard(
                                  label: "Owner Name",
                                  icon: Icons.person,
                                  value: shopVisitViewModel.owner_name.value,
                                )),

                                _buildTextFieldCard(
                                  label: "Booker Name",
                                  icon: Icons.person,
                                  initialValue:
                                  shopVisitViewModel.booker_name.value,
                                  validator: (value) => value == null ||
                                      value.isEmpty
                                      ? 'Please enter the booker name'
                                      : null,
                                  onChanged: (value) => shopVisitViewModel
                                      .booker_name.value = value,
                                ),

                                const SizedBox(height: 24),

                                // Stock Check Section
                                _buildSectionHeader(
                                    'Stock Check', Icons.inventory),
                                const SizedBox(height: 16),

                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                        isSmallScreen ? 10 : 12),
                                    border: Border.all(
                                      color: Colors.blueGrey.shade200,
                                      width: 1,
                                    ),
                                    color: Colors.blueGrey.shade50,
                                  ),
                                  child: ProductSearchCard(
                                    filterData:
                                    shopVisitDetailsViewModel.filterData,
                                    rowsNotifier:
                                    shopVisitDetailsViewModel.rowsNotifier,
                                    filteredRows: shopVisitDetailsViewModel
                                        .filteredRows,
                                    shopVisitDetailsViewModel:
                                    shopVisitDetailsViewModel,
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Checklist Section
                                _buildSectionHeader('Checklist', Icons.checklist),
                                const SizedBox(height: 16),

                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                        isSmallScreen ? 10 : 12),
                                    border: Border.all(
                                      color: Colors.blueGrey.shade200,
                                      width: 1,
                                    ),
                                    color: Colors.blueGrey.shade50,
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: ChecklistSection(
                                    labels: shopVisitViewModel.checklistLabels,
                                    checklistState:
                                    shopVisitViewModel.checklistState,
                                    onStateChanged: (index, value) {
                                      shopVisitViewModel
                                          .updateChecklistState(index, value);
                                    },
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Photo Section
                                _buildSectionHeader('Photos', Icons.photo),
                                const SizedBox(height: 16),

                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                        isSmallScreen ? 10 : 12),
                                    border: Border.all(
                                      color: Colors.blueGrey.shade200,
                                      width: 1,
                                    ),
                                    color: Colors.blueGrey.shade50,
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: PhotoPicker(
                                    selectedImage:
                                    shopVisitViewModel.selectedImage,
                                    onTakePicture:
                                    shopVisitViewModel.takePicture,
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Location Section
                                _buildSectionHeader(
                                    'Location Settings', Icons.location_on),
                                const SizedBox(height: 16),

                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 0 : 8,
                                  ),
                                  child: Obx(() => CustomSwitch(
                                    label: "GPS Enabled",
                                    value: locationViewModel.isGPSEnabled.value,
                                    onChanged: (value) async {
                                      locationViewModel.isGPSEnabled.value =
                                          value;
                                      if (value) {
                                        await locationViewModel
                                            .saveCurrentLocation();
                                      }
                                      shopVisitViewModel.updateButtonReadiness();
                                    },
                                  )),
                                ),

                                SizedBox(height: isSmallScreen ? 24 : 32),

                                // Action Buttons
                                Container(
                                  width: double.infinity,
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Obx(() {
                                        bool isButtonDisabled =
                                        !shopVisitViewModel
                                            .isOnlyVisitButtonEnabled.value;
                                        bool isLoading = shopVisitViewModel
                                            .isOnlyVisitLoading.value;

                                        return Container(
                                          width: isSmallScreen
                                              ? size.width * 0.4
                                              : size.width * 0.3,
                                          child: CustomButton(
                                            buttonText: isLoading
                                                ? "Processing..."
                                                : "Only Visit",
                                            icon: Icons
                                                .arrow_back_ios_new_rounded,
                                            iconPosition: IconPosition.left,
                                            onTap: isButtonDisabled || isLoading
                                                ? null
                                                : () {
                                              debugPrint(
                                                  "Only Visit tapped ✅ (Proceeding)");
                                              shopVisitViewModel
                                                  .saveFormNoOrder();
                                            },
                                            gradientColors: isButtonDisabled ||
                                                isLoading
                                                ? [
                                              Colors.grey.shade400,
                                              Colors.grey.shade600
                                            ]
                                                : [
                                              Colors.red,
                                              Colors.red.shade700
                                            ],
                                          ),
                                        );
                                      }),
                                      Obx(() {
                                        bool isButtonDisabled =
                                        !shopVisitViewModel
                                            .isOrderButtonEnabled.value;
                                        bool isLoading = shopVisitViewModel
                                            .isOrderFormLoading.value;

                                        return Container(
                                          width: isSmallScreen
                                              ? size.width * 0.4
                                              : size.width * 0.3,
                                          child: CustomButton(
                                            buttonText: isLoading
                                                ? "Processing..."
                                                : "Order Form",
                                            icon: Icons
                                                .arrow_forward_ios_outlined,
                                            iconPosition: IconPosition.right,
                                            onTap: isButtonDisabled || isLoading
                                                ? null
                                                : () {
                                              debugPrint(
                                                  "Order Form tapped ✅ (Proceeding)");
                                              shopVisitViewModel
                                                  .saveForm();
                                            },
                                            gradientColors: isButtonDisabled ||
                                                isLoading
                                                ? [
                                              Colors.grey.shade400,
                                              Colors.grey.shade600
                                            ]
                                                : [
                                              Colors.blueGrey,
                                              Colors.blueGrey.shade600
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: responsivePadding),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
          decoration: BoxDecoration(
            color: Colors.blueGrey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: isSmallScreen ? 18 : 20,
            color: Colors.blueGrey,
          ),
        ),
        SizedBox(width: isSmallScreen ? 8 : 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: isSmallScreen ? 15 : 16,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextFieldCard({
    required String label,
    required IconData icon,
    required String initialValue,
    required String? Function(String?) validator,
    required Function(String) onChanged,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.blueGrey.shade600,
              fontSize: isSmallScreen ? 13 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: initialValue,
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: Colors.blueGrey,
                size: isSmallScreen ? 20 : 22,
              ),
              filled: true,
              fillColor: Colors.blueGrey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                borderSide:
                BorderSide(color: Colors.blueGrey.shade200, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                borderSide:
                BorderSide(color: Colors.blueGrey.shade200, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                borderSide: BorderSide(color: Colors.blueGrey, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                borderSide: const BorderSide(color: Color(0xFFEF5350), width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                borderSide: const BorderSide(color: Color(0xFFEF5350), width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isSmallScreen ? 14 : 16,
              ),
            ),
            style: TextStyle(
              fontSize: isSmallScreen ? 15 : 16,
              fontWeight: FontWeight.w500,
              color: Colors.blueGrey.shade800,
            ),
            onChanged: onChanged,
            keyboardType: keyboardType,
            obscureText: obscureText,
            validator: validator,
            cursorColor: Colors.blueGrey,
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyTextFieldCard({
    required String label,
    required IconData icon,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.blueGrey.shade600,
              fontSize: isSmallScreen ? 13 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
              border: Border.all(
                color: Colors.blueGrey.shade200,
                width: 1,
              ),
              color: Colors.blueGrey.shade50,
            ),
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: Colors.blueGrey,
                    size: isSmallScreen ? 20 : 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      value.isEmpty ? "Select a shop to see details" : value,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 15 : 16,
                        fontWeight: FontWeight.w500,
                        color: value.isEmpty
                            ? Colors.blueGrey.shade300
                            : Colors.blueGrey.shade800,
                      ),
                    ),
                  ),
                  if (value.isNotEmpty)
                    Icon(
                      Icons.lock_outline,
                      size: isSmallScreen ? 16 : 18,
                      color: Colors.blueGrey,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownCard({
    required String label,
    required IconData icon,
    required String value,
    required Function(String?) onChanged,
    required List<String> items,
    required String? Function(String?) validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.blueGrey.shade600,
              fontSize: isSmallScreen ? 13 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
              border: Border.all(
                color: Colors.blueGrey.shade200,
                width: 1,
              ),
              color: Colors.blueGrey.shade50,
            ),
            child: CustomDropdown(
              label: label,
              icon: icon,
              items: items,
              selectedValue: value,
              onChanged: onChanged,
              validator: validator,
              useBoxShadow: false,
              inputBorder: InputBorder.none,
              iconSize: isSmallScreen ? 20 : 22,
              contentPadding: 0,
              iconColor: Colors.blueGrey,
              textStyle: TextStyle(
                fontSize: isSmallScreen ? 15 : 16,
                fontWeight: FontWeight.w500,
                color: Colors.blueGrey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoColumnLayout({required List<Widget> children}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}