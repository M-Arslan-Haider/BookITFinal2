//
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:lucide_icons/lucide_icons.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../../Databases/util.dart';
// import '../../Reports/add_shop_screen/add_screen_report.dart';
// import '../../Reports/attendence_report/attendence_report_screen.dart';
// import '../../Reports/dispatch_report/dispatch_report_screen.dart';
// import '../../Reports/order_detail_report/OrderReportScreen.dart';
// import '../../Reports/recovery_report/recovery_report_screen.dart';
// import '../../Reports/shop_visit_report/shop_visit_report_screen.dart';
// import '../../Screens/login_screen.dart';
// import '../../Services/Biometric/biometric_services.dart';
//
// import '../../ViewModels/add_shop_view_model.dart';
// import '../../ViewModels/attendance_view_model.dart';
// import '../../ViewModels/login_view_model.dart';
// import '../../ViewModels/order_master_view_model.dart';
// import '../../ViewModels/recovery_form_view_model.dart';
// import '../../ViewModels/return_form_view_model.dart';
// import '../../ViewModels/shop_visit_view_model.dart';
// import 'timer_card.dart';
// import 'work_time_progress_card.dart';
// import 'Today Stats/today_stats_record.dart';
//
// // ═══════════════════════════════════════════════════════════════
// //  AppDrawer
// // ═══════════════════════════════════════════════════════════════
// class AppDrawer extends StatefulWidget {
//   final AddShopViewModel      addShopViewModel;
//   final ShopVisitViewModel    shopVisitViewModel;
//   final OrderMasterViewModel  orderMasterViewModel;
//   final RecoveryFormViewModel recoveryFormViewModel;
//   final ReturnFormViewModel   returnFormViewModel;
//   final AttendanceViewModel   attendanceViewModel;
//
//   const AppDrawer({
//     super.key,
//     required this.addShopViewModel,
//     required this.shopVisitViewModel,
//     required this.orderMasterViewModel,
//     required this.recoveryFormViewModel,
//     required this.returnFormViewModel,
//     required this.attendanceViewModel,
//   });
//
//   @override
//   State<AppDrawer> createState() => _AppDrawerState();
// }
//
// class _AppDrawerState extends State<AppDrawer> {
//   String userName = '';
//   String userId   = '';
//
//   // ✅ NEW — biometric toggle state
//   bool _biometricEnabled     = false;
//   bool _biometricAvailable   = false;
//   bool _biometricToggling    = false; // prevents double-tap while async runs
//
//   // @override
//   // void initState() {
//   //   super.initState();
//   //   _loadUser();
//   //   _loadBiometricState(); // ✅ NEW
//   // }
//
//   Future<void> _loadUser() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.reload();
//     setState(() {
//       userName = prefs.getString('userName') ?? 'User';
//       userId   = prefs.getString('userId')   ?? '';
//     });
//   }
//
//   // // ✅ NEW ──────────────────────────────────────────────────────────────────
//   //
//   // Future<void> _loadBiometricState() async {
//   //   final available = await BiometricService.instance.isAvailable();
//   //   final enabled   = await BiometricService.instance.isEnabled();
//   //   if (mounted) {
//   //     setState(() {
//   //       _biometricAvailable = available;
//   //       _biometricEnabled   = enabled;
//   //     });
//   //   }
//   // }
//   //
//   // Future<void> _toggleBiometric(bool turnOn) async {
//   //   if (_biometricToggling) return;
//   //   setState(() => _biometricToggling = true);
//   //
//   //   try {
//   //     LoginViewModel loginVM;
//   //     try {
//   //       loginVM = Get.find<LoginViewModel>();
//   //     } catch (_) {
//   //       loginVM = Get.put(LoginViewModel());
//   //     }
//   //
//   //     if (turnOn) {
//   //       // enableBiometric() scans the finger once to confirm, then saves.
//   //       final success = await loginVM.enableBiometric();
//   //       if (!mounted) return;
//   //
//   //       if (success) {
//   //         setState(() => _biometricEnabled = true);
//   //         Get.snackbar(
//   //           '✅ Fingerprint Enabled',
//   //           'You can now log in using your fingerprint.',
//   //           snackPosition: SnackPosition.BOTTOM,
//   //           backgroundColor: Colors.blueGrey,
//   //           colorText: Colors.white,
//   //         );
//   //       } else {
//   //         // User cancelled or finger scan failed
//   //         Get.snackbar(
//   //           'Fingerprint Not Set',
//   //           'Could not verify fingerprint. Try again.',
//   //           snackPosition: SnackPosition.BOTTOM,
//   //           backgroundColor: Colors.orange.shade700,
//   //           colorText: Colors.white,
//   //         );
//   //       }
//   //     } else {
//   //       // Disable — confirm first
//   //       final confirm = await Get.dialog<bool>(
//   //         AlertDialog(
//   //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//   //           title: const Text('Disable Fingerprint Login'),
//   //           content: const Text('Are you sure you want to disable fingerprint login?'),
//   //           actions: [
//   //             TextButton(
//   //               onPressed: () => Get.back(result: false),
//   //               child: Text('Cancel', style: TextStyle(color: Colors.blueGrey)),
//   //             ),
//   //             TextButton(
//   //               onPressed: () => Get.back(result: true),
//   //               child: const Text('Disable', style: TextStyle(color: Colors.red)),
//   //             ),
//   //           ],
//   //         ),
//   //       );
//   //
//   //       if (confirm == true) {
//   //         await loginVM.disableBiometric();
//   //         if (mounted) setState(() => _biometricEnabled = false);
//   //         Get.snackbar(
//   //           'Fingerprint Disabled',
//   //           'You\'ll need your password to log in next time.',
//   //           snackPosition: SnackPosition.BOTTOM,
//   //           backgroundColor: Colors.blueGrey,
//   //           colorText: Colors.white,
//   //         );
//   //       }
//   //     }
//   //   } finally {
//   //     if (mounted) setState(() => _biometricToggling = false);
//   //   }
//   // }
//
//   // ── Logout (unchanged) ────────────────────────────────────────────────────
//
//   Future<void> _logout() async {
//     final confirm = await Get.dialog<bool>(
//       AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: const Text('Logout'),
//         content: const Text('Are you sure you want to logout?'),
//         actions: [
//           TextButton(
//             onPressed: () => Get.back(result: false),
//             child: Text('Cancel', style: TextStyle(color: Colors.blueGrey)),
//           ),
//           TextButton(
//             onPressed: () => Get.back(result: true),
//             child: const Text('Logout', style: TextStyle(color: Colors.red)),
//           ),
//         ],
//       ),
//     );
//
//     if (confirm != true) return;
//
//     Get.back(); // close drawer
//
//     Get.dialog(
//       const Center(child: CircularProgressIndicator()),
//       barrierDismissible: false,
//     );
//
//     try {
//       LoginViewModel? loginViewModel;
//       try {
//         loginViewModel = Get.find<LoginViewModel>();
//       } catch (e) {
//         loginViewModel = Get.put(LoginViewModel());
//       }
//
//       await loginViewModel!.logout();
//
//       if (Get.isDialogOpen ?? false) Get.back();
//       Get.offAll(() => const LoginScreen());
//
//       Get.snackbar(
//         'Logged Out',
//         'You have been logged out successfully',
//         snackPosition: SnackPosition.BOTTOM,
//         backgroundColor: Colors.blueGrey,
//         colorText: Colors.white,
//         duration: const Duration(seconds: 2),
//       );
//     } catch (e) {
//       if (Get.isDialogOpen ?? false) Get.back();
//       Get.snackbar(
//         'Error', 'Failed to logout: $e',
//         snackPosition: SnackPosition.BOTTOM,
//         backgroundColor: Colors.red,
//         colorText: Colors.white,
//       );
//     }
//   }
//
//   // ── Build ─────────────────────────────────────────────────────────────────
//
//   @override
//   Widget build(BuildContext context) {
//     return Drawer(
//       backgroundColor: Colors.white,
//       child: Column(
//         children: [
//           _buildHeader(),
//           Expanded(
//             child: ListView(
//               padding: const EdgeInsets.symmetric(vertical: 12),
//               children: [
//
//                 // 1. HOME
//                 _tile(
//                   icon:  LucideIcons.home,
//                   label: 'Home',
//                   onTap: () => Get.back(),
//                 ),
//
//                 // 2. PROFILE
//                 _tile(
//                   icon:  LucideIcons.user,
//                   label: 'Profile',
//                   onTap: () {
//                     Get.back();
//                     Get.snackbar(
//                       'Profile', 'Profile screen will come here',
//                       backgroundColor: Colors.blueGrey,
//                       colorText: Colors.white,
//                       snackPosition: SnackPosition.BOTTOM,
//                     );
//                   },
//                 ),
//
//                 // // ✅ NEW — 3. BIOMETRIC LOGIN TOGGLE
//                 // if (_biometricAvailable) _biometricTile(),
//
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
//                   child: Divider(height: 1, color: Colors.blueGrey.shade100),
//                 ),
//
//                 // 4. SUMMARY
//                 _tile(
//                   icon:  LucideIcons.clipboardList,
//                   label: 'Summary',
//                   onTap: () {
//                     Get.back();
//                     Get.to(() => _SummaryScreen(
//                       addShopVM:     widget.addShopViewModel,
//                       shopVisitVM:   widget.shopVisitViewModel,
//                       orderMasterVM: widget.orderMasterViewModel,
//                       recoveryVM:    widget.recoveryFormViewModel,
//                       returnVM:      widget.returnFormViewModel,
//                       attendanceVM:  widget.attendanceViewModel,
//                     ));
//                   },
//                 ),
//
//                 // 6. TODAY STATS
//                 _tile(
//                   icon:  LucideIcons.barChart2,
//                   label: 'Today Stats',
//                   onTap: () {
//                     Get.back();
//                     Get.to(() => _TodayStatsScreen());
//                   },
//                 ),
//
//                 // 7. LOGOUT
//                 const Divider(height: 32, thickness: 1, indent: 16, endIndent: 16),
//                 _logoutTile(),
//               ],
//             ),
//           ),
//           _buildFooter(),
//         ],
//       ),
//     );
//   }
//
//   // ── Header (unchanged) ────────────────────────────────────────────────────
//
//   Widget _buildHeader() {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.fromLTRB(20, 52, 20, 22),
//       decoration: const BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Colors.blueGrey, Color(0xFF607D8B)],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Container(
//             width: 54, height: 54,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               color: Colors.white.withOpacity(0.22),
//               border: Border.all(color: Colors.white54, width: 2),
//             ),
//             child: const Icon(LucideIcons.user, color: Colors.white, size: 26),
//           ),
//           const SizedBox(height: 12),
//           Text(
//             userName.isNotEmpty ? userName : 'Welcome',
//             style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
//           ),
//           if (userId.isNotEmpty)
//             Text(
//               'ID: $userId',
//               style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
//             ),
//           const SizedBox(height: 8),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.18),
//               borderRadius: BorderRadius.circular(20),
//             ),
//             child: const Text(
//               'BOOKIT',
//               style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ── Normal tile (unchanged) ───────────────────────────────────────────────
//
//   Widget _tile({
//     required IconData icon,
//     required String label,
//     required VoidCallback onTap,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
//       child: Material(
//         color: Colors.transparent,
//         borderRadius: BorderRadius.circular(10),
//         child: InkWell(
//           borderRadius: BorderRadius.circular(10),
//           onTap: onTap,
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
//             child: Row(
//               children: [
//                 Icon(icon, size: 21, color: Colors.blueGrey.shade600),
//                 const SizedBox(width: 16),
//                 Text(
//                   label,
//                   style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: Colors.blueGrey.shade800),
//                 ),
//                 const Spacer(),
//                 Icon(Icons.chevron_right_rounded, size: 18, color: Colors.blueGrey.shade300),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ✅ NEW — Biometric toggle tile ───────────────────────────────────────────
//
//   // Widget _biometricTile() {
//   //   return Padding(
//   //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
//   //     child: Material(
//   //       color: Colors.transparent,
//   //       borderRadius: BorderRadius.circular(10),
//   //       child: InkWell(
//   //         borderRadius: BorderRadius.circular(10),
//   //         onTap: _biometricToggling ? null : () => _toggleBiometric(!_biometricEnabled),
//   //         child: Padding(
//   //           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//   //           child: Row(
//   //             children: [
//   //               // Fingerprint icon in a coloured circle
//   //               Container(
//   //                 width: 32, height: 32,
//   //                 decoration: BoxDecoration(
//   //                   shape: BoxShape.circle,
//   //                   color: _biometricEnabled
//   //                       ? Colors.blueGrey.withOpacity(0.12)
//   //                       : Colors.blueGrey.withOpacity(0.06),
//   //                 ),
//   //                 child: Icon(
//   //                   Icons.fingerprint,
//   //                   size: 20,
//   //                   color: _biometricEnabled ? Colors.blueGrey.shade700 : Colors.blueGrey.shade400,
//   //                 ),
//   //               ),
//   //               const SizedBox(width: 16),
//   //               Expanded(
//   //                 child: Column(
//   //                   crossAxisAlignment: CrossAxisAlignment.start,
//   //                   children: [
//   //                     Text(
//   //                       'Fingerprint Login',
//   //                       style: TextStyle(
//   //                         fontSize: 14.5,
//   //                         fontWeight: FontWeight.w500,
//   //                         color: Colors.blueGrey.shade800,
//   //                       ),
//   //                     ),
//   //                     Text(
//   //                       _biometricEnabled ? 'Enabled — tap to disable' : 'Tap to enable',
//   //                       style: TextStyle(fontSize: 11.5, color: Colors.blueGrey.shade400),
//   //                     ),
//   //                   ],
//   //                 ),
//   //               ),
//   //               // Toggle switch
//   //               _biometricToggling
//   //                   ? const SizedBox(
//   //                 width: 24, height: 24,
//   //                 child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueGrey),
//   //               )
//   //                   : Switch(
//   //                 value: _biometricEnabled,
//   //                 onChanged: _biometricToggling ? null : _toggleBiometric,
//   //                 activeColor: Colors.blueGrey.shade700,
//   //                 inactiveThumbColor: Colors.blueGrey.shade300,
//   //                 inactiveTrackColor: Colors.blueGrey.shade100,
//   //               ),
//   //             ],
//   //           ),
//   //         ),
//   //       ),
//   //     ),
//   //   );
//   // }
//
//   // ── Logout tile (unchanged) ───────────────────────────────────────────────
//
//   Widget _logoutTile() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
//       child: Material(
//         color: Colors.transparent,
//         borderRadius: BorderRadius.circular(10),
//         child: InkWell(
//           borderRadius: BorderRadius.circular(10),
//           onTap: _logout,
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
//             child: Row(
//               children: [
//                 Container(
//                   width: 32, height: 32,
//                   decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
//                   child: const Icon(Icons.logout, size: 18, color: Colors.red),
//                 ),
//                 const SizedBox(width: 16),
//                 const Text(
//                   'Logout',
//                   style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: Colors.red),
//                 ),
//                 const Spacer(),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ── Footer (unchanged) ────────────────────────────────────────────────────
//
//   Widget _buildFooter() {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
//       decoration: BoxDecoration(
//         border: Border(top: BorderSide(color: Colors.blueGrey.shade100)),
//       ),
//       child: Column(
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(LucideIcons.info, size: 13, color: Colors.blueGrey.shade300),
//               const SizedBox(width: 8),
//               Text(
//                 'BOOKIT  •  Book once. Anywhere.',
//                 style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade400, fontStyle: FontStyle.italic),
//               ),
//             ],
//           ),
//           const SizedBox(height: 6),
//           Text(
//             "$version",
//             style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
//
// // ═══════════════════════════════════════════════════════════════
// //  Summary Screen — list with live counts (unchanged)
// // ═══════════════════════════════════════════════════════════════
// // class _SummaryScreen extends StatelessWidget {
// //   final AddShopViewModel      addShopVM;
// //   final ShopVisitViewModel    shopVisitVM;
// //   final OrderMasterViewModel  orderMasterVM;
// //   final RecoveryFormViewModel recoveryVM;
// //   final ReturnFormViewModel   returnVM;
// //   final AttendanceViewModel   attendanceVM;
// //
// //   const _SummaryScreen({
// //     required this.addShopVM,
// //     required this.shopVisitVM,
// //     required this.orderMasterVM,
// //     required this.recoveryVM,
// //     required this.returnVM,
// //     required this.attendanceVM,
// //   });
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         title: const Text('Summary'),
// //         backgroundColor: Colors.blueGrey,
// //         foregroundColor: Colors.white,
// //         elevation: 0,
// //       ),
// //       backgroundColor: Colors.blueGrey.shade50,
// //       body: SingleChildScrollView(
// //         padding: const EdgeInsets.all(16),
// //         child: Obx(() {
// //           final rows = [
// //             _Row(Icons.store_outlined,             'Shops',      addShopVM.allAddShop.length,               () => Get.to(() => AddShopReportScreen())),
// //             _Row(Icons.directions_walk_outlined,   'Visits',     shopVisitVM.apiShopVisitsCount.value,      () => Get.to(() => ShopVisitReportDashboard())),
// //             _Row(Icons.shopping_cart_outlined,     'Orders',     orderMasterVM.allOrderMaster.length,       () => Get.to(() => OrderReportScreen())),
// //             _Row(Icons.local_shipping_outlined,    'Dispatched', orderMasterVM.apiDispatchedCount.value,    () => Get.to(() => DispatchOrdersDashboard())),
// //             _Row(Icons.assignment_return_outlined, 'Returns',    returnVM.allReturnForm.length,             null),
// //             _Row(Icons.attach_money_outlined,      'Recovery',   recoveryVM.allRecoveryForm.length,         () => Get.to(() => RecoveryFormDashboard())),
// //             _Row(Icons.punch_clock_outlined,       'Attendance', attendanceVM.allAttendance.length,         () => Get.to(() => AttendanceRecordScreen())),
// //           ];
// //
// //           return Container(
// //             decoration: BoxDecoration(
// //               color: Colors.white,
// //               borderRadius: BorderRadius.circular(14),
// //               boxShadow: [BoxShadow(color: Colors.blueGrey.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
// //             ),
// //             child: Column(
// //               children: List.generate(rows.length, (i) {
// //                 final r = rows[i];
// //                 return Column(
// //                   children: [
// //                     InkWell(
// //                       onTap: r.onTap,
// //                       borderRadius: i == 0
// //                           ? const BorderRadius.vertical(top: Radius.circular(14))
// //                           : i == rows.length - 1
// //                           ? const BorderRadius.vertical(bottom: Radius.circular(14))
// //                           : BorderRadius.zero,
// //                       child: Padding(
// //                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
// //                         child: Row(
// //                           children: [
// //                             Container(
// //                               width: 40, height: 40,
// //                               decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.1), shape: BoxShape.circle),
// //                               child: Icon(r.icon, size: 20, color: Colors.blueGrey),
// //                             ),
// //                             const SizedBox(width: 14),
// //                             Expanded(
// //                               child: Text(r.label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: Colors.blueGrey.shade800)),
// //                             ),
// //                             Container(
// //                               padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
// //                               decoration: BoxDecoration(color: Colors.blueGrey, borderRadius: BorderRadius.circular(20)),
// //                               child: Text(r.value.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
// //                             ),
// //                             if (r.onTap != null) ...[
// //                               const SizedBox(width: 6),
// //                               Icon(Icons.chevron_right_rounded, size: 17, color: Colors.blueGrey.shade300),
// //                             ],
// //                           ],
// //                         ),
// //                       ),
// //                     ),
// //                     if (i < rows.length - 1)
// //                       Divider(height: 1, indent: 56, color: Colors.blueGrey.shade100),
// //                   ],
// //                 );
// //               }),
// //             ),
// //           );
// //         }),
// //       ),
// //     );
// //   }
// // }
//
// // ═══════════════════════════════════════════════════════════════
// //  Summary Screen — list without numbers
// // ═══════════════════════════════════════════════════════════════
// class _SummaryScreen extends StatelessWidget {
//   final AddShopViewModel      addShopVM;
//   final ShopVisitViewModel    shopVisitVM;
//   final OrderMasterViewModel  orderMasterVM;
//   final RecoveryFormViewModel recoveryVM;
//   final ReturnFormViewModel   returnVM;
//   final AttendanceViewModel   attendanceVM;
//
//   const _SummaryScreen({
//     required this.addShopVM,
//     required this.shopVisitVM,
//     required this.orderMasterVM,
//     required this.recoveryVM,
//     required this.returnVM,
//     required this.attendanceVM,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Summary'),
//         backgroundColor: Colors.blueGrey,
//         foregroundColor: Colors.white,
//         elevation: 0,
//       ),
//       backgroundColor: Colors.blueGrey.shade50,
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Container(
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(14),
//             boxShadow: [BoxShadow(color: Colors.blueGrey.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
//           ),
//           child: Column(
//             children: [
//               _buildListItem(Icons.store_outlined, 'Shops', () => Get.to(() => AddShopReportScreen())),
//               _buildDivider(),
//               _buildListItem(Icons.directions_walk_outlined, 'Visits', () => Get.to(() => ShopVisitReportDashboard())),
//               _buildDivider(),
//               _buildListItem(Icons.shopping_cart_outlined, 'Orders', () => Get.to(() => OrderReportScreen())),
//               _buildDivider(),
//               _buildListItem(Icons.local_shipping_outlined, 'Dispatched', () => Get.to(() => DispatchOrdersDashboard())),
//               _buildDivider(),
//               _buildListItem(Icons.assignment_return_outlined, 'Returns', null),
//               _buildDivider(),
//               _buildListItem(Icons.attach_money_outlined, 'Recovery', () => Get.to(() => RecoveryFormDashboard())),
//               _buildDivider(),
//               _buildListItem(Icons.punch_clock_outlined, 'Attendance', () => Get.to(() => AttendanceRecordScreen())),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildListItem(IconData icon, String label, VoidCallback? onTap) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(14),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//         child: Row(
//           children: [
//             Container(
//               width: 40, height: 40,
//               decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.1), shape: BoxShape.circle),
//               child: Icon(icon, size: 20, color: Colors.blueGrey),
//             ),
//             const SizedBox(width: 14),
//             Expanded(
//               child: Text(
//                 label,
//                 style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: Colors.blueGrey.shade800),
//               ),
//             ),
//             if (onTap != null)
//               Icon(Icons.chevron_right_rounded, size: 17, color: Colors.blueGrey.shade300),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildDivider() {
//     return Divider(height: 1, indent: 56, color: Colors.blueGrey.shade100);
//   }
// }
//
// class _Row {
//   final IconData icon;
//   final String label;
//   final int value;
//   final VoidCallback? onTap;
//   _Row(this.icon, this.label, this.value, this.onTap);
// }
// //
// // // ═══════════════════════════════════════════════════════════════
// // //  Today Work Time Screen (unchanged)
// // // ═══════════════════════════════════════════════════════════════
// // class _WorkTimeScreen extends StatelessWidget {
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(title: const Text('Today Work Time'), backgroundColor: Colors.blueGrey, foregroundColor: Colors.white, elevation: 0),
// //       backgroundColor: Colors.blueGrey.shade50,
// //       body: SingleChildScrollView(
// //         padding: const EdgeInsets.all(16),
// //         child: Column(children: [TimerCard(), const SizedBox(height: 16), DailyTimeCircularCard()]),
// //       ),
// //     );
// //   }
// // }
//
// // ═══════════════════════════════════════════════════════════════
// //  Today Stats Screen (unchanged)
// // ═══════════════════════════════════════════════════════════════
// class _TodayStatsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Today Stats'), backgroundColor: Colors.blueGrey, foregroundColor: Colors.white, elevation: 0),
//       backgroundColor: Colors.blueGrey.shade50,
//       body: const SingleChildScrollView(padding: EdgeInsets.all(16), child: TodayStatsCard()),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Databases/util.dart';
import '../../Reports/add_shop_screen/add_screen_report.dart';
import '../../Reports/attendence_report/attendence_report_screen.dart';
import '../../Reports/dispatch_report/dispatch_report_screen.dart';
import '../../Reports/order_detail_report/OrderReportScreen.dart';
import '../../Reports/recovery_report/recovery_report_screen.dart';
import '../../Reports/shop_visit_report/shop_visit_report_screen.dart';
import '../../Screens/login_screen.dart';
import '../../Services/Biometric/biometric_services.dart';
import '../../ViewModels/add_shop_view_model.dart';
import '../../ViewModels/attendance_view_model.dart';
import '../../ViewModels/login_view_model.dart';
import '../../ViewModels/order_master_view_model.dart';
import '../../ViewModels/recovery_form_view_model.dart';
import '../../ViewModels/return_form_view_model.dart';
import '../../ViewModels/shop_visit_view_model.dart';
import 'timer_card.dart';
import 'work_time_progress_card.dart';
import 'Today Stats/today_stats_record.dart';

// ═══════════════════════════════════════════════════════════════
//  AppDrawer
// ═══════════════════════════════════════════════════════════════
class AppDrawer extends StatefulWidget {
  final AddShopViewModel      addShopViewModel;
  final ShopVisitViewModel    shopVisitViewModel;
  final OrderMasterViewModel  orderMasterViewModel;
  final RecoveryFormViewModel recoveryFormViewModel;
  final ReturnFormViewModel   returnFormViewModel;
  final AttendanceViewModel   attendanceViewModel;

  const AppDrawer({
    super.key,
    required this.addShopViewModel,
    required this.shopVisitViewModel,
    required this.orderMasterViewModel,
    required this.recoveryFormViewModel,
    required this.returnFormViewModel,
    required this.attendanceViewModel,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String userName = '';
  String userId   = '';

  // ── Biometric state ────────────────────────────────────────────────────────
  bool _biometricEnabled   = false;
  bool _biometricAvailable = false;
  bool _biometricToggling  = false; // prevents double-tap while async runs

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadBiometricState();
  }

  // ── Load user from SharedPreferences ─────────────────────────────────────

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    setState(() {
      userName = prefs.getString('userName') ?? 'User';
      userId   = prefs.getString('userId')   ?? '';
    });
  }

  // ── Biometric: load current state ─────────────────────────────────────────

  Future<void> _loadBiometricState() async {
    final available = await BiometricService.instance.isAvailable();
    final enabled   = await BiometricService.instance.isEnabled();

    // Only show as enabled if the registered userId matches the current user
    final registeredId = await BiometricService.instance.registeredUserId();
    final prefs = await SharedPreferences.getInstance();
    final currentId = prefs.getString('userId') ?? '';

    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        // show toggle as ON only if it's THIS user's biometric
        _biometricEnabled = enabled && registeredId == currentId;
      });
    }
  }

  // ── Biometric: toggle on/off ───────────────────────────────────────────────

  Future<void> _toggleBiometric(bool turnOn) async {
    if (_biometricToggling) return;
    setState(() => _biometricToggling = true);

    try {
      if (turnOn) {
        // enable() scans finger once to confirm, then saves userId + userName
        final success = await BiometricService.instance.enable(userId, userName);
        if (!mounted) return;

        if (success) {
          setState(() => _biometricEnabled = true);
          _showSnack(
            title: '✅ Fingerprint Enabled',
            message: 'You can now log in using your fingerprint.',
            color: Colors.blueGrey,
          );
        } else {
          _showSnack(
            title: 'Fingerprint Not Set',
            message: 'Could not verify fingerprint. Please try again.',
            color: Colors.orange.shade700,
          );
        }
      } else {
        // Ask for confirmation before disabling
        final confirm = await Get.dialog<bool>(
          AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Disable Fingerprint Login'),
            content: const Text(
                'Are you sure you want to disable fingerprint login?'),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: Text('Cancel',
                    style: TextStyle(color: Colors.blueGrey)),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: const Text('Disable',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await BiometricService.instance.disable();
          if (mounted) setState(() => _biometricEnabled = false);
          _showSnack(
            title: 'Fingerprint Disabled',
            message: "You'll need your password to log in next time.",
            color: Colors.blueGrey,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _biometricToggling = false);
    }
  }

  void _showSnack({
    required String title,
    required String message,
    required Color color,
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: color,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel', style: TextStyle(color: Colors.blueGrey)),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    Get.back(); // close drawer

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      LoginViewModel? loginViewModel;
      try {
        loginViewModel = Get.find<LoginViewModel>();
      } catch (e) {
        loginViewModel = Get.put(LoginViewModel());
      }

      await loginViewModel!.logout();

      if (Get.isDialogOpen ?? false) Get.back();
      Get.offAll(() => const LoginScreen());

      Get.snackbar(
        'Logged Out',
        'You have been logged out successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.blueGrey,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        'Error', 'Failed to logout: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [

                // 1. HOME
                _tile(
                  icon:  LucideIcons.home,
                  label: 'Home',
                  onTap: () => Get.back(),
                ),

                // 2. PROFILE
                _tile(
                  icon:  LucideIcons.user,
                  label: 'Profile',
                  onTap: () {
                    Get.back();
                    Get.snackbar(
                      'Profile', 'Profile screen will come here',
                      backgroundColor: Colors.blueGrey,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  },
                ),

                // ✅ 3. BIOMETRIC LOGIN TOGGLE — shown only when hardware available
                if (_biometricAvailable) _biometricTile(),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Divider(height: 1, color: Colors.blueGrey.shade100),
                ),

                // 4. SUMMARY
                _tile(
                  icon:  LucideIcons.clipboardList,
                  label: 'Summary',
                  onTap: () {
                    Get.back();
                    Get.to(() => _SummaryScreen(
                      addShopVM:     widget.addShopViewModel,
                      shopVisitVM:   widget.shopVisitViewModel,
                      orderMasterVM: widget.orderMasterViewModel,
                      recoveryVM:    widget.recoveryFormViewModel,
                      returnVM:      widget.returnFormViewModel,
                      attendanceVM:  widget.attendanceViewModel,
                    ));
                  },
                ),

                // 5. TODAY STATS
                _tile(
                  icon:  LucideIcons.barChart2,
                  label: 'Today Stats',
                  onTap: () {
                    Get.back();
                    Get.to(() => _TodayStatsScreen());
                  },
                ),

                // 6. LOGOUT
                const Divider(height: 32, thickness: 1, indent: 16, endIndent: 16),
                _logoutTile(),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueGrey, Color(0xFF607D8B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.22),
              border: Border.all(color: Colors.white54, width: 2),
            ),
            child: const Icon(LucideIcons.user, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            userName.isNotEmpty ? userName : 'Welcome',
            style: const TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          if (userId.isNotEmpty)
            Text(
              'ID: $userId',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.75), fontSize: 12),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'BOOKIT',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2),
            ),
          ),
        ],
      ),
    );
  }

  // ── Normal tile ───────────────────────────────────────────────────────────

  Widget _tile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 21, color: Colors.blueGrey.shade600),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.blueGrey.shade800),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: Colors.blueGrey.shade300),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── ✅ Biometric toggle tile ───────────────────────────────────────────────

  Widget _biometricTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _biometricToggling
              ? null
              : () => _toggleBiometric(!_biometricEnabled),
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Fingerprint icon in a coloured circle
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _biometricEnabled
                        ? Colors.blueGrey.withOpacity(0.12)
                        : Colors.blueGrey.withOpacity(0.06),
                  ),
                  child: Icon(
                    Icons.fingerprint,
                    size: 20,
                    color: _biometricEnabled
                        ? Colors.blueGrey.shade700
                        : Colors.blueGrey.shade400,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fingerprint Login',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.blueGrey.shade800,
                        ),
                      ),
                      Text(
                        _biometricEnabled
                            ? 'Enabled — tap to disable'
                            : 'Tap to enable',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.blueGrey.shade400),
                      ),
                    ],
                  ),
                ),
                // Toggle switch or spinner
                _biometricToggling
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.blueGrey),
                )
                    : Switch(
                  value: _biometricEnabled,
                  onChanged:
                  _biometricToggling ? null : _toggleBiometric,
                  activeColor: Colors.blueGrey.shade700,
                  inactiveThumbColor: Colors.blueGrey.shade300,
                  inactiveTrackColor: Colors.blueGrey.shade100,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Logout tile ───────────────────────────────────────────────────────────

  Widget _logoutTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _logout,
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child:
                  const Icon(Icons.logout, size: 18, color: Colors.red),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Logout',
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.red),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.blueGrey.shade100)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.info, size: 13, color: Colors.blueGrey.shade300),
              const SizedBox(width: 8),
              Text(
                'BOOKIT  •  Book once. Anywhere.',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.blueGrey.shade400,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "$version",
            style: const TextStyle(
                fontSize: 10,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Summary Screen
// ═══════════════════════════════════════════════════════════════
class _SummaryScreen extends StatelessWidget {
  final AddShopViewModel      addShopVM;
  final ShopVisitViewModel    shopVisitVM;
  final OrderMasterViewModel  orderMasterVM;
  final RecoveryFormViewModel recoveryVM;
  final ReturnFormViewModel   returnVM;
  final AttendanceViewModel   attendanceVM;

  const _SummaryScreen({
    required this.addShopVM,
    required this.shopVisitVM,
    required this.orderMasterVM,
    required this.recoveryVM,
    required this.returnVM,
    required this.attendanceVM,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Summary'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.blueGrey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.blueGrey.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            children: [
              _buildListItem(Icons.store_outlined, 'Shops',
                      () => Get.to(() => AddShopReportScreen())),
              _buildDivider(),
              _buildListItem(Icons.directions_walk_outlined, 'Visits',
                      () => Get.to(() => ShopVisitReportDashboard())),
              _buildDivider(),
              _buildListItem(Icons.shopping_cart_outlined, 'Orders',
                      () => Get.to(() => OrderReportScreen())),
              _buildDivider(),
              _buildListItem(Icons.local_shipping_outlined, 'Dispatched',
                      () => Get.to(() => DispatchOrdersDashboard())),
              _buildDivider(),
              _buildListItem(
                  Icons.assignment_return_outlined, 'Returns', null),
              _buildDivider(),
              _buildListItem(Icons.attach_money_outlined, 'Recovery',
                      () => Get.to(() => RecoveryFormDashboard())),
              _buildDivider(),
              _buildListItem(Icons.punch_clock_outlined, 'Attendance',
                      () => Get.to(() => AttendanceRecordScreen())),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListItem(IconData icon, String label, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: Colors.blueGrey),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.blueGrey.shade800),
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                  size: 17, color: Colors.blueGrey.shade300),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 56, color: Colors.blueGrey.shade100);
  }
}

class _Row {
  final IconData icon;
  final String label;
  final int value;
  final VoidCallback? onTap;
  _Row(this.icon, this.label, this.value, this.onTap);
}

// ═══════════════════════════════════════════════════════════════
//  Today Stats Screen
// ═══════════════════════════════════════════════════════════════
class _TodayStatsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Today Stats'),
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
          elevation: 0),
      backgroundColor: Colors.blueGrey.shade50,
      body: const SingleChildScrollView(
          padding: EdgeInsets.all(16), child: TodayStatsCard()),
    );
  }
}