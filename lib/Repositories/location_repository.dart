
import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Databases/dp_helper.dart';
import '../Databases/util.dart';
import '../Models/location_model.dart';
import '../Services/ApiServices/api_service.dart';
import '../Services/ApiServices/serial_number_genterator.dart';
import '../Services/FirebaseServices/firebase_remote_config.dart';

class LocationRepository {
  DBHelper dbHelper = DBHelper();

  Future<List<LocationModel>> getLocation() async {
    var dbClient = await dbHelper.db;
    List<Map> maps = await dbClient.query(locationTableName, columns: [
      'location_id',
      'location_date',
      'location_time',
      'file_name',
      'user_id',
      'booker_name',
      'total_distance',
      'body',
      'posted'
    ]);
    List<LocationModel> location = [];
    for (int i = 0; i < maps.length; i++) {
      location.add(LocationModel.fromMap(maps[i]));
    }

    debugPrint('Raw data from Location database:');

    // ignore: unused_local_variable
    for (var map in maps) {

      debugPrint("$map");

    }
    return location;
  }

  Future<void> fetchAndSaveLocation() async {
    await Config.fetchLatestConfig();
    debugPrint('${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.getApiUrlLocation}$user_id');
    List<dynamic> data = await ApiService.getData('${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.getApiUrlLocation}$user_id');
    var dbClient = await dbHelper.db;

    // Save data to database
    for (var item in data) {
      item['posted'] = 1; // Set posted to 1
      LocationModel model = LocationModel.fromMap(item);
      await dbClient.insert(locationTableName, model.toMap());
    }
  }

  Future<List<LocationModel>> getUnPostedLocation() async {
    var dbClient = await dbHelper.db;
    List<Map> maps = await dbClient.query(
      locationTableName,
      where: 'posted = ?',
      whereArgs: [0],  // Fetch machines that have not been posted
    );

    List<LocationModel> attendanceIn = maps.map((map) => LocationModel.fromMap(map)).toList();
    return attendanceIn;
  }

  Future<void> postDataFromDatabaseToAPI() async {
    try {
      var unPostedShops = await getUnPostedLocation();

      if (await isNetworkAvailable()) {
        for (var shop in unPostedShops) {
          try {
            await postShopToAPI(shop, shop.body!);
            shop.posted = 1;
            await update(shop);

            debugPrint('Shop with id ${shop.location_id} posted and updated in local database.');

          }
          catch (e)
          {

            debugPrint('Failed to post shop with id ${shop.location_id}: $e');

          }
        }
      } else {

        debugPrint('Network not available. Unposted shops will remain local.');

      }
    } catch (e) {

      debugPrint('Error fetching unposted shops: $e');

    }
  }


  Future<void> postShopToAPI(LocationModel shop, Uint8List imageBytes) async {
    try {
      await Config.fetchLatestConfig();

      debugPrint('Updated Shop Post API: ${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.postApiUrlLocation}');

      var shopData = shop.toMap();

      var request = http.MultipartRequest(
          'POST',
          Uri.parse('${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.postApiUrlLocation}'
          ));

      request.headers['Content-Type'] = 'multipart/form-data';
      request.headers['Accept'] = 'application/json';

      request.fields.addAll(shopData.map((key, value) => MapEntry(key, value.toString())));

      // ignore: unnecessary_null_comparison
      if (imageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'body',
            imageBytes,
            // Change 'body/jpeg' to 'application/gpx+xml'
            contentType: MediaType('application', 'gpx+xml'),
          ),
        );
      }

      final response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Shop data posted successfully: ${shop.toMap()}');
        await delete(shop.location_id!);

        debugPrint('location_id with id ${shop.location_id} deleted from local database.');

      } else {
        final responseBody = await response.stream.bytesToString();
        throw Exception('Server error: ${response.statusCode}, $responseBody');
      }
    } catch (e) {
      print('Error posting shop data: $e');
      throw Exception('Failed to post data: $e');
    }
  }

  // Future<void> postShopToAPI(LocationModel shop) async {
  //   try {
  //     await Config.fetchLatestConfig();
  //     if (kDebugMode) {
  //       print('Updated Shop Post API: ${Config.getApiUrlServerIP}{Config.getApiUrlERPCompanyName}{Config.postApiUrlLocation}');
  //     }
  //     var shopData = shop.toMap();
  //     final response = await http.post(
  //       Uri.parse(Config.getApiUrlServerIP}{Config.getApiUrlERPCompanyName}{Config.postApiUrlLocation),
  //       headers: {
  //         "Content-Type": "application/json",
  //         "Accept": "application/json",
  //       },
  //       body: jsonEncode(shopData),
  //     );
  //
  //     if (response.statusCode == 200 || response.statusCode == 201) {
  //       print('Shop data posted successfully: $shopData');
  //     } else {
  //       throw Exception('Server error: ${response.statusCode}, ${response.body}');
  //     }
  //   } catch (e) {
  //     print('Error posting shop data: $e');
  //     throw Exception('Failed to post data: $e');
  //   }
  // }
  Future<int> add(LocationModel locationModel) async {
    var dbClient = await dbHelper.db;
    return await dbClient.insert(locationTableName, locationModel.toMap());
  }

  Future<int> update(LocationModel locationModel) async {
    var dbClient = await dbHelper.db;
    return await dbClient.update(locationTableName, locationModel.toMap(),
        where: 'location_id = ?', whereArgs: [locationModel.location_id]);
  }

  Future<int> delete(String id) async {
    var dbClient = await dbHelper.db;
    return await dbClient
        .delete(locationTableName, where: 'location_id = ?', whereArgs: [id]);
  }
  Future<void> serialNumberGeneratorApi() async {
    await Config.fetchLatestConfig();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final orderDetailsGenerator = SerialNumberGenerator(
      apiUrl: '${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.getApiUrlLocationSerial}$user_id',
      maxColumnName: 'max(location_id)',
      serialType: locationHighestSerial, // Unique identifier for shop visit serials
    );
    await orderDetailsGenerator.getAndIncrementSerialNumber();
    locationHighestSerial = orderDetailsGenerator.serialType;
    await prefs.reload();
    await prefs.setInt("locationHighestSerial", locationHighestSerial!);

  }
}
