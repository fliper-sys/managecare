import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../services/business_notification_manager.dart';
// ============= MODELS =============

class WholesaleProduct {
  final String id;
  final String name;
  final String sku;
  final String category;
  final double costPrice;
  final double sellingPrice;
  final double wholesalePrice;
  final int quantity;
  final int reorderLevel;
  final int reorderQuantity;
  final String? imageUrl;
  final String supplier;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, int> warehouseAllocations; // warehouseId -> quantity

  WholesaleProduct({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.costPrice,
    required this.sellingPrice,
    required this.wholesalePrice,
    required this.quantity,
    required this.reorderLevel,
    required this.reorderQuantity,
    this.imageUrl,
    required this.supplier,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, int>? warehouseAllocations,
  })  : createdAt = createdAt ?? DateTime.now(),
      updatedAt = updatedAt ?? DateTime.now(),
      warehouseAllocations = warehouseAllocations ?? {};

  factory WholesaleProduct.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      if (value is Timestamp) return value.toDate();
      return null;
    }

    return WholesaleProduct(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      sku: (json['sku'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: ((json['sellingPrice'] ?? json['price']) as num?)?.toDouble() ?? 0.0,
      wholesalePrice: (json['wholesalePrice'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as int?) ?? 0,
      reorderLevel: json['reorderLevel'] as int? ?? 10,
      reorderQuantity: json['reorderQuantity'] as int? ?? 50,
      imageUrl: json['imageUrl'] as String?,
      supplier: (json['supplier'] as String?) ?? '',
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      warehouseAllocations: (json['warehouseAllocations'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toInt())) ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sku': sku,
        'category': category,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      // Backwards-compatible price key for other screens
      'price': sellingPrice,
        'wholesalePrice': wholesalePrice,
        'quantity': quantity,
        'reorderLevel': reorderLevel,
        'reorderQuantity': reorderQuantity,
        'imageUrl': imageUrl,
        'supplier': supplier,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'warehouseAllocations': warehouseAllocations,
      };

  WholesaleProduct copyWith({
    String? id,
    String? name,
    String? sku,
    String? category,
    double? costPrice,
    double? sellingPrice,
    double? wholesalePrice,
    int? quantity,
    int? reorderLevel,
    int? reorderQuantity,
    String? imageUrl,
    String? supplier,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, int>? warehouseAllocations,
  }) {
    return WholesaleProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      quantity: quantity ?? this.quantity,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      reorderQuantity: reorderQuantity ?? this.reorderQuantity,
      imageUrl: imageUrl ?? this.imageUrl,
      supplier: supplier ?? this.supplier,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      warehouseAllocations: warehouseAllocations ?? this.warehouseAllocations,
    );
  }
}

class PurchaseOrder {
  final String id;
  final String supplier;
  final List<OrderItem> items;
  final double subtotal;
  final double tax;
  final double total;
  final String? receivingWarehouseId;
  final String status; // pending, confirmed, delivered, cancelled
  final DateTime createdAt;
  final DateTime? expectedDelivery;
  final DateTime? deliveredAt;
  final String? notes;

  PurchaseOrder({
    required this.id,
    required this.supplier,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    this.receivingWarehouseId,
    this.status = 'pending',
    DateTime? createdAt,
    this.expectedDelivery,
    this.deliveredAt,
    this.notes,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      if (value is Timestamp) return value.toDate();
      return null;
    }

    return PurchaseOrder(
      id: (json['id'] as String?) ?? '',
      supplier: (json['supplier'] as String?) ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      receivingWarehouseId: json['receivingWarehouseId'] as String?,
      createdAt: _parseDate(json['createdAt']),
      expectedDelivery: _parseDate(json['expectedDelivery']),
      deliveredAt: _parseDate(json['deliveredAt']),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'supplier': supplier,
        'items': items.map((e) => e.toJson()).toList(),
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'status': status,
        'receivingWarehouseId': receivingWarehouseId,
        'createdAt': createdAt.toIso8601String(),
        'expectedDelivery': expectedDelivery?.toIso8601String(),
        'deliveredAt': deliveredAt?.toIso8601String(),
        'notes': notes,
      };
}

class OrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double total;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        productId: (json['productId'] as String?) ?? '',
        productName: (json['productName'] as String?) ?? '',
        quantity: (json['quantity'] as int?) ?? 0,
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
        total: (json['total'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'total': total,
      };
}

class StockTransfer {
  final String id;
  final String fromWarehouse;
  final String toWarehouse;
  final List<OrderItem> items;
  final String status; // pending, in-transit, received, cancelled
  final DateTime createdAt;
  final DateTime? receivedAt;
  final String? notes;

  StockTransfer({
    required this.id,
    required this.fromWarehouse,
    required this.toWarehouse,
    required this.items,
    this.status = 'pending',
    DateTime? createdAt,
    this.receivedAt,
    this.notes,
  }) : createdAt = createdAt ?? DateTime.now();

  factory StockTransfer.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      if (value is Timestamp) return value.toDate();
      return null;
    }

    return StockTransfer(
      id: (json['id'] as String?) ?? '',
      fromWarehouse: (json['fromWarehouse'] as String?) ?? '',
      toWarehouse: (json['toWarehouse'] as String?) ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      status: json['status'] as String? ?? 'pending',
      createdAt: _parseDate(json['createdAt']),
      receivedAt: _parseDate(json['receivedAt']),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromWarehouse': fromWarehouse,
        'toWarehouse': toWarehouse,
        'items': items.map((e) => e.toJson()).toList(),
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'receivedAt': receivedAt?.toIso8601String(),
        'notes': notes,
      };
}

// ============= PROVIDER =============

class WarehouseLocation {
  final String id;
  final String name;
  final String location;
  final String? address;
  final String? phone;

  WarehouseLocation({
    required this.id,
    required this.name,
    required this.location,
    this.address,
    this.phone,
  });

  factory WarehouseLocation.fromJson(Map<String, dynamic> json, String id) => WarehouseLocation(
        id: id,
        name: json['name'] ?? '',
        location: json['location'] ?? '',
        address: json['address'] as String?,
        phone: json['phone'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'location': location,
        'address': address,
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class WholesaleProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _businessId;

  List<WholesaleProduct> _products = [];
  List<PurchaseOrder> _purchaseOrders = [];
  List<StockTransfer> _stockTransfers = [];
  String _errorMessage = '';

  // Warehouses (similar to retail stores)
  List<WarehouseLocation> _warehouses = [];

  // Getters
  List<WholesaleProduct> get products => _products;
  List<PurchaseOrder> get purchaseOrders => _purchaseOrders;
  List<StockTransfer> get stockTransfers => _stockTransfers;
  List<WarehouseLocation> get warehouses => List.unmodifiable(_warehouses);
  String get errorMessage => _errorMessage;
  bool get hasBusinessContext => _businessId != null && _businessId!.isNotEmpty;

  // Initialize with business ID
  void initializeWithBusinessId(String businessId) {
    _businessId = businessId;
    loadProducts();
    loadPurchaseOrders();
    loadStockTransfers();
    loadWarehouses();
  }

  // ============= PRODUCTS =============

  Future<void> loadProducts() async {
    if (_businessId == null) return;
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory')
          .get();

      final tempProducts = <WholesaleProduct>[];
      for (final doc in snapshot.docs) {
        try {
          final data = {...doc.data(), 'id': doc.id};
          tempProducts.add(WholesaleProduct.fromJson(data));
        } catch (e, st) {
          debugPrint('[WholesaleProvider] Failed to parse product ${doc.id}: $e\n$st');
        }
      }
      _products = tempProducts;

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading products: $e';
      debugPrint('[WholesaleProvider] $e');
      notifyListeners();
    }
  }

  Future<void> addProduct(WholesaleProduct product) async {
    if (_businessId == null) return;
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory')
          .doc(product.id)
          .set(product.toJson());

      _products.add(product);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error adding product: $e';
      debugPrint('[WholesaleProvider] $e');
    }
  }

  Future<void> updateProduct(WholesaleProduct product) async {
    if (_businessId == null) return;
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory')
          .doc(product.id)
          .update(product.toJson());

      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error updating product: $e';
      debugPrint('[WholesaleProvider] $e');
    }
  }

  Future<void> deleteProduct(String productId) async {
    if (_businessId == null) return;
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('inventory')
          .doc(productId)
          .delete();

      _products.removeWhere((p) => p.id == productId);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error deleting product: $e';
      debugPrint('[WholesaleProvider] $e');
    }
  }

  // ============= PURCHASE ORDERS =============

  Future<void> loadPurchaseOrders() async {
    if (_businessId == null) return;
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('purchaseOrders')
          .orderBy('createdAt', descending: true)
          .get();

      final tempOrders = <PurchaseOrder>[];
      for (final doc in snapshot.docs) {
        try {
          final data = {...doc.data(), 'id': doc.id};
          tempOrders.add(PurchaseOrder.fromJson(data));
        } catch (e, st) {
          debugPrint('[WholesaleProvider] Failed to parse purchase order ${doc.id}: $e\n$st');
        }
      }
      _purchaseOrders = tempOrders;

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading purchase orders: $e';
      debugPrint('[WholesaleProvider] $e');
    }
  }

  Future<void> createPurchaseOrder(PurchaseOrder order) async {
    if (_businessId == null) return;
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('purchaseOrders')
          .doc(order.id)
          .set(order.toJson());

      _purchaseOrders.insert(0, order);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error creating purchase order: $e';
      debugPrint('[WholesaleProvider] $e');
    }
  }

  Future<void> updatePurchaseOrderStatus(String orderId, String status) async {
    if (_businessId == null) return;
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('purchaseOrders')
          .doc(orderId)
          .update({
        'status': status,
        'deliveredAt':
            status == 'delivered' ? FieldValue.serverTimestamp() : null,
      });

      final index = _purchaseOrders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        // If delivered, allocate received quantities to the receiving warehouse
        if (status == 'delivered') {
          final po = _purchaseOrders[index];
          final wid = po.receivingWarehouseId;
          if (wid != null && wid.isNotEmpty) {
            for (final item in po.items) {
              final productIdx = _products.indexWhere((p) => p.id == item.productId);
              if (productIdx != -1) {
                final product = _products[productIdx];
                final newQty = (product.quantity + item.quantity).clamp(0, 999999);
                final allocs = Map<String, int>.from(product.warehouseAllocations);
                allocs[wid] = (allocs[wid] ?? 0) + item.quantity;

                // persist changes
                await _firestore
                    .collection('businesses')
                    .doc(_businessId)
                    .collection('inventory')
                    .doc(product.id)
                    .update({
                  'quantity': newQty,
                  'warehouseAllocations': allocs,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                // update local cache
                _products[productIdx] = product.copyWith(quantity: newQty, warehouseAllocations: allocs);
              }
            }
          }
        }

        // Reload to get updated data
        await loadPurchaseOrders();
      }
    } catch (e) {
      _errorMessage = 'Error updating purchase order: $e';
      debugPrint('[WholesaleProvider] $e');
    }
  }

  // ============= STOCK TRANSFERS =============

  Future<void> loadStockTransfers() async {
    if (_businessId == null) return;
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('stockTransfers')
          .orderBy('createdAt', descending: true)
          .get();

      final tempTransfers = <StockTransfer>[];
      for (final doc in snapshot.docs) {
        try {
          final data = {...doc.data(), 'id': doc.id};
          tempTransfers.add(StockTransfer.fromJson(data));
        } catch (e, st) {
          debugPrint('[WholesaleProvider] Failed to parse stock transfer ${doc.id}: $e\n$st');
        }
      }
      _stockTransfers = tempTransfers;

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading stock transfers: $e';
      debugPrint('[WholesaleProvider] $e');
    }
  }

  // ============= WAREHOUSES =============

  Future<void> loadWarehouses() async {
    if (_businessId == null) return;
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('warehouses')
          .get();

      _warehouses = snapshot.docs
          .map((doc) => WarehouseLocation.fromJson(doc.data(), doc.id))
          .toList();

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading warehouses: $e';
      debugPrint('[WholesaleProvider] $e');
    }
  }

  Future<void> addWarehouse(WarehouseLocation w) async {
    if (_businessId == null) return;
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('warehouses')
          .doc(w.id)
          .set(w.toJson());
      _warehouses.add(w);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error adding warehouse: $e';
      debugPrint('[WholesaleProvider] $e');
    }
  }

  Future<void> updateWarehouse(WarehouseLocation w) async {
    if (_businessId == null) return;
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('warehouses')
          .doc(w.id)
          .update(w.toJson());

      final idx = _warehouses.indexWhere((x) => x.id == w.id);
      if (idx != -1) {
        _warehouses[idx] = w;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error updating warehouse: $e';
      debugPrint('[WholesaleProvider] $e');
    }
  }

  Future<void> deleteWarehouse(String id) async {
    if (_businessId == null) return;
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('warehouses')
          .doc(id)
          .delete();
      _warehouses.removeWhere((w) => w.id == id);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error deleting warehouse: $e';
      debugPrint('[WholesaleProvider] $e');
    }
  }

  Future<void> createStockTransfer(StockTransfer transfer) async {
    if (_businessId == null) return;
    try {
      // Deduct from source warehouse
      for (final item in transfer.items) {
        final product = _products.firstWhere((p) => p.id == item.productId,
            orElse: () => WholesaleProduct(
                  id: '',
                  name: '',
                  sku: '',
                  category: '',
                  costPrice: 0,
                  sellingPrice: 0,
                  wholesalePrice: 0,
                  quantity: 0,
                  reorderLevel: 0,
                  reorderQuantity: 0,
                  supplier: '',
                ));

        if (product.id.isNotEmpty) {
          final newQuantity =
              (product.quantity - item.quantity).clamp(0, 999999);
          final allocs = Map<String, int>.from(product.warehouseAllocations);
          final currentSource = allocs[transfer.fromWarehouse] ?? 0;
          allocs[transfer.fromWarehouse] =
              (currentSource - item.quantity).clamp(0, 999999);
          await updateProduct(
            product.copyWith(
              quantity: newQuantity,
              warehouseAllocations: allocs,
            ),
          );
        }
      }

      // Create transfer record
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('stockTransfers')
          .doc(transfer.id)
          .set(transfer.toJson());

      _stockTransfers.insert(0, transfer);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error creating stock transfer: $e';
      debugPrint('[WholesaleProvider] $e');
    }
  }

  Future<void> updateStockTransferStatus(
      String transferId, String status) async {
    if (_businessId == null) return;
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('stockTransfers')
          .doc(transferId)
          .update({
        'status': status,
        'receivedAt':
            status == 'received' ? FieldValue.serverTimestamp() : null,
      });

      final index = _stockTransfers.indexWhere((t) => t.id == transferId);
      if (index != -1) {
        if (status == 'received') {
          final transfer = _stockTransfers[index];
          for (final item in transfer.items) {
            final productIdx = _products.indexWhere((p) => p.id == item.productId);
            if (productIdx == -1) continue;

            final product = _products[productIdx];
            final allocs = Map<String, int>.from(product.warehouseAllocations);
            allocs[transfer.toWarehouse] =
                (allocs[transfer.toWarehouse] ?? 0) + item.quantity;

            await _firestore
                .collection('businesses')
                .doc(_businessId)
                .collection('inventory')
                .doc(product.id)
                .update({
              'warehouseAllocations': allocs,
              'updatedAt': FieldValue.serverTimestamp(),
            });

            _products[productIdx] = product.copyWith(
              warehouseAllocations: allocs,
            );
          }
        }
        await loadStockTransfers();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error updating stock transfer: $e';
      debugPrint('[WholesaleProvider] $e');
    }
  }

  // ============= UTILITIES =============

  WholesaleProduct? getProductById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  List<WholesaleProduct> getLowStockProducts() {
    return _products.where((p) => p.quantity <= p.reorderLevel).toList();
  }

  double getTotalInventoryValue() {
    return _products.fold(0, (acc, p) => acc + (p.costPrice * p.quantity));
  }

  int getTotalItems() {
    return _products.fold(0, (acc, p) => acc + p.quantity);
  }

  int getWarehouseItemCount(String warehouseId) {
    return _products.fold<int>(
      0,
      (sum, product) => sum + (product.warehouseAllocations[warehouseId] ?? 0),
    );
  }

  double getWarehouseInventoryValue(String warehouseId) {
    return _products.fold<double>(
      0,
      (sum, product) =>
          sum +
          ((product.warehouseAllocations[warehouseId] ?? 0) * product.costPrice),
    );
  }

  int getPendingPurchaseOrdersCount() {
    return _purchaseOrders.where((o) => o.status == 'pending').length;
  }

  int getInTransitTransfersCount() {
    return _stockTransfers.where((t) => t.status == 'in-transit').length;
  }

  Map<String, int> getInventoryCategoryBreakdown() {
    final result = <String, int>{};
    for (final product in _products) {
      result[product.category] = (result[product.category] ?? 0) + product.quantity;
    }
    return result;
  }

  /// Create a sale record and update inventory similar to RetailProvider.checkout
  Future<void> createSale({
    required List<OrderItem> items,
    required String paymentMethod,
    double discount = 0.0,
    String? workerId,
    String? workerName,
    String? warehouseId,
  }) async {
    if (_businessId == null) return;
    try {
      final subtotal = items.fold<double>(0, (s, it) => s + it.total);
      final totalAmount = subtotal - discount;

      final saleData = {
        'items': items.map((it) => it.toJson()).toList(),
        'subtotal': subtotal,
        'discount': discount,
        'totalAmount': totalAmount,
        'paymentMethod': paymentMethod,
        'category': 'Wholesale',
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
        if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId,
      };

      if (workerId != null && workerId.isNotEmpty) {
        saleData['workerId'] = workerId;
        saleData['workerName'] = workerName ?? 'Unknown';
      }

      final saleRef = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('sales')
          .add(saleData);

      await saleRef.update({'orderId': saleRef.id});

      // Update inventory counts (deduct from warehouse allocation if warehouseId provided)
      for (final it in items) {
        final prodIdx = _products.indexWhere((p) => p.id == it.productId);
        if (prodIdx == -1) continue;
        final product = _products[prodIdx];

        int newQty = (product.quantity - it.quantity).clamp(0, 999999);

        final allocs = Map<String, int>.from(product.warehouseAllocations);
        if (warehouseId != null && warehouseId.isNotEmpty) {
          final currentAlloc = allocs[warehouseId] ?? 0;
          final newAlloc = (currentAlloc - it.quantity).clamp(0, 999999);
          allocs[warehouseId] = newAlloc;
        }

        // persist updated quantity and allocations
        await _firestore.collection('businesses').doc(_businessId).collection('inventory').doc(product.id).update({
          'quantity': newQty,
          'warehouseAllocations': allocs,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // update local cache
        _products[prodIdx] = product.copyWith(quantity: newQty, warehouseAllocations: allocs);

        // send low stock notification if necessary
        if (newQty <= product.reorderLevel) {
          try {
            await BusinessNotificationManager.instance.notifyLowStock(
              businessId: _businessId!,
              itemName: product.name,
              currentStock: newQty,
              reorderPoint: product.reorderLevel,
            );
          } catch (e) {
            debugPrint('[WholesaleProvider] Failed to notify low stock: $e');
          }
        }
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error creating sale: $e';
      debugPrint('[WholesaleProvider] $e');
    }
  }
}

// Extension for copyWith
extension WholesaleProductCopyWith on WholesaleProduct {
  WholesaleProduct copyWith({
    String? id,
    String? name,
    String? sku,
    String? category,
    double? costPrice,
    double? sellingPrice,
    double? wholesalePrice,
    int? quantity,
    int? reorderLevel,
    int? reorderQuantity,
    String? imageUrl,
    String? supplier,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, int>? warehouseAllocations,
  }) {
    return WholesaleProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      quantity: quantity ?? this.quantity,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      reorderQuantity: reorderQuantity ?? this.reorderQuantity,
      imageUrl: imageUrl ?? this.imageUrl,
      supplier: supplier ?? this.supplier,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      warehouseAllocations: warehouseAllocations ?? this.warehouseAllocations,
    );
  }
}


extension WholesaleProviderSales on WholesaleProvider {
  /// Get today's sales total from Firestore sales collection
  Future<double> getTodaysSalesTotal() async {
    if (_businessId == null || _businessId!.isEmpty) {
      return 0.0;
    }

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      double sumSales(QuerySnapshot<Map<String, dynamic>> snapshot) {
        var totalSales = 0.0;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if ((data['status'] as String?)?.toLowerCase() != 'completed') {
            continue;
          }
          totalSales +=
              (data['finalAmount'] as num?)?.toDouble() ??
              (data['totalAmount'] as num?)?.toDouble() ??
              (data['total'] as num?)?.toDouble() ??
              0.0;
        }
        return totalSales;
      }

      try {
        final snapshot = await _firestore
            .collection('businesses')
            .doc(_businessId)
            .collection('sales')
            .where('createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('createdAt',
                isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .where('status', isEqualTo: 'completed')
            .get();

        final totalSales = sumSales(snapshot);
        debugPrint("[WholesaleProvider] Today's sales total: NGN $totalSales");
        return totalSales;
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('requires an index') ||
            msg.contains('FAILED_PRECONDITION')) {
          try {
            debugPrint(
                "[WholesaleProvider] Composite index required; falling back to date-only query for today's sales");
            final fallback = await _firestore
                .collection('businesses')
                .doc(_businessId)
                .collection('sales')
                .where('createdAt',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                .where('createdAt',
                    isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
                .get();

            final totalSales = sumSales(fallback);
            debugPrint(
                "[WholesaleProvider] Today's sales total (fallback): NGN $totalSales");
            return totalSales;
          } catch (e2) {
            debugPrint(
                "[WholesaleProvider] Fallback date-only query failed: $e2");
            return 0.0;
          }
        }

        debugPrint("[WholesaleProvider] Error fetching today's sales: $e");
        return 0.0;
      }
    } catch (e) {
      debugPrint("[WholesaleProvider] Error fetching today's sales: $e");
      return 0.0;
    }
  }
}
