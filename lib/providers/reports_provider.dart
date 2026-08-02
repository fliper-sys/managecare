import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:business_manager/core/utils/formatters.dart';
import '../core/utils/datetime_utils.dart';
import '../providers/auth_provider.dart';
import '../services/managecare_api_client.dart';
import '../data/repositories/sales_repository_supabase.dart';
import '../data/repositories/inventory_repository_supabase.dart';
import '../data/repositories/customer_repository_supabase.dart';
import 'dart:io';
import '../services/web_email_receipt_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../services/pdf_utils.dart';
import '../services/web_download.dart' as web_download;

/// Simple DTO for per-store totals used across reports screens
class StoreSales {
  final String storeId;
  final String storeName;
  final double total;

  StoreSales(
      {required this.storeId, required this.storeName, required this.total});
}

/// Simple DTO for per-warehouse totals used across reports screens
class WarehouseSales {
  final String warehouseId;
  final String warehouseName;
  final double total;

  WarehouseSales(
      {required this.warehouseId,
      required this.warehouseName,
      required this.total});
}

/// Provider for managing all reports and analytics across the application
class ReportsProvider extends ChangeNotifier {
  final ManagecareApiClient _api = ManagecareApiClient.instance;
  final SalesRepositorySupabase _salesRepo = SalesRepositorySupabase();
  final InventoryRepositorySupabase _inventoryRepo =
      InventoryRepositorySupabase();
  final CustomerRepositorySupabase _customerRepo = CustomerRepositorySupabase();
  AuthProvider? _authProvider;

  // Sales Report Data
  List<SaleReport> _salesReports = [];
  DateTime _salesStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _salesEndDate = DateTime.now();

  // Financial Report Data
  List<FinancialReport> _financialReports = [];

  bool get isComputingFinancials => _isComputingFinancials;
  DateTime _financialStartDate =
      DateTime.now().subtract(const Duration(days: 30));
  DateTime _financialEndDate = DateTime.now();

  // Inventory Report Data
  List<InventoryReport> _inventoryReports = [];

  // Expense Report Data
  final List<Map<String, dynamic>> _expenses = [];

  // Customer Report Data
  List<CustomerReport> _customerReports = [];
  final List<ReportExportHistoryItem> _exportHistory = [];
  bool _scheduledExportsEnabled = false;
  String _scheduledExportFrequency = 'weekly';

  // Loading states
  bool _isLoading = false;
  bool _isComputingFinancials = false;
  String? _error;

  // The custom backend doesn't implement Supabase's Realtime protocol, so
  // these "subscriptions" are polled the same way
  // InventoryRepositorySupabase.streamInventory is (see that class for the
  // fuller explanation).
  static const _pollInterval = Duration(seconds: 15);
  Timer? _salesSubscription;
  Timer? _financialSalesSubscription;
  Timer? _expensesSubscription;
  Timer? _inventorySubscription;
  List<Map<String, dynamic>> _latestSalesDocs = [];
  List<Map<String, dynamic>> _latestExpensesDocs = [];
  final Map<String, double> _inventoryCostCache = {};
  String? _inventoryCostCacheBusinessId;

  ReportsProvider({
    AuthProvider? authProvider,
  }) {
    _authProvider = authProvider;
  }

  String? _currentSubscribedBusinessId;

  Future<Map<String, double>> _getInventoryCostMap(
    String businessId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _inventoryCostCacheBusinessId == businessId &&
        _inventoryCostCache.isNotEmpty) {
      return Map<String, double>.from(_inventoryCostCache);
    }

    try {
      final items = await _inventoryRepo.getInventory(businessId);
      final nextCache = <String, double>{};
      for (final raw in items) {
        final data = raw as Map<String, dynamic>;
        final id = (data['id'] ?? '').toString();
        if (id.isEmpty) continue;
        nextCache[id] = (data['cost_price'] as num?)?.toDouble() ?? 0.0;
      }
      _inventoryCostCacheBusinessId = businessId;
      _inventoryCostCache
        ..clear()
        ..addAll(nextCache);
    } catch (e) {
      debugPrint('[ReportsProvider] Inventory cost fallback load failed: $e');
    }

    if (_inventoryCostCacheBusinessId == businessId) {
      return Map<String, double>.from(_inventoryCostCache);
    }
    return <String, double>{};
  }

  double _resolveItemCost(
    Map<String, dynamic> item,
    Map<String, double> inventoryCostMap,
  ) {
    final directCandidates = <dynamic>[
      item['cost'],
      item['costPrice'],
      item['unitCost'],
      item['purchasePrice'],
      item['inventoryCost'],
    ];
    for (final candidate in directCandidates) {
      final parsed = _toDouble(candidate);
      if (parsed != null) return parsed;
    }

    final nestedProduct = item['product'];
    if (nestedProduct is Map<String, dynamic>) {
      final nestedCandidates = <dynamic>[
        nestedProduct['cost'],
        nestedProduct['costPrice'],
        nestedProduct['purchasePrice'],
        nestedProduct['averageCost'],
      ];
      for (final candidate in nestedCandidates) {
        final parsed = _toDouble(candidate);
        if (parsed != null) return parsed;
      }
    }

    final productId =
        (item['productId'] ??
                item['product_id'] ??
                item['inventoryProductId'] ??
                item['id'] ??
                (nestedProduct is Map<String, dynamic>
                    ? nestedProduct['id']
                    : null))
            ?.toString();
    if (productId == null || productId.isEmpty) {
      return 0.0;
    }
    return inventoryCostMap[productId] ?? 0.0;
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.\-]'), '');
      return double.tryParse(cleaned);
    }
    return null;
  }

  List<Map<String, dynamic>> _normalizeSaleProducts(dynamic rawItems) {
    if (rawItems is! List) return const [];
    return rawItems.map<Map<String, dynamic>>((raw) {
      final item =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final name = _extractStringValue(
            item['productName'] ??
                item['product_name'] ??
                item['name'] ??
                item['title'] ??
                item['product'],
          ) ??
          'Unknown Product';
      final unitPrice = _toDouble(
            item['unitPrice'] ??
                item['price'] ??
                item['unit_price'] ??
                item['sellingPrice'],
          ) ??
          0.0;
      final quantity = _toDouble(
            item['quantity'] ??
                item['qty'] ??
                item['volume'] ??
                item['litres'] ??
                item['liters'] ??
                item['quantity_sold'] ??
                item['quantitySold'],
          ) ??
          1.0;
      return {
        'id':
            (item['productId'] ?? item['product_id'] ?? item['id'] ?? '')
                .toString(),
        'productId':
            (item['productId'] ?? item['product_id'] ?? item['id'] ?? '')
                .toString(),
        'productName': name,
        'name': name,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'price': unitPrice,
        'unit': item['unit'] ?? item['uom'] ?? item['saleUnit'] ?? item['sale_unit'],
        'pricingMode': item['pricingMode'] ?? item['pricing_mode'],
        'inventoryUnit': item['inventoryUnit'] ?? item['inventory_unit'],
        'saleUnit': item['saleUnit'] ?? item['sale_unit'],
        'saleUnitMultiplier':
            _toDouble(item['saleUnitMultiplier'] ?? item['sale_unit_multiplier']) ??
                1.0,
        'total': _toDouble(item['total'] ?? item['lineTotal'] ?? item['amount']) ??
            (quantity * unitPrice),
      };
    }).toList();
  }

  Map<String, dynamic> _normalizeSaleForClient(Map<String, dynamic> raw) {
    final data = Map<String, dynamic>.from(raw);
    final items = _normalizeSaleProducts(data['items']);
    final finalAmount = _toDouble(
          data['finalAmount'] ?? data['final_amount'] ?? data['total'],
        ) ??
        0.0;
    final totalAmount = _toDouble(
          data['totalAmount'] ?? data['total_amount'] ?? data['subtotal'],
        ) ??
        finalAmount;

    data
      ..['businessId'] = (data['businessId'] ?? data['business_id'] ?? '')
          .toString()
      ..['customerId'] = data['customerId'] ?? data['customer_id']
      ..['customerName'] = _extractStringValue(
            data['customerName'] ?? data['customer_name'],
          ) ??
          ''
      ..['workerId'] = data['workerId'] ?? data['worker_id']
      ..['workerName'] = _extractStringValue(
            data['workerName'] ?? data['worker_name'],
          ) ??
          ''
      ..['storeId'] = data['storeId'] ?? data['store_id']
      ..['totalAmount'] = totalAmount
      ..['discountAmount'] = _toDouble(
            data['discountAmount'] ?? data['discount_amount'] ?? data['discount'],
          ) ??
          0.0
      ..['taxAmount'] = _toDouble(data['taxAmount'] ?? data['tax_amount']) ?? 0.0
      ..['finalAmount'] = finalAmount
      ..['paymentMethod'] = (data['paymentMethod'] ??
              data['payment_method'] ??
              data['payment'] ??
              '')
          .toString()
      ..['saleType'] = (data['saleType'] ?? data['sale_type'] ?? 'retail')
          .toString()
      ..['createdBy'] = (data['createdBy'] ?? data['created_by'] ?? '')
          .toString()
      ..['createdAt'] = data['createdAt'] ?? data['created_at']
      ..['updatedAt'] = data['updatedAt'] ?? data['updated_at']
      ..['items'] = items;

    return data;
  }

  /// Helper to extract error message from wrapped or unwrapped exceptions
  static String extractErrorMessage(dynamic error) {
    try {
      if (error == null) return 'Unknown error';

      // Try to access 'error' property for boxed errors (web platform)
      if (error is Map && error.containsKey('error')) {
        return error['error'].toString();
      }

      // For wrapped exceptions, try to extract the actual message
      String str = error.toString();
      if (str.contains('Exception:') && !str.startsWith('Exception')) {
        str = str.split('Exception:').last.trim();
      }

      return str.isEmpty ? 'Unknown error' : str;
    } catch (_) {
      return error.toString();
    }
  }

  /// Helper to safely extract string values from Firestore data that might be Maps
  static String? _extractStringValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) {
      // Try common keys that might contain the actual string value
      final possibleKeys = ['name', 'value', 'text', 'displayName', 'fullName'];
      for (final key in possibleKeys) {
        if (value.containsKey(key) && value[key] is String) {
          return value[key] as String;
        }
      }
      // If no string keys found, convert the map to string as fallback
      return value.toString();
    }
    // For other types, convert to string
    return value.toString();
  }

  /// Set `AuthProvider` when this provider is created via ProxyProvider
  void setAuthProvider(AuthProvider? authProvider) {
    _authProvider = authProvider;
    // If we gained a businessId, ensure subscriptions are initialized for the default ranges
    final bid = _currentSubscribedBusinessId ??
        _authProvider?.currentUser?.currentBusinessId ??
        _authProvider?.currentUser?.preferredBusinessId ??
        _authProvider?.currentUser?.businessId ??
        '';
    // Defer subscription initialization to the next frame so we don't call
    // notifyListeners() synchronously during a widget build which can cause
    // "setState() or markNeedsBuild() called during build" exceptions.
    if (bid.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          // Only subscribe if we haven't already subscribed
          if (_salesSubscription == null) {
            subscribeToSalesReports(businessId: bid);
          }
          if (_salesSubscription == null || _financialReports.isEmpty) {
            subscribeToFinancialReports(businessId: bid);
          }
          if (_inventorySubscription == null) {
            subscribeToInventoryReports(businessId: bid);
          }
          if (_expensesSubscription == null) {
            subscribeToExpensesReports(businessId: bid);
          }
        } catch (e) {
          debugPrint('[ReportsProvider] Deferred subscription failed: $e');
        }
      });
    }
  }

  // Getters
  List<SaleReport> get salesReports => _salesReports;
  List<FinancialReport> get financialReports => _financialReports;
  List<InventoryReport> get inventoryReports => _inventoryReports;
  List<Map<String, dynamic>> get expenses => _expenses;
  List<CustomerReport> get customerReports => _customerReports;
  List<ReportExportHistoryItem> get exportHistory =>
      List.unmodifiable(_exportHistory);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get scheduledExportsEnabled => _scheduledExportsEnabled;
  String get scheduledExportFrequency => _scheduledExportFrequency;

  DateTime get salesStartDate => _salesStartDate;
  DateTime get salesEndDate => _salesEndDate;
  DateTime get financialStartDate => _financialStartDate;
  DateTime get financialEndDate => _financialEndDate;

  void setScheduledExport({
    required bool enabled,
    String? frequency,
  }) {
    _scheduledExportsEnabled = enabled;
    if (frequency != null && frequency.isNotEmpty) {
      _scheduledExportFrequency = frequency;
    }
    notifyListeners();
  }

  void addExportHistory({
    required String fileName,
    required String format,
    required String reportType,
    String? filePath,
    int? bytes,
  }) {
    _exportHistory.insert(
      0,
      ReportExportHistoryItem(
        fileName: fileName,
        format: format,
        reportType: reportType,
        exportedAt: DateTime.now(),
        filePath: filePath,
        bytes: bytes,
      ),
    );
    if (_exportHistory.length > 20) {
      _exportHistory.removeRange(20, _exportHistory.length);
    }
    notifyListeners();
  }

  // Date range setters
  void setSalesDateRange(DateTime start, DateTime end) {
    _salesStartDate = start;
    _salesEndDate = end;
    // Defer the subscription update to avoid triggering notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        subscribeToSalesReports(businessId: _currentSubscribedBusinessId);
      } catch (e) {
        debugPrint('[ReportsProvider] Deferred sales subscription failed: $e');
      }
    });
    notifyListeners();
  }

  void setFinancialDateRange(DateTime start, DateTime end) {
    _financialStartDate = start;
    _financialEndDate = end;
    // Defer the subscription update to avoid triggering notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        subscribeToFinancialReports(businessId: _currentSubscribedBusinessId);
      } catch (e) {
        debugPrint(
            '[ReportsProvider] Deferred financial subscription failed: $e');
      }
    });
    notifyListeners();
  }

  // Helper: parse a Firestore date/timestamp into a DateTime safely
  DateTime _parseDate(dynamic raw) {
    final dt = parseTimestamp(raw);
    return dt;
  }

  /// Get per-store sales totals for a given date range

  Future<List<StoreSales>> getStoreSalesBreakdown(
      {String? businessId, DateTime? start, DateTime? end}) async {
    final bid = businessId ??
        _currentSubscribedBusinessId ??
        _authProvider?.currentUser?.currentBusinessId ??
        _authProvider?.currentUser?.preferredBusinessId ??
        _authProvider?.currentUser?.businessId;
    if (bid == null || bid.isEmpty) throw Exception('No business ID found');

    final startDate = start ?? _salesStartDate;
    final endDate = (end ?? _salesEndDate).add(const Duration(days: 1));

    final sales = await _salesRepo.fetchSales(
      businessId: bid,
      start: startDate,
      end: endDate,
    );

    final Map<String, double> totals = {};
    for (var data in sales) {
      final storeId =
          (data['store_id'] as String?)?.toString() ?? 'unassigned';
      final amount = ((data['final_amount'] ??
              data['total_amount'] ??
              0) as num)
          .toDouble();
      totals[storeId] = (totals[storeId] ?? 0.0) + amount;
    }

    // Map store ids to human-friendly names
    final storesData = await _api.get('/api/stores/$bid');
    final Map<String, String> storeNames = {};
    for (final raw in (storesData as List? ?? [])) {
      final data = raw as Map<String, dynamic>;
      storeNames[(data['id'] ?? '').toString()] =
          (data['name'] as String?) ?? '';
    }

    final result = totals.entries
        .map((e) => StoreSales(
              storeId: e.key,
              storeName: storeNames[e.key] ??
                  (e.key == 'unassigned' ? 'Unassigned' : 'Unknown'),
              total: e.value,
            ))
        .toList();

    result.sort((a, b) => b.total.compareTo(a.total));
    return result;
  }

  /// Build warehouse sales from raw sales document maps and a map of warehouse names.
  /// This helper is static so it can be unit tested without needing Firestore.
  static List<WarehouseSales> buildWarehouseSalesFromRaw(
      List<Map<String, dynamic>> salesDocs,
      Map<String, String> warehouseNames) {
    final Map<String, double> totals = {};

    for (final data in salesDocs) {
      final warehouseId =
          (data['warehouseId'] as String?)?.toString() ?? 'unassigned';
      final amount = ((data['finalAmount'] ??
              data['totalAmount'] ??
              data['total'] ??
              0) as num)
          .toDouble();
      totals[warehouseId] = (totals[warehouseId] ?? 0.0) + amount;
    }

    final result = totals.entries
        .map((e) => WarehouseSales(
              warehouseId: e.key,
              warehouseName: warehouseNames[e.key] ??
                  (e.key == 'unassigned' ? 'Unassigned' : 'Unknown'),
              total: e.value,
            ))
        .toList();

    result.sort((a, b) => b.total.compareTo(a.total));
    return result;
  }

  /// Get per-warehouse sales totals for a given date range (used by Wholesale)
  // TODO(migration): the wholesale/distributor vertical (warehouses,
  // distributor_sales, distributors) hasn't been migrated to the custom
  // backend yet - there's no `warehouses` table. This has no confirmed UI
  // call sites currently, so it's stubbed rather than guessed at; revisit
  // when the wholesale vertical migration happens.
  Future<List<WarehouseSales>> getWarehouseSalesBreakdown(
      {String? businessId, DateTime? start, DateTime? end}) async {
    return const [];
  }

  /// Get payment method breakdown for a business within a date range (aggregates values per method)
  Future<Map<String, double>> getPaymentMethodBreakdown(
      {String? businessId, DateTime? start, DateTime? end}) async {
    final bid = businessId ??
        _currentSubscribedBusinessId ??
        _authProvider?.currentUser?.currentBusinessId ??
        _authProvider?.currentUser?.preferredBusinessId ??
        _authProvider?.currentUser?.businessId;
    if (bid == null || bid.isEmpty) throw Exception('No business ID found');

    final startDate = start ?? _financialStartDate;
    final endDate = (end ?? _financialEndDate).add(const Duration(days: 1));

    final sales = await _salesRepo.fetchSales(
      businessId: bid,
      start: startDate,
      end: endDate,
    );

    final Map<String, double> totals = {};
    for (final data in sales) {
      final method = (data['payment_method'] as String?) ?? 'unknown';
      final amt = ((data['final_amount'] ?? data['total_amount'] ?? 0) as num)
          .toDouble();
      totals[method] = (totals[method] ?? 0.0) + amt;
    }

    return totals;
  }

  /// One-off fetch for sales documents with optional search (used by settings/export UI)
  Future<List<Map<String, dynamic>>> fetchSalesList({
    String? businessId,
    DateTime? start,
    DateTime? end,
    String? search,
    int limit = 1000,
  }) async {
    final bid = businessId ??
        _currentSubscribedBusinessId ??
        _authProvider?.currentUser?.currentBusinessId ??
        _authProvider?.currentUser?.preferredBusinessId ??
        _authProvider?.currentUser?.businessId;
    if (bid == null || bid.isEmpty) throw Exception('No business ID found');

    final startDate = start ?? _salesStartDate;
    final endDate = (end ?? _salesEndDate).add(const Duration(days: 1));

    final sales = await _salesRepo.fetchSales(
      businessId: bid,
      start: startDate,
      end: endDate,
      limit: limit,
    );

    List<Map<String, dynamic>> list = sales.map((data) {
      final normalized = _normalizeSaleForClient(data);
      final id = (normalized['id'] ?? data['id'] ?? '').toString();
      normalized.remove('id');
      return {'id': id, 'data': normalized};
    }).toList();

    if (list.length > limit) list = list.sublist(0, limit);

    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      final filtered = list.where((item) {
        final data = item['data'] as Map<String, dynamic>;
        final id = (item['id'] as String).toLowerCase();
        final customer = (data['customerName'] ??
                data['customer_name'] ??
                '')
            .toString()
            .toLowerCase();
        final pm = (data['paymentMethod'] ?? data['payment_method'] ?? '')
            .toString()
            .toLowerCase();
        final cashier = (data['workerName'] ?? data['worker_name'] ?? '')
            .toString()
            .toLowerCase();
        final products = ((data['items'] as List?) ?? []).map((it) {
          if (it is Map) {
            return ((it['name'] ?? it['productName'] ?? it['product_name']) ?? '')
                .toString()
                .toLowerCase();
          }
          return it.toString().toLowerCase();
        }).join(' ');
        return id.contains(q) ||
            customer.contains(q) ||
            pm.contains(q) ||
            cashier.contains(q) ||
            products.contains(q);
      }).toList();
      return filtered.cast<Map<String, dynamic>>();
    }

    return list;
  }

  /// Delete a sale. The backend restores inventory and writes the audit log
  /// (`sale_deletions` table) atomically as part of the DELETE call
  /// (routes/sales.js) - this used to be a client-side transaction (and a
  /// separate web-specific fallback, since Firestore transactions behaved
  /// differently there) but a REST DELETE doesn't have that platform split.
  Future<Map<String, dynamic>?> deleteSale(String saleId,
      {String? businessId}) async {
    final bid = businessId ??
        _currentSubscribedBusinessId ??
        _authProvider?.currentUser?.currentBusinessId ??
        _authProvider?.currentUser?.preferredBusinessId ??
        _authProvider?.currentUser?.businessId;
    if (bid == null || bid.isEmpty) throw Exception('No business ID found');

    try {
      final response = await _salesRepo.deleteSaleForBusiness(bid, saleId);

      if (_salesSubscription != null) {
        subscribeToSalesReports(businessId: bid);
      }

      return {
        'businessId': bid,
        'success': true,
        if (response != null) ...response,
      };
    } catch (e, st) {
      final errMsg = extractErrorMessage(e);
      debugPrint('[ReportsProvider.deleteSale] Error: $errMsg');
      debugPrint('[ReportsProvider.deleteSale] stack trace: $st');
      return {'success': false, 'error': errMsg, 'stack': st.toString()};
    }
  }

  SaleReport _buildSaleReport(Map<String, dynamic> data) {
    final date = _parseDate(data['createdAt'] ?? data['created_at']);
    final products = _normalizeSaleProducts(data['items']);

    return SaleReport(
      date: date,
      category: data['category'] ?? data['sale_type'] ?? 'N/A',
      itemsCount: products.length,
      totalAmount: ((data['totalAmount'] ??
              data['final_amount'] ??
              data['total_amount'] ??
              0) as num)
          .toDouble(),
      cashier: _extractStringValue(data['workerName']) ??
          _extractStringValue(data['worker_name']) ??
          'N/A',
      paymentMethod: _extractStringValue(data['paymentMethod']) ??
          _extractStringValue(data['payment_method']) ??
          'N/A',
      productNames: products
          .map((p) => _extractStringValue(p['name']) ?? 'Unknown')
          .toList(),
      products: products,
      receiptId: (data['id'] ?? '').toString(),
      customerId: _extractStringValue(data['customerId']) ??
          _extractStringValue(data['customer_id']) ??
          '',
      customerName: _extractStringValue(data['customerName']) ??
          _extractStringValue(data['customer_name']) ??
          '',
    );
  }

  Future<void> _fetchSalesReportsInternal(String bid) async {
    final sales = await _salesRepo.fetchSales(
      businessId: bid,
      start: _salesStartDate,
      end: _salesEndDate.add(const Duration(days: 1)),
    );
    _latestSalesDocs = sales;
    _salesReports = sales.map(_buildSaleReport).toList();
  }

  /// Poll for sales report updates (see class-level note on why this polls
  /// instead of subscribing to a realtime stream).
  void subscribeToSalesReports({String? businessId}) {
    _salesSubscription?.cancel();
    _isLoading = true;
    notifyListeners();

    final bid = businessId ??
        _currentSubscribedBusinessId ??
        _authProvider?.currentUser?.currentBusinessId ??
        _authProvider?.currentUser?.preferredBusinessId ??
        _authProvider?.currentUser?.businessId ??
        '';
    _currentSubscribedBusinessId = bid;
    debugPrint(
        '[subscribeToSalesReports] Invoked with businessId: $businessId; resolved bid: $bid; start: $_salesStartDate, end: $_salesEndDate');
    if (bid.isEmpty) {
      _error = 'No business ID found';
      _isLoading = false;
      notifyListeners();
      return;
    }

    Future<void> poll() async {
      try {
        await _fetchSalesReportsInternal(bid);
        _isLoading = false;
        _error = null;
        debugPrint(
            '[subscribeToSalesReports] Sales count: ${_salesReports.length}');
        notifyListeners();
      } catch (e) {
        _error = 'Failed to subscribe to sales: $e';
        _isLoading = false;
        notifyListeners();
      }
    }

    unawaited(poll());
    _salesSubscription = Timer.periodic(_pollInterval, (_) => poll());
  }

  Future<List<Map<String, dynamic>>> _fetchExpensesInternal(
    String bid, {
    DateTime? start,
    DateTime? end,
  }) async {
    final response = await _api.get('/api/expenses/$bid', query: {
      'limit': 100,
      if (start != null) 'startDate': start.toIso8601String(),
      if (end != null) 'endDate': end.toIso8601String(),
    });
    final data = (response['data'] as List?) ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  /// Poll for financial report updates (sales + expenses), recomputing on
  /// each tick (see class-level note on why this polls instead of
  /// subscribing to a realtime stream).
  void subscribeToFinancialReports({String? businessId}) {
    _expensesSubscription?.cancel();
    _financialSalesSubscription?.cancel();
    _isLoading = true;
    notifyListeners();

    final bid = businessId ??
        _currentSubscribedBusinessId ??
        _authProvider?.currentUser?.currentBusinessId ??
        _authProvider?.currentUser?.preferredBusinessId ??
        _authProvider?.currentUser?.businessId;
    _currentSubscribedBusinessId = bid;
    debugPrint(
        '[subscribeToFinancialReports] Invoked with businessId: $businessId; resolved bid: $bid; start: $_financialStartDate, end: $_financialEndDate');
    if (bid == null || bid.isEmpty) {
      _error = 'No business ID found';
      _isLoading = false;
      notifyListeners();
      return;
    }

    Future<void> poll() async {
      try {
        final salesEnd = _financialEndDate.add(const Duration(days: 1));
        _latestSalesDocs = await _salesRepo.fetchSales(
          businessId: bid,
          start: _financialStartDate,
          end: salesEnd,
        );
        _latestExpensesDocs = await _fetchExpensesInternal(
          bid,
          start: _financialStartDate,
          end: salesEnd,
        );
        await _recomputeFinancialReports(bid);
      } catch (e) {
        _error = 'Failed to subscribe to financials: $e';
        _isLoading = false;
        notifyListeners();
      }
    }

    unawaited(poll());
    _financialSalesSubscription = Timer.periodic(_pollInterval, (_) => poll());
  }

  Future<void> _recomputeFinancialReports(String bid) async {
    try {
      // Mark that we're computing heavier financial stats (inline load state)
      _isComputingFinancials = true;
      notifyListeners();
      final inventoryCostMap = await _getInventoryCostMap(bid);

      // monthlyData maps month -> (revenue, cogs, otherExpenses)
      final monthlyData = <int, (double, double, double)>{};

      // compute revenue & cogs from sales
      for (var data in _latestSalesDocs) {
        final date = _parseDate(data['createdAt'] ?? data['created_at']);
        if (date.isAfter(
                _financialStartDate.subtract(const Duration(days: 1))) &&
            date.isBefore(_financialEndDate.add(const Duration(days: 1)))) {
          final month = date.month;
          final grossRevenue = ((data['totalAmount'] ??
                  data['final_amount'] ??
                  data['total_amount'] ??
                  0) as num)
              .toDouble();

          // If part or all of this sale was returned/refunded, subtract the
          // refunded amount so profit isn't overstated.
          final returnAmount =
              ((data['returnAmount'] ?? data['return_amount'] ?? 0) as num)
                  .toDouble();
          final revenue =
              (grossRevenue - returnAmount).clamp(0, double.infinity).toDouble();

          final items = data['items'] as List? ?? [];
          double cogsForSale = 0.0;
          for (var item in items) {
            if (item is Map<String, dynamic>) {
              final itemCost = _resolveItemCost(item, inventoryCostMap);
              final itemQty = ((item['inventoryQuantity'] ??
                          item['quantity'] ??
                          1) as num)
                      .toDouble();
              cogsForSale += (itemCost * itemQty).toDouble();
            }
          }
          // Without item-level return details, approximate the COGS for the
          // returned portion proportionally to the sale's overall cost
          // ratio, so a partial refund doesn't leave COGS for goods that
          // came back.
          if (returnAmount > 0 && grossRevenue > 0) {
            final returnedFraction =
                (returnAmount / grossRevenue).clamp(0.0, 1.0);
            cogsForSale = cogsForSale * (1 - returnedFraction);
          }
          if (monthlyData.containsKey(month)) {
            final (existingRevenue, existingCogs, existingOther) =
                monthlyData[month]!;
            monthlyData[month] = (
              existingRevenue + revenue,
              existingCogs + cogsForSale,
              existingOther
            );
          } else {
            monthlyData[month] = (revenue, cogsForSale, 0.0);
          }
        }
      }

      // add other expenses from latest expenses fetch
      for (var data in _latestExpensesDocs) {
        final date = _parseDate(data['date'] ?? data['created_at']);
        if (date.isAfter(
                _financialStartDate.subtract(const Duration(days: 1))) &&
            date.isBefore(_financialEndDate.add(const Duration(days: 1)))) {
          final month = date.month;
          final amount = (data['amount'] ?? 0) as num;
          if (monthlyData.containsKey(month)) {
            final (revenue, cogs, existingOther) = monthlyData[month]!;
            monthlyData[month] =
                (revenue, cogs, existingOther + amount.toDouble());
          } else {
            monthlyData[month] = (0.0, 0.0, amount.toDouble());
          }
        }
      }

      _financialReports = monthlyData.entries.map((entry) {
        final (revenue, cogs, otherExpenses) = entry.value;
        return FinancialReport(
          month: entry.key,
          revenue: revenue,
          cogs: cogs,
          expenses: otherExpenses,
          salaries: otherExpenses * 0.6,
          utilities: otherExpenses * 0.4,
        );
      }).toList();

      _isComputingFinancials = false;
      _isLoading = false;
      _error = null;
      debugPrint(
          '[recomputeFinancialReports] Months: ${_financialReports.length}');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to recompute financials: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Subscribe to inventory report updates (optional store scoping)
  InventoryReport _buildInventoryReport(Map<String, dynamic> data) {
    final id = (data['id'] ?? '').toString();
    final cost = (data['cost_price'] as num?)?.toDouble() ?? 0.0;
    return InventoryReport(
      productId: id,
      productName: data['name'] ?? 'Unknown',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      reorderLevel: (data['min_stock_level'] as num?)?.toInt() ?? 10,
      unitPrice: (data['unit_price'] as num?)?.toDouble() ?? 0.0,
      costPrice: cost,
      unit: (data['unit'] ?? 'pc').toString(),
      businessSection: '',
      category: (data['category'] ?? '').toString(),
      lastProcurementAt: _parseDate(data['updated_at']),
    );
  }

  Future<void> _fetchInventoryReportsInternal(String bid,
      {String? storeId}) async {
    final items = await _inventoryRepo.getInventory(bid, storeId: storeId);
    final data = items.cast<Map<String, dynamic>>();

    _inventoryCostCacheBusinessId = bid;
    _inventoryCostCache
      ..clear()
      ..addEntries(data.map((item) => MapEntry(
          (item['id'] ?? '').toString(),
          (item['cost_price'] as num?)?.toDouble() ?? 0.0)));

    _inventoryReports = data.map(_buildInventoryReport).toList();
  }

  /// Poll for inventory report updates (see class-level note on why this
  /// polls instead of subscribing to a realtime stream).
  void subscribeToInventoryReports({String? businessId, String? storeId}) {
    _inventorySubscription?.cancel();
    _isLoading = true;
    notifyListeners();

    final bid = businessId ??
        _currentSubscribedBusinessId ??
        _authProvider?.currentUser?.currentBusinessId ??
        _authProvider?.currentUser?.preferredBusinessId ??
        _authProvider?.currentUser?.businessId;
    _currentSubscribedBusinessId = bid;
    if (bid == null || bid.isEmpty) {
      _error = 'No business ID found';
      _isLoading = false;
      notifyListeners();
      return;
    }

    debugPrint(
        '[subscribeToInventoryReports] Invoked with businessId: $businessId; resolved bid: $bid; storeId: $storeId');

    Future<void> poll() async {
      try {
        await _fetchInventoryReportsInternal(bid, storeId: storeId);
        _isLoading = false;
        _error = null;
        debugPrint(
            '[subscribeToInventoryReports] Inventory count: ${_inventoryReports.length}');
        notifyListeners();
      } catch (e) {
        _error = 'Failed to subscribe to inventory: $e';
        _isLoading = false;
        notifyListeners();
      }
    }

    unawaited(poll());
    _inventorySubscription = Timer.periodic(_pollInterval, (_) => poll());
  }

  /// Cancel all subscriptions
  void unsubscribeFromReportSubscriptions() {
    debugPrint('[unsubscribeFromReportSubscriptions] Cancelling subscriptions');
    _salesSubscription?.cancel();
    _financialSalesSubscription?.cancel();
    _expensesSubscription?.cancel();
    _inventorySubscription?.cancel();
    _salesSubscription = null;
    _financialSalesSubscription = null;
    _expensesSubscription = null;
    _inventorySubscription = null;
  }

  /// Cancel only sales subscription
  void unsubscribeFromSalesReports() {
    debugPrint('[unsubscribeFromSalesReports] Cancelling sales subscription');
    _salesSubscription?.cancel();
    _salesSubscription = null;
    notifyListeners();
  }

  /// Cancel only financial subscription
  void unsubscribeFromFinancialReports() {
    debugPrint(
        '[unsubscribeFromFinancialReports] Cancelling financial subscription');
    _financialSalesSubscription?.cancel();
    _financialSalesSubscription = null;
    notifyListeners();
  }

  /// Cancel only inventory subscription
  void unsubscribeFromInventoryReports() {
    debugPrint(
        '[unsubscribeFromInventoryReports] Cancelling inventory subscription');
    _inventorySubscription?.cancel();
    _inventorySubscription = null;
    notifyListeners();
  }

  /// Cancel only expenses subscription
  void unsubscribeFromExpensesReports() {
    debugPrint(
        '[unsubscribeFromExpensesReports] Cancelling expenses subscription');
    _expensesSubscription?.cancel();
    _expensesSubscription = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unsubscribeFromReportSubscriptions();
    super.dispose();
  }

  // ===================== EXPENSE MANAGEMENT METHODS =====================

  /// Add a new expense record.
  // Note: the backend's `expenses` table has no `receipt_url` column - the
  // receipt-upload feature (WebEmailReceiptService) isn't backed by
  // persisted storage yet, so receiptUrl is kept in the in-memory list for
  // this session but won't survive a reload. Flagged rather than dropped
  // silently.
  Future<void> addExpense({
    required String description,
    required double amount,
    required String category,
    String? receiptUrl,
  }) async {
    try {
      final bid = _currentSubscribedBusinessId ??
          _authProvider?.currentUser?.currentBusinessId ??
          _authProvider?.currentUser?.preferredBusinessId ??
          _authProvider?.currentUser?.businessId;
      if (bid == null || bid.isEmpty) {
        throw Exception('No business ID available');
      }

      final created = await _api.post('/api/expenses/$bid', body: {
        'description': description,
        'amount': amount,
        'category': category,
        'created_by': _authProvider?.currentUser?.id,
      });

      final newExpense = {
        'id': created['id'],
        'description': description,
        'amount': amount,
        'category': category,
        'receiptUrl': receiptUrl,
        'date': DateTime.now(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      _expenses.add(newExpense);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to add expense: $e');
    }
  }

  /// Remove an expense record
  Future<void> removeExpense(String expenseId) async {
    try {
      // if expense has an uploaded receipt, attempt to delete it from server
      final removed =
          _expenses.where((expense) => expense['id'] == expenseId).toList();
      if (removed.isNotEmpty) {
        final receiptUrl = removed.first['receiptUrl'] as String?;
        if (receiptUrl != null && receiptUrl.isNotEmpty) {
          try {
            final service = WebEmailReceiptService();
            await service.deleteUploadedFile(receiptUrl);
          } catch (e) {
            debugPrint(
                '[ReportsProvider.removeExpense] Failed to delete receipt file: $e');
          }
        }
      }

      _expenses.removeWhere((expense) => expense['id'] == expenseId);

      final bid = _currentSubscribedBusinessId ??
          _authProvider?.currentUser?.currentBusinessId ??
          _authProvider?.currentUser?.preferredBusinessId ??
          _authProvider?.currentUser?.businessId;
      if (bid != null && bid.isNotEmpty) {
        await _api.delete('/api/expenses/$bid/$expenseId');
      }

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to remove expense: $e');
    }
  }

  /// Get expenses filtered by category
  List<Map<String, dynamic>> getExpensesByFilter(String category) {
    if (category.toLowerCase() == 'all') {
      return _expenses;
    }
    return _expenses
        .where((expense) =>
            expense['category'].toString().toLowerCase() ==
            category.toLowerCase())
        .toList();
  }

  /// Get total expenses for all time
  String getTotalExpenses() {
    double total = 0;
    for (var expense in _expenses) {
      total += (expense['amount'] as num).toDouble();
    }
    return _formatCurrency(total);
  }

  /// Get total expenses for current month
  String getMonthlyExpenses() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);

    double total = 0;
    for (var expense in _expenses) {
      final expenseDate = _parseDate(expense['date']);
      final expenseMonth = DateTime(expenseDate.year, expenseDate.month, 1);

      if (expenseMonth == currentMonth) {
        total += (expense['amount'] as num).toDouble();
      }
    }
    return _formatCurrency(total);
  }

  /// Get expenses grouped by category with totals
  Map<String, double> getExpensesByCategory() {
    final categoryTotals = <String, double>{};

    for (var expense in _expenses) {
      final category = expense['category'].toString();
      final amount = (expense['amount'] as num).toDouble();

      if (categoryTotals.containsKey(category)) {
        categoryTotals[category] = categoryTotals[category]! + amount;
      } else {
        categoryTotals[category] = amount;
      }
    }

    return categoryTotals;
  }

  /// Export expense report to CSV format
  Future<String> exportExpenseReportToCSV() async {
    try {
      final StringBuffer csvBuffer = StringBuffer();

      // Add headers
      csvBuffer.writeln('Date,Description,Category,Amount,ReceiptUrl');

      // Add expense rows sorted by date (newest first)
      final sortedExpenses = [
        ..._expenses
      ]..sort((a, b) => _parseDate(b['date']).compareTo(_parseDate(a['date'])));

      for (var expense in sortedExpenses) {
        final date = _parseDate(expense['date']);
        final formattedDate =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        csvBuffer.writeln(
            '"$formattedDate","${expense['description']}","${expense['category']}","${expense['amount']}","${expense['receiptUrl'] ?? ''}"');
      }

      // Add summary section
      csvBuffer.writeln('');
      csvBuffer.writeln('Summary');
      csvBuffer.writeln(
          'Total Expenses,${_expenses.fold<double>(0, (sum, exp) => sum + (exp['amount'] as num).toDouble())}');

      // Get expense by category
      final categoryTotals = getExpensesByCategory();
      csvBuffer.writeln('');
      csvBuffer.writeln('By Category');
      for (var entry in categoryTotals.entries) {
        csvBuffer.writeln('${entry.key},${entry.value}');
      }

      return csvBuffer.toString();
    } catch (e) {
      throw Exception('Failed to export expense report: $e');
    }
  }

  /// Export expense report to PDF format.
  Future<String> exportExpenseReportToPDF({
    String businessName = 'Business',
    String? businessAddress,
    String? businessPhone,
    String? businessEmail,
    String? businessLogoUrl,
    String? subscriptionTier,
    String? businessClass,
    String? generatedBy,
  }) async {
    try {
      final branding = await loadPdfBranding(
        businessLogoUrl: businessLogoUrl,
        subscriptionTier: subscriptionTier,
        businessClass: businessClass,
        allowBusinessLogoWithoutTier: true,
      );
      final pdf = pw.Document();
      final now = DateTime.now();
      final expenses = [..._expenses]
        ..sort((a, b) => _parseDate(b['date']).compareTo(_parseDate(a['date'])));
      final totalExpenses = expenses.fold<double>(
        0,
        (sum, expense) => sum + ((expense['amount'] as num?)?.toDouble() ?? 0.0),
      );
      final thisMonth = expenses.fold<double>(0, (sum, expense) {
        final expenseDate = _parseDate(expense['date']);
        final currentMonth = DateTime(now.year, now.month, 1);
        final itemMonth = DateTime(expenseDate.year, expenseDate.month, 1);
        if (itemMonth == currentMonth) {
          return sum + ((expense['amount'] as num?)?.toDouble() ?? 0.0);
        }
        return sum;
      });
      final categoryTotals = getExpensesByCategory();
      final averageExpense = expenses.isEmpty ? 0.0 : totalExpenses / expenses.length;
      final receiptsCount = expenses.where((expense) {
        final receiptUrl = expense['receiptUrl']?.toString() ?? '';
        return receiptUrl.trim().isNotEmpty;
      }).length;

      final currency = NumberFormat.currency(
        locale: 'en_US',
        symbol: branding.currencySymbol,
        decimalDigits: 2,
      );
      final businessDetails = <String>[
        if ((businessAddress ?? '').trim().isNotEmpty) businessAddress!.trim(),
        if ((businessPhone ?? '').trim().isNotEmpty) 'Phone: ${businessPhone!.trim()}',
        if ((businessEmail ?? '').trim().isNotEmpty) 'Email: ${businessEmail!.trim()}',
      ].join(' | ');
      final details = <String>[
        'Generated: ${DateFormat('dd MMM yyyy, HH:mm').format(now)}',
        'Period: All loaded expenses',
        if ((generatedBy ?? '').trim().isNotEmpty)
          'Prepared by: ${generatedBy!.trim()}',
      ];

      pw.Widget sectionHeader(String title, [String? subtitle]) {
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFB42318),
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              if (subtitle != null && subtitle.trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text(
                    subtitle,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.white,
                    ),
                  ),
                ),
            ],
          ),
        );
      }

      pw.Widget metricCard(String label, String value, PdfColor color) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(14),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 12,
                height: 12,
                decoration: pw.BoxDecoration(
                  color: color,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      label,
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      value,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(base: branding.font),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildPdfHeader(
                font: branding.font,
                businessName: businessName,
                businessDetails: businessDetails.isEmpty ? null : businessDetails,
                logoBytes: branding.showBusinessLogo
                    ? branding.businessLogoBytes
                    : branding.manageCareLogoBytes,
              ),
              pw.SizedBox(height: 8),
            ],
          ),
          footer: (context) => pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 4),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ),
          build: (context) => [
            pw.Text(
              'Expense Report',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Detailed expense register with categories, receipts, and recorded-by information.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
              ),
              child: pw.Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  pw.SizedBox(width: 168, child: metricCard('Entries', '${expenses.length}', PdfColor.fromInt(0xFFB42318))),
                  pw.SizedBox(width: 168, child: metricCard('Total Expenses', currency.format(totalExpenses), PdfColor.fromInt(0xFF0F4C81))),
                  pw.SizedBox(width: 168, child: metricCard('This Month', currency.format(thisMonth), PdfColor.fromInt(0xFFF59E0B))),
                  pw.SizedBox(width: 168, child: metricCard('Receipts', '$receiptsCount', PdfColor.fromInt(0xFF0F9D58))),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Report Details',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  ...details.map(
                    (line) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Text(
                        line,
                        style: const pw.TextStyle(
                          fontSize: 9.5,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            sectionHeader('Expense Summary', 'Core totals for the currently loaded expense list.'),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.5),
                1: pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildPdfCell('Metric', bold: true),
                    _buildPdfCell('Value', bold: true, align: pw.TextAlign.right),
                  ],
                ),
                pw.TableRow(children: [
                  _buildPdfCell('Total Expenses'),
                  _buildPdfCell(currency.format(totalExpenses), align: pw.TextAlign.right),
                ]),
                pw.TableRow(children: [
                  _buildPdfCell('This Month'),
                  _buildPdfCell(currency.format(thisMonth), align: pw.TextAlign.right),
                ]),
                pw.TableRow(children: [
                  _buildPdfCell('Average Expense'),
                  _buildPdfCell(currency.format(averageExpense), align: pw.TextAlign.right),
                ]),
                pw.TableRow(children: [
                  _buildPdfCell('Receipt-backed Entries'),
                  _buildPdfCell('$receiptsCount', align: pw.TextAlign.right),
                ]),
              ],
            ),
            pw.SizedBox(height: 14),
            sectionHeader('Expenses by Category'),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.5),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(0.8),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildPdfCell('Category', bold: true),
                    _buildPdfCell('Amount', bold: true),
                    _buildPdfCell('%', bold: true, align: pw.TextAlign.right),
                  ],
                ),
                ...categoryTotals.entries.map((entry) {
                  final share = totalExpenses == 0 ? 0 : (entry.value / totalExpenses) * 100;
                  return pw.TableRow(
                    children: [
                      _buildPdfCell(entry.key),
                      _buildPdfCell(currency.format(entry.value)),
                      _buildPdfCell('${share.toStringAsFixed(1)}%', align: pw.TextAlign.right),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 14),
            sectionHeader('Detailed Expenses', 'Each expense row includes the receipt reference when available.'),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
              columnWidths: const {
                0: pw.FlexColumnWidth(1),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(1.2),
                3: pw.FlexColumnWidth(1),
                4: pw.FlexColumnWidth(1.8),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildPdfCell('Date', bold: true),
                    _buildPdfCell('Description', bold: true),
                    _buildPdfCell('Category', bold: true),
                    _buildPdfCell('Amount', bold: true, align: pw.TextAlign.right),
                    _buildPdfCell('Receipt / Recorded By', bold: true),
                  ],
                ),
                ...expenses.map(
                  (expense) {
                    final receiptUrl = expense['receiptUrl']?.toString() ?? '';
                    final recordedBy = (expense['createdByName'] ??
                            expense['createdBy'] ??
                            expense['submittedBy'] ??
                            'N/A')
                        .toString();
                    return pw.TableRow(
                      children: [
                        _buildPdfCell(DateFormat('dd MMM yyyy').format(_parseDate(expense['date']))),
                        _buildPdfCell(expense['description']?.toString() ?? 'N/A'),
                        _buildPdfCell(expense['category']?.toString() ?? 'N/A'),
                        _buildPdfCell(currency.format((expense['amount'] as num?)?.toDouble() ?? 0.0), align: pw.TextAlign.right),
                        _buildPdfCell(
                          receiptUrl.trim().isNotEmpty ? 'Receipt available\n$recordedBy' : recordedBy,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'This report is auto-generated from live expense records and is optimized for both web downloads and Android sharing.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
      );

      final bytes = Uint8List.fromList(await pdf.save());
      final fileName = 'Expense_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      if (kIsWeb) {
        web_download.downloadBytes(bytes, fileName, 'application/pdf');
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Expense Report');
      }

      return fileName;
    } catch (e) {
      throw Exception('Failed to export expense report as PDF: $e');
    }
  }

  // ===================== SALES REPORT METHODS =====================
  /// Generate sales report with real Firestore data
  Future<void> generateSalesReport({String? businessId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get business ID from parameter, current subscribed business, or auth provider
      String? bid = businessId ??
          _currentSubscribedBusinessId ??
          _authProvider?.currentUser?.currentBusinessId ??
          _authProvider?.currentUser?.preferredBusinessId ??
          _authProvider?.currentUser?.businessId;

      if (bid == null || bid.isEmpty) {
        _error = 'No business ID found';
        _isLoading = false;
        notifyListeners();
        return;
      }

      await _fetchSalesReportsInternal(bid);
      _isLoading = false;
    } catch (e) {
      _error = 'Failed to load sales report: $e';
      _isLoading = false;
    }
    notifyListeners();
  }

  // Financial Report Methods
  /// Generate financial report with real Firestore data
  Future<void> generateFinancialReport({String? businessId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      String? bid = businessId ??
          _currentSubscribedBusinessId ??
          _authProvider?.currentUser?.currentBusinessId ??
          _authProvider?.currentUser?.preferredBusinessId ??
          _authProvider?.currentUser?.businessId;

      if (bid == null || bid.isEmpty) {
        _error = 'No business ID found';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final endDatePlusOne = _financialEndDate.add(const Duration(days: 1));
      _latestSalesDocs = await _salesRepo.fetchSales(
        businessId: bid,
        start: _financialStartDate,
        end: endDatePlusOne,
      );
      _latestExpensesDocs = await _fetchExpensesInternal(
        bid,
        start: _financialStartDate,
        end: endDatePlusOne,
      );
      await _recomputeFinancialReports(bid);
    } catch (e) {
      debugPrint('[FinancialReport] Error: $e');
      _error = 'Failed to load financial report: $e';
      _isComputingFinancials = false;
      _isLoading = false;
    }
    notifyListeners();
  }

  // Inventory Report Methods
  /// Generate inventory report with real Firestore data
  Future<void> generateInventoryReport(
      {String? businessId, String? storeId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get business ID from parameter or auth provider
      String? bid = businessId ??
          _currentSubscribedBusinessId ??
          _authProvider?.currentUser?.currentBusinessId ??
          _authProvider?.currentUser?.preferredBusinessId ??
          _authProvider?.currentUser?.businessId;

      if (bid == null || bid.isEmpty) {
        _error = 'No business ID found';
        _isLoading = false;
        notifyListeners();
        return;
      }

      debugPrint(
          '[generateInventoryReport] Invoked with businessId: $businessId; resolved bid: $bid; storeId: $storeId');
      await _fetchInventoryReportsInternal(bid, storeId: storeId);
      _isLoading = false;
    } catch (e) {
      _error = 'Failed to load inventory report: $e';
      _isLoading = false;
    }
    notifyListeners();
  }

  /// Subscribe to expenses collection to keep in-memory _expenses in sync
  Future<void> _fetchExpensesReportInternal(String bid) async {
    final data = await _fetchExpensesInternal(bid);
    data.sort((a, b) {
      final aDate = _parseDate(a['date'] ?? a['created_at']);
      final bDate = _parseDate(b['date'] ?? b['created_at']);
      return bDate.compareTo(aDate);
    });
    _expenses
      ..clear()
      ..addAll(data);
  }

  /// Poll for expense updates (see class-level note on why this polls
  /// instead of subscribing to a realtime stream).
  void subscribeToExpensesReports({String? businessId}) {
    _expensesSubscription?.cancel();
    _isLoading = true;
    notifyListeners();

    final bid = businessId ??
        _currentSubscribedBusinessId ??
        _authProvider?.currentUser?.currentBusinessId ??
        _authProvider?.currentUser?.preferredBusinessId ??
        _authProvider?.currentUser?.businessId;
    _currentSubscribedBusinessId = bid;
    if (bid == null || bid.isEmpty) {
      _error = 'No business ID found';
      _isLoading = false;
      notifyListeners();
      return;
    }

    Future<void> poll() async {
      try {
        await _fetchExpensesReportInternal(bid);
        _isLoading = false;
        _error = null;
        debugPrint(
            '[subscribeToExpensesReports] Expenses count: ${_expenses.length}');
        notifyListeners();
      } catch (e) {
        _error = 'Failed to subscribe to expenses: $e';
        _isLoading = false;
        notifyListeners();
      }
    }

    unawaited(poll());
    _expensesSubscription = Timer.periodic(_pollInterval, (_) => poll());
  }

  /// Load expenses once without keeping a live subscription.
  Future<void> generateExpenseReport({String? businessId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final bid = businessId ??
          _currentSubscribedBusinessId ??
          _authProvider?.currentUser?.currentBusinessId ??
          _authProvider?.currentUser?.preferredBusinessId ??
          _authProvider?.currentUser?.businessId;
      _currentSubscribedBusinessId = bid;
      if (bid == null || bid.isEmpty) {
        _error = 'No business ID found';
        _isLoading = false;
        notifyListeners();
        return;
      }

      await _fetchExpensesReportInternal(bid);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load expenses report: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Customer Report Methods
  /// Generate customer report with real Firestore data
  Future<void> generateCustomerReport({String? businessId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get business ID from parameter, current subscribed business, or auth provider
      String? bid = businessId ??
          _currentSubscribedBusinessId ??
          _authProvider?.currentUser?.currentBusinessId ??
          _authProvider?.currentUser?.preferredBusinessId ??
          _authProvider?.currentUser?.businessId;

      if (bid == null || bid.isEmpty) {
        _error = 'No business ID found';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final customers = await _customerRepo.getCustomers(bid);

      // For each customer, calculate total spent and orders
      _customerReports = [];
      for (final raw in customers) {
        final customerData = raw as Map<String, dynamic>;
        final customerId = (customerData['id'] ?? '').toString();

        final sales = await _salesRepo.getSales(bid, filters: {
          'customerId': customerId,
        });

        double totalSpent = 0;
        for (final sale in sales) {
          totalSpent +=
              ((sale['final_amount'] ?? sale['total_amount'] ?? 0) as num)
                  .toDouble();
        }

        _customerReports.add(CustomerReport(
          customerId: customerId,
          customerName: customerData['name'] ?? 'Unknown',
          totalSpent: totalSpent,
          totalOrders: sales.length,
          isActive: sales.isNotEmpty,
        ));
      }

      _isLoading = false;
    } catch (e) {
      _error = 'Failed to load customer report: $e';
      _isLoading = false;
    }
    notifyListeners();
  }

  /// Get list of raw sales records for a given customer id
  Future<List<Map<String, dynamic>>> getCustomerTransactions(String customerId,
      {String? businessId}) async {
    try {
      final bid = businessId ??
          _currentSubscribedBusinessId ??
          _authProvider?.currentUser?.businessId;
      if (bid == null || bid.isEmpty || customerId.isEmpty) return [];

      final sales = await _salesRepo.getSales(bid, filters: {
        'customerId': customerId,
      });

      final result = sales.cast<Map<String, dynamic>>().toList();
      result.sort((a, b) {
        final aDate = _parseDate(a['createdAt'] ?? a['created_at']);
        final bDate = _parseDate(b['createdAt'] ?? b['created_at']);
        return bDate.compareTo(aDate);
      });

      return result;
    } catch (e) {
      return [];
    }
  }

  // Export Methods
  Future<String> exportSalesReportToPDF({
    String businessName = 'Business',
    String? businessAddress,
    String? businessPhone,
    String? businessEmail,
    String? businessLogoUrl,
    String? subscriptionTier,
    String? businessClass,
    String? generatedBy,
  }) async {
    try {
      final branding = await loadPdfBranding(
        businessLogoUrl: businessLogoUrl,
        subscriptionTier: subscriptionTier,
        businessClass: businessClass,
        allowBusinessLogoWithoutTier: true,
      );
      final pdf = pw.Document();
      final now = DateTime.now();
      final sales = [..._salesReports]
        ..sort((a, b) => b.date.compareTo(a.date));
      final totalTransactions = sales.length;
      final totalSalesAmount = sales.fold<double>(
        0,
        (sum, sale) => sum + sale.totalAmount,
      );
      final totalItemsSold = sales.fold<int>(
        0,
        (sum, sale) => sum + sale.itemsCount,
      );
      final uniqueCustomers = sales
          .map((sale) => sale.customerName.isNotEmpty
              ? sale.customerName
              : (sale.customerId.isNotEmpty ? sale.customerId : 'Walk-in'))
          .toSet()
          .length;
      final averageSale =
          totalTransactions == 0 ? 0.0 : totalSalesAmount / totalTransactions;
      final categoryTotals = <String, double>{};
      final paymentTotals = <String, int>{};
      final itemRows = <Map<String, dynamic>>[];

      for (final sale in sales) {
        categoryTotals[sale.category] =
            (categoryTotals[sale.category] ?? 0) + sale.totalAmount;
        paymentTotals[sale.paymentMethod] =
            (paymentTotals[sale.paymentMethod] ?? 0) + 1;

        final saleProducts = sale.products.isNotEmpty
            ? sale.products
            : [
                {
                  'name': sale.productNames.isNotEmpty
                      ? sale.productNames.join(', ')
                      : sale.category,
                  'quantity': sale.itemsCount,
                  'unitPrice': sale.itemsCount > 0
                      ? sale.totalAmount / sale.itemsCount
                      : sale.totalAmount,
                  'category': sale.category,
                }
              ];

        for (final product in saleProducts) {
          final quantity = (product['quantity'] as num?)?.toDouble() ?? 1;
          final unitPrice = (product['unitPrice'] as num?)?.toDouble() ??
              (sale.itemsCount > 0 ? sale.totalAmount / sale.itemsCount : 0);
          final lineTotal = unitPrice * quantity;
          itemRows.add({
            'date': sale.date,
            'receiptId': sale.receiptId ?? '',
            'customer': sale.customerName.isNotEmpty
                ? sale.customerName
                : (sale.customerId.isNotEmpty ? sale.customerId : 'Walk-in'),
            'cashier': sale.cashier,
            'paymentMethod': sale.paymentMethod,
            'product': (product['name'] ?? product['productName'] ?? 'Product')
                .toString(),
            'quantity': quantity,
            'unitPrice': unitPrice,
            'lineTotal': lineTotal,
            'saleTotal': sale.totalAmount,
            'saleItems': sale.itemsCount,
            'category': (product['category'] ?? sale.category).toString(),
          });
        }
      }

      itemRows.sort((a, b) {
        final aDate = a['date'] as DateTime;
        final bDate = b['date'] as DateTime;
        return bDate.compareTo(aDate);
      });

      final currency = NumberFormat.currency(
        locale: 'en_US',
        symbol: branding.currencySymbol,
        decimalDigits: 2,
      );
      final businessDetails = <String>[
        if ((businessAddress ?? '').trim().isNotEmpty) businessAddress!.trim(),
        if ((businessPhone ?? '').trim().isNotEmpty) 'Phone: ${businessPhone!.trim()}',
        if ((businessEmail ?? '').trim().isNotEmpty) 'Email: ${businessEmail!.trim()}',
      ].join(' | ');
      final details = <String>[
        'Generated: ${DateFormat('dd MMM yyyy, HH:mm').format(now)}',
        'Period: ${DateFormat('dd MMM yyyy').format(_salesStartDate)} to ${DateFormat('dd MMM yyyy').format(_salesEndDate)}',
        if ((generatedBy ?? '').trim().isNotEmpty)
          'Prepared by: ${generatedBy!.trim()}',
      ];

      pw.Widget sectionHeader(String title, [String? subtitle]) {
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF0F4C81),
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              if (subtitle != null && subtitle.trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text(
                    subtitle,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.white,
                    ),
                  ),
                ),
            ],
          ),
        );
      }

      pw.Widget metricCard(String label, String value, PdfColor color) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(14),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 12,
                height: 12,
                decoration: pw.BoxDecoration(
                  color: color,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      label,
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      value,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(base: branding.font),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildPdfHeader(
                font: branding.font,
                businessName: businessName,
                businessDetails: businessDetails.isEmpty ? null : businessDetails,
                logoBytes: branding.showBusinessLogo
                    ? branding.businessLogoBytes
                    : branding.manageCareLogoBytes,
              ),
              pw.SizedBox(height: 8),
            ],
          ),
          footer: (context) => pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 4),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ),
          build: (context) => [
            pw.Text(
              'Sales Report',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Comprehensive sales activity with customer, product, quantity, and salesperson details.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
              ),
              child: pw.Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  pw.SizedBox(width: 168, child: metricCard('Transactions', '$totalTransactions', PdfColor.fromInt(0xFF0F4C81))),
                  pw.SizedBox(width: 168, child: metricCard('Sales Total', currency.format(totalSalesAmount), PdfColor.fromInt(0xFF0F9D58))),
                  pw.SizedBox(width: 168, child: metricCard('Average Sale', currency.format(averageSale), PdfColor.fromInt(0xFFF59E0B))),
                  pw.SizedBox(width: 168, child: metricCard('Customers', '$uniqueCustomers', PdfColor.fromInt(0xFF7C3AED))),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Report Details',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  ...details.map(
                    (line) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Text(
                        line,
                        style: const pw.TextStyle(
                          fontSize: 9.5,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            sectionHeader('Transaction Overview', 'One row per sale, with the customer and salesperson context.'),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.15),
                1: pw.FlexColumnWidth(1.25),
                2: pw.FlexColumnWidth(1.6),
                3: pw.FlexColumnWidth(1.4),
                4: pw.FlexColumnWidth(1.2),
                5: pw.FlexColumnWidth(1.1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildPdfCell('Date', bold: true),
                    _buildPdfCell('Receipt', bold: true),
                    _buildPdfCell('Customer', bold: true),
                    _buildPdfCell('Payment', bold: true),
                    _buildPdfCell('Salesperson', bold: true),
                    _buildPdfCell('Total', bold: true, align: pw.TextAlign.right),
                  ],
                ),
                ...sales.map(
                  (sale) => pw.TableRow(
                    children: [
                      _buildPdfCell(DateFormat('dd MMM yyyy').format(sale.date)),
                      _buildPdfCell(sale.receiptId ?? 'N/A'),
                      _buildPdfCell(
                        sale.customerName.isNotEmpty
                            ? sale.customerName
                            : (sale.customerId.isNotEmpty ? sale.customerId : 'Walk-in'),
                      ),
                      _buildPdfCell(sale.paymentMethod),
                      _buildPdfCell(sale.cashier),
                      _buildPdfCell(currency.format(sale.totalAmount), align: pw.TextAlign.right),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      sectionHeader('Sales by Category'),
                      pw.SizedBox(height: 8),
                      pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
                        columnWidths: const {
                          0: pw.FlexColumnWidth(1.5),
                          1: pw.FlexColumnWidth(1),
                          2: pw.FlexColumnWidth(0.8),
                        },
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                            children: [
                              _buildPdfCell('Category', bold: true),
                              _buildPdfCell('Amount', bold: true),
                              _buildPdfCell('%', bold: true, align: pw.TextAlign.right),
                            ],
                          ),
                          ...categoryTotals.entries.map((entry) {
                            final share = totalSalesAmount == 0
                                ? 0
                                : (entry.value / totalSalesAmount) * 100;
                            return pw.TableRow(
                              children: [
                                _buildPdfCell(entry.key),
                                _buildPdfCell(currency.format(entry.value)),
                                _buildPdfCell('${share.toStringAsFixed(1)}%', align: pw.TextAlign.right),
                              ],
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      sectionHeader('Payment Method Mix'),
                      pw.SizedBox(height: 8),
                      pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
                        columnWidths: const {
                          0: pw.FlexColumnWidth(1.5),
                          1: pw.FlexColumnWidth(0.8),
                        },
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                            children: [
                              _buildPdfCell('Method', bold: true),
                              _buildPdfCell('Count', bold: true, align: pw.TextAlign.right),
                            ],
                          ),
                          ...paymentTotals.entries.map(
                            (entry) => pw.TableRow(
                              children: [
                                _buildPdfCell(entry.key),
                                _buildPdfCell('${entry.value}', align: pw.TextAlign.right),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            sectionHeader('Detailed Line Items', 'Each product sold appears with quantity, unit price, and the responsible salesperson.'),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.05),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1.45),
                3: pw.FlexColumnWidth(1.15),
                4: pw.FlexColumnWidth(1.15),
                5: pw.FlexColumnWidth(1.1),
                6: pw.FlexColumnWidth(0.9),
                7: pw.FlexColumnWidth(0.95),
                8: pw.FlexColumnWidth(1.05),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildPdfCell('Date', bold: true),
                    _buildPdfCell('Receipt', bold: true),
                    _buildPdfCell('Customer', bold: true),
                    _buildPdfCell('Product', bold: true),
                    _buildPdfCell('Category', bold: true),
                    _buildPdfCell('Salesperson', bold: true),
                    _buildPdfCell('Qty', bold: true, align: pw.TextAlign.right),
                    _buildPdfCell('Unit Price', bold: true, align: pw.TextAlign.right),
                    _buildPdfCell('Line Total', bold: true, align: pw.TextAlign.right),
                  ],
                ),
                ...itemRows.map(
                  (row) => pw.TableRow(
                    children: [
                      _buildPdfCell(DateFormat('dd MMM yyyy').format(row['date'] as DateTime)),
                      _buildPdfCell(row['receiptId']?.toString().isNotEmpty == true ? row['receiptId'].toString() : 'N/A'),
                      _buildPdfCell(row['customer'].toString()),
                      _buildPdfCell(row['product'].toString()),
                      _buildPdfCell(row['category'].toString()),
                      _buildPdfCell(row['cashier'].toString()),
                      _buildPdfCell((row['quantity'] as num).toStringAsFixed(0), align: pw.TextAlign.right),
                      _buildPdfCell(currency.format((row['unitPrice'] as num).toDouble()), align: pw.TextAlign.right),
                      _buildPdfCell(currency.format((row['lineTotal'] as num).toDouble()), align: pw.TextAlign.right),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Sales Summary',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  _buildSummaryRow('Total Sales', currency.format(totalSalesAmount)),
                  _buildSummaryRow('Average Sale', currency.format(averageSale)),
                  _buildSummaryRow('Transactions', '$totalTransactions'),
                  _buildSummaryRow('Items Sold', '$totalItemsSold'),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'This report is auto-generated from live transaction data and can be opened, shared, or downloaded on both web and Android.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
      );

      final bytes = Uint8List.fromList(await pdf.save());
      final fileName = 'Sales_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      if (kIsWeb) {
        web_download.downloadBytes(bytes, fileName, 'application/pdf');
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Sales Report');
      }

      return fileName;
    } catch (e) {
      _error = 'Failed to export PDF: $e';
      notifyListeners();
      rethrow;
    }
  }

  List<pw.Widget> _buildSalesSummaryRows() {
    final summary = getSalesSummary();
    return [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Total Sales:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(formatCurrency((summary['totalSales'] as double))),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Average Sale:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(formatCurrency((summary['averageSale'] as double))),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Total Transactions:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(summary['totalTransactions'].toString()),
        ],
      ),
    ];
  }

  pw.Widget _buildSummaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfCell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColors.black,
        ),
        textAlign: align,
      ),
    );
  }

  Future<String> exportSalesReportToCSV() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'Sales_Report_${DateTime.now().millisecondsSinceEpoch}.csv';
      final filePath = '${directory.path}/$fileName';

      // Generate CSV content
      final csvContent = _generateSalesReportCSV();
      final file = File(filePath);
      await file.writeAsString(csvContent);

      // Share the file
      await Share.shareXFiles([XFile(file.path)], text: 'Sales Report');

      return fileName;
    } catch (e) {
      _error = 'Failed to export CSV: $e';
      notifyListeners();
      rethrow;
    }
  }

  String _generateSalesReportCSV() {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('Sales Report');
    buffer.writeln(
        'Generated on: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    buffer.writeln(
        'Date Range: ${DateFormat('yyyy-MM-dd').format(_salesStartDate)} to ${DateFormat('yyyy-MM-dd').format(_salesEndDate)}');
    buffer.writeln('');
    // Header for itemized rows
    buffer.writeln(
        'Date,SaleId,Customer,Cashier,Payment,Category,Product,Quantity,UnitPrice,LineTotal,SaleAmount');

    // Real data (itemized)
    for (var report in _salesReports) {
      final date = DateFormat('yyyy-MM-dd').format(report.date);
      final saleId = report.receiptId ?? '';
      final customer = report.customerName.isNotEmpty
          ? report.customerName
          : (report.customerId.isNotEmpty ? report.customerId : 'Walk-in');
      for (var p in report.products) {
        final pname = p['name']?.toString().replaceAll(',', ' ') ?? '';
        final qty = (p['quantity'] ?? 1).toString();
        final unit = ((p['unitPrice'] ?? 0) is double)
            ? (p['unitPrice'] as double).toStringAsFixed(2)
            : p['unitPrice'].toString();
        final lineTotal =
            ((p['unitPrice'] ?? 0) as double) * ((p['quantity'] ?? 1) as num);
        buffer.writeln(
            '$date,$saleId,$customer,${report.cashier},${report.paymentMethod},${report.category},$pname,$qty,$unit,${lineTotal.toStringAsFixed(2)},${report.totalAmount.toStringAsFixed(2)}');
      }
    }

    // Summary section
    buffer.writeln('');
    buffer.writeln('SUMMARY');
    final summary = getSalesSummary();
    buffer.writeln(
        'Total Sales,₦${(summary['totalSales'] as double).toStringAsFixed(2)}');
    buffer.writeln(
        'Average Sale,₦${(summary['averageSale'] as double).toStringAsFixed(2)}');
    buffer.writeln('Total Transactions,${summary['totalTransactions']}');

    return buffer.toString();
  }

  Future<String> exportFinancialReportToPDF() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'Financial_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${directory.path}/$fileName';

      // Create PDF document
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            pw.Text(
              'Financial Report',
              style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),

            // Report metadata
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
                  style:
                      const pw.TextStyle(fontSize: 11, color: PdfColors.grey),
                ),
                pw.Text(
                  'Period: ${DateFormat('yyyy-MM-dd').format(_financialStartDate)} to ${DateFormat('yyyy-MM-dd').format(_financialEndDate)}',
                  style:
                      const pw.TextStyle(fontSize: 11, color: PdfColors.grey),
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Financial data table
            pw.Text(
              'Financial Data',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 15),

            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Month',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Revenue',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Expenses',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Profit',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                ..._financialReports.map((report) => pw.TableRow(
                      children: [
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(report.month.toString())),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                                '₦${report.revenue.toStringAsFixed(2)}')),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                                '₦${report.expenses.toStringAsFixed(2)}')),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                                '₦${report.profit.toStringAsFixed(2)}')),
                      ],
                    )),
              ],
            ),
            pw.SizedBox(height: 30),

            // Summary
            pw.Text(
              'Summary',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 15),

            ..._buildFinancialSummaryRows(),

            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text(
              'This is an auto-generated report. For questions, contact support.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      );

      // Save PDF
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // Share the file
      await Share.shareXFiles([XFile(file.path)], text: 'Financial Report');

      return fileName;
    } catch (e) {
      _error = 'Failed to export PDF: $e';
      notifyListeners();
      rethrow;
    }
  }

  List<pw.Widget> _buildFinancialSummaryRows() {
    final summary = getFinancialSummary();
    return [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Total Revenue:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('₦${(summary['totalRevenue'] as double).toStringAsFixed(2)}'),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Total Expenses:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(
              '₦${(summary['totalExpenses'] as double).toStringAsFixed(2)}'),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Total Profit:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('₦${(summary['profit'] as double).toStringAsFixed(2)}'),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Profit Margin:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('${(summary['profitMargin'] as double).toStringAsFixed(2)}%'),
        ],
      ),
    ];
  }

  pw.Widget _buildTableCell(String text,
      {bool isHeader = false, int color = 0xFF000000}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColor.fromInt(color),
        ),
      ),
    );
  }

  Future<String> exportInventoryReportToPDF() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'Inventory_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${directory.path}/$fileName';

      // Create PDF document
      final pdf = pw.Document();

      // Load default PDF font and logo bytes (ensures ₦ renders correctly when available)
      final fontResult = await loadDefaultPdfFont();
      final font = fontResult.font;
      final supportsNaira = fontResult.supportsNaira;
      final logoBytes = await loadBusinessLogoBytes();
      final symbol = supportsNaira ? '₦' : 'NGN ';

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: font),
        build: (context) => [
          // Shared header
          buildPdfHeader(
              font: font,
              businessName: 'Manage Care',
              businessDetails: null,
              logoBytes: logoBytes),

          // Report title
          pw.Text('Inventory Report',
              style:
                  pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(
              'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
              style: const pw.TextStyle(
                  fontSize: 11, color: PdfColor.fromInt(0xFF666666))),
          pw.SizedBox(height: 20),

          // Inventory table
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.5),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1.2),
              5: const pw.FlexColumnWidth(1.5),
              6: const pw.FlexColumnWidth(1),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColor.fromInt(0xFF2C3E50)),
                children: [
                  _buildTableCell('Product ID',
                      isHeader: true, color: 0xFFFFFFFF),
                  _buildTableCell('Product Name',
                      isHeader: true, color: 0xFFFFFFFF),
                  _buildTableCell('Qty', isHeader: true, color: 0xFFFFFFFF),
                  _buildTableCell('Min Level',
                      isHeader: true, color: 0xFFFFFFFF),
                  _buildTableCell('Unit Price',
                      isHeader: true, color: 0xFFFFFFFF),
                  _buildTableCell('Total Value',
                      isHeader: true, color: 0xFFFFFFFF),
                  _buildTableCell('Status', isHeader: true, color: 0xFFFFFFFF),
                ],
              ),
              // Data rows
              for (var report in _inventoryReports)
                pw.TableRow(
                  children: [
                    _buildTableCell(report.productId),
                    _buildTableCell(report.productName),
                    _buildTableCell(report.quantity.toString()),
                    _buildTableCell(report.reorderLevel.toString()),
                    _buildTableCell(
                        '${symbol}${report.unitPrice.toStringAsFixed(2)}'),
                    _buildTableCell(
                        '${symbol}${report.totalValue.toStringAsFixed(2)}'),
                    _buildTableCell(
                      report.isLowStock ? 'Low Stock' : 'OK',
                      color: report.isLowStock ? 0xFFE74C3C : 0xFF27AE60,
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Summary section
          ..._buildInventorySummaryRows(symbol: symbol),
        ],
      ));

      // Save PDF
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // Share the file
      await Share.shareXFiles([XFile(file.path)], text: 'Inventory Report');

      return fileName;
    } catch (e) {
      _error = 'Failed to export PDF: $e';
      notifyListeners();
      rethrow;
    }
  }

  List<pw.Widget> _buildInventorySummaryRows({String symbol = '₦'}) {
    final totalInventoryValue = _inventoryReports.fold<double>(
        0, (sum, report) => sum + report.totalValue);
    final lowStockCount = _inventoryReports.where((r) => r.isLowStock).length;

    return [
      pw.Text('Summary',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(2)
        },
        children: [
          pw.TableRow(
            decoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFFECF0F1)),
            children: [
              _buildTableCell('Metric', isHeader: true),
              _buildTableCell('Value', isHeader: true),
            ],
          ),
          pw.TableRow(
            children: [
              _buildTableCell('Total Items'),
              _buildTableCell(_inventoryReports.length.toString()),
            ],
          ),
          pw.TableRow(
            children: [
              _buildTableCell('Total Inventory Value'),
              _buildTableCell(
                  '${symbol}${totalInventoryValue.toStringAsFixed(2)}'),
            ],
          ),
          pw.TableRow(
            children: [
              _buildTableCell('Low Stock Items'),
              _buildTableCell(
                lowStockCount.toString(),
                color: lowStockCount > 0 ? 0xFFE74C3C : 0xFF27AE60,
              ),
            ],
          ),
        ],
      ),
    ];
  }

  // Summary Statistics Methods
  Map<String, dynamic> getSalesSummary() {
    double totalSales = _salesReports.fold<double>(
        0.0, (sum, report) => sum + report.totalAmount);
    double averageSale =
        _salesReports.isEmpty ? 0 : totalSales / _salesReports.length;
    int totalTransactions = _salesReports.length;

    debugPrint(
        '[getSalesSummary] Sales reports count: ${_salesReports.length}');
    debugPrint(
        '[getSalesSummary] Total Sales: ${totalSales.toStringAsFixed(2)}');
    debugPrint(
        '[getSalesSummary] Average Sale: ${averageSale.toStringAsFixed(2)}');

    return {
      'totalSales': totalSales,
      'averageSale': averageSale,
      'totalTransactions': totalTransactions,
      'trend': _calculateTrend(_salesReports),
    };
  }

  Map<String, dynamic> getFinancialSummary() {
    double totalRevenue = _financialReports.fold<double>(
        0.0, (sum, report) => sum + report.revenue);
    double totalCogs =
        _financialReports.fold<double>(0.0, (sum, report) => sum + report.cogs);
    double totalOtherExpenses = _financialReports.fold<double>(
        0.0, (sum, report) => sum + report.expenses);

    double grossProfit = totalRevenue - totalCogs;
    double totalExpenses = totalOtherExpenses; // operating expenses only
    double totalAllExpenses = totalCogs + totalOtherExpenses;
    double netProfit = totalRevenue - totalCogs - totalOtherExpenses;
    double grossMargin =
        totalRevenue == 0 ? 0 : (grossProfit / totalRevenue) * 100;
    double profitMargin =
        totalRevenue == 0 ? 0 : (netProfit / totalRevenue) * 100;

    debugPrint(
        '[getFinancialSummary] Reports count: ${_financialReports.length}');
    debugPrint(
        '[getFinancialSummary] Total Revenue: ${totalRevenue.toStringAsFixed(2)}');
    debugPrint(
        '[getFinancialSummary] Total COGS: ${totalCogs.toStringAsFixed(2)}');
    debugPrint(
        '[getFinancialSummary] Total Operating Expenses: ${totalExpenses.toStringAsFixed(2)}');
    debugPrint(
        '[getFinancialSummary] Total Expenses (including COGS): ${totalAllExpenses.toStringAsFixed(2)}');
    debugPrint(
        '[getFinancialSummary] Gross Profit: ${grossProfit.toStringAsFixed(2)}');
    debugPrint(
        '[getFinancialSummary] Gross Margin: ${grossMargin.toStringAsFixed(1)}%');
    debugPrint(
        '[getFinancialSummary] Net Profit: ${netProfit.toStringAsFixed(2)}');
    debugPrint(
        '[getFinancialSummary] Net Profit Margin: ${profitMargin.toStringAsFixed(1)}%');

    return {
      'totalRevenue': totalRevenue,
      'totalCogs': totalCogs,
      'totalExpenses': totalExpenses,
      'totalOtherExpenses': totalOtherExpenses,
      'totalAllExpenses': totalAllExpenses,
      'grossProfit': grossProfit,
      'grossMargin': grossMargin,
      'netProfit': netProfit,
      'profit': netProfit, // net profit (backwards compatible)
      'netProfitMargin': profitMargin,
      'profitMargin': profitMargin,
    };
  }

  Map<String, dynamic> getFinancialDeepDive() {
    final summary = getFinancialSummary();
    final startDate = _financialStartDate;
    final endDate = _financialEndDate.add(const Duration(days: 1));
    final inventoryCostMap = Map<String, double>.from(_inventoryCostCache);

    final sales = <Map<String, dynamic>>[];
    double calculatedRevenue = 0.0;
    double calculatedCogs = 0.0;

    for (final data in _latestSalesDocs) {
      final saleDate = _parseDate(data['createdAt'] ?? data['created_at']);
      if (saleDate.isBefore(startDate) || !saleDate.isBefore(endDate)) {
        continue;
      }

      final items = (data['items'] as List?) ?? [];
      final itemRows = <Map<String, dynamic>>[];
      double saleRevenue = 0.0;
      double saleCogs = 0.0;

      for (final rawItem in items) {
        if (rawItem is! Map) continue;
        final item = Map<String, dynamic>.from(rawItem);
        final quantity = _toDouble(
              item['inventoryQuantity'] ??
                  item['quantity'] ??
                  item['qty'] ??
                  item['soldQty'] ??
                  1,
            ) ??
            0.0;
        final unitPrice = _toDouble(
              item['unitPrice'] ??
                  item['price'] ??
                  item['sellingPrice'] ??
                  item['amount'] ??
                  0,
            ) ??
            0.0;
        final costPerUnit = _resolveItemCost(item, inventoryCostMap);
        final lineRevenue = unitPrice * quantity;
        final lineCogs = costPerUnit * quantity;
        final saleMode = (item['pricingMode'] ?? item['saleMode'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        saleRevenue += lineRevenue;
        saleCogs += lineCogs;

        itemRows.add({
          'name': (item['name'] ?? item['productName'] ?? 'Item').toString(),
          'productId': (item['productId'] ?? item['id'] ?? '').toString(),
          'quantity': quantity,
          'unitPrice': unitPrice,
          'costPerUnit': costPerUnit,
          'revenue': lineRevenue,
          'cogs': lineCogs,
          'saleUnit': (item['saleUnit'] ?? item['unit'] ?? '').toString(),
          'inventoryQuantity': _toDouble(item['inventoryQuantity']) ?? quantity,
          'pricingMode': saleMode.isEmpty ? 'retail' : saleMode,
          'isWholesale': saleMode == 'wholesale',
        });
      }

      calculatedRevenue += saleRevenue;
      calculatedCogs += saleCogs;

      sales.add({
        'id': (data['id'] ?? '').toString(),
        'date': saleDate,
        'receiptNumber': (data['receiptNumber'] ?? '').toString(),
        'customerName':
            (data['customerName'] ?? data['customer_name'] ?? 'Walk-in')
                .toString(),
        'paymentMethod':
            (data['paymentMethod'] ?? data['payment_method'] ?? 'cash')
                .toString(),
        'revenue': saleRevenue,
        'cogs': saleCogs,
        'grossProfit': saleRevenue - saleCogs,
        'grossMargin': saleRevenue == 0 ? 0.0 : ((saleRevenue - saleCogs) / saleRevenue) * 100,
        'items': itemRows,
        'isWholesale': itemRows.any((item) => item['isWholesale'] == true),
      });
    }

    sales.sort((left, right) =>
        (right['date'] as DateTime).compareTo(left['date'] as DateTime));

    final expenses = <Map<String, dynamic>>[];
    double operatingExpenses = 0.0;
    for (final data in _latestExpensesDocs) {
      final expenseDate =
          _parseDate(data['date'] ?? data['createdAt'] ?? data['created_at']);
      if (expenseDate.isBefore(startDate) || !expenseDate.isBefore(endDate)) {
        continue;
      }

      final amount = _toDouble(data['amount'] ?? data['value'] ?? 0) ?? 0.0;
      operatingExpenses += amount;
      expenses.add({
        'id': (data['id'] ?? '').toString(),
        'date': expenseDate,
        'amount': amount,
        'category': (data['category'] ?? 'Expense').toString(),
        'description': (data['description'] ?? data['note'] ?? '').toString(),
      });
    }

    return {
      'summary': summary,
      'sales': sales,
      'expenses': expenses,
      'calculatedRevenue': calculatedRevenue,
      'calculatedCogs': calculatedCogs,
      'operatingExpenses': operatingExpenses,
      'netProfit': calculatedRevenue - calculatedCogs - operatingExpenses,
      'grossProfit': calculatedRevenue - calculatedCogs,
      'grossMargin': calculatedRevenue == 0
          ? 0.0
          : ((calculatedRevenue - calculatedCogs) / calculatedRevenue) * 100,
      'netMargin': calculatedRevenue == 0
          ? 0.0
          : ((calculatedRevenue - calculatedCogs - operatingExpenses) /
                  calculatedRevenue) *
              100,
      'startDate': startDate,
      'endDate': _financialEndDate,
    };
  }

  Map<String, dynamic> getInventorySummary() {
    int totalItems =
        _inventoryReports.fold(0, (sum, report) => sum + report.quantity);
    int lowStockItems =
        _inventoryReports.where((r) => r.quantity < r.reorderLevel).length;
    double inventoryValue =
        _inventoryReports.fold(0, (sum, report) => sum + report.totalValue);
    double inventoryCostValue = _inventoryReports.fold(
      0.0,
      (sum, report) => sum + (report.quantity * report.costPrice),
    );

    return {
      'totalItems': totalItems,
      'lowStockItems': lowStockItems,
      'inventoryValue': inventoryValue,
      'inventoryCostValue': inventoryCostValue,
    };
  }

  Map<String, dynamic> getCustomerSummary() {
    int totalCustomers = _customerReports.length;
    int activeCustomers = _customerReports.where((c) => c.isActive).length;
    double averageOrderValue = _customerReports.isEmpty
        ? 0
        : _customerReports.fold(0.0, (sum, c) => sum + c.totalSpent) /
            _customerReports.length;

    return {
      'totalCustomers': totalCustomers,
      'activeCustomers': activeCustomers,
      'averageOrderValue': averageOrderValue,
    };
  }

  /// Get detailed transaction list from sales reports
  List<Map<String, dynamic>>? getDetailedTransactions() {
    if (_salesReports.isNotEmpty) {
      return _salesReports
          .map((report) => {
                'date': report.date.toIso8601String(),
                'description': report.productNames.isNotEmpty
                    ? report.productNames.take(3).join(', ')
                    : '${report.paymentMethod} - ${report.category}',
                'type': 'Sale',
                'amount': report.totalAmount,
                'cashier': report.cashier,
                'items': report.itemsCount,
                'paymentMethod': report.paymentMethod,
              })
          .toList();
    }

    if (_latestSalesDocs.isEmpty) {
      return [];
    }

    return _latestSalesDocs.map((data) {
      final items = (data['items'] as List?) ?? [];
      final itemNames = items
          .map((item) {
            if (item is Map<String, dynamic>) {
              return (item['name'] ??
                      item['productName'] ??
                      item['product_name'] ??
                      '')
                  .toString();
            }
            return item.toString();
          })
          .where((name) => name.trim().isNotEmpty)
          .take(3)
          .join(', ');

      return {
        'date': _parseDate(
          data['saleDate'] ?? data['createdAt'] ?? data['created_at'],
        ).toIso8601String(),
        'description': itemNames.isNotEmpty
            ? itemNames
            : (data['category'] ?? data['sale_type'] ?? 'Sale').toString(),
        'type': 'Sale',
        'amount': ((data['totalAmount'] ??
                data['final_amount'] ??
                data['total_amount'] ??
                0) as num)
            .toDouble(),
        'cashier': (data['cashier'] ??
                data['workerName'] ??
                data['worker_name'] ??
                'N/A')
            .toString(),
        'items': items.length,
        'paymentMethod':
            (data['paymentMethod'] ?? data['payment_method'] ?? 'N/A')
                .toString(),
      };
    }).toList()
      ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
  }

  // Helper methods
  String _calculateTrend(List<SaleReport> reports) {
    if (reports.length < 2) return 'stable';

    double firstHalf = reports
        .take(reports.length ~/ 2)
        .fold(0, (sum, r) => sum + r.totalAmount);
    double secondHalf = reports
        .skip(reports.length ~/ 2)
        .fold(0, (sum, r) => sum + r.totalAmount);

    if (secondHalf > firstHalf) return 'up';
    if (secondHalf < firstHalf) return 'down';
    return 'stable';
  }

  String _formatCurrency(double amount) {
    return formatCurrency(amount);
  }
}

// Report Data Models
class SaleReport {
  final DateTime date;
  final double totalAmount;
  final int itemsCount;
  final String category;
  final List<String> productNames;
  final String paymentMethod;
  final String cashier;
  final List<Map<String, dynamic>> products;
  final String? receiptId;
  final String customerId;
  final String customerName;

  SaleReport({
    required this.date,
    required this.totalAmount,
    required this.itemsCount,
    required this.category,
    this.productNames = const [],
    this.paymentMethod = 'N/A',
    this.cashier = 'N/A',
    this.products = const [],
    this.receiptId,
    this.customerId = '',
    this.customerName = '',
  });
}

class FinancialReport {
  final int month;
  final double revenue;
  final double cogs; // cost of goods sold
  final double expenses; // other expenses (excludes COGS)
  final double salaries;
  final double utilities;

  FinancialReport({
    required this.month,
    required this.revenue,
    required this.cogs,
    required this.expenses,
    required this.salaries,
    required this.utilities,
  });

  /// Gross profit = revenue - COGS
  double get grossProfit => revenue - cogs;

  /// Net profit = gross profit - other expenses
  /// (equivalent to revenue - (COGS + other expenses))
  double get netProfit => grossProfit - expenses;

  /// Backwards-compatible profit value (same as net profit)
  double get profit => netProfit;

  double get profitMargin => revenue == 0 ? 0 : (profit / revenue) * 100;
}

class InventoryReport {
  final String productId;
  final String productName;
  final int quantity;
  final int reorderLevel;
  final double unitPrice; // selling price per unit
  final double costPrice; // cost per unit (purchase/average cost)
  final String unit;
  final String businessSection;
  final String category;
  final DateTime? lastProcurementAt;

  InventoryReport({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.reorderLevel,
    required this.unitPrice,
    this.costPrice = 0.0,
    this.unit = 'pc',
    this.businessSection = '',
    this.category = '',
    this.lastProcurementAt,
  });

  double get totalValue => quantity * unitPrice;
  bool get isLowStock => quantity < reorderLevel;

  double get profitPerUnit => unitPrice - costPrice;
  double get totalProfit => profitPerUnit * quantity;
}


class CustomerReport {
  final String customerId;
  final String customerName;
  final double totalSpent;
  final int totalOrders;
  final bool isActive;

  CustomerReport({
    required this.customerId,
    required this.customerName,
    required this.totalSpent,
    required this.totalOrders,
    required this.isActive,
  });

  double get averageOrderValue =>
      totalOrders == 0 ? 0 : totalSpent / totalOrders;
}

class ReportExportHistoryItem {
  final String fileName;
  final String format;
  final String reportType;
  final DateTime exportedAt;
  final String? filePath;
  final int? bytes;

  ReportExportHistoryItem({
    required this.fileName,
    required this.format,
    required this.reportType,
    required this.exportedAt,
    this.filePath,
    this.bytes,
  });

  String get displaySize {
    final size = bytes ?? 0;
    if (size <= 0) return '-';
    if (size < 1024) return '${size} B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
