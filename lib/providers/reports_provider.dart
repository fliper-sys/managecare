import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:business_manager/core/utils/formatters.dart';
import '../core/utils/datetime_utils.dart';
import '../providers/auth_provider.dart';
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
  late final FirebaseFirestore _firestore;
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

  // Firestore subscriptions
  StreamSubscription<QuerySnapshot>? _salesSubscription;
  StreamSubscription<QuerySnapshot>? _financialSalesSubscription;
  StreamSubscription<QuerySnapshot>? _expensesSubscription;
  StreamSubscription<QuerySnapshot>? _inventorySubscription;
  StreamSubscription<QuerySnapshot>? _customersSubscription;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _latestSalesDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _latestExpensesDocs = [];
  final Map<String, double> _inventoryCostCache = {};
  String? _inventoryCostCacheBusinessId;

  ReportsProvider({
    FirebaseFirestore? firestore,
    AuthProvider? authProvider,
  }) {
    _firestore = firestore ?? FirebaseFirestore.instance;
    _authProvider = authProvider;
  }

  String? _currentSubscribedBusinessId;

  bool _triedTimestampSalesQuery = false;

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
      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('inventory')
          .get();
      final nextCache = <String, double>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        nextCache[doc.id] =
            ((data['averageCost'] ??
                        data['cost'] ??
                        data['lastProcurementCost']) as num?)
                    ?.toDouble() ??
                0.0;
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
        'id': (item['productId'] ?? item['id'] ?? '').toString(),
        'name': name,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'unit': item['unit'] ?? item['uom'] ?? item['saleUnit'],
        'total': _toDouble(item['total'] ?? item['lineTotal'] ?? item['amount']) ??
            (quantity * unitPrice),
      };
    }).toList();
  }

  /// Helper to extract error message from wrapped or unwrapped exceptions
  static String extractErrorMessage(dynamic error) {
    try {
      if (error == null) return 'Unknown error';

      // Try to access 'error' property for boxed errors (web platform)
      if (error is Map && error.containsKey('error')) {
        return error['error'].toString();
      }

      // Handle Future exception where error might be in nested structure
      if (error.runtimeType.toString().contains('Future') ||
          error.toString().contains('Dart exception thrown')) {
        debugPrint(
            '[extractErrorMessage] Detected wrapped Future exception, attempting deep extraction');
        // Try to extract from toString which may contain the actual error
        String str = error.toString();
        if (str.isNotEmpty) {
          // Remove the wrapper message and try to find the actual error
          if (str.contains('Dart exception thrown from converted Future')) {
            return 'Transaction failed - likely a permission or networking issue. Check Firebase console logs.';
          }
        }
      }

      if (error is FirebaseException) {
        final code = error.code;
        final msg = error.message ?? '';
        return '$code${msg.isNotEmpty ? ': $msg' : ''}'.trim();
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

    // Try createdAt (Timestamp) based query first
    var query = _firestore
        .collection('businesses')
        .doc(bid)
        .collection('sales')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

    var snapshot = await query.get();

    if (snapshot.docs.isEmpty) {
      // Fallback to numeric timestamp range
      final tsQuery = _firestore
          .collection('businesses')
          .doc(bid)
          .collection('sales')
          .where('timestamp',
              isGreaterThanOrEqualTo: startDate.millisecondsSinceEpoch)
          .where('timestamp',
              isLessThanOrEqualTo: endDate.millisecondsSinceEpoch);
      snapshot = await tsQuery.get();
    }

    final Map<String, double> totals = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final storeId = (data['storeId'] as String?)?.toString() ?? 'unassigned';
      final amount = ((data['finalAmount'] ??
              data['totalAmount'] ??
              data['total'] ??
              0) as num)
          .toDouble();
      totals[storeId] = (totals[storeId] ?? 0.0) + amount;
    }

    // Map store ids to human-friendly names
    final storesSnapshot = await _firestore
        .collection('businesses')
        .doc(bid)
        .collection('stores')
        .get();
    final Map<String, String> storeNames = {};
    for (var s in storesSnapshot.docs) {
      final data = s.data() as Map<String, dynamic>?;
      storeNames[s.id] = (data?['name'] as String?) ?? '';
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
  Future<List<WarehouseSales>> getWarehouseSalesBreakdown(
      {String? businessId, DateTime? start, DateTime? end}) async {
    final bid = businessId ??
        _currentSubscribedBusinessId ??
        _authProvider?.currentUser?.currentBusinessId ??
        _authProvider?.currentUser?.preferredBusinessId ??
        _authProvider?.currentUser?.businessId;
    if (bid == null || bid.isEmpty) throw Exception('No business ID found');

    final startDate = start ?? _salesStartDate;
    final endDate = (end ?? _salesEndDate).add(const Duration(days: 1));

    var query = _firestore
        .collection('businesses')
        .doc(bid)
        .collection('sales')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

    var snapshot = await query.get();

    if (snapshot.docs.isEmpty) {
      final tsQuery = _firestore
          .collection('businesses')
          .doc(bid)
          .collection('sales')
          .where('timestamp',
              isGreaterThanOrEqualTo: startDate.millisecondsSinceEpoch)
          .where('timestamp',
              isLessThanOrEqualTo: endDate.millisecondsSinceEpoch);
      snapshot = await tsQuery.get();
    }

    final List<Map<String, dynamic>> salesDocs =
        snapshot.docs.map((d) => d.data()).toList();

    // Map warehouse ids to friendly names
    final warehousesSnapshot = await _firestore
        .collection('businesses')
        .doc(bid)
        .collection('warehouses')
        .get();
    final Map<String, String> warehouseNames = {};
    for (var s in warehousesSnapshot.docs) {
      final data = s.data() as Map<String, dynamic>?;
      warehouseNames[s.id] = (data?['name'] as String?) ?? '';
    }

    return buildWarehouseSalesFromRaw(salesDocs, warehouseNames);
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

    var query = _firestore
        .collection('businesses')
        .doc(bid)
        .collection('sales')
        .where('saleDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('saleDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

    var snapshot = await query.get();
    if (snapshot.docs.isEmpty) {
      // fallback to createdAt range
      query = _firestore
          .collection('businesses')
          .doc(bid)
          .collection('sales')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      snapshot = await query.get();
    }

    final Map<String, double> totals = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      // if there are split payments, sum each method individually
      if (data['payments'] is List) {
        for (final p in data['payments']) {
          final method = (p['method'] as String?) ?? 'unknown';
          final amt = ((p['amount'] ?? 0) as num).toDouble();
          totals[method] = (totals[method] ?? 0.0) + amt;
        }
      } else {
        final method = (data['paymentMethod'] as String?) ?? 'unknown';
        final amt = ((data['total'] ??
                data['finalAmount'] ??
                data['totalAmount'] ??
                0) as num)
            .toDouble();
        totals[method] = (totals[method] ?? 0.0) + amt;
      }
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

    // We'll query both the nested business sales and the root 'sales' collection (filtered by businessId)
    // to ensure we capture records written to either location. Combine, dedupe (nested takes precedence), and sort.
    List<QuerySnapshot> snapshots = [];

    try {
      var nestedQuery = _firestore
          .collection('businesses')
          .doc(bid)
          .collection('sales')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('createdAt', descending: true)
          .limit(limit) as dynamic;

      var rootQuery = _firestore
          .collection('sales')
          .where('businessId', isEqualTo: bid) as dynamic;

      // Try to apply createdAt constraints to root query as well
      try {
        rootQuery = rootQuery
            .where('createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .where('createdAt',
                isLessThanOrEqualTo: Timestamp.fromDate(endDate))
            .orderBy('createdAt', descending: true)
            .limit(limit);
      } catch (_) {
        // root docs may not have createdAt as Timestamp or queries may require composite indexes; ignore and fetch by businessId only
        rootQuery = rootQuery.limit(limit);
      }

      final nestedSnap = await nestedQuery.get();
      snapshots.add(nestedSnap);

      final rootSnap = await rootQuery.get();
      snapshots.add(rootSnap);

      // If nested snapshot is empty, try timestamp numeric fallback on nested (older docs may use numeric 'timestamp')
      if (nestedSnap.docs.isEmpty) {
        try {
          final tsQuery = _firestore
              .collection('businesses')
              .doc(bid)
              .collection('sales')
              .where('timestamp',
                  isGreaterThanOrEqualTo: startDate.millisecondsSinceEpoch)
              .where('timestamp',
                  isLessThanOrEqualTo: endDate.millisecondsSinceEpoch)
              .orderBy('timestamp', descending: true)
              .limit(limit);
          final tsSnap = await tsQuery.get();
          snapshots[0] = tsSnap;
        } catch (_) {}
      }
    } catch (e) {
      // If query failed (e.g., composite index required), attempt more permissive fetches
      String errStr = e.toString();
      final isIndexError =
          errStr.contains('failed-precondition') || errStr.contains('index');
      if (isIndexError) {
        debugPrint(
            '[ReportsProvider] fetchSalesList requires Firestore composite index. Creating a composite index on (businessId, createdAt) is recommended for better performance.');
      } else {
        debugPrint(
            '[ReportsProvider] fetchSalesList primary query failed: $errStr');
      }
      try {
        final nestedSnap = await _firestore
            .collection('businesses')
            .doc(bid)
            .collection('sales')
            .limit(limit)
            .get();
        final rootSnap = await _firestore
            .collection('sales')
            .where('businessId', isEqualTo: bid)
            .limit(limit)
            .get();
        snapshots.add(nestedSnap);
        snapshots.add(rootSnap);
      } catch (e2) {
        final errStr2 = extractErrorMessage(e2);
        debugPrint(
            '[ReportsProvider] fetchSalesList fallback failed: $errStr2');
        rethrow;
      }
    }

    // Combine and dedupe (nested docs overwrite root docs)
    final Map<String, Map<String, dynamic>> combined = {};
    if (snapshots.isNotEmpty) {
      // root snapshot is at index 1 if present, nested at 0
      for (final doc in (snapshots.length > 1
          ? snapshots[1].docs
          : <QueryDocumentSnapshot>[])) {
        combined[doc.id] = {
          ...(doc.data() as Map<String, dynamic>),
          'id': doc.id
        };
      }
      for (final doc in snapshots[0].docs) {
        combined[doc.id] = {
          ...(doc.data() as Map<String, dynamic>),
          'id': doc.id
        };
      }
    }

    List<Map<String, dynamic>> list = combined.values
        .map((m) => {'id': m['id'], 'data': m..remove('id')})
        .toList();

    int _createdAtToMillis(dynamic v) {
      if (v == null) return 0;
      if (v is Timestamp) return v.toDate().millisecondsSinceEpoch;
      if (v is DateTime) return v.millisecondsSinceEpoch;
      if (v is num) return v.toInt();
      if (v is String) {
        final p = int.tryParse(v);
        if (p != null) return p;
        final dt = DateTime.tryParse(v);
        if (dt != null) return dt.millisecondsSinceEpoch;
      }
      return 0;
    }

    list.sort((a, b) => _createdAtToMillis(
            (b['data'] as Map)['createdAt'] ?? (b['data'] as Map)['timestamp'])
        .compareTo(_createdAtToMillis((a['data'] as Map)['createdAt'] ??
            (a['data'] as Map)['timestamp'])));

    if (list.length > limit) list = list.sublist(0, limit);

    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      final filtered = list.where((item) {
        final data = item['data'] as Map<String, dynamic>;
        final id = (item['id'] as String).toLowerCase();
        final customer = (data['customerName'] ??
                data['customerDisplayName'] ??
                data['customer'] ??
                '')
            .toString()
            .toLowerCase();
        final pm = (data['paymentMethod'] ?? data['payment'] ?? '')
            .toString()
            .toLowerCase();
        final cashier =
            (data['cashier'] ?? data['workerName'] ?? data['soldBy'] ?? '')
                .toString()
                .toLowerCase();
        final products = ((data['items'] as List?) ?? []).map((it) {
          if (it is Map)
            return ((it['name'] ?? it['productName'] ?? it['title']) ?? '')
                .toString()
                .toLowerCase();
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

  /// Delete a sale document (business-level and optional top-level mirror)
  /// Returns a map with auditId, items and businessId if available so UI can display restored quantities.
  /// Web-specific fallback for deleteSale that avoids complex transaction issues on web platform
  Future<Map<String, dynamic>?> _deleteSaleWeb(
      String saleId, String bid) async {
    try {
      debugPrint(
          '[ReportsProvider.deleteSaleWeb] Using web fallback for sale deletion');

      // Step 1: Read the sale document
      final saleRef = _firestore
          .collection('businesses')
          .doc(bid)
          .collection('sales')
          .doc(saleId);
      final saleSnap = await saleRef.get();

      List<dynamic> items = [];
      Map<String, dynamic> data = {};

      if (saleSnap.exists) {
        data = saleSnap.data() as Map<String, dynamic>;
        items = (data['items'] as List<dynamic>?) ?? [];
      } else {
        // Try root sales collection
        final rootRef = _firestore.collection('sales').doc(saleId);
        final rootSnap = await rootRef.get();
        if (!rootSnap.exists) {
          return {'auditId': null, 'items': [], 'businessId': null};
        }
        data = rootSnap.data() as Map<String, dynamic>;
        items = (data['items'] as List<dynamic>?) ?? [];
      }

      final actualBid = (data['businessId'] ?? bid)?.toString() ?? '';

      // Step 2: Update inventory (without transaction to avoid web issues)
      if (actualBid.isNotEmpty) {
        for (final raw in items) {
          if (raw is! Map<String, dynamic>) continue;
          final pid = (raw['productId'] ?? raw['id'] ?? raw['product_id'] ?? '')
              .toString();
          final qtyNum =
              (raw['quantity'] ?? raw['qty'] ?? raw['quantitySold'] ?? 0);
          double qty;
          try {
            if (qtyNum is num)
              qty = qtyNum.toDouble();
            else {
              final cleaned =
                  qtyNum?.toString().replaceAll(RegExp(r'[^0-9.\-]'), '');
              qty = double.tryParse(cleaned!) ?? 0.0;
            }
          } catch (_) {
            qty = 0.0;
          }

          if (pid.isEmpty || qty <= 0) continue;

          try {
            final invRef = _firestore
                .collection('businesses')
                .doc(actualBid)
                .collection('inventory')
                .doc(pid);
            final invSnap = await invRef.get();

            if (invSnap.exists) {
              await invRef.update({
                'quantity': FieldValue.increment(qty),
                'updatedAt': FieldValue.serverTimestamp(),
              });
            } else {
              await invRef.set({
                'quantity': qty,
                'name': (raw['name'] ?? raw['productName'] ?? '').toString(),
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          } catch (e) {
            debugPrint(
                '[ReportsProvider._deleteSaleWeb] Error updating inventory for $pid: $e');
            // Continue even if inventory update fails
          }
        }

        // Step 3: Create audit log
        try {
          final auditRef = _firestore
              .collection('businesses')
              .doc(actualBid)
              .collection('sale_deletions')
              .doc();
          await auditRef.set({
            'saleId': saleId,
            'deletedBy': _authProvider?.currentUser?.id ?? 'system',
            'items': items,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint(
              '[ReportsProvider._deleteSaleWeb] Error creating audit log: $e');
        }
      }

      // Step 4: Delete the sale documents
      try {
        if (saleSnap.exists) {
          await saleRef.delete();
        }
      } catch (e) {
        debugPrint(
            '[ReportsProvider._deleteSaleWeb] Error deleting business sale: $e');
      }

      try {
        final rootRef = _firestore.collection('sales').doc(saleId);
        final rootSnap = await rootRef.get();
        if (rootSnap.exists) {
          await rootRef.delete();
        }
      } catch (e) {
        debugPrint(
            '[ReportsProvider._deleteSaleWeb] Error deleting root sale: $e');
      }

      // Refresh subscription if active
      try {
        if (_salesSubscription != null) {
          subscribeToSalesReports(businessId: bid);
        }
      } catch (_) {}

      debugPrint(
          '[ReportsProvider._deleteSaleWeb] Sale deletion completed successfully');
      return {
        'auditId': null,
        'items': items,
        'businessId': actualBid,
        'success': true
      };
    } catch (e, st) {
      final errMsg = extractErrorMessage(e);
      final fullMsg =
          'Sale deletion failed on web: $errMsg - Please check Firebase security rules and try again';
      debugPrint('[ReportsProvider._deleteSaleWeb] Error: $fullMsg');
      debugPrint('[ReportsProvider._deleteSaleWeb] Stack: $st');

      return {'success': false, 'error': fullMsg, 'stack': st.toString()};
    }
  }

  /// Native/mobile transaction-based deletion (Android, iOS)
  Future<Map<String, dynamic>?> deleteSale(String saleId,
      {String? businessId}) async {
    final bid = businessId ??
        _currentSubscribedBusinessId ??
        _authProvider?.currentUser?.currentBusinessId ??
        _authProvider?.currentUser?.preferredBusinessId ??
        _authProvider?.currentUser?.businessId;
    if (bid == null || bid.isEmpty) throw Exception('No business ID found');

    // Web platform has stricter transaction handling; use fallback for web
    if (kIsWeb) {
      return _deleteSaleWeb(saleId, bid);
    }

    try {
      // Perform atomic restock + delete in a transaction to avoid races and partial updates
      final result = await _firestore.runTransaction((tx) async {
        final saleRef = _firestore
            .collection('businesses')
            .doc(bid)
            .collection('sales')
            .doc(saleId);
        final saleSnap = await tx.get(saleRef);

        List<dynamic> items = [];
        Map<String, dynamic> data = {};

        if (saleSnap.exists) {
          data = saleSnap.data() as Map<String, dynamic>;
          items = (data['items'] as List<dynamic>?) ?? [];
        } else {
          // Try to fall back to root 'sales' document if business-level sale is missing
          final rootRefFallback = _firestore.collection('sales').doc(saleId);
          final rootSnapFallback = await tx.get(rootRefFallback);
          if (!rootSnapFallback.exists) {
            // nothing to do
            return {'auditId': null, 'items': [], 'businessId': null};
          }
          data = rootSnapFallback.data() as Map<String, dynamic>;
          items = (data['items'] as List<dynamic>?) ?? [];
        }

        final actualBid = (data['businessId'] ?? bid)?.toString() ?? '';
        if (actualBid.isNotEmpty) {
          final List<Map<String, dynamic>> _deleteErrors = [];
          for (final raw in items) {
            if (raw is! Map<String, dynamic>) continue;
            final pid =
                (raw['productId'] ?? raw['id'] ?? raw['product_id'] ?? '')
                    .toString();
            final qtyNum =
                (raw['quantity'] ?? raw['qty'] ?? raw['quantitySold'] ?? 0);
            double qty;
            try {
              if (qtyNum is num)
                qty = qtyNum.toDouble();
              else {
                final cleaned =
                    qtyNum?.toString().replaceAll(RegExp(r'[^0-9.\-]'), '');
                qty = double.tryParse(cleaned!) ?? 0.0;
              }
            } catch (_) {
              qty = 0.0;
            }

            if (pid.isEmpty || qty <= 0) continue;

            try {
              final invRef = _firestore
                  .collection('businesses')
                  .doc(actualBid)
                  .collection('inventory')
                  .doc(pid);
              final invSnap = await tx.get(invRef);

              if (invSnap.exists) {
                tx.update(invRef, {
                  'quantity': FieldValue.increment(qty),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              } else {
                tx.set(invRef, {
                  'quantity': qty,
                  'name': (raw['name'] ?? raw['productName'] ?? '').toString(),
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              }
            } catch (e) {
              _deleteErrors.add({'productId': pid, 'error': e.toString()});
            }
          }

          // log the deletion for audit (include any per-item errors)
          final auditRef = _firestore
              .collection('businesses')
              .doc(actualBid)
              .collection('sale_deletions')
              .doc();
          tx.set(auditRef, {
            'saleId': saleId,
            'deletedBy': _authProvider?.currentUser?.id ?? 'system',
            'items': items,
            'errors': _deleteErrors,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // delete the sale doc from the business collection if it existed
          if (saleSnap.exists) tx.delete(saleRef);

          final saleType = (data['saleType'] ?? '').toString().trim().toLowerCase();
          final distributorId = (data['distributorId'] ?? '').toString().trim();
          if (saleType == 'distributor' && distributorId.isNotEmpty) {
            final distributorSaleRef = _firestore.collection('businesses').doc(actualBid).collection('distributor_sales').doc(saleId);
            final distributorSaleSnap = await tx.get(distributorSaleRef);
            if (distributorSaleSnap.exists) tx.delete(distributorSaleRef);

            final distributorDocSaleRef = _firestore
                .collection('businesses')
                .doc(actualBid)
                .collection('distributors')
                .doc(distributorId)
                .collection('sales')
                .doc(saleId);
            final distributorDocSaleSnap = await tx.get(distributorDocSaleRef);
            if (distributorDocSaleSnap.exists) tx.delete(distributorDocSaleRef);
          }

          // delete mirror in root 'sales' collection if it exists
          final rootRef = _firestore.collection('sales').doc(saleId);
          final rootSnap = await tx.get(rootRef);
          if (rootSnap.exists) tx.delete(rootRef);

          final resMap = {
            'auditId': auditRef.id,
            'items': items,
            'businessId': actualBid,
            'success': true
          };
          return resMap;
        }

        // If we cannot determine a business id, still attempt to delete docs
        if (saleSnap.exists) tx.delete(saleRef);
        final rootRef = _firestore.collection('sales').doc(saleId);
        final rootSnap = await tx.get(rootRef);
        if (rootSnap.exists) tx.delete(rootRef);

        return {
          'auditId': null,
          'items': [],
          'businessId': null,
          'success': true
        };
      });

      // refresh subscription if active
      try {
        if (_salesSubscription != null) {
          subscribeToSalesReports(businessId: bid);
        }
      } catch (_) {}

      return result;
    } catch (e, st) {
      final errMsg = extractErrorMessage(e);

      // Add context-specific hints
      String fullMsg = errMsg;
      if (errMsg.toLowerCase().contains('permission')) {
        fullMsg +=
            ' - Check Firestore security rules for sale_deletions and inventory write permissions';
      } else if (errMsg.toLowerCase().contains('transaction')) {
        fullMsg +=
            ' - Ensure Firestore indexes exist for timestamp-based queries';
      } else if (errMsg.toLowerCase().contains('failed') || errMsg.isEmpty) {
        fullMsg =
            'Sale deletion transaction failed. This may be due to: 1) Missing Firestore indexes, 2) Security rule restrictions, or 3) Network connectivity. Check Firebase console.';
      }

      // Always log the raw error for debugging
      debugPrint(
          '[ReportsProvider.deleteSale] Raw error type: ${e.runtimeType}');
      debugPrint('[ReportsProvider.deleteSale] Raw error: $e');
      debugPrint('[ReportsProvider.deleteSale] transaction failed: $fullMsg');
      debugPrint('[ReportsProvider.deleteSale] stack trace: $st');

      // Return structured error instead of throwing to make UI handling clearer
      return {'success': false, 'error': fullMsg, 'stack': st.toString()};
    }
  }

  /// Subscribe to sales report realtime updates
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

    final endDatePlusOne = _salesEndDate.add(const Duration(days: 1));
    _triedTimestampSalesQuery = false;
    final createdAtQuery = _firestore
        .collection('businesses')
        .doc(bid)
        .collection('sales')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_salesStartDate))
        .where('createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endDatePlusOne));
    final createdAtOrderedQuery =
        createdAtQuery.orderBy('createdAt', descending: true);
    _salesSubscription = createdAtOrderedQuery.snapshots().listen((snapshot) {
      _salesReports = snapshot.docs.map((doc) {
        final data = doc.data();
        final date = _parseDate(data['createdAt'] ?? data['timestamp']);

        // Extract items/products and payment information
        final products = _normalizeSaleProducts(data['items']);

        return SaleReport(
          date: date,
          category: data['category'] ?? data['type'] ?? 'N/A',
          itemsCount: products.length,
          totalAmount: (data['totalAmount'] ?? data['total'] ?? 0).toDouble(),
          cashier: _extractStringValue(data['cashier']) ??
              _extractStringValue(data['workerName']) ??
              _extractStringValue(data['soldBy']) ??
              'N/A',
          paymentMethod: _extractStringValue(data['paymentMethod']) ??
              _extractStringValue(data['payment']) ??
              _extractStringValue(data['tenderType']) ??
              'N/A',
          productNames: products
              .map((p) => _extractStringValue(p['name']) ?? 'Unknown')
              .toList(),
          products: products,
          receiptId: doc.id,
          customerId: _extractStringValue(data['customerId']) ??
              _extractStringValue(data['customer']) ??
              '',
          customerName: _extractStringValue(data['customerName']) ??
              _extractStringValue(data['customerDisplayName']) ??
              '',
        );
      }).toList();
      _isLoading = false;
      _error = null;
      debugPrint(
          '[subscribeToSalesReports] Sales count: ${_salesReports.length}');
      notifyListeners();
      if (snapshot.docs.isEmpty && !_triedTimestampSalesQuery) {
        _triedTimestampSalesQuery = true;
        debugPrint(
            '[subscribeToSalesReports] No docs found on createdAt; falling back to timestamp field');
        _salesSubscription?.cancel();
        final tsQuery = _firestore
            .collection('businesses')
            .doc(bid)
            .collection('sales')
            .where('timestamp',
                isGreaterThanOrEqualTo: _salesStartDate.millisecondsSinceEpoch)
            .where('timestamp',
                isLessThanOrEqualTo: endDatePlusOne.millisecondsSinceEpoch);
        _salesSubscription = tsQuery
            .orderBy('timestamp', descending: true)
            .snapshots()
            .listen((tsSnapshot) {
          _salesReports = tsSnapshot.docs.map((doc) {
            final data = doc.data();
            final date = _parseDate(data['createdAt'] ?? data['timestamp']);

            final products = _normalizeSaleProducts(data['items']);

            return SaleReport(
              date: date,
              category: data['category'] ?? data['type'] ?? 'N/A',
              itemsCount: products.length,
              totalAmount:
                  (data['totalAmount'] ?? data['total'] ?? 0).toDouble(),
              cashier: data['cashier'] ??
                  data['workerName'] ??
                  data['soldBy'] ??
                  'N/A',
              paymentMethod: data['paymentMethod'] ??
                  data['payment'] ??
                  data['tenderType'] ??
                  'N/A',
              productNames: products.map((p) => p['name'].toString()).toList(),
              products: products,
              receiptId: doc.id,
              customerId: data['customerId'] ?? data['customer'] ?? '',
              customerName:
                  data['customerName'] ?? data['customerDisplayName'] ?? '',
            );
          }).toList();
          _isLoading = false;
          _error = null;
          debugPrint(
              '[subscribeToSalesReports] Timestamp fallback sales count: ${_salesReports.length}');
          notifyListeners();
        }, onError: (e) {
          _error = 'Failed to subscribe to sales (timestamp fallback): $e';
          _isLoading = false;
          notifyListeners();
        });
        return;
      }
    }, onError: (e) {
      _error = 'Failed to subscribe to sales: $e';
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Subscribe to financial report realtime updates
  void subscribeToFinancialReports({String? businessId}) {
    // Cancel any existing subscriptions
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

    final salesEnd = _financialEndDate.add(const Duration(days: 1));
    _triedTimestampSalesQuery = false;
    final salesQuery = _firestore
        .collection('businesses')
        .doc(bid)
        .collection('sales')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_financialStartDate))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(salesEnd));
    final salesOrderedQuery = salesQuery.orderBy('createdAt', descending: true);

    // Subscribe to both sales and expenses to recompute financial figures in realtime
    _financialSalesSubscription =
        salesOrderedQuery.snapshots().listen((salesSnapshot) {
      _latestSalesDocs = salesSnapshot.docs;
      _recomputeFinancialReports(bid);
      if (salesSnapshot.docs.isEmpty && !_triedTimestampSalesQuery) {
        _triedTimestampSalesQuery = true;
        debugPrint(
            '[subscribeToFinancialReports] No sales docs on createdAt range; trying timestamp range as fallback');
        _financialSalesSubscription?.cancel();
        final tsQuery = _firestore
            .collection('businesses')
            .doc(bid)
            .collection('sales')
            .where('timestamp',
                isGreaterThanOrEqualTo:
                    _financialStartDate.millisecondsSinceEpoch)
            .where('timestamp',
                isLessThanOrEqualTo: salesEnd.millisecondsSinceEpoch);
        _financialSalesSubscription = tsQuery
            .orderBy('timestamp', descending: true)
            .snapshots()
            .listen((tsSnapshot) {
          _latestSalesDocs = tsSnapshot.docs;
          _recomputeFinancialReports(bid);
        }, onError: (e) {
          _error =
              'Failed to subscribe to financials (sales timestamp fallback): $e';
          _isLoading = false;
          notifyListeners();
        });
      }
    }, onError: (e) {
      _error = 'Failed to subscribe to financials (sales): $e';
      _isLoading = false;
      notifyListeners();
    });

    final expensesQuery =
        _firestore.collection('businesses').doc(bid).collection('expenses');
    _expensesSubscription =
        expensesQuery.snapshots().listen((expensesSnapshot) {
      _latestExpensesDocs = expensesSnapshot.docs;
      _recomputeFinancialReports(bid);
    }, onError: (e) {
      _error = 'Failed to subscribe to financials (expenses): $e';
      _isLoading = false;
      notifyListeners();
    });
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
      for (var doc in _latestSalesDocs) {
        final data = doc.data();
        final date = _parseDate(data['createdAt'] ?? data['timestamp']);
        if (date.isAfter(
                _financialStartDate.subtract(const Duration(days: 1))) &&
            date.isBefore(_financialEndDate.add(const Duration(days: 1)))) {
          final month = date.month;
          final revenue =
              ((data['totalAmount'] ?? data['total'] ?? 0) as num).toDouble();
          final items = data['items'] as List? ?? [];
          double cogsForSale = 0.0;
          for (var item in items) {
            if (item is Map<String, dynamic>) {
              final itemCost = _resolveItemCost(item, inventoryCostMap);
              final itemQty =
                  ((item['inventoryQuantity'] ??
                              item['quantity'] ??
                              item['qty'] ??
                              1) as num)
                          .toDouble();
              cogsForSale += (itemCost * itemQty).toDouble();
            }
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

      // add other expenses from latest expenses snapshot
      for (var doc in _latestExpensesDocs) {
        final data = doc.data();
        final date = _parseDate(data['date']);
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
    Query query =
        _firestore.collection('businesses').doc(bid).collection('inventory');
    if (storeId != null && storeId.isNotEmpty)
      query = query.where('storeId', isEqualTo: storeId);

    _inventorySubscription = query.snapshots().listen((snapshot) async {
      _inventoryCostCacheBusinessId = bid;
      _inventoryCostCache
        ..clear()
        ..addEntries(snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final cost =
              ((data['averageCost'] ?? data['cost'] ?? data['lastProcurementCost'])
                      as num?)
                  ?.toDouble() ??
                  0.0;
          return MapEntry(doc.id, cost);
        }));
      _inventoryReports = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final cost = _inventoryCostCache[doc.id] ?? ((data['averageCost'] ?? data['cost'] ?? data['lastProcurementCost']) as num?)?.toDouble() ?? 0.0;
        return InventoryReport(
          productId: doc.id,
          productName: data['name'] ?? 'Unknown',
          quantity: (data['quantity'] as num?)?.toInt() ?? 0,
          reorderLevel: (data['reorderLevel'] as num?)?.toInt() ?? 10,
          unitPrice: (data['price'] as num?)?.toDouble() ?? 0.0,
          costPrice: cost,
          unit: (data['unit'] ?? 'pc').toString(),
          businessSection: (data['businessSection'] ?? data['section'] ?? '').toString(),
          category: (data['category'] ?? data['type'] ?? '').toString(),
          lastProcurementAt: _parseDate(data['lastProcurementAt'] ?? data['lastProcuredAt'] ?? data['lastProcured']),
        );
      }).toList();

      // Fallback: inventory might be stored in 'documents' if primary collection is empty
      if (_inventoryReports.isEmpty) {
        try {
          final documentsSnapshot = await _firestore
              .collection('businesses')
              .doc(bid)
              .collection('documents')
              .get();
          final docItems = <InventoryReport>[];
          for (var d in documentsSnapshot.docs) {
            final ddata = d.data();
            Iterable<dynamic>? items;
            if (ddata.containsKey('items') && ddata['items'] is List) {
              items = ddata['items'] as List;
            } else if (ddata.containsKey('inventory') &&
                ddata['inventory'] is List)
              items = ddata['inventory'] as List;
            else if ((ddata['name'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains('inventory') &&
                ddata.containsKey('data') &&
                ddata['data'] is List) items = ddata['data'] as List;

            if (items != null) {
              var ii = 0;
              for (final raw in items) {
                if (raw is Map<String, dynamic>) {
                  final rawCost = ((raw['averageCost'] ?? raw['cost'] ?? raw['costPrice'] ?? raw['purchasePrice']) as num?)?.toDouble() ?? 0.0;
                  docItems.add(InventoryReport(
                    productId: '${d.id}_$ii',
                    productName:
                        (raw['name'] ?? raw['item'] ?? 'Unknown').toString(),
                    quantity: (raw['quantity'] as num?)?.toInt() ??
                        (raw['qty'] as num?)?.toInt() ??
                        0,
                    reorderLevel: (raw['reorderLevel'] as num?)?.toInt() ?? 10,
                    unitPrice: (raw['price'] as num?)?.toDouble() ?? 0.0,
                    costPrice: rawCost,
                    unit: (raw['unit'] ?? 'pc').toString(),
                  ));
                }
                ii++;
              }
            }
          }
          if (docItems.isNotEmpty) {
            _inventoryReports = docItems;
            debugPrint(
                '[subscribeToInventoryReports] Document-based inventory found: ${docItems.length} items for business $bid');
          }
        } catch (e) {
          debugPrint(
              '[subscribeToInventoryReports] Document-based inventory fallback failed: $e');
        }
      }

      _isLoading = false;
      _error = null;
      debugPrint(
          '[subscribeToInventoryReports] Inventory count: ${_inventoryReports.length}');
      notifyListeners();
    }, onError: (e) {
      _error = 'Failed to subscribe to inventory: $e';
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Cancel all subscriptions
  void unsubscribeFromReportSubscriptions() {
    debugPrint('[unsubscribeFromReportSubscriptions] Cancelling subscriptions');
    if (_salesSubscription != null)
      debugPrint(
          '[unsubscribeFromReportSubscriptions] _salesSubscription active, canceling');
    if (_financialSalesSubscription != null)
      debugPrint(
          '[unsubscribeFromReportSubscriptions] _financialSalesSubscription active, canceling');
    if (_expensesSubscription != null)
      debugPrint(
          '[unsubscribeFromReportSubscriptions] _expensesSubscription active, canceling');
    if (_inventorySubscription != null)
      debugPrint(
          '[unsubscribeFromReportSubscriptions] _inventorySubscription active, canceling');
    if (_customersSubscription != null)
      debugPrint(
          '[unsubscribeFromReportSubscriptions] _customersSubscription active, canceling');
    _salesSubscription?.cancel();
    _financialSalesSubscription?.cancel();
    _expensesSubscription?.cancel();
    _inventorySubscription?.cancel();
    _customersSubscription?.cancel();
    _salesSubscription = null;
    _financialSalesSubscription = null;
    _expensesSubscription = null;
    _inventorySubscription = null;
    _customersSubscription = null;
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

  /// Add a new expense record
  Future<void> addExpense({
    required String description,
    required double amount,
    required String category,
    String? receiptUrl,
  }) async {
    try {
      final newExpense = {
        'id': 'exp_${DateTime.now().millisecondsSinceEpoch}',
        'description': description,
        'amount': amount,
        'category': category,
        'receiptUrl': receiptUrl,
        // Store date as Firestore `Timestamp` locally for consistency with server
        'date': Timestamp.fromDate(DateTime.now()),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      _expenses.add(newExpense);

      // Save to Firebase if user is authenticated and businessId is available
      final bid = _currentSubscribedBusinessId ??
          _authProvider?.currentUser?.currentBusinessId ??
          _authProvider?.currentUser?.preferredBusinessId ??
          _authProvider?.currentUser?.businessId;
      if (bid != null && bid.isNotEmpty && newExpense['id'] != null) {
        final docRef = _firestore
            .collection('businesses')
            .doc(bid)
            .collection('expenses')
            .doc(newExpense['id'] as String);
        final payload = {
          'id': newExpense['id'],
          'description': description,
          'amount': amount,
          'category': category,
          'date': Timestamp.fromDate(DateTime.now()),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        if (receiptUrl != null && receiptUrl.isNotEmpty)
          payload['receiptUrl'] = receiptUrl;

        await docRef.set(payload);
      } else {
        debugPrint(
            '[ReportsProvider.addExpense] No business ID available - expense stored locally only');
      }

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

      // Remove from Firebase if user is authenticated and businessId available
      final bid = _currentSubscribedBusinessId ??
          _authProvider?.currentUser?.currentBusinessId ??
          _authProvider?.currentUser?.preferredBusinessId ??
          _authProvider?.currentUser?.businessId;
      if (bid != null && bid.isNotEmpty) {
        await _firestore
            .collection('businesses')
            .doc(bid)
            .collection('expenses')
            .doc(expenseId)
            .delete();
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

      // Query sales within date range for current business
      final query = _firestore
          .collection('businesses')
          .doc(bid)
          .collection('sales')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(_salesStartDate))
          .where('createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(
                  _salesEndDate.add(const Duration(days: 1))))
          .orderBy('createdAt', descending: true);

      final snapshot = await query.get();

      // Fallback: if no docs found using `createdAt`, attempt numeric `timestamp` range
      if (snapshot.docs.isEmpty) {
        try {
          debugPrint(
              '[generateSalesReport] No sales found with createdAt; trying timestamp field fallback');
          final tsQuery = _firestore
              .collection('businesses')
              .doc(bid)
              .collection('sales')
              .where('timestamp',
                  isGreaterThanOrEqualTo:
                      _salesStartDate.millisecondsSinceEpoch)
              .where('timestamp',
                  isLessThanOrEqualTo: _salesEndDate
                      .add(const Duration(days: 1))
                      .millisecondsSinceEpoch)
              .orderBy('timestamp', descending: true);
          final tsSnapshot = await tsQuery.get();
          if (tsSnapshot.docs.isNotEmpty) {
            debugPrint(
                '[generateSalesReport] Found ${tsSnapshot.docs.length} sales using timestamp fallback');
            // Populate using timestamp results
            _salesReports = tsSnapshot.docs.map((doc) {
              final data = doc.data();
              final products = _normalizeSaleProducts(data['items']);
              return SaleReport(
                date: _parseDate(data['createdAt'] ?? data['timestamp']),
                totalAmount:
                    ((data['total'] ?? data['totalAmount'] ?? 0) as num)
                        .toDouble(),
                itemsCount: products.length,
                category: data['category'] ?? 'General',
                productNames: products.map((p) => p['name'].toString()).toList(),
                products: products,
                receiptId: doc.id,
                paymentMethod: data['paymentMethod'] ?? 'Cash',
                cashier: data['cashier'] ??
                    data['workerName'] ??
                    data['soldBy'] ??
                    'N/A',
              );
            }).toList();
          }
        } catch (e) {
          debugPrint('[generateSalesReport] Timestamp fallback failed: $e');
        }
      }

      _salesReports = snapshot.docs.map((doc) {
        final data = doc.data();

        final products = _normalizeSaleProducts(data['items']);

        return SaleReport(
          date: _parseDate(data['createdAt'] ?? data['timestamp']),
          totalAmount:
              ((data['total'] ?? data['totalAmount'] ?? 0) as num).toDouble(),
          itemsCount: products.length,
          category: data['category'] ?? 'General',
          productNames: products.map((p) => p['name'].toString()).toList(),
          products: products,
          receiptId: doc.id,
          paymentMethod: data['paymentMethod'] ?? 'Cash',
          cashier:
              data['cashier'] ?? data['workerName'] ?? data['soldBy'] ?? 'N/A',
        );
      }).toList();

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

      // Query sales for revenue - add 1 day to end date to include all of that day
      final endDatePlusOne = _financialEndDate.add(const Duration(days: 1));
      final salesQuery = _firestore
          .collection('businesses')
          .doc(bid)
          .collection('sales')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(_financialStartDate))
          .where('createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(endDatePlusOne));

      final salesSnapshot =
          await salesQuery.orderBy('createdAt', descending: true).get();

      // We'll unify docs into saleDocs for processing (supporting fallback)
      List salesDocs = salesSnapshot.docs;

      // Fallback to numeric timestamp if createdAt-based query returned nothing
      if (salesDocs.isEmpty) {
        try {
          debugPrint(
              '[generateFinancialReport] No sales found with createdAt; trying timestamp fallback');
          final tsQuery = _firestore
              .collection('businesses')
              .doc(bid)
              .collection('sales')
              .where('timestamp',
                  isGreaterThanOrEqualTo:
                      _financialStartDate.millisecondsSinceEpoch)
              .where('timestamp',
                  isLessThanOrEqualTo: endDatePlusOne.millisecondsSinceEpoch)
              .orderBy('timestamp', descending: true);
          final tsSnapshot = await tsQuery.get();
          if (tsSnapshot.docs.isNotEmpty) {
            debugPrint(
                '[generateFinancialReport] Found ${tsSnapshot.docs.length} sales using timestamp fallback');
            // Use tsSnapshot instead of salesSnapshot
            // Assign fallback docs to saleDocs so the rest of the function uses them
            salesDocs = tsSnapshot.docs;
            // We'll process fallbackDocs similarly as salesSnapshot later in the method
            // Replace the salesSnapshot variable by creating placeholder
            // Convert fallbackDocs to a Firestore QuerySnapshot-like list by reusing its docs
            // We'll copy the processing below to handle fallbackDocs in the next sections
            // For simplicity, we'll proceed with fallbackDocs in place of salesSnapshot in subsequent steps.
          }
        } catch (e) {
          debugPrint('[generateFinancialReport] Timestamp fallback failed: $e');
        }
      }

      // Mark computing state while we calculate COGS and expenses
      _isComputingFinancials = true;
      notifyListeners();
      final inventoryCostMap = await _getInventoryCostMap(bid);

      // Group sales by month and calculate totals
      // monthlyData maps month -> (revenue, cogs, otherExpenses)
      final monthlyData = <int, (double, double, double)>{};
      double totalCostOfGoods = 0.0;

      debugPrint('[FinancialReport] Found ${salesDocs.length} sales records');

      for (var doc in salesDocs) {
        final data = doc.data();
        final date = _parseDate(data['createdAt'] ?? data['timestamp']);
        final month = date.month;
        final grossRevenue =
            ((data['totalAmount'] ?? data['total'] ?? 0) as num).toDouble();

        // If part or all of this sale was returned/refunded, subtract the
        // refunded amount from revenue so profit isn't overstated.
        final returnAmount = ((data['returnAmount'] ?? 0) as num).toDouble();
        final excludeReturn = data['excludeReturnFromTotals'] == true;
        final effectiveReturnAmount = excludeReturn ? 0.0 : returnAmount;
        final revenue = (grossRevenue - effectiveReturnAmount).clamp(0, double.infinity).toDouble();

        // Calculate cost of goods sold from items if available
        final items = data['items'] as List? ?? [];
        double saleCogs = 0.0;
        for (var item in items) {
          if (item is Map<String, dynamic>) {
            final itemCost = _resolveItemCost(item, inventoryCostMap);
            final itemQty =
                ((item['inventoryQuantity'] ??
                            item['quantity'] ??
                            item['qty'] ??
                            1) as num)
                        .toDouble();
            final itemCogs = (itemCost * itemQty).toDouble();
            saleCogs += itemCogs;
          }
        }

        // Without item-level return details, approximate the COGS for the
        // returned portion proportionally to the sale's overall cost ratio,
        // so a partial refund doesn't leave COGS for goods that came back.
        if (effectiveReturnAmount > 0 && grossRevenue > 0) {
          final returnedFraction = (effectiveReturnAmount / grossRevenue).clamp(0.0, 1.0);
          saleCogs = saleCogs * (1 - returnedFraction);
        }
        totalCostOfGoods += saleCogs;

        debugPrint(
            '[FinancialReport] Sale - Date: $date, Month: $month, Revenue: ₦$revenue, COGS: ₦$saleCogs');

        if (monthlyData.containsKey(month)) {
          final (existingRevenue, existingCogs, existingOther) =
              monthlyData[month]!;
          monthlyData[month] = (
            existingRevenue + revenue,
            existingCogs + saleCogs,
            existingOther
          );
        } else {
          monthlyData[month] = (revenue, saleCogs, 0.0);
        }
      }

      // Query expenses from expenses collection
      double totalOtherExpenses = 0.0;
      try {
        final expensesQuery =
            _firestore.collection('businesses').doc(bid).collection('expenses');

        final expensesSnapshot = await expensesQuery.get();

        for (var doc in expensesSnapshot.docs) {
          final data = doc.data();
          final date = _parseDate(data['date']);

          // Only include expenses within date range (including both start and end dates)
          if (date.isAfter(
                  _financialStartDate.subtract(const Duration(days: 1))) &&
              date.isBefore(endDatePlusOne)) {
            final month = date.month;
            final amount = (data['amount'] ?? 0) as num;
            totalOtherExpenses += amount.toDouble();

            if (monthlyData.containsKey(month)) {
              final (revenue, cogs, existingOther) = monthlyData[month]!;
              monthlyData[month] =
                  (revenue, cogs, existingOther + amount.toDouble());
            } else {
              monthlyData[month] = (0.0, 0.0, amount.toDouble());
            }
          }
        }
      } catch (e) {
        debugPrint(
            '[FinancialReport] Note: Expenses collection may not exist: $e');
      }

      // Include cost of goods in total expenses (for backward-compatible logging)
      final double totalExpenses = totalOtherExpenses + totalCostOfGoods;

      // Convert to FinancialReport list
      _financialReports = monthlyData.entries.map((entry) {
        final (revenue, cogs, otherExpenses) = entry.value;
        final report = FinancialReport(
          month: entry.key,
          revenue: revenue,
          cogs: cogs,
          expenses: otherExpenses,
          salaries:
              otherExpenses * 0.6, // Estimate 60% of other expenses as salaries
          utilities: otherExpenses *
              0.4, // Estimate 40% of other expenses as utilities
        );
        debugPrint(
            '[FinancialReport] Month ${report.month}: Revenue=₦${report.revenue}, COGS=₦${report.cogs}, OtherExpenses=₦${report.expenses}');
        return report;
      }).toList();

      debugPrint(
          '[FinancialReport] Total Revenue: ₦${_financialReports.fold(0.0, (sum, r) => sum + r.revenue)}');
      debugPrint(
          '[FinancialReport] Total Expenses (including COGS): ₦$totalExpenses');
      debugPrint('[FinancialReport] Total Cost of Goods: ₦$totalCostOfGoods');
      debugPrint(
          '[FinancialReport] Net Profit: ₦${_financialReports.fold(0.0, (sum, r) => sum + r.netProfit)}');

      _isComputingFinancials = false;
      _isLoading = false;
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

      // Query inventory for current business (optionally scoped to a store)
      debugPrint(
          '[generateInventoryReport] Invoked with businessId: $businessId; resolved bid: $bid; storeId: $storeId');
      Query query =
          _firestore.collection('businesses').doc(bid).collection('inventory');
      if (storeId != null && storeId.isNotEmpty)
        query = query.where('storeId', isEqualTo: storeId);

      final snapshot = await query.get();

      _inventoryReports = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final cost = _inventoryCostCache[doc.id] ?? ((data['averageCost'] ?? data['cost'] ?? data['lastProcurementCost']) as num?)?.toDouble() ?? 0.0;
        return InventoryReport(
          productId: doc.id,
          productName: data['name'] ?? 'Unknown',
          quantity: (data['quantity'] as num?)?.toInt() ?? 0,
          reorderLevel: (data['reorderLevel'] as num?)?.toInt() ?? 10,
          unitPrice: (data['price'] as num?)?.toDouble() ?? 0.0,
          costPrice: cost,
          unit: (data['unit'] ?? 'pc').toString(),
          businessSection: (data['businessSection'] ?? data['section'] ?? '').toString(),
          category: (data['category'] ?? data['type'] ?? '').toString(),
          lastProcurementAt: _parseDate(data['lastProcurementAt'] ?? data['lastProcuredAt'] ?? data['lastProcured']),
        );
      }).toList();

      // If inventory collection has no items, fallback to documents' embedded inventory lists
      if (_inventoryReports.isEmpty) {
        try {
          final documentsSnapshot = await _firestore
              .collection('businesses')
              .doc(bid)
              .collection('documents')
              .get();
          final docItems = <InventoryReport>[];
          for (var d in documentsSnapshot.docs) {
            final ddata = d.data();
            Iterable<dynamic>? items;
            if (ddata.containsKey('items') && ddata['items'] is List) {
              items = ddata['items'] as List;
            } else if (ddata.containsKey('inventory') &&
                ddata['inventory'] is List)
              items = ddata['inventory'] as List;
            else if ((ddata['name'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains('inventory') &&
                ddata.containsKey('data') &&
                ddata['data'] is List) items = ddata['data'] as List;

            if (items != null) {
              var ii = 0;
              for (final raw in items) {
                if (raw is Map<String, dynamic>) {
                  final rawCost = ((raw['averageCost'] ?? raw['cost'] ?? raw['costPrice'] ?? raw['purchasePrice']) as num?)?.toDouble() ?? 0.0;
                  docItems.add(InventoryReport(
                    productId: '${d.id}_$ii',
                    productName:
                        (raw['name'] ?? raw['item'] ?? 'Unknown').toString(),
                    quantity: (raw['quantity'] as num?)?.toInt() ??
                        (raw['qty'] as num?)?.toInt() ??
                        0,
                    reorderLevel: (raw['reorderLevel'] as num?)?.toInt() ?? 10,
                    unitPrice: (raw['price'] as num?)?.toDouble() ?? 0.0,
                    costPrice: rawCost,
                    unit: (raw['unit'] ?? 'pc').toString(),
                    businessSection: (raw['businessSection'] ?? raw['section'] ?? '').toString(),
                    category: (raw['category'] ?? raw['type'] ?? '').toString(),
                    lastProcurementAt: _parseDate(raw['lastProcurementAt'] ?? raw['lastProcuredAt'] ?? raw['lastProcured']),
                  ));
                }
                ii++;
              }
            }
          }
          if (docItems.isNotEmpty) {
            _inventoryReports = docItems;
            debugPrint(
                '[generateInventoryReport] Document-based inventory found: ${docItems.length} items for business $bid');
          }
        } catch (e) {
          debugPrint(
              '[generateInventoryReport] Document inventory fallback failed: $e');
        }
      }

      _isLoading = false;
    } catch (e) {
      _error = 'Failed to load inventory report: $e';
      _isLoading = false;
    }
    notifyListeners();
  }

  /// Subscribe to expenses collection to keep in-memory _expenses in sync
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

    final collectionRef =
        _firestore.collection('businesses').doc(bid).collection('expenses');
    _expensesSubscription = collectionRef.snapshots().listen((snapshot) {
      _expenses.clear();

      // Normalize and sort docs locally. Some historical docs may use numeric
      // `timestamp`, others may use `date` (a Timestamp). We sort by numeric
      // timestamp when available, else by parsed `date`.
      final docs = snapshot.docs.toList();
      docs.sort((a, b) {
        final aData = a.data();
        final bData = b.data();
        final aTs = aData['timestamp'];
        final bTs = bData['timestamp'];
        if (aTs is num && bTs is num) return bTs.compareTo(aTs);
        final aDate = _parseDate(aData['date']);
        final bDate = _parseDate(bData['date']);
        return bDate.compareTo(aDate);
      });

      for (var doc in docs) {
        final data = doc.data();
        _expenses.add({
          'id': doc.id,
          ...data,
        });
      }

      _isLoading = false;
      _error = null;
      debugPrint(
          '[subscribeToExpensesReports] Expenses count: ${_expenses.length}');
      notifyListeners();
    }, onError: (e) {
      _error = 'Failed to subscribe to expenses: $e';
      _isLoading = false;
      notifyListeners();
    });
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

      final collectionRef =
          _firestore.collection('businesses').doc(bid).collection('expenses');
      final snapshot = await collectionRef.get();

      final docs = snapshot.docs.toList();
      docs.sort((a, b) {
        final aData = a.data();
        final bData = b.data();
        final aTs = aData['timestamp'];
        final bTs = bData['timestamp'];
        if (aTs is num && bTs is num) return bTs.compareTo(aTs);
        final aDate = _parseDate(aData['date']);
        final bDate = _parseDate(bData['date']);
        return bDate.compareTo(aDate);
      });

      _expenses
        ..clear()
        ..addAll(docs.map((doc) => {'id': doc.id, ...doc.data()}));

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

      // Query customers for current business
      final query =
          _firestore.collection('businesses').doc(bid).collection('customers');

      final snapshot = await query.get();

      // For each customer, calculate total spent and orders
      _customerReports = [];
      for (var customerDoc in snapshot.docs) {
        final customerData = customerDoc.data();

        // Query sales for this customer
        final salesQuery = _firestore
            .collection('businesses')
            .doc(bid)
            .collection('sales')
            .where('customerId', isEqualTo: customerDoc.id);

        final salesSnapshot = await salesQuery.get();

        double totalSpent = 0;
        for (var saleDoc in salesSnapshot.docs) {
          totalSpent += ((saleDoc.data()['totalAmount'] ?? 0)).toDouble();
        }

        _customerReports.add(CustomerReport(
          customerId: customerDoc.id,
          customerName:
              customerData['name'] ?? customerData['displayName'] ?? 'Unknown',
          totalSpent: totalSpent,
          totalOrders: salesSnapshot.docs.length,
          isActive: salesSnapshot.docs.isNotEmpty,
        ));
      }

      _isLoading = false;
    } catch (e) {
      _error = 'Failed to load customer report: $e';
      _isLoading = false;
    }
    notifyListeners();
  }

  /// Get list of raw sales documents for a given customer id
  Future<List<Map<String, dynamic>>> getCustomerTransactions(String customerId,
      {String? businessId}) async {
    try {
      final bid = businessId ??
          _currentSubscribedBusinessId ??
          _authProvider?.currentUser?.businessId;
      if (bid == null || bid.isEmpty || customerId.isEmpty) return [];

      final salesRef = _firestore
          .collection('businesses')
          .doc(bid)
          .collection('sales');

      // Some sales records store the customer link as customerId, some use a nested
      // customer object with an id field, and some may store the customer value
      // directly on the customer field. Query all common variants and merge.
      final queries = <Future<QuerySnapshot>>[
        salesRef.where('customerId', isEqualTo: customerId).get(),
        salesRef.where('customer.id', isEqualTo: customerId).get(),
        salesRef.where('customer', isEqualTo: customerId).get(),
      ];

      final snapshots = await Future.wait(queries);
      final Map<String, Map<String, dynamic>> salesById = {};

      for (final snap in snapshots) {
        for (final doc in snap.docs) {
          final saleData = doc.data() as Map<String, dynamic>?;
          salesById[doc.id] = {...?saleData, 'id': doc.id};
        }
      }

      final sales = salesById.values.toList();
      sales.sort((a, b) {
        final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
            (a['createdAt'] is Timestamp ? (a['createdAt'] as Timestamp).toDate() : DateTime.fromMillisecondsSinceEpoch(0));
        final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
            (b['createdAt'] is Timestamp ? (b['createdAt'] as Timestamp).toDate() : DateTime.fromMillisecondsSinceEpoch(0));
        return bDate.compareTo(aDate);
      });

      return sales;
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

    for (final doc in _latestSalesDocs) {
      final data = doc.data();
      final saleDate = _parseDate(data['createdAt'] ?? data['timestamp']);
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
        'id': doc.id,
        'date': saleDate,
        'receiptNumber': (data['receiptNumber'] ?? '').toString(),
        'customerName': (data['customerName'] ?? 'Walk-in').toString(),
        'paymentMethod': (data['paymentMethod'] ?? 'cash').toString(),
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
    for (final doc in _latestExpensesDocs) {
      final data = doc.data();
      final expenseDate = _parseDate(data['date'] ?? data['createdAt'] ?? data['timestamp']);
      if (expenseDate.isBefore(startDate) || !expenseDate.isBefore(endDate)) {
        continue;
      }

      final amount = _toDouble(data['amount'] ?? data['value'] ?? 0) ?? 0.0;
      operatingExpenses += amount;
      expenses.add({
        'id': doc.id,
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

    return _latestSalesDocs.map((doc) {
      final data = doc.data();
      final items = (data['items'] as List?) ?? [];
      final itemNames = items
          .map((item) {
            if (item is Map<String, dynamic>) {
              return (item['name'] ?? item['productName'] ?? item['title'] ?? '')
                  .toString();
            }
            return item.toString();
          })
          .where((name) => name.trim().isNotEmpty)
          .take(3)
          .join(', ');

      return {
        'date': _parseDate(
          data['saleDate'] ?? data['createdAt'] ?? data['timestamp'],
        ).toIso8601String(),
        'description': itemNames.isNotEmpty
            ? itemNames
            : (data['category'] ?? data['type'] ?? 'Sale').toString(),
        'type': 'Sale',
        'amount': ((data['totalAmount'] ?? data['total'] ?? 0) as num)
            .toDouble(),
        'cashier': (data['cashier'] ??
                data['workerName'] ??
                data['soldBy'] ??
                'N/A')
            .toString(),
        'items': items.length,
        'paymentMethod':
            (data['paymentMethod'] ?? data['payment'] ?? data['tenderType'] ?? 'N/A')
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
