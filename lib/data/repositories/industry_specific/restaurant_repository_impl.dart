import 'package:cloud_firestore/cloud_firestore.dart';

class MenuItemModel {
  final String id;
  final String name;
  final String category;
  final double price;
  final int stock;

  MenuItemModel(
      {required this.id,
      required this.name,
      this.category = '',
      required this.price,
      required this.stock});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'price': price,
        'stock': stock
      };

  factory MenuItemModel.fromJson(Map<String, dynamic> json) => MenuItemModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        category: json['category'] ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        stock: json['stock'] ?? 0,
      );
}

class OrderModel {
  final String id;
  final String table;
  final List<Map<String, dynamic>> items;
  final double total;
  final DateTime createdAt;
  String status; // pending, ready, served, completed

  OrderModel(
      {required this.id,
      required this.table,
      required this.items,
      required this.total,
      DateTime? createdAt,
      this.status = 'pending'})
      : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'table': table,
        'items': items,
        'total': total,
        'createdAt': createdAt.toIso8601String(),
        'status': status,
      };

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
        id: json['id'] ?? '',
        table: json['table'] ?? '',
        items: List<Map<String, dynamic>>.from(json['items'] ?? []),
        total: (json['total'] as num?)?.toDouble() ?? 0.0,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        status: json['status'] ?? 'pending',
      );
}

/// Firestore implementation for restaurant repository
class RestaurantRepositoryImpl {
  final FirebaseFirestore _firestore;

  RestaurantRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<MenuItemModel>> fetchMenu({String? businessId}) async {
    try {
      var query = _firestore.collection('restaurant_menu') as Query;
      if (businessId != null) {
        query = query.where('businessId', isEqualTo: businessId);
      }
      final snapshot = await query.get();
      return snapshot.docs
          .map((d) => MenuItemModel.fromJson(
              {...d.data() as Map<String, dynamic>, 'id': d.id}))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<OrderModel>> fetchOrders(
      {String? businessId, String? status}) async {
    try {
      var query = _firestore.collection('restaurant_orders') as Query;
      if (businessId != null) {
        query = query.where('businessId', isEqualTo: businessId);
      }
      if (status != null) query = query.where('status', isEqualTo: status);
      final snapshot = await query.orderBy('createdAt', descending: true).get();
      return snapshot.docs
          .map((d) => OrderModel.fromJson(
              {...d.data() as Map<String, dynamic>, 'id': d.id}))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> syncMenuItem(MenuItemModel item,
      {String? businessId, Map<String, dynamic>? extraData}) async {
    try {
      final data = item.toJson();
      if (businessId != null) data['businessId'] = businessId;
      if (extraData != null) data.addAll(extraData);
      if (item.id.isNotEmpty) {
        await _firestore
            .collection('restaurant_menu')
            .doc(item.id)
            .set(data, SetOptions(merge: true));
      } else {
        await _firestore.collection('restaurant_menu').add(data);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createOrder(OrderModel order, {String? businessId}) async {
    try {
      final data = order.toJson();
      if (businessId != null) data['businessId'] = businessId;
      await _firestore.collection('restaurant_orders').add(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _firestore
          .collection('restaurant_orders')
          .doc(orderId)
          .update({'status': status});
    } catch (e) {
      rethrow;
    }
  }

  Future<List<MenuItemModel>> getLowStockItems(String businessId,
      {int threshold = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('restaurant_menu')
          .where('businessId', isEqualTo: businessId)
          .where('stock', isLessThan: threshold)
          .get();
      return snapshot.docs
          .map((d) => MenuItemModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}

