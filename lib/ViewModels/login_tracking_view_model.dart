import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../Models/LoginModels/login_tracking_model.dart';
import '../Repositories/LoginRepositories/login_tracking_repository.dart';

class LoginTrackingViewModel extends GetxController {
  final LoginTrackingRepository _repository = LoginTrackingRepository();

  LoginTrackingRepository get repository => _repository;

  var isLoading = false.obs;
  var unpostedRecords = <LoginTrackingModel>[].obs;
  var allRecords = <LoginTrackingModel>[].obs;
  var syncResult = RxMap<String, dynamic>({});

  @override
  void onInit() {
    super.onInit();
    loadUnpostedRecords();
    loadAllRecords();
  }

  Future<void> loadUnpostedRecords() async {
    try {
      isLoading.value = true;
      unpostedRecords.value = await _repository.getUnpostedLoginTracking();
    } catch (e) {
      debugPrint('❌ [LoginTrackingVM] Error loading unposted: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadAllRecords() async {
    try {
      isLoading.value = true;
      allRecords.value = await _repository.getAllLoginTracking();
    } catch (e) {
      debugPrint('❌ [LoginTrackingVM] Error loading all: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<LoginTrackingModel?> createAndPostLoginRecord({
    required String userId,
    required String bookerName,
    required String designation,
    required String companyCode,
  }) async {
    try {
      isLoading.value = true;

      final model = await _repository.createAndPostLoginRecord(
        userId: userId,
        bookerName: bookerName,
        designation: designation,
        companyCode: companyCode,
      );

      await loadUnpostedRecords();
      await loadAllRecords();

      return model;
    } catch (e) {
      debugPrint('❌ [LoginTrackingVM] Error creating record: $e');
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<Map<String, dynamic>> syncAllRecords() async {
    try {
      isLoading.value = true;

      final result = await _repository.syncUnpostedRecords();
      syncResult.value = result;

      await loadUnpostedRecords();
      await loadAllRecords();

      return result;
    } catch (e) {
      debugPrint('❌ [LoginTrackingVM] Error syncing: $e');
      return {'success': false, 'error': e.toString()};
    } finally {
      isLoading.value = false;
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    return await _repository.getLoginTrackingStats();
  }
}