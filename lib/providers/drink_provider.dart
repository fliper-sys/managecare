import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/whatsapp_service.dart';
import '../services/notification_and_email_service.dart';

// Models
class DrinkItem {
  final String id;
  final String name;
  final double pricePerBottle;
  final int bottlesPerCarton;
  final String emoji; // emoji used as avatar fallback
  final String? imageUrl;
  final String category;
  final String description;

  DrinkItem({
    required this.id,
    required this.name,
    required this.pricePerBottle,
    this.bottlesPerCarton = 1,
    this.emoji = '🥤',
    this.imageUrl,
    this.category = 'Drinks',
    this.description = '',
  });
}

class Modifier {
  final String id;
  final String name;
  final double price;

  Modifier({required this.id, required this.name, this.price = 0.0});
}

class StockItem {
  final String drinkId;
  int bottles; // individual bottles in stock
  int cartons; // full cartons in stock

  StockItem({required this.drinkId, this.bottles = 0, this.cartons = 0});

  int totalBottles(int bottlesPerCarton) =>
      bottles + (cartons * bottlesPerCarton);
}

class OrderLine {
  final String drinkId;
  int quantityBottles; // number of bottles ordered
  final List<Modifier> modifiers;
  double unitPrice;

  OrderLine({
    required this.drinkId,
    this.quantityBottles = 1,
    this.modifiers = const [],
    required this.unitPrice,
  });

  double lineTotal() {
    final mod = modifiers.fold<double>(0.0, (p, m) => p + m.price);
    return (unitPrice + mod) * quantityBottles;
  }
}

class Order {
  final String id;
  final List<OrderLine> lines;
  String status; // pending, served, paid, cancelled
  final DateTime createdAt;

  Order(
      {required this.id,
      this.lines = const [],
      this.status = 'pending',
      DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();

  double total() => lines.fold<double>(0.0, (sum, l) => sum + l.lineTotal());
}

class Shift {
  final String id;
  final String staffName;
  DateTime start;
  DateTime? end;
  double sales;

  Shift(
      {required this.id,
      required this.staffName,
      DateTime? start,
      this.end,
      this.sales = 0.0})
      : start = start ?? DateTime.now();
}

// Optional repository interface class placeholder (injected for persistence)
abstract class DrinkRepository {
  Future<void> saveOrder(Map<String, dynamic> data);

  Future<List<DrinkItem>> fetchDrinks();

  Future<List<StockItem>> fetchInventory();

  Future<void> updateStock(String drinkId, StockItem stock);

  Future<List<Order>> fetchOrders();

  Future<void> startShift(Shift shift);

  Future<void> saveDrink(DrinkItem drink);

  Future<void> deleteDrink(String drinkId);

  Future<void> deleteInventory(String drinkId);

  // Real-time streams
  Stream<List<DrinkItem>> streamDrinks();
  Stream<List<StockItem>> streamInventory();
  Stream<List<Order>> streamOrders();
}

class DrinkProvider extends ChangeNotifier {
  DrinkRepository? repository;
  StreamSubscription<List<DrinkItem>>? _drinksSub;
  StreamSubscription<List<StockItem>>? _inventorySub;
  StreamSubscription<List<Order>>? _ordersSub;

  String? _businessId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<DrinkItem> drinks = [];
  final List<Modifier> modifiers = [];
  final List<StockItem> inventory = [];
  final List<Order> orders = [];
  final List<Shift> shifts = [];

  DrinkProvider({this.repository}) {
    _initSampleData();
  }

  void setBusinessId(String businessId) {
    _businessId = businessId;
  }

  /// Initialize the provider with a persistence-backed repository.
  ///
  /// Pass an instance of a class that implements `DrinkRepository`
  /// (for example `DrinkRepositoryImpl`) which will be used to
  /// load drinks, inventory and orders from persistent storage.
  Future<void> initialize({required DrinkRepository repository}) async {
    this.repository = repository;
    try {
      final fetchedDrinks = await repository.fetchDrinks();
      drinks
        ..clear()
        ..addAll(fetchedDrinks);

      final fetchedInventory = await repository.fetchInventory();
      inventory
        ..clear()
        ..addAll(fetchedInventory);

      final fetchedOrders = await repository.fetchOrders();
      orders
        ..clear()
        ..addAll(fetchedOrders);

      notifyListeners();

      // subscribe to real-time updates if repository exposes streams
      try {
        _drinksSub?.cancel();
        _drinksSub = repository.streamDrinks().listen((list) {
          drinks
            ..clear()
            ..addAll(list);
          notifyListeners();
        });

        _inventorySub?.cancel();
        _inventorySub = repository.streamInventory().listen((list) {
          inventory
            ..clear()
            ..addAll(list);
          notifyListeners();
        });

        _ordersSub?.cancel();
        _ordersSub = repository.streamOrders().listen((list) {
          orders
            ..clear()
            ..addAll(list);
          notifyListeners();
        });
      } catch (_) {
        // repository may not support streams; ignore
      }
    } catch (e) {
      if (kDebugMode) print('DrinkProvider.initialize error: $e');
    }
  }

  @override
  void dispose() {
    _drinksSub?.cancel();
    _inventorySub?.cancel();
    _ordersSub?.cancel();
    super.dispose();
  }

  void _initSampleData() {
    drinks.addAll([
      DrinkItem(
          id: 'd1',
          name: 'Classic Lager',
          pricePerBottle: 3.5,
          bottlesPerCarton: 24,
          emoji: '🍺',
          imageUrl: null,
          description: 'Crisp lager'),
      DrinkItem(
          id: 'd2',
          name: 'Red Wine',
          pricePerBottle: 8.0,
          bottlesPerCarton: 6,
          emoji: '🍷',
          imageUrl: null,
          description: 'Medium-bodied wine'),
      DrinkItem(
          id: 'd3',
          name: 'Cocktail Mix',
          pricePerBottle: 5.0,
          bottlesPerCarton: 12,
          emoji: '🍹',
          imageUrl: null,
          description: 'Ready-to-serve mix'),
    ]);

    modifiers.addAll([
      Modifier(id: 'm1', name: 'Lemon Twist', price: 0.5),
      Modifier(id: 'm2', name: 'Extra Ice', price: 0.0),
      Modifier(id: 'm3', name: 'Top Shelf', price: 2.0),
    ]);

    inventory.addAll([
      StockItem(drinkId: 'd1', bottles: 10, cartons: 2),
      StockItem(drinkId: 'd2', bottles: 3, cartons: 1),
      StockItem(drinkId: 'd3', bottles: 24, cartons: 1),
    ]);

    // sample orders
    orders.addAll([
      Order(id: 'o1', lines: [
        OrderLine(drinkId: 'd1', quantityBottles: 2, unitPrice: 3.5)
      ]),
      Order(
          id: 'o2',
          lines: [OrderLine(drinkId: 'd3', quantityBottles: 1, unitPrice: 5.0)],
          status: 'served'),
    ]);

    // sample shift
    shifts.add(Shift(
        id: 's1',
        staffName: 'Emma',
        sales: 50.0,
        start: DateTime.now().subtract(const Duration(hours: 5))));
  }

  // Drinks
  void addDrink(DrinkItem d) {
    drinks.add(d);
    notifyListeners();
  }

  /// Convenience wrapper to persist a drink using the repository if available
  Future<void> saveDrink(DrinkItem d) async {
    final existingIndex = drinks.indexWhere((x) => x.id == d.id);
    if (existingIndex >= 0) {
      drinks[existingIndex] = d;
    } else {
      drinks.add(d);
    }
    notifyListeners();
    if (repository != null) {
      try {
        await repository!.saveDrink(d);
      } catch (e) {
        if (kDebugMode) print('Failed to save drink: $e');
      }
    }
  }

  DrinkItem? getDrinkById(String id) {
    try {
      return drinks.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  // Inventory
  StockItem? getStock(String drinkId) {
    try {
      return inventory.firstWhere((s) => s.drinkId == drinkId);
    } catch (_) {
      return null;
    }
  }

  void addStock(StockItem s) {
    inventory.add(s);
    notifyListeners();
  }

  void adjustStock(String drinkId, {int bottleDelta = 0, int cartonDelta = 0}) {
    final s = getStock(drinkId);
    if (s == null) return;
    s.bottles += bottleDelta;
    s.cartons += cartonDelta;
    if (s.bottles < 0) s.bottles = 0;
    if (s.cartons < 0) s.cartons = 0;
    notifyListeners();
  }

  int getTotalBottles(String drinkId) {
    final d = getDrinkById(drinkId);
    final s = getStock(drinkId);
    if (d == null || s == null) return 0;
    return s.totalBottles(d.bottlesPerCarton);
  }

  List<DrinkItem> getLowStockDrinks([int threshold = 6]) {
    return drinks.where((d) => getTotalBottles(d.id) <= threshold).toList();
  }

  // Orders
  void createOrder(Order o) async {
    orders.add(o);
    // decrease stock automatically
    for (final line in o.lines) {
      final d = getDrinkById(line.drinkId);
      final s = getStock(line.drinkId);
      if (d != null && s != null) {
        var needed = line.quantityBottles;
        // consume bottles first
        final fromBottles = (s.bottles >= needed) ? needed : s.bottles;
        s.bottles -= fromBottles;
        needed -= fromBottles;
        // if still needed, open cartons
        while (needed > 0 && s.cartons > 0) {
          s.cartons -= 1;
          s.bottles += d.bottlesPerCarton; // open a carton into bottles
          final take = (s.bottles >= needed) ? needed : s.bottles;
          s.bottles -= take;
          needed -= take;
        }
      }
    }

    notifyListeners();

    // persist order and stock changes if repository present
    if (repository != null) {
      try {
        await repository!.saveOrder({
          'id': o.id,
          'total': o.total(),
          'status': o.status,
          'createdAt': o.createdAt.toIso8601String()
        });

        // update stock documents for any modified stock items
        for (final line in o.lines) {
          final s = getStock(line.drinkId);
          if (s != null) {
            await repository!.updateStock(line.drinkId, s);
          }
        }
        // send WhatsApp notification to business owner (fire-and-forget)
        try {
          if (_businessId != null && _businessId!.isNotEmpty) {
            final whatsapp = WhatsAppService();
            final items = o.lines
                .map((l) => {
                      'drinkId': l.drinkId,
                      'name': getDrinkById(l.drinkId)?.name ?? '',
                      'quantity': l.quantityBottles
                    })
                .toList();
            // don't block order persistence — run in background
            whatsapp.sendOrderNotification(
                businessId: _businessId!,
                orderId: o.id,
                total: o.total(),
                items: items);
          }
        } catch (_) {}
      } catch (e) {
        if (kDebugMode) print('Error persisting order/stock: $e');
      }
    }
  }

  List<Order> getOpenOrders() => orders
      .where((o) => o.status == 'pending' || o.status == 'served')
      .toList();

  void updateOrderStatus(String orderId, String status) {
    final o = orders.firstWhere((x) => x.id == orderId);
    o.status = status;
    notifyListeners();
  }

  /// Process an order that has been marked as paid.
  /// This will create a sale record in the business `sales` collection,
  /// persist sale metadata, send notifications, and mark order as paid.
  Future<void> processPaidOrder(String orderId, String paymentMethod, {String? workerId, String? workerName}) async {
    final o = orders.firstWhere((x) => x.id == orderId);

    // Build sale payload
    final items = o.lines.map((l) {
      final d = getDrinkById(l.drinkId);
      return {
        'productId': l.drinkId,
        'productName': d?.name ?? 'Unknown',
        'quantity': l.quantityBottles,
        'unitPrice': l.unitPrice,
        'total': l.lineTotal(),
      };
    }).toList();

    final subtotal = o.total();
    final saleData = {
      'items': items,
      'subtotal': subtotal,
      'discount': 0.0,
      'total': subtotal,
      'totalAmount': subtotal,
      'finalAmount': subtotal,
      'paymentMethod': paymentMethod,
      'category': 'Drinks/Bar',
      'createdAt': FieldValue.serverTimestamp(),
      if (workerId != null) 'workerId': workerId,
      if (workerName != null) 'workerName': workerName,
      'linkedOrderId': orderId,
    };

    // Save sale to Firestore if we have business context
    try {
      if (_businessId != null && _businessId!.isNotEmpty) {
        final saleRef = await _firestore.collection('businesses').doc(_businessId).collection('sales').add(saleData);
        await saleRef.update({'orderId': saleRef.id});

        // Optionally, send owner notification/email
        try {
          final businessDoc = await _firestore.collection('businesses').doc(_businessId).get();
          final businessData = businessDoc.data() ?? <String, dynamic>{};
          final ownerEmail = (businessData['email'] as String?) ?? '';
          final businessName = (businessData['name'] as String?) ?? '';

          if (ownerEmail.isNotEmpty) {
            final notif = NotificationAndEmailService();
            final ownerSuccess = await notif.sendSalesNotification(
              ownerEmail: ownerEmail,
              businessName: businessName,
              customerName: 'Walk-in',
              customerEmail: '',
              totalAmount: subtotal,
              items: items.cast<Map<String, dynamic>>(),
              paymentMethod: paymentMethod,
              receiptNumber: saleRef.id,
              businessId: _businessId,
            );

            try {
              await notif.logNotificationEvent(
                businessId: _businessId!,
                type: 'sale',
                channel: 'email',
                recipient: ownerEmail,
                success: ownerSuccess,
                orderId: saleRef.id,
              );
            } catch (_) {}
          }
        } catch (e) {
          if (kDebugMode) print('Failed to notify owner: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Failed to create sale record for paid order: $e');
    }

    // Mark order as paid and persist via repository if available
    try {
      o.status = 'paid';
      notifyListeners();
      if (repository != null) {
        await repository!.saveOrder({
          'id': o.id,
          'total': o.total(),
          'status': o.status,
          'createdAt': o.createdAt.toIso8601String(),
        });
      }
    } catch (e) {
      if (kDebugMode) print('Failed to persist order status change: $e');
    }
  }

  double getTotalSales() {
    return orders.fold<double>(
        0.0, (sum, o) => sum + (o.status == 'paid' ? o.total() : 0.0));
  }

  Future<double> getTotalSalesFromFirestore() async {
    if (_businessId == null) {
      // Fallback to in-memory orders
      return getTotalSales();
    }

    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('orders')
          .where('status', isEqualTo: 'paid')
          .get();

      double totalSales = 0.0;
      for (final doc in snapshot.docs) {
        final amount = (doc['total'] as num?)?.toDouble() ?? 0.0;
        totalSales += amount;
      }

      debugPrint('[DrinkProvider] Firestore total sales: \u20a6$totalSales');
      return totalSales;
    } catch (e) {
      debugPrint(
          '[DrinkProvider] Error fetching from Firestore: $e, falling back to in-memory');
      return getTotalSales();
    }
  }

  // Shifts
  void startShift(Shift s) {
    shifts.add(s);
    notifyListeners();
  }

  void endShift(String shiftId) {
    final s = shifts.firstWhere((x) => x.id == shiftId);
    s.end = DateTime.now();
    notifyListeners();
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
          final amount = (doc['finalAmount'] as num?)?.toDouble() ?? 0.0;
          totalSales += amount;
        }

        debugPrint('[DrinkProvider] Today\'s sales total: ₦$totalSales');
        return totalSales;
      } catch (e) {
        // If Firestore requires a composite index, fall back to a date-only
        // query and filter the status on the client side. This avoids a
        // hard failure in the app when indexes are missing.
        final msg = e.toString();
        if (msg.contains('requires an index') || msg.contains('FAILED_PRECONDITION')) {
          try {
            debugPrint('[DrinkProvider] Composite index required; falling back to date-only query for today\'s sales');
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
              final amount = (doc['finalAmount'] as num?)?.toDouble() ?? 0.0;
              totalSales += amount;
            }

            debugPrint('[DrinkProvider] Today\'s sales total (fallback): ₦$totalSales');
            return totalSales;
          } catch (e2) {
            debugPrint('[DrinkProvider] Fallback date-only query failed: $e2');
            return 0.0;
          }
        }

        debugPrint('[DrinkProvider] Error fetching today\'s sales: $e');
        return 0.0;
      }
    } catch (e) {
      debugPrint('[DrinkProvider] Error fetching today\'s sales: $e');
      return 0.0;
    }
  }
}

