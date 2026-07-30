import 'dart:async';
import 'package:flutter/material.dart';
import '../data/models/analytics_model.dart';
import '../data/repositories/sales_repository_supabase.dart';
import '../data/repositories/inventory_repository_supabase.dart';
import '../data/repositories/customer_repository_supabase.dart';

class AnalyticsProvider extends ChangeNotifier {
  final SalesRepositorySupabase _salesRepo = SalesRepositorySupabase();
  final InventoryRepositorySupabase _inventoryRepo =
      InventoryRepositorySupabase();
  final CustomerRepositorySupabase _customerRepo = CustomerRepositorySupabase();

  String? _businessId;
  AnalyticsModel? _currentAnalytics;
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _revenueTrend = [];
  DateTime? _lastRangeStart;
  DateTime? _lastRangeEnd;
  final Map<String, AnalyticsModel> _analyticsCache = {};
  final Map<String, Map<String, dynamic>> _productCache = {};

  // The custom backend doesn't implement Supabase's Realtime protocol, so
  // these are polled the same way InventoryRepositorySupabase.streamInventory
  // is (see that class for the fuller explanation).
  static const _pollInterval = Duration(seconds: 15);
  Timer? _salesPollTimer;
  Timer? _productsPollTimer;
  bool _isLoading = false;
  String _errorMessage = '';

  // Getters
  AnalyticsModel? get currentAnalytics => _currentAnalytics;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  void setBusinessId(String businessId) {
    if (_businessId != null && _businessId != businessId) {
      _salesPollTimer?.cancel();
      _productsPollTimer?.cancel();
      _salesPollTimer = null;
    }
    _businessId = businessId;
    // fetch products to seed product cache
    if (_businessId != null) {
      fetchProducts();
      subscribeToProductUpdates();
    }
    notifyListeners();
  }

  /// Fetch products (inventory) for the current business to use in analytics
  Future<void> fetchProducts() async {
    if (_businessId == null) return;
    try {
      final items = await _inventoryRepo.getInventory(_businessId!);

      final Map<String, Map<String, dynamic>> cache = {};
      for (final raw in items) {
        final data = raw as Map<String, dynamic>;
        final id = (data['id'] ?? '').toString();
        if (id.isEmpty) continue;
        cache[id] = {
          'id': id,
          'name': data['name'] ?? 'Unknown',
          'price': (data['unit_price'] as num?)?.toDouble() ?? 0.0,
          'cost': (data['cost_price'] as num?)?.toDouble() ?? 0.0,
          'category': data['category'] ?? '',
          'stock': (data['quantity'] as num?)?.toInt() ?? 0,
          'imageUrl': data['image_url'],
        };
      }
      _productCache.clear();
      _productCache.addAll(cache);
      notifyListeners();
    } catch (e) {
      debugPrint('[AnalyticsProvider] Error fetching products: $e');
    }
  }

  void subscribeToProductUpdates() {
    if (_businessId == null) return;
    _productsPollTimer?.cancel();

    Future<void> poll() async {
      await fetchProducts();
      // Refresh analytics-derived lists if we have a known range
      if (_lastRangeStart != null && _lastRangeEnd != null) {
        _topProducts = await getTopProducts(_lastRangeStart!, _lastRangeEnd!);
        _revenueTrend = await getRevenueTrend(_lastRangeStart!, _lastRangeEnd!);
        notifyListeners();
      }
    }

    _productsPollTimer = Timer.periodic(_pollInterval, (_) => poll());
  }

  void unsubscribeFromProductUpdates() {
    _productsPollTimer?.cancel();
    _productsPollTimer = null;
  }

  String? _itemProductId(Map<String, dynamic> item) =>
      (item['productId'] ?? item['product_id'])?.toString();

  double _saleAmount(Map<String, dynamic> data) =>
      (data['totalAmount'] as num?)?.toDouble() ??
      (data['final_amount'] as num?)?.toDouble() ??
      (data['total_amount'] as num?)?.toDouble() ??
      (data['total'] as num?)?.toDouble() ??
      0.0;

  /// Calculate analytics for date range
  Future<AnalyticsModel?> calculateAnalytics(
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (_businessId == null) return null;

    _isLoading = true;
    notifyListeners();

    try {
      // store range for subsequent refreshes
      _lastRangeStart = startDate;
      _lastRangeEnd = endDate;

      final sales = await _salesRepo.fetchSales(
        businessId: _businessId,
        start: startDate,
        end: endDate,
      );

      final model = await _computeAnalyticsFromData(startDate, endDate, sales);
      _currentAnalytics = model;
      _topProducts = await getTopProducts(startDate, endDate);
      _revenueTrend = await getRevenueTrend(startDate, endDate);
      if (model != null) {
        _analyticsCache[_getCacheKey(startDate, endDate)] = model;
      }
      _errorMessage = '';
      debugPrint(
          '[AnalyticsProvider] Analytics calculated: ${model?.totalRevenue} revenue');
    } catch (e) {
      _errorMessage = 'Failed to calculate analytics: $e';
      debugPrint('[AnalyticsProvider] Error: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return _currentAnalytics;
  }

  /// Get trends over multiple periods
  Future<List<AnalyticsModel>> getTrends(
    DateTime startDate,
    DateTime endDate,
    String period, // 'daily', 'weekly', 'monthly'
  ) async {
    List<AnalyticsModel> trends = [];

    try {
      var currentDate = startDate;
      while (currentDate.isBefore(endDate)) {
        final periodEndDate = _getNextPeriodDate(currentDate, period);
        final adjustedEndDate =
            periodEndDate.isAfter(endDate) ? endDate : periodEndDate;

        final analytics =
            await calculateAnalytics(currentDate, adjustedEndDate);
        if (analytics != null) {
          trends.add(analytics);
        }

        currentDate = adjustedEndDate;
      }
    } catch (e) {
      debugPrint('[AnalyticsProvider] Error getting trends: $e');
    }

    return trends;
  }

  Map<String, Map<String, dynamic>> _computeProductStats(
      List<Map<String, dynamic>> sales) {
    Map<String, Map<String, dynamic>> productStats = {};
    for (var data in sales) {
      final items = (data['items'] as List<dynamic>?) ?? [];
      for (var item in items) {
        final itemMap = item as Map<String, dynamic>;
        final productId = _itemProductId(itemMap);
        final productNameFromItem = (itemMap['productName'] as String?) ??
            (itemMap['product_name'] as String?) ??
            (itemMap['name'] as String?);
        final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 0;
        double unitPrice = 0.0;
        if (productId != null && _productCache.containsKey(productId)) {
          unitPrice = (_productCache[productId]!['price'] as double?) ?? 0.0;
        }
        unitPrice = unitPrice == 0.0
            ? (itemMap['unitPrice'] as num?)?.toDouble() ??
                (itemMap['unit_price'] as num?)?.toDouble() ??
                (itemMap['price'] as num?)?.toDouble() ??
                0.0
            : unitPrice;
        final key = productId ??
            productNameFromItem ??
            'unknown_${productStats.length}';
        final name = productId != null && _productCache.containsKey(productId)
            ? _productCache[productId]!['name']
            : (productNameFromItem ?? 'Unknown');

        double costPerUnit = 0.0;
        if (productId != null && _productCache.containsKey(productId)) {
          costPerUnit = (_productCache[productId]!['cost'] as double?) ?? 0.0;
        }

        if (!productStats.containsKey(key)) {
          productStats[key] = {
            'id': productId,
            'name': name,
            'quantity': 0,
            'revenue': 0.0,
            'unitPrice': unitPrice,
            'costPerUnit': costPerUnit,
          };
        }

        productStats[key]!['quantity'] += quantity;
        productStats[key]!['revenue'] += quantity * unitPrice;
        productStats[key]!['unitPrice'] = unitPrice;
        productStats[key]!['costPerUnit'] = costPerUnit;
      }
    }
    return productStats;
  }

  /// Get top products by sales
  Future<List<Map<String, dynamic>>> getTopProducts(
    DateTime startDate,
    DateTime endDate, {
    int limit = 5,
  }) async {
    if (_businessId == null) return [];

    try {
      final sales = await _salesRepo.fetchSales(
        businessId: _businessId,
        start: startDate,
        end: endDate,
      );

      final productStats = _computeProductStats(sales);

      final sorted = productStats.values.toList()
        ..sort((a, b) =>
            (b['revenue'] as double).compareTo(a['revenue'] as double));

      return sorted.take(limit).toList();
    } catch (e) {
      debugPrint('[AnalyticsProvider] Error getting top products: $e');
      return [];
    }
  }

  /// Get revenue trend data for charts
  Future<List<Map<String, dynamic>>> getRevenueTrend(
    DateTime startDate,
    DateTime endDate, {
    String period = 'daily', // 'daily', 'weekly', 'monthly'
  }) async {
    if (_businessId == null) return [];

    try {
      final trendEntries = <Map<String, dynamic>>[];
      var currentDate = startDate;

      while (currentDate.isBefore(endDate)) {
        final periodEndDate = _getNextPeriodDate(currentDate, period);
        final adjustedEndDate =
            periodEndDate.isAfter(endDate) ? endDate : periodEndDate;

        final sales = await _salesRepo.fetchSales(
          businessId: _businessId,
          start: currentDate,
          end: adjustedEndDate,
        );

        double periodRevenue = 0;
        for (var sale in sales) {
          periodRevenue += _saleAmount(sale);
        }

        final key = _formatPeriodKey(currentDate, period);
        trendEntries.add({
          'period': key,
          'revenue': periodRevenue,
          'date': currentDate,
        });

        currentDate = adjustedEndDate;
      }

      return trendEntries;
    } catch (e) {
      debugPrint('[AnalyticsProvider] Error getting revenue trend: $e');
      return [];
    }
  }

  // Poll for changes to sales in the given range, recomputing analytics on
  // each tick.
  void subscribeToSalesUpdates(DateTime startDate, DateTime endDate) {
    if (_businessId == null) return;
    _salesPollTimer?.cancel();

    Future<void> poll() async {
      try {
        final sales = await _salesRepo.fetchSales(
          businessId: _businessId,
          start: startDate,
          end: endDate,
        );
        final model =
            await _computeAnalyticsFromData(startDate, endDate, sales);
        _currentAnalytics = model;
        _topProducts = await getTopProducts(startDate, endDate);
        _revenueTrend = await getRevenueTrend(startDate, endDate,
            period: _getPeriodLabel(endDate.difference(startDate).inDays));
        _errorMessage = '';
        notifyListeners();
      } catch (e) {
        debugPrint('[AnalyticsProvider] Sales poll error: $e');
      }
    }

    unawaited(poll());
    _salesPollTimer = Timer.periodic(_pollInterval, (_) => poll());
  }

  void unsubscribeFromSalesUpdates() {
    _salesPollTimer?.cancel();
    _salesPollTimer = null;
  }

  Future<AnalyticsModel?> _computeAnalyticsFromData(DateTime startDate,
      DateTime endDate, List<Map<String, dynamic>> salesData) async {
    try {
      double totalRevenue = 0;
      double totalCogs = 0.0;
      int totalTransactions = salesData.length;
      Map<String, double> workerSalesMap = {};
      Set<String> allCustomerIds = {};

      for (var data in salesData) {
        final amount = _saleAmount(data);
        totalRevenue += amount;
        final customerId =
            (data['customerId'] ?? data['customer_id']) as String?;
        if (customerId != null) allCustomerIds.add(customerId);

        final items = (data['items'] as List<dynamic>?) ?? [];
        for (var item in items) {
          final itemMap = item as Map<String, dynamic>;
          final productId = _itemProductId(itemMap);
          final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 0;
          double costPerUnit = 0.0;
          if (productId != null && _productCache.containsKey(productId)) {
            costPerUnit = (_productCache[productId]!['cost'] as double?) ?? 0.0;
          }
          totalCogs += (costPerUnit * quantity);
        }

        final workerId = (data['workerId'] ?? data['worker_id']) as String?;
        final workerName =
            (data['workerName'] ?? data['worker_name']) as String?;
        if (workerId != null && workerName != null) {
          workerSalesMap[workerName] =
              (workerSalesMap[workerName] ?? 0.0) + amount;
        }
      }

      final productStats = _computeProductStats(salesData);

      final periodDays = endDate.difference(startDate).inDays;
      final previousStartDate = startDate.subtract(Duration(days: periodDays));
      final previousEndDate = startDate;

      final previousSales = await _salesRepo.fetchSales(
        businessId: _businessId,
        start: previousStartDate,
        end: previousEndDate,
      );

      double previousRevenue = 0;
      int previousTransactions = previousSales.length;
      for (var sale in previousSales) {
        previousRevenue += _saleAmount(sale);
      }
      final revenueGrowth = previousRevenue > 0
          ? ((totalRevenue - previousRevenue) / previousRevenue) * 100
          : 0.0;
      final transactionGrowth = totalTransactions - previousTransactions;

      int newCustomers = 0;
      try {
        final newCustomersList = await _customerRepo.getCustomers(
          _businessId!,
          filters: {
            'startDate': startDate.toIso8601String(),
            'endDate': endDate.toIso8601String(),
            'limit': 200,
          },
        );
        newCustomers = newCustomersList.length;
      } catch (e) {
        debugPrint('[AnalyticsProvider] Error fetching new customers: $e');
      }
      int returningCustomers = allCustomerIds.length - newCustomers;
      double retentionRate = allCustomerIds.isNotEmpty
          ? (returningCustomers / allCustomerIds.length) * 100
          : 0.0;

      String topProductName = 'N/A';
      int topProductSales = 0;
      String topProductId = '';
      productStats.forEach((key, stats) {
        final sales = (stats['quantity'] as int?) ?? 0;
        if (sales > topProductSales) {
          topProductSales = sales;
          topProductName = (stats['name'] as String?) ?? 'N/A';
          topProductId = (stats['id'] as String?) ?? '';
        }
      });

      String topWorkerName = 'N/A';
      double topWorkerSales = 0.0;
      workerSalesMap.forEach((name, sales) {
        if (sales > topWorkerSales) {
          topWorkerSales = sales;
          topWorkerName = name;
        }
      });

      final averageOrderValue =
          totalTransactions > 0 ? totalRevenue / totalTransactions : 0.0;

      final grossProfit = totalRevenue - totalCogs;

      return AnalyticsModel(
        period: _getPeriodLabel(periodDays),
        startDate: startDate,
        endDate: endDate,
        totalRevenue: totalRevenue,
        averageOrderValue: averageOrderValue,
        revenueGrowth: revenueGrowth,
        totalTransactions: totalTransactions,
        transactionGrowth: transactionGrowth,
        newCustomers: newCustomers,
        returningCustomers: returningCustomers,
        customerRetentionRate: retentionRate,
        topProductId: topProductId,
        topProductName: topProductName,
        topProductSales: topProductSales,
        totalCogs: totalCogs,
        grossProfit: grossProfit,
        topWorkerId: 'worker_1',
        topWorkerName: topWorkerName,
        topWorkerSales: topWorkerSales,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[AnalyticsProvider] computeFromData error: $e');
      return null;
    }
  }

  List<Map<String, dynamic>> get topProducts => List.unmodifiable(_topProducts);
  List<Map<String, dynamic>> get revenueTrend =>
      List.unmodifiable(_revenueTrend);

  /// Public helper for testing: compute analytics from raw sales data
  Future<AnalyticsModel?> computeAnalyticsFromSalesData(
      DateTime startDate,
      DateTime endDate,
      List<Map<String, dynamic>> salesData,
      {Map<String, Map<String, dynamic>>? productCacheOverride}) async {
    // If a product cache override is provided (useful for tests), temporarily use it
    final oldCache = Map<String, Map<String, dynamic>>.from(_productCache);
    if (productCacheOverride != null) {
      _productCache.clear();
      _productCache.addAll(productCacheOverride);
    }

    final result = await _computeAnalyticsFromData(startDate, endDate, salesData);

    // Restore old cache
    _productCache.clear();
    _productCache.addAll(oldCache);

    return result;
  }

  // Helper methods
  String _getPeriodLabel(int days) {
    if (days == 1) return 'daily';
    if (days <= 7) return 'weekly';
    if (days <= 30) return 'monthly';
    return 'yearly';
  }

  String _getCacheKey(DateTime start, DateTime end) {
    return '${start.toIso8601String()}_${end.toIso8601String()}';
  }

  DateTime _getNextPeriodDate(DateTime date, String period) {
    switch (period) {
      case 'daily':
        return date.add(const Duration(days: 1));
      case 'weekly':
        return date.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(date.year, date.month + 1, date.day);
      default:
        return date.add(const Duration(days: 1));
    }
  }

  String _formatPeriodKey(DateTime date, String period) {
    switch (period) {
      case 'daily':
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      case 'weekly':
        final weekStart = date.subtract(Duration(days: date.weekday - 1));
        return 'W${date.month}D${weekStart.day}';
      case 'monthly':
        return '${date.year}-${date.month.toString().padLeft(2, '0')}';
      default:
        return date.toIso8601String();
    }
  }

  void clear() {
    _currentAnalytics = null;
    _analyticsCache.clear();
    _errorMessage = '';
    notifyListeners();
  }
}
