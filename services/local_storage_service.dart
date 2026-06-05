import 'dart:convert';
import 'package:hive/hive.dart';
import '../utils/constants.dart';

class LocalStorageService {
  static late Box _box;

  static Future<void> init() async {
    _box = Hive.box(AppConstants.localDbBox);
  }

  // Generic save/load
  static Future<void> saveData(String key, dynamic data) async {
    await _box.put(key, data);
  }

  static dynamic getData(String key) {
    return _box.get(key);
  }

  // Products
  static Future<void> saveProducts(List<Map<String, dynamic>> products) async {
    await _box.put('products', jsonEncode(products));
  }

  static List<Map<String, dynamic>> getProducts() {
    final products = _box.get('products');
    if (products is String && products.isNotEmpty) {
      try {
        final decoded = jsonDecode(products);
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        }
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  // Customers
  static Future<void> saveCustomers(List<Map<String, dynamic>> customers) async {
    await _box.put('customers', jsonEncode(customers));
  }

  static List<Map<String, dynamic>> getCustomers() {
    final customers = _box.get('customers');
    if (customers is String && customers.isNotEmpty) {
      try {
        final decoded = jsonDecode(customers);
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        }
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  // Purchases
  static Future<void> savePurchases(List<Map<String, dynamic>> purchases) async {
    await _box.put('purchases', jsonEncode(purchases));
  }

  static List<Map<String, dynamic>> getPurchases() {
    final purchases = _box.get('purchases');
    if (purchases is String && purchases.isNotEmpty) {
      try {
        final decoded = jsonDecode(purchases);
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        }
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  // Sync timestamp
  static Future<void> setLastSync(DateTime time) async {
    await _box.put('lastSync', time.toIso8601String());
  }

  static DateTime? getLastSync() {
    final lastSync = _box.get('lastSync');
    if (lastSync is String) {
      return DateTime.parse(lastSync);
    }
    return null;
  }

  // Clear all
  static Future<void> clearAll() async {
    await _box.clear();
  }
}