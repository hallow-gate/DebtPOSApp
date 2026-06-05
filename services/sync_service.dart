import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_storage_service.dart';
import '../utils/constants.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> hasNetwork() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> syncAllData() async {
    final hasConnection = await hasNetwork();
    if (!hasConnection) {
      throw Exception('No internet connection');
    }

    await Future.wait([
      syncProducts(),
      syncCustomers(),
      syncPurchases(),
    ]);

    await LocalStorageService.setLastSync(DateTime.now());
  }

  Future<void> syncProducts() async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.productsCollection)
          .get();
      
      final products = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      await LocalStorageService.saveProducts(products);
    } catch (e) {
      throw Exception('Failed to sync products: $e');
    }
  }

  Future<void> syncCustomers() async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.customersCollection)
          .get();
      
      final customers = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      await LocalStorageService.saveCustomers(customers);
    } catch (e) {
      throw Exception('Failed to sync customers: $e');
    }
  }

  Future<void> syncPurchases() async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.purchasesCollection)
          .orderBy('purchase_date', descending: true)
          .get();
      
      final purchases = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      await LocalStorageService.savePurchases(purchases);
    } catch (e) {
      throw Exception('Failed to sync purchases: $e');
    }
  }

  Future<void> pushPurchaseToFirebase(Map<String, dynamic> purchase) async {
    final hasConnection = await hasNetwork();
    if (!hasConnection) {
      throw Exception('No internet connection. Purchase saved locally.');
    }
    
    try {
      await _firestore
          .collection(AppConstants.purchasesCollection)
          .add(purchase);
    } catch (e) {
      throw Exception('Failed to push purchase: $e');
    }
  }

  Future<void> updateProductStock(String productId, int newStock) async {
    final hasConnection = await hasNetwork();
    if (!hasConnection) {
      throw Exception('No internet connection. Stock update saved locally.');
    }
    
    try {
      await _firestore
          .collection(AppConstants.productsCollection)
          .doc(productId)
          .update({
            'stock': newStock,
            'updatedAt': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      throw Exception('Failed to update stock: $e');
    }
  }
}