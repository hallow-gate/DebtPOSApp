import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/purchase.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';
import '../utils/constants.dart';

class PurchaseProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SyncService _syncService = SyncService();
  
  List<Purchase> _purchases = [];
  bool _isLoading = true;
  bool _isOffline = false;

  List<Purchase> get purchases => _purchases;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;

  PurchaseProvider() {
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    _isLoading = true;
    notifyListeners();

    final localPurchases = LocalStorageService.getPurchases();
    if (localPurchases.isNotEmpty) {
      _purchases = localPurchases.map((p) => Purchase.fromMap(p['id'], p)).toList();
      _isOffline = true;
      notifyListeners();
    }

    await _syncWithFirebase();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _syncWithFirebase() async {
    try {
      await _syncService.syncPurchases();
      final freshPurchases = LocalStorageService.getPurchases();
      _purchases = freshPurchases.map((p) => Purchase.fromMap(p['id'], p)).toList();
      _isOffline = false;
      notifyListeners();
    } catch (e) {
      _isOffline = true;
    }
  }

  Future<void> addPurchase(Purchase purchase) async {
    try {
      final purchaseMap = purchase.toMap();
      await _syncService.pushPurchaseToFirebase(purchaseMap);
      
      final docRef = await _firestore
          .collection(AppConstants.purchasesCollection)
          .add(purchaseMap);
      
      final newPurchase = Purchase(
        id: docRef.id,
        createdBy: purchase.createdBy,
        createdByEmail: purchase.createdByEmail,
        customerId: purchase.customerId,
        customerName: purchase.customerName,
        items: purchase.items,
        purchaseDate: purchase.purchaseDate,
        status: purchase.status,
        totalAmount: purchase.totalAmount,
      );
      
      _purchases.insert(0, newPurchase);
      notifyListeners();
      
      final localPurchases = LocalStorageService.getPurchases();
      localPurchases.insert(0, newPurchase.toMap()..['id'] = docRef.id);
      await LocalStorageService.savePurchases(localPurchases);
    } catch (e) {
      // Save locally only
      final tempId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      final newPurchase = Purchase(
        id: tempId,
        createdBy: purchase.createdBy,
        createdByEmail: purchase.createdByEmail,
        customerId: purchase.customerId,
        customerName: purchase.customerName,
        items: purchase.items,
        purchaseDate: purchase.purchaseDate,
        status: purchase.status,
        totalAmount: purchase.totalAmount,
      );
      
      _purchases.insert(0, newPurchase);
      notifyListeners();
      
      final localPurchases = LocalStorageService.getPurchases();
      localPurchases.insert(0, newPurchase.toMap()..['id'] = tempId);
      await LocalStorageService.savePurchases(localPurchases);
      
      throw Exception('Saved locally. Will sync when online.');
    }
  }

  Future<void> updatePurchase(String id, Map<String, dynamic> updates) async {
    try {
      await _firestore
          .collection(AppConstants.purchasesCollection)
          .doc(id)
          .update(updates);
      
      final index = _purchases.indexWhere((p) => p.id == id);
      if (index != -1) {
        final updated = _purchases[index];
        final newStatus = updates['status'] ?? updated.status;
        _purchases[index] = Purchase(
          id: updated.id,
          createdBy: updated.createdBy,
          createdByEmail: updated.createdByEmail,
          customerId: updated.customerId,
          customerName: updated.customerName,
          items: updated.items,
          purchaseDate: updated.purchaseDate,
          status: newStatus,
          totalAmount: updated.totalAmount,
        );
        notifyListeners();
      }
      
      await _syncWithFirebase();
    } catch (e) {
      throw Exception('Failed to update purchase');
    }
  }

  Future<void> deletePurchase(String id) async {
    try {
      await _firestore
          .collection(AppConstants.purchasesCollection)
          .doc(id)
          .delete();
      
      _purchases.removeWhere((p) => p.id == id);
      notifyListeners();
      
      await _syncWithFirebase();
    } catch (e) {
      throw Exception('Failed to delete purchase');
    }
  }

  Future<void> refresh() async {
    await _syncWithFirebase();
  }
}