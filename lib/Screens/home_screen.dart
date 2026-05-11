


import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:order_booking_app/Databases/util.dart';
import 'package:order_booking_app/Screens/recovery_form_screen.dart';
import 'package:order_booking_app/Screens/shop_visit_screen.dart';
import 'package:order_booking_app/ViewModels/shop_visit_view_model.dart';
import 'package:order_booking_app/screens/add_shop_screen.dart';
import 'package:order_booking_app/screens/return_form_screen.dart';
import 'package:order_booking_app/widgets/color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../Utils/ForceUpdateService.dart';
import '../ViewModels/ScreenViewModels/signup_view_model.dart';
import '../ViewModels/add_shop_view_model.dart';
import '../ViewModels/location_view_model.dart';
import '../ViewModels/order_details_view_model.dart';
import '../ViewModels/return_form_view_model.dart';
import '../ViewModels/shop_visit_details_view_model.dart';
import '../ViewModels/attendance_out_view_model.dart';
import '../ViewModels/attendance_view_model.dart';
import '../ViewModels/order_master_view_model.dart';
import '../ViewModels/recovery_form_view_model.dart';

import 'HomeScreenComponents/navbar.dart';
import 'HomeScreenComponents/profile_section.dart';
import 'HomeScreenComponents/timer_card.dart';
import 'HomeScreenComponents/Today Stats/today_stats_record.dart';
import 'HomeScreenComponents/work_time_progress_card.dart';
import 'HomeScreenComponents/app_drawer.dart';   // ← NEW
import 'leave_form_screen.dart';
import 'order_booking_status_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ── ViewModels ──────────────────────────────────────────────
  late final addShopViewModel          = Get.put(AddShopViewModel());
  late final shopVisitViewModel        = Get.put(ShopVisitViewModel());
  late final shopVisitDetailsViewModel = Get.put(ShopVisitDetailsViewModel());
  late final orderMasterViewModel      = Get.put(OrderMasterViewModel());
  late final orderDetailsViewModel     = Get.put(OrderDetailsViewModel());
  late final recoveryFormViewModel     = Get.put(RecoveryFormViewModel());
  late final returnFormViewModel       = Get.put(ReturnFormViewModel());
  late final attendanceViewModel       = Get.put(AttendanceViewModel());
  late final attendanceOutViewModel    = Get.put(AttendanceOutViewModel());
  late final signUpController          = Get.put(SignUpController());
  late final LocationViewModel locationVM;

  // GlobalKey — hamburger button ko drawer se connect karta hai
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String user_id  = '';
  String userName = '';

  // ── initState ───────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    locationVM = Get.isRegistered<LocationViewModel>()
        ? Get.find<LocationViewModel>()
        : Get.put(LocationViewModel());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ForceUpdateService.check(context);
    });

    _retrieveSavedValues();

    addShopViewModel.fetchAllAddShop();
    shopVisitViewModel.fetchAllShopVisit();
    shopVisitViewModel.fetchTotalShopVisit();
    shopVisitDetailsViewModel.initializeProductData();
    orderMasterViewModel.fetchAllOrderMaster();
    orderMasterViewModel.fetchTotalDispatched();
    recoveryFormViewModel.fetchAllRecoveryForm();
    returnFormViewModel.fetchAllReturnForm();
    attendanceViewModel.fetchAllAttendance();
    attendanceOutViewModel.fetchAllAttendanceOut();

    FlutterForegroundTask.startService(
      notificationTitle: 'Clock Running',
      notificationText: 'Tracking time and location...',
      callback: startCallback,
    );
  }

  Future<void> _retrieveSavedValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    setState(() {
      user_id  = prefs.getString('userId')   ?? '';
      userName = prefs.getString('userName') ?? '';
    });
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {

    return WillPopScope(
      onWillPop: () async => false,
      child: SafeArea(
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.blueGrey.shade50,

          // ╔══════════════════════════════════╗
          // ║  SIDE DRAWER                     ║
          // ╚══════════════════════════════════╝
          drawer: AppDrawer(
            addShopViewModel:      addShopViewModel,
            shopVisitViewModel:    shopVisitViewModel,
            orderMasterViewModel:  orderMasterViewModel,
            recoveryFormViewModel: recoveryFormViewModel,
            returnFormViewModel:   returnFormViewModel,
            attendanceViewModel:   attendanceViewModel,
          ),

          body: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding  = constraints.maxWidth < 400 ? 12.0 : 20.0;
              final spacingBetweenRows = constraints.maxWidth < 400 ? 12.0 : 15.0;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 10),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: TimerCard(),
                    ),
                    SizedBox(height: spacingBetweenRows),
                    _buildQuickActions(horizontalPadding: horizontalPadding),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.blueGrey.shade500],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft:  Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        children: [
          // Decorative blob
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
          Column(
            children: [
              // Navbar — scaffoldKey pass kiya taake hamburger drawer khole
              Navbar(scaffoldKey: _scaffoldKey),
              const SizedBox(height: 20),
              const ProfileSection(),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  QUICK ACTIONS  (exactly same as original)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildQuickActions({required double horizontalPadding}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Quick Actions",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _actionTile(
                icon:  LucideIcons.store,
                label: 'Add Shop',
                onTap: () {
                  if (locationVM.isClockedIn.value) {
                    Get.to(() => AddShopScreen());
                  } else {
                    _showClockInRequiredDialog();
                  }
                },
              ),
              const SizedBox(width: 10),
              _actionTile(
                icon:  LucideIcons.building,
                label: 'Shop Visit',
                onTap: () {
                  if (locationVM.isClockedIn.value) {
                    Get.to(() => const ShopVisitScreen());
                  } else {
                    _showClockInRequiredDialog();
                  }
                },
              ),
              const SizedBox(width: 10),
              _actionTile(
                icon:  LucideIcons.refreshCcw,
                label: 'Return',
                onTap: () async {
                  if (locationVM.isClockedIn.value) {
                    await orderMasterViewModel.fetchAllOrderMaster();
                    await orderDetailsViewModel.fetchAllReConfirmOrder();
                    Get.to(() => ReturnFormScreen());
                  } else {
                    _showClockInRequiredDialog();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _actionTile(
                icon:  LucideIcons.wallet,
                label: 'Recovery',
                onTap: () async {
                  if (locationVM.isClockedIn.value) {
                    await orderMasterViewModel.fetchAllOrderMaster();
                    await recoveryFormViewModel.initializeData();
                    Get.to(() => RecoveryFormScreen());
                  } else {
                    _showClockInRequiredDialog();
                  }
                },
              ),
              const SizedBox(width: 10),
              _actionTile(
                icon:  LucideIcons.clipboardCheck,
                label: 'Booking Status',
                onTap: () async {
                  await orderMasterViewModel.fetchAllOrderMaster();
                  Get.to(() => OrderBookingStatusScreen());
                },
              ),
              const SizedBox(width: 10),
              _actionTile(
                icon:  LucideIcons.calendarDays,
                label: 'Leave',
                onTap: () => Get.to(() => LeaveFormScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 100,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueGrey,
                ),
                child: Icon(icon, size: 26, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.blueGrey.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DIALOG
  // ═══════════════════════════════════════════════════════════════
  void _showClockInRequiredDialog() {
    Get.defaultDialog(
      title: "Clock In Required",
      titleStyle: const TextStyle(
          fontWeight: FontWeight.w600, color: Colors.blueGrey),
      middleText: "Please start your work timer first.",
      middleTextStyle: TextStyle(color: Colors.blueGrey.shade600),
      textConfirm: "OK",
      confirmTextColor: Colors.white,
      buttonColor: Colors.blueGrey,
      radius: 12,
      onConfirm: Get.back,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Foreground Task
// ═══════════════════════════════════════════════════════════════
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {}
  @override
  Future<void> onDestroy(DateTime timestamp, bool restart) async {}
}



