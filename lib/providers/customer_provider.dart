import 'package:flutter/material.dart';

import '../data/models/customer_model.dart';
import '../services/managecare_api_client.dart';

class CustomerProvider extends ChangeNotifier {
  final ManagecareApiClient _api = ManagecareApiClient.instance;

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

  /// Load all customers for the business.
  Future<void> loadCustomers({bool forceRefresh = false}) async {
    final businessId = _businessId;
    if (businessId == null || businessId.isEmpty) return;

    // ── Quota optimisation: TTL cache ────────────────────────────────
    // Return immediately if we already have customers and the cache is
    // still fresh. Pass forceRefresh: true after adding/editing a customer.
    if (!forceRefresh &&
        _customers.isNotEmpty &&
        _lastCustomerFetch != null &&
        DateTime.now().difference(_lastCustomerFetch!) < _customerCacheTtl) {
      return; // Serve from in-memory cache — zero network calls
    }
    // ─────────────────────────────────────────────────────────────────

    _isLoading = true;
    notifyListeners();

    try {
      // limit=1000: the backend paginates by default; customer lists are
      // small enough per business that a single page covers real usage.
      final response = await _api.get(
        '/api/customers/$businessId',
        query: {'isActive': 'true', 'limit': 1000},
      );
      final rows = (response['data'] as List<dynamic>? ?? const []);

      _customers = rows
          .map((row) => CustomerModel.fromJson(row as Map<String, dynamic>))
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

  /// Search customers by name or phone (in-memory, from the loaded cache).
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
    final businessId = _businessId;
    final trimmedPhone = _cleanNullable(phone);
    if (businessId == null || trimmedPhone == null) return null;

    try {
      await _ensureCustomersLoaded();

      final existingCustomer = _findExistingCustomer(phone: trimmedPhone);
      if (existingCustomer != null) {
        _selectedCustomer = existingCustomer;
        notifyListeners();
        return existingCustomer;
      }

      final created = await _api.post(
        '/api/customers/$businessId',
        body: {'name': _cleanNullable(name) ?? trimmedPhone, 'phone': trimmedPhone},
      );
      final newCustomer =
          CustomerModel.fromJson(created as Map<String, dynamic>);

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
    final businessId = _businessId;
    final trimmedName = name.trim();
    final trimmedPhone = _cleanNullable(phone);
    final trimmedEmail = _cleanNullable(email);

    if (businessId == null || trimmedName.isEmpty) return null;

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

      final created = await _api.post(
        '/api/customers/$businessId',
        body: {
          'name': trimmedName,
          if (trimmedPhone != null) 'phone': trimmedPhone,
          if (trimmedEmail != null) 'email': trimmedEmail,
        },
      );
      final newCustomer =
          CustomerModel.fromJson(created as Map<String, dynamic>);

      _upsertLocalCustomer(newCustomer, selectCustomer: true);
      notifyListeners();
      return newCustomer;
    } catch (e) {
      _errorMessage = 'Failed to create customer: $e';
      debugPrint('[CustomerProvider] Error: $_errorMessage');
      return null;
    }
  }

  /// Update customer after purchase - atomic server-side increment.
  Future<void> updateCustomerAfterPurchase(
    String customerId,
    double purchaseAmount,
  ) async {
    final businessId = _businessId;
    if (businessId == null) return;

    try {
      final updated = await _api.patch(
        '/api/customers/$businessId/$customerId/purchase',
        body: {'amount': purchaseAmount},
      );
      final updatedCustomer =
          CustomerModel.fromJson(updated as Map<String, dynamic>);

      _upsertLocalCustomer(
        updatedCustomer,
        selectCustomer: _selectedCustomer?.id == customerId,
      );
      notifyListeners();

      debugPrint(
        '[CustomerProvider] Customer $customerId updated after purchase: +NGN $purchaseAmount',
      );
    } catch (e) {
      debugPrint('[CustomerProvider] Error updating customer: $e');
      rethrow;
    }
  }

  /// Get top customers by spending
  Future<List<CustomerModel>> getTopCustomers({int limit = 10}) async {
    final businessId = _businessId;
    if (businessId == null) return [];

    try {
      final response = await _api.get(
        '/api/customers/$businessId/top',
        query: {'limit': limit},
      );
      final rows = (response as List<dynamic>? ?? const []);
      return rows
          .map((row) => CustomerModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[CustomerProvider] Error getting top customers: $e');
      return [];
    }
  }

  /// Get customers by date range (in-memory, from the loaded cache - the
  /// business-level customer count is small enough that this doesn't need
  /// a dedicated server-side query).
  Future<List<CustomerModel>> getCustomersByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (_businessId == null) return [];

    try {
      await _ensureCustomersLoaded();
      return _customers
          .where((customer) =>
              !customer.firstPurchaseDate.isBefore(startDate) &&
              !customer.firstPurchaseDate.isAfter(endDate))
          .toList();
    } catch (e) {
      debugPrint(
        '[CustomerProvider] Error getting customers by date range: $e',
      );
      return [];
    }
  }

  /// Get customer purchase history (their sales records).
  Future<List<Map<String, dynamic>>> getCustomerPurchaseHistory(
    String customerId,
  ) async {
    final businessId = _businessId;
    if (businessId == null) return [];

    try {
      final response = await _api.get(
        '/api/sales/$businessId',
        query: {'customerId': customerId, 'limit': 50},
      );
      final rows = (response['data'] as List<dynamic>? ?? const []);
      return rows.cast<Map<String, dynamic>>();
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

    final index = _customers
        .indexWhere((customer) => customer.id == currentSelection.id);
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
