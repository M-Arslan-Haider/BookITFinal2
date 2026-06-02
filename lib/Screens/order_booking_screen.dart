
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:order_booking_app/ViewModels/order_details_view_model.dart';
import 'package:order_booking_app/ViewModels/order_master_view_model.dart';
import 'package:order_booking_app/ViewModels/shop_visit_view_model.dart';
import '../widgets/rounded_button.dart';
import 'Components/custom_dropdown.dart';
import 'Components/custom_editable_menu_option.dart';
import 'OrderBookingScreenComponents/order_master_product_search_card.dart';

class OrderBookingScreen extends StatefulWidget {
  const OrderBookingScreen({super.key});

  @override
  _OrderBookingScreenState createState() => _OrderBookingScreenState();
}

class _OrderBookingScreenState extends State<OrderBookingScreen> {
  final OrderMasterViewModel orderMasterViewModel = Get.put(OrderMasterViewModel());
  final OrderDetailsViewModel orderDetailsViewModel = Get.put(OrderDetailsViewModel());
  final ShopVisitViewModel shopVisitViewModel = Get.put(ShopVisitViewModel());
  final _formKey = GlobalKey<FormState>();

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
    orderDetailsViewModel.initializeProductData();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.blueGrey.shade50,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Order Booking Form',
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
          onPressed: () {
            Get.offNamed("/home");
          },
        ),
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
                            Icons.shopping_cart_rounded,
                            size: isSmallScreen ? 42 : 52,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Order Information',
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
                          key: _formKey,
                          child: Padding(
                            padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Shop Information Section
                                _buildSectionHeader(
                                    'Shop Information', Icons.store),
                                const SizedBox(height: 16),

                                _buildReadOnlyTextField(
                                  label: "Shop Name",
                                  text: shopVisitViewModel.selectedShop.value,
                                  icon: Icons.warehouse,
                                ),

                                _buildReadOnlyTextField(
                                  label: "Owner Name",
                                  text: shopVisitViewModel.owner_name.value,
                                  icon: Icons.person_outlined,
                                ),

                                _buildReadOnlyTextField(
                                  label: "Phone Number",
                                  text: shopVisitViewModel.phone_number.value,
                                  icon: Icons.phone,
                                ),

                                _buildReadOnlyTextField(
                                  label: "Brand",
                                  text: shopVisitViewModel.selectedBrand.value,
                                  icon: Icons.branding_watermark,
                                ),

                                const SizedBox(height: 24),

                                // Products Section
                                _buildSectionHeader('Products', Icons.inventory),
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
                                  child: OrderMasterProductSearchCard(
                                    filterData: orderDetailsViewModel.filterData,
                                    rowsNotifier: orderDetailsViewModel.rowsNotifier,
                                    filteredRows: orderDetailsViewModel.filteredRows,
                                    orderDetailsViewModel: orderDetailsViewModel,
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Order Summary Section
                                _buildSectionHeader('Order Summary', Icons.summarize),
                                const SizedBox(height: 16),

                                Obx(() => _buildTotalField(
                                  label: "Total",
                                  value: orderDetailsViewModel.total.value,
                                  icon: Icons.money,
                                )),

                                const SizedBox(height: 16),

                                _buildCreditLimitDropdown(),

                                const SizedBox(height: 16),

                                Obx(() => _buildDeliveryDateField(context)),

                                SizedBox(height: isSmallScreen ? 24 : 32),

                                // Confirm Button
                                // Center(
                                //   child: Container(
                                //     width: isSmallScreen
                                //         ? size.width * 0.6
                                //         : size.width * 0.3,
                                //     constraints: const BoxConstraints(
                                //       maxWidth: 300,
                                //       minWidth: 150,
                                //     ),
                                //     child: RoundedButton(
                                //       text: 'Confirm',
                                //       press: () {
                                //         if (_formKey.currentState!.validate()) {
                                //           orderMasterViewModel.submitForm(_formKey);
                                //         }
                                //       },
                                //       // color: Colors.blueGrey,
                                //       // textColor: Colors.white,
                                //     ),
                                //   ),
                                // ),
                                Center(
                                  child: Container(
                                    width: isSmallScreen
                                        ? size.width * 0.6
                                        : size.width * 0.3,
                                    constraints: const BoxConstraints(
                                      maxWidth: 300,
                                      minWidth: 150,
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        if (_formKey.currentState!.validate()) {
                                          orderMasterViewModel.submitForm(_formKey);
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueGrey,
                                        foregroundColor: Colors.white,
                                        elevation: 4,
                                        shadowColor: Colors.blueGrey.withOpacity(0.3),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          vertical: isSmallScreen ? 14 : 16,
                                          horizontal: 32,
                                        ),
                                        minimumSize: const Size(150, 50),
                                      ),
                                      child: Text(
                                        'Confirm',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 16 : 18,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
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

  Widget _buildReadOnlyTextField({
    required String label,
    required String text,
    required IconData icon,
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
                      text.isEmpty ? "Not available" : text,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 15 : 16,
                        fontWeight: FontWeight.w500,
                        color: text.isEmpty
                            ? Colors.blueGrey.shade300
                            : Colors.blueGrey.shade800,
                      ),
                    ),
                  ),
                  if (text.isNotEmpty)
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

  Widget _buildTotalField({
    required String label,
    required String value,
    required IconData icon,
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
                      value.isEmpty ? "0.00" : value,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 15 : 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditLimitDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Credit Limit",
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
              label: "Credit Limit",
              icon: Icons.payment,
              items: orderMasterViewModel.credits,
              selectedValue:
              orderMasterViewModel.credit_limit.value.isNotEmpty
                  ? orderMasterViewModel.credit_limit.value
                  : "Credit Limit",
              onChanged: (value) {
                orderMasterViewModel.credit_limit.value = value!;
                if (kDebugMode) {
                  debugPrint(
                      "Selected: ${orderMasterViewModel.credit_limit.value}");
                }
              },
              useBoxShadow: false,
              validator: (value) => value == null || value.isEmpty
                  ? 'Please select a credit limit'
                  : null,
              inputBorder: InputBorder.none,
              maxHeight: 50.0,
              maxWidth: 360.0,
              iconSize: isSmallScreen ? 20 : 22,
              contentPadding: 6.0,
              iconColor: Colors.blueGrey,
              textStyle: TextStyle(
                fontSize: isSmallScreen ? 14 : 15,
                fontWeight: FontWeight.w500,
                color: Colors.blueGrey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryDateField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Required Delivery",
            style: TextStyle(
              color: Colors.blueGrey.shade600,
              fontSize: isSmallScreen ? 13 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              DateTime today = DateTime.now();
              DateTime firstDate =
              DateTime(today.year, today.month, today.day); // Strip time

              DateTime? selectedDate = await showDatePicker(
                context: context,
                initialDate: firstDate,
                firstDate: firstDate,
                lastDate: DateTime(2100),
              );
              if (selectedDate != null) {
                String formattedDate =
                    "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
                orderMasterViewModel.required_delivery_date.value =
                    formattedDate;
              }
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                border: Border.all(
                  color: Colors.blueGrey.shade200,
                  width: 1,
                ),
                color: Colors.blueGrey.shade50,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Colors.blueGrey,
                      size: isSmallScreen ? 20 : 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        orderMasterViewModel.required_delivery_date.isNotEmpty
                            ? orderMasterViewModel.required_delivery_date.value
                            : "Select a date",
                        style: TextStyle(
                          fontSize: isSmallScreen ? 15 : 16,
                          fontWeight: FontWeight.w500,
                          color: orderMasterViewModel
                              .required_delivery_date.value.isEmpty
                              ? Colors.blueGrey.shade300
                              : Colors.blueGrey.shade800,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.calendar_month,
                      size: isSmallScreen ? 16 : 18,
                      color: Colors.blueGrey,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}