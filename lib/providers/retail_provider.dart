import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import '../core/utils/datetime_utils.dart';
import '../core/utils/connectivity_helper.dart';
import '../services/business_notification_manager.dart';
import '../services/notification_and_email_service.dart';
import '../services/managecare_api_client.dart';
import '../data/local/database_helper.dart';
import '../data/repositories/sales_repository_supabase.dart';
import '../data/repositories/inventory_repository_supabase.dart';
import '../services/sync_service.dart';

class Product {
  final String id;
  final String name;
  final double price;
  final double cost;
  final double? wholesalePrice;
  double stock;
  final String category;
  final String? imageUrl;
  final String? barcode;
  final String emoji;
  final String unit; // e.g., L, cyl
  final String saleUnit;
  final double saleUnitMultiplier;
  final bool trackExpiry;
  final DateTime? expiryDate;
  final String? batchLabel;
  final int? shelfLifeDays;
  final double distributorDiscountPercent;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.cost = 0.0,
    this.wholesalePrice,
    required this.stock,
    required this.category,
    this.imageUrl,
    this.barcode,
    this.emoji = '📦',
    this.unit = 'pc',
    this.saleUnit = '',
    this.saleUnitMultiplier = 1.0,
    this.trackExpiry = false,
    this.expiryDate,
    this.batchLabel,
    this.shelfLifeDays,
    this.distributorDiscountPercent = 0.0,
  });

  String get resolvedSaleUnit => saleUnit.trim().isEmpty ? unit : saleUnit;
  double get resolvedSaleUnitMultiplier =>
      saleUnitMultiplier <= 0 ? 1.0 : saleUnitMultiplier;
  bool get hasWholesalePricing =>
      (wholesalePrice ?? 0) > 0 && (wholesalePrice! - price).abs() > 0.0001;

  factory Product.fromJson(Map<String, dynamic> data) {
    return Product(
      id: (data['id'] ?? '').toString(),
      name: data['name'] ?? '',
      price: (data['price'] ?? data['unit_price'] ?? 0.0).toDouble(),
      cost: (data['cost'] ?? 0.0).toDouble(),
      wholesalePrice:
          (data['wholesalePrice'] ?? data['wholesale_price'] as num?)
              ?.toDouble(),
      stock: (data['quantity'] as num?)?.toDouble() ??
          (data['stock'] as num?)?.toDouble() ??
          0.0,
      category: data['category'] ?? 'Uncategorized',
      imageUrl: data['imageUrl'] ?? data['image_url'],
      barcode: data['barcode'],
      emoji: data['emoji'] ?? '📦',
      unit: (data['unit'] ?? 'pc').toString(),
      saleUnit:
          (data['saleUnit'] ?? data['sale_unit'] ?? data['unit'] ?? 'pc')
              .toString(),
      saleUnitMultiplier: (data['saleUnitMultiplier'] ??
                  data['sale_unit_multiplier'] as num?)
              ?.toDouble() ??
          1.0,
      trackExpiry: data['trackExpiry'] == true || data['track_expiry'] == true,
      expiryDate: (data['expiryDate'] ?? data['expiry_date']) == null
          ? null
          : parseTimestamp(data['expiryDate'] ?? data['expiry_date']),
      batchLabel: (data['batchLabel'] ?? data['batch_label'])?.toString(),
      shelfLifeDays:
          (data['shelfLifeDays'] ?? data['shelf_life_days'] as num?)?.toInt(),
      distributorDiscountPercent: (data['distributorDiscountPercent'] ??
                  data['distributor_discount_percent'] as num?)
              ?.toDouble() ??
          0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'cost': cost,
      'quantity': stock,
      'category': category,
      'image_url': imageUrl,
      'barcode': barcode,
      'emoji': emoji,
      'unit': unit,
      'wholesale_price': wholesalePrice,
      'sale_unit': resolvedSaleUnit,
      'sale_unit_multiplier': resolvedSaleUnitMultiplier,
      'track_expiry': trackExpiry,
      if (expiryDate != null) 'expiry_date': expiryDate!.toIso8601String(),
      if (batchLabel != null && batchLabel!.trim().isNotEmpty)
        'batch_label': batchLabel!.trim(),
      if (shelfLifeDays != null) 'shelf_life_days': shelfLifeDays,
      'distributor_discount_percent': distributorDiscountPercent,
    };
  }
}

class Supplier {
  final String id;
  final String name;
  final String contact;
  final String email;
  final String? address;

  Supplier({
    required this.id,
    required this.name,
    required this.contact,
    required this.email,
    this.address,
  });

  factory Supplier.fromJson(Map<String, dynamic> data) {
    return Supplier(
      id: (data['id'] ?? '').toString(),
      name: data['name'] ?? '',
      contact: data['contact'] ?? '',
      email: data['email'] ?? '',
      address: data['address'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'contact': contact,
      'email': email,
      'address': address,
    };
  }
}

class StoreLocation {
  final String id;
  final String name;
  final String location;
  final String? address;
  final String? phone;

  StoreLocation({
    required this.id,
    required this.name,
    required this.location,
    this.address,
    this.phone,
  });

  factory StoreLocation.fromJson(Map<String, dynamic> data) {
    return StoreLocation(
      id: (data['id'] ?? '').toString(),
      name: data['name'] ?? '',
      location: data['location'] ?? '',
      address: data['address'],
      phone: data['phone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'location': location,
      'address': address,
      'phone': phone,
    };
  }
}

class Promotion {
  final String id;
  final String name;
  final String description;
  final double discountPercentage;
  final DateTime startDate;
  final DateTime endDate;

  Promotion({
    required this.id,
    required this.name,
    required this.description,
    required this.discountPercentage,
    required this.startDate,
    required this.endDate,
  });

  factory Promotion.fromJson(Map<String, dynamic> data) {
    return Promotion(
      id: (data['id'] ?? '').toString(),
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      discountPercentage:
          (data['discountPercentage'] ?? data['discount_percentage'] ?? 0.0)
              .toDouble(),
      startDate: parseTimestamp(data['startDate'] ?? data['start_date']),
      endDate: parseTimestamp(data['endDate'] ?? data['end_date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'discount_percentage': discountPercentage,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    };
  }
}

class CartSessionSummary {
  final String id;
  final String label;
  final int itemCount;
  final bool isActive;

  const CartSessionSummary({
    required this.id,
    required this.label,
    required this.itemCount,
    required this.isActive,
  });
}

class RetailProvider extends ChangeNotifier {
  final NotificationAndEmailService _notificationEmailService;
  final ManagecareApiClient _api = ManagecareApiClient.instance;
  final SalesRepositorySupabase _salesRepo = SalesRepositorySupabase();
  final InventoryRepositorySupabase _inventoryRepo =
      InventoryRepositorySupabase();

  List<Product> _products = [];
  List<Supplier> _suppliers = [];
  List<StoreLocation> _stores = [];
  List<Promotion> _promotions = [];

  // ── Quota optimisation: product cache TTL ───────────────────────────
  // Products are re-fetched only when the cache is older than 5 minutes
  // or the business/store changes. Pass forceRefresh: true after mutations.
  DateTime? _lastProductFetch;
  String? _lastProductFetchStoreId;
  static const _productCacheTtl = Duration(minutes: 5);
  // ────────────────────────────────────────────────────────────────────

  // Cart: productId -> qty
  final Map<String, int> _cart = {};
  final Map<String, Map<String, int>> _cartSessions = {};
  final Map<String, String> _cartLabels = {};
  // Pricing modes are tracked per cart session to avoid cross-cart bleed.
  final Map<String, Map<String, String>> _cartSessionPricingModes = {};
  final Map<String, String> _cartDefaultPricingModes = {};
  String _activeCartId = 'cart_1';
  int _cartSessionCounter = 1;
  static const String _cartCacheKeyPrefix = 'retail_cart_state_v1_';
  static const String _pendingPumpSalesKeyPrefix = 'pending_pump_sales_v1_';

  bool _isLoading = false;
  String? _errorMessage;
  String? _businessId;

  // Initialization tracking to prevent redundant loads
  bool _isInitialized = false;
  DateTime? _lastInitTime;
  static const Duration _initMinInterval = Duration(minutes: 10);

  // Getters
  List<Product> get products => List.unmodifiable(_products);
  List<Supplier> get suppliers => List.unmodifiable(_suppliers);
  List<StoreLocation> get stores => List.unmodifiable(_stores);
  List<Promotion> get promotions => List.unmodifiable(_promotions);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get activeCartId => _activeCartId;
  Future<int> get pendingPumpSaleCount async {
    final businessId = _businessId;
    if (businessId == null || businessId.isEmpty) return 0;
    return (await _loadPendingPumpSales(businessId)).length;
  }

  String get activeCartLabel => _cartLabels[_activeCartId] ?? 'Cart 1';
  String get activeCartPricingMode =>
      _cartDefaultPricingModes[_activeCartId] ?? 'retail';

  List<CartSessionSummary> get cartSessions {
    return _cartSessions.entries.map((entry) {
      final itemCount =
          entry.value.values.fold<int>(0, (sum, qty) => sum + qty);
      return CartSessionSummary(
        id: entry.key,
        label: _cartLabels[entry.key] ?? 'Cart',
        itemCount: itemCount,
        isActive: entry.key == _activeCartId,
      );
    }).toList()
      ..sort((a, b) {
        if (a.isActive == b.isActive) {
          return a.label.compareTo(b.label);
        }
        return a.isActive ? -1 : 1;
      });
  }

  Map<Product, int> get cartItems {
    return Map.fromEntries(
      _cart.entries.map((e) {
        final p = _products.firstWhere(
          (prod) => prod.id == e.key,
          orElse: () => Product(
            id: e.key,
            name: 'Unknown',
            price: 0,
            stock: 0,
            category: 'Unknown',
          ),
        );
        return MapEntry(p, e.value);
      }),
    );
  }

  int get cartCount => _cart.values.fold(0, (a, b) => a + b);

  Map<String, int> get cart => Map.unmodifiable(_cart);

  double get cartTotal => _cart.entries.fold(0.0, (sum, e) {
        return sum + getEffectivePriceForCartItem(e.key) * e.value;
      });

  // final dynamic _printerService; // accepts any object implementing PrinterService for testability - UNUSED

  RetailProvider(
      {NotificationAndEmailService? notificationEmailService,
      dynamic printerService})
      : _notificationEmailService =
            notificationEmailService ?? NotificationAndEmailService() {
    _ensureActiveCart();
    // printerService parameter unused - for future implementation
  }

  Map<String, int> _ensureActiveCart() {
    _cartSessions.putIfAbsent(_activeCartId, () => _cart);
    _cartLabels.putIfAbsent(_activeCartId, () => 'Cart 1');
    _cartSessionPricingModes.putIfAbsent(
      _activeCartId,
      () => <String, String>{},
    );
    _cartDefaultPricingModes.putIfAbsent(_activeCartId, () => 'retail');
    return _cartSessions[_activeCartId]!;
  }

  Map<String, String> _activePricingModes() {
    _ensureActiveCart();
    return _cartSessionPricingModes[_activeCartId]!;
  }

  void _syncActiveCartSnapshot() {
    final pricingModes = _activePricingModes();
    pricingModes.removeWhere((productId, _) => !_cart.containsKey(productId));
    _cartSessions[_activeCartId] = Map<String, int>.from(_cart);
    _cartLabels.putIfAbsent(_activeCartId, () => 'Cart 1');
    _cartDefaultPricingModes.putIfAbsent(_activeCartId, () => 'retail');
    if (_cart.isNotEmpty) {
      final uniqueModes = _cart.keys
          .map((productId) => pricingModes[productId] ?? 'retail')
          .toSet();
      if (uniqueModes.length == 1) {
        _cartDefaultPricingModes[_activeCartId] = uniqueModes.first;
      }
    }
  }

  String _cartCacheKey(String businessId) =>
      '$_cartCacheKeyPrefix${businessId.trim()}';

  int _deriveCartSessionCounter([Iterable<String>? cartIds]) {
    var maxCounter = 1;
    for (final cartId in cartIds ?? _cartSessions.keys) {
      final match = RegExp(r'^cart_(\d+)$').firstMatch(cartId.trim());
      final parsed = int.tryParse(match?.group(1) ?? '');
      if (parsed != null && parsed > maxCounter) {
        maxCounter = parsed;
      }
    }
    return maxCounter;
  }

  void _queueCartCacheSave() {
    unawaited(_saveCartStateToCache());
  }

  Future<void> _saveCartStateToCache() async {
    final businessId = _businessId?.trim() ?? '';
    if (businessId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        'activeCartId': _activeCartId,
        'cartSessionCounter': _cartSessionCounter,
        'cartLabels': Map<String, String>.from(_cartLabels),
        'cartSessions': _cartSessions.map(
          (cartId, items) => MapEntry(cartId, Map<String, int>.from(items)),
        ),
        'cartPricingModes': _cartSessionPricingModes.map(
          (cartId, modes) => MapEntry(cartId, Map<String, String>.from(modes)),
        ),
        'cartDefaultPricingModes': Map<String, String>.from(
          _cartDefaultPricingModes,
        ),
        'savedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_cartCacheKey(businessId), jsonEncode(payload));
    } catch (e) {
      debugPrint('[RetailProvider] Failed to cache cart state: $e');
    }
  }

  Future<void> _restoreCartStateFromCache() async {
    final businessId = _businessId?.trim() ?? '';
    if (businessId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cartCacheKey(businessId));
      if (raw == null || raw.trim().isEmpty) {
        _ensureActiveCart();
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _ensureActiveCart();
        return;
      }

      final restoredSessions = <String, Map<String, int>>{};
      final rawSessions = decoded['cartSessions'];
      if (rawSessions is Map) {
        for (final entry in rawSessions.entries) {
          final cartId = entry.key.toString();
          final value = entry.value;
          if (value is! Map) continue;
          restoredSessions[cartId] = value.map<String, int>((key, qty) {
            final parsedQty = qty is num
                ? qty.toInt()
                : int.tryParse(qty?.toString() ?? '') ?? 0;
            return MapEntry(key.toString(), parsedQty);
          })
            ..removeWhere((_, qty) => qty <= 0);
        }
      }

      final restoredLabels = <String, String>{};
      final rawLabels = decoded['cartLabels'];
      if (rawLabels is Map) {
        for (final entry in rawLabels.entries) {
          restoredLabels[entry.key.toString()] = entry.value.toString();
        }
      }

      final restoredPricingModes = <String, Map<String, String>>{};
      final rawPricingModes = decoded['cartPricingModes'];
      if (rawPricingModes is Map) {
        for (final entry in rawPricingModes.entries) {
          final cartId = entry.key.toString();
          final value = entry.value;
          if (value is! Map) continue;
          restoredPricingModes[cartId] = value.map<String, String>((key, mode) {
            final normalized =
                mode.toString() == 'wholesale' ? 'wholesale' : 'retail';
            return MapEntry(key.toString(), normalized);
          });
        }
      }

      final restoredDefaultModes = <String, String>{};
      final rawDefaultModes = decoded['cartDefaultPricingModes'];
      if (rawDefaultModes is Map) {
        for (final entry in rawDefaultModes.entries) {
          restoredDefaultModes[entry.key.toString()] =
              entry.value.toString() == 'wholesale' ? 'wholesale' : 'retail';
        }
      }

      _cartSessions
        ..clear()
        ..addAll(restoredSessions);
      _cartLabels
        ..clear()
        ..addAll(restoredLabels);
      _cartSessionPricingModes
        ..clear()
        ..addAll(restoredPricingModes);
      _cartDefaultPricingModes
        ..clear()
        ..addAll(restoredDefaultModes);

      final restoredCounter = decoded['cartSessionCounter'] is num
          ? (decoded['cartSessionCounter'] as num).toInt()
          : 0;
      final derivedCounter = _deriveCartSessionCounter(restoredSessions.keys);
      _cartSessionCounter = restoredCounter > 0
          ? (restoredCounter > derivedCounter
              ? restoredCounter
              : derivedCounter)
          : derivedCounter;

      final restoredActiveCartId =
          decoded['activeCartId']?.toString().trim() ?? '';
      if (restoredActiveCartId.isNotEmpty &&
          _cartSessions.containsKey(restoredActiveCartId)) {
        _activeCartId = restoredActiveCartId;
      } else if (_cartSessions.isNotEmpty) {
        _activeCartId = _cartSessions.keys.first;
      } else {
        _activeCartId = 'cart_1';
      }

      _ensureActiveCart();
      _cart
        ..clear()
        ..addAll(_cartSessions[_activeCartId] ?? const <String, int>{});
      _syncActiveCartSnapshot();
      notifyListeners();
    } catch (e) {
      debugPrint('[RetailProvider] Failed to restore cart cache: $e');
      _ensureActiveCart();
    }
  }

  void _resetActiveCartState({bool resetDefaultPricingMode = true}) {
    _cart.clear();
    _activePricingModes().clear();
    if (resetDefaultPricingMode) {
      _cartDefaultPricingModes[_activeCartId] = 'retail';
    }
    _syncActiveCartSnapshot();
  }

  Future<void> createCartSession(
      {String? label, bool switchToNew = true}) async {
    final seedPricingMode = activeCartPricingMode;
    _syncActiveCartSnapshot();
    _cartSessionCounter += 1;
    final cartId = 'cart_$_cartSessionCounter';
    _cartLabels[cartId] = (label == null || label.trim().isEmpty)
        ? 'Cart $_cartSessionCounter'
        : label.trim();
    _cartSessions[cartId] = <String, int>{};
    _cartSessionPricingModes[cartId] = <String, String>{};
    _cartDefaultPricingModes[cartId] = seedPricingMode;
    if (switchToNew) {
      _activeCartId = cartId;
      _cart
        ..clear()
        ..addAll(_cartSessions[cartId]!);
    }
    _queueCartCacheSave();
    notifyListeners();
  }

  DateTime _readTimestamp(dynamic value) {
    if (value is DateTime) return value;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  void switchCart(String cartId) {
    if (!_cartSessions.containsKey(cartId) || cartId == _activeCartId) return;
    _syncActiveCartSnapshot();
    _activeCartId = cartId;
    _cart
      ..clear()
      ..addAll(_cartSessions[cartId] ?? const <String, int>{});
    _ensureActiveCart();
    _queueCartCacheSave();
    notifyListeners();
  }

  void renameCart(String cartId, String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty || !_cartSessions.containsKey(cartId)) return;
    _cartLabels[cartId] = trimmed;
    _queueCartCacheSave();
    notifyListeners();
  }

  void closeCart(String cartId) {
    if (!_cartSessions.containsKey(cartId) || _cartSessions.length <= 1) {
      return;
    }
    final wasActive = cartId == _activeCartId;
    _cartSessions.remove(cartId);
    _cartLabels.remove(cartId);
    _cartSessionPricingModes.remove(cartId);
    _cartDefaultPricingModes.remove(cartId);
    if (wasActive) {
      final nextId = _cartSessions.keys.first;
      _activeCartId = nextId;
      _cart
        ..clear()
        ..addAll(_cartSessions[nextId] ?? const <String, int>{});
    }
    _ensureActiveCart();
    _queueCartCacheSave();
    notifyListeners();
  }

  // Initialize with business ID
  Future<void> initialize(String businessId) async {
    final isBusinessSwitch = _businessId != null && _businessId != businessId;
    // if switching business, cancel existing subscriptions
    if (isBusinessSwitch) {
      unsubscribeFromSalesHistory();
      _cart.clear();
      _cartSessions
        ..clear()
        ..['cart_1'] = _cart;
      _cartLabels
        ..clear()
        ..['cart_1'] = 'Cart 1';
      _cartSessionPricingModes
        ..clear()
        ..['cart_1'] = <String, String>{};
      _cartDefaultPricingModes
        ..clear()
        ..['cart_1'] = 'retail';
      _activeCartId = 'cart_1';
      _cartSessionCounter = 1;
      // ── Quota optimisation: invalidate product cache on business switch
      _lastProductFetch = null;
      _lastProductFetchStoreId = null;
      // ────────────────────────────────────────────────────────────────
    }
    _businessId = businessId;
    _ensureActiveCart();
    unawaited(syncPendingPumpSales());

    // Check if we should skip initialization (already initialized recently)
    if (!isBusinessSwitch && _isInitialized && _lastInitTime != null) {
      final elapsed = DateTime.now().difference(_lastInitTime!);
      if (elapsed < _initMinInterval) {
        print(
            '[RetailProvider] ⏭️ Skipping initialization - last init was ${elapsed.inSeconds}s ago');
        return;
      }
    }

    _isInitialized = true;
    _lastInitTime = DateTime.now();

    await Future.wait([
      loadProducts(),
      loadSuppliers(),
      loadStores(),
      loadPromotions(),
    ]);

    await _restoreCartStateFromCache();
  }

  /// Set business id and (re)initialize provider for that business
  Future<void> setBusinessId(String businessId) async {
    if (_businessId != null && _businessId == businessId) return;
    await initialize(businessId);
    notifyListeners();
  }

  // Load products from the inventory API
  Future<void> loadProducts(
      {String? storeId, bool forceRefresh = false}) async {
    if (_businessId == null) return;

    // ── Quota optimisation: TTL cache ────────────────────────────────
    if (!forceRefresh &&
        _products.isNotEmpty &&
        _lastProductFetch != null &&
        _lastProductFetchStoreId == (storeId ?? '') &&
        DateTime.now().difference(_lastProductFetch!) < _productCacheTtl) {
      return;
    }
    // ─────────────────────────────────────────────────────────────────

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final items = await _inventoryRepo.getInventory(
        _businessId!,
        storeId: storeId,
      );

      _products = items
          .map((raw) => Product.fromJson(raw as Map<String, dynamic>))
          .toList();

      // ── Quota optimisation: stamp cache timestamp ──────────────────
      _lastProductFetch = DateTime.now();
      _lastProductFetchStoreId = storeId ?? '';
      // ───────────────────────────────────────────────────────────────

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load products: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading products: $e');
    }
  }

  // Suppliers: no backend support yet.
  // TODO(migration): add a suppliers table + /api/suppliers routes on the
  // custom backend, then wire this up like loadProducts/loadStores.
  Future<void> loadSuppliers() async {
    if (_businessId == null) return;

    try {
      _suppliers = [];
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading suppliers: $e');
    }
  }

  Future<Map<String, dynamic>> _calculateFuelMetricsSnapshot(
    List<Map<String, dynamic>> sales,
  ) async {
    if (_products.isEmpty && _businessId != null) {
      await loadProducts();
    }

    double totalAmount = 0.0;
    double totalVolume = 0.0;
    int transactions = 0;

    final Map<String, String> productCategory = {
      for (var p in _products) p.id: p.category.toLowerCase()
    };

    for (final data in sales) {
      final items = (data['items'] as List<dynamic>?) ?? [];
      bool hasFuel = false;
      double saleFuelVolume = 0.0;
      double saleAmount = (data['final_amount'] as num?)?.toDouble() ??
          (data['total_amount'] as num?)?.toDouble() ??
          0.0;

      final saleCategory = (data['sale_type'] as String?)?.toLowerCase() ?? '';
      if (saleCategory.contains('fuel') ||
          saleCategory.contains('petrol') ||
          saleCategory.contains('gas')) {
        hasFuel = true;
      }

      for (final it in items) {
        if (it is! Map<String, dynamic>) continue;
        final pid = (it['product_id'] as String?) ?? '';
        final qtyNum = it['quantity'];
        double qty = 0.0;
        if (qtyNum is num) {
          qty = qtyNum.toDouble();
        } else {
          qty = double.tryParse(qtyNum?.toString() ?? '') ?? 0.0;
        }

        final category = productCategory[pid] ?? '';
        if (category.contains('fuel') ||
            category.contains('petrol') ||
            category.contains('gas')) {
          hasFuel = true;
          saleFuelVolume += qty;
        }
      }

      if (hasFuel) {
        transactions += 1;
        totalVolume += saleFuelVolume;
        totalAmount += saleAmount;
      }
    }

    return {
      'totalAmount': totalAmount,
      'totalVolume': totalVolume,
      'transactions': transactions,
    };
  }

  bool _isFuelText(String value) {
    final text = value.trim().toLowerCase();
    return text.contains('fuel') ||
        text.contains('gas') ||
        text.contains('pump') ||
        text.contains('petrol') ||
        text.contains('petroleum') ||
        text.contains('diesel') ||
        text.contains('deseal') ||
        text.contains('kerosene');
  }

  Future<List<Map<String, dynamic>>> _calculateFuelSalesHistorySnapshot(
    List<Map<String, dynamic>> sales,
  ) async {
    if (_products.isEmpty && _businessId != null) {
      await loadProducts();
    }

    final Map<String, String> productCategory = {
      for (var p in _products) p.id: p.category.toLowerCase()
    };

    final results = <Map<String, dynamic>>[];
    for (final data in sales) {
      final items = (data['items'] as List<dynamic>?) ?? [];
      double fuelVolume = 0.0;
      bool hasFuel = _isFuelText(data['category']?.toString() ?? '') ||
          _isFuelText(data['sale_type']?.toString() ?? '') ||
          _isFuelText(data['order_type']?.toString() ?? '') ||
          (data['pump_id']?.toString().isNotEmpty == true);
      for (final it in items) {
        if (it is! Map<String, dynamic>) continue;
        final pid = (it['product_id'] as String?) ?? '';
        final qtyNum = it['quantity'];
        double qty = 0.0;
        if (qtyNum is num) {
          qty = qtyNum.toDouble();
        } else {
          qty = double.tryParse(qtyNum?.toString() ?? '') ?? 0.0;
        }

        final category = productCategory[pid] ?? '';
        if (_isFuelText(category) ||
            _isFuelText(it['category']?.toString() ?? '') ||
            _isFuelText(it['product_name']?.toString() ?? '') ||
            _isFuelText(it['name']?.toString() ?? '')) {
          hasFuel = true;
          fuelVolume += qty;
        }
      }

      if (hasFuel) {
        final createdAt = _readTimestamp(data['created_at']);
        results.add({
          'id': data['id'],
          'createdAt': createdAt,
          'createdAtRaw': data['created_at'],
          'customerName': data['customer_name'] ?? 'Walk-in',
          'totalAmount': (data['final_amount'] as num?)?.toDouble() ??
              (data['total_amount'] as num?)?.toDouble() ??
              0.0,
          'fuelVolume': fuelVolume,
          'paymentMethod': data['payment_method'] ?? 'Cash',
          'items': items,
        });
      }
    }

    return results;
  }

  /// Returns aggregated fuel metrics for the business within an optional date range.
  /// If no range provided it uses today as default.
  Future<Map<String, dynamic>> getFuelMetrics(
      {DateTime? start, DateTime? end}) async {
    if (_businessId == null)
      return {'totalAmount': 0.0, 'totalVolume': 0.0, 'transactions': 0};

    final now = DateTime.now();
    final s = start ?? DateTime(now.year, now.month, now.day);
    final e = end ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    try {
      final sales = await _salesRepo.fetchSales(
        businessId: _businessId,
        start: s,
        end: e,
      );
      return await _calculateFuelMetricsSnapshot(sales);
    } catch (e) {
      debugPrint('Error computing fuel metrics: $e');
      return {'totalAmount': 0.0, 'totalVolume': 0.0, 'transactions': 0};
    }
  }

  // No realtime push from the custom backend - polled like the inventory
  // streams (InventoryRepositorySupabase.streamInventory).
  static const _fuelMetricsPollInterval = Duration(seconds: 15);

  Stream<Map<String, dynamic>> watchFuelMetrics(
      {DateTime? start, DateTime? end}) async* {
    if (_businessId == null) {
      yield {'totalAmount': 0.0, 'totalVolume': 0.0, 'transactions': 0};
      return;
    }

    while (true) {
      yield await getFuelMetrics(start: start, end: end);
      await Future.delayed(_fuelMetricsPollInterval);
    }
  }

  /// Returns a list of sales that include fuel items, with computed fuelVolume for each sale.
  ///
  /// If `start` and `end` are not provided, this will return the most recent `limit`
  /// sales regardless of date (useful for viewing recent history for a gas station).
  Future<List<Map<String, dynamic>>> getFuelSalesHistory(
      {DateTime? start, DateTime? end, int limit = 100}) async {
    if (_businessId == null) return [];

    try {
      final sales = await _salesRepo.fetchSales(
        businessId: _businessId,
        start: start,
        end: end,
      );
      final history = await _calculateFuelSalesHistorySnapshot(sales);
      if (history.length > limit) {
        return history.sublist(0, limit);
      }
      return history;
    } catch (e) {
      debugPrint('Error fetching fuel sales history: $e');
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> watchFuelSalesHistory({
    DateTime? start,
    DateTime? end,
    int limit = 100,
  }) async* {
    if (_businessId == null) {
      yield [];
      return;
    }

    while (true) {
      yield await getFuelSalesHistory(start: start, end: end, limit: limit);
      await Future.delayed(_fuelMetricsPollInterval);
    }
  }

  // Load stores from the stores API
  Future<void> loadStores() async {
    if (_businessId == null) return;

    try {
      final data = await _api.get('/stores/$_businessId');
      final list = (data as List?) ?? [];
      _stores = list
          .map((raw) => StoreLocation.fromJson(raw as Map<String, dynamic>))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading stores: $e');
    }
  }

  // Promotions: no backend support yet.
  // TODO(migration): add a promotions table + /api/promotions routes on the
  // custom backend, then wire this up like loadStores.
  Future<void> loadPromotions() async {
    if (_businessId == null) return;

    try {
      _promotions = [];
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading promotions: $e');
    }
  }

  // Store Management
  // Add store to Firestore
  Future<void> addStore(
      {required String name,
      required String location,
      String? address,
      String? phone}) async {
    if (_businessId == null) return;

    try {
      // Enforce Tier 1 businesses can only have one store
      try {
        final business = await Supabase.instance.client
            .from('businesses')
            .select('subscription_tier')
            .eq('id', _businessId as Object)
            .maybeSingle();
        final subscriptionTier =
            (business?['subscription_tier'] ?? '').toString().toLowerCase();
        if (subscriptionTier == 'tier1' ||
            subscriptionTier == 'basic' ||
            subscriptionTier == 'standard') {
          if (_stores.isEmpty) {
            await loadStores();
          }
          if (_stores.isNotEmpty) {
            _errorMessage =
                'Your subscription allows only one store. Upgrade to add more stores.';
            notifyListeners();
            return;
          }
        }
      } catch (e) {
        // If we cannot determine subscription tier, fall back to permissive behavior
        debugPrint(
            'Warning: could not verify subscription tier before adding store: $e');
      }

      await _api.post('/stores/$_businessId', body: {
        'name': name,
        'location': location,
        'address': address,
        'phone': phone,
      });

      await loadStores();
    } catch (e) {
      _errorMessage = 'Failed to add store: $e';
      notifyListeners();
      debugPrint('Error adding store: $e');
    }
  }

  // Update store via the stores API
  Future<void> updateStore(String storeId,
      {required String name,
      required String location,
      String? address,
      String? phone}) async {
    if (_businessId == null) return;

    try {
      await _api.put('/stores/$_businessId/$storeId', body: {
        'name': name,
        'location': location,
        'address': address,
        'phone': phone,
      });

      await loadStores();
    } catch (e) {
      _errorMessage = 'Failed to update store: $e';
      notifyListeners();
      debugPrint('Error updating store: $e');
    }
  }

  // Delete store via the stores API
  Future<void> deleteStore(String storeId) async {
    if (_businessId == null) return;

    try {
      await _api.delete('/stores/$_businessId/$storeId');

      await loadStores();
    } catch (e) {
      _errorMessage = 'Failed to delete store: $e';
      notifyListeners();
      debugPrint('Error deleting store: $e');
    }
  }

  // Add product via the inventory API
  Future<void> addProduct(Product product, {String? storeId}) async {
    if (_businessId == null) return;

    try {
      final data = product.toJson();
      data['businessId'] = _businessId;
      if (storeId != null && storeId.isNotEmpty) data['store_id'] = storeId;

      final created = await _inventoryRepo.addInventory(data);
      final newId = (created is Map ? created['id'] : null)?.toString() ?? '';

      await _logProductActivity(
        productId: newId,
        action: 'created',
        productName: product.name,
        changes: data,
        storeId: storeId,
      );

      await loadProducts(storeId: storeId, forceRefresh: true);
    } catch (e) {
      _errorMessage = 'Failed to add product: $e';
      notifyListeners();
      debugPrint('Error adding product: $e');
    }
  }

  // Update product via the inventory API
  Future<void> updateProduct(String productId, Product product,
      {String? storeId}) async {
    if (_businessId == null) return;

    try {
      final updateData = product.toJson();
      updateData['businessId'] = _businessId;
      if (storeId != null && storeId.isNotEmpty) {
        updateData['store_id'] = storeId;
      }

      await _inventoryRepo.updateInventory(productId, updateData);

      await _logProductActivity(
        productId: productId,
        action: 'updated',
        productName: product.name,
        changes: updateData,
        storeId: storeId,
      );

      await loadProducts(storeId: storeId, forceRefresh: true);
    } catch (e) {
      _errorMessage = 'Failed to update product: $e';
      notifyListeners();
      debugPrint('Error updating product: $e');
    }
  }

  // Delete product via the inventory API
  Future<void> deleteProduct(String productId, {String? storeId}) async {
    if (_businessId == null) return;

    try {
      final product = _products.firstWhere(
        (p) => p.id == productId,
        orElse: () => Product(
          id: productId,
          name: 'Unknown product',
          price: 0,
          stock: 0,
          category: 'Unknown',
        ),
      );

      await _inventoryRepo.deleteInventoryForBusiness(_businessId!, productId);

      await _logProductActivity(
        productId: productId,
        action: 'deleted',
        productName: product.name,
        storeId: storeId,
      );

      await loadProducts(storeId: storeId, forceRefresh: true);
    } catch (e) {
      _errorMessage = 'Failed to delete product: $e';
      notifyListeners();
      debugPrint('Error deleting product: $e');
    }
  }

  Future<void> _logProductActivity({
    required String productId,
    required String action,
    required String productName,
    Map<String, dynamic>? changes,
    String? storeId,
  }) async {
    if (_businessId == null || _businessId!.isEmpty || productId.isEmpty) {
      return;
    }

    try {
      await _inventoryRepo.addHistoryEntry(_businessId!, productId, {
        'change_type': action,
        'notes': productName,
        'product_name': productName,
        'changes': changes ?? const <String, dynamic>{},
        'store_id': storeId,
      });
    } catch (e) {
      debugPrint('[RetailProvider] Product activity log failed: $e');
    }
  }

  // Suppliers: no backend support yet.
  // TODO(migration): add a suppliers table + /api/suppliers routes on the
  // custom backend, then wire this up like addProduct.
  Future<void> addSupplier(Supplier supplier) async {
    if (_businessId == null) return;

    try {
      await loadSuppliers();
    } catch (e) {
      _errorMessage = 'Failed to add supplier: $e';
      notifyListeners();
      debugPrint('Error adding supplier: $e');
    }
  }

  // Promotions: no backend support yet.
  // TODO(migration): add a promotions table + /api/promotions routes on the
  // custom backend, then wire this up like addProduct.
  Future<void> addPromotion(Promotion promotion) async {
    if (_businessId == null) return;

    try {
      await loadPromotions();
    } catch (e) {
      _errorMessage = 'Failed to add promotion: $e';
      notifyListeners();
      debugPrint('Error adding promotion: $e');
    }
  }

  // Cart management methods
  void addToCart(String productId, {int qty = 1, String? pricingMode}) {
    if (qty <= 0) return;
    _ensureActiveCart();
    final existingMode = _activePricingModes()[productId];
    final resolvedMode = pricingMode == 'wholesale' || pricingMode == 'retail'
        ? pricingMode!
        : (existingMode ?? activeCartPricingMode);
    _cart.update(productId, (v) => v + qty, ifAbsent: () => qty);
    _activePricingModes()[productId] = resolvedMode;
    _syncActiveCartSnapshot();
    _queueCartCacheSave();
    notifyListeners();
  }

  /// Remove product from cart
  void removeFromCart(String productId) {
    _cart.remove(productId);
    _activePricingModes().remove(productId);
    _syncActiveCartSnapshot();
    _queueCartCacheSave();
    notifyListeners();
  }

  /// Find product by its barcode (returns null if not found)
  Product? getProductByBarcode(String barcode) {
    final code = barcode.trim();
    if (code.isEmpty) return null;

    try {
      return _products.firstWhere((p) => (p.barcode ?? '').trim() == code);
    } catch (_) {
      // Fallback: try matching by id or exact name
      try {
        return _products.firstWhere(
            (p) => p.id == code || p.name.toLowerCase() == code.toLowerCase());
      } catch (_) {
        return null;
      }
    }
  }

  /// Add to cart using a scanned barcode; returns true when product was found and added
  bool addByBarcode(String barcode, {int qty = 1}) {
    final p = getProductByBarcode(barcode);
    if (p != null) {
      addToCart(p.id, qty: qty);
      return true;
    }
    return false;
  }

  void updateQty(String productId, int qty) {
    if (qty <= 0) {
      _cart.remove(productId);
      _activePricingModes().remove(productId);
    } else {
      _cart[productId] = qty;
    }
    _syncActiveCartSnapshot();
    _queueCartCacheSave();
    notifyListeners();
  }

  void clearCart() {
    _resetActiveCartState();
    _queueCartCacheSave();
    notifyListeners();
  }

  /// Get the pricing mode for a product in cart ('retail' or 'wholesale')
  String getPricingModeForCartItem(String productId) {
    return _activePricingModes()[productId] ?? activeCartPricingMode;
  }

  /// Toggle pricing mode between retail and wholesale for a cart item
  void togglePricingModeForCartItem(String productId) {
    final currentMode = getPricingModeForCartItem(productId);
    final newMode = currentMode == 'wholesale' ? 'retail' : 'wholesale';
    setPricingModeForCartItem(productId, newMode);
  }

  /// Set pricing mode for a cart item
  void setPricingModeForCartItem(String productId, String mode) {
    if ((mode != 'wholesale' && mode != 'retail') ||
        !_cart.containsKey(productId)) {
      return;
    }
    _activePricingModes()[productId] = mode;
    _syncActiveCartSnapshot();
    _queueCartCacheSave();
    notifyListeners();
  }

  void setActiveCartPricingMode(
    String mode, {
    bool applyToExistingItems = false,
  }) {
    if (mode != 'wholesale' && mode != 'retail') return;
    _ensureActiveCart();
    _cartDefaultPricingModes[_activeCartId] = mode;
    if (applyToExistingItems) {
      final pricingModes = _activePricingModes();
      for (final productId in _cart.keys) {
        pricingModes[productId] = mode;
      }
    }
    _syncActiveCartSnapshot();
    _queueCartCacheSave();
    notifyListeners();
  }

  /// Get the effective price for a product considering its pricing mode
  double getEffectivePriceForCartItem(String productId) {
    final product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => Product(
        id: productId,
        name: 'Unknown',
        price: 0,
        stock: 0,
        category: 'Unknown',
      ),
    );

    final mode = getPricingModeForCartItem(productId);

    // If wholesale mode is selected and product has wholesale pricing, use it
    if (mode == 'wholesale' &&
        product.hasWholesalePricing &&
        product.wholesalePrice != null) {
      return product.wholesalePrice!;
    }

    // Otherwise use retail price
    return product.price;
  }

  Product _findProductForCart(String productId) {
    return _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => Product(
        id: productId,
        name: 'Unknown',
        price: 0,
        stock: 0,
        category: 'Unknown',
      ),
    );
  }

  bool _usesWholesaleSaleUnit(Product product, String mode) {
    return mode == 'wholesale' &&
        product.hasWholesalePricing &&
        product.wholesalePrice != null;
  }

  String getEffectiveSaleUnitForCartItem(String productId) {
    final product = _findProductForCart(productId);
    final mode = getPricingModeForCartItem(productId);
    if (_usesWholesaleSaleUnit(product, mode)) {
      return product.resolvedSaleUnit;
    }
    return product.unit;
  }

  double getEffectiveSaleUnitMultiplierForCartItem(String productId) {
    final product = _findProductForCart(productId);
    final mode = getPricingModeForCartItem(productId);
    if (_usesWholesaleSaleUnit(product, mode)) {
      return product.resolvedSaleUnitMultiplier;
    }
    return 1.0;
  }

  // Checkout with Firestore updates
  // Returns true if the sale was stored offline (queued), false when successfully uploaded
  Future<bool> checkout({
    required String paymentMethod,
    double tax = 0.0,
    double discount = 0.0,
    String? workerId,
    String? workerName,
    String? customerId,
    String? customerEmail,
    String? customerName,
    String? storeId,
    Map<String, double>? priceOverrides,
  }) async {
    if (_businessId == null) return false;
    final activeCartEntries = Map<String, int>.from(_cart);
    if (activeCartEntries.isEmpty) return false;

    try {
      // Validate stock availability before proceeding
      for (final entry in activeCartEntries.entries) {
        final product = _findProductForCart(entry.key);
        final stockReduction =
            getEffectiveSaleUnitMultiplierForCartItem(entry.key) * entry.value;
        if (product.stock < stockReduction) {
          throw Exception(
              'Insufficient stock for ${product.name}. Available: ${product.stock}, Required: $stockReduction');
        }
      }

      // Compute subtotal applying any price overrides and pricing modes
      double subtotal = 0.0;
      for (final entry in activeCartEntries.entries) {
        // Use price overrides first, otherwise use effective price based on pricing mode
        final unitPrice =
            priceOverrides != null && priceOverrides.containsKey(entry.key)
                ? priceOverrides[entry.key]!
                : getEffectivePriceForCartItem(entry.key);
        subtotal += unitPrice * entry.value;
      }

      final taxAmount = subtotal * (tax / 100);
      double totalAmount = subtotal + taxAmount - discount;

      // Create sale record for upload
      final saleData = {
        'cartId': _activeCartId,
        'cartLabel': activeCartLabel,
        'items': activeCartEntries.entries.map((e) {
          final product = _findProductForCart(e.key);
          final unitPrice =
              priceOverrides != null && priceOverrides.containsKey(e.key)
                  ? priceOverrides[e.key]!
                  : getEffectivePriceForCartItem(e.key);
          final pricingMode = getPricingModeForCartItem(e.key);
          final saleUnit = getEffectiveSaleUnitForCartItem(e.key);
          final saleUnitMultiplier =
              getEffectiveSaleUnitMultiplierForCartItem(e.key);
          return {
            'productId': e.key,
            'productName': product.name,
            'name': product.name,
            'quantity': e.value,
            'unitPrice': unitPrice,
            'price': unitPrice,
            'cost': product.cost,
            'costPrice': product.cost,
            'pricingMode': pricingMode,
            'inventoryUnit': product.unit,
            'saleUnit': saleUnit,
            'saleUnitMultiplier': saleUnitMultiplier,
            'inventoryQuantity': saleUnitMultiplier * e.value,
            'total': unitPrice * e.value,
          };
        }).toList(),
        'subtotal': subtotal,
        'tax': taxAmount,
        'taxRate': tax,
        'discount': discount,
        'totalAmount': totalAmount,
        'finalAmount': totalAmount,
        'paymentMethod': paymentMethod,
        'category': 'General',
        'createdAt': DateTime.now().toIso8601String(),
        if (customerId != null && customerId.isNotEmpty)
          'customerId': customerId,
        if (customerEmail != null) 'customerEmail': customerEmail,
        if (customerName != null) 'customerName': customerName,
        if (storeId != null && storeId.isNotEmpty) 'storeId': storeId,
      };

      // Add worker information if provided
      if (workerId != null && workerId.isNotEmpty) {
        saleData['workerId'] = workerId;
        saleData['workerName'] = workerName ?? 'Unknown';
        debugPrint(
            '[Checkout] Recording sale for worker: $workerName (ID: $workerId)');
      }

      // Check connectivity up front so we can reliably tell the cashier
      // "this sale is offline and pending sync" instead of guessing from a
      // failed request later.
      final hasNetwork = await ConnectivityHelper.hasInternetConnection();
      if (!hasNetwork) {
        debugPrint('[Checkout] No network detected, saving sale offline');
        return await _saveSaleOffline(
          activeCartEntries: activeCartEntries,
          totalAmount: totalAmount,
          taxAmount: taxAmount,
          discount: discount,
          paymentMethod: paymentMethod,
          customerId: customerId,
          workerId: workerId,
          workerName: workerName,
          storeId: storeId,
          priceOverrides: priceOverrides,
        );
      }

      // Try to write to the backend first
      try {
        final saleId = 'SALE-${DateTime.now().millisecondsSinceEpoch}';
        final createdBy = workerId?.isNotEmpty == true
            ? workerId!
            : (Supabase.instance.client.auth.currentUser?.id ?? '');

        final apiItems = (saleData['items'] as List).map((raw) {
          final item = raw as Map<String, dynamic>;
          return {
            'product_id': item['productId'],
            'product_name': item['productName'],
            'quantity': item['quantity'],
            'unit_price': item['unitPrice'],
            'discount': 0,
            'total': item['total'],
            'pricing_mode': item['pricingMode'],
            'inventory_unit': item['inventoryUnit'],
            'sale_unit': item['saleUnit'],
            'sale_unit_multiplier': item['saleUnitMultiplier'],
          };
        }).toList();

        final created = await _salesRepo.createSale({
          'id': saleId,
          'businessId': _businessId,
          'customer_id': customerId,
          'store_id': storeId,
          'worker_id': workerId,
          'worker_name': workerName,
          'total_amount': subtotal,
          'discount_amount': discount,
          'tax_amount': taxAmount,
          'final_amount': totalAmount,
          'payment_method': paymentMethod,
          'status': 'completed',
          'created_by': createdBy,
          'sale_type': 'retail',
          'items': apiItems,
        });
        final orderId = (created is Map ? created['id']?.toString() : null) ??
            saleId;

        // The backend's sale-creation route already decrements inventory
        // atomically server-side (routes/sales.js), so only mirror the
        // reduction into the in-memory product list here for immediate POS
        // UI feedback — writing it again client-side would double-decrement.
        for (final entry in activeCartEntries.entries) {
          final product = _findProductForCart(entry.key);

          final stockReduction =
              getEffectiveSaleUnitMultiplierForCartItem(entry.key) *
                  entry.value;
          final newQuantity =
              (product.stock - stockReduction).clamp(0.0, 999999.0);

          final idx = _products.indexWhere((p) => p.id == product.id);
          if (idx != -1) {
            _products[idx].stock = newQuantity;
          }

          // Notify if stock is low (use integer for notifications)
          if (newQuantity < 10) {
            await BusinessNotificationManager.instance.notifyLowStock(
              businessId: _businessId!,
              itemName: product.name,
              currentStock: newQuantity.toInt(),
              reorderPoint: 10,
            );
          }
        }

        if (customerId != null && customerId.isNotEmpty) {
          try {
            await savePurchaseToCustomerHistory(
              customerId,
              {
                'saleId': orderId,
                'orderId': orderId,
                'items': saleData['items'],
                'subtotal': subtotal,
                'tax': taxAmount,
                'discount': discount,
                'totalAmount': totalAmount,
                'paymentMethod': paymentMethod,
                'customerName': customerName,
                'customerEmail': customerEmail,
              },
            );
          } catch (e) {
            debugPrint(
                '[RetailProvider] Error saving customer purchase history: $e');
          }
        }

        _resetActiveCartState();
        _queueCartCacheSave();
        await loadProducts(); // Refresh products
        notifyListeners();

        // Send sale completed notification
        await BusinessNotificationManager.instance.notifySaleCompleted(
          businessId: _businessId!,
          customerName: 'Customer',
          amount: totalAmount,
          paymentMethod: paymentMethod,
        );

        // Send notification for large sales
        if (totalAmount > 100) {
          await BusinessNotificationManager.instance.notifyLargeSale(
            businessId: _businessId!,
            customerName: 'Customer',
            amount: totalAmount,
          );
        }

        // Clear cart and refresh
        _resetActiveCartState();
        _queueCartCacheSave();
        await loadProducts();
        notifyListeners();

        return false; // uploaded successfully
      } catch (e) {
        // Backend write failed — fall back to local DB and queue for sync
        debugPrint('[Checkout] Backend write failed, saving locally: $e');
        return await _saveSaleOffline(
          activeCartEntries: activeCartEntries,
          totalAmount: totalAmount,
          taxAmount: taxAmount,
          discount: discount,
          paymentMethod: paymentMethod,
          customerId: customerId,
          workerId: workerId,
          workerName: workerName,
          storeId: storeId,
          priceOverrides: priceOverrides,
        );
      }
    } catch (e) {
      debugPrint('[Checkout] Error during checkout: $e');
      rethrow;
    }
  }

  /// Persists a sale to the local database and queues it for sync when
  /// connectivity returns. Used both when we already know we're offline and
  /// as a fallback if a Firestore write unexpectedly fails.
  Future<bool> _saveSaleOffline({
    required Map<String, int> activeCartEntries,
    required double totalAmount,
    required double taxAmount,
    required double discount,
    required String paymentMethod,
    String? customerId,
    String? workerId,
    String? workerName,
    String? storeId,
    Map<String, double>? priceOverrides,
  }) async {
    final dbHelper = DatabaseHelper.instance;
    final saleId = 'SALE-${DateTime.now().millisecondsSinceEpoch}';

    final localSale = {
      'id': saleId,
      'businessId': _businessId!,
      'customerId': customerId,
      'totalAmount': totalAmount,
      'discountAmount': discount,
      'taxAmount': taxAmount,
      'finalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'status': 'completed',
      'notes': null,
      'createdBy': workerId ?? '',
      'createdAt': DateTime.now().toIso8601String(),
      'syncStatus': 'pending',
      if (workerId != null && workerId.isNotEmpty) 'workerId': workerId,
      if (workerId != null && workerId.isNotEmpty)
        'workerName': workerName ?? 'Unknown',
      if (storeId != null && storeId.isNotEmpty) 'storeId': storeId,
    };

    // Insert sale
    await dbHelper.insert('sales', localSale);

    try {
      await _saveSaleOfflineItems(
        dbHelper: dbHelper,
        saleId: saleId,
        activeCartEntries: activeCartEntries,
        priceOverrides: priceOverrides,
      );
    } catch (e) {
      // The sale row exists but its items don't (or only partially do) —
      // syncing it later would create an item-less transaction in
      // Firestore, same as the bug this whole fix started from. Better to
      // remove the half-written record and surface the failure clearly so
      // the cashier knows to retry, rather than silently queue something
      // broken.
      debugPrint(
          '[Checkout] Offline item save failed, rolling back local sale $saleId: $e');
      try {
        await dbHelper
            .delete('sale_items', where: 'saleId = ?', whereArgs: [saleId]);
        await dbHelper.delete('sales', where: 'id = ?', whereArgs: [saleId]);
      } catch (_) {}
      rethrow;
    }

    // Add to sync queue
    await dbHelper.addToSyncQueue(
        entityType: 'sale',
        entityId: saleId,
        action: 'create',
        data: localSale);

    // Try to trigger a background sync (no-op if still offline)
    try {
      final syncService = SyncService();
      await syncService.syncSales();
    } catch (_) {}

    _resetActiveCartState();
    _queueCartCacheSave();
    await loadProducts();
    notifyListeners();

    return true; // saved offline
  }

  Future<void> _saveSaleOfflineItems({
    required DatabaseHelper dbHelper,
    required String saleId,
    required Map<String, int> activeCartEntries,
    Map<String, double>? priceOverrides,
  }) async {
    for (final e in activeCartEntries.entries) {
      final itemId = DateTime.now().millisecondsSinceEpoch.toString() + e.key;
      final product = _findProductForCart(e.key);
      final pricingMode = getPricingModeForCartItem(e.key);
      final saleUnit = getEffectiveSaleUnitForCartItem(e.key);
      final saleUnitMultiplier =
          getEffectiveSaleUnitMultiplierForCartItem(e.key);
      final item = {
        'id': itemId,
        'saleId': saleId,
        'productId': e.key,
        'productName': product.name,
        'quantity': e.value,
        'unitPrice': priceOverrides != null && priceOverrides.containsKey(e.key)
            ? priceOverrides[e.key]!
            : getEffectivePriceForCartItem(e.key),
        'pricingMode': pricingMode,
        'inventoryUnit': product.unit,
        'saleUnit': saleUnit,
        'saleUnitMultiplier': saleUnitMultiplier,
        'inventoryQuantity': saleUnitMultiplier * e.value,
        'discount': 0.0,
        'total': (priceOverrides != null && priceOverrides.containsKey(e.key)
                ? priceOverrides[e.key]!
                : getEffectivePriceForCartItem(e.key)) *
            e.value,
      };
      await dbHelper.insert('sale_items', item);

      // Update local inventory record
      final inv = await dbHelper.query(
        'inventory',
        where: '(id = ? OR barcode = ? OR name = ?) AND businessId = ?',
        whereArgs: [
          e.key,
          product.barcode ?? '',
          product.name,
          _businessId,
        ],
        limit: 1,
      );
      if (inv.isNotEmpty) {
        final currentQty = (inv.first['quantity'] as num).toDouble();
        final newQty =
            (currentQty - (saleUnitMultiplier * e.value)).clamp(0, 999999);
        await dbHelper.update(
          'inventory',
          {
            'quantity': newQty,
            'stock': newQty,
            'syncStatus': 'pending',
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: '(id = ? OR barcode = ? OR name = ?) AND businessId = ?',
          whereArgs: [
            e.key,
            product.barcode ?? '',
            product.name,
            _businessId,
          ],
        );
      } else {
        await dbHelper.insert('inventory', {
          'id': e.key,
          'businessId': _businessId!,
          'name': product.name,
          'unitPrice': product.price,
          'barcode': product.barcode,
          'quantity':
              (0 - (saleUnitMultiplier * e.value)).toDouble().clamp(0, 999999),
          'stock':
              (0 - (saleUnitMultiplier * e.value)).toDouble().clamp(0, 999999),
          'createdAt': DateTime.now().toIso8601String(),
          'syncStatus': 'pending',
        });
      }
    }
  }

  String _pendingPumpSalesKey(String businessId) =>
      '$_pendingPumpSalesKeyPrefix$businessId';

  Future<List<Map<String, dynamic>>> _loadPendingPumpSales(
    String businessId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingPumpSalesKey(businessId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _savePendingPumpSales(
    String businessId,
    List<Map<String, dynamic>> sales,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingPumpSalesKey(businessId), jsonEncode(sales));
  }

  Future<void> _queuePendingPumpSale(
    String businessId,
    Map<String, dynamic> pendingSale,
  ) async {
    final pending = await _loadPendingPumpSales(businessId);
    final orderId = pendingSale['orderId']?.toString() ?? '';
    final existingIndex =
        pending.indexWhere((sale) => sale['orderId']?.toString() == orderId);
    if (existingIndex == -1) {
      pending.add(pendingSale);
    } else {
      pending[existingIndex] = pendingSale;
    }
    await _savePendingPumpSales(businessId, pending);
  }

  // The backend's sale-creation route accepts an optional client-supplied
  // id and, if a sale with that id already exists, returns it as-is instead
  // of re-inserting (see routes/sales.js) — and it decrements inventory
  // atomically as part of creating the sale. That makes this retry safe to
  // call repeatedly: a sale that already synced (and already had its
  // inventory decremented) on a previous attempt is just returned again,
  // never re-applied.
  Future<void> _syncPendingPumpSale(
    String businessId,
    Map<String, dynamic> pendingSale,
  ) async {
    final orderId = pendingSale['orderId']?.toString() ?? '';
    final productId = pendingSale['productId']?.toString() ?? '';
    final quantity = (pendingSale['quantity'] as num?)?.toDouble() ?? 0.0;
    if (orderId.isEmpty || productId.isEmpty || quantity <= 0) {
      throw Exception('Invalid pending pump sale');
    }

    final saleData = Map<String, dynamic>.from(
      pendingSale['saleData'] as Map<String, dynamic>? ?? {},
    );
    final items = (saleData['items'] as List<dynamic>?) ?? [];
    final apiItems = items.map((raw) {
      final item = raw as Map<String, dynamic>;
      return {
        'product_id': item['productId'],
        'product_name': item['productName'],
        'quantity': item['quantity'],
        'unit_price': item['unitPrice'],
        'discount': 0,
        'total': item['total'],
        'sale_unit_multiplier': 1,
      };
    }).toList();

    final workerId = saleData['workerId']?.toString() ?? '';
    final createdBy = workerId.isNotEmpty
        ? workerId
        : (Supabase.instance.client.auth.currentUser?.id ?? '');

    await _salesRepo.createSale({
      'id': orderId,
      'businessId': businessId,
      'store_id': saleData['storeId'],
      'worker_id': saleData['workerId'],
      'worker_name': saleData['workerName'],
      'total_amount': saleData['subtotal'] ?? saleData['totalAmount'] ?? 0,
      'discount_amount': saleData['discount'] ?? 0,
      'tax_amount': saleData['tax'] ?? 0,
      'final_amount': saleData['totalAmount'] ?? saleData['total'] ?? 0,
      'payment_method': saleData['paymentMethod'] ?? 'Cash',
      'status': 'completed',
      'created_by': createdBy,
      'sale_type': 'fuel',
      'items': apiItems,
    });
  }

  Future<int> syncPendingPumpSales() async {
    final businessId = _businessId;
    if (businessId == null || businessId.isEmpty) return 0;
    final pending = await _loadPendingPumpSales(businessId);
    if (pending.isEmpty) return 0;

    final remaining = <Map<String, dynamic>>[];
    var synced = 0;
    for (final sale in pending) {
      try {
        await _syncPendingPumpSale(businessId, sale);
        synced += 1;
      } catch (e) {
        debugPrint('[RetailProvider] Pending pump sale sync failed: $e');
        remaining.add(sale);
      }
    }
    await _savePendingPumpSales(businessId, remaining);
    if (synced > 0) {
      await loadProducts(forceRefresh: true);
      notifyListeners();
    }
    return synced;
  }

  /// Fuel / Gas sale flow: sell fuel by amount or by volume (litres/kg)
  /// Returns the created sale document id and the sale map for post-sale actions.
  Future<Map<String, dynamic>> fuelSale({
    required String productId,
    double? amountPaid,
    double? quantity,
    required String paymentMethod,
    String? workerId,
    String? workerName,
    String? customerEmail,
    String? customerName,
    String? storeId,
    String? pumpId,
    String? pumpNumber,
    String? pumpName,
  }) async {
    if (_businessId == null) throw Exception('No business selected');

    // Find product info
    final product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => Product(
          id: productId,
          name: 'Unknown',
          price: 0,
          stock: 0,
          category: 'Unknown'),
    );

    final unitPrice = (product.price).toDouble();
    if (unitPrice <= 0) throw Exception('Product has invalid unit price');

    // Compute missing value
    double qty = (quantity ?? 0.0).toDouble();
    double paid = (amountPaid ?? 0.0).toDouble();

    final unit = product.unit.toString().toLowerCase();

    if (paid > 0 && qty <= 0) {
      var rawQty = paid / unitPrice;
      // If selling cylinders, only whole units allowed
      if (unit == 'cyl' || unit == 'cylinder') {
        rawQty = rawQty.floorToDouble();
        paid = double.parse((rawQty * unitPrice).toStringAsFixed(2));
      }
      qty = rawQty;
    } else if (qty > 0 && paid <= 0) {
      // If cylinders, enforce integer qty
      if (unit == 'cyl' || unit == 'cylinder') {
        qty = qty.toInt().toDouble();
      }
      paid = qty * unitPrice;
    }

    // Round quantity and paid appropriately
    if (unit == 'cyl' || unit == 'cylinder') {
      qty = qty.toInt().toDouble();
    } else {
      qty = double.parse(qty.toStringAsFixed(3));
    }
    paid = double.parse(paid.toStringAsFixed(2));

    // Prevent sales of zero units (e.g., insufficient amount for a cylinder)
    if (qty <= 0) {
      throw Exception('Insufficient amount/quantity to process sale');
    }

    // Ensure we don't oversell stock
    final available = product.stock;
    if (qty > available) {
      qty = available;
      paid = double.parse((qty * unitPrice).toStringAsFixed(2));
    }

    final saleData = {
      'items': [
        {
          'productId': product.id,
          'productName': product.name,
          'quantity': qty,
          'unit': product.unit,
          'unitPrice': unitPrice,
          'total': paid,
        }
      ],
      'subtotal': paid,
      'tax': 0.0,
      'taxRate': 0.0,
      'discount': 0.0,
      'total': paid,
      'totalAmount': paid,
      'paymentMethod': paymentMethod,
      'customerEmail': customerEmail,
      'customerName': customerName,
      'createdAt': DateTime.now().toIso8601String(),
      if (storeId != null && storeId.isNotEmpty) 'storeId': storeId,
      if (pumpId != null && pumpId.isNotEmpty) 'pumpId': pumpId,
      if (pumpNumber != null && pumpNumber.isNotEmpty) 'pumpNumber': pumpNumber,
      if (pumpName != null && pumpName.isNotEmpty) 'pumpName': pumpName,
      'category': 'Fuel',
    };

    // Add worker info
    if (workerId != null && workerId.isNotEmpty) {
      saleData['workerId'] = workerId;
      saleData['workerName'] = workerName ?? 'Unknown';
    }

    final orderId = 'SALE-${DateTime.now().millisecondsSinceEpoch}';
    saleData['id'] = orderId;
    saleData['orderId'] = orderId;
    saleData['status'] = 'completed';
    saleData['saleStatus'] = 'completed';
    saleData['paymentStatus'] = 'paid';

    final newQty =
        (product.stock.toDouble() - qty).clamp(0.0, 999999.0).toDouble();

    var saleWrittenOnline = false;

    // Shared by both the "we already know we're offline" and the "the
    // Firestore write unexpectedly failed" paths, so the pump sale is
    // queued locally the same way either way.
    Future<Map<String, dynamic>> queueFuelSaleOffline() async {
      final queuedAt = DateTime.now();
      final offlineSaleData = Map<String, dynamic>.from(saleData);
      offlineSaleData['createdAt'] = queuedAt.toIso8601String();
      offlineSaleData['updatedAt'] = queuedAt.toIso8601String();
      offlineSaleData['offlineQueued'] = true;
      offlineSaleData['offlineQueuedAt'] = queuedAt.toIso8601String();

      await _queuePendingPumpSale(_businessId!, {
        'orderId': orderId,
        'productId': product.id,
        'quantity': qty,
        'saleWrittenOnline': saleWrittenOnline,
        'queuedAt': queuedAt.toIso8601String(),
        'saleData': offlineSaleData,
      });

      final productIndex = _products.indexWhere((p) => p.id == product.id);
      if (productIndex != -1) {
        _products[productIndex].stock = newQty;
      }
      notifyListeners();

      return {
        ...offlineSaleData,
        'id': orderId,
        'total': paid,
        'quantity': qty,
        'offlineQueued': true,
        'syncStatus': 'pending',
        'status': 'completed',
        'saleStatus': 'completed',
        'paymentStatus': 'paid',
      };
    }

    // Check connectivity up front so a genuinely offline sale reliably
    // queues instead of only finding out via a failed request later.
    final hasNetwork = await ConnectivityHelper.hasInternetConnection();
    if (!hasNetwork) {
      debugPrint(
          '[RetailProvider.fuelSale] No network detected, queueing sale offline');
      return await queueFuelSaleOffline();
    }

    try {
      final createdBy = (workerId?.isNotEmpty == true)
          ? workerId!
          : (Supabase.instance.client.auth.currentUser?.id ?? '');
      // The backend decrements inventory atomically as part of creating the
      // sale (routes/sales.js), so no separate _writeInventoryStock call is
      // needed here.
      await _salesRepo.createSale({
        'id': orderId,
        'businessId': _businessId,
        'store_id': storeId,
        'worker_id': workerId,
        'worker_name': workerName,
        'total_amount': paid,
        'discount_amount': 0,
        'tax_amount': 0,
        'final_amount': paid,
        'payment_method': paymentMethod,
        'status': 'completed',
        'created_by': createdBy,
        'sale_type': 'fuel',
        'items': [
          {
            'product_id': product.id,
            'product_name': product.name,
            'quantity': qty,
            'unit_price': unitPrice,
            'discount': 0,
            'total': paid,
            'sale_unit_multiplier': 1,
          },
        ],
      });
      saleWrittenOnline = true;
      final productIndex = _products.indexWhere((p) => p.id == product.id);
      if (productIndex != -1) {
        _products[productIndex].stock = newQty;
        notifyListeners();
      }
      unawaited(syncPendingPumpSales());
    } catch (e) {
      return await queueFuelSaleOffline();
    }

    // Notify if low stock
    if (newQty < 10) {
      try {
        await BusinessNotificationManager.instance.notifyLowStock(
          businessId: _businessId!,
          itemName: product.name,
          currentStock: newQty.toInt(),
          reorderPoint: 10,
        );
      } catch (e) {
        debugPrint('[RetailProvider] Error notifying low stock: $e');
      }
    }

    // Send sale completed notification
    try {
      await BusinessNotificationManager.instance.notifySaleCompleted(
        businessId: _businessId!,
        customerName: customerName ?? 'Customer',
        amount: paid,
        paymentMethod: paymentMethod,
      );
    } catch (e) {
      debugPrint('[RetailProvider] Error notifying sale completed: $e');
    }

    // Attempt to email owner
    try {
      final businessData = await Supabase.instance.client
              .from('businesses')
              .select('name, email, address, phone')
              .eq('id', _businessId as Object)
              .maybeSingle() ??
          <String, dynamic>{};
      final ownerEmail = (businessData['email'] as String?) ?? '';
      final businessName = (businessData['name'] as String?) ?? 'Your Business';

      if (ownerEmail.isNotEmpty) {
        final items = (saleData['items'] as List<dynamic>).map((it) {
          return {
            'name': it['productName'] ?? it['name'] ?? 'Item',
            'quantity': it['quantity'] ?? 0,
            'unitPrice': it['unitPrice'] ?? 0,
          };
        }).toList();

        final ownerSuccess =
            await _notificationEmailService.sendSalesNotification(
          ownerEmail: ownerEmail,
          businessName: businessName,
          customerName: customerName ?? 'Customer',
          customerEmail: customerEmail ?? '',
          totalAmount: paid,
          items: items.cast<Map<String, dynamic>>(),
          paymentMethod: paymentMethod,
          receiptNumber: orderId,
          businessId: _businessId,
        );

        // Log notification attempt using injected service
        try {
          if (_businessId != null) {
            await _notificationEmailService.logNotificationEvent(
              businessId: _businessId!,
              type: 'sale',
              channel: 'email',
              recipient: ownerEmail,
              success: ownerSuccess,
              orderId: orderId,
            );
          }
        } catch (e) {
          debugPrint('[RetailProvider] Notification log failed: $e');
        }
      }
    } catch (e) {
      debugPrint('[RetailProvider] Error sending owner email: $e');
    }

    // TODO(migration): automatic receipt printing was gated by a
    // per-business `industrySpecificSettings.receiptPrinting` flag and a
    // `receipt_settings/thermalPreferences` doc, neither of which exist on
    // the custom backend's schema yet. Deferred until that settings surface
    // is rebuilt server-side.

    // Refresh local products and notify listeners
    await loadProducts();
    notifyListeners();

    // Return sale info for UI to show receipt/printing actions
    final result = {
      ...saleData,
      'id': orderId,
      'createdAt': DateTime.now(),
      'total': paid,
      'quantity': qty,
      'offlineQueued': false,
      'syncStatus': 'synced',
      'status': 'completed',
      'saleStatus': 'completed',
      'paymentStatus': 'paid',
    };
    return result;
  }

  // Get total sales for a specific worker
  Future<double> getWorkerTotalSales(String workerId, {String? storeId}) async {
    if (_businessId == null) return 0.0;

    try {
      final sales = await _salesRepo.getSales(_businessId!, filters: {
        'workerId': workerId,
        if (storeId != null && storeId.isNotEmpty) 'storeId': storeId,
      });

      double totalSales = 0.0;
      for (final sale in sales) {
        final amount = (sale['final_amount'] as num?)?.toDouble() ?? 0.0;
        totalSales += amount;
      }

      debugPrint(
          '[RetailProvider] Worker $workerId total sales: $totalSales');
      return totalSales;
    } catch (e) {
      debugPrint('[RetailProvider] Error fetching worker sales: $e');
      return 0.0;
    }
  }

  // Get sales count for a specific worker
  Future<int> getWorkerSalesCount(String workerId, {String? storeId}) async {
    if (_businessId == null) return 0;

    try {
      final sales = await _salesRepo.getSales(_businessId!, filters: {
        'workerId': workerId,
        if (storeId != null && storeId.isNotEmpty) 'storeId': storeId,
      });

      debugPrint(
          '[RetailProvider] Worker $workerId sales count: ${sales.length}');
      return sales.length;
    } catch (e) {
      debugPrint('[RetailProvider] Error fetching worker sales count: $e');
      return 0;
    }
  }

  // Get total sales for a date range
  Future<double> getTotalSalesForPeriod({
    required DateTime startDate,
    required DateTime endDate,
    String? storeId,
  }) async {
    if (_businessId == null) return 0.0;

    try {
      final sales = await _salesRepo.fetchSales(
        businessId: _businessId,
        storeId: storeId,
        start: startDate,
        end: endDate,
      );

      double totalSales = 0.0;
      for (final sale in sales) {
        final amount = (sale['final_amount'] as num?)?.toDouble() ?? 0.0;
        totalSales += amount;
      }

      debugPrint(
          '[RetailProvider] Total sales from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}: $totalSales');
      return totalSales;
    } catch (e) {
      debugPrint('[RetailProvider] Error fetching sales for period: $e');
      return 0.0;
    }
  }

  // The backend returns sale rows with snake_case columns (final_amount,
  // created_at, ...), but the UI (and the locally-queued offline sales built
  // in _saveSaleOffline) were written against the old Firestore camelCase
  // shape. Rather than rewrite every screen, mirror the fields it reads
  // under their camelCase aliases too.
  Map<String, dynamic> _normalizeSaleForUi(Map<String, dynamic> sale) {
    final normalized = Map<String, dynamic>.from(sale);
    normalized['totalAmount'] ??= sale['final_amount'] ?? sale['total_amount'];
    normalized['finalAmount'] ??= sale['final_amount'];
    normalized['discountAmount'] ??= sale['discount_amount'];
    normalized['taxAmount'] ??= sale['tax_amount'];
    normalized['paymentMethod'] ??= sale['payment_method'];
    normalized['customerName'] ??= sale['customer_name'];
    normalized['workerName'] ??= sale['worker_name'];
    normalized['storeId'] ??= sale['store_id'];
    normalized['createdAt'] ??= sale['created_at'];
    normalized['returnAmount'] ??= sale['return_amount'];
    normalized['returnedQuantities'] ??= sale['returned_quantities'];
    normalized['hasReturn'] ??= sale['has_return'];

    final items = sale['items'];
    if (items is List) {
      normalized['items'] = items.map((raw) {
        if (raw is! Map) return raw;
        final item = Map<String, dynamic>.from(raw);
        item['productId'] ??= item['product_id'];
        item['productName'] ??= item['product_name'];
        item['unitPrice'] ??= item['unit_price'];
        item['price'] ??= item['unit_price'];
        return item;
      }).toList();
    }
    return normalized;
  }

  // Get sales history with optional limit and range. This is a simple convenience method (non-paged).
  Future<List<Map<String, dynamic>>> getSalesHistory({
    int limit = 50,
    String? storeId,
    DateTime? start,
    DateTime? end,
    String? status,
  }) async {
    if (_businessId == null) return [];

    try {
      final sales = await _salesRepo.getSales(_businessId!, filters: {
        if (storeId != null && storeId.isNotEmpty) 'storeId': storeId,
        if (status != null && status.isNotEmpty && status != 'all')
          'status': status,
        if (start != null) 'startDate': start.toIso8601String(),
        if (end != null) 'endDate': end.toIso8601String(),
      });

      var results = sales
          .cast<Map<String, dynamic>>()
          .map(_normalizeSaleForUi)
          .toList();
      if (results.length > limit) results = results.sublist(0, limit);

      debugPrint('[RetailProvider] Fetched ${results.length} sales records');
      return results;
    } catch (e) {
      debugPrint('[RetailProvider] Error fetching sales history: $e');
      return [];
    }
  }

  // Fetch a single sale by id.
  Future<Map<String, dynamic>?> getSaleById(String saleId) async {
    if (_businessId == null || saleId.trim().isEmpty) return null;

    try {
      final sale = await _salesRepo.getSaleById(saleId);
      if (sale is Map<String, dynamic>) return _normalizeSaleForUi(sale);
      return null;
    } catch (e) {
      debugPrint('[RetailProvider] Error fetching sale $saleId: $e');
      return null;
    }
  }

  /// Sales that only exist locally (queued while offline, or stuck after a
  /// failed sync attempt) so Sales History can show them before they've
  /// actually reached Firestore. Each entry is shaped like a Firestore sale
  /// doc plus a `pendingSync: true` marker and its line items attached.
  Future<List<Map<String, dynamic>>> getLocalPendingSales() async {
    if (_businessId == null) return [];
    try {
      final dbHelper = DatabaseHelper.instance;
      final pending = await dbHelper
          .query('sales', where: 'syncStatus = ?', whereArgs: ['pending']);
      final failed = await dbHelper
          .query('sales', where: 'syncStatus = ?', whereArgs: ['failed']);
      final errored = await dbHelper
          .query('sales', where: 'syncStatus = ?', whereArgs: ['error']);
      final rows = [...pending, ...failed, ...errored]
          .where((r) => r['businessId']?.toString() == _businessId);

      final result = <Map<String, dynamic>>[];
      for (final row in rows) {
        final saleId = row['id']?.toString() ?? '';
        final itemRows = saleId.isEmpty
            ? <Map<String, dynamic>>[]
            : await dbHelper
                .query('sale_items', where: 'saleId = ?', whereArgs: [saleId]);
        result.add({
          ...Map<String, dynamic>.from(row),
          'items': itemRows.map((i) => Map<String, dynamic>.from(i)).toList(),
          'pendingSync': true,
          'syncError': row['syncStatus'] == 'error',
        });
      }
      return result;
    } catch (e) {
      debugPrint('[RetailProvider] Error fetching local pending sales: $e');
      return [];
    }
  }

  // Paged sales fetch — returns sales plus the next page number to request
  // (null once there are no more pages), using the backend's page/limit
  // pagination (routes/sales.js).
  Future<Map<String, dynamic>> getSalesHistoryPage({
    int limit = 50,
    String? storeId,
    DateTime? start,
    DateTime? end,
    String? status,
    int? page,
  }) async {
    if (_businessId == null) {
      return {'sales': <Map<String, dynamic>>[], 'nextPage': null};
    }

    try {
      // A "refunded" filter should also surface partially-refunded sales —
      // otherwise a partial return makes a sale vanish from both the
      // Completed tab (it's no longer that status) and the Refunded tab
      // (its status isn't an exact match). The REST route only takes a
      // single `status` filter, so each value is fetched separately and
      // merged when more than one applies.
      final statusValues = status == 'refunded'
          ? const ['refunded', 'partially_refunded']
          : <String>[
              if (status != null && status.isNotEmpty && status != 'all') status
            ];

      final currentPage = page ?? 1;

      Future<Map<String, dynamic>> fetchPage(String? statusValue) async {
        final response = await _api.get('/sales/$_businessId', query: {
          'page': currentPage,
          'limit': limit,
          if (storeId != null && storeId.isNotEmpty) 'storeId': storeId,
          if (start != null) 'startDate': start.toIso8601String(),
          if (end != null) 'endDate': end.toIso8601String(),
          if (statusValue != null) 'status': statusValue,
        });
        return response as Map<String, dynamic>;
      }

      List<Map<String, dynamic>> sales;
      int? nextPage;

      if (statusValues.length <= 1) {
        final response = await fetchPage(
          statusValues.isEmpty ? null : statusValues.first,
        );
        sales = ((response['data'] as List?) ?? [])
            .cast<Map<String, dynamic>>();
        final pagination = response['pagination'] as Map<String, dynamic>?;
        final totalPages =
            (pagination?['totalPages'] as num?)?.toInt() ?? currentPage;
        nextPage = currentPage < totalPages ? currentPage + 1 : null;
      } else {
        final combined = <String, Map<String, dynamic>>{};
        for (final statusValue in statusValues) {
          final response = await fetchPage(statusValue);
          final data = ((response['data'] as List?) ?? [])
              .cast<Map<String, dynamic>>();
          for (final sale in data) {
            combined[sale['id'].toString()] = sale;
          }
        }
        sales = combined.values.toList()
          ..sort((a, b) => (b['created_at'] ?? '')
              .toString()
              .compareTo((a['created_at'] ?? '').toString()));
        // Multi-status paging isn't exact server-side; a full page from
        // either status is treated as "there might be more".
        nextPage = sales.length >= limit ? currentPage + 1 : null;
      }

      debugPrint(
          '[RetailProvider] Fetched ${sales.length} (paged) sales records');
      return {
        'sales': sales.map(_normalizeSaleForUi).toList(),
        'nextPage': nextPage,
      };
    } catch (e) {
      debugPrint('[RetailProvider] Error fetching paged sales history: $e');
      return {'sales': <Map<String, dynamic>>[], 'nextPage': null};
    }
  }

  // The custom backend doesn't implement Supabase's Realtime protocol, so
  // this is polled the same way InventoryRepositorySupabase.streamInventory
  // is (see that class for the fuller explanation).
  Timer? _salesHistoryPollTimer;
  static const _salesHistoryPollInterval = Duration(seconds: 15);

  void subscribeToSalesHistory(
      void Function(List<Map<String, dynamic>> sales) onUpdate,
      {int limit = 50}) {
    if (_businessId == null) return;
    _salesHistoryPollTimer?.cancel();

    Future<void> poll() async {
      try {
        final sales = await getSalesHistory(limit: limit);
        onUpdate(sales);
      } catch (e) {
        debugPrint('[RetailProvider] Sales subscription error: $e');
      }
    }

    unawaited(poll());
    _salesHistoryPollTimer =
        Timer.periodic(_salesHistoryPollInterval, (_) => poll());
  }

  void unsubscribeFromSalesHistory() {
    _salesHistoryPollTimer?.cancel();
    _salesHistoryPollTimer = null;
  }

  // Get sales count for a date range
  Future<int> getSalesCountForPeriod({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_businessId == null) return 0;

    try {
      final sales = await _salesRepo.fetchSales(
        businessId: _businessId,
        start: startDate,
        end: endDate,
      );

      debugPrint(
          '[RetailProvider] Sales count from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}: ${sales.length}');
      return sales.length;
    } catch (e) {
      debugPrint('[RetailProvider] Error fetching sales count: $e');
      return 0;
    }
  }

  // Sync inventory
  Future<void> syncInventory() async {
    if (_businessId == null) return;

    try {
      await loadProducts();
    } catch (e) {
      _errorMessage = 'Failed to sync inventory: $e';
      notifyListeners();
      debugPrint('Error syncing inventory: $e');
    }
  }

  // Process return/refund via the returns API (routes/returns.js), which
  // atomically records the return, increments the sale's running
  // return_amount and per-item returned_quantities, and flips the sale's
  // status to 'refunded'/'partially_refunded'.
  Future<void> processReturn(Map<String, dynamic> returnData) async {
    try {
      final businessId = returnData['businessId'];

      if (businessId == null) {
        throw Exception('Business ID not found');
      }

      await _api.post('/returns/$businessId', body: {
        'sale_id': returnData['saleId'],
        'reason': returnData['reason'],
        'refund_method': returnData['refundMethod'],
        'refund_amount': returnData['refundAmount'],
        'exclude_from_totals': returnData['excludeFromTotals'] == true,
        'items_returned': returnData['itemsReturned'],
        'processed_by_id': returnData['processedById'],
        'processed_by_name': returnData['processedBy'],
        'entered_by_id': returnData['enteredById'],
        'entered_by_name': returnData['enteredByName'],
        'entered_by_email': returnData['enteredByEmail'],
        'entered_by_role': returnData['enteredByRole'],
        'sale_reference': returnData['saleReference'],
        'sold_by_id': returnData['soldById'],
        'sold_by_name': returnData['soldByName'],
        'customer_id': returnData['customerId'],
        'customer_name': returnData['customerName'],
      });

      debugPrint(
          '[RetailProvider] Return processed: ${returnData['refundAmount']}');
      notifyListeners();
    } catch (e) {
      debugPrint('[RetailProvider] Error processing return: $e');
      rethrow;
    }
  }

  // Add inventory (restore on return)
  Future<void> addInventory(String productId, int quantity) async {
    try {
      if (_businessId == null) return;

      await _api.patch('/inventory/$_businessId/$productId/quantity', body: {
        'quantity': quantity,
        'operation': 'increment',
      });

      final idx = _products.indexWhere((p) => p.id == productId);
      if (idx != -1) {
        _products[idx].stock += quantity;
        notifyListeners();
      }

      debugPrint('[RetailProvider] Inventory restored: $productId +$quantity');
    } catch (e) {
      debugPrint('[RetailProvider] Error restoring inventory: $e');
      rethrow;
    }
  }

  // Record a purchase against the customer's running totals.
  Future<void> savePurchaseToCustomerHistory(
    String customerId,
    Map<String, dynamic> saleData,
  ) async {
    try {
      if (_businessId == null) return;

      final amount = ((saleData['totalAmount'] ??
              saleData['finalAmount'] ??
              saleData['total'] ??
              0) as num)
          .toDouble();

      await _api.patch(
        '/customers/$_businessId/$customerId/purchase',
        body: {'amount': amount},
      );

      debugPrint(
          '[RetailProvider] Purchase saved to customer history: $customerId');
    } catch (e) {
      debugPrint('[RetailProvider] Error saving purchase history: $e');
      rethrow;
    }
  }

  // Link customer to sale
  Future<void> linkCustomerToSale(String saleId, String customerId) async {
    try {
      if (_businessId == null) return;

      await _salesRepo.updateSale(saleId, {
        'businessId': _businessId,
        'customer_id': customerId,
      });

      debugPrint('[RetailProvider] Customer $customerId linked to sale $saleId');
    } catch (e) {
      debugPrint('[RetailProvider] Error linking customer to sale: $e');
      rethrow;
    }
  }

  /// Get today's sales total.
  Future<double> getTodaysSalesTotal() async {
    if (_businessId == null || _businessId!.isEmpty) {
      return 0.0;
    }

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final sales = await _salesRepo.getSales(_businessId!, filters: {
        'startDate': startOfDay.toIso8601String(),
        'endDate': endOfDay.toIso8601String(),
        'status': 'completed',
      });

      double totalSales = 0.0;
      for (final sale in sales) {
        final amount = (sale['final_amount'] as num?)?.toDouble() ?? 0.0;
        totalSales += amount;
      }

      debugPrint('[RetailProvider] Today\'s sales total: $totalSales');
      return totalSales;
    } catch (e) {
      debugPrint('[RetailProvider] Error fetching today\'s sales: $e');
      return 0.0;
    }
  }
}
