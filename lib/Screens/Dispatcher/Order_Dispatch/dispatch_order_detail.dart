
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OrderDetailsScreen extends StatefulWidget {
  final String dispatch_no;
  final String shopName;

  const OrderDetailsScreen({
    Key? key,
    required this.dispatch_no,
    required this.shopName,
  }) : super(key: key);

  @override
  _OrderDetailsScreenState createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> orderDetails = [];
  String errorMessage = '';
  Map<String, dynamic>? apiMetadata; // Store metadata like count, hasMore, etc.

  @override
  void initState() {
    super.initState();
    fetchOrderDetails();
  }

  Future<void> fetchOrderDetails() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final String baseUrl = 'https://cloud.metaxperts.net:8443/erp/valor_trading';
      final String url = '$baseUrl/dispatchdetailget/get/${widget.dispatch_no}';
      debugPrint('🔗 Fetching order details from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      debugPrint('📊 Order Details API Status: ${response.statusCode}');
      debugPrint('📊 Order Details Response: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic rawResponse = json.decode(response.body);
        List<Map<String, dynamic>> processedDetails = [];
        Map<String, dynamic> metadata = {};

        if (rawResponse is Map) {
          final mapResponse = Map<String, dynamic>.from(rawResponse);

          // Store metadata
          metadata = {
            'count': mapResponse['count'],
            'hasMore': mapResponse['hasMore'],
            'limit': mapResponse['limit'],
            'offset': mapResponse['offset'],
          };
          debugPrint('📋 API Metadata: $metadata');

          // Extract items array
          if (mapResponse.containsKey('items') && mapResponse['items'] is List) {
            debugPrint('✅ Found ${(mapResponse['items'] as List).length} items in "items" key');
            final itemsList = mapResponse['items'] as List;

            for (var item in itemsList) {
              if (item is Map) {
                processedDetails.add(Map<String, dynamic>.from(item));
                debugPrint('📦 Item: ${item['product'] ?? item['product_name'] ?? 'Unknown'}');
              }
            }
          } else {
            // Fallback: Try other possible keys
            List<String> possibleKeys = [
              'data',
              'details',
              'order_details',
              'orderDetails',
              'records',
              'dispatch_details',
              'dispatchDetails'
            ];

            bool found = false;
            for (var key in possibleKeys) {
              if (mapResponse.containsKey(key) && mapResponse[key] is List) {
                debugPrint('✅ Found data in key: "$key"');
                final dataList = mapResponse[key] as List;
                for (var item in dataList) {
                  if (item is Map) {
                    processedDetails.add(Map<String, dynamic>.from(item));
                  }
                }
                found = true;
                break;
              }
            }

            if (!found) {
              debugPrint('⚠️ No standard key found. Response structure:');
              mapResponse.forEach((key, value) {
                debugPrint('  Key: "$key" => Type: ${value.runtimeType}');
                if (value is List) {
                  debugPrint('    List length: ${value.length}');
                }
              });
            }
          }
        } else if (rawResponse is List) {
          // Direct array response
          debugPrint('✅ Direct array response with ${rawResponse.length} items');
          for (var item in rawResponse) {
            if (item is Map) {
              processedDetails.add(Map<String, dynamic>.from(item));
            }
          }
        }

        setState(() {
          orderDetails = processedDetails;
          apiMetadata = metadata;
          isLoading = false;
        });

        debugPrint('✅ Successfully loaded ${orderDetails.length} order detail items');

        if (orderDetails.isEmpty) {
          debugPrint('⚠️ WARNING: No items found in the response!');
          debugPrint('⚠️ Raw response type: ${rawResponse.runtimeType}');
          if (rawResponse is Map) {
            debugPrint('⚠️ Available keys: ${(rawResponse as Map).keys.toList()}');
          }
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Order Details API Error: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
      Get.snackbar(
        'Error',
        'Failed to load order details: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    }
  }

  double _calculateTotalAmount() {
    double total = 0;
    for (var item in orderDetails) {
      final amount = item['amount'] ??
          item['total_price'] ??
          item['total'] ?? 0;
      total += double.tryParse(amount.toString()) ?? 0;
    }
    return total;
  }

  double _calculateTotalQuantity() {
    double total = 0;
    for (var item in orderDetails) {
      final qty = item['quantity'] ?? item['qty'] ?? 0;
      total += double.tryParse(qty.toString()) ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blueGrey[700],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.shopName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchOrderDetails,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blueGrey),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading order details...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                'Failed to Load Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: fetchOrderDetails,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Summary Header - only show when there are items
        if (orderDetails.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueGrey[700]!, Colors.blueGrey[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Dispatch #${widget.dispatch_no}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (apiMetadata != null && apiMetadata!['count'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Total Records: ${apiMetadata!['count']}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSummaryCard(
                      'Total Items',
                      orderDetails.length.toString(),
                      Icons.shopping_cart_outlined,
                    ),
                    _buildSummaryCard(
                      'Total Quantity',
                      _calculateTotalQuantity().toStringAsFixed(0),
                      Icons.inventory_2_outlined,
                    ),
                    _buildSummaryCard(
                      'Total Amount',
                      _calculateTotalAmount().toStringAsFixed(2),
                      Icons.attach_money,
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Order Items List or Empty State
        Expanded(
          child: orderDetails.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
            onRefresh: fetchOrderDetails,
            color: Colors.blueGrey,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orderDetails.length,
              itemBuilder: (context, index) {
                final item = orderDetails[index];
                return _buildOrderItemCard(item, index + 1);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: Colors.orange[300],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Order Items Found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This dispatch order doesn\'t have any items yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'API Details',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dispatch #${widget.dispatch_no}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Endpoint: dispatchdetailget/get/${widget.dispatch_no}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (apiMetadata != null && apiMetadata!['count'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'API Count: ${apiMetadata!['count']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Possible Reasons:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              _buildReasonItem('• Order items not yet added to this dispatch'),
              _buildReasonItem('• Items may be in a different system/table'),
              _buildReasonItem('• Dispatch is pending item assignment'),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: fetchOrderDetails,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blueGrey,
                  side: BorderSide(color: Colors.blueGrey[300]!),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReasonItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Icon(icon, color: Colors.white, size: 15),
          // const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemCard(Map<String, dynamic> item, int itemNumber) {
    // Extract all possible field variations
    final productName = item['product'] ??
        item['product_name'] ??
        item['item_name'] ??
        'Unknown Product';

    final productCode = item['product_code'] ??
        item['item_code'] ??
        item['order_details_id'];

    final quantity = item['quantity'] ?? item['qty'] ?? 'N/A';
    final rate = item['rate'] ?? item['unit_price'] ?? item['price'] ?? 'N/A';
    final amount = item['amount'] ?? item['total_price'] ?? item['total'] ?? 'N/A';
    final orderMasterId = item['order_master_id'];
    final orderDetailsDate = item['order_details_date'];
    final dispatchDate = item['dispatch_date'];
    final dispatchedBy = item['dispatched_by'];
    final approvalStatus = item['approval_status'];
    final inStock = item['in_stock'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueGrey[50]!, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#$itemNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName.toString(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (productCode != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Code: $productCode',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Status badge if available
                if (approvalStatus != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: approvalStatus.toString().toUpperCase() == 'PENDING'
                          ? Colors.orange[100]
                          : approvalStatus.toString().toUpperCase() == 'APPROVED'
                          ? Colors.green[100]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      approvalStatus.toString(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: approvalStatus.toString().toUpperCase() == 'PENDING'
                            ? Colors.orange[900]
                            : approvalStatus.toString().toUpperCase() == 'APPROVED'
                            ? Colors.green[900]
                            : Colors.grey[900],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Item Details
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildDetailRow(
                  'Quantity',
                  quantity,
                  Icons.inventory_2_outlined,
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Rate',
                  rate,
                  Icons.price_change_outlined,
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Amount',
                  amount,
                  Icons.attach_money,
                  isHighlight: true,
                ),
                if (orderMasterId != null) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Order Master ID',
                    orderMasterId,
                    Icons.receipt_long_outlined,
                  ),
                ],
                if (orderDetailsDate != null) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Order Date',
                    orderDetailsDate,
                    Icons.calendar_today_outlined,
                  ),
                ],
                // if (dispatchDate != null) ...[
                //   const SizedBox(height: 8),
                //   _buildDetailRow(
                //     'Dispatch Date',
                //     dispatchDate,
                //     Icons.local_shipping_outlined,
                //   ),
                // ],
                // if (dispatchedBy != null) ...[
                //   const SizedBox(height: 8),
                //   _buildDetailRow(
                //     'Dispatched By',
                //     dispatchedBy,
                //     Icons.person_outline,
                //   ),
                // ],
                if (inStock != null) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'In Stock',
                    inStock,
                    Icons.warehouse_outlined,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      String label,
      dynamic value,
      IconData icon, {
        bool isHighlight = false,
      }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlight ? Colors.green[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlight ? Colors.green[200]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isHighlight ? Colors.green[700] : Colors.blueGrey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isHighlight ? Colors.green[900] : Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value?.toString() ?? 'N/A',
              style: TextStyle(
                fontSize: 14,
                color: isHighlight ? Colors.green[900] : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}