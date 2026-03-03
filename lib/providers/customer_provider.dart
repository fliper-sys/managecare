import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../data/models/customer_model.dart';

class CustomerProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _businessId;
  List<CustomerModel> _customers = [];
  CustomerModel? _selectedCustomer;
  bool _isLoading = false;
  String _errorMessage = '';

  // Getters
  List<CustomerModel> get customers => _customers;
  CustomerModel? get selectedCustomer => _selectedCustomer;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  void setBusinessId(String businessId) {
    _businessId = businessId;
    notifyListeners();
  }

  /// Load all customers for the business
  Future<void> loadCustomers() async {
    if (_businessId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('customers')
          .where('isActive', isEqualTo: true)
          .orderBy('lastPurchaseDate', descending: true)
          .get();

      _customers = snapshot.docs
          .map((doc) => CustomerModel.fromJson(doc.data()))
          .toList();

      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Failed to load customers: $e';
      debugPrint('[CustomerProvider] Error: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Search customers by name or phone
  Future<List<CustomerModel>> searchCustomers(String query) async {
    if (_businessId == null || query.isEmpty) return _customers;

    try {
      final results = _customers.where((customer) {
        final matchName =
            customer.name.toLowerCase().contains(query.toLowerCase());
        final matchPhone =
            customer.phone?.toLowerCase().contains(query.toLowerCase()) ??
                false;
        final matchEmail =
            customer.email?.toLowerCase().contains(query.toLowerCase()) ??
                false;
        return matchName || matchPhone || matchEmail;
      }).toList();

      return results;
    } catch (e) {
      debugPrint('[CustomerProvider] Search error: $e');
      return [];
    }
  }

  /// Get or create customer by phone number (for quick checkout)
  Future<CustomerModel?> getOrCreateCustomerByPhone(
      String phone, String name) async {
    if (_businessId == null || phone.isEmpty) return null;

    try {
      final existing = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('customers')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        final customer = CustomerModel.fromJson(existing.docs.first.data());
        _selectedCustomer = customer;
        notifyListeners();
        return customer;
      }

      // Create new customer
      final now = DateTime.now();
      final newCustomer = CustomerModel(
        id: _firestore
            .collection('businesses')
            .doc(_businessId)
            .collection('customers')
            .doc()
            .id,
        businessId: _businessId!,
        name: name,
        phone: phone,
        totalSpent: 0.0,
        totalTransactions: 0,
        averageOrderValue: 0.0,
        firstPurchaseDate: now,
        lastPurchaseDate: now,
        createdAt: now,
        updatedAt: now,
        isActive: true,
      );

      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('customers')
          .doc(newCustomer.id)
          .set(newCustomer.toJson());

      _selectedCustomer = newCustomer;
      _customers.add(newCustomer);
      notifyListeners();

      return newCustomer;
    } catch (e) {
      _errorMessage = 'Failed to get/create customer: $e';
      debugPrint('[CustomerProvider] Error: $_errorMessage');
      return null;
    }
  }

  /// Update customer after purchase
  Future<void> updateCustomerAfterPurchase(
    String customerId,
    double purchaseAmount,
  ) async {
    if (_businessId == null) return;

    try {
      final customerRef = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('customers')
          .doc(customerId);

      final currentDoc = await customerRef.get();
      if (!currentDoc.exists) return;

      final data = currentDoc.data()!;
      final previousTransactions =
          (data['totalTransactions'] as num?)?.toInt() ?? 0;
      final previousSpent = (data['totalSpent'] as num?)?.toDouble() ?? 0.0;

      final newTransactionCount = previousTransactions + 1;
      final newTotalSpent = previousSpent + purchaseAmount;
      final newAverageOrderValue = newTotalSpent / newTransactionCount;

      await customerRef.update({
        'totalTransactions': newTransactionCount,
        'totalSpent': newTotalSpent,
        'averageOrderValue': newAverageOrderValue,
        'lastPurchaseDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local customer if it's the selected one
      if (_selectedCustomer?.id == customerId) {
        _selectedCustomer = _selectedCustomer!.copyWith(
          totalTransactions: newTransactionCount,
          totalSpent: newTotalSpent,
          averageOrderValue: newAverageOrderValue,
          lastPurchaseDate: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }

      print(
          '[CustomerProvider] Customer $customerId updated after purchase: +₦$purchaseAmount');
    } catch (e) {
      debugPrint('[CustomerProvider] Error updating customer: $e');
      rethrow;
    }
  }

  /// Get top customers by spending
  Future<List<CustomerModel>> getTopCustomers({int limit = 10}) async {
    if (_businessId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('customers')
          .orderBy('totalSpent', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => CustomerModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[CustomerProvider] Error getting top customers: $e');
      return [];
    }
  }

  /// Get customers by date range
  Future<List<CustomerModel>> getCustomersByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (_businessId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('customers')
          .where('firstPurchaseDate', isGreaterThanOrEqualTo: startDate)
          .where('firstPurchaseDate', isLessThanOrEqualTo: endDate)
          .get();

      return snapshot.docs
          .map((doc) => CustomerModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint(
          '[CustomerProvider] Error getting customers by date range: $e');
      return [];
    }
  }

  /// Get customer purchase history
  Future<List<Map<String, dynamic>>> getCustomerPurchaseHistory(
      String customerId) async {
    if (_businessId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('customers')
          .doc(customerId)
          .collection('purchases')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('[CustomerProvider] Error getting purchase history: $e');
      return [];
    }
  }

  /// Clear selected customer
  void clearSelectedCustomer() {
    _selectedCustomer = null;
    notifyListeners();
  }

  /// Clear all
  void clear() {
    _customers.clear();
    _selectedCustomer = null;
    _errorMessage = '';
    notifyListeners();
  }
}

