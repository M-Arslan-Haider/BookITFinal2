

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

import '../LocatioPoints/ravelTimeViewModel.dart';
import '../Reports/add_shop_screen/add_screen_report.dart';
import '../Reports/attendence_report/attendence_report_screen.dart';

import '../Reports/dispatch_report/dispatch_report_screen.dart';
import '../Reports/order_detail_report/OrderReportScreen.dart';
import '../Reports/recovery_report/recovery_report_screen.dart';
import '../Reports/shop_visit_report/shop_visit_report_screen.dart';
import '../Utils/ForceUpdateService.dart';
import '../ViewModels/ScreenViewModels/signup_view_model.dart';
import '../ViewModels/add_shop_view_model.dart';
import '../ViewModels/location_view_model.dart';
import '../ViewModels/order_details_view_model.dart';
import '../ViewModels/return_form_view_model.dart';
import '../ViewModels/shop_visit_details_view_model.dart';

import 'HomeScreenComponents/navbar.dart';
import 'HomeScreenComponents/profile_section.dart';
import 'HomeScreenComponents/timer_card.dart';
import 'package:order_booking_app/ViewModels/attendance_out_view_model.dart';
import 'package:order_booking_app/ViewModels/attendance_view_model.dart';
import 'package:order_booking_app/ViewModels/order_master_view_model.dart';
import 'package:order_booking_app/ViewModels/recovery_form_view_model.dart';
import 'HomeScreenComponents/Today Stats/today_stats_record.dart';
import 'HomeScreenComponents/work_time_progress_card.dart';
import 'leave_form_screen.dart';
import 'order_booking_status_screen.dart';
import 'package:lucide_icons/lucide_icons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ViewModels
  late final addShopViewModel = Get.put(AddShopViewModel());
  late final shopVisitViewModel = Get.put(ShopVisitViewModel());
  late final shopVisitDetailsViewModel = Get.put(ShopVisitDetailsViewModel());
  late final orderMasterViewModel = Get.put(OrderMasterViewModel());
  late final orderDetailsViewModel = Get.put(OrderDetailsViewModel());
  late final recoveryFormViewModel = Get.put(RecoveryFormViewModel());
  late final returnFormViewModel = Get.put(ReturnFormViewModel());
  late final attendanceViewModel = Get.put(AttendanceViewModel());
  late final attendanceOutViewModel = Get.put(AttendanceOutViewModel());
  late final signUpController = Get.put(SignUpController());
  // final LocationViewModel locationVM = Get.find<LocationViewModel>();
  late final LocationViewModel locationVM;

  String user_id = '';
  String userName = '';

  @override
  void initState() {
    super.initState();
    // ✅ Initialize LocationViewModel safely
    locationVM = Get.isRegistered<LocationViewModel>()
        ? Get.find<LocationViewModel>()
        : Get.put(LocationViewModel());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ForceUpdateService.check(context);
    });

    _retrieveSavedValues();

    addShopViewModel.fetchAllAddShop(); // → Shops
    shopVisitViewModel.fetchAllShopVisit(); // → Visit list
    shopVisitViewModel.fetchTotalShopVisit(); // → Visit COUNT (dashboard)
    shopVisitDetailsViewModel.initializeProductData();

    orderMasterViewModel.fetchAllOrderMaster(); // → Orders
    orderMasterViewModel.fetchTotalDispatched(); // → Dispatched

    recoveryFormViewModel.fetchAllRecoveryForm(); // → Recovery
    returnFormViewModel.fetchAllReturnForm(); // → Returns

    attendanceViewModel.fetchAllAttendance(); // → Attendance IN
    attendanceOutViewModel.fetchAllAttendanceOut(); // (optional OUT)

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
      user_id = prefs.getString('userId') ?? '';
      userName = prefs.getString('userName') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    // Set working status false on home screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final travelTimeVM = Get.find<TravelTimeViewModel>();
      travelTimeVM.setWorkingScreenStatus(false);
    });

    return WillPopScope(
      onWillPop: () async => false,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.blueGrey.shade50,
          body: LayoutBuilder(
            builder: (context, constraints) {
              // Responsive horizontal padding
              final horizontalPadding =
                  constraints.maxWidth < 400 ? 12.0 : 20.0;
              final spacingBetweenRows =
                  constraints.maxWidth < 400 ? 12.0 : 15.0;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 10),
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: TimerCard(),
                    ),
                    SizedBox(height: spacingBetweenRows),
                    _buildQuickActions(horizontalPadding: horizontalPadding),
                    SizedBox(height: 20),
                    TodayStatsCard(),
                    SizedBox(
                      height: 20,
                    ),
                    _buildPerformanceOverview(
                        horizontalPadding: horizontalPadding),
                    const SizedBox(height: 20),
                    DailyTimeCircularCard(),
                    SizedBox(
                      height: 20,
                    ),
                    _buildFooter(),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.blueGrey.shade500,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        children: [
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
              Navbar(),
              const SizedBox(height: 20),
              const ProfileSection(),
            ],
          ),
        ],
      ),
    );
  }

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
                icon: LucideIcons.store,
                label: 'Add Shop',
                onTap: () {
                  if (locationVM.isClockedIn.value) {
                    Get.to(() => AddShopScreen());
                  } else {
                    _showClockInRequiredDialog();
                  }
                },
              ),
              SizedBox(width: 10),
              _actionTile(
                icon: LucideIcons.building,
                label: 'Shop Visit',
                onTap: () {
                  if (locationVM.isClockedIn.value) {
                    Get.to(() => const ShopVisitScreen());
                  } else {
                    _showClockInRequiredDialog();
                  }
                },
              ),
              SizedBox(width: 10),
              _actionTile(
                icon: LucideIcons.refreshCcw,
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
                icon: LucideIcons.wallet,
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
              SizedBox(width: 10),
              _actionTile(
                icon: LucideIcons.clipboardCheck,
                label: 'Booking Status',
                onTap: () async {
                  await orderMasterViewModel.fetchAllOrderMaster();
                  Get.to(() => OrderBookingStatusScreen());
                },
              ),
              SizedBox(width: 10),
              _actionTile(
                icon: LucideIcons.calendarDays,
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
          height: 100, // FIXED HEIGHT as requested
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueGrey,
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: Colors.white,
                ),
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

  Widget _buildPerformanceOverview({required double horizontalPadding}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Summary",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade800,
            ),
          ),
          const SizedBox(height: 10),
          Obx(() {
            // final totalShops = addShopViewModel.allAddShop.length;
            // final totalVisits = shopVisitViewModel.apiShopVisitsCount.value;
            // final totalOrders = orderMasterViewModel.allOrderMaster.length;
            // final dispatched = orderMasterViewModel.apiDispatchedCount.value;
            // final totalRecovery = recoveryFormViewModel.allRecoveryForm.length;
            // final totalReturns = returnFormViewModel.allReturnForm.length;
            // final attendanceIn = attendanceViewModel.allAttendance.length;
            final totalShops = addShopViewModel.allAddShop.length;
            final totalVisits = shopVisitViewModel.apiShopVisitsCount.value;
            final totalOrders = orderMasterViewModel.allOrderMaster.length;
            final dispatched = orderMasterViewModel.apiDispatchedCount.value;
            final totalRecovery = recoveryFormViewModel.allRecoveryForm.length;
            final totalReturns = returnFormViewModel.allReturnForm.length;
            final attendanceIn = attendanceViewModel.allAttendance.length;
            // final totalBookings  = bookingViewModel.allBookings.length; // agar booking module hai

            return SizedBox(
              height: 180, // FIXED HEIGHT as requested
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueGrey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueGrey.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.0,
                  ),
                  children: [
                    _statGridItem(
                      "Shops",
                      totalShops,
                      Icons.store_outlined,
                      onTap: () => Get.to(() => AddShopReportScreen()),
                    ),

                    _statGridItem(
                      "Visits",
                      totalVisits,
                      Icons.directions_walk_outlined,
                      onTap: () => Get.to(() => ShopVisitReportDashboard()),
                    ),

                    _statGridItem(
                      "Orders",
                      totalOrders,
                      Icons.shopping_cart_outlined,
                      onTap: () => Get.to(() => OrderReportScreen()),
                    ),

                    _statGridItem("Dispatched", dispatched,
                        Icons.local_shipping_outlined,
                      onTap: () => Get.to(() => DispatchOrdersDashboard()),
                    ),

                    _statGridItem("Returns", totalReturns,
                        Icons.assignment_return_outlined),

                    _statGridItem(
                        "Recovery", totalRecovery, Icons.attach_money_outlined,
                        onTap: () => Get.to(() => RecoveryFormDashboard()),
                    ),

                    _statGridItem(
                      "Attendance",
                      attendanceIn,
                      Icons.punch_clock_outlined,
                      onTap: () => Get.to(() => AttendanceRecordScreen()),
                    ),

                    _statGridItem(
                      "Bookings",
                      totalOrders,
                      Icons.book,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _statGridItem(String label, int value, IconData icon,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blueGrey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: Colors.blueGrey,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      value.toString(),
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.blueGrey.shade800,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          "$version",
          style: const TextStyle(
            // fontSize: fontSize - 1,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  void _showClockInRequiredDialog() {
    Get.defaultDialog(
      title: "Clock In Required",
      titleStyle:
          const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey),
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

// Foreground task handler
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
