import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/purchase.dart';
import '../utils/constants.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== AUTHENTICATION ====================
  
  Future<User?> getCurrentUser() async {
    return _auth.currentUser;
  }
  
  Future<User?> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return result.user;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }
  
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ==================== PRODUCTS ====================
  
  Stream<List<Product>> streamProducts() {
    return _firestore
        .collection(AppConstants.productsCollection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Product.fromMap(doc.id, doc.data())).toList());
  }
  
  Future<List<Product>> getProducts() async {
    final snapshot = await _firestore
        .collection(AppConstants.productsCollection)
        .orderBy('name')
        .get();
    return snapshot.docs.map((doc) => Product.fromMap(doc.id, doc.data())).toList();
  }
  
  Future<String> addProduct(Product product) async {
    final docRef = await _firestore
        .collection(AppConstants.productsCollection)
        .add({
          ...product.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
    return docRef.id;
  }
  
  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    await _firestore
        .collection(AppConstants.productsCollection)
        .doc(id)
        .update({
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }
  
  Future<void> deleteProduct(String id) async {
    await _firestore
        .collection(AppConstants.productsCollection)
        .doc(id)
        .delete();
  }
  
  Future<Product?> getProductByCode(String code) async {
    final snapshot = await _firestore
        .collection(AppConstants.productsCollection)
        .where('productCode', isEqualTo: code)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return Product.fromMap(snapshot.docs.first.id, snapshot.docs.first.data());
  }
  
  Future<void> updateStock(String productId, int newStock) async {
    await _firestore
        .collection(AppConstants.productsCollection)
        .doc(productId)
        .update({
          'stock': newStock,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  // ==================== CUSTOMERS ====================
  
  Stream<List<Customer>> streamCustomers() {
    return _firestore
        .collection(AppConstants.customersCollection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Customer.fromMap(doc.id, doc.data())).toList());
  }
  
  Future<List<Customer>> getCustomers() async {
    final snapshot = await _firestore
        .collection(AppConstants.customersCollection)
        .orderBy('name')
        .get();
    return snapshot.docs.map((doc) => Customer.fromMap(doc.id, doc.data())).toList();
  }
  
  Future<String> addCustomer(Customer customer) async {
    final docRef = await _firestore
        .collection(AppConstants.customersCollection)
        .add({
          ...customer.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
    return docRef.id;
  }
  
  Future<void> updateCustomer(String id, Map<String, dynamic> data) async {
    await _firestore
        .collection(AppConstants.customersCollection)
        .doc(id)
        .update({
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }
  
  Future<void> deleteCustomer(String id) async {
    // Delete all associated purchases first
    final purchases = await _firestore
        .collection(AppConstants.purchasesCollection)
        .where('customer_id', isEqualTo: id)
        .get();
    
    final batch = _firestore.batch();
    for (var doc in purchases.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_firestore.collection(AppConstants.customersCollection).doc(id));
    await batch.commit();
  }
  
  Future<Customer?> getCustomerById(String id) async {
    final doc = await _firestore
        .collection(AppConstants.customersCollection)
        .doc(id)
        .get();
    if (!doc.exists) return null;
    return Customer.fromMap(doc.id, doc.data()!);
  }

  // ==================== PURCHASES ====================
  
  Stream<List<Purchase>> streamPurchases() {
    return _firestore
        .collection(AppConstants.purchasesCollection)
        .orderBy('purchase_date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Purchase.fromMap(doc.id, doc.data())).toList());
  }
  
  Future<List<Purchase>> getPurchases() async {
    final snapshot = await _firestore
        .collection(AppConstants.purchasesCollection)
        .orderBy('purchase_date', descending: true)
        .get();
    return snapshot.docs.map((doc) => Purchase.fromMap(doc.id, doc.data())).toList();
  }
  
  Future<String> addPurchase(Purchase purchase) async {
    final user = _auth.currentUser;
    final docRef = await _firestore
        .collection(AppConstants.purchasesCollection)
        .add({
          'created_by': user?.uid ?? 'unknown',
          'created_by_email': user?.email ?? 'unknown',
          'customer_id': purchase.customerId,
          'customer_name': purchase.customerName,
          'product_data': _serializeProductData(purchase.items),
          'purchase_date': purchase.purchaseDate.toIso8601String(),
          'status': purchase.status,
          'total_amount': purchase.totalAmount,
          'createdAt': FieldValue.serverTimestamp(),
        });
    return docRef.id;
  }
  
  String _serializeProductData(List<PurchaseItem> items) {
    final List<Map<String, dynamic>> itemsList = items.map((item) => {
      'product_id': item.productId,
      'name': item.name,
      'price': item.price,
      'quantity': item.quantity,
      'subtotal': item.subtotal,
      if (item.costPrice != null) 'cost_price': item.costPrice,
    }).toList();
    return itemsList.toString();
  }
  
  Future<void> updatePurchaseStatus(String id, String status) async {
    await _firestore
        .collection(AppConstants.purchasesCollection)
        .doc(id)
        .update({
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }
  
  Future<void> updatePurchase(String id, Map<String, dynamic> data) async {
    await _firestore
        .collection(AppConstants.purchasesCollection)
        .doc(id)
        .update({
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }
  
  Future<void> deletePurchase(String id) async {
    await _firestore
        .collection(AppConstants.purchasesCollection)
        .doc(id)
        .delete();
  }
  
  Future<List<Purchase>> getPurchasesByCustomer(String customerId) async {
    final snapshot = await _firestore
        .collection(AppConstants.purchasesCollection)
        .where('customer_id', isEqualTo: customerId)
        .orderBy('purchase_date', descending: true)
        .get();
    return snapshot.docs.map((doc) => Purchase.fromMap(doc.id, doc.data())).toList();
  }
  
  Future<double> getTotalRevenue() async {
    final snapshot = await _firestore
        .collection(AppConstants.purchasesCollection)
        .get();
    return snapshot.docs.fold<double>(0, (sum, doc) => sum + (doc.data()['total_amount'] ?? 0));
  }
  
  Future<double> getPendingAmount() async {
    final snapshot = await _firestore
        .collection(AppConstants.purchasesCollection)
        .where('status', isNotEqualTo: 'paid')
        .get();
    return snapshot.docs.fold<double>(0, (sum, doc) => sum + (doc.data()['total_amount'] ?? 0));
  }

  // ==================== BATCH OPERATIONS ====================
  
  Future<void> batchUpdateProducts(List<Map<String, dynamic>> updates) async {
    final batch = _firestore.batch();
    for (final update in updates) {
      final ref = _firestore
          .collection(AppConstants.productsCollection)
          .doc(update['id']);
      batch.update(ref, update['data']);
    }
    await batch.commit();
  }
  
  Future<Map<String, dynamic>> getDashboardStats() async {
    final productsSnapshot = await _firestore
        .collection(AppConstants.productsCollection)
        .get();
    final customersSnapshot = await _firestore
        .collection(AppConstants.customersCollection)
        .get();
    final purchasesSnapshot = await _firestore
        .collection(AppConstants.purchasesCollection)
        .get();
    
    final totalSales = purchasesSnapshot.docs.fold<double>(
      0, (sum, doc) => sum + (doc.data()['total_amount'] ?? 0));
    
    final pendingCount = purchasesSnapshot.docs.where(
      (doc) => doc.data()['status'] != 'paid').length;
    
    final lowStockCount = productsSnapshot.docs.where((doc) {
      final data = doc.data();
      final stock = data['stock'] ?? 0;
      final threshold = data['lowStockThreshold'] ?? 5;
      return stock <= threshold;
    }).length;
    
    return {
      'totalProducts': productsSnapshot.docs.length,
      'totalCustomers': customersSnapshot.docs.length,
      'totalOrders': purchasesSnapshot.docs.length,
      'totalSales': totalSales,
      'pendingOrders': pendingCount,
      'lowStockProducts': lowStockCount,
    };
  }

  // ==================== REAL-TIME LISTENERS ====================
  
  Stream<QuerySnapshot> listenToProducts() {
    return _firestore
        .collection(AppConstants.productsCollection)
        .orderBy('name')
        .snapshots();
  }
  
  Stream<QuerySnapshot> listenToCustomers() {
    return _firestore
        .collection(AppConstants.customersCollection)
        .orderBy('name')
        .snapshots();
  }
  
  Stream<QuerySnapshot> listenToPurchases() {
    return _firestore
        .collection(AppConstants.purchasesCollection)
        .orderBy('purchase_date', descending: true)
        .snapshots();
  }
}