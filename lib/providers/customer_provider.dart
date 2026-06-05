import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';
import '../utils/constants.dart';

class CustomerProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SyncService _syncService = SyncService();
  
  List<Customer> _customers = [];
  bool _isLoading = true;
  bool _isOffline = false;

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;

  CustomerProvider() {
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    _isLoading = true;
    notifyListeners();

    final localCustomers = LocalStorageService.getCustomers();
    if (localCustomers.isNotEmpty) {
      _customers = localCustomers.map((c) => Customer.fromMap(c['id'], c)).toList();
      _isOffline = true;
      notifyListeners();
    }

    await _syncWithFirebase();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _syncWithFirebase() async {
    try {
      await _syncService.syncCustomers();
      final freshCustomers = LocalStorageService.getCustomers();
      _customers = freshCustomers.map((c) => Customer.fromMap(c['id'], c)).toList();
      _isOffline = false;
      notifyListeners();
    } catch (e) {
      _isOffline = true;
    }
  }

  Future<Customer> addCustomer(Customer customer) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.customersCollection)
          .add(customer.toMap());
      
      final newCustomer = customer.copyWith(id: docRef.id);
      _customers.add(newCustomer);
      notifyListeners();
      
      final localCustomers = LocalStorageService.getCustomers();
      localCustomers.add(newCustomer.toMap()..['id'] = docRef.id);
      await LocalStorageService.saveCustomers(localCustomers);
      
      return newCustomer;
    } catch (e) {
      final tempId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      final newCustomer = customer.copyWith(id: tempId);
      _customers.add(newCustomer);
      notifyListeners();
      
      final localCustomers = LocalStorageService.getCustomers();
      localCustomers.add(newCustomer.toMap()..['id'] = tempId);
      await LocalStorageService.saveCustomers(localCustomers);
      
      return newCustomer;
    }
  }

  Future<void> updateCustomer(String id, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection(AppConstants.customersCollection)
          .doc(id)
          .update({
            ...data,
            'updatedAt': DateTime.now().toIso8601String(),
          });
      
      final index = _customers.indexWhere((c) => c.id == id);
      if (index != -1) {
        _customers[index] = _customers[index].copyWith(
          name: data['name'] ?? _customers[index].name,
          phone: data['phone'] ?? _customers[index].phone,
          email: data['email'] ?? _customers[index].email,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
      
      await _syncWithFirebase();
    } catch (e) {
      throw Exception('Failed to update customer');
    }
  }

  Future<void> deleteCustomer(String id) async {
    try {
      await _firestore
          .collection(AppConstants.customersCollection)
          .doc(id)
          .delete();
      
      _customers.removeWhere((c) => c.id == id);
      notifyListeners();
      
      await _syncWithFirebase();
    } catch (e) {
      throw Exception('Failed to delete customer');
    }
  }

  Future<void> refresh() async {
    await _syncWithFirebase();
  }
}