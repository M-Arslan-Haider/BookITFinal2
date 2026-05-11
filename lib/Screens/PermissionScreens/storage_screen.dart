// //
// //
// // import 'package:flutter/material.dart';
// // import 'package:get/get.dart';
// // import 'package:permission_handler/permission_handler.dart';
// // import '../../constants.dart' as AppColors;
// // import '../login_screen.dart';
// //
// // class StorageScreen extends StatelessWidget {
// //   const StorageScreen({Key? key}) : super(key: key);
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: Colors.white,
// //       body: Stack(
// //         children: [
// //           // Background design
// //           Positioned(
// //             top: -100,
// //             right: -50,
// //             child: Transform.rotate(
// //               angle: -0.2,
// //               child: Container(
// //                 width: 300,
// //                 height: 300,
// //                 decoration: BoxDecoration(
// //                   borderRadius: BorderRadius.circular(80),
// //                   gradient: LinearGradient(
// //                     colors: [
// //                       Colors.blueGrey.withOpacity(0.4),
// //                       Colors.blueGrey.withOpacity(0.1),
// //                     ],
// //                     begin: Alignment.topLeft,
// //                     end: Alignment.bottomRight,
// //                   ),
// //                 ),
// //               ),
// //             ),
// //           ),
// //           Positioned(
// //             top: 50,
// //             left: -30,
// //             child: Container(
// //               width: 120,
// //               height: 120,
// //               decoration: BoxDecoration(
// //                 shape: BoxShape.circle,
// //                 color: Colors.blueGrey.withOpacity(0.05),
// //               ),
// //             ),
// //           ),
// //
// //           SafeArea(
// //             child: Padding(
// //               padding: const EdgeInsets.symmetric(horizontal: 32),
// //               child: Column(
// //                 mainAxisAlignment: MainAxisAlignment.center,
// //                 children: [
// //                   Container(
// //                     padding: const EdgeInsets.all(32),
// //                     decoration: BoxDecoration(
// //                       color: Colors.white,
// //                       shape: BoxShape.circle,
// //                       boxShadow: [
// //                         BoxShadow(
// //                           color: Colors.black.withOpacity(0.05),
// //                           blurRadius: 20,
// //                           offset: const Offset(0, 10),
// //                         ),
// //                       ],
// //                     ),
// //                     child: const Icon(
// //                       Icons.storage_rounded,
// //                       size: 70,
// //                       color: Colors.blueGrey,
// //                     ),
// //                   ),
// //                   const SizedBox(height: 40),
// //                   Text(
// //                     "Storage Permission",
// //                     style: TextStyle(
// //                       fontSize: 26,
// //                       fontWeight: FontWeight.w800,
// //                       color: AppColors.darkText,
// //                       letterSpacing: -0.5,
// //                     ),
// //                     textAlign: TextAlign.center,
// //                   ),
// //                   const SizedBox(height: 10),
// //                   Text(
// //                     "Grant storage access to export location data and save files.\n\nFiles will be saved to:\n📁 Internal Storage/DCIM/LocationData/",
// //                     style: TextStyle(
// //                       fontSize: 16,
// //                       color: AppColors.subText,
// //                       height: 1.5,
// //                     ),
// //                     textAlign: TextAlign.center,
// //                   ),
// //                   const SizedBox(height: 60),
// //
// //                   SizedBox(
// //                     width: double.infinity,
// //                     height: 56,
// //                     child: ElevatedButton(
// //                       onPressed: () async {
// //                         debugPrint("Requesting storage permission...");
// //
// //                         // Request all storage permissions
// //                         Map<Permission, PermissionStatus> statuses = await [
// //                           Permission.storage,
// //                           Permission.manageExternalStorage,
// //                           Permission.photos,
// //                           Permission.videos,
// //                         ].request();
// //
// //                         bool allGranted = true;
// //                         statuses.forEach((permission, status) {
// //                           if (!status.isGranted) {
// //                             allGranted = false;
// //                             debugPrint("${permission.toString()} not granted: $status");
// //                           }
// //                         });
// //
// //                         // Also request MANAGE_EXTERNAL_STORAGE separately
// //                         if (await Permission.manageExternalStorage.isDenied) {
// //                           await Permission.manageExternalStorage.request();
// //                         }
// //
// //                         if (allGranted || await Permission.manageExternalStorage.isGranted) {
// //                           debugPrint("Permission granted, navigating to LoginScreen");
// //                           Get.offAll(() => const LoginScreen());
// //                         } else if (await Permission.manageExternalStorage.isPermanentlyDenied) {
// //                           debugPrint("Permission permanently denied, opening app settings");
// //                           Get.snackbar(
// //                             'Permission Required',
// //                             'Please enable "All files access" permission in app settings to export data.',
// //                             snackPosition: SnackPosition.BOTTOM,
// //                             backgroundColor: Colors.redAccent,
// //                             colorText: Colors.white,
// //                             duration: const Duration(seconds: 5),
// //                             mainButton: TextButton(
// //                               onPressed: () async {
// //                                 await openAppSettings();
// //                               },
// //                               child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
// //                             ),
// //                           );
// //                         } else {
// //                           debugPrint("Permission denied");
// //                           Get.snackbar(
// //                             'Permission Denied',
// //                             'Storage permission is needed to export location data.\n\nFiles will still be saved to app directory.',
// //                             snackPosition: SnackPosition.BOTTOM,
// //                             backgroundColor: Colors.orange,
// //                             colorText: Colors.white,
// //                             duration: const Duration(seconds: 5),
// //                           );
// //                           Get.offAll(() => const LoginScreen());
// //                         }
// //                       },
// //                       style: ElevatedButton.styleFrom(
// //                         backgroundColor: const Color(0xFF2D3436),
// //                         foregroundColor: Colors.white,
// //                         elevation: 4,
// //                         shadowColor: Colors.black26,
// //                         shape: RoundedRectangleBorder(
// //                           borderRadius: BorderRadius.circular(18),
// //                         ),
// //                       ),
// //                       child: const Text("ALLOW", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
//
//
// // // import 'package:flutter/material.dart';
// // // import 'package:get/get.dart';
// // // import 'package:permission_handler/permission_handler.dart';
// // // import '../login_screen.dart';
// // // import '../Components/WidgetsComponents/contect_widget.dart';
// // // import '../Components/WidgetsComponents/custom_button.dart';
// // // import '../Components/WidgetsComponents/header_widget.dart';
// // //
// // // class StorageScreen extends StatelessWidget {
// // //   const StorageScreen({Key? key}) : super(key: key);
// // //
// // //   @override
// // //   Widget build(BuildContext context) {
// // //     final screenHeight = MediaQuery.of(context).size.height;
// // //     final screenWidth = MediaQuery.of(context).size.width;
// // //
// // //     // Static content for the screen
// // //     const IconData icon = Icons.storage_rounded;
// // //     const String headerText = "Storage Permission";
// // //     const String descriptionText =
// // //         "Grant storage access to save and retrieve files during app usage.";
// // //
// // //     return Scaffold(
// // //       body: Stack(
// // //         children: [
// // //           Container(color: Colors.white),
// // //           // Header Widget
// // //           Positioned(
// // //             bottom: screenHeight * 0.6,
// // //             top: 0,
// // //             left: 0,
// // //             right: 0,
// // //             child: HeaderWidget(
// // //               icon: icon,
// // //               screenWidth: screenWidth,
// // //             ),
// // //           ),
// // //           // Content Widget
// // //           Positioned(
// // //             top: screenHeight * 0.4,
// // //             left: 0,
// // //             right: 0,
// // //             child: ContentWidget(
// // //               headerText: headerText,
// // //               descriptionText: descriptionText,
// // //               highlightedIndex: 6,
// // //             ),
// // //           ),
// // //           // Custom Button
// // //           Positioned(
// // //             bottom: screenHeight * 0.05,
// // //             left: screenWidth * 0.1,
// // //             right: screenWidth * 0.1,
// // //             child: CustomButton(
// // //               buttonText: 'ALLOW',
// // //               onPressed: () async {
// // //                 debugPrint("Requesting storage permission...");
// // //                 PermissionStatus storageStatus = await Permission.mediaLibrary.request();
// // //                 // PermissionStatus storageStatus = await Permission.manageExternalStorage.request();
// // //                 // PermissionStatus storageStatus = await Permission.storage.request();
// // //
// // //                 debugPrint("Permission status: $storageStatus");
// // //
// // //                 if (storageStatus.isGranted) {
// // //                   debugPrint("Permission granted, navigating to LoginScreen");
// // //                   Get.to(() => const LoginScreen());
// // //                 } else if (storageStatus.isDenied) {
// // //                   debugPrint("Permission permanently denied, opening app settings");
// // //                   Get.snackbar(
// // //                     'Permission Required',
// // //                     'Please enable storage permission in the app settings.',
// // //                     snackPosition: SnackPosition.BOTTOM,
// // //                     backgroundColor: Colors.redAccent,
// // //                     colorText: Colors.white,
// // //                     mainButton: TextButton(
// // //                       onPressed: () async {
// // //                         await openAppSettings();
// // //                       },
// // //                       child: Text('Open Settings'),
// // //                     ),
// // //                   );
// // //                 } else {
// // //                   debugPrint("Permission denied, showing snackbar");
// // //                   Get.snackbar(
// // //                     'Permission Denied',
// // //                     'You need to allow storage permission to proceed.',
// // //                     snackPosition: SnackPosition.BOTTOM,
// // //                     backgroundColor: Colors.redAccent,
// // //                     colorText: Colors.white,
// // //                   );
// // //                 }
// // //               },
// // //             )
// // //           ),
// // //         ],
// // //       ),
// // //     );
// // //   }
// // // }
// //
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../constants.dart' as AppColors;
import '../login_screen.dart';
import '../Components/WidgetsComponents/contect_widget.dart';
import '../Components/WidgetsComponents/custom_button.dart';
import '../Components/WidgetsComponents/header_widget.dart';

class StorageScreen extends StatelessWidget {
  const StorageScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
        // --- BACKGROUND DESIGN ---
        // Large abstract shape at the top
        Positioned(
        top: -100,
        right: -50,
        child: Transform.rotate(
          angle: -0.2, // Tilts the shape for that "pointed" look
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.stop_rounded,
                  size: 70,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                "Storage Permission",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              Text(
                "Grant storage access to save and retrieve files during app usage.",
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.subText,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              // const Text(
              //   "Storage Permission",
              //   style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
              //   textAlign: TextAlign.center,
              // ),
              // const SizedBox(height: 16),
              // const Text(
              //   "Grant storage access to save and retrieve files during app usage.",
              //   style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.45),
              //   textAlign: TextAlign.center,
              // ),
              const SizedBox(height: 60),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    debugPrint("Requesting storage permission...");
                    PermissionStatus storageStatus = await Permission.mediaLibrary.request();

                    debugPrint("Permission status: $storageStatus");

                    if (storageStatus.isGranted) {
                      debugPrint("Permission granted, navigating to LoginScreen");
                      Get.to(() => const LoginScreen());
                    } else {
                      debugPrint("Permission denied, showing snackbar");
                      Get.snackbar(
                        'Permission Required',
                        'Please enable storage permission in settings.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.redAccent,
                        colorText: Colors.white,
                        mainButton: TextButton(
                          onPressed: () async => await openAppSettings(),
                          child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D3436), // Darker for "Attack" design feel
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text("ALLOW", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () => Get.to(() => const LoginScreen()),
                child: const Text("", style: TextStyle(fontSize: 16, color: Color(0xFF1976D2), fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
      ]
      )
    );
  }
}

// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../../constants.dart' as AppColors;
// import '../login_screen.dart';
//
// /// StorageScreen
// ///
// /// Shown once at first-launch to request storage permission.
// ///
// /// Strategy:
// ///  • Android 11+ (SDK ≥ 30) → request MANAGE_EXTERNAL_STORAGE so we can
// ///    write to Downloads/LocationData/.
// ///  • Android 10 and below   → request READ_WRITE STORAGE.
// ///  • Either way, if the user taps "Skip / Later" we still navigate to
// ///    Login — the export will fall back to the app-scoped directory.
// class StorageScreen extends StatefulWidget {
//   const StorageScreen({Key? key}) : super(key: key);
//
//   @override
//   State<StorageScreen> createState() => _StorageScreenState();
// }
//
// class _StorageScreenState extends State<StorageScreen> {
//   bool _isRequesting = false;
//
//   // ── Android SDK version ──────────────────────────────────────────────────
//
//   Future<int> _getSdkVersion() async {
//     if (!Platform.isAndroid) return 0;
//     try {
//       final result = await Process.run('getprop', ['ro.build.version.sdk']);
//       return int.tryParse(result.stdout.toString().trim()) ?? 30;
//     } catch (_) {
//       return 30;
//     }
//   }
//
//   // ── Main permission request ──────────────────────────────────────────────
//
//   Future<void> _requestPermission() async {
//     if (_isRequesting) return;
//     setState(() => _isRequesting = true);
//
//     final sdkInt = await _getSdkVersion();
//     debugPrint('📱 [STORAGE SCREEN] Android SDK: $sdkInt');
//
//     if (sdkInt >= 30) {
//       await _requestAndroid11(sdkInt);
//     } else {
//       await _requestLegacy();
//     }
//
//     setState(() => _isRequesting = false);
//   }
//
//   /// Android 11+ — MANAGE_EXTERNAL_STORAGE
//   Future<void> _requestAndroid11(int sdkInt) async {
//     // On Android 13+ (SDK 33), MANAGE_EXTERNAL_STORAGE is granted via the
//     // "All files access" system settings page, not a runtime dialog.
//     // We must open settings directly.
//     if (sdkInt >= 33) {
//       final status = await Permission.manageExternalStorage.status;
//       if (!status.isGranted) {
//         // Tell the user what to do, then open settings.
//         _showSettingsDialog(
//           title: 'All Files Access Required',
//           body:
//           'To save location exports to your Downloads folder, please enable '
//               '"All files access" for this app in the next screen.',
//           onConfirm: () async {
//             await openAppSettings();
//             // After returning, navigate regardless (export will use fallback dir)
//             _goToLogin();
//           },
//           onSkip: _goToLogin,
//         );
//         return;
//       }
//       _goToLogin();
//       return;
//     }
//
//     // Android 11 / 12 — runtime dialog works for MANAGE_EXTERNAL_STORAGE
//     final status = await Permission.manageExternalStorage.request();
//     debugPrint('📱 [STORAGE SCREEN] manageExternalStorage: $status');
//
//     if (status.isGranted) {
//       _showSnackAndGo(
//         'Permission Granted',
//         'Location exports will be saved to Downloads/LocationData/',
//         Colors.green,
//       );
//     } else if (status.isPermanentlyDenied) {
//       _showSettingsDialog(
//         title: 'Permission Needed',
//         body:
//         'Storage permission was permanently denied. Please enable "All files '
//             'access" in App Settings to export to Downloads.',
//         onConfirm: () async {
//           await openAppSettings();
//           _goToLogin();
//         },
//         onSkip: _goToLogin,
//       );
//     } else {
//       // Denied but not permanent — continue with fallback
//       _showSnackAndGo(
//         'Permission Skipped',
//         'Exports will be saved to app internal storage instead.',
//         Colors.orange,
//       );
//     }
//   }
//
//   /// Android 10 and below — READ_WRITE_EXTERNAL_STORAGE
//   Future<void> _requestLegacy() async {
//     final statuses = await [
//       Permission.storage,
//     ].request();
//
//     final storageStatus = statuses[Permission.storage]!;
//     debugPrint('📱 [STORAGE SCREEN] storage: $storageStatus');
//
//     if (storageStatus.isGranted) {
//       _showSnackAndGo(
//         'Permission Granted',
//         'Location exports will be saved to Downloads/LocationData/',
//         Colors.green,
//       );
//     } else if (storageStatus.isPermanentlyDenied) {
//       _showSettingsDialog(
//         title: 'Permission Needed',
//         body: 'Storage permission was permanently denied. Open App Settings → '
//             'Permissions → Storage → Allow.',
//         onConfirm: () async {
//           await openAppSettings();
//           _goToLogin();
//         },
//         onSkip: _goToLogin,
//       );
//     } else {
//       _showSnackAndGo(
//         'Permission Denied',
//         'Exports will be saved to app internal storage.',
//         Colors.orange,
//       );
//     }
//   }
//
//   // ── Helpers ──────────────────────────────────────────────────────────────
//
//   void _goToLogin() => Get.offAll(() => const LoginScreen());
//
//   void _showSnackAndGo(String title, String message, Color color) {
//     Get.snackbar(
//       title,
//       message,
//       snackPosition: SnackPosition.BOTTOM,
//       backgroundColor: color,
//       colorText: Colors.white,
//       duration: const Duration(seconds: 3),
//     );
//     Future.delayed(const Duration(milliseconds: 400), _goToLogin);
//   }
//
//   void _showSettingsDialog({
//     required String title,
//     required String body,
//     required VoidCallback onConfirm,
//     required VoidCallback onSkip,
//   }) {
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
//         content: Text(body),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               onSkip();
//             },
//             child: const Text('Skip'),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D3436)),
//             onPressed: () {
//               Navigator.pop(context);
//               onConfirm();
//             },
//             child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   //  BUILD
//   // ══════════════════════════════════════════════════════════════════════════
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Stack(
//         children: [
//           // ── Background shapes ──────────────────────────────────────────
//           Positioned(
//             top: -100,
//             right: -50,
//             child: Transform.rotate(
//               angle: -0.2,
//               child: Container(
//                 width: 300,
//                 height: 300,
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(80),
//                   gradient: LinearGradient(
//                     colors: [
//                       Colors.blueGrey.withOpacity(0.4),
//                       Colors.blueGrey.withOpacity(0.1),
//                     ],
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           Positioned(
//             top: 50,
//             left: -30,
//             child: Container(
//               width: 120,
//               height: 120,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: Colors.blueGrey.withOpacity(0.05),
//               ),
//             ),
//           ),
//
//           // ── Content ────────────────────────────────────────────────────
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 32),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   // Icon
//                   Container(
//                     padding: const EdgeInsets.all(32),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       shape: BoxShape.circle,
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.05),
//                           blurRadius: 20,
//                           offset: const Offset(0, 10),
//                         ),
//                       ],
//                     ),
//                     child: const Icon(
//                       Icons.storage_rounded,
//                       size: 70,
//                       color: Colors.blueGrey,
//                     ),
//                   ),
//                   const SizedBox(height: 40),
//
//                   // Title
//                   Text(
//                     'Storage Permission',
//                     style: TextStyle(
//                       fontSize: 26,
//                       fontWeight: FontWeight.w800,
//                       color: AppColors.darkText,
//                       letterSpacing: -0.5,
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                   const SizedBox(height: 10),
//
//                   // Description
//                   Text(
//                     'Allow storage access so the app can export your GPS location '
//                         'data as CSV files.\n\n'
//                         '📁 Files will be saved to:\n'
//                         'Downloads / LocationData /',
//                     style: TextStyle(
//                       fontSize: 15,
//                       color: AppColors.subText,
//                       height: 1.55,
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                   const SizedBox(height: 50),
//
//                   // ALLOW button
//                   SizedBox(
//                     width: double.infinity,
//                     height: 56,
//                     child: ElevatedButton(
//                       onPressed: _isRequesting ? null : _requestPermission,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xFF2D3436),
//                         foregroundColor: Colors.white,
//                         elevation: 4,
//                         shadowColor: Colors.black26,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(18),
//                         ),
//                       ),
//                       child: _isRequesting
//                           ? const SizedBox(
//                           width: 22,
//                           height: 22,
//                           child: CircularProgressIndicator(
//                               color: Colors.white, strokeWidth: 2.5))
//                           : const Text(
//                         'ALLOW ACCESS',
//                         style: TextStyle(
//                             fontSize: 16, fontWeight: FontWeight.bold),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//
//                   // Skip / Later link
//                   GestureDetector(
//                     onTap: _isRequesting ? null : _goToLogin,
//                     child: Text(
//                       'Skip for now',
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: Colors.blueGrey.shade400,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }