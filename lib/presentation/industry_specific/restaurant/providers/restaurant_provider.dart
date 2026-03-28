import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../providers/retail_provider.dart';
import '../../../../services/business_notification_manager.dart';
import '../../../../services/notification_and_email_service.dart';

// Helper to parse DateTime values from Firestore documents (strings, Timestamps, ints)
DateTime? _parseNullableDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  if (v is Timestamp) return v.toDate();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

DateTime _parseDateOrNow(dynamic v) => _parseNullableDate(v) ?? DateTime.now();

// Models
class MenuOptionChoice {
  final String id;
  final String name;
  final double priceModifier; // absolute modifier (e.g., +2.00)

  MenuOptionChoice({
    required this.id,
    required this.name,
    this.priceModifier = 0.0,
  });

  factory MenuOptionChoice.fromJson(Map<String, dynamic> json) => MenuOptionChoice(
        id: json['id'] as String,
        name: json['name'] as String,
        priceModifier: (json['priceModifier'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'priceModifier': priceModifier,
      };
}

class MenuOption {
  final String id;
  final String name;
  final List<MenuOptionChoice> choices; // radio/checkbox

  MenuOption({
    required this.id,
    required this.name,
    this.choices = const [],
  });

  factory MenuOption.fromJson(Map<String, dynamic> json) => MenuOption(
        id: json['id'] as String,
        name: json['name'] as String,
        choices: (json['choices'] as List<dynamic>?)
                ?.map((e) => MenuOptionChoice.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'choices': choices.map((c) => c.toJson()).toList(),
      };
}

class MenuItem {
  final String id;
  final String name;
  final String category;
  final double price;
  final double? cost; // cost price for inventory integration
  final String? description;
  final bool available;
  final int preparationTime; // in minutes
  final String? imageUrl;
  final double? rating;
  final int? reviewCount;
  final String? inventoryProductId; // link to inventory product if available
  final int? inventoryStock;
  final List<MenuOption> options;

  MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.cost,
    this.description,
    this.available = true,
    this.preparationTime = 15,
    this.imageUrl,
    this.rating,
    this.reviewCount,
    this.inventoryProductId,
    this.inventoryStock,
    this.options = const [],
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        price: (json['price'] as num).toDouble(),
        cost: (json['cost'] as num?)?.toDouble(),
        description: json['description'] as String?,
        available: json['available'] as bool? ?? true,
        preparationTime: json['preparationTime'] as int? ?? 15,
        imageUrl: json['imageUrl'] as String?,
        rating: (json['rating'] as num?)?.toDouble(),
        reviewCount: json['reviewCount'] as int?,
        inventoryProductId: json['inventoryProductId'] as String?,
        inventoryStock: json['inventoryStock'] as int?,
        options: (json['options'] as List<dynamic>?)
                ?.map((e) => MenuOption.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'price': price,
        'cost': cost,
        'description': description,
        'available': available,
        'preparationTime': preparationTime,
        'imageUrl': imageUrl,
        'rating': rating,
        'reviewCount': reviewCount,
        'inventoryProductId': inventoryProductId,
        'inventoryStock': inventoryStock,
        'options': options.map((o) => o.toJson()).toList(),
      };
}

class OrderItem {
  final String id;
  final String menuItemId;
  final String menuItemName;
  final double price;
  final int quantity;
  final String? specialInstructions;
  final double subtotal;
  final String? inventoryProductId;
  final List<Map<String, dynamic>> selectedOptions; // {name, choiceName, price}

  OrderItem({
    required this.id,
    required this.menuItemId,
    required this.menuItemName,
    required this.price,
    required this.quantity,
    this.specialInstructions,
    required this.subtotal,
    this.inventoryProductId,
    this.selectedOptions = const [],
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: json['id'] as String,
        menuItemId: json['menuItemId'] as String,
        menuItemName: json['menuItemName'] as String,
        price: (json['price'] as num).toDouble(),
        quantity: json['quantity'] as int,
        specialInstructions: json['specialInstructions'] as String?,
        subtotal: (json['subtotal'] as num).toDouble(),
        inventoryProductId: json['inventoryProductId'] as String?,
        selectedOptions: (json['selectedOptions'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'menuItemId': menuItemId,
        'menuItemName': menuItemName,
        'price': price,
        'quantity': quantity,
        'specialInstructions': specialInstructions,
        'subtotal': subtotal,
        'inventoryProductId': inventoryProductId,
        'selectedOptions': selectedOptions,
      };
}

class TableInfo {
  final String id;
  final int tableNumber;
  final int capacity;
  final String status; // available, occupied, reserved, maintenance
  final String? assignedWaiterId;
  final String? assignedWaiterName;
  final DateTime? reservedUntil;

  TableInfo({
    required this.id,
    required this.tableNumber,
    required this.capacity,
    this.status = 'available',
    this.assignedWaiterId,
    this.assignedWaiterName,
    this.reservedUntil,
  });

  factory TableInfo.fromJson(Map<String, dynamic> json) => TableInfo(
        id: json['id'] as String,
        tableNumber: json['tableNumber'] as int,
        capacity: json['capacity'] as int,
        status: json['status'] as String? ?? 'available',
        assignedWaiterId: json['assignedWaiterId'] as String?,
        assignedWaiterName: json['assignedWaiterName'] as String?,
        reservedUntil: _parseNullableDate(json['reservedUntil']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tableNumber': tableNumber,
        'capacity': capacity,
        'status': status,
        'assignedWaiterId': assignedWaiterId,
        'assignedWaiterName': assignedWaiterName,
        'reservedUntil': reservedUntil?.toIso8601String(),
      };
}

class RestaurantOrder {
  final String id;
  final String businessId;
  final String? tableId;
  final int? tableNumber;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final List<OrderItem> items;
  final double subtotal;
  final double tax;
  final double discount;
  final double total;
  final String
      status; // pending, confirmed, preparing, ready, served, completed, cancelled
  final String paymentStatus; // pending, partial, paid, refunded
  final String? assignedChefId;
  final String? assignedWaiterId;
  final List<String> paymentMethods; // e.g., ['cash','card']
  final List<Map<String, dynamic>> paymentBreakdown; // list of {method, amount, transactionId}
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? notes;
  final String orderType; // dine-in, takeaway, delivery

  RestaurantOrder({
    required this.id,
    required this.businessId,
    this.tableId,
    this.tableNumber,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    required this.items,
    required this.subtotal,
    required this.tax,
    this.discount = 0,
    required this.total,
    this.status = 'pending',
    this.paymentStatus = 'pending',
    this.assignedChefId,
    this.assignedWaiterId,
    this.paymentMethods = const [],
    this.paymentBreakdown = const [],
    DateTime? createdAt,
    this.completedAt,
    this.notes,
    this.orderType = 'dine-in',
  }) : createdAt = createdAt ?? DateTime.now();

  factory RestaurantOrder.fromJson(Map<String, dynamic> json) =>
      RestaurantOrder(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        tableId: json['tableId'] as String?,
        tableNumber: json['tableNumber'] as int?,
        customerId: json['customerId'] as String?,
        customerName: json['customerName'] as String?,
        customerPhone: json['customerPhone'] as String?,
        customerEmail: json['customerEmail'] as String?,
        items: (json['items'] as List<dynamic>?)
                ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        subtotal: (json['subtotal'] as num).toDouble(),
        tax: (json['tax'] as num).toDouble(),
        discount: (json['discount'] as num?)?.toDouble() ?? 0,
        total: (json['total'] as num).toDouble(),
        status: json['status'] as String? ?? 'pending',
        paymentStatus: json['paymentStatus'] as String? ??
            ((json['status'] as String?) == 'completed' ? 'paid' : 'pending'),
        assignedChefId: json['assignedChefId'] as String?,
        assignedWaiterId: json['assignedWaiterId'] as String?,
        paymentMethods: (json['paymentMethods'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        paymentBreakdown: (json['paymentBreakdown'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>)).toList() ?? [],
        createdAt: _parseDateOrNow(json['createdAt']),
        completedAt: _parseNullableDate(json['completedAt']),
        notes: json['notes'] as String?,
        orderType: json['orderType'] as String? ?? 'dine-in',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'tableId': tableId,
        'tableNumber': tableNumber,
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerEmail': customerEmail,
        'items': items.map((e) => e.toJson()).toList(),
        'subtotal': subtotal,
        'tax': tax,
        'discount': discount,
        'total': total,
        'status': status,
        'paymentStatus': paymentStatus,
        'assignedChefId': assignedChefId,
        'assignedWaiterId': assignedWaiterId,
        'paymentMethods': paymentMethods,
        'paymentBreakdown': paymentBreakdown,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'notes': notes,
        'orderType': orderType,
      };

  RestaurantOrder copyWith({
    String? id,
    String? businessId,
    String? tableId,
    int? tableNumber,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    List<OrderItem>? items,
    double? subtotal,
    double? tax,
    double? discount,
    double? total,
    String? status,
    String? paymentStatus,
    String? assignedChefId,
    String? assignedWaiterId,
    List<String>? paymentMethods,
    List<Map<String, dynamic>>? paymentBreakdown,
    DateTime? createdAt,
    DateTime? completedAt,
    String? notes,
    String? orderType,
  }) {
    return RestaurantOrder(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      tableId: tableId ?? this.tableId,
      tableNumber: tableNumber ?? this.tableNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      assignedChefId: assignedChefId ?? this.assignedChefId,
      assignedWaiterId: assignedWaiterId ?? this.assignedWaiterId,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      paymentBreakdown: paymentBreakdown ?? this.paymentBreakdown,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      orderType: orderType ?? this.orderType,
    );
  }
}

class Reservation {
  final String id;
  final String businessId;
  final String customerName;
  final String customerPhone;
  final int guestCount;
  final DateTime reservationDateTime;
  final String status; // pending, confirmed, checked-in, completed, cancelled
  final String? specialRequests;
  final String? tableId;
  final int? tableNumber;
  final String? assignedWaiterId;
  final String? assignedWaiterName;
  final DateTime createdAt;

  Reservation({
    required this.id,
    required this.businessId,
    required this.customerName,
    required this.customerPhone,
    required this.guestCount,
    required this.reservationDateTime,
    this.status = 'pending',
    this.specialRequests,
    this.tableId,
    this.tableNumber,
    this.assignedWaiterId,
    this.assignedWaiterName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Reservation.fromJson(Map<String, dynamic> json) => Reservation(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        customerName: json['customerName'] as String,
        customerPhone: json['customerPhone'] as String,
        guestCount: json['guestCount'] as int,
        reservationDateTime: _parseDateOrNow(json['reservationDateTime']),
        status: json['status'] as String? ?? 'pending',
        specialRequests: json['specialRequests'] as String?,
        tableId: json['tableId'] as String?,
        tableNumber: json['tableNumber'] as int?,
        assignedWaiterId: json['assignedWaiterId'] as String?,
        assignedWaiterName: json['assignedWaiterName'] as String?,
        createdAt: _parseDateOrNow(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'guestCount': guestCount,
        'reservationDateTime': reservationDateTime.toIso8601String(),
        'status': status,
        'specialRequests': specialRequests,
        'tableId': tableId,
        'tableNumber': tableNumber,
        'assignedWaiterId': assignedWaiterId,
        'assignedWaiterName': assignedWaiterName,
        'createdAt': createdAt.toIso8601String(),
      };
}

class Server {
  final String id;
  final String name;
  final String phone;
  final String role;
  final bool active;

  Server({
    required this.id,
    required this.name,
    this.phone = '',
    this.role = 'waiter',
    this.active = true,
  });

  factory Server.fromJson(Map<String, dynamic> json) => Server(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String? ?? '',
        role: json['role'] as String? ?? 'waiter',
        active: json['active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'role': role,
        'active': active,
      };
}

class RestaurantProvider extends ChangeNotifier {
  final BusinessNotificationManager _notificationManager =
      BusinessNotificationManager.instance;
  final NotificationAndEmailService _notificationLogger =
      NotificationAndEmailService();
  // State
  List<MenuItem> _menuItems = [];
  List<RestaurantOrder> _orders = [];
  List<TableInfo> _tables = [];
  List<Reservation> _reservations = [];
  List<Server> _servers = [];
  bool _isLoading = false;
  String? _error;
  String _businessId = '';

  // Supported payment methods (Flutterwave intentionally excluded)
  static const List<String> supportedPaymentMethods = [
    'cash',
    'card',
    'pos',
    'bank_transfer',
    'mobile_money',
  ];

  // Getters
  List<MenuItem> get menuItems => _menuItems;
  List<RestaurantOrder> get orders => _orders;
  List<TableInfo> get tables => _tables;
  List<Reservation> get reservations => _reservations;
  List<Server> get servers => _servers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<String> get availablePaymentMethods => RestaurantProvider.supportedPaymentMethods;
  List<RestaurantOrder> get recentOrders {
    final items = [..._orders];
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  List<RestaurantOrder> get pendingPaymentOrders {
    return _orders.where((order) {
      return order.paymentStatus != 'paid' &&
          order.status != 'completed' &&
          order.status != 'cancelled';
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Initialize
  void setBusinessId(String businessId) {
    _businessId = businessId;
  }

  String _resolveBusinessId(RestaurantOrder order) {
    if (order.businessId.isNotEmpty) return order.businessId;
    return _businessId;
  }

  String _shortOrderId(String orderId) {
    if (orderId.length <= 6) return orderId.toUpperCase();
    return orderId.substring(orderId.length - 6).toUpperCase();
  }

  Future<void> _logOrderNotification({
    required String businessId,
    required String type,
    required String recipient,
    String? orderId,
  }) async {
    try {
      await _notificationLogger.logNotificationEvent(
        businessId: businessId,
        type: type,
        channel: 'local',
        recipient: recipient,
        success: true,
        orderId: orderId,
      );
    } catch (e) {
      debugPrint('[RestaurantProvider] notification log failed: $e');
    }
  }

  // Menu Management
  Future<void> initializeMenu({String? businessId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final bid = businessId ?? _businessId;
      if (bid.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('restaurant_menu')
            .where('businessId', isEqualTo: bid)
            .get();
        _menuItems = snap.docs
            .map((d) => MenuItem.fromJson({...d.data(), 'id': d.id}))
            .toList();
        if (kDebugMode) print('[RestaurantProvider] initializeMenu: loaded ${_menuItems.length} items for business $bid');
      } else {
        // no business configured yet - keep empty list
        _menuItems = [];
      }
      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
    }
    notifyListeners();
  }

  /// Synchronize menu items with retail inventory prices/stock when available
  void syncMenuWithRetail(RetailProvider retail) {
    if (retail.products.isEmpty) return;

    final updated = <MenuItem>[];
    for (final m in _menuItems) {
      // Try find match by barcode/sku or name
      final matched = retail.products.firstWhere(
          (p) => (p.barcode != null && p.barcode!.isNotEmpty && p.barcode == m.id) ||
              p.name.toLowerCase() == m.name.toLowerCase(),
          orElse: () => Product(
                id: '',
                name: '',
                price: 0,
                stock: 0,
                category: 'Unknown',
              ));

      if (matched.id.isNotEmpty) {
        updated.add(MenuItem(
          id: m.id,
          name: m.name,
          category: m.category,
          price: matched.price, // align price with inventory
          description: m.description,
          available: matched.stock > 0,
          preparationTime: m.preparationTime,
          imageUrl: matched.imageUrl ?? m.imageUrl,
          rating: m.rating,
          reviewCount: m.reviewCount,
          inventoryProductId: matched.id,
          inventoryStock: matched.stock as int,
        ));
      } else {
        updated.add(m);
      }
    }

    _menuItems = updated;
    notifyListeners();
  }

  Future<void> addMenuItem(MenuItem item) async {
    if (_businessId.isNotEmpty) {
      final data = item.toJson();
      data['businessId'] = _businessId;
      final docRef = await FirebaseFirestore.instance.collection('restaurant_menu').add(data);
      final created = MenuItem.fromJson({...data, 'id': docRef.id});
      _menuItems.add(created);
    } else {
      _menuItems.add(item);
    }
    notifyListeners();
  }

  Future<void> updateMenuItem(String id, MenuItem updatedItem) async {
    final index = _menuItems.indexWhere((item) => item.id == id);
    if (index != -1) {
      if (_businessId.isNotEmpty) {
        final data = updatedItem.toJson();
        data['businessId'] = _businessId;
        await FirebaseFirestore.instance.collection('restaurant_menu').doc(id).set(data, SetOptions(merge: true));
      }
      _menuItems[index] = updatedItem;
      notifyListeners();
    }
  }

  Future<void> deleteMenuItem(String id) async {
    _menuItems.removeWhere((item) => item.id == id);
    if (_businessId.isNotEmpty && id.isNotEmpty) {
      await FirebaseFirestore.instance.collection('restaurant_menu').doc(id).delete();
    }
    notifyListeners();
  }

  List<MenuItem> getMenuByCategory(String category) {
    return _menuItems.where((item) => item.category == category).toList();
  }

  // Order Management
  Future<void> initializeOrders({String? businessId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final bid = businessId ?? _businessId;
      if (bid.isNotEmpty) {
        final snap = await FirebaseFirestore.instance.collection('restaurant_orders').where('businessId', isEqualTo: bid).orderBy('createdAt', descending: true).get();
        _orders = snap.docs.map((d) => RestaurantOrder.fromJson({...d.data(), 'id': d.id})).toList();
        if (kDebugMode) print('[RestaurantProvider] initializeOrders: loaded ${_orders.length} orders for business $bid');
      } else {
        // no business configured yet - start empty
        _orders = [];
      }
      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
    }
    notifyListeners();
  }

  Future<void> createOrder(RestaurantOrder order) async {
    RestaurantOrder persistedOrder = order;

    if (_businessId.isNotEmpty) {
      final data = order.toJson();
      data['businessId'] = _businessId;

      if (order.id.isEmpty) {
        final docRef = await FirebaseFirestore.instance.collection('restaurant_orders').add(data);
        persistedOrder = RestaurantOrder.fromJson({...data, 'id': docRef.id});
        _orders.insert(0, persistedOrder);
      } else {
        await FirebaseFirestore.instance.collection('restaurant_orders').doc(order.id).set(data, SetOptions(merge: true));
        final index = _orders.indexWhere((o) => o.id == order.id);
        if (index != -1) {
          _orders[index] = order;
        } else {
          _orders.insert(0, order);
        }
        persistedOrder = order;
      }
    } else {
      _orders.insert(0, order);
      persistedOrder = order;
    }

    final businessId = _resolveBusinessId(persistedOrder);
    if (businessId.isNotEmpty) {
      try {
        await _notificationManager.notifyOrderPlaced(
          businessId: businessId,
          orderId: _shortOrderId(persistedOrder.id),
          itemCount: persistedOrder.items.fold<int>(
            0,
            (sum, item) => sum + item.quantity,
          ),
          total: persistedOrder.total,
        );
        await _logOrderNotification(
          businessId: businessId,
          type: 'restaurant_order_created',
          recipient: persistedOrder.customerName ??
              'Table ${persistedOrder.tableNumber ?? 'N/A'}',
          orderId: persistedOrder.id,
        );
        if (persistedOrder.paymentStatus == 'paid') {
          await _notificationManager.notifyPaymentReceived(
            businessId: businessId,
            customerName: persistedOrder.customerName ??
                'Table ${persistedOrder.tableNumber ?? 'N/A'}',
            amount: persistedOrder.total,
            transactionId: persistedOrder.id,
          );
          await _logOrderNotification(
            businessId: businessId,
            type: 'restaurant_payment_received',
            recipient: persistedOrder.customerName ??
                'Table ${persistedOrder.tableNumber ?? 'N/A'}',
            orderId: persistedOrder.id,
          );
        }
      } catch (e) {
        debugPrint('[RestaurantProvider] createOrder notification error: $e');
      }
    }

    notifyListeners();
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index != -1) {
      final order = _orders[index];
      final updatedOrder = order.copyWith(
        status: newStatus,
        completedAt: newStatus == 'completed' ? DateTime.now() : order.completedAt,
      );

      _orders[index] = updatedOrder;

      if (_businessId.isNotEmpty && order.id.isNotEmpty) {
        await FirebaseFirestore.instance.collection('restaurant_orders').doc(order.id).set({
          'status': newStatus,
          'completedAt': updatedOrder.completedAt?.toIso8601String(),
          'paymentStatus': updatedOrder.paymentStatus,
        }, SetOptions(merge: true));
      }

      final businessId = _resolveBusinessId(updatedOrder);
      if (businessId.isNotEmpty) {
        try {
          if (newStatus == 'preparing') {
            await _notificationManager.notifyOrderBeingPrepared(
              businessId: businessId,
              orderId: _shortOrderId(updatedOrder.id),
            );
          } else if (newStatus == 'ready') {
            await _notificationManager.notifyOrderReady(
              businessId: businessId,
              orderId: _shortOrderId(updatedOrder.id),
              orderType: updatedOrder.orderType,
            );
          } else if (newStatus == 'cancelled') {
            await _notificationManager.notifyOrderCancelled(
              businessId: businessId,
              orderId: _shortOrderId(updatedOrder.id),
              reason: 'Order cancelled',
            );
          }

          await _logOrderNotification(
            businessId: businessId,
            type: 'restaurant_order_${newStatus.replaceAll('-', '_')}',
            recipient:
                updatedOrder.customerName ?? 'Table ${updatedOrder.tableNumber ?? 'N/A'}',
            orderId: updatedOrder.id,
          );
        } catch (e) {
          debugPrint('[RestaurantProvider] updateOrderStatus notification error: $e');
        }
      }

      notifyListeners();
    }
  }

  void assignChefToOrder(String orderId, String chefId) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index != -1) {
      final order = _orders[index];
      _orders[index] = order.copyWith(assignedChefId: chefId);
      notifyListeners();
    }
  }

  void assignWaiterToOrder(String orderId, String waiterId) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index != -1) {
      final order = _orders[index];
      _orders[index] = order.copyWith(assignedWaiterId: waiterId);
      notifyListeners();
    }
  }

  Future<void> updateOrderPaymentStatus(
    String orderId, {
    required String paymentStatus,
    String? status,
    List<String>? paymentMethods,
    List<Map<String, dynamic>>? paymentBreakdown,
  }) async {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return;

    final order = _orders[index];
    final updatedOrder = order.copyWith(
      paymentStatus: paymentStatus,
      status: status ?? order.status,
      paymentMethods: paymentMethods ?? order.paymentMethods,
      paymentBreakdown: paymentBreakdown ?? order.paymentBreakdown,
      completedAt: (status ?? order.status) == 'completed'
          ? DateTime.now()
          : order.completedAt,
    );

    _orders[index] = updatedOrder;

    if (_businessId.isNotEmpty && order.id.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('restaurant_orders')
          .doc(order.id)
          .set({
        'paymentStatus': updatedOrder.paymentStatus,
        'status': updatedOrder.status,
        'paymentMethods': updatedOrder.paymentMethods,
        'paymentBreakdown': updatedOrder.paymentBreakdown,
        'completedAt': updatedOrder.completedAt?.toIso8601String(),
      }, SetOptions(merge: true));
    }

    final businessId = _resolveBusinessId(updatedOrder);
    if (businessId.isNotEmpty && paymentStatus == 'paid') {
      try {
        await _notificationManager.notifyPaymentReceived(
          businessId: businessId,
          customerName: updatedOrder.customerName ??
              'Table ${updatedOrder.tableNumber ?? 'N/A'}',
          amount: updatedOrder.total,
          transactionId: updatedOrder.id,
        );
        await _logOrderNotification(
          businessId: businessId,
          type: 'restaurant_payment_received',
          recipient: updatedOrder.customerName ??
              'Table ${updatedOrder.tableNumber ?? 'N/A'}',
          orderId: updatedOrder.id,
        );
      } catch (e) {
        debugPrint('[RestaurantProvider] updateOrderPaymentStatus notification error: $e');
      }
    }

    notifyListeners();
  }

  List<RestaurantOrder> getOrdersByStatus(String status) {
    return _orders.where((order) => order.status == status).toList();
  }

  List<RestaurantOrder> getOrdersByTableId(String tableId) {
    return _orders.where((order) => order.tableId == tableId).toList();
  }

  // Table Management
  Future<void> initializeTables({String? businessId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final bid = businessId ?? _businessId;
      if (bid.isNotEmpty) {
        final snap = await FirebaseFirestore.instance.collection('tables').where('businessId', isEqualTo: bid).orderBy('number').get();
        _tables = snap.docs.map((d) => TableInfo.fromJson({...d.data(), 'id': d.id})).toList();
        if (kDebugMode) print('[RestaurantProvider] initializeTables: loaded ${_tables.length} tables for business $bid');
      } else {
        // no business configured yet - start empty
        _tables = [];
      }
      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
    }
    notifyListeners();
  }

  void updateTableStatus(String tableId, String newStatus) {
    final index = _tables.indexWhere((table) => table.id == tableId);
    if (index != -1) {
      final table = _tables[index];
      _tables[index] = TableInfo(
        id: table.id,
        tableNumber: table.tableNumber,
        capacity: table.capacity,
        status: newStatus,
        assignedWaiterId: table.assignedWaiterId,
        assignedWaiterName: table.assignedWaiterName,
        reservedUntil: table.reservedUntil,
      );
      notifyListeners();
    }
  }

  void assignWaiterToTable(String tableId, String waiterId, String waiterName) {
    final index = _tables.indexWhere((table) => table.id == tableId);
    if (index != -1) {
      final table = _tables[index];
      _tables[index] = TableInfo(
        id: table.id,
        tableNumber: table.tableNumber,
        capacity: table.capacity,
        status: table.status,
        assignedWaiterId: waiterId,
        assignedWaiterName: waiterName,
        reservedUntil: table.reservedUntil,
      );
      notifyListeners();
    }
  }

  Future<void> addTable(TableInfo table) async {
    if (_businessId.isNotEmpty) {
      final data = table.toJson();
      data['businessId'] = _businessId;
      final docRef = await FirebaseFirestore.instance.collection('tables').add(data);
      final created = TableInfo.fromJson({...data, 'id': docRef.id});
      _tables.add(created);
    } else {
      _tables.add(table);
    }
    notifyListeners();
  }

  Future<void> updateTable(TableInfo table) async {
    final index = _tables.indexWhere((t) => t.id == table.id);
    if (index != -1) {
      if (_businessId.isNotEmpty && table.id.isNotEmpty) {
        final data = table.toJson();
        data['businessId'] = _businessId;
        await FirebaseFirestore.instance.collection('tables').doc(table.id).set(data, SetOptions(merge: true));
      }
      _tables[index] = table;
      notifyListeners();
    }
  }

  Future<void> deleteTable(String id) async {
    _tables.removeWhere((t) => t.id == id);
    if (_businessId.isNotEmpty && id.isNotEmpty) {
      await FirebaseFirestore.instance.collection('tables').doc(id).delete();
    }
    notifyListeners();
  }

  List<TableInfo> getAvailableTables() {
    return _tables.where((table) => table.status == 'available').toList();
  }

  // Reservation Management
  Future<void> initializeReservations({String? businessId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final bid = businessId ?? _businessId;
      if (bid.isNotEmpty) {
        final snap = await FirebaseFirestore.instance.collection('restaurant_reservations').where('businessId', isEqualTo: bid).orderBy('reservationDateTime').get();
        _reservations = snap.docs.map((d) => Reservation.fromJson({...d.data(), 'id': d.id})).toList();
      } else {
        _reservations = [];
      }
      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
    }
    notifyListeners();
  }

  Future<void> createReservation(Reservation reservation) async {
    if (_businessId.isNotEmpty) {
      final data = reservation.toJson();
      data['businessId'] = _businessId;
      final docRef = await FirebaseFirestore.instance.collection('restaurant_reservations').add(data);
      final created = Reservation.fromJson({...data, 'id': docRef.id});
      _reservations.add(created);
      // mark table reserved if provided
      if (created.tableId != null && created.tableId!.isNotEmpty) {
        final index = _tables.indexWhere((t) => t.id == created.tableId);
        if (index != -1) {
          final table = _tables[index];
          _tables[index] = TableInfo(
              id: table.id,
              tableNumber: table.tableNumber,
              capacity: table.capacity,
              status: 'reserved',
              assignedWaiterId: table.assignedWaiterId,
              assignedWaiterName: table.assignedWaiterName,
              reservedUntil: created.reservationDateTime.add(Duration(hours: 2)));
        }
      }
    } else {
      _reservations.add(reservation);
    }
    notifyListeners();
  }

  Future<void> updateReservationStatus(String reservationId, String newStatus) async {
    final index = _reservations.indexWhere((res) => res.id == reservationId);
    if (index != -1) {
      final reservation = _reservations[index];
      final updated = Reservation(
        id: reservation.id,
        businessId: reservation.businessId,
        customerName: reservation.customerName,
        customerPhone: reservation.customerPhone,
        guestCount: reservation.guestCount,
        reservationDateTime: reservation.reservationDateTime,
        status: newStatus,
        specialRequests: reservation.specialRequests,
        tableId: reservation.tableId,
        tableNumber: reservation.tableNumber,
        assignedWaiterId: reservation.assignedWaiterId,
        assignedWaiterName: reservation.assignedWaiterName,
        createdAt: reservation.createdAt,
      );

      _reservations[index] = updated;

      if (_businessId.isNotEmpty && reservation.id.isNotEmpty) {
        await FirebaseFirestore.instance.collection('restaurant_reservations').doc(reservation.id).set({'status': newStatus}, SetOptions(merge: true));
      }

      // if confirmed, mark table reserved
      if (newStatus == 'confirmed' && reservation.tableId != null) {
        final tIndex = _tables.indexWhere((t) => t.id == reservation.tableId);
        if (tIndex != -1) {
          final table = _tables[tIndex];
          _tables[tIndex] = TableInfo(
            id: table.id,
            tableNumber: table.tableNumber,
            capacity: table.capacity,
            status: 'reserved',
            assignedWaiterId: reservation.assignedWaiterId ?? table.assignedWaiterId,
            assignedWaiterName: reservation.assignedWaiterName ?? table.assignedWaiterName,
            reservedUntil: reservation.reservationDateTime.add(Duration(hours: 2)),
          );
        }
      }

      notifyListeners();
    }
  }

  List<Reservation> getTodayReservations() {
    final today = DateTime.now();
    return _reservations
        .where((res) =>
            res.reservationDateTime.year == today.year &&
            res.reservationDateTime.month == today.month &&
            res.reservationDateTime.day == today.day)
        .toList();
  }

  // Servers / Staff Management
  Future<void> initializeServers({String? businessId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final bid = businessId ?? _businessId;
      if (bid.isNotEmpty) {
        final snap = await FirebaseFirestore.instance.collection('restaurant_staff').where('businessId', isEqualTo: bid).get();
        _servers = snap.docs.map((d) => Server.fromJson({...d.data(), 'id': d.id})).toList();
      } else {
        _servers = [];
      }
      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
    }
    notifyListeners();
  }

  Future<void> addServer(Server server) async {
    if (_businessId.isNotEmpty) {
      final data = server.toJson();
      data['businessId'] = _businessId;
      final docRef = await FirebaseFirestore.instance.collection('restaurant_staff').add(data);
      final created = Server.fromJson({...data, 'id': docRef.id});
      _servers.add(created);
    } else {
      _servers.add(server);
    }
    notifyListeners();
  }

  Future<void> updateServer(Server server) async {
    final index = _servers.indexWhere((s) => s.id == server.id);
    if (index != -1) {
      if (_businessId.isNotEmpty && server.id.isNotEmpty) {
        final data = server.toJson();
        data['businessId'] = _businessId;
        await FirebaseFirestore.instance.collection('restaurant_staff').doc(server.id).set(data, SetOptions(merge: true));
      }
      _servers[index] = server;
      notifyListeners();
    }
  }

  Future<void> deleteServer(String id) async {
    _servers.removeWhere((s) => s.id == id);
    if (_businessId.isNotEmpty && id.isNotEmpty) {
      await FirebaseFirestore.instance.collection('restaurant_staff').doc(id).delete();
    }
    notifyListeners();
  }

  // Analytics
  Map<String, dynamic> getDailyStats() {
    final today = DateTime.now();
    final todayOrders = _orders
        .where((order) =>
            order.createdAt.year == today.year &&
            order.createdAt.month == today.month &&
            order.createdAt.day == today.day &&
            order.status == 'completed')
        .toList();

    final totalRevenue =
        todayOrders.fold(0.0, (sum, order) => sum + order.total);
    final totalOrders = todayOrders.length;
    final averageOrderValue = totalOrders == 0 ? 0 : totalRevenue / totalOrders;

    return {
      'totalRevenue': totalRevenue,
      'totalOrders': totalOrders,
      'averageOrderValue': averageOrderValue,
      'tablesInUse':
          _tables.where((table) => table.status == 'occupied').length,
    };
  }

  Map<String, dynamic> getOrderStats() {
    return {
      'pending': _orders.where((o) => o.status == 'pending').length,
      'confirmed': _orders.where((o) => o.status == 'confirmed').length,
      'preparing': _orders.where((o) => o.status == 'preparing').length,
      'ready': _orders.where((o) => o.status == 'ready').length,
      'served': _orders.where((o) => o.status == 'served').length,
      'completed': _orders.where((o) => o.status == 'completed').length,
      'pendingPayment': pendingPaymentOrders.length,
    };
  }


}

