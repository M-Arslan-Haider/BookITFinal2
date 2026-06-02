import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


import 'package:shared_preferences/shared_preferences.dart';

import '../../Databases/util.dart';
import '../../Models/Bookers_RSM_SM_NSM_Models/ShopStatusModel.dart';
import '../../Services/FirebaseServices/firebase_remote_config.dart';
import '../../main.dart';
import '../SM/shop_details_page.dart';
class NSMShopDetailPage extends StatefulWidget {
  @override
  _NSMShopDetailPageState createState() => _NSMShopDetailPageState();
}


class _NSMShopDetailPageState extends State<NSMShopDetailPage> {

  List<ShopStatusModel> _allShops = [];
  List<ShopStatusModel> _filteredShops = [];
  final List<ShopStatusModel> _displayedShops = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    print(user_id);
    _loadData();
  }
  Future<void> _loadData() async {
    bool isConnected = await isNetworkAvailable();
    if (isConnected) {
      bool newDataFetched = await _fetchAndSaveData();
      if (newDataFetched) {
        await _loadBookersData();
        _filteredShops = _allShops;
        _addBookersToList(_filteredShops);
      } else {
        await _loadBookersData();
        _filteredShops = _allShops;
        _addBookersToList(_filteredShops);
      }
    } else {
      await _loadBookersData();
      _filteredShops = _allShops;
      _addBookersToList(_filteredShops);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? lastSyncTime = prefs.getString('last_NSMshop_sync_time');
      if (lastSyncTime != null) {
        DateTime syncDateTime = DateTime.parse(lastSyncTime);
        String formattedTime = "${syncDateTime.toLocal()}";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Last sync: $formattedTime')),
        );
      }
    }
  }

  Future<bool> _fetchAndSaveData() async {
    await Config.fetchLatestConfig();
    final url =
        "${Config.getApiUrlServerIP}${Config.getApiUrlERPCompanyName}${Config.getApiUrlNsmShop}$user_id";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body)['items'];
      List<ShopStatusModel> fetchedShops = data.map<ShopStatusModel>((json) => ShopStatusModel.fromJson(json)).toList();

      // Compare with existing data to check if new data is fetched
      bool isNewData = _hasNewData(fetchedShops, _allShops);

      if (isNewData) {
        _allShops = fetchedShops;
        await _saveBookersData();

        // Save the last sync timestamp
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_NSMshop_sync_time', DateTime.now().toIso8601String());
      }

      return isNewData;
    } else {
      throw Exception('Failed to load data');
    }
  }

  bool _hasNewData(List<ShopStatusModel> newData, List<ShopStatusModel> oldData) {
    if (newData.length != oldData.length) return true;
    for (int i = 0; i < newData.length; i++) {
      if (newData[i].toJson() != oldData[i].toJson()) return true;
    }
    return false;
  }

  Future<String?> _getLastSyncTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lastSyncTime = prefs.getString('last_NSMshop_sync_time');
    if (lastSyncTime != null) {
      DateTime syncDateTime = DateTime.parse(lastSyncTime);
      return "${syncDateTime.toLocal()}";
    }
    return null;
  }


  Future<void> _saveBookersData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String bookersJson = jsonEncode(_allShops.map((b) => b.toJson()).toList());
    prefs.setString('NSMshops_data', bookersJson);
  }

  Future<void> _loadBookersData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? bookersJson = prefs.getString('NSMshops_data');
    if (bookersJson != null) {
      List<dynamic> jsonList = jsonDecode(bookersJson);
      _allShops = jsonList.map((json) => ShopStatusModel.fromJson(json)).toList();
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final response = await http.get(Uri.parse('https://www.google.com'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void _addBookersToList(List<ShopStatusModel> bookers) async {
    for (int i = 0; i < bookers.length; i++) {
      if (!_displayedShops.contains(bookers[i])) {
        _displayedShops.add(bookers[i]);
        _listKey.currentState?.insertItem(_displayedShops.indexOf(bookers[i]), duration: const Duration(seconds: 1));
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  void _removeBookersFromList() async {
    for (int i = _displayedShops.length - 1; i >= 0; i--) {
      final removedShop = _displayedShops.removeAt(i);
      _listKey.currentState?.removeItem(
        i,
            (context, animation) => _buildShopCard(removedShop, animation),
        duration: const Duration(milliseconds: 300),
      );
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void _filterShops() {
    final nameFilter = _nameController.text.toLowerCase();
    final cityFilter = _cityController.text.toLowerCase();
    _filteredShops = _allShops.where((booker) {
      final matchesName = booker.name.toLowerCase().contains(nameFilter);
      final matchesStatus = booker.city.toLowerCase().contains(cityFilter);
      return matchesName && matchesStatus;
    }).toList();
    _removeBookersFromList();
    _addBookersToList(_filteredShops);
  }





  void showProfessionalDialog(BuildContext context, String message, IconData icon, Color backgroundColor, {String? actionText, VoidCallback? onActionPressed}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          elevation: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [backgroundColor.withOpacity(0.7), backgroundColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 36),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (actionText != null && onActionPressed != null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: backgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      elevation: 5,
                    ),
                    onPressed: onActionPressed,
                    child: Text(
                      actionText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }


  Future<void> _handleRefresh() async {
    try {
      bool isConnected = await isNetworkAvailable();

      if (isConnected) {
        // Set a timeout duration
        const timeoutDuration = Duration(seconds: 20);

        // Create a Future that will complete when data is loaded or timeout occurs
        Future<void> loadDataFuture = _loadData();

        // Run the loadDataFuture with a timeout
        await loadDataFuture.timeout(timeoutDuration, onTimeout: () {
          throw TimeoutException('Data loading took too long');
        });

        // Update the list after data is loaded
        setState(() {
          _filteredShops = _allShops;
          _removeBookersFromList();
          _addBookersToList(_filteredShops);
        });

        // Notify user of successful refresh
        showProfessionalDialog(
          context,
          'Data refreshed successfully!',
          Icons.check_circle_outline,
          Colors.blueGrey[600]!,

        );
      } else {
        // Notify user of connectivity issue
        showProfessionalDialog(
          context,
          'No internet connection. Please check your connection and try again.',
          Icons.signal_wifi_off,
          Colors.red[600]!,
          actionText: 'Retry',
          onActionPressed: () {
            Navigator.of(context).pop(); // Close the dialog
            _handleRefresh(); // Retry refreshing data
          },
        );
      }
    } catch (e) {
      // Handle timeout and other errors
      if (e is TimeoutException) {
        showProfessionalDialog(
          context,
          'Data refresh timed out. Please try again later.',
          Icons.timer_off,
          Colors.orange[600]!,
          actionText: 'Retry',
          onActionPressed: () {
            Navigator.of(context).pop(); // Close the dialog
            _handleRefresh(); // Retry refreshing data
          },
        );
      } else {
        // Handle any other errors
        if (kDebugMode) {
          print('Error during refresh: $e');
        }
        showProfessionalDialog(
          context,
          'Failed to refresh data. Please try again later.',
          Icons.error_outline,
          Colors.orange[600]!,
          actionText: 'Retry',
          onActionPressed: () {
            Navigator.of(context).pop(); // Close the dialog
            _handleRefresh(); // Retry refreshing data
          },
        );
      }
    }
  }




  Widget _buildTextField(String hint, TextEditingController controller, bool isDate, bool isReadOnly) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Card(
        elevation: 1.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(
              isDate ? Icons.calendar_today : Icons.search,
              color: Colors.blueGrey,
            ),
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.withOpacity(0.4), fontSize: 13),
            border: InputBorder.none,
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blueGrey, width: 0.1),
              borderRadius: BorderRadius.circular(10.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.0),
              borderRadius: BorderRadius.circular(10.0),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          ),
          keyboardType: isDate ? TextInputType.datetime : TextInputType.text,
          readOnly: isReadOnly,
          onChanged: (value) {
            _filterShops();
          },
        ),
      ),
    );
  }


  Widget _buildShopCard(ShopStatusModel shop, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShopDetailsPage(shop: shop),
            ),
          );
        },
        child: Card(
          margin: const EdgeInsets.all(1.0),
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: Row(

              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2.0),
                  child: SizedBox(
                    width: 45,
                    height: 45,
                    child: Image.asset(
                      'assets/icons/shop-svg-3.png', // Path to your vector image
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8.0),
                      Row(
                        children: [
                          const Icon(Icons.location_city, size: 10.0, color: Colors.blueGrey),
                          const SizedBox(width: 4.0),
                          Expanded(
                            child: Text('City: ${shop.city}', style: const TextStyle(fontSize: 10)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4.0),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 10.0, color: Colors.blueGrey),
                          const SizedBox(width: 4.0),
                          Expanded(
                            child: Text('Address: ${shop.address}', style: const TextStyle(fontSize: 10)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('NSM SHOP DETAIL', style: TextStyle(color: Colors.white),),
      backgroundColor: Colors.blueGrey,
      // 👇 Back arrow color
      iconTheme: const IconThemeData(
        color: Colors.white,
      ),
        ),
        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          child:  Column(
            children: [
              Column(
                children: [
                  _buildTextField('Search by Booker Name', _nameController, false, false),
                ],
              ),
                FutureBuilder<String?>(
                  future: _getLastSyncTime(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    } else if (snapshot.hasData && snapshot.data != null) {
                      DateTime lastSyncDateTime = DateTime.parse(snapshot.data!);
                      String formattedTime = DateFormat('dd MMM yyyy, hh:mm a').format(lastSyncDateTime);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, color: Colors.blueGrey),
                            const SizedBox(width: 8.0),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Last Sync: ',
                                  style: TextStyle(fontSize: 10.0),
                                ),
                                SizedBox(height: 4.0), // Add gap between Last Sync and the date
                                Text(
                                  formattedTime,
                                  style: const TextStyle( fontSize: 10.0),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    } else {
                      return Container();
                    }
                  },
                ),
                Expanded(
                  child: AnimatedList(
                    key: _listKey,
                    initialItemCount: _displayedShops.length,
                    itemBuilder: (context, index, animation) {
                      final shop = _displayedShops[index];
                      return _buildShopCard(shop, animation);
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }



}

