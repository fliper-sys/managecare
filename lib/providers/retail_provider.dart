import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/datetime_utils.dart';
import '../core/utils/connectivity_helper.dart';
import '../services/business_notification_manager.dart';
import '../services/notification_and_email_service.dart';
import '../data/local/database_helper.dart';
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
      (wholesalePrice ?? 0) > 0 &&
      (wholesalePrice! - price).abs() > 0.0001;

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw is! Map<String, dynamic>) {
      debugPrint('[RetailProvider] Product.fromFirestore: unexpected data type ${raw.runtimeType} for doc ${doc.id}');
    }
    final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      cost: (data['cost'] ?? 0.0).toDouble(),
      wholesalePrice: (data['wholesalePrice'] as num?)?.toDouble(),
      stock: (data['quantity'] as num?)?.toDouble() ??
          (data['stock'] as num?)?.toDouble() ??
          0.0,
      category: data['category'] ?? 'Uncategorized',
      imageUrl: data['imageUrl'],
      barcode: data['barcode'],
      emoji: data['emoji'] ?? '📦',
      unit: (data['unit'] ?? 'pc').toString(),
      saleUnit: (data['saleUnit'] ?? data['unit'] ?? 'pc').toString(),
      saleUnitMultiplier:
          (data['saleUnitMultiplier'] as num?)?.toDouble() ?? 1.0,
      trackExpiry: data['trackExpiry'] == true,
      expiryDate: parseTimestamp(
        data['expiryDate'] ?? data['expiry'] ?? data['bestBeforeDate'],
      ),
      batchLabel: data['batchLabel']?.toString(),
      shelfLifeDays: (data['shelfLifeDays'] as num?)?.toInt(),
      distributorDiscountPercent: (data['distributorDiscountPercent'] as num?)?.toDouble() ??
          (data['discountPercent'] as num?)?.toDouble() ??
          0.0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'price': price,
      'cost': cost,
      'quantity': stock,
      'category': category,
      'imageUrl': imageUrl,
      'barcode': barcode,
      'emoji': emoji,
      'unit': unit,
      'wholesalePrice': wholesalePrice,
      'saleUnit': resolvedSaleUnit,
      'saleUnitMultiplier': resolvedSaleUnitMultiplier,
      'trackExpiry': trackExpiry,
      if (expiryDate != null) 'expiryDate': expiryDate,
      if (batchLabel != null && batchLabel!.trim().isNotEmpty)
        'batchLabel': batchLabel!.trim(),
      if (shelfLifeDays != null) 'shelfLifeDays': shelfLifeDays,
      'distributorDiscountPercent': distributorDiscountPercent,
      'updatedAt': FieldValue.serverTimestamp(),
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

  factory Supplier.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Supplier(
      id: doc.id,
      name: data['name'] ?? '',
      contact: data['contact'] ?? '',
      email: data['email'] ?? '',
      address: data['address'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'contact': contact,
      'email': email,
      'address': address,
      'updatedAt': FieldValue.serverTimestamp(),
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

  factory StoreLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoreLocation(
      id: doc.id,
      name: data['name'] ?? '',
      location: data['location'] ?? '',
      address: data['address'],
      phone: data['phone'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'location': location,
      'address': address,
      'phone': phone,
      'updatedAt': FieldValue.serverTimestamp(),
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

  factory Promotion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Promotion(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      discountPercentage: (data['discountPercentage'] ?? 0.0).toDouble(),
      startDate: parseTimestamp(data['startDate']),
      endDate: parseTimestamp(data['endDate']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'discountPercentage': discountPercentage,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'updatedAt': FieldValue.serverTimestamp(),
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
  final FirebaseFirestore _firestore;
  final NotificationAndEmailService _notificationEmailService;

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
      final itemCount = entry.value.values.fold<int>(0, (sum, qty) => sum + qty);
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
      {FirebaseFirestore? firestore,
      NotificationAndEmailService? notificationEmailService,
      dynamic printerService})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _notificationEmailService =
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
            final normalized = mode.toString() == 'wholesale'
                ? 'wholesale'
                : 'retail';
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

  Future<void> createCartSession({String? label, bool switchToNew = true}) async {
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

  double _readStockQuantity(Map<String, dynamic> data) {
    final quantityValue = data['quantity'];
    if (quantityValue is num) return quantityValue.toDouble();
    final stockValue = data['stock'];
    if (stockValue is num) return stockValue.toDouble();
    return double.tryParse(
          quantityValue?.toString() ?? stockValue?.toString() ?? '',
        ) ??
        0.0;
  }

  Future<DocumentReference<Map<String, dynamic>>?> _resolveInventoryDocRef(
    Product product, {
    String? storeId,
  }) async {
    if (_businessId == null || _businessId!.isEmpty) return null;

    final inventory = _firestore
        .collection('businesses')
        .doc(_businessId)
        .collection('inventory');

    Future<DocumentReference<Map<String, dynamic>>?> tryDoc(String docId) async {
      if (docId.isEmpty) return null;
      final ref = inventory.doc(docId);
      final snap = await ref.get();
      if (snap.exists) return ref;
      return null;
    }

    final direct = await tryDoc(product.id);
    if (direct != null) return direct;

    final barcode = (product.barcode ?? '').trim();
    if (barcode.isNotEmpty) {
      try {
        final snap = await inventory.where('barcode', isEqualTo: barcode).limit(1).get();
        if (snap.docs.isNotEmpty) return snap.docs.first.reference;
      } catch (_) {}
    }

    final name = product.name.trim();
    if (name.isNotEmpty) {
      try {
        final snap = await inventory.where('name', isEqualTo: name).limit(1).get();
        if (snap.docs.isNotEmpty) return snap.docs.first.reference;
      } catch (_) {}
    }

    if (storeId != null && storeId.isNotEmpty) {
      try {
        final snap = await inventory
            .where('storeId', isEqualTo: storeId)
            .where('name', isEqualTo: name)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) return snap.docs.first.reference;
      } catch (_) {}
    }

    return null;
  }

  Future<void> _writeInventoryStock(
    Product product,
    double newStock, {
    String? storeId,
  }) async {
    final ref = await _resolveInventoryDocRef(product, storeId: storeId);
    if (ref == null) {
      throw Exception('Inventory record not found for ${product.name}');
    }

    await ref.update({
      'quantity': newStock,
      'stock': newStock,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  DateTime _readTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  Product _productFromData(String id, Map<String, dynamic> data) {
    return Product(
      id: id,
      name: data['name'] ?? data['item'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      cost: (data['cost'] as num?)?.toDouble() ?? 0.0,
      wholesalePrice: (data['wholesalePrice'] as num?)?.toDouble(),
      stock: _readStockQuantity(data),
      category: data['category'] ?? 'Uncategorized',
      imageUrl: data['imageUrl'],
      barcode: data['barcode'],
      emoji: data['emoji'] ?? '📦',
      unit: (data['unit'] ?? 'pc').toString(),
      saleUnit: (data['saleUnit'] ?? data['unit'] ?? 'pc').toString(),
      saleUnitMultiplier:
          (data['saleUnitMultiplier'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Product _pickPreferredProduct(
    Product current,
    Product candidate, {
    DateTime? currentUpdatedAt,
    DateTime? candidateUpdatedAt,
  }) {
    final currentHasStock = current.stock > 0;
    final candidateHasStock = candidate.stock > 0;
    if (currentHasStock != candidateHasStock) {
      return candidateHasStock ? candidate : current;
    }
    if ((candidate.stock - current.stock).abs() > 0.0001) {
      return candidate.stock > current.stock ? candidate : current;
    }
    if ((candidate.price > 0) != (current.price > 0)) {
      return candidate.price > 0 ? candidate : current;
    }
    if ((candidate.cost > 0) != (current.cost > 0)) {
      return candidate.cost > 0 ? candidate : current;
    }
    final currentStamp = currentUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final candidateStamp =
        candidateUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return candidateStamp.isAfter(currentStamp) ? candidate : current;
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
        print('[RetailProvider] ⏭️ Skipping initialization - last init was ${elapsed.inSeconds}s ago');
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

  /// Generate receipt text for printing
  String _generateReceiptText({
    required String businessName,
    required String businessAddress,
    required String businessPhone,
    required String orderId,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double tax,
    required double discount,
    required double total,
    required String paymentMethod,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(businessName);
    buffer.writeln('RECEIPT');
    buffer.writeln('Order: $orderId');
    buffer.writeln('');
    for (var item in items) {
      buffer.writeln('${item['name']} x${item['quantity']}');
      buffer.writeln('  \$${(item['price'] as num).toStringAsFixed(2)}');
    }
    buffer.writeln('─' * 40);
    buffer.writeln('Subtotal: \$${subtotal.toStringAsFixed(2)}');
    if (tax > 0) buffer.writeln('Tax: \$${tax.toStringAsFixed(2)}');
    if (discount > 0) buffer.writeln('Discount: \$${discount.toStringAsFixed(2)}');
    buffer.writeln('TOTAL: \$${total.toStringAsFixed(2)}');
    buffer.writeln('Payment: $paymentMethod');
    return buffer.toString();
  }

  // Load products from Firestore inventory
  Future<void> loadProducts({String? storeId, bool forceRefresh = false}) async {
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

      // Load from inventory collection (official product storage)
      Query query = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory');
      if (storeId != null && storeId.isNotEmpty) {
        query = query.where('storeId', isEqualTo: storeId);
      }

      final snapshot = await query.get();

      _products = snapshot.docs.map((doc) {
        final raw = doc.data();
        if (raw is! Map<String, dynamic>) {
          debugPrint('[RetailProvider] Unexpected doc.data() type (${raw.runtimeType}) for doc ${doc.id} - using defaults');
          return Product(
            id: doc.id,
            name: '',
            price: 0.0,
            cost: 0.0,
            stock: 0.0,
            category: 'Uncategorized',
          );
        }
        final data = raw;
        return Product(
          id: doc.id,
          name: data['name'] ?? '',
          price: (data['price'] as num?)?.toDouble() ?? 0.0,
          cost: (data['cost'] as num?)?.toDouble() ?? 0.0,
          wholesalePrice: (data['wholesalePrice'] as num?)?.toDouble(),
          stock: _readStockQuantity(data),
          category: data['category'] ?? 'Uncategorized',
          imageUrl: data['imageUrl'],
          barcode: data['barcode'],
          emoji: data['emoji'] ?? '📦',
          unit: (data['unit'] ?? 'pc').toString(),
          saleUnit: (data['saleUnit'] ?? data['unit'] ?? 'pc').toString(),
          saleUnitMultiplier:
              (data['saleUnitMultiplier'] as num?)?.toDouble() ?? 1.0,
        );
      }).toList();

      // Also check business documents for inventory-like items (e.g., uploaded sheets)
      final docsSnapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('documents')
          .get();

      final documentProducts = <Product>[];
      for (final d in docsSnapshot.docs) {
        final ddata = d.data();
        Iterable<dynamic>? items;
        if (ddata.containsKey('items') && ddata['items'] is List) {
          items = ddata['items'] as List;
        } else if (ddata.containsKey('inventory') && ddata['inventory'] is List)
          items = ddata['inventory'] as List;
        else if ((ddata['name'] ?? '')
                .toString()
                .toLowerCase()
                .contains('inventory') &&
            ddata.containsKey('data') &&
            ddata['data'] is List) items = ddata['data'] as List;

        if (items != null) {
          var i = 0;
          for (final raw in items) {
            if (raw is Map<String, dynamic>) {
              final prod = Product(
                id: '${d.id}_$i',
                name: raw['name'] ?? raw['item'] ?? '',
                price: (raw['price'] as num?)?.toDouble() ?? 0.0,
                cost: (raw['cost'] as num?)?.toDouble() ?? 0.0,
                wholesalePrice:
                    (raw['wholesalePrice'] as num?)?.toDouble(),
                stock: _readStockQuantity(raw),
                category: raw['category'] ?? 'Uncategorized',
                imageUrl: raw['imageUrl'],
                barcode: raw['barcode'],
                emoji: raw['emoji'] ?? '📦',
                unit: (raw['unit'] ?? 'pc').toString(),
                saleUnit:
                    (raw['saleUnit'] ?? raw['unit'] ?? 'pc').toString(),
                saleUnitMultiplier:
                    (raw['saleUnitMultiplier'] as num?)?.toDouble() ?? 1.0,
              );
              documentProducts.add(prod);
            }
            i++;
          }
        }
      }

      // Merge and dedupe using SKU or name. Prefer records with live stock and
      // richer inventory data so quick sale does not surface stale zero-stock
      // duplicates ahead of the active product.
      final merged = <String, Product>{};
      final mergedUpdatedAt = <String, DateTime>{};
      for (final p in documentProducts) {
        final key = (p.barcode ?? '').isNotEmpty
            ? 'sku:${p.barcode}'
            : 'name:${p.name.toLowerCase()}';
        if (!merged.containsKey(key)) {
          merged[key] = p;
          mergedUpdatedAt[key] = DateTime.fromMillisecondsSinceEpoch(0);
        }
      }
      for (final p in _products) {
        final key = (p.barcode ?? '').isNotEmpty
            ? 'sku:${p.barcode}'
            : 'name:${p.name.toLowerCase()}';
        if (!merged.containsKey(key)) {
          merged[key] = p;
          mergedUpdatedAt[key] = DateTime.now();
          continue;
        }
        merged[key] = _pickPreferredProduct(
          merged[key]!,
          p,
          currentUpdatedAt: mergedUpdatedAt[key],
          candidateUpdatedAt: DateTime.now(),
        );
      }

      _products = merged.values.toList();

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

  // Load suppliers from Firestore
  Future<void> loadSuppliers() async {
    if (_businessId == null) return;

    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('suppliers')
          .get();

      _suppliers =
          snapshot.docs.map((doc) => Supplier.fromFirestore(doc)).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading suppliers: $e');
    }
  }

  Future<Map<String, dynamic>> _calculateFuelMetricsSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
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

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final items = (data['items'] as List<dynamic>?) ?? [];
      bool hasFuel = false;
      double saleFuelVolume = 0.0;
      double saleAmount =
          (data['totalAmount'] as num?)?.toDouble() ??
          (data['total'] as num?)?.toDouble() ??
          0.0;

      final saleCategory = (data['category'] as String?)?.toLowerCase() ?? '';
      if (saleCategory.contains('fuel') ||
          saleCategory.contains('petrol') ||
          saleCategory.contains('gas')) {
        hasFuel = true;
      }

      for (final it in items) {
        if (it is! Map<String, dynamic>) continue;
        final pid = (it['productId'] as String?) ?? '';
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
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    if (_products.isEmpty && _businessId != null) {
      await loadProducts();
    }

    final Map<String, String> productCategory = {
      for (var p in _products) p.id: p.category.toLowerCase()
    };

    final results = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final items = (data['items'] as List<dynamic>?) ?? [];
      double fuelVolume = 0.0;
      bool hasFuel = _isFuelText(data['category']?.toString() ?? '') ||
          _isFuelText(data['saleType']?.toString() ?? '') ||
          _isFuelText(data['order_type']?.toString() ?? '') ||
          (data['pumpId']?.toString().isNotEmpty == true);
      for (final it in items) {
        if (it is! Map<String, dynamic>) continue;
        final pid = (it['productId'] as String?) ?? '';
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
            _isFuelText(it['productName']?.toString() ?? '') ||
            _isFuelText(it['name']?.toString() ?? '')) {
          hasFuel = true;
          fuelVolume += qty;
        }
      }

      if (hasFuel) {
        final createdAt = _readTimestamp(data['createdAt']);
        results.add({
          'id': doc.id,
          'createdAt': createdAt,
          'createdAtRaw': data['createdAt'],
          'customerName': data['customerName'] ?? data['customer'] ?? 'Walk-in',
          'totalAmount': (data['totalAmount'] as num?)?.toDouble() ??
              (data['total'] as num?)?.toDouble() ??
              0.0,
          'fuelVolume': fuelVolume,
          'paymentMethod': data['paymentMethod'] ?? 'Cash',
          'items': items,
        });
      }
    }

    return results;
  }

  /// Returns aggregated fuel metrics for the business within an optional date range.
  /// If no range provided it uses today as default.
  Future<Map<String, dynamic>> getFuelMetrics({DateTime? start, DateTime? end}) async {
    if (_businessId == null) return {'totalAmount': 0.0, 'totalVolume': 0.0, 'transactions': 0};

    final now = DateTime.now();
    final s = start ?? DateTime(now.year, now.month, now.day);
    final e = end ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('sales')
          .where('createdAt', isGreaterThanOrEqualTo: s)
          .where('createdAt', isLessThanOrEqualTo: e)
          .get();

      return await _calculateFuelMetricsSnapshot(snapshot);
    } catch (e) {
      debugPrint('Error computing fuel metrics: $e');
      return {'totalAmount': 0.0, 'totalVolume': 0.0, 'transactions': 0};
    }
  }

  Stream<Map<String, dynamic>> watchFuelMetrics({DateTime? start, DateTime? end}) {
    if (_businessId == null) {
      return Stream.value({'totalAmount': 0.0, 'totalVolume': 0.0, 'transactions': 0});
    }

    final now = DateTime.now();
    final s = start ?? DateTime(now.year, now.month, now.day);
    final e = end ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _firestore
        .collection('businesses')
        .doc(_businessId)
        .collection('sales')
        .where('createdAt', isGreaterThanOrEqualTo: s)
        .where('createdAt', isLessThanOrEqualTo: e)
        .snapshots()
        .asyncMap((snapshot) => _calculateFuelMetricsSnapshot(snapshot));
  }

  /// Returns a list of sales that include fuel items, with computed fuelVolume for each sale.
  ///
  /// If `start` and `end` are not provided, this will return the most recent `limit`
  /// sales regardless of date (useful for viewing recent history for a gas station).
  Future<List<Map<String, dynamic>>> getFuelSalesHistory({DateTime? start, DateTime? end, int limit = 100}) async {
    if (_businessId == null) return [];

    // If no date range provided, fetch the most recent `limit` sales (no date filter).
    final useDateRange = start != null || end != null;
    DateTime? s;
    DateTime? e;
    if (useDateRange) {
      final now = DateTime.now();
      s = start ?? DateTime(now.year, now.month, now.day);
      e = end ?? DateTime(now.year, now.month, now.day, 23, 59, 59);
    }

    try {
      var query = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('sales')
          .orderBy('createdAt', descending: true) as dynamic;

      if (useDateRange) {
        query = _firestore
            .collection('businesses')
            .doc(_businessId)
            .collection('sales')
            .where('createdAt', isGreaterThanOrEqualTo: s)
            .where('createdAt', isLessThanOrEqualTo: e)
            .orderBy('createdAt', descending: true);
      }

      final snapshot = await query.limit(limit).get();
      return await _calculateFuelSalesHistorySnapshot(snapshot);
    } catch (e) {
      debugPrint('Error fetching fuel sales history: $e');
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> watchFuelSalesHistory({
    DateTime? start,
    DateTime? end,
    int limit = 100,
  }) {
    if (_businessId == null) {
      return Stream.value([]);
    }

    final useDateRange = start != null || end != null;
    DateTime? s;
    DateTime? e;
    if (useDateRange) {
      final now = DateTime.now();
      s = start ?? DateTime(now.year, now.month, now.day);
      e = end ?? DateTime(now.year, now.month, now.day, 23, 59, 59);
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection('businesses')
        .doc(_businessId)
        .collection('sales')
        .orderBy('createdAt', descending: true);

    if (useDateRange) {
      query = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('sales')
          .where('createdAt', isGreaterThanOrEqualTo: s)
          .where('createdAt', isLessThanOrEqualTo: e)
          .orderBy('createdAt', descending: true);
    }

    return query.limit(limit).snapshots().asyncMap(
          (snapshot) => _calculateFuelSalesHistorySnapshot(snapshot),
        );
  }

  // Load stores from Firestore
  Future<void> loadStores() async {
    if (_businessId == null) return;

    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('stores')
          .get();

      _stores =
          snapshot.docs.map((doc) => StoreLocation.fromFirestore(doc)).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading stores: $e');
    }
  }

  // Load promotions from Firestore
  Future<void> loadPromotions() async {
    if (_businessId == null) return;

    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('promotions')
          .where('endDate', isGreaterThan: Timestamp.now())
          .get();

      _promotions =
          snapshot.docs.map((doc) => Promotion.fromFirestore(doc)).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading promotions: $e');
    }
  }

  // Store Management
  // Add store to Firestore
  Future<void> addStore({required String name, required String location, String? address, String? phone}) async {
    if (_businessId == null) return;

    try {
      // Enforce Tier 1 businesses can only have one store
      try {
        final businessDoc = await _firestore.collection('businesses').doc(_businessId).get();
        final subscriptionTier = (businessDoc.data()?['subscriptionTier'] ?? '').toString().toLowerCase();
        if (subscriptionTier == 'tier1' || subscriptionTier == 'basic' || subscriptionTier == 'standard') {
          final storesSnapshot = await _firestore.collection('businesses').doc(_businessId).collection('stores').get();
          if (storesSnapshot.docs.length >= 1) {
            _errorMessage = 'Your subscription allows only one store. Upgrade to add more stores.';
            notifyListeners();
            return;
          }
        }
      } catch (e) {
        // If we cannot determine subscription tier, fall back to permissive behavior
        debugPrint('Warning: could not verify subscription tier before adding store: $e');
      }

      final data = {
        'name': name,
        'location': location,
        'address': address,
        'phone': phone,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('stores')
          .add(data);

      await loadStores();
    } catch (e) {
      _errorMessage = 'Failed to add store: $e';
      notifyListeners();
      debugPrint('Error adding store: $e');
    }
  }

  // Update store in Firestore
  Future<void> updateStore(String storeId, {required String name, required String location, String? address, String? phone}) async {
    if (_businessId == null) return;

    try {
      final updateData = {
        'name': name,
        'location': location,
        'address': address,
        'phone': phone,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('stores')
          .doc(storeId)
          .update(updateData);

      await loadStores();
    } catch (e) {
      _errorMessage = 'Failed to update store: $e';
      notifyListeners();
      debugPrint('Error updating store: $e');
    }
  }

  // Delete store from Firestore
  Future<void> deleteStore(String storeId) async {
    if (_businessId == null) return;

    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('stores')
          .doc(storeId)
          .delete();

      await loadStores();
    } catch (e) {
      _errorMessage = 'Failed to delete store: $e';
      notifyListeners();
      debugPrint('Error deleting store: $e');
    }
  }

  // Add product to Firestore
  Future<void> addProduct(Product product, {String? storeId}) async {
    if (_businessId == null) return;

    try {
      // Save to inventory collection (official product storage)
      final data = {
        'name': product.name,
        'price': product.price,
        'cost': product.cost,
        'wholesalePrice': product.wholesalePrice,
        'quantity': product.stock,
        'category': product.category,
        'unit': product.unit,
        'saleUnit': product.resolvedSaleUnit,
        'saleUnitMultiplier': product.resolvedSaleUnitMultiplier,
        'barcode': product.barcode,
        'emoji': product.emoji,
        'imageUrl': product.imageUrl,
        'trackExpiry': product.trackExpiry,
        if (product.expiryDate != null) 'expiryDate': product.expiryDate,
        if (product.batchLabel != null &&
            product.batchLabel!.trim().isNotEmpty)
          'batchLabel': product.batchLabel!.trim(),
        if (product.shelfLifeDays != null)
          'shelfLifeDays': product.shelfLifeDays,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (storeId != null && storeId.isNotEmpty) data['storeId'] = storeId;

      final docRef = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory')
          .add(data);

      await _logProductActivity(
        productId: docRef.id,
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

  // Update product in Firestore
  Future<void> updateProduct(String productId, Product product, {String? storeId}) async {
    if (_businessId == null) return;

    try {
      // Update in inventory collection (official product storage)
      final updateData = {
        'name': product.name,
        'price': product.price,
        'cost': product.cost,
        'wholesalePrice': product.wholesalePrice,
        'quantity': product.stock,
        'category': product.category,
        'unit': product.unit,
        'saleUnit': product.resolvedSaleUnit,
        'saleUnitMultiplier': product.resolvedSaleUnitMultiplier,
        'barcode': product.barcode,
        'emoji': product.emoji,
        'imageUrl': product.imageUrl,
        'trackExpiry': product.trackExpiry,
        if (product.expiryDate != null) 'expiryDate': product.expiryDate,
        if (product.batchLabel != null &&
            product.batchLabel!.trim().isNotEmpty)
          'batchLabel': product.batchLabel!.trim(),
        if (product.shelfLifeDays != null)
          'shelfLifeDays': product.shelfLifeDays,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (storeId != null && storeId.isNotEmpty) updateData['storeId'] = storeId;

      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory')
          .doc(productId)
          .update(updateData);

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

  // Delete product from Firestore
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

      // Delete from inventory collection (official product storage)
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory')
          .doc(productId)
          .delete();

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

    final payload = <String, dynamic>{
      'productId': productId,
      'productName': productName,
      'action': action,
      'changes': changes ?? const <String, dynamic>{},
      'storeId': storeId,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      final businessRef = _firestore.collection('businesses').doc(_businessId);
      await businessRef
          .collection('inventory')
          .doc(productId)
          .collection('activity')
          .add(payload);
      await businessRef.collection('product_activity').add(payload);
    } catch (e) {
      debugPrint('[RetailProvider] Product activity log failed: $e');
    }
  }

  // Add supplier to Firestore
  Future<void> addSupplier(Supplier supplier) async {
    if (_businessId == null) return;

    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('suppliers')
          .add(supplier.toFirestore());

      await loadSuppliers();
    } catch (e) {
      _errorMessage = 'Failed to add supplier: $e';
      notifyListeners();
      debugPrint('Error adding supplier: $e');
    }
  }

  // Add promotion to Firestore
  Future<void> addPromotion(Promotion promotion) async {
    if (_businessId == null) return;

    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('promotions')
          .add(promotion.toFirestore());

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
    final resolvedMode =
        pricingMode == 'wholesale' || pricingMode == 'retail'
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
        return _products.firstWhere((p) => p.id == code || p.name.toLowerCase() == code.toLowerCase());
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
    if (mode == 'wholesale' && product.hasWholesalePricing && product.wholesalePrice != null) {
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
          throw Exception('Insufficient stock for ${product.name}. Available: ${product.stock}, Required: $stockReduction');
        }
      }

      // Compute subtotal applying any price overrides and pricing modes
      double subtotal = 0.0;
      for (final entry in activeCartEntries.entries) {
        final product = _findProductForCart(entry.key);
        // Use price overrides first, otherwise use effective price based on pricing mode
        final unitPrice = priceOverrides != null && priceOverrides.containsKey(entry.key)
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
          final unitPrice = priceOverrides != null && priceOverrides.containsKey(e.key)
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
        'createdAt': FieldValue.serverTimestamp(),
        if (customerId != null && customerId.isNotEmpty) 'customerId': customerId,
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

      // Check connectivity up front. Firestore's own offline persistence
      // would otherwise resolve a write locally without throwing even with
      // no network — safe for the data, but it means we could never
      // reliably tell the cashier "this sale is offline and pending sync".
      // Checking first makes that signal trustworthy.
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
          storeId: storeId,
          priceOverrides: priceOverrides,
        );
      }

      // Try to write to Firestore first
      try {
        final saleRef = await _firestore
            .collection('businesses')
            .doc(_businessId)
            .collection('sales')
            .add(saleData);
        final orderId = saleRef.id;
        // Save orderId back to the sale document for tracking
        await saleRef.update({'orderId': orderId});

        // ── Quota optimisation: update daily sales summary ─────────────
        // One atomic increment per sale so the dashboard can read a single
        // summary doc instead of fetching every sale in the date range.
        try {
          final now = DateTime.now();
          final dayKey =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          await _firestore
              .collection('businesses')
              .doc(_businessId)
              .collection('salesSummaries')
              .doc(dayKey)
              .set({
            'date': dayKey,
            'totalSales': FieldValue.increment(totalAmount),
            'totalTransactions': FieldValue.increment(1),
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          // Non-fatal — dashboard falls back gracefully if summary is absent.
          debugPrint('[Checkout] salesSummaries update failed: $e');
        }
        // ────────────────────────────────────────────────────────────────

        // Update product stock in inventory collection
        for (final entry in activeCartEntries.entries) {
          final product = _findProductForCart(entry.key);

          final stockReduction =
              getEffectiveSaleUnitMultiplierForCartItem(entry.key) *
                  entry.value;
          final newQuantity =
              (product.stock - stockReduction).clamp(0.0, 999999.0);
          await _writeInventoryStock(product, newQuantity, storeId: storeId);

          // Update in-memory stock immediately so the POS grid shows the
          // correct quantity without waiting for the next loadProducts call.
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
        // Firestore write failed — fall back to local DB and queue for sync
        debugPrint('[Checkout] Firestore write failed, saving locally: $e');
        return await _saveSaleOffline(
          activeCartEntries: activeCartEntries,
          totalAmount: totalAmount,
          taxAmount: taxAmount,
          discount: discount,
          paymentMethod: paymentMethod,
          customerId: customerId,
          workerId: workerId,
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
      debugPrint('[Checkout] Offline item save failed, rolling back local sale $saleId: $e');
      try {
        await dbHelper.delete('sale_items', where: 'saleId = ?', whereArgs: [saleId]);
        await dbHelper.delete('sales', where: 'id = ?', whereArgs: [saleId]);
      } catch (_) {}
      rethrow;
    }

    // Add to sync queue
    await dbHelper.addToSyncQueue(entityType: 'sale', entityId: saleId, action: 'create', data: localSale);

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
        final newQty = (currentQty - (saleUnitMultiplier * e.value))
            .clamp(0, 999999);
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
          'quantity': (0 - (saleUnitMultiplier * e.value))
              .toDouble()
              .clamp(0, 999999),
          'stock': (0 - (saleUnitMultiplier * e.value))
              .toDouble()
              .clamp(0, 999999),
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

  Map<String, dynamic> _serverPumpSaleData(Map<String, dynamic> pendingSale) {
    final data = Map<String, dynamic>.from(
      pendingSale['saleData'] as Map<String, dynamic>? ?? {},
    );
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    data['offlineSyncedAt'] = FieldValue.serverTimestamp();
    data['offlineQueued'] = false;
    data['orderId'] = pendingSale['orderId'];
    return data;
  }

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

    final saleRef = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('sales')
        .doc(orderId);
    final inventoryRef = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('inventory')
        .doc(productId);

    await _firestore.runTransaction((transaction) async {
      final existingSale = await transaction.get(saleRef);
      final existingSaleData = existingSale.data() ?? <String, dynamic>{};
      final shouldApplyInventory = !existingSale.exists ||
          (pendingSale['saleWrittenOnline'] == true &&
              existingSaleData['offlineInventorySynced'] != true);
      final inventorySnapshot =
          shouldApplyInventory ? await transaction.get(inventoryRef) : null;
      final serverSaleData = _serverPumpSaleData(pendingSale);
      if (shouldApplyInventory) {
        serverSaleData['offlineInventorySynced'] = true;
      }
      transaction.set(saleRef, serverSaleData, SetOptions(merge: true));
      if (!shouldApplyInventory) return;
      if (inventorySnapshot == null) return;

      final inventoryData = inventorySnapshot.data() ?? <String, dynamic>{};
      final currentStock =
          (inventoryData['quantity'] as num?)?.toDouble() ??
              (inventoryData['stock'] as num?)?.toDouble() ??
              0.0;
      final nextStock = (currentStock - quantity).clamp(0.0, 999999999.0);
      transaction.set(
        inventoryRef,
        {
          'quantity': nextStock,
          'stock': nextStock,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
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
      orElse: () => Product(id: productId, name: 'Unknown', price: 0, stock: 0, category: 'Unknown'),
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
      'createdAt': FieldValue.serverTimestamp(),
      if (storeId != null && storeId.isNotEmpty) 'storeId': storeId,
      if (pumpId != null && pumpId.isNotEmpty) 'pumpId': pumpId,
      if (pumpNumber != null && pumpNumber.isNotEmpty)
        'pumpNumber': pumpNumber,
      if (pumpName != null && pumpName.isNotEmpty) 'pumpName': pumpName,
      'category': 'Fuel',
    };

    // Add worker info
    if (workerId != null && workerId.isNotEmpty) {
      saleData['workerId'] = workerId;
      saleData['workerName'] = workerName ?? 'Unknown';
    }

    final saleRef = _firestore
        .collection('businesses')
        .doc(_businessId)
        .collection('sales')
        .doc();
    final orderId = saleRef.id;
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

    // Check connectivity up front rather than relying on the Firestore write
    // to throw — with offline persistence enabled, writes resolve locally
    // without an exception even with no network, which would otherwise make
    // "offlineQueued" almost never trigger for genuinely offline sales.
    final hasNetwork = await ConnectivityHelper.hasInternetConnection();
    if (!hasNetwork) {
      debugPrint(
          '[RetailProvider.fuelSale] No network detected, queueing sale offline');
      return await queueFuelSaleOffline();
    }

    try {
      await saleRef.set(saleData);
      saleWrittenOnline = true;
      await _writeInventoryStock(product, newQty);
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
      final businessDoc = await _firestore.collection('businesses').doc(_businessId).get();
      final businessData = businessDoc.data() ?? <String, dynamic>{};
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

        final ownerSuccess = await _notificationEmailService.sendSalesNotification(
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

    // Attempt automatic receipt printing for pump/gas sales when enabled
    try {
      final businessDoc = await _firestore.collection('businesses').doc(_businessId).get();
      final businessData = businessDoc.data() ?? <String, dynamic>{};
      final receiptEnabled = (businessData['industrySpecificSettings'] ?? {})['receiptPrinting'] ?? false;

      if (receiptEnabled == true) {
        // load thermal preferences
        await _firestore
            .collection('businesses')
            .doc(_businessId)
            .collection('receipt_settings')
            .doc('thermalPreferences')
            .get();
        // Note: prefDoc could be used for future printer preference configuration

        // Build a receipt using the enhanced formatter and send to printer
        final itemsForPrint = (saleData['items'] as List<dynamic>).map((it) {
          return {
            'name': it['productName'] ?? it['name'] ?? 'Item',
            'quantity': it['quantity'] ?? 0,
            'price': it['unitPrice'] ?? it['price'] ?? 0,
            'total': it['total'] ?? 0,
          };

        }).toList();

        final businessName = businessData['name'] ?? 'Your Business';

        // Format receipt as simple text
        final receiptText = _generateReceiptText(
          businessName: businessName,
          businessAddress: businessData['address'] ?? '',
          businessPhone: businessData['phone'] ?? '',
          orderId: orderId,
          items: itemsForPrint.cast<Map<String, dynamic>>(),
          subtotal: paid,
          tax: 0.0,
          discount: 0.0,
          total: paid,
          paymentMethod: paymentMethod,
        );

        debugPrint('[RetailProvider] Auto-print receipt generated: ${receiptText.length} chars');
      }
    } catch (e) {
      debugPrint('[RetailProvider] Error during automatic receipt printing: $e');
    }

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
      var query = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('sales')
          .where('workerId', isEqualTo: workerId) as dynamic;
      if (storeId != null && storeId.isNotEmpty) {
        query = query.where('storeId', isEqualTo: storeId);
      }

      final snapshot = await query.get();

      double totalSales = 0.0;
      for (final doc in snapshot.docs) {
        final amount = (doc['totalAmount'] as num?)?.toDouble() ?? 0.0;
        totalSales += amount;
      }

      debugPrint(
          '[RetailProvider] Worker $workerId total sales: \u20a6$totalSales');
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
      var query = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('sales')
          .where('workerId', isEqualTo: workerId) as dynamic;
      if (storeId != null && storeId.isNotEmpty) query = query.where('storeId', isEqualTo: storeId);

      final snapshot = await query.get();

      debugPrint(
          '[RetailProvider] Worker $workerId sales count: ${snapshot.docs.length}');
      return snapshot.docs.length;
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
      var query = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('sales')
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThanOrEqualTo: endDate) as dynamic;
      if (storeId != null && storeId.isNotEmpty) query = query.where('storeId', isEqualTo: storeId);

      final snapshot = await query.get();

      double totalSales = 0.0;
      for (final doc in snapshot.docs) {
        final amount = (doc['totalAmount'] as num?)?.toDouble() ?? 0.0;
        totalSales += amount;
      }

      debugPrint(
          '[RetailProvider] Total sales from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}: ₦$totalSales');
      return totalSales;
    } catch (e) {
      debugPrint('[RetailProvider] Error fetching sales for period: $e');
      return 0.0;
    }
  }

  // Get sales history with optional limit and range. This is a simple convenience method (non-paged).
  // NOTE: Sales may exist both in the business subcollection and in the root "sales" collection
  // (some modules write to root). We combine both sources, dedupe by id (nested takes precedence),
  // sort by createdAt desc, and return up to `limit` records.
  Future<List<Map<String, dynamic>>> getSalesHistory({
    int limit = 50,
    String? storeId,
    DateTime? start,
    DateTime? end,
    String? status,
  }) async {
    if (_businessId == null) return [];

    try {
      // Nested (business) query
      var nestedQuery = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('sales')
          .orderBy('createdAt', descending: true) as dynamic;
      if (storeId != null && storeId.isNotEmpty) nestedQuery = nestedQuery.where('storeId', isEqualTo: storeId);
      if (status != null && status.isNotEmpty && status != 'all') nestedQuery = nestedQuery.where('status', isEqualTo: status);
      if (start != null) nestedQuery = nestedQuery.where('createdAt', isGreaterThanOrEqualTo: start);
      if (end != null) nestedQuery = nestedQuery.where('createdAt', isLessThanOrEqualTo: end);

      // Root query filtering by businessId
      var rootQuery = _firestore.collection('sales').where('businessId', isEqualTo: _businessId) as dynamic;
      if (storeId != null && storeId.isNotEmpty) rootQuery = rootQuery.where('storeId', isEqualTo: storeId);
      if (status != null && status.isNotEmpty && status != 'all') rootQuery = rootQuery.where('status', isEqualTo: status);
      if (start != null) rootQuery = rootQuery.where('createdAt', isGreaterThanOrEqualTo: start);
      if (end != null) rootQuery = rootQuery.where('createdAt', isLessThanOrEqualTo: end);

      final nestedSnapshot = await nestedQuery.limit(limit).get();
      final rootSnapshot = await rootQuery.limit(limit).get();

      final Map<String, Map<String, dynamic>> combined = {};

      // Root first, nested overwrites if same id
      for (final doc in rootSnapshot.docs) {
        combined[doc.id] = {'id': doc.id, ...(doc.data() as Map<String, dynamic>)};
      }
      for (final doc in nestedSnapshot.docs) {
        combined[doc.id] = {'id': doc.id, ...(doc.data() as Map<String, dynamic>)};
      }

      List<Map<String, dynamic>> sales = combined.values.toList();

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

      sales.sort((a, b) => _createdAtToMillis(b['createdAt']).compareTo(_createdAtToMillis(a['createdAt'])));

      if (sales.length > limit) sales = sales.sublist(0, limit);

      debugPrint('[RetailProvider] Fetched ${sales.length} sales records (combined root & nested)');
      return sales;
    } catch (e) {
      debugPrint('[RetailProvider] Error fetching sales history: $e');
      return [];
    }
  }

  // Fetch a single sale from either the business sales collection or the root
  // sales collection so receipt reprints can reopen older records reliably.
  Future<Map<String, dynamic>?> getSaleById(String saleId) async {
    if (_businessId == null || saleId.trim().isEmpty) return null;

    try {
      final nestedDoc = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('sales')
          .doc(saleId)
          .get();
      if (nestedDoc.exists) {
        return {'id': nestedDoc.id, ...(nestedDoc.data() ?? const {})};
      }

      final rootDoc = await _firestore.collection('sales').doc(saleId).get();
      if (rootDoc.exists) {
        return {'id': rootDoc.id, ...(rootDoc.data() ?? const {})};
      }
    } catch (e) {
      debugPrint('[RetailProvider] Error fetching sale by id: $e');
    }

    return null;
  }

  /// Sales that only exist locally (queued while offline, or stuck after a
  /// failed sync attempt) so Sales History can show them before they've
  /// actually reached Firestore. Each entry is shaped like a Firestore sale
  /// doc plus a `pendingSync: true` marker and its line items attached.
  Future<List<Map<String, dynamic>>> getLocalPendingSales() async {
    if (_businessId == null) return [];
    try {
      final dbHelper = DatabaseHelper.instance;
      final pending = await dbHelper.query('sales', where: 'syncStatus = ?', whereArgs: ['pending']);
      final failed = await dbHelper.query('sales', where: 'syncStatus = ?', whereArgs: ['failed']);
      final errored = await dbHelper.query('sales', where: 'syncStatus = ?', whereArgs: ['error']);
      final rows = [...pending, ...failed, ...errored]
          .where((r) => r['businessId']?.toString() == _businessId);

      final result = <Map<String, dynamic>>[];
      for (final row in rows) {
        final saleId = row['id']?.toString() ?? '';
        final itemRows = saleId.isEmpty
            ? <Map<String, dynamic>>[]
            : await dbHelper.query('sale_items', where: 'saleId = ?', whereArgs: [saleId]);
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

  // Paged sales fetch — returns sales plus the last document snapshot (for startAfter)
  // This method merges business-level sales and root 'sales' collection (filtered by businessId).
  // Paging uses the nested business collection's document snapshot as the cursor (startAfterDoc).
  Future<Map<String, dynamic>> getSalesHistoryPage({
    int limit = 50,
    String? storeId,
    DateTime? start,
    DateTime? end,
    String? status,
    DocumentSnapshot? startAfterDoc,
  }) async {
    if (_businessId == null) return {'sales': <Map<String, dynamic>>[], 'lastDoc': null};

    try {
      // A "refunded" filter should also surface partially-refunded sales —
      // otherwise a partial return makes a sale vanish from both the
      // Completed tab (it's no longer that status) and the Refunded tab
      // (its status isn't an exact match). Queried as separate equality
      // filters (rather than whereIn) so this doesn't require deploying a
      // new Firestore composite index beyond what the existing per-status
      // filters already rely on.
      final statusValues = status == 'refunded'
          ? const ['refunded', 'partially_refunded']
          : <String>[if (status != null && status.isNotEmpty && status != 'all') status];

      final Map<String, Map<String, dynamic>> combined = {};
      DocumentSnapshot? lastDoc;

      if (statusValues.isEmpty) {
        var nestedQuery = _firestore
            .collection('businesses')
            .doc(_businessId)
            .collection('sales')
            .orderBy('createdAt', descending: true) as dynamic;
        if (storeId != null && storeId.isNotEmpty) nestedQuery = nestedQuery.where('storeId', isEqualTo: storeId);
        if (start != null) nestedQuery = nestedQuery.where('createdAt', isGreaterThanOrEqualTo: start);
        if (end != null) nestedQuery = nestedQuery.where('createdAt', isLessThanOrEqualTo: end);
        if (startAfterDoc != null) nestedQuery = nestedQuery.startAfterDocument(startAfterDoc);

        var rootQuery = _firestore.collection('sales').where('businessId', isEqualTo: _businessId) as dynamic;
        if (storeId != null && storeId.isNotEmpty) rootQuery = rootQuery.where('storeId', isEqualTo: storeId);
        if (start != null) rootQuery = rootQuery.where('createdAt', isGreaterThanOrEqualTo: start);
        if (end != null) rootQuery = rootQuery.where('createdAt', isLessThanOrEqualTo: end);

        final nestedSnapshot = await nestedQuery.limit(limit).get();
        final rootSnapshot = await rootQuery.limit(limit).get();
        for (final doc in rootSnapshot.docs) {
          combined[doc.id] = {'id': doc.id, ...(doc.data() as Map<String, dynamic>)};
        }
        for (final doc in nestedSnapshot.docs) {
          combined[doc.id] = {'id': doc.id, ...(doc.data() as Map<String, dynamic>)};
        }
        if (nestedSnapshot.docs.isNotEmpty) lastDoc = nestedSnapshot.docs.last;
      } else {
        for (final statusValue in statusValues) {
          var nestedQuery = _firestore
              .collection('businesses')
              .doc(_businessId)
              .collection('sales')
              .orderBy('createdAt', descending: true)
              .where('status', isEqualTo: statusValue) as dynamic;
          if (storeId != null && storeId.isNotEmpty) nestedQuery = nestedQuery.where('storeId', isEqualTo: storeId);
          if (start != null) nestedQuery = nestedQuery.where('createdAt', isGreaterThanOrEqualTo: start);
          if (end != null) nestedQuery = nestedQuery.where('createdAt', isLessThanOrEqualTo: end);
          if (startAfterDoc != null) nestedQuery = nestedQuery.startAfterDocument(startAfterDoc);

          var rootQuery = _firestore
              .collection('sales')
              .where('businessId', isEqualTo: _businessId)
              .where('status', isEqualTo: statusValue) as dynamic;
          if (storeId != null && storeId.isNotEmpty) rootQuery = rootQuery.where('storeId', isEqualTo: storeId);
          if (start != null) rootQuery = rootQuery.where('createdAt', isGreaterThanOrEqualTo: start);
          if (end != null) rootQuery = rootQuery.where('createdAt', isLessThanOrEqualTo: end);

          final nestedSnapshot = await nestedQuery.limit(limit).get();
          final rootSnapshot = await rootQuery.limit(limit).get();
          for (final doc in rootSnapshot.docs) {
            combined[doc.id] = {'id': doc.id, ...(doc.data() as Map<String, dynamic>)};
          }
          for (final doc in nestedSnapshot.docs) {
            combined[doc.id] = {'id': doc.id, ...(doc.data() as Map<String, dynamic>)};
          }
          if (nestedSnapshot.docs.isNotEmpty) lastDoc = nestedSnapshot.docs.last;
        }
      }

      List<Map<String, dynamic>> sales = combined.values.toList();

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

      sales.sort((a, b) => _createdAtToMillis(b['createdAt']).compareTo(_createdAtToMillis(a['createdAt'])));

      if (sales.length > limit) sales = sales.sublist(0, limit);

      debugPrint('[RetailProvider] Fetched ${sales.length} (paged, combined root & nested) sales records');
      return {'sales': sales, 'lastDoc': lastDoc};
    } catch (e) {
      debugPrint('[RetailProvider] Error fetching paged sales history: $e');
      return {'sales': <Map<String, dynamic>>[], 'lastDoc': null};
    }
  }

  // Realtime sales history subscription
  StreamSubscription<QuerySnapshot>? _salesHistorySubscription;

  void subscribeToSalesHistory(
      void Function(List<Map<String, dynamic>> sales) onUpdate,
      {int limit = 50}) {
    if (_businessId == null) return;
    _salesHistorySubscription?.cancel();
    _salesHistorySubscription = _firestore
        .collection('businesses')
        .doc(_businessId)
        .collection('sales')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .listen((snapshot) {
      final sales = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
      onUpdate(sales);
    }, onError: (e) {
      debugPrint('[RetailProvider] Sales subscription error: $e');
    });
  }

  void unsubscribeFromSalesHistory() {
    _salesHistorySubscription?.cancel();
    _salesHistorySubscription = null;
  }

  // Get sales count for a date range
  Future<int> getSalesCountForPeriod({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_businessId == null) return 0;

    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('sales')
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThanOrEqualTo: endDate)
          .get();

      debugPrint(
          '[RetailProvider] Sales count from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}: ${snapshot.docs.length}');
      return snapshot.docs.length;
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

  // Process return/refund
  Future<void> processReturn(Map<String, dynamic> returnData) async {
    try {
      final businessId = returnData['businessId'];

      if (businessId == null) {
        throw Exception('Business ID not found');
      }

      // Save return to Firestore
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('returns')
          .add({
        ...returnData,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update original sale with return reference
      final saleId = returnData['saleId'];
      if (saleId != null && saleId.isNotEmpty) {
        final saleRef = FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessId)
            .collection('sales')
            .doc(saleId);

        // Determine whether this (plus any prior) refund covers the full
        // sale amount, so the sale's status reflects reality and the
        // "Refunded" tab in Sales History actually picks it up — a partial
        // return should not silently hide the sale from view.
        final refundAmount = ((returnData['refundAmount'] ?? 0) as num).toDouble();
        String status = 'partially_refunded';
        try {
          final saleSnap = await saleRef.get();
          final saleData = saleSnap.data() ?? <String, dynamic>{};
          final saleTotal = ((saleData['finalAmount'] ?? saleData['totalAmount'] ?? saleData['total'] ?? 0) as num).toDouble();
          final priorReturnAmount = ((saleData['returnAmount'] ?? 0) as num).toDouble();
          final totalReturned = priorReturnAmount + refundAmount;
          if (saleTotal <= 0 || totalReturned >= saleTotal - 0.01) {
            status = 'refunded';
          }
        } catch (e) {
          print('[RetailProvider] Error reading sale to determine refund status: $e');
        }

        final updateMap = <String, dynamic>{
          'hasReturn': true,
          'status': status,
          'returnAmount': FieldValue.increment(refundAmount),
          'returnedAt': FieldValue.serverTimestamp(),
          // Mark this return so it may or may not subtract from sales totals
          'excludeReturnFromTotals': returnData['excludeFromTotals'] == true,
        };

        // Accumulate per-item returned quantities (dot-path updates merge
        // into the existing map rather than overwriting it) so a later
        // partial refund on the same sale knows exactly how much of each
        // item is still available to return.
        final itemsReturned = returnData['itemsReturned'] as List? ?? const [];
        for (final raw in itemsReturned) {
          if (raw is! Map) continue;
          final item = Map<String, dynamic>.from(raw);
          final productId = (item['productId'] ?? '').toString();
          final qty = ((item['quantity'] ?? 0) as num);
          if (productId.isEmpty || qty <= 0) continue;
          updateMap['returnedQuantities.$productId'] = FieldValue.increment(qty);
        }

        await saleRef.update(updateMap);
      }

      print(
          '[RetailProvider] Return processed: ₦${returnData['refundAmount']}');
      notifyListeners();
    } catch (e) {
      print('[RetailProvider] Error processing return: $e');
      rethrow;
    }
  }

  // Add inventory (restore on return)
  Future<void> addInventory(String productId, int quantity) async {
    try {
      if (_businessId == null) return;

      final productRef = FirebaseFirestore.instance
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory')
          .doc(productId);

      await productRef.update({
        'quantity': FieldValue.increment(quantity),
        'stock': FieldValue.increment(quantity),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('[RetailProvider] Inventory restored: $productId +$quantity');
    } catch (e) {
      print('[RetailProvider] Error restoring inventory: $e');
      rethrow;
    }
  }

  // Save customer purchase to history
  Future<void> savePurchaseToCustomerHistory(
    String customerId,
    Map<String, dynamic> saleData,
  ) async {
    try {
      if (_businessId == null) return;

      // Save to customer's purchases subcollection
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(_businessId)
          .collection('customers')
          .doc(customerId)
          .collection('purchases')
          .add({
        ...saleData,
        'customerId': customerId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('[RetailProvider] Purchase saved to customer history: $customerId');
    } catch (e) {
      print('[RetailProvider] Error saving purchase history: $e');
      rethrow;
    }
  }

  // Link customer to sale
  Future<void> linkCustomerToSale(String saleId, String customerId) async {
    try {
      if (_businessId == null) return;

      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(_businessId)
          .collection('sales')
          .doc(saleId)
          .update({
        'customerId': customerId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('[RetailProvider] Customer $customerId linked to sale $saleId');
    } catch (e) {
      print('[RetailProvider] Error linking customer to sale: $e');
      rethrow;
    }
  }

  /// Get today's sales total from Firestore sales collection
  Future<double> getTodaysSalesTotal() async {
    if (_businessId == null || _businessId!.isEmpty) {
      return 0.0;
    }

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      try {
        final snapshot = await _firestore
            .collection('businesses')
            .doc(_businessId)
            .collection('sales')
            .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
            .where('createdAt', isLessThanOrEqualTo: endOfDay)
            .where('status', isEqualTo: 'completed')
            .get();

        double totalSales = 0.0;
        for (final doc in snapshot.docs) {
          final amount = (doc['totalAmount'] as num?)?.toDouble() ?? 0.0;
          totalSales += amount;
        }

        debugPrint('[RetailProvider] Today\'s sales total: ₦$totalSales');
        return totalSales;
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('requires an index') || msg.contains('FAILED_PRECONDITION')) {
          try {
            debugPrint('[RetailProvider] Composite index required; falling back to date-only query for today\'s sales');
            final fallback = await _firestore
                .collection('businesses')
                .doc(_businessId)
                .collection('sales')
                .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
                .where('createdAt', isLessThanOrEqualTo: endOfDay)
                .get();

            double totalSales = 0.0;
            for (final doc in fallback.docs) {
              if ((doc['status'] as String?)?.toLowerCase() != 'completed') continue;
              final amount = (doc['totalAmount'] as num?)?.toDouble() ?? 0.0;
              totalSales += amount;
            }

            debugPrint('[RetailProvider] Today\'s sales total (fallback): ₦$totalSales');
            return totalSales;
          } catch (e2) {
            debugPrint('[RetailProvider] Fallback date-only query failed: $e2');
            return 0.0;
          }
        }

        debugPrint('[RetailProvider] Error fetching today\'s sales: $e');
        return 0.0;
      }
    } catch (e) {
      debugPrint('[RetailProvider] Error fetching today\'s sales: $e');
      return 0.0;
    }
  }
}
