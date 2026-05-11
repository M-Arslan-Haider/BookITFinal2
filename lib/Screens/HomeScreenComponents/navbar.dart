// //
// //
// // import 'package:flutter/material.dart';
// // import 'package:get/get.dart';
// // import 'package:order_booking_app/ViewModels/update_function_view_model.dart';
// //
// // class Navbar extends StatelessWidget {
// //   Navbar({super.key});
// //
// //   final updateFunctionViewModel = Get.put(UpdateFunctionViewModel());
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Container(
// //       padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
// //       decoration: BoxDecoration(
// //         gradient: LinearGradient(
// //           colors: [
// //             Colors.blueGrey,
// //             Colors.blueGrey,
// //           ],
// //           begin: Alignment.topCenter,
// //           end: Alignment.bottomCenter,
// //         ),
// //         // borderRadius: const BorderRadius.only(
// //         //   bottomLeft: Radius.circular(30),
// //         //   bottomRight: Radius.circular(30),
// //         // ),
// //       ),
// //       child: Row(
// //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //         children: [
// //           // Left side - App Logo/Name
// //           Row(
// //             children: [
// //               // Optional: small logo/icon container (muted)
// //               // Container(
// //               //   padding: const EdgeInsets.all(8),
// //               //   decoration: BoxDecoration(
// //               //     color: Colors.white.withOpacity(0.18),
// //               //     borderRadius: BorderRadius.circular(10),
// //               //   ),
// //               //   child: const Icon(
// //               //     Icons.business_center_rounded, // or your preferred icon
// //               //     color: Colors.white,
// //               //     size: 26,
// //               //   ),
// //               // ),
// //               // const SizedBox(width: 12),
// //
// //               Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   const Text(
// //                     "BOOKIT",
// //                     style: TextStyle(
// //                       color: Colors.white,
// //                       fontSize: 20,
// //                       fontWeight: FontWeight.w700,
// //                       letterSpacing: 0.8,
// //                     ),
// //                   ),
// //                   Text(
// //                     "Book once. Anywhere.",
// //                     style: TextStyle(
// //                       color: Colors.white.withOpacity(0.80),
// //                       fontSize: 11,
// //                       fontWeight: FontWeight.w400,
// //                       letterSpacing: 0.4,
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ],
// //           ),
// //
// //           // Right side - Sync button (cleaner version)
// //           Material(
// //             color: Colors.transparent,
// //             child: InkWell(
// //               borderRadius: BorderRadius.circular(12),
// //               onTap: () async {
// //                 // ───────────────────────────────────────
// //                 //   Sync logic (kept same as original)
// //                 // ───────────────────────────────────────
// //                 Get.showSnackbar(
// //                   GetSnackBar(
// //                     message: 'Syncing data...',
// //                     duration: const Duration(seconds: 2),
// //                     backgroundColor: const Color(0xFF3B82F6),
// //                     icon: const Icon(Icons.sync, color: Colors.white),
// //                     borderRadius: 10,
// //                     margin: const EdgeInsets.all(12),
// //                   ),
// //                 );
// //
// //                 debugPrint('🔄 Manual sync triggered from navbar');
// //
// //                 await updateFunctionViewModel.fetchAndSaveUpdatedCities();
// //                 await updateFunctionViewModel.fetchAndSaveUpdatedProducts();
// //                 await updateFunctionViewModel.fetchAndSaveUpdatedOrderMaster();
// //
// //                 await updateFunctionViewModel.syncAllLocalDataToServer();
// //                 await updateFunctionViewModel.checkAndSetInitializationDateTime();
// //
// //                 Get.showSnackbar(
// //                   const GetSnackBar(
// //                     message: 'Data synced successfully',
// //                     duration: Duration(seconds: 2),
// //                     backgroundColor: Color(0xFF10B981), // emerald-500 (calmer green)
// //                     icon: Icon(Icons.check_circle_outline_rounded, color: Colors.white),
// //                     borderRadius: 10,
// //                     margin: EdgeInsets.all(12),
// //                   ),
// //                 );
// //               },
// //               child: Container(
// //                 width: 44,
// //                 height: 44,
// //                 decoration: BoxDecoration(
// //                   color: Colors.white.withOpacity(0.18),
// //                   borderRadius: BorderRadius.circular(12),
// //                 ),
// //                 child: const Icon(
// //                   Icons.sync_rounded,
// //                   color: Colors.white,
// //                   size: 24,
// //                 ),
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
//
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:order_booking_app/ViewModels/update_function_view_model.dart';

class Navbar extends StatelessWidget {
  // Make scaffoldKey optional with a fallback
  final GlobalKey<ScaffoldState>? scaffoldKey;

  Navbar({super.key, this.scaffoldKey});

  final updateFunctionViewModel = Get.put(UpdateFunctionViewModel());

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueGrey, Colors.blueGrey],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [

          // ── LEFT: Hamburger → opens drawer (if scaffoldKey exists) ──
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                // Only try to open drawer if scaffoldKey is provided
                if (scaffoldKey != null) {
                  scaffoldKey?.currentState?.openDrawer();
                }
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),

          // ── CENTER: App name ─────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                "BOOKIT",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                "Book once. Anywhere.",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.80),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),

          // ── RIGHT: Sync button ───────────────────────────
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                Get.showSnackbar(
                  GetSnackBar(
                    message: 'Syncing data...',
                    duration: const Duration(seconds: 2),
                    backgroundColor: const Color(0xFF3B82F6),
                    icon: const Icon(Icons.sync, color: Colors.white),
                    borderRadius: 10,
                    margin: const EdgeInsets.all(12),
                  ),
                );

                debugPrint('🔄 Manual sync triggered from navbar');

                await updateFunctionViewModel.fetchAndSaveUpdatedCities();
                await updateFunctionViewModel.fetchAndSaveUpdatedProducts();
                await updateFunctionViewModel.fetchAndSaveUpdatedOrderMaster();
                await updateFunctionViewModel.syncAllLocalDataToServer();
                await updateFunctionViewModel.checkAndSetInitializationDateTime();

                Get.showSnackbar(
                  const GetSnackBar(
                    message: 'Data synced successfully',
                    duration: Duration(seconds: 2),
                    backgroundColor: Color(0xFF10B981),
                    icon: Icon(Icons.check_circle_outline_rounded,
                        color: Colors.white),
                    borderRadius: 10,
                    margin: EdgeInsets.all(12),
                  ),
                );
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.sync_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}
//
// ///desin
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:order_booking_app/ViewModels/update_function_view_model.dart';
//
// /// ─── Warm Field Color Palette (shared) ───────────────────────
// class WFColors {
//   static const cream        = Color(0xFFFAF5EF);
//   static const terracotta   = Color(0xFFE8612A);
//   static const terracottaDark  = Color(0xFFCF4E1C);
//   static const terracottaLight = Color(0xFFF07A4A);
//   static const amber        = Color(0xFFF59E0B);
//   static const cardWhite    = Color(0xFFFFFFFF);
//   static const textDark     = Color(0xFF2D1F0F);
//   static const textMid      = Color(0xFF7A5C3C);
//   static const textLight    = Color(0xFFB09070);
//   static const divider      = Color(0xFFF0E8DF);
// }
//
// class Navbar extends StatelessWidget {
//   final GlobalKey<ScaffoldState>? scaffoldKey;
//
//   Navbar({super.key, this.scaffoldKey});
//
//   final updateFunctionViewModel = Get.put(UpdateFunctionViewModel());
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//
//           // ── LEFT: Hamburger ──────────────────────────────────
//           _NavBtn(
//             onTap: () => scaffoldKey?.currentState?.openDrawer(),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 _bar(18),
//                 const SizedBox(height: 4),
//                 _bar(13),
//                 const SizedBox(height: 4),
//                 _bar(18),
//               ],
//             ),
//           ),
//
//           // ── CENTER: Brand name ───────────────────────────────
//           Column(
//             children: [
//               const Text(
//                 'BOOKIT',
//                 style: TextStyle(
//                   fontFamily: 'Georgia',
//                   fontSize: 20,
//                   fontWeight: FontWeight.w700,
//                   color: Colors.white,
//                   letterSpacing: 1.0,
//                 ),
//               ),
//               Text(
//                 'Book once. Anywhere.',
//                 style: TextStyle(
//                   fontSize: 10,
//                   color: Colors.white.withOpacity(0.70),
//                   letterSpacing: 0.5,
//                 ),
//               ),
//             ],
//           ),
//
//           // ── RIGHT: Sync button ───────────────────────────────
//           _NavBtn(
//             onTap: () async {
//               Get.showSnackbar(
//                 GetSnackBar(
//                   message: 'Syncing data...',
//                   duration: const Duration(seconds: 2),
//                   backgroundColor: WFColors.terracottaDark,
//                   icon: const Icon(Icons.sync, color: Colors.white),
//                   borderRadius: 12,
//                   margin: const EdgeInsets.all(12),
//                 ),
//               );
//
//               await updateFunctionViewModel.fetchAndSaveUpdatedCities();
//               await updateFunctionViewModel.fetchAndSaveUpdatedProducts();
//               await updateFunctionViewModel.fetchAndSaveUpdatedOrderMaster();
//               await updateFunctionViewModel.syncAllLocalDataToServer();
//               await updateFunctionViewModel.checkAndSetInitializationDateTime();
//
//               Get.showSnackbar(
//                 const GetSnackBar(
//                   message: 'Data synced successfully ✓',
//                   duration: Duration(seconds: 2),
//                   backgroundColor: Color(0xFF10B981),
//                   icon: Icon(Icons.check_circle_outline_rounded, color: Colors.white),
//                   borderRadius: 12,
//                   margin: EdgeInsets.all(12),
//                 ),
//               );
//             },
//             child: const Icon(Icons.sync_rounded, color: Colors.white, size: 22),
//           ),
//
//         ],
//       ),
//     );
//   }
//
//   Widget _bar(double w) => Container(
//     width: w,
//     height: 2,
//     decoration: BoxDecoration(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(2),
//     ),
//   );
// }
//
// // ── Reusable frosted nav button ───────────────────────────────
// class _NavBtn extends StatelessWidget {
//   final VoidCallback onTap;
//   final Widget child;
//
//   const _NavBtn({required this.onTap, required this.child});
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width: 42,
//         height: 42,
//         decoration: BoxDecoration(
//           color: Colors.white.withOpacity(0.18),
//           borderRadius: BorderRadius.circular(13),
//           border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
//         ),
//         child: child,
//       ),
//     );
//   }
// }