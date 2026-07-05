 import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../data/models/analytics_model.dart';

class AnalyticsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _businessId;
  AnalyticsModel? _currentAnalytics;
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _revenueTrend = [];
  DateTime? _lastRangeStart;
  DateTime? _lastRangeEnd;
  final Map<String, AnalyticsModel> _analyticsCache = {};
  final Map<String, Map<String, dynamic>> _productCache = {};
  StreamSubscription<QuerySnapshot>? _salesSubscription;
  StreamSubscription<QuerySnapshot>? _productsSubscription;
  bool _isLoading = false;
  String _errorMessage = '';

  // Getters
  AnalyticsModel? get currentAnalytics => _currentAnalytics;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  void setBusinessId(String businessId) {
    if (_businessId != null && _businessId != businessId) {
      // cancel any existing realtime subscriptions
      _salesSubscription?.cancel();
      _productsSubscription?.cancel();
      _salesSubscription = null;
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
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory')
          .get();

      final Map<String, Map<String, dynamic>> cache = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        cache[doc.id] = {
          'id': doc.id,
          'name':
              data['name'] ?? data['productName'] ?? data['title'] ?? 'Unknown',
          'price': (data['price'] as num?)?.toDouble() ??
              (data['unitPrice'] as num?)?.toDouble() ??
              0.0,          // cost fields (cost, costPrice, purchasePrice, unitCost)
          'cost': (data['cost'] as num?)?.toDouble() ??
              (data['costPrice'] as num?)?.toDouble() ??
              (data['purchasePrice'] as num?)?.toDouble() ??
              (data['unitCost'] as num?)?.toDouble() ??
              0.0,          'category': data['category'] ?? '',
          'stock': (data['stock'] as num?)?.toInt() ?? 0,
          'imageUrl': data['imageUrl'],
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
    _productsSubscription?.cancel();
    _productsSubscription = _firestore
        .collection('businesses')
        .doc(_businessId)
        .collection('inventory')
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        _productCache[doc.id] = {
          'id': doc.id,
          'name': data['name'] ?? data['productName'] ?? 'Unknown',
          'price': (data['price'] as num?)?.toDouble() ??
              (data['unitPrice'] as num?)?.toDouble() ??
              0.0,          'cost': (data['cost'] as num?)?.toDouble() ??
              (data['costPrice'] as num?)?.toDouble() ??
              (data['purchasePrice'] as num?)?.toDouble() ??
              (data['unitCost'] as num?)?.toDouble() ??
              0.0,          'category': data['category'] ?? '',
          'stock': (data['stock'] as num?)?.toInt() ?? 0,
          'imageUrl': data['imageUrl'],
        };
      }
      // remove deleted products
      final ids = snapshot.docs.map((d) => d.id).toSet();
      _productCache.removeWhere((k, v) => !ids.contains(k));
      notifyListeners();
      // Refresh analytics-derived lists if we have a known range
      if (_lastRangeStart != null && _lastRangeEnd != null) {
        getTopProducts(_lastRangeStart!, _lastRangeEnd!).then((list) {
          _topProducts = list;
          notifyListeners();
        });
        getRevenueTrend(_lastRangeStart!, _lastRangeEnd!).then((list) {
          _revenueTrend = list;
          notifyListeners();
        });
      }
    }, onError: (e) {
      debugPrint('[AnalyticsProvider] Product subscription error: $e');
    });
  }

  void unsubscribeFromProductUpdates() {
    _productsSubscription?.cancel();
    _productsSubscription = null;
  }

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
      // Get all sales in range
      final salesSnapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('sales')
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThanOrEqualTo: endDate)
          .get();

      final sales = salesSnapshot.docs;

      // Calculate metrics
      double totalRevenue = 0;
      double totalCogs = 0.0;
      int totalTransactions = sales.length;
      Map<String, Map<String, dynamic>> productStats = {};
      Map<String, double> workerSalesMap = {};
      // Set<String> newCustomerIds = {};
      Set<String> allCustomerIds = {};

      for (var sale in sales) {
        final data = sale.data();
        // supporters use totalAmount for clarity; fall back to old 'total' if present
        final amount = (data['totalAmount'] as num?)?.toDouble() ??
            (data['total'] as num?)?.toDouble() ??
            0.0;
        totalRevenue += amount;

        // Track customer
        final customerId = data['customerId'] as String?;
        if (customerId != null) {
          allCustomerIds.add(customerId);
        }

        // Track products
        final items = (data['items'] as List<dynamic>?) ?? [];
        for (var item in items) {
          final itemMap = item as Map<String, dynamic>;
          final productId = itemMap['productId'] as String?;
          final productNameFromItem = (itemMap['productName'] as String?) ??
              (itemMap['name'] as String?);
          final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 0;
          double unitPrice = 0.0;
          if (productId != null && _productCache.containsKey(productId)) {
            unitPrice = (_productCache[productId]!['price'] as double?) ?? 0.0;
          }
          unitPrice = unitPrice == 0.0
              ? (itemMap['unitPrice'] as num?)?.toDouble() ??
                  (itemMap['price'] as num?)?.toDouble() ??
                  0.0
              : unitPrice;
          final key = productId ??
              productNameFromItem ??
              'unknown_${productStats.length}';
          final name = productId != null && _productCache.containsKey(productId)
              ? _productCache[productId]!['name']
              : (productNameFromItem ?? 'Unknown');

          // determine cost per unit (prefer product cache cost, then item-level fields)
          double costPerUnit = 0.0;
          if (productId != null && _productCache.containsKey(productId)) {
            costPerUnit = (_productCache[productId]!['cost'] as double?) ?? 0.0;
          }
          if (costPerUnit == 0.0) {
            costPerUnit = (itemMap['cost'] as num?)?.toDouble() ??
                (itemMap['costPrice'] as num?)?.toDouble() ??
                (itemMap['purchasePrice'] as num?)?.toDouble() ??
                0.0;
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

          // accumulate COGS
          totalCogs += (costPerUnit * quantity);
        }

        // Track workers
        final workerId = data['workerId'] as String?;
        final workerName = data['workerName'] as String?;
        if (workerId != null && workerName != null) {
          workerSalesMap[workerName] =
              (workerSalesMap[workerName] ?? 0.0) + amount;
        }
      }

      // Get previous period for growth calculation
      final periodDays = endDate.difference(startDate).inDays;
      final previousStartDate = startDate.subtract(Duration(days: periodDays));
      final previousEndDate = startDate;

      final previousSalesSnapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('sales')
          .where('createdAt', isGreaterThanOrEqualTo: previousStartDate)
          .where('createdAt', isLessThanOrEqualTo: previousEndDate)
          .get();

      double previousRevenue = 0;
      int previousTransactions = previousSalesSnapshot.docs.length;

      for (var sale in previousSalesSnapshot.docs) {
        final amount = (sale.data()['totalAmount'] as num?)?.toDouble() ??
            (sale.data()['total'] as num?)?.toDouble() ??
            0.0;
        previousRevenue += amount;
      }

      // Calculate growth percentages
      final revenueGrowth = previousRevenue > 0
          ? ((totalRevenue - previousRevenue) / previousRevenue) * 100
          : 0.0;

      final transactionGrowth = totalTransactions - previousTransactions;

      // Get new customers
      final newCustomersSnapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('customers')
          .where('firstPurchaseDate', isGreaterThanOrEqualTo: startDate)
          .where('firstPurchaseDate', isLessThanOrEqualTo: endDate)
          .get();

      int newCustomers = newCustomersSnapshot.docs.length;
      int returningCustomers = allCustomerIds.length - newCustomers;

      // Calculate retention rate
      double retentionRate = allCustomerIds.isNotEmpty
          ? (returningCustomers / allCustomerIds.length) * 100
          : 0.0;

      // Find top product
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

      // Find top worker
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
      final analytics = AnalyticsModel(
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
        topWorkerId: 'worker_1',
        topWorkerName: topWorkerName,
        topWorkerSales: topWorkerSales,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        totalCogs: totalCogs,
        grossProfit: grossProfit,
      );

      _currentAnalytics = analytics;
      // compute a cached topProducts and revenueTrend for UI consumption
      _topProducts = await getTopProducts(startDate, endDate);
      _revenueTrend = await getRevenueTrend(startDate, endDate);
      _analyticsCache[_getCacheKey(startDate, endDate)] = analytics;
      _errorMessage = '';
      print('[AnalyticsProvider] Analytics calculated: ₦$totalRevenue revenue');
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

  /// Get top products by sales
  Future<List<Map<String, dynamic>>> getTopProducts(
    DateTime startDate,
    DateTime endDate, {
    int limit = 5,
  }) async {
    if (_businessId == null) return [];

    try {
      final salesSnapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('sales')
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThanOrEqualTo: endDate)
          .get();

      Map<String, Map<String, dynamic>> productStats = {};

      for (var sale in salesSnapshot.docs) {
        final data = sale.data();
        final items = (data['items'] as List<dynamic>?) ?? [];

        for (var item in items) {
          final itemMap = item as Map<String, dynamic>;
          final productId = itemMap['productId'] as String?;
          final productNameFromItem = (itemMap['productName'] as String?) ??
              (itemMap['name'] as String?);
          final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 0;
          // Prefer product price from product cache or field 'price'/'unitPrice' on the item
          double unitPrice = 0.0;
          if (productId != null && _productCache.containsKey(productId)) {
            unitPrice = (_productCache[productId]!['price'] as double?) ?? 0.0;
          }
          unitPrice = unitPrice == 0.0
              ? (itemMap['unitPrice'] as num?)?.toDouble() ??
                  (itemMap['price'] as num?)?.toDouble() ??
                  0.0
              : unitPrice;
          final key = productId ??
              productNameFromItem ??
              'unknown_${productStats.length}';
          final name = productId != null && _productCache.containsKey(productId)
              ? _productCache[productId]!['name']
              : (productNameFromItem ?? 'Unknown');

          if (!productStats.containsKey(key)) {
            productStats[key] = {
              'id': productId,
              'name': name,
              'quantity': 0,
              'revenue': 0.0,
              'unitPrice': unitPrice,
            };
          }

          productStats[key]!['quantity'] += quantity;
          productStats[key]!['revenue'] += quantity * unitPrice;
          // If unitPrice differs, keep latest value
          productStats[key]!['unitPrice'] = unitPrice;
        }
      }

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

        final salesSnapshot = await _firestore
            .collection('businesses')
            .doc(_businessId)
            .collection('sales')
            .where('createdAt', isGreaterThanOrEqualTo: currentDate)
            .where('createdAt', isLessThanOrEqualTo: adjustedEndDate)
            .get();

        double periodRevenue = 0;
        for (var sale in salesSnapshot.docs) {
          final amount = (sale.data()['totalAmount'] as num?)?.toDouble() ??
              (sale.data()['total'] as num?)?.toDouble() ??
              0.0;
          periodRevenue += amount;
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

  // Real-time subscription to sales updates for given range
  void subscribeToSalesUpdates(DateTime startDate, DateTime endDate) {
    if (_businessId == null) return;
    _salesSubscription?.cancel();
    _salesSubscription = _firestore
        .collection('businesses')
        .doc(_businessId)
        .collection('sales')
        .where('createdAt', isGreaterThanOrEqualTo: startDate)
        .where('createdAt', isLessThanOrEqualTo: endDate)
        .snapshots()
        .listen((snapshot) async {
      // Recompute analytics on every change
      try {
        final docs = snapshot.docs;
        // Convert docs to list of data to reuse existing compute paths
        final tempSales = docs.map((d) => d.data()).toList();
        // Use an internal helper to compute analytics directly
        final model =
            await _computeAnalyticsFromData(startDate, endDate, tempSales);
        _currentAnalytics = model;
        _topProducts = await getTopProducts(startDate, endDate);
        _revenueTrend = await getRevenueTrend(startDate, endDate,
            period: _getPeriodLabel(endDate.difference(startDate).inDays));
        _errorMessage = '';
        notifyListeners();
      } catch (e) {
        debugPrint('[AnalyticsProvider] Realtime calc error: $e');
      }
    }, onError: (e) {
      debugPrint('[AnalyticsProvider] Sales subscription error: $e');
    });
  }

  void unsubscribeFromSalesUpdates() {
    _salesSubscription?.cancel();
    _salesSubscription = null;
  }

  Future<AnalyticsModel?> _computeAnalyticsFromData(DateTime startDate,
      DateTime endDate, List<Map<String, dynamic>> salesData) async {
    try {
      double totalRevenue = 0;
      double totalCogs = 0.0;
      int totalTransactions = salesData.length;
      Map<String, Map<String, dynamic>> productStats = {};
      Map<String, double> workerSalesMap = {};
      Set<String> allCustomerIds = {};

      for (var data in salesData) {
        final amount = (data['totalAmount'] as num?)?.toDouble() ??
            (data['total'] as num?)?.toDouble() ??
            0.0;
        totalRevenue += amount;
        final customerId = data['customerId'] as String?;
        if (customerId != null) allCustomerIds.add(customerId);
        final items = (data['items'] as List<dynamic>?) ?? [];
        for (var item in items) {
          final itemMap = item as Map<String, dynamic>;
          final productId = itemMap['productId'] as String?;
          final productNameFromItem = (itemMap['productName'] as String?) ??
              (itemMap['name'] as String?);
          final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 0;
          double unitPrice = 0.0;
          if (productId != null && _productCache.containsKey(productId)) {
            unitPrice = (_productCache[productId]!['price'] as double?) ?? 0.0;
          }
          unitPrice = unitPrice == 0.0
              ? (itemMap['unitPrice'] as num?)?.toDouble() ??
                  (itemMap['price'] as num?)?.toDouble() ??
                  0.0
              : unitPrice;
          final key = productId ??
              productNameFromItem ??
              'unknown_${productStats.length}';
          final name = productId != null && _productCache.containsKey(productId)
              ? _productCache[productId]!['name']
              : (productNameFromItem ?? 'Unknown');

          // determine cost per unit (prefer product cache cost, then item-level fields)
          double costPerUnit = 0.0;
          if (productId != null && _productCache.containsKey(productId)) {
            costPerUnit = (_productCache[productId]!['cost'] as double?) ?? 0.0;
          }
          if (costPerUnit == 0.0) {
            costPerUnit = (itemMap['cost'] as num?)?.toDouble() ??
                (itemMap['costPrice'] as num?)?.toDouble() ??
                (itemMap['purchasePrice'] as num?)?.toDouble() ??
                0.0;
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

          // accumulate COGS
          totalCogs += (costPerUnit * quantity);
        }
        final workerId = data['workerId'] as String?;
        final workerName = data['workerName'] as String?;
        if (workerId != null && workerName != null) {
          workerSalesMap[workerName] =
              (workerSalesMap[workerName] ?? 0.0) + amount;
        }
      }

      final periodDays = endDate.difference(startDate).inDays;
      final previousStartDate = startDate.subtract(Duration(days: periodDays));
      final previousEndDate = startDate;

      final previousSalesSnapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('sales')
          .where('createdAt', isGreaterThanOrEqualTo: previousStartDate)
          .where('createdAt', isLessThanOrEqualTo: previousEndDate)
          .get();

      double previousRevenue = 0;
      int previousTransactions = previousSalesSnapshot.docs.length;
      for (var sale in previousSalesSnapshot.docs) {
        final amount = (sale.data()['totalAmount'] as num?)?.toDouble() ??
            (sale.data()['total'] as num?)?.toDouble() ??
            0.0;
        previousRevenue += amount;
      }
      final revenueGrowth = previousRevenue > 0
          ? ((totalRevenue - previousRevenue) / previousRevenue) * 100
          : 0.0;
      final transactionGrowth = totalTransactions - previousTransactions;

      final newCustomersSnapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('customers')
          .where('firstPurchaseDate', isGreaterThanOrEqualTo: startDate)
          .where('firstPurchaseDate', isLessThanOrEqualTo: endDate)
          .get();
      int newCustomers = newCustomersSnapshot.docs.length;
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

