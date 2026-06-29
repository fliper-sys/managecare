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

  // ── Quota optimisation: customer cache TTL ───────────────────────────
  // Prevents re-fetching the full customer list on every screen visit.
  // Customers are re-fetched only if the cache is older than
  // [_customerCacheTtl] or if the business changes.
  DateTime? _lastCustomerFetch;
  static const _customerCacheTtl = Duration(minutes: 5);
  // ─────────────────────────────────────────────────────────────────────

  List<CustomerModel> get customers => _customers;
  CustomerModel? get selectedCustomer => _selectedCustomer;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  CollectionReference<Map<String, dynamic>>? get _businessCustomersRef {
    final businessId = _businessId?.trim();
    if (businessId == null || businessId.isEmpty) return null;

    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('customers');
  }

  CollectionReference<Map<String, dynamic>> get _rootCustomersRef =>
      _firestore.collection('customers');

  void setBusinessId(String businessId) {
    if (_businessId != businessId) {
      _businessId = businessId;
      _customers.clear();
      _selectedCustomer = null;
      _errorMessage = '';
      // ── Quota optimisation: invalidate cache on business switch ──────
      _lastCustomerFetch = null;
      // ─────────────────────────────────────────────────────────────────
    }
    notifyListeners();
  }

  /// Load all customers for the business and normalize older Firestore shapes.
  Future<void> loadCustomers({bool forceRefresh = false}) async {
    final customerRef = _businessCustomersRef;
    if (customerRef == null) return;

    // ── Quota optimisation: TTL cache ────────────────────────────────
    // Return immediately if we already have customers and the cache is
    // still fresh. Pass forceRefresh: true after adding/editing a customer.
    if (!forceRefresh &&
        _customers.isNotEmpty &&
        _lastCustomerFetch != null &&
        DateTime.now().difference(_lastCustomerFetch!) < _customerCacheTtl) {
      return; // Serve from in-memory cache — zero Firestore reads
    }
    // ─────────────────────────────────────────────────────────────────

    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await customerRef.get();

      _customers = snapshot.docs
          .map(CustomerModel.fromFirestore)
          .where((customer) => customer.isActive)
          .toList();

      _sortCustomers();
      _syncSelectedCustomerFromList();
      _errorMessage = '';
      // ── Quota optimisation: stamp cache timestamp ────────────────────
      _lastCustomerFetch = DateTime.now();
      // ─────────────────────────────────────────────────────────────────
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
    String phone,
    String name,
  ) async {
    final customerRef = _businessCustomersRef;
    final trimmedPhone = _cleanNullable(phone);
    if (customerRef == null || trimmedPhone == null) return null;

    try {
      await _ensureCustomersLoaded();

      final existingCustomer = _findExistingCustomer(phone: trimmedPhone);
      if (existingCustomer != null) {
        _selectedCustomer = existingCustomer;
        notifyListeners();
        return existingCustomer;
      }

      final now = DateTime.now();
      final newCustomer = CustomerModel(
        id: customerRef.doc().id,
        businessId: _businessId!,
        name: _cleanNullable(name) ?? trimmedPhone,
        phone: trimmedPhone,
        totalSpent: 0.0,
        totalTransactions: 0,
        averageOrderValue: 0.0,
        firstPurchaseDate: now,
        lastPurchaseDate: now,
        createdAt: now,
        updatedAt: now,
        isActive: true,
      );

      await _persistCustomer(newCustomer);
      _upsertLocalCustomer(newCustomer, selectCustomer: true);
      notifyListeners();

      return newCustomer;
    } catch (e) {
      _errorMessage = 'Failed to get/create customer: $e';
      debugPrint('[CustomerProvider] Error: $_errorMessage');
      return null;
    }
  }

  Future<CustomerModel?> createCustomer({
    required String name,
    String? phone,
    String? email,
  }) async {
    final customerRef = _businessCustomersRef;
    final trimmedName = name.trim();
    final trimmedPhone = _cleanNullable(phone);
    final trimmedEmail = _cleanNullable(email);

    if (customerRef == null || trimmedName.isEmpty) return null;

    try {
      await _ensureCustomersLoaded();

      final existingCustomer = _findExistingCustomer(
        phone: trimmedPhone,
        email: trimmedEmail,
      );
      if (existingCustomer != null) {
        _selectedCustomer = existingCustomer;
        notifyListeners();
        return existingCustomer;
      }

      final now = DateTime.now();
      final newCustomer = CustomerModel(
        id: customerRef.doc().id,
        businessId: _businessId!,
        name: trimmedName,
        phone: trimmedPhone,
        email: trimmedEmail,
        totalSpent: 0.0,
        totalTransactions: 0,
        averageOrderValue: 0.0,
        firstPurchaseDate: now,
        lastPurchaseDate: now,
        createdAt: now,
        updatedAt: now,
        isActive: true,
      );

      await _persistCustomer(newCustomer);
      _upsertLocalCustomer(newCustomer, selectCustomer: true);
      notifyListeners();
      return newCustomer;
    } catch (e) {
      _errorMessage = 'Failed to create customer: $e';
      debugPrint('[CustomerProvider] Error: $_errorMessage');
      return null;
    }
  }

  /// Update customer after purchase
  Future<void> updateCustomerAfterPurchase(
    String customerId,
    double purchaseAmount,
  ) async {
    final businessCustomersRef = _businessCustomersRef;
    if (businessCustomersRef == null) return;

    try {
      final customerRef = businessCustomersRef.doc(customerId);
      final currentDoc = await customerRef.get();

      Map<String, dynamic>? existingData;
      if (currentDoc.exists) {
        existingData = currentDoc.data();
      } else {
        final rootDoc = await _rootCustomersRef.doc(customerId).get();
        if (rootDoc.exists) {
          existingData = rootDoc.data();
        }
      }

      if (existingData == null) return;

      final currentCustomer =
          CustomerModel.fromJson(existingData, documentId: customerId);
      final newTransactionCount = currentCustomer.totalTransactions + 1;
      final newTotalSpent = currentCustomer.totalSpent + purchaseAmount;
      final newAverageOrderValue = newTotalSpent / newTransactionCount;
      final now = DateTime.now();

      final updates = {
        'totalTransactions': newTransactionCount,
        'totalOrders': newTransactionCount,
        'totalSpent': newTotalSpent,
        'totalPurchases': newTotalSpent,
        'averageOrderValue': newAverageOrderValue,
        'lastPurchaseDate': now,
        'updatedAt': now,
      };

      final batch = _firestore.batch();
      batch.set(customerRef, updates, SetOptions(merge: true));
      batch.set(
        _rootCustomersRef.doc(customerId),
        {
          ...updates,
          'businessId': currentCustomer.businessId.isNotEmpty
              ? currentCustomer.businessId
              : _businessId,
        },
        SetOptions(merge: true),
      );
      await batch.commit();

      final updatedCustomer = currentCustomer.copyWith(
        totalTransactions: newTransactionCount,
        totalSpent: newTotalSpent,
        averageOrderValue: newAverageOrderValue,
        lastPurchaseDate: now,
        updatedAt: now,
      );

      _upsertLocalCustomer(
        updatedCustomer,
        selectCustomer: _selectedCustomer?.id == customerId,
      );
      notifyListeners();

      print(
        '[CustomerProvider] Customer $customerId updated after purchase: +NGN $purchaseAmount',
      );
    } catch (e) {
      debugPrint('[CustomerProvider] Error updating customer: $e');
      rethrow;
    }
  }

  /// Get top customers by spending
  Future<List<CustomerModel>> getTopCustomers({int limit = 10}) async {
    final customerRef = _businessCustomersRef;
    if (customerRef == null) return [];

    try {
      final snapshot = await customerRef
          .orderBy('totalSpent', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map(CustomerModel.fromFirestore).toList();
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
    final customerRef = _businessCustomersRef;
    if (customerRef == null) return [];

    try {
      final snapshot = await customerRef
          .where('firstPurchaseDate', isGreaterThanOrEqualTo: startDate)
          .where('firstPurchaseDate', isLessThanOrEqualTo: endDate)
          .get();

      return snapshot.docs.map(CustomerModel.fromFirestore).toList();
    } catch (e) {
      debugPrint(
        '[CustomerProvider] Error getting customers by date range: $e',
      );
      return [];
    }
  }

  /// Get customer purchase history
  Future<List<Map<String, dynamic>>> getCustomerPurchaseHistory(
    String customerId,
  ) async {
    final customerRef = _businessCustomersRef;
    if (customerRef == null) return [];

    try {
      final snapshot = await customerRef
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

  void selectCustomer(CustomerModel? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  /// Clear all
  void clear() {
    _customers.clear();
    _selectedCustomer = null;
    _errorMessage = '';
    notifyListeners();
  }

  Future<void> _ensureCustomersLoaded() async {
    if (_customers.isEmpty && !_isLoading) {
      await loadCustomers();
    }
  }

  Future<void> _persistCustomer(CustomerModel customer) async {
    final customerRef = _businessCustomersRef;
    if (customerRef == null) return;

    final payload = customer.toJson();
    final batch = _firestore.batch();
    batch.set(customerRef.doc(customer.id), payload, SetOptions(merge: true));
    batch.set(
      _rootCustomersRef.doc(customer.id),
      payload,
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  void _upsertLocalCustomer(
    CustomerModel customer, {
    bool selectCustomer = false,
  }) {
    final index = _customers.indexWhere((entry) => entry.id == customer.id);
    if (index == -1) {
      _customers.add(customer);
    } else {
      _customers[index] = customer;
    }

    _sortCustomers();

    if (selectCustomer) {
      _selectedCustomer = customer;
    }
  }

  void _sortCustomers() {
    _customers.sort((a, b) {
      final lastPurchaseCompare =
          b.lastPurchaseDate.compareTo(a.lastPurchaseDate);
      if (lastPurchaseCompare != 0) return lastPurchaseCompare;
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  void _syncSelectedCustomerFromList() {
    final currentSelection = _selectedCustomer;
    if (currentSelection == null) return;

    final index =
        _customers.indexWhere((customer) => customer.id == currentSelection.id);
    if (index == -1) {
      _selectedCustomer = null;
      return;
    }

    _selectedCustomer = _customers[index];
  }

  CustomerModel? _findExistingCustomer({
    String? phone,
    String? email,
  }) {
    final normalizedPhone = _normalizeValue(phone);
    final normalizedEmail = _normalizeValue(email);

    for (final customer in _customers) {
      final phoneMatches = normalizedPhone != null &&
          _normalizeValue(customer.phone) == normalizedPhone;
      final emailMatches = normalizedEmail != null &&
          _normalizeValue(customer.email) == normalizedEmail;

      if (phoneMatches || emailMatches) {
        return customer;
      }
    }

    return null;
  }

  String? _cleanNullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String? _normalizeValue(String? value) {
    final trimmed = _cleanNullable(value);
    return trimmed?.toLowerCase();
  }
}
