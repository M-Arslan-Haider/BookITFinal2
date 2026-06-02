

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Databases/dp_helper.dart';
import '../Databases/util.dart';
import '../Models/order_details_model.dart';
import '../Services/ApiServices/api_service.dart';
import '../Services/ApiServices/serial_number_genterator.dart';
import '../Services/FirebaseServices/firebase_remote_config.dart';

class OrderDetailsRepository extends GetxService {
  DBHelper dbHelper = DBHelper();

  Future<List<OrderDetailsModel>> getReConfirmOrder() async {
    var dbClient = await dbHelper.db;
    List<Map> maps = await dbClient.query(orderDetailsTableName, columns: [
      'order_details_id',
      'order_details_date',
      'order_details_time',
      'product',
      'quantity',
      'in_stock',
      'rate',
      'amount',
      'order_master_id',
      'user_id',
      'posted'
    ]);
    List<OrderDetailsModel> reconfirmorder = [];
    for (int i = 0; i < maps.length; i++) {
      reconfirmorder.add(OrderDetailsModel.fromMap(maps[i]));
    }

    debugPrint('OrderDetails Raw data from database:');

    for (var map in maps) {
      debugPrint("OrderDetails: $map");
    }
    return reconfirmorder;
  }

  fetchAndSaveOrderDetails() async {
    await Config.fetchLatestConfig();
    debugPrint('${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.getApiUrlOrderDetails}$user_id');
    List<dynamic> data = await ApiService.getData('${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.getApiUrlOrderDetails}$user_id');
    var dbClient = await dbHelper.db;

    // Save data to database
    for (var item in data) {
      item['posted'] = 1; // Set posted to 1
      OrderDetailsModel model = OrderDetailsModel.fromMap(item);
      await dbClient.insert(orderDetailsTableName, model.toMap());
    }
  }

  Future<List<OrderDetailsModel>> getUnPostedOrderDetails() async {
    var dbClient = await dbHelper.db;
    List<Map> maps = await dbClient.query(
      orderDetailsTableName,
      where: 'posted = ?',
      whereArgs: [0],  // Fetch machines that have not been posted
    );

    List<OrderDetailsModel> attendanceIn = maps.map((map) => OrderDetailsModel.fromMap(map)).toList();
    return attendanceIn;
  }

  Future<int> add(OrderDetailsModel orderDetailsModel) async {
    var dbClient = await dbHelper.db;
    int result =
    await dbClient.insert(orderDetailsTableName, orderDetailsModel.toMap());

    debugPrint('Inserted OrderDetailsModel: ${orderDetailsModel.toMap()}');

    return result;
  }

  Future<void> postDataFromDatabaseToAPI() async {
    try {
      var unPostedShops = await getUnPostedOrderDetails();

      if (await isNetworkAvailable()) {
        for (var shop in unPostedShops) {
          try {
            await postShopToAPI(shop);
            shop.posted = 1;
            await update(shop);

            debugPrint('Shop with id ${shop.order_details_id} posted and updated in local database.');
          } catch (e) {
            debugPrint('Failed to post shop with id ${shop.order_details_id}: $e');
          }
        }
      } else {
        debugPrint('Network not available. Unposted shops will remain local.');
      }
    } catch (e) {
      debugPrint('Error fetching unposted shops: $e');
    }
  }

  Future<void> postShopToAPI(OrderDetailsModel shop) async {
    try {
      await Config.fetchLatestConfig();

      debugPrint('Updated Shop Post API: ${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.postApiUrlOrderDetails}');

      var shopData = shop.toMap();
      final response = await http.post(
        Uri.parse("${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.postApiUrlOrderDetails}"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(shopData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Shop data posted successfully: $shopData');
      } else {
        throw Exception('Server error: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      debugPrint('Error posting shop data: $e');
      throw Exception('Failed to post data: $e');
    }
  }

  Future<int> update(OrderDetailsModel orderDetailsModel) async {
    var dbClient = await dbHelper.db;
    return await dbClient.update(
        orderDetailsTableName, orderDetailsModel.toMap(),
        where: 'order_details_id = ?', whereArgs: [orderDetailsModel.order_details_id]);
  }

  Future<int> delete(int id) async {
    var dbClient = await dbHelper.db;
    return await dbClient
        .delete(orderDetailsTableName, where: 'order_details_id = ?', whereArgs: [id]);
  }

  Future<void> getHighestSerialNo() async {
    int serial;

    final db = await dbHelper.db;
    final result = await db!.rawQuery('''
    SELECT order_details_id 
    FROM $orderDetailsTableName
    WHERE user_id = ? AND order_details_id IS NOT NULL
  ''', [user_id]);

    if (result.isNotEmpty) {
      // Extract the serial numbers from the order_details_id strings
      final serialNos = result.map((row) {
        final orderNo = row['order_details_id'] as String?;
        if (orderNo != null) {
          final parts = orderNo.split('-');
          if (parts.length > 2) {
            final serialNoPart = parts.last;
            if (serialNoPart.isNotEmpty) {
              return int.tryParse(serialNoPart);
            }
          }
        }
        return null;
      }).where((serialNo) => serialNo != null).cast<int>().toList();

      // Find and set the maximum serial number
      if (serialNos.isNotEmpty) {
        serial = serialNos.reduce(max);
        serial++; // Increment the highest serial number
        orderDetailsHighestSerial = serial;

        // PERSIST THIS VALUE IMMEDIATELY
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setInt("orderDetailsHighestSerial", orderDetailsHighestSerial!);

        if (kDebugMode) {
          print('Highest serial number orderDetailsHighestSerial incremented to: $orderDetailsHighestSerial');
        }
      } else {
        if (kDebugMode) {
          print('No valid order numbers found for this user');
        }
      }
    } else {
      if (kDebugMode) {
        print('No orders found for this user');
      }
    }
  }

  Future<void> serialNumberGeneratorApi() async {
    await Config.fetchLatestConfig();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final orderDetailsGenerator = SerialNumberGenerator(
      apiUrl: '${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.getApiUrlOrderDetailsSerial}$user_id',
      maxColumnName: 'max(order_details_id)',
      serialType: orderDetailsHighestSerial, // Unique identifier for shop visit serials
    );
    await orderDetailsGenerator.getAndIncrementSerialNumber();
    orderDetailsHighestSerial = orderDetailsGenerator.serialType;
    await prefs.reload();
    await prefs.setInt("orderDetailsHighestSerial", orderDetailsHighestSerial!);
  }
}