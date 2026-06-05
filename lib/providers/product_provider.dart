import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';
import '../utils/constants.dart';

class ProductProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SyncService _syncService = SyncService();
  
  List<Product> _products = [];
  bool _isLoading = true;
  bool _isOffline = false;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;

  List<Product> get lowStockProducts => 
      _products.where((p) => p.isLowStock).toList();
  
  List<Product> get outOfStockProducts => 
      _products.where((p) => p.isOutOfStock).toList();

  ProductProvider() {
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    _isLoading = true;
    notifyListeners();

    // Try to load from local storage first
    final localProducts = LocalStorageService.getProducts();
    if (localProducts.isNotEmpty) {
      _products = localProducts.map((p) => Product.fromMap(p['id'], p)).toList();
      _isOffline = true;
      notifyListeners();
    }

    // Try to sync with Firebase
    await _syncWithFirebase();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _syncWithFirebase() async {
    try {
      await _syncService.syncProducts();
      final freshProducts = LocalStorageService.getProducts();
      _products = freshProducts.map((p) => Product.fromMap(p['id'], p)).toList();
      _isOffline = false;
      notifyListeners();
    } catch (e) {
      _isOffline = true;
    }
  }

  Future<void> addProduct(Product product) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.productsCollection)
          .add(product.toMap());
      
      final newProduct = product.copyWith(id: docRef.id);
      _products.add(newProduct);
      notifyListeners();
      
      // Update local storage
      final localProducts = LocalStorageService.getProducts();
      localProducts.add(newProduct.toMap()..['id'] = docRef.id);
      await LocalStorageService.saveProducts(localProducts);
    } catch (e) {
      // Offline - save locally only
      final tempId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      final newProduct = product.copyWith(id: tempId);
      _products.add(newProduct);
      notifyListeners();
      
      final localProducts = LocalStorageService.getProducts();
      localProducts.add(newProduct.toMap()..['id'] = tempId);
      await LocalStorageService.saveProducts(localProducts);
      
      throw Exception('Saved locally. Will sync when online.');
    }
  }

  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection(AppConstants.productsCollection)
          .doc(id)
          .update({
            ...data,
            'updatedAt': DateTime.now().toIso8601String(),
          });
      
      final index = _products.indexWhere((p) => p.id == id);
      if (index != -1) {
        _products[index] = _products[index].copyWith(
          productCode: data['productCode'] ?? _products[index].productCode,
          name: data['name'] ?? _products[index].name,
          costPrice: data['costPrice']?.toDouble() ?? _products[index].costPrice,
          retailPrice: data['retailPrice']?.toDouble() ?? _products[index].retailPrice,
          stock: data['stock'] ?? _products[index].stock,
          lowStockThreshold: data['lowStockThreshold'] ?? _products[index].lowStockThreshold,
          category: data['category'] ?? _products[index].category,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
      
      // Update local storage
      await _syncWithFirebase();
    } catch (e) {
      throw Exception('Failed to update product');
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _firestore
          .collection(AppConstants.productsCollection)
          .doc(id)
          .delete();
      
      _products.removeWhere((p) => p.id == id);
      notifyListeners();
      
      await _syncWithFirebase();
    } catch (e) {
      throw Exception('Failed to delete product');
    }
  }

  Future<void> refresh() async {
    await _syncWithFirebase();
  }
}