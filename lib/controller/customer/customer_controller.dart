import 'package:get/get.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/models/customer_model.dart';

class CustomerController extends GetxController {
  final SqlDB _db = SqlDB();

  var customers = <CustomerModel>[].obs;
  var filteredCustomers = <CustomerModel>[].obs;
  var customerStats = <String, dynamic>{}.obs;
  var isLoading = false.obs;

  Future<void> loadCustomers() async {
    isLoading.value = true;
    try {
      final data = await _db.readData(
        'SELECT * FROM customers WHERE is_active = 1 ORDER BY customer_name',
      );
      customers.value = data.map((e) => CustomerModel.fromMap(e)).toList();
      filteredCustomers.value = customers;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addCustomer(CustomerModel customer) async {
    try {
      final data = customer.toMap();
      data.remove('customer_id');
      data['join_date'] = DateTime.now().toIso8601String();
      await _db.safeInsert('customers', data);
      await loadCustomers();
      Get.back();
      Get.snackbar('نجاح', 'تمت إضافة الزبون بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في إضافة الزبون: $e');
    }
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    try {
      if (customer.customerId == null) return;
      final data = customer.toMap();
      await _db.safeUpdate(
        'customers',
        data,
        where: 'customer_id = ?',
        whereArgs: [customer.customerId],
      );
      await loadCustomers();
      Get.back();
      Get.snackbar('نجاح', 'تم تحديث الزبون بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في تحديث الزبون: $e');
    }
  }

  Future<void> deleteCustomer(int customerId) async {
    try {
      await _db.safeUpdate(
        'customers',
        {'is_active': 0},
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
      await loadCustomers();
      Get.snackbar('نجاح', 'تم حذف الزبون بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في حذف الزبون: $e');
    }
  }

  Future<void> addLoyaltyPoints(int customerId, int points) async {
    try {
      await _db.updateData(
        'UPDATE customers SET loyalty_points = loyalty_points + ? WHERE customer_id = ?',
        [points, customerId],
      );

      final customerData = await _db.readData(
        'SELECT loyalty_points FROM customers WHERE customer_id = ?',
        [customerId],
      );

      if (customerData.isNotEmpty) {
        final currentPoints = customerData.first['loyalty_points'] ?? 0;
        String tier = 'bronze';
        if (currentPoints >= 1000) {
          tier = 'gold';
        } else if (currentPoints >= 500) {
          tier = 'silver';
        }
        await _db.safeUpdate(
          'customers',
          {'tier': tier},
          where: 'customer_id = ?',
          whereArgs: [customerId],
        );
      }

      await loadCustomers();
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في إضافة نقاط الولاء: $e');
    }
  }

  Future<void> redeemPoints(int customerId, int points) async {
    try {
      final customerData = await _db.readData(
        'SELECT loyalty_points FROM customers WHERE customer_id = ?',
        [customerId],
      );

      if (customerData.isEmpty) return;
      final currentPoints = customerData.first['loyalty_points'] ?? 0;

      if (currentPoints < points) {
        Get.snackbar('خطأ', 'النقاط غير كافية');
        return;
      }

      await _db.updateData(
        'UPDATE customers SET loyalty_points = loyalty_points - ? WHERE customer_id = ?',
        [points, customerId],
      );
      await loadCustomers();
      Get.snackbar('نجاح', 'تم استبدال النقاط بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في استبدال النقاط: $e');
    }
  }

  Future<List<CustomerModel>> searchCustomers(String query) async {
    if (query.isEmpty) {
      filteredCustomers.value = customers;
      return customers;
    }

    final data = await _db.readData(
      'SELECT * FROM customers WHERE is_active = 1 '
      'AND (customer_name LIKE ? OR phone_1 LIKE ? OR phone_2 LIKE ? OR email LIKE ?) '
      'ORDER BY customer_name',
      ['%$query%', '%$query%', '%$query%', '%$query%'],
    );

    final results = data.map((e) => CustomerModel.fromMap(e)).toList();
    filteredCustomers.value = results;
    return results;
  }

  Future<Map<String, dynamic>> getCustomerStats() async {
    try {
      final totalCustomers = await _db.readData(
        'SELECT COUNT(*) AS count FROM customers WHERE is_active = 1',
      );

      final totalSpent = await _db.readData(
        'SELECT COALESCE(SUM(total_spent), 0) AS total FROM customers',
      );

      final tierBreakdown = await _db.readData(
        'SELECT tier, COUNT(*) AS count FROM customers WHERE is_active = 1 '
        'GROUP BY tier',
      );

      final topSpenders = await _db.readData(
        'SELECT customer_name, total_spent FROM customers '
        'WHERE is_active = 1 ORDER BY total_spent DESC LIMIT 10',
      );

      final stats = {
        'total_customers': totalCustomers.first['count'] ?? 0,
        'total_spent': (totalSpent.first['total'] ?? 0).toDouble(),
        'tier_breakdown': tierBreakdown,
        'top_spenders': topSpenders,
      };

      customerStats.value = stats;
      return stats;
    } catch (e) {
      return {};
    }
  }
}
