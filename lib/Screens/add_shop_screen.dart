// // /
// // // lib/screens/add_shop_screen.dart
// // import 'package:flutter/material.dart';
// // import 'package:flutter/services.dart';
// // import 'package:get/get.dart';
// // import 'package:order_booking_app/Screens/Components/custom_switch.dart';
// // import 'package:order_booking_app/ViewModels/location_view_model.dart';
// // import '../LocatioPoints/ravelTimeViewModel.dart';
// // import '../ViewModels/add_shop_view_model.dart';
// // import 'Components/custom_button.dart';
// // import 'Components/custom_dropdown_second.dart';
// // import 'Components/validators.dart';
// //
// // class AddShopScreen extends StatefulWidget {
// //   const AddShopScreen({super.key});
// //
// //   @override
// //   State<AddShopScreen> createState() => _AddShopScreenState();
// // }
// //
// // class _AddShopScreenState extends State<AddShopScreen> {
// //   final AddShopViewModel _viewModel = Get.put(AddShopViewModel());
// //   final LocationViewModel locationViewModel = Get.put(LocationViewModel());
// //
// //   // For responsive design
// //   bool get isSmallScreen => MediaQuery.of(context).size.width < 600;
// //   bool get isMediumScreen =>
// //       MediaQuery.of(context).size.width >= 600 &&
// //           MediaQuery.of(context).size.width < 1200;
// //   bool get isLargeScreen => MediaQuery.of(context).size.width >= 1200;
// //   double get responsivePadding => isSmallScreen ? 16 : 24;
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     WidgetsBinding.instance.addPostFrameCallback((_) {
// //       final travelTimeViewModel = Get.find<TravelTimeViewModel>();
// //       travelTimeViewModel.setWorkingScreenStatus(true);
// //       debugPrint("📍 [WORKING STATUS] Add Shop Screen - Working time ACTIVE");
// //     });
// //   }
// //
// //   @override
// //   void dispose() {
// //     final travelTimeViewModel = Get.find<TravelTimeViewModel>();
// //     travelTimeViewModel.setWorkingScreenStatus(false);
// //     debugPrint("📍 [WORKING STATUS] Add Shop Screen - Working time INACTIVE");
// //     super.dispose();
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final size = MediaQuery.of(context).size;
// //
// //     return Scaffold(
// //       backgroundColor: const Color(0xFFF5F7FA),
// //       appBar: AppBar(
// //         elevation: 0,
// //         title: Text(
// //           'Add New Shop',
// //           style: TextStyle(
// //             fontSize: isSmallScreen ? 18 : 20,
// //             fontWeight: FontWeight.w600,
// //             color: Colors.white,
// //             letterSpacing: 0.5,
// //           ),
// //         ),
// //         centerTitle: true,
// //         backgroundColor: const Color(0xFF2196F3),
// //         iconTheme: const IconThemeData(color: Colors.white),
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
// //                       vertical: isSmallScreen ? 20 : 28,
// //                       horizontal: responsivePadding,
// //                     ),
// //                     child: Column(
// //                       children: [
// //                         Container(
// //                           padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
// //                           decoration: BoxDecoration(
// //                             color: Colors.white.withOpacity(0.2),
// //                             shape: BoxShape.circle,
// //                           ),
// //                           child: Icon(
// //                             Icons.store_mall_directory_rounded,
// //                             size: isSmallScreen ? 42 : 52,
// //                             color: Colors.white,
// //                           ),
// //                         ),
// //                         const SizedBox(height: 12),
// //                         Text(
// //                           'Shop Information',
// //                           style: TextStyle(
// //                             color: Colors.white,
// //                             fontSize: isSmallScreen ? 15 : 17,
// //                             fontWeight: FontWeight.w500,
// //                           ),
// //                         ),
// //                       ],
// //                     ),
// //                   ),
// //
// //                   // Form Card
// //                   Container(
// //                     margin: EdgeInsets.all(responsivePadding),
// //                     constraints: BoxConstraints(
// //                       maxWidth: isLargeScreen ? 800 : double.infinity,
// //                     ),
// //                     width: double.infinity,
// //                     child: Center(
// //                       child: Container(
// //                         width: isLargeScreen ? 800 : double.infinity,
// //                         decoration: BoxDecoration(
// //                           color: Colors.white,
// //                           borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
// //                           boxShadow: [
// //                             BoxShadow(
// //                               color: Colors.black.withOpacity(0.08),
// //                               blurRadius: 20,
// //                               offset: const Offset(0, 4),
// //                             ),
// //                           ],
// //                         ),
// //                         child: Form(
// //                           key: _viewModel.formKey,
// //                           child: Padding(
// //                             padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
// //                             child: Column(
// //                               crossAxisAlignment: CrossAxisAlignment.start,
// //                               children: [
// //                                 // Basic Details Section
// //                                 _buildSectionHeader('Basic Details', Icons.info_outline),
// //                                 const SizedBox(height: 16),
// //
// //                                 _buildTextField(
// //                                   label: "Shop Name",
// //                                   icon: Icons.storefront_rounded,
// //                                   onChanged: (value) =>
// //                                       _viewModel.setShopField('shop_name', value),
// //                                   validator: (value) => value == null || value.isEmpty
// //                                       ? "Please enter shop name"
// //                                       : null,
// //                                 ),
// //
// //                                 Obx(() => CustomDropdownSecond(
// //                                   borderColor: const Color(0xFFE0E0E0),
// //                                   iconColor: const Color(0xFF2196F3),
// //                                   label: "",
// //                                   useBoxShadow: false,
// //                                   icon: Icons.location_city_rounded,
// //                                   items: _viewModel.cities.value,
// //                                   selectedValue: _viewModel.selectedCity.value.isNotEmpty
// //                                       ? _viewModel.selectedCity.value
// //                                       : '',
// //                                   onChanged: (value) {
// //                                     if (value != null && value != '') {
// //                                       String selectedCity = value.toString();
// //                                       _viewModel.setShopField('city', selectedCity);
// //                                     }
// //                                   },
// //                                   validator: (value) =>
// //                                   value == null || value.isEmpty ? "Please select a City" : null,
// //                                   textStyle: TextStyle(
// //                                     fontSize: isSmallScreen ? 15 : 16,
// //                                     fontWeight: FontWeight.w500,
// //                                     color: const Color(0xFF424242),
// //                                   ),
// //                                   showSerialNumbers: true,
// //                                 )),
// //
// //                                 _buildTextField(
// //                                   label: "Shop Address",
// //                                   icon: Icons.place_rounded,
// //                                   onChanged: (value) =>
// //                                       _viewModel.setShopField('shop_address', value),
// //                                   validator: (value) => value == null || value.isEmpty
// //                                       ? "Please enter shop address"
// //                                       : null,
// //                                   maxLines: isSmallScreen ? 2 : 3,
// //                                 ),
// //
// //                                 const SizedBox(height: 24),
// //
// //                                 // Owner Details Section
// //                                 _buildSectionHeader('Owner Details', Icons.person_outline),
// //                                 const SizedBox(height: 16),
// //
// //                                 if (isLargeScreen)
// //                                   _buildTwoColumnLayout(
// //                                     children: [
// //                                       Expanded(
// //                                         child: _buildTextField(
// //                                           label: "Owner Name",
// //                                           icon: Icons.person_rounded,
// //                                           onChanged: (value) =>
// //                                               _viewModel.setShopField('owner_name', value),
// //                                           validator: (value) => value == null || value.isEmpty
// //                                               ? "Please enter owner name"
// //                                               : null,
// //                                         ),
// //                                       ),
// //                                       SizedBox(width: 16),
// //                                       Expanded(
// //                                         child: _buildTextField(
// //                                           label: "CNIC",
// //                                           icon: Icons.badge_rounded,
// //                                           keyboardType: TextInputType.number,
// //                                           inputFormatters: [CNICInputFormatter()],
// //                                           validator: Validators.validateCNIC,
// //                                           onChanged: (value) {
// //                                             _viewModel.setShopField('owner_cnic', value);
// //                                           },
// //                                         ),
// //                                       ),
// //                                     ],
// //                                   )
// //                                 else
// //                                   Column(
// //                                     children: [
// //                                       _buildTextField(
// //                                         label: "Owner Name",
// //                                         icon: Icons.person_rounded,
// //                                         onChanged: (value) =>
// //                                             _viewModel.setShopField('owner_name', value),
// //                                         validator: (value) => value == null || value.isEmpty
// //                                             ? "Please enter owner name"
// //                                             : null,
// //                                       ),
// //                                       _buildTextField(
// //                                         label: "CNIC",
// //                                         icon: Icons.badge_rounded,
// //                                         keyboardType: TextInputType.number,
// //                                         inputFormatters: [CNICInputFormatter()],
// //                                         validator: Validators.validateCNIC,
// //                                         onChanged: (value) {
// //                                           _viewModel.setShopField('owner_cnic', value);
// //                                         },
// //                                       ),
// //                                     ],
// //                                   ),
// //
// //                                 const SizedBox(height: 24),
// //
// //                                 // Contact Information Section
// //                                 _buildSectionHeader('Contact Information', Icons.phone_rounded),
// //                                 const SizedBox(height: 16),
// //
// //                                 if (isLargeScreen)
// //                                   _buildTwoColumnLayout(
// //                                     children: [
// //                                       Expanded(
// //                                         child: _buildTextField(
// //                                           label: "Phone Number",
// //                                           icon: Icons.phone_rounded,
// //                                           onChanged: (value) => _viewModel.setShopField('phone_no', value),
// //                                           validator: Validators.validatePhoneNumber,
// //                                           keyboardType: TextInputType.phone,
// //                                           inputFormatters: [PhoneNumberFormatter()],
// //                                         ),
// //                                       ),
// //                                       SizedBox(width: 16),
// //                                       Expanded(
// //                                         child: _buildTextField(
// //                                           label: "Alternative Phone Number",
// //                                           icon: Icons.phone_android_rounded,
// //                                           onChanged: (value) =>
// //                                               _viewModel.setShopField('alternative_phone_no', value),
// //                                           validator: Validators.validatePhoneNumber,
// //                                           keyboardType: TextInputType.phone,
// //                                           inputFormatters: [PhoneNumberFormatter()],
// //                                         ),
// //                                       ),
// //                                     ],
// //                                   )
// //                                 else
// //                                   Column(
// //                                     children: [
// //                                       _buildTextField(
// //                                         label: "Phone Number",
// //                                         icon: Icons.phone_rounded,
// //                                         onChanged: (value) => _viewModel.setShopField('phone_no', value),
// //                                         validator: Validators.validatePhoneNumber,
// //                                         keyboardType: TextInputType.phone,
// //                                         inputFormatters: [PhoneNumberFormatter()],
// //                                       ),
// //                                       _buildTextField(
// //                                         label: "Alternative Phone Number",
// //                                         icon: Icons.phone_android_rounded,
// //                                         onChanged: (value) =>
// //                                             _viewModel.setShopField('alternative_phone_no', value),
// //                                         validator: Validators.validatePhoneNumber,
// //                                         keyboardType: TextInputType.phone,
// //                                         inputFormatters: [PhoneNumberFormatter()],
// //                                       ),
// //                                     ],
// //                                   ),
// //
// //                                 const SizedBox(height: 24),
// //
// //                                 // Location Section
// //                                 _buildSectionHeader('Location', Icons.location_on_rounded),
// //                                 const SizedBox(height: 16),
// //
// //                                 Container(
// //                                   width: double.infinity,
// //                                   padding: EdgeInsets.symmetric(
// //                                     horizontal: isSmallScreen ? 0 : 8,
// //                                   ),
// //                                   child: Obx(() => CustomSwitch(
// //                                     label: "GPS Enabled",
// //                                     value: locationViewModel.isGPSEnabled.value,
// //                                     onChanged: (value) async {
// //                                       locationViewModel.isGPSEnabled.value = value;
// //                                       if (value) {
// //                                         await locationViewModel.saveCurrentLocation();
// //                                       }
// //                                       _viewModel.updateSaveButtonState();
// //                                     },
// //                                   )),
// //                                 ),
// //
// //                                 SizedBox(height: isSmallScreen ? 24 : 32),
// //
// //                                 // Save Button
// //                                 Container(
// //                                   width: double.infinity,
// //                                   padding: EdgeInsets.symmetric(
// //                                     horizontal: isLargeScreen ? 100 : 0,
// //                                   ),
// //                                   child: Obx(
// //                                         () => CustomButton(
// //                                       buttonText: "Save Shop",
// //                                       onTap: _viewModel.isFormReadyToSave.value
// //                                           ? _viewModel.saveForm
// //                                           : null,
// //                                       gradientColors: _viewModel.isFormReadyToSave.value
// //                                           ? const [Color(0xFF2196F3), Color(0xFF1976D2)]
// //                                           : const [Color(0xFFBDBDBD), Color(0xFF9E9E9E)],
// //                                     ),
// //                                   ),
// //                                 ),
// //                               ],
// //                             ),
// //                           ),
// //                         ),
// //                       ),
// //                     ),
// //                   ),
// //
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
// //   Widget _buildSectionHeader(String title, IconData icon) {
// //     return Row(
// //       children: [
// //         Container(
// //           padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
// //           decoration: BoxDecoration(
// //             color: const Color(0xFF2196F3).withOpacity(0.1),
// //             borderRadius: BorderRadius.circular(8),
// //           ),
// //           child: Icon(
// //             icon,
// //             size: isSmallScreen ? 18 : 20,
// //             color: const Color(0xFF2196F3),
// //           ),
// //         ),
// //         SizedBox(width: isSmallScreen ? 8 : 12),
// //         Expanded(
// //           child: Text(
// //             title,
// //             style: TextStyle(
// //               fontSize: isSmallScreen ? 15 : 16,
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
// //   Widget _buildTextField({
// //     required String label,
// //     required IconData icon,
// //     required ValueChanged<String> onChanged,
// //     required String? Function(String?) validator,
// //     TextInputType keyboardType = TextInputType.text,
// //     List<TextInputFormatter>? inputFormatters,
// //     int maxLines = 1,
// //   }) {
// //     return Padding(
// //       padding: EdgeInsets.only(bottom: 16),
// //       child: TextFormField(
// //         decoration: InputDecoration(
// //           labelText: label,
// //           labelStyle: TextStyle(
// //             color: const Color(0xFF757575),
// //             fontSize: isSmallScreen ? 13 : 14,
// //             fontWeight: FontWeight.w500,
// //           ),
// //           prefixIcon: Icon(
// //               icon,
// //               color: const Color(0xFF2196F3),
// //               size: isSmallScreen ? 20 : 22
// //           ),
// //           filled: true,
// //           fillColor: const Color(0xFFF8F9FA),
// //           border: OutlineInputBorder(
// //             borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
// //             borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
// //           ),
// //           enabledBorder: OutlineInputBorder(
// //             borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
// //             borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
// //           ),
// //           focusedBorder: OutlineInputBorder(
// //             borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
// //             borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
// //           ),
// //           errorBorder: OutlineInputBorder(
// //             borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
// //             borderSide: const BorderSide(color: Color(0xFFEF5350), width: 1),
// //           ),
// //           focusedErrorBorder: OutlineInputBorder(
// //             borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
// //             borderSide: const BorderSide(color: Color(0xFFEF5350), width: 2),
// //           ),
// //           contentPadding: EdgeInsets.symmetric(
// //             horizontal: 16,
// //             vertical: isSmallScreen ? 14 : 16,
// //           ),
// //         ),
// //         style: TextStyle(
// //           fontSize: isSmallScreen ? 15 : 16,
// //           fontWeight: FontWeight.w500,
// //           color: const Color(0xFF212121),
// //         ),
// //         onChanged: onChanged,
// //         keyboardType: keyboardType,
// //         inputFormatters: inputFormatters,
// //         validator: validator,
// //         maxLines: maxLines,
// //       ),
// //     );
// //   }
// //
// //   Widget _buildTwoColumnLayout({required List<Widget> children}) {
// //     return Row(
// //       crossAxisAlignment: CrossAxisAlignment.start,
// //       children: children,
// //     );
// //   }
// // }
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:order_booking_app/Screens/Components/custom_switch.dart';
// import 'package:order_booking_app/ViewModels/location_view_model.dart';
// import '../LocatioPoints/ravelTimeViewModel.dart';
// import '../ViewModels/add_shop_view_model.dart';
// import 'Components/custom_button.dart';
// import 'Components/custom_dropdown_second.dart';
// import 'Components/validators.dart';
//
// class AddShopScreen extends StatefulWidget {
//   const AddShopScreen({super.key});
//
//   @override
//   State<AddShopScreen> createState() => _AddShopScreenState();
// }
//
// class _AddShopScreenState extends State<AddShopScreen> {
//   final AddShopViewModel _viewModel = Get.put(AddShopViewModel());
//   final LocationViewModel locationViewModel = Get.put(LocationViewModel());
//
//   // For responsive design
//   bool get isSmallScreen => MediaQuery.of(context).size.width < 600;
//   bool get isMediumScreen =>
//       MediaQuery.of(context).size.width >= 600 &&
//           MediaQuery.of(context).size.width < 1200;
//   bool get isLargeScreen => MediaQuery.of(context).size.width >= 1200;
//   double get responsivePadding => isSmallScreen ? 16 : 24;
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       final travelTimeViewModel = Get.find<TravelTimeViewModel>();
//       travelTimeViewModel.setWorkingScreenStatus(true);
//       debugPrint("📍 [WORKING STATUS] Add Shop Screen - Working time ACTIVE");
//     });
//   }
//
//   @override
//   void dispose() {
//     final travelTimeViewModel = Get.find<TravelTimeViewModel>();
//     travelTimeViewModel.setWorkingScreenStatus(false);
//     debugPrint("📍 [WORKING STATUS] Add Shop Screen - Working time INACTIVE");
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//
//     return Scaffold(
//       backgroundColor: Colors.blueGrey.shade50, // Updated
//       appBar: AppBar(
//         elevation: 0,
//         title: Text(
//           'Add New Shop',
//           style: TextStyle(
//             fontSize: isSmallScreen ? 18 : 20,
//             fontWeight: FontWeight.w600,
//             color: Colors.white,
//             letterSpacing: 0.5,
//           ),
//         ),
//         centerTitle: true,
//         backgroundColor: Colors.blueGrey, // Updated
//         iconTheme: const IconThemeData(color: Colors.white),
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
//                     decoration: BoxDecoration(
//                       gradient: LinearGradient( // Updated
//                         colors: [
//                           Colors.blueGrey.shade700,
//                           Colors.blueGrey.shade500,
//                         ],
//                         begin: Alignment.topCenter,
//                         end: Alignment.bottomCenter,
//                       ),
//                     ),
//                     padding: EdgeInsets.symmetric(
//                       vertical: isSmallScreen ? 20 : 28,
//                       horizontal: responsivePadding,
//                     ),
//                     child: Column(
//                       children: [
//                         Container(
//                           padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
//                           decoration: BoxDecoration(
//                             color: Colors.white.withOpacity(0.2),
//                             shape: BoxShape.circle,
//                           ),
//                           child: Icon(
//                             Icons.store_mall_directory_rounded,
//                             size: isSmallScreen ? 42 : 52,
//                             color: Colors.white,
//                           ),
//                         ),
//                         const SizedBox(height: 12),
//                         Text(
//                           'Shop Information',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: isSmallScreen ? 15 : 17,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   // Form Card
//                   Container(
//                     margin: EdgeInsets.all(responsivePadding),
//                     constraints: BoxConstraints(
//                       maxWidth: isLargeScreen ? 800 : double.infinity,
//                     ),
//                     width: double.infinity,
//                     child: Center(
//                       child: Container(
//                         width: isLargeScreen ? 800 : double.infinity,
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.08),
//                               blurRadius: 20,
//                               offset: const Offset(0, 4),
//                             ),
//                           ],
//                         ),
//                         child: Form(
//                           key: _viewModel.formKey,
//                           child: Padding(
//                             padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 // Basic Details Section
//                                 _buildSectionHeader('Basic Details', Icons.info_outline),
//                                 const SizedBox(height: 16),
//
//                                 _buildTextField(
//                                   label: "Shop Name",
//                                   icon: Icons.storefront_rounded,
//                                   onChanged: (value) =>
//                                       _viewModel.setShopField('shop_name', value),
//                                   validator: (value) => value == null || value.isEmpty
//                                       ? "Please enter shop name"
//                                       : null,
//                                 ),
//
//                                 // Obx(() => CustomDropdownSecond(
//                                 //   borderColor: Colors.blueGrey.shade300, // Updated
//                                 //   iconColor: Colors.blueGrey, // Updated
//                                 //   label: "",
//                                 //   useBoxShadow: false,
//                                 //   icon: Icons.location_city_rounded,
//                                 //   items: _viewModel.cities.value,
//                                 //   selectedValue: _viewModel.selectedCity.value.isNotEmpty
//                                 //       ? _viewModel.selectedCity.value
//                                 //       : '',
//                                 //   onChanged: (value) {
//                                 //     if (value != null && value != '') {
//                                 //       String selectedCity = value.toString();
//                                 //       _viewModel.setShopField('city', selectedCity);
//                                 //     }
//                                 //   },
//                                 //   validator: (value) =>
//                                 //   value == null || value.isEmpty ? "Please select a City" : null,
//                                 //   textStyle: TextStyle(
//                                 //     fontSize: isSmallScreen ? 15 : 16,
//                                 //     fontWeight: FontWeight.w500,
//                                 //     color: Colors.blueGrey.shade800, // Updated
//                                 //   ),
//                                 //   showSerialNumbers: true,
//                                 // )),
//                                 Obx(() => CustomDropdownSecond(
//                                   key: ValueKey(_viewModel.cities.length), // 👈 yeh line ADD karo
//                                   borderColor: Colors.blueGrey.shade300,
//                                   iconColor: Colors.blueGrey,
//                                   label: "",
//                                   useBoxShadow: false,
//                                   icon: Icons.location_city_rounded,
//                                   items: _viewModel.cities.toList(), // 👈 .toList()
//                                   selectedValue: _viewModel.selectedCity.value.isNotEmpty
//                                       ? _viewModel.selectedCity.value
//                                       : '',
//                                   onChanged: (value) {
//                                     if (value != null && value != '') {
//                                       String selectedCity = value.toString();
//                                       _viewModel.setShopField('city', selectedCity);
//                                     }
//                                   },
//                                   validator: (value) =>
//                                   value == null || value.isEmpty ? "Please select a City" : null,
//                                   textStyle: TextStyle(
//                                     fontSize: isSmallScreen ? 15 : 16,
//                                     fontWeight: FontWeight.w500,
//                                     color: Colors.blueGrey.shade800,
//                                   ),
//                                   showSerialNumbers: true,
//                                 )),
//
//
//                                 _buildTextField(
//                                   label: "Shop Address",
//                                   icon: Icons.place_rounded,
//                                   onChanged: (value) =>
//                                       _viewModel.setShopField('shop_address', value),
//                                   validator: (value) => value == null || value.isEmpty
//                                       ? "Please enter shop address"
//                                       : null,
//                                   maxLines: isSmallScreen ? 2 : 3,
//                                 ),
//
//                                 const SizedBox(height: 24),
//
//                                 // Owner Details Section
//                                 _buildSectionHeader('Owner Details', Icons.person_outline),
//                                 const SizedBox(height: 16),
//
//                                 if (isLargeScreen)
//                                   _buildTwoColumnLayout(
//                                     children: [
//                                       Expanded(
//                                         child: _buildTextField(
//                                           label: "Owner Name",
//                                           icon: Icons.person_rounded,
//                                           onChanged: (value) =>
//                                               _viewModel.setShopField('owner_name', value),
//                                           validator: (value) => value == null || value.isEmpty
//                                               ? "Please enter owner name"
//                                               : null,
//                                         ),
//                                       ),
//                                       SizedBox(width: 16),
//                                       Expanded(
//                                         child: _buildTextField(
//                                           label: "CNIC",
//                                           icon: Icons.badge_rounded,
//                                           keyboardType: TextInputType.number,
//                                           inputFormatters: [CNICInputFormatter()],
//                                           validator: Validators.validateCNIC,
//                                           onChanged: (value) {
//                                             _viewModel.setShopField('owner_cnic', value);
//                                           },
//                                         ),
//                                       ),
//                                     ],
//                                   )
//                                 else
//                                   Column(
//                                     children: [
//                                       _buildTextField(
//                                         label: "Owner Name",
//                                         icon: Icons.person_rounded,
//                                         onChanged: (value) =>
//                                             _viewModel.setShopField('owner_name', value),
//                                         validator: (value) => value == null || value.isEmpty
//                                             ? "Please enter owner name"
//                                             : null,
//                                       ),
//                                       _buildTextField(
//                                         label: "CNIC",
//                                         icon: Icons.badge_rounded,
//                                         keyboardType: TextInputType.number,
//                                         inputFormatters: [CNICInputFormatter()],
//                                         validator: Validators.validateCNIC,
//                                         onChanged: (value) {
//                                           _viewModel.setShopField('owner_cnic', value);
//                                         },
//                                       ),
//                                     ],
//                                   ),
//
//                                 const SizedBox(height: 24),
//
//                                 // Contact Information Section
//                                 _buildSectionHeader('Contact Information', Icons.phone_rounded),
//                                 const SizedBox(height: 16),
//
//                                 if (isLargeScreen)
//                                   _buildTwoColumnLayout(
//                                     children: [
//                                       Expanded(
//                                         child: _buildTextField(
//                                           label: "Phone Number",
//                                           icon: Icons.phone_rounded,
//                                           onChanged: (value) => _viewModel.setShopField('phone_no', value),
//                                           validator: Validators.validatePhoneNumber,
//                                           keyboardType: TextInputType.phone,
//                                           inputFormatters: [PhoneNumberFormatter()],
//                                         ),
//                                       ),
//                                       SizedBox(width: 16),
//                                       Expanded(
//                                         child: _buildTextField(
//                                           label: "Alternative Phone Number",
//                                           icon: Icons.phone_android_rounded,
//                                           onChanged: (value) =>
//                                               _viewModel.setShopField('alternative_phone_no', value),
//                                           validator: Validators.validatePhoneNumber,
//                                           keyboardType: TextInputType.phone,
//                                           inputFormatters: [PhoneNumberFormatter()],
//                                         ),
//                                       ),
//                                     ],
//                                   )
//                                 else
//                                   Column(
//                                     children: [
//                                       _buildTextField(
//                                         label: "Phone Number",
//                                         icon: Icons.phone_rounded,
//                                         onChanged: (value) => _viewModel.setShopField('phone_no', value),
//                                         validator: Validators.validatePhoneNumber,
//                                         keyboardType: TextInputType.phone,
//                                         inputFormatters: [PhoneNumberFormatter()],
//                                       ),
//                                       _buildTextField(
//                                         label: "Alternative Phone Number",
//                                         icon: Icons.phone_android_rounded,
//                                         onChanged: (value) =>
//                                             _viewModel.setShopField('alternative_phone_no', value),
//                                         validator: Validators.validatePhoneNumber,
//                                         keyboardType: TextInputType.phone,
//                                         inputFormatters: [PhoneNumberFormatter()],
//                                       ),
//                                     ],
//                                   ),
//
//                                 const SizedBox(height: 24),
//
//                                 // Location Section
//                                 _buildSectionHeader('Location', Icons.location_on_rounded),
//                                 const SizedBox(height: 16),
//
//                                 Container(
//                                   width: double.infinity,
//                                   padding: EdgeInsets.symmetric(
//                                     horizontal: isSmallScreen ? 0 : 8,
//                                   ),
//                                   child: Obx(() => CustomSwitch(
//                                     label: "GPS Enabled",
//                                     value: locationViewModel.isGPSEnabled.value,
//                                     onChanged: (value) async {
//                                       locationViewModel.isGPSEnabled.value = value;
//                                       if (value) {
//                                         await locationViewModel.saveCurrentLocation();
//                                       }
//                                       _viewModel.updateSaveButtonState();
//                                     },
//                                   )),
//                                 ),
//
//                                 SizedBox(height: isSmallScreen ? 24 : 32),
//
//                                 // Save Button
//                                 Container(
//                                   width: double.infinity,
//                                   padding: EdgeInsets.symmetric(
//                                     horizontal: isLargeScreen ? 100 : 0,
//                                   ),
//                                   child: Obx(
//                                         () => CustomButton(
//                                       buttonText: "Save Shop",
//                                       onTap: _viewModel.isFormReadyToSave.value
//                                           ? _viewModel.saveForm
//                                           : null,
//                                       gradientColors: _viewModel.isFormReadyToSave.value
//                                           ? [Colors.blueGrey, Colors.blueGrey.shade600] // Updated
//                                           : [Colors.grey.shade400, Colors.grey.shade600], // Updated
//                                     ),
//                                   ),
//                                 ),
//                                 // Save Button
//                                 // Container(
//                                 //   width: double.infinity,
//                                 //   padding: EdgeInsets.symmetric(
//                                 //     horizontal: isLargeScreen ? 100 : 0,
//                                 //   ),
//                                 //   child: Obx(
//                                 //         () {
//                                 //       bool isButtonEnabled = _viewModel.isFormReadyToSave.value &&
//                                 //           !_viewModel.isLoading.value;
//                                 //
//                                 //       return CustomButton(
//                                 //         buttonText: _viewModel.isLoading.value ? "Saving..." : "Save Shop",
//                                 //         onTap: isButtonEnabled ? _viewModel.saveForm : null,
//                                 //         gradientColors: isButtonEnabled
//                                 //             ? [Colors.blueGrey, Colors.blueGrey.shade600]
//                                 //             : [Colors.grey.shade400, Colors.grey.shade600],
//                                 //       );
//                                 //     },
//                                 //   ),
//                                 // ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//
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
//   Widget _buildSectionHeader(String title, IconData icon) {
//     return Row(
//       children: [
//         Container(
//           padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
//           decoration: BoxDecoration(
//             color: Colors.blueGrey.withOpacity(0.1), // Updated
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Icon(
//             icon,
//             size: isSmallScreen ? 18 : 20,
//             color: Colors.blueGrey, // Updated
//           ),
//         ),
//         SizedBox(width: isSmallScreen ? 8 : 12),
//         Expanded(
//           child: Text(
//             title,
//             style: TextStyle(
//               fontSize: isSmallScreen ? 15 : 16,
//               fontWeight: FontWeight.w600,
//               color: Colors.blueGrey.shade800, // Updated
//               letterSpacing: 0.3,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildTextField({
//     required String label,
//     required IconData icon,
//     required ValueChanged<String> onChanged,
//     required String? Function(String?) validator,
//     TextInputType keyboardType = TextInputType.text,
//     List<TextInputFormatter>? inputFormatters,
//     int maxLines = 1,
//   }) {
//     return Padding(
//       padding: EdgeInsets.only(bottom: 16),
//       child: TextFormField(
//         decoration: InputDecoration(
//           labelText: label,
//           labelStyle: TextStyle(
//             color: Colors.blueGrey.shade600, // Updated
//             fontSize: isSmallScreen ? 13 : 14,
//             fontWeight: FontWeight.w500,
//           ),
//           prefixIcon: Icon(
//               icon,
//               color: Colors.blueGrey, // Updated
//               size: isSmallScreen ? 20 : 22
//           ),
//           filled: true,
//           fillColor: Colors.blueGrey.shade50, // Updated
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
//             borderSide: BorderSide(color: Colors.blueGrey.shade200, width: 1), // Updated
//           ),
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
//             borderSide: BorderSide(color: Colors.blueGrey.shade200, width: 1), // Updated
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
//             borderSide: BorderSide(color: Colors.blueGrey, width: 2), // Updated
//           ),
//           errorBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
//             borderSide: const BorderSide(color: Color(0xFFEF5350), width: 1),
//           ),
//           focusedErrorBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
//             borderSide: const BorderSide(color: Color(0xFFEF5350), width: 2),
//           ),
//           contentPadding: EdgeInsets.symmetric(
//             horizontal: 16,
//             vertical: isSmallScreen ? 14 : 16,
//           ),
//         ),
//         style: TextStyle(
//           fontSize: isSmallScreen ? 15 : 16,
//           fontWeight: FontWeight.w500,
//           color: Colors.blueGrey.shade800, // Updated
//         ),
//         onChanged: onChanged,
//         keyboardType: keyboardType,
//         inputFormatters: inputFormatters,
//         validator: validator,
//         maxLines: maxLines,
//       ),
//     );
//   }
//
//   Widget _buildTwoColumnLayout({required List<Widget> children}) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: children,
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:order_booking_app/Screens/Components/custom_switch.dart';
import 'package:order_booking_app/ViewModels/location_view_model.dart';
import '../ViewModels/add_shop_view_model.dart';
import 'Components/custom_button.dart';
import 'Components/custom_dropdown_second.dart';
import 'Components/validators.dart';

class AddShopScreen extends StatefulWidget {
  const AddShopScreen({super.key});

  @override
  State<AddShopScreen> createState() => _AddShopScreenState();
}

class _AddShopScreenState extends State<AddShopScreen> {
  final AddShopViewModel _viewModel = Get.put(AddShopViewModel());
  final LocationViewModel locationViewModel = Get.put(LocationViewModel());

  // For responsive design
  bool get isSmallScreen => MediaQuery.of(context).size.width < 600;
  bool get isMediumScreen =>
      MediaQuery.of(context).size.width >= 600 &&
          MediaQuery.of(context).size.width < 1200;
  bool get isLargeScreen => MediaQuery.of(context).size.width >= 1200;
  double get responsivePadding => isSmallScreen ? 16 : 24;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.blueGrey.shade50,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Add New Shop',
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
                          'Shop Information',
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
                          borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _viewModel.formKey,
                          child: Padding(
                            padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Basic Details Section
                                _buildSectionHeader('Basic Details', Icons.info_outline),
                                const SizedBox(height: 16),

                                _buildTextField(
                                  label: "Shop Name",
                                  icon: Icons.storefront_rounded,
                                  onChanged: (value) =>
                                      _viewModel.setShopField('shop_name', value),
                                  validator: (value) => value == null || value.isEmpty
                                      ? "Please enter shop name"
                                      : null,
                                ),

                                Obx(() => CustomDropdownSecond(
                                  key: ValueKey(_viewModel.cities.length),
                                  borderColor: Colors.blueGrey.shade300,
                                  iconColor: Colors.blueGrey,
                                  label: "",
                                  useBoxShadow: false,
                                  icon: Icons.location_city_rounded,
                                  items: _viewModel.cities.toList(),
                                  selectedValue: _viewModel.selectedCity.value.isNotEmpty
                                      ? _viewModel.selectedCity.value
                                      : '',
                                  onChanged: (value) {
                                    if (value != null && value != '') {
                                      String selectedCity = value.toString();
                                      _viewModel.setShopField('city', selectedCity);
                                    }
                                  },
                                  validator: (value) =>
                                  value == null || value.isEmpty ? "Please select a City" : null,
                                  textStyle: TextStyle(
                                    fontSize: isSmallScreen ? 15 : 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blueGrey.shade800,
                                  ),
                                  showSerialNumbers: true,
                                )),

                                _buildTextField(
                                  label: "Shop Address",
                                  icon: Icons.place_rounded,
                                  onChanged: (value) =>
                                      _viewModel.setShopField('shop_address', value),
                                  validator: (value) => value == null || value.isEmpty
                                      ? "Please enter shop address"
                                      : null,
                                  maxLines: isSmallScreen ? 2 : 3,
                                ),

                                const SizedBox(height: 24),

                                // Owner Details Section
                                _buildSectionHeader('Owner Details', Icons.person_outline),
                                const SizedBox(height: 16),

                                if (isLargeScreen)
                                  _buildTwoColumnLayout(
                                    children: [
                                      Expanded(
                                        child: _buildTextField(
                                          label: "Owner Name",
                                          icon: Icons.person_rounded,
                                          onChanged: (value) =>
                                              _viewModel.setShopField('owner_name', value),
                                          validator: (value) => value == null || value.isEmpty
                                              ? "Please enter owner name"
                                              : null,
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: _buildTextField(
                                          label: "CNIC",
                                          icon: Icons.badge_rounded,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [CNICInputFormatter()],
                                          validator: Validators.validateCNIC,
                                          onChanged: (value) {
                                            _viewModel.setShopField('owner_cnic', value);
                                          },
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Column(
                                    children: [
                                      _buildTextField(
                                        label: "Owner Name",
                                        icon: Icons.person_rounded,
                                        onChanged: (value) =>
                                            _viewModel.setShopField('owner_name', value),
                                        validator: (value) => value == null || value.isEmpty
                                            ? "Please enter owner name"
                                            : null,
                                      ),
                                      _buildTextField(
                                        label: "CNIC",
                                        icon: Icons.badge_rounded,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [CNICInputFormatter()],
                                        validator: Validators.validateCNIC,
                                        onChanged: (value) {
                                          _viewModel.setShopField('owner_cnic', value);
                                        },
                                      ),
                                    ],
                                  ),

                                const SizedBox(height: 24),

                                // Contact Information Section
                                _buildSectionHeader('Contact Information', Icons.phone_rounded),
                                const SizedBox(height: 16),

                                if (isLargeScreen)
                                  _buildTwoColumnLayout(
                                    children: [
                                      Expanded(
                                        child: _buildTextField(
                                          label: "Phone Number",
                                          icon: Icons.phone_rounded,
                                          onChanged: (value) => _viewModel.setShopField('phone_no', value),
                                          validator: Validators.validatePhoneNumber,
                                          keyboardType: TextInputType.phone,
                                          inputFormatters: [PhoneNumberFormatter()],
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: _buildTextField(
                                          label: "Alternative Phone Number",
                                          icon: Icons.phone_android_rounded,
                                          onChanged: (value) =>
                                              _viewModel.setShopField('alternative_phone_no', value),
                                          validator: Validators.validatePhoneNumber,
                                          keyboardType: TextInputType.phone,
                                          inputFormatters: [PhoneNumberFormatter()],
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Column(
                                    children: [
                                      _buildTextField(
                                        label: "Phone Number",
                                        icon: Icons.phone_rounded,
                                        onChanged: (value) => _viewModel.setShopField('phone_no', value),
                                        validator: Validators.validatePhoneNumber,
                                        keyboardType: TextInputType.phone,
                                        inputFormatters: [PhoneNumberFormatter()],
                                      ),
                                      _buildTextField(
                                        label: "Alternative Phone Number",
                                        icon: Icons.phone_android_rounded,
                                        onChanged: (value) =>
                                            _viewModel.setShopField('alternative_phone_no', value),
                                        validator: Validators.validatePhoneNumber,
                                        keyboardType: TextInputType.phone,
                                        inputFormatters: [PhoneNumberFormatter()],
                                      ),
                                    ],
                                  ),

                                const SizedBox(height: 24),

                                // Location Section
                                _buildSectionHeader('Location', Icons.location_on_rounded),
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
                                      locationViewModel.isGPSEnabled.value = value;
                                      if (value) {
                                        await locationViewModel.saveCurrentLocation();
                                      }
                                      _viewModel.updateSaveButtonState();
                                    },
                                  )),
                                ),

                                SizedBox(height: isSmallScreen ? 24 : 32),

                                // Save Button
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isLargeScreen ? 100 : 0,
                                  ),
                                  child: Obx(
                                        () => CustomButton(
                                      buttonText: "Save Shop",
                                      onTap: _viewModel.isFormReadyToSave.value
                                          ? _viewModel.saveForm
                                          : null,
                                      gradientColors: _viewModel.isFormReadyToSave.value
                                          ? [Colors.blueGrey, Colors.blueGrey.shade600]
                                          : [Colors.grey.shade400, Colors.grey.shade600],
                                    ),
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

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required ValueChanged<String> onChanged,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.blueGrey.shade600,
            fontSize: isSmallScreen ? 13 : 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
              icon,
              color: Colors.blueGrey,
              size: isSmallScreen ? 20 : 22
          ),
          filled: true,
          fillColor: Colors.blueGrey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
            borderSide: BorderSide(color: Colors.blueGrey.shade200, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
            borderSide: BorderSide(color: Colors.blueGrey.shade200, width: 1),
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
        inputFormatters: inputFormatters,
        validator: validator,
        maxLines: maxLines,
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