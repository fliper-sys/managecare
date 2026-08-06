import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/whatsapp_service.dart';
import '../services/notification_and_email_service.dart';
import '../services/sync_service.dart';
import '../data/local/database_helper.dart';
import '../core/utils/connectivity_helper.dart';

DateTime? _parseDrinkNullableDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

DateTime _parseDrinkDateOrNow(dynamic value) =>
    _parseDrinkNullableDate(value) ?? DateTime.now();

double _readDrinkDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _readDrinkInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

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

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    return OrderLine(
      drinkId: (json['drinkId'] ?? json['productId'] ?? '').toString(),
      quantityBottles:
          _readDrinkInt(json['quantityBottles'] ?? json['quantity']),
      modifiers: (json['modifiers'] as List<dynamic>?)
              ?.map((item) {
                final map = Map<String, dynamic>.from(item as Map);
                return Modifier(
                  id: (map['id'] ?? '').toString(),
                  name: (map['name'] ?? '').toString(),
                  price: _readDrinkDouble(map['price']),
                );
              })
              .toList() ??
          const [],
      unitPrice: _readDrinkDouble(json['unitPrice'] ?? json['price']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'drinkId': drinkId,
      'quantityBottles': quantityBottles,
      'unitPrice': unitPrice,
      'modifiers': modifiers
          .map((mod) => {'id': mod.id, 'name': mod.name, 'price': mod.price})
          .toList(),
    };
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

class BarInvoice {
  final String id;
  final String businessId;
  final String invoiceNumber;
  final String invoiceType; // invoice, tab, table
  final String status; // open, converted, cancelled
  final String? customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? tableLabel;
  final String? notes;
  final List<OrderLine> lines;
  final double subtotal;
  final double tax;
  final double discount;
  final double total;
  final DateTime createdAt;
  final DateTime? convertedAt;
  final String? linkedSaleId;
  final String? paymentMethod;
  final String? workerId;
  final String? workerName;
  final String? storeId;

  const BarInvoice({
    required this.id,
    required this.businessId,
    required this.invoiceNumber,
    required this.invoiceType,
    required this.status,
    this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.tableLabel,
    this.notes,
    this.lines = const [],
    required this.subtotal,
    this.tax = 0.0,
    this.discount = 0.0,
    required this.total,
    required this.createdAt,
    this.convertedAt,
    this.linkedSaleId,
    this.paymentMethod,
    this.workerId,
    this.workerName,
    this.storeId,
  });

  int get itemCount =>
      lines.fold<int>(0, (sum, line) => sum + line.quantityBottles);

  factory BarInvoice.fromJson(Map<String, dynamic> json) {
    final parsedLines = (json['lines'] as List<dynamic>?)
            ?.map((item) =>
                OrderLine.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList() ??
        (json['items'] as List<dynamic>?)
                ?.map((item) =>
                    OrderLine.fromJson(Map<String, dynamic>.from(item as Map)))
                .toList() ??
            const <OrderLine>[];
    final calculatedSubtotal =
        parsedLines.fold<double>(0.0, (sum, line) => sum + line.lineTotal());
    final storedSubtotal = _readDrinkDouble(json['subtotal']);
    final tax = _readDrinkDouble(json['tax']);
    final discount = _readDrinkDouble(json['discount']);
    final subtotal = storedSubtotal > 0 ? storedSubtotal : calculatedSubtotal;
    final storedTotal = _readDrinkDouble(
      json['total'] ?? json['totalAmount'] ?? json['finalAmount'],
    );
    final calculatedTotal =
        (subtotal + tax - discount).clamp(0.0, double.infinity).toDouble();

    return BarInvoice(
      id: (json['id'] ?? '').toString(),
      businessId: (json['businessId'] ?? '').toString(),
      invoiceNumber: (json['invoiceNumber'] ?? '').toString(),
      invoiceType: (json['invoiceType'] ?? 'invoice').toString(),
      status: (json['status'] ?? 'open').toString(),
      customerId: json['customerId']?.toString(),
      customerName: (json['customerName'] ?? 'Walk-in Customer').toString(),
      customerPhone: json['customerPhone']?.toString(),
      customerEmail: json['customerEmail']?.toString(),
      tableLabel: json['tableLabel']?.toString(),
      notes: json['notes']?.toString(),
      lines: parsedLines,
      subtotal: subtotal,
      tax: tax,
      discount: discount,
      total: storedTotal > 0 ? storedTotal : calculatedTotal,
      createdAt: _parseDrinkDateOrNow(json['createdAt']),
      convertedAt: _parseDrinkNullableDate(json['convertedAt']),
      linkedSaleId: json['linkedSaleId']?.toString(),
      paymentMethod: json['paymentMethod']?.toString(),
      workerId: json['workerId']?.toString(),
      workerName: json['workerName']?.toString(),
      storeId: json['storeId']?.toString(),
    );
  }

  BarInvoice copyWith({
    String? invoiceType,
    String? status,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? tableLabel,
    String? notes,
    List<OrderLine>? lines,
    double? subtotal,
    double? tax,
    double? discount,
    double? total,
    DateTime? convertedAt,
    String? linkedSaleId,
    String? paymentMethod,
    String? workerId,
    String? workerName,
    String? storeId,
  }) {
    return BarInvoice(
      id: id,
      businessId: businessId,
      invoiceNumber: invoiceNumber,
      invoiceType: invoiceType ?? this.invoiceType,
      status: status ?? this.status,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      tableLabel: tableLabel ?? this.tableLabel,
      notes: notes ?? this.notes,
      lines: lines ?? this.lines,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      createdAt: createdAt,
      convertedAt: convertedAt ?? this.convertedAt,
      linkedSaleId: linkedSaleId ?? this.linkedSaleId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      storeId: storeId ?? this.storeId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'businessId': businessId,
      'source': 'drink',
      'category': 'Drinks/Bar',
      'invoiceNumber': invoiceNumber,
      'invoiceType': invoiceType,
      'status': status,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'tableLabel': tableLabel,
      'notes': notes,
      'lines': lines.map((line) => line.toJson()).toList(),
      'items': lines
          .map((line) => {
                'productId': line.drinkId,
                'quantity': line.quantityBottles,
                'unitPrice': line.unitPrice,
                'total': line.lineTotal(),
              })
          .toList(),
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'total': total,
      'createdAt': createdAt,
      'convertedAt': convertedAt,
      'linkedSaleId': linkedSaleId,
      'paymentMethod': paymentMethod,
      'workerId': workerId,
      'workerName': workerName,
      'storeId': storeId,
    };
  }
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
  Future<void> saveInvoice(Map<String, dynamic> data);

  Future<List<DrinkItem>> fetchDrinks();

  Future<List<StockItem>> fetchInventory();

  Future<void> updateStock(String drinkId, StockItem stock);

  Future<List<Order>> fetchOrders();
  Future<List<BarInvoice>> fetchInvoices();

  Future<void> startShift(Shift shift);

  Future<void> saveDrink(DrinkItem drink);

  Future<void> deleteDrink(String drinkId);

  Future<void> deleteInventory(String drinkId);

  // Real-time streams
  Stream<List<DrinkItem>> streamDrinks();
  Stream<List<StockItem>> streamInventory();
  Stream<List<Order>> streamOrders();
  Stream<List<BarInvoice>> streamInvoices();

  // Saved bar table labels
  Future<List<String>> fetchBarTables();
  Future<void> saveBarTable(String label);
  Future<void> deleteBarTable(String label);

  // Sale creation (a paid order or a converted invoice becomes a sale)
  Future<Map<String, dynamic>> createSale(Map<String, dynamic> saleData);

  /// Sums completed sales for this business. Pass [period] ('today') for a
  /// server-side date filter, or an explicit [start]/[end] range; omitting
  /// both sums all-time.
  Future<double> getSalesTotal({String? period, DateTime? start, DateTime? end});

  /// Merges bar-specific extras (preferred table, common purchases) into a
  /// customer's metadata. Doesn't bump total_spent/total_transactions -
  /// those are already recorded by the sale itself (createSale carries the
  /// customer id, which the backend uses to update those stats), so a
  /// second increment here would double-count.
  Future<void> mergeCustomerMetadata(String customerId, Map<String, dynamic> metadata);
}

class DrinkProvider extends ChangeNotifier {
  DrinkRepository? repository;
  StreamSubscription<List<DrinkItem>>? _drinksSub;
  StreamSubscription<List<StockItem>>? _inventorySub;
  StreamSubscription<List<Order>>? _ordersSub;
  StreamSubscription<List<BarInvoice>>? _invoicesSub;

  String? _businessId;

  final List<DrinkItem> drinks = [];
  final List<Modifier> modifiers = [];
  final List<StockItem> inventory = [];
  final List<Order> orders = [];
  final List<BarInvoice> invoices = [];
  final List<Shift> shifts = [];
  final List<String> savedBarTables = [];

  DrinkProvider({this.repository}) {
    _initSampleData();
  }

  void setBusinessId(String businessId) {
    _businessId = businessId;
  }

  Future<void> loadSavedBarTables() async {
    if (_businessId == null || _businessId!.isEmpty || repository == null) return;

    try {
      final labels = await repository!.fetchBarTables();
      savedBarTables
        ..clear()
        ..addAll(labels);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('DrinkProvider.loadSavedBarTables error: $e');
      }
    }
  }

  Future<void> addSavedBarTable(String label) async {
    final businessId = _businessId;
    final trimmed = label.trim();
    if (businessId == null || businessId.isEmpty) {
      throw StateError('Business ID not found');
    }
    if (trimmed.isEmpty) {
      throw StateError('Table label is required');
    }
    if (repository == null) {
      throw StateError('No repository configured');
    }

    final exists = savedBarTables.any(
      (table) => table.trim().toLowerCase() == trimmed.toLowerCase(),
    );
    if (!exists) {
      savedBarTables.add(trimmed);
      savedBarTables.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      notifyListeners();
    }

    await repository!.saveBarTable(trimmed);
  }

  Future<void> deleteSavedBarTable(String label) async {
    final businessId = _businessId;
    final trimmed = label.trim();
    if (businessId == null || businessId.isEmpty || trimmed.isEmpty || repository == null) return;

    savedBarTables.removeWhere(
      (table) => table.trim().toLowerCase() == trimmed.toLowerCase(),
    );
    notifyListeners();

    try {
      await repository!.deleteBarTable(trimmed);
    } catch (e) {
      if (kDebugMode) {
        print('DrinkProvider.deleteSavedBarTable error: $e');
      }
    }
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

      final fetchedInvoices = await repository.fetchInvoices();
      invoices
        ..clear()
        ..addAll(fetchedInvoices);

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

        _invoicesSub?.cancel();
        _invoicesSub = repository.streamInvoices().listen((list) {
          invoices
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
    _invoicesSub?.cancel();
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
    _applyStockConsumption(o.lines);

    notifyListeners();

    // persist order and stock changes if repository present
    if (repository != null) {
      try {
        await repository!.saveOrder({
          'id': o.id,
          'total': o.total(),
          'status': o.status,
          'createdAt': o.createdAt,
          'lines': o.lines.map((line) => line.toJson()).toList(),
          'itemCount':
              o.lines.fold<int>(0, (sum, line) => sum + line.quantityBottles),
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

  List<BarInvoice> getOpenInvoices() => invoices
      .where((invoice) => invoice.status == 'open')
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<BarInvoice> getInvoiceHistory() {
    final all = List<BarInvoice>.from(invoices);
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  BarInvoice? getInvoiceById(String invoiceId) {
    try {
      return invoices.firstWhere((invoice) => invoice.id == invoiceId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistInvoice(BarInvoice invoice) async {
    if (repository == null) {
      throw StateError('No repository configured');
    }
    await repository!.saveInvoice(invoice.toJson());
  }

  Future<void> _persistStockItem(String drinkId, StockItem stock) async {
    if (repository == null) return;
    await repository!.updateStock(drinkId, stock);
  }

  void _applyStockConsumption(List<OrderLine> lines) {
    for (final line in lines) {
      final drink = getDrinkById(line.drinkId);
      final stock = getStock(line.drinkId);

      if (drink == null || stock == null) {
        throw StateError('Stock item not found for ${line.drinkId}');
      }

      final available = stock.totalBottles(drink.bottlesPerCarton);
      if (available < line.quantityBottles) {
        throw StateError('Insufficient stock for ${drink.name}');
      }

      var needed = line.quantityBottles;
      final fromBottles = stock.bottles >= needed ? needed : stock.bottles;
      stock.bottles -= fromBottles;
      needed -= fromBottles;

      while (needed > 0) {
        if (stock.cartons <= 0) {
          throw StateError('Insufficient stock for ${drink.name}');
        }

        stock.cartons -= 1;
        stock.bottles += drink.bottlesPerCarton;

        final take = stock.bottles >= needed ? needed : stock.bottles;
        stock.bottles -= take;
        needed -= take;
      }
    }
  }

  void _restoreStockConsumption(List<OrderLine> lines) {
    for (final line in lines) {
      final drink = getDrinkById(line.drinkId);
      final stock = getStock(line.drinkId);

      if (drink == null || stock == null) {
        // If drink or stock not found, we can't restore, but this shouldn't happen
        debugPrint('Warning: Cannot restore stock for ${line.drinkId} - drink or stock not found');
        continue;
      }

      // Add back the bottles to stock
      var toRestore = line.quantityBottles;
      
      // First, try to add to existing bottles
      stock.bottles += toRestore;
      
      // If we have more than a carton, convert to cartons
      while (stock.bottles >= drink.bottlesPerCarton) {
        stock.cartons += 1;
        stock.bottles -= drink.bottlesPerCarton;
      }
    }
  }

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
      'businessId': _businessId,
      'items': items,
      'subtotal': subtotal,
      'discount': 0.0,
      'total': subtotal,
      'totalAmount': subtotal,
      'finalAmount': subtotal,
      'status': 'completed',
      'paymentMethod': paymentMethod,
      if (workerId != null) 'workerId': workerId,
      if (workerName != null) 'workerName': workerName,
    };

    // Save sale to the backend if we have business context
    if (_businessId != null && _businessId!.isNotEmpty && repository != null) {
      // Check connectivity up front — same reasoning as RetailProvider.checkout:
      // a write attempted with no network would otherwise leave this sale
      // with no local record, no sync queue entry, and no way to tell the
      // cashier it's pending sync.
      final hasNetwork = await ConnectivityHelper.hasInternetConnection();
      if (!hasNetwork) {
        debugPrint('[DrinkProvider] No network detected, saving sale offline');
        await _saveSaleOffline(
          items: items,
          subtotal: subtotal,
          paymentMethod: paymentMethod,
          workerId: workerId,
        );
      } else {
        try {
          final created = await repository!.createSale(saleData);
          final saleId = created['id']?.toString() ?? '';

          // Optionally, send owner notification/email
          try {
            final businessData = await Supabase.instance.client
                    .from('businesses')
                    .select('name, email')
                    .eq('id', _businessId as Object)
                    .maybeSingle() ??
                <String, dynamic>{};
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
                receiptNumber: saleId,
                businessId: _businessId,
              );

              try {
                await notif.logNotificationEvent(
                  businessId: _businessId!,
                  type: 'sale',
                  channel: 'email',
                  recipient: ownerEmail,
                  success: ownerSuccess,
                  orderId: saleId,
                );
              } catch (_) {}
            }
          } catch (e) {
            if (kDebugMode) print('Failed to notify owner: $e');
          }
        } catch (e) {
          if (kDebugMode) print('Failed to create sale record for paid order: $e');
          debugPrint('[DrinkProvider] Remote sale write failed, saving locally: $e');
          await _saveSaleOffline(
            items: items,
            subtotal: subtotal,
            paymentMethod: paymentMethod,
            workerId: workerId,
          );
        }
      }
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
          'createdAt': o.createdAt,
          'lines': o.lines.map((line) => line.toJson()).toList(),
        });
      }
    } catch (e) {
      if (kDebugMode) print('Failed to persist order status change: $e');
    }
  }

  /// Persists a drinks/bar sale to the local database and queues it for
  /// sync when connectivity returns, mirroring RetailProvider._saveSaleOffline.
  /// Bottle-level stock consumption already happened in-memory at
  /// createOrder(); this ensures the sale itself isn't lost and that the
  /// generic sync pipeline (SyncService -> SalesRepositoryImpl) can still
  /// push a matching inventory deduction once the sale uploads.
  Future<void> _saveSaleOffline({
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required String paymentMethod,
    String? workerId,
  }) async {
    final dbHelper = DatabaseHelper.instance;
    final saleId = 'SALE-${DateTime.now().millisecondsSinceEpoch}';

    final localSale = {
      'id': saleId,
      'businessId': _businessId!,
      'totalAmount': subtotal,
      'discountAmount': 0.0,
      'taxAmount': 0.0,
      'finalAmount': subtotal,
      'paymentMethod': paymentMethod,
      'category': 'Drinks/Bar',
      'status': 'completed',
      'createdBy': workerId ?? '',
      'createdAt': DateTime.now().toIso8601String(),
      'syncStatus': 'pending',
    };

    await dbHelper.insert('sales', localSale);

    try {
      for (final item in items) {
        final itemId = '${DateTime.now().millisecondsSinceEpoch}-${item['productId']}';
        await dbHelper.insert('sale_items', {
          'id': itemId,
          'saleId': saleId,
          'productId': item['productId'],
          'productName': item['productName'],
          'quantity': item['quantity'],
          'unitPrice': item['unitPrice'],
          'discount': 0.0,
          'total': item['total'],
        });
      }
    } catch (e) {
      // Sale row exists without (all of) its items — remove it rather than
      // let a broken record sync later, and surface the failure so it
      // isn't silently mistaken for "queued fine".
      debugPrint('[DrinkProvider] Offline item save failed, rolling back local sale $saleId: $e');
      try {
        await dbHelper.delete('sale_items', where: 'saleId = ?', whereArgs: [saleId]);
        await dbHelper.delete('sales', where: 'id = ?', whereArgs: [saleId]);
      } catch (_) {}
      rethrow;
    }

    await dbHelper.addToSyncQueue(
        entityType: 'sale', entityId: saleId, action: 'create', data: localSale);

    // Try to trigger a background sync (no-op if still offline)
    try {
      final syncService = SyncService();
      await syncService.syncSales();
    } catch (_) {}
  }

  Future<BarInvoice> createInvoice({
    required List<OrderLine> lines,
    String invoiceType = 'invoice',
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? tableLabel,
    String? notes,
    String? workerId,
    String? workerName,
    String? storeId,
    double tax = 0.0,
    double discount = 0.0,
  }) async {
    final businessId = _businessId;
    if (businessId == null || businessId.isEmpty) {
      throw StateError('Business ID not found');
    }
    if (lines.isEmpty) {
      throw StateError('Cannot create an invoice without items');
    }

    // Validate stock availability before creating invoice
    for (final line in lines) {
      final drink = getDrinkById(line.drinkId);
      final stock = getStock(line.drinkId);
      if (drink == null || stock == null) {
        throw StateError('Stock item not found for ${line.drinkId}');
      }
      // For invoice creation, we don't deduct stock yet - only when converted to sale
    }

    final now = DateTime.now();
    final subtotal = lines.fold<double>(0.0, (sum, line) => sum + line.lineTotal());
    final safeTax = tax < 0 ? 0.0 : tax;
    final safeDiscount = discount < 0 ? 0.0 : discount;
    final total =
        (subtotal + safeTax - safeDiscount).clamp(0.0, double.infinity).toDouble();
    final invoice = BarInvoice(
      id: 'bar_invoice_${now.microsecondsSinceEpoch}',
      businessId: businessId,
      invoiceNumber:
          'INV-${now.millisecondsSinceEpoch.toString().substring(5)}',
      invoiceType: invoiceType,
      status: 'open',
      customerId: customerId,
      customerName: (customerName == null || customerName.trim().isEmpty)
          ? 'Walk-in Customer'
          : customerName.trim(),
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      tableLabel: tableLabel,
      notes: notes,
      lines: lines,
      subtotal: subtotal,
      tax: safeTax,
      discount: safeDiscount,
      total: total,
      createdAt: now,
      workerId: workerId,
      workerName: workerName,
      storeId: storeId,
    );

    await _persistInvoice(invoice);

    final index = invoices.indexWhere((item) => item.id == invoice.id);
    if (index >= 0) {
      invoices[index] = invoice;
    } else {
      invoices.insert(0, invoice);
    }
    notifyListeners();
    return invoice;
  }

  Future<BarInvoice> updateInvoice({
    required String invoiceId,
    required List<OrderLine> lines,
    String? invoiceType,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? tableLabel,
    String? notes,
    String? workerId,
    String? workerName,
    String? storeId,
    double tax = 0.0,
    double discount = 0.0,
  }) async {
    final invoice = getInvoiceById(invoiceId);
    if (invoice == null) {
      throw StateError('Invoice not found');
    }
    if (invoice.status == 'converted') {
      throw StateError('Converted invoices cannot be edited');
    }
    if (lines.isEmpty) {
      throw StateError('Cannot save an invoice without items');
    }

    // For invoice updates, stock will be deducted when converted to sale
    final subtotal =
        lines.fold<double>(0.0, (sum, line) => sum + line.lineTotal());
    final safeTax = tax < 0 ? 0.0 : tax;
    final safeDiscount = discount < 0 ? 0.0 : discount;
    final total =
        (subtotal + safeTax - safeDiscount).clamp(0.0, double.infinity).toDouble();
    final updatedInvoice = BarInvoice(
      id: invoice.id,
      businessId: invoice.businessId,
      invoiceNumber: invoice.invoiceNumber,
      invoiceType: invoiceType ?? invoice.invoiceType,
      status: 'open',
      customerId: customerId,
      customerName: (customerName == null || customerName.trim().isEmpty)
          ? 'Walk-in Customer'
          : customerName.trim(),
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      tableLabel: tableLabel,
      notes: notes,
      lines: lines,
      subtotal: subtotal,
      tax: safeTax,
      discount: safeDiscount,
      total: total,
      createdAt: invoice.createdAt,
      workerId: workerId ?? invoice.workerId,
      workerName: workerName ?? invoice.workerName,
      storeId: storeId ?? invoice.storeId,
    );

    await _persistInvoice(updatedInvoice);

    final index = invoices.indexWhere((item) => item.id == invoice.id);
    if (index >= 0) {
      invoices[index] = updatedInvoice;
    } else {
      invoices.insert(0, updatedInvoice);
    }

    notifyListeners();
    return updatedInvoice;
  }

  Future<BarInvoice> reopenInvoice(String invoiceId) async {
    final invoice = getInvoiceById(invoiceId);
    if (invoice == null) {
      throw StateError('Invoice not found');
    }
    if (invoice.status == 'converted') {
      throw StateError('Converted invoices cannot be reopened');
    }

    final reopenedInvoice = BarInvoice(
      id: invoice.id,
      businessId: invoice.businessId,
      invoiceNumber: invoice.invoiceNumber,
      invoiceType: invoice.invoiceType,
      status: 'open',
      customerId: invoice.customerId,
      customerName: invoice.customerName,
      customerPhone: invoice.customerPhone,
      customerEmail: invoice.customerEmail,
      tableLabel: invoice.tableLabel,
      notes: invoice.notes,
      lines: invoice.lines,
      subtotal: invoice.subtotal,
      tax: invoice.tax,
      discount: invoice.discount,
      total: invoice.total,
      createdAt: invoice.createdAt,
      workerId: invoice.workerId,
      workerName: invoice.workerName,
      storeId: invoice.storeId,
    );

    await _persistInvoice(reopenedInvoice);

    final index = invoices.indexWhere((item) => item.id == invoice.id);
    if (index >= 0) {
      invoices[index] = reopenedInvoice;
    } else {
      invoices.insert(0, reopenedInvoice);
    }

    notifyListeners();
    return reopenedInvoice;
  }

  Future<Map<String, dynamic>> convertInvoiceToSale(
    String invoiceId,
    String paymentMethod, {
    String? workerId,
    String? workerName,
  }) async {
    final businessId = _businessId;
    if (businessId == null || businessId.isEmpty) {
      throw StateError('Business ID not found');
    }

    final invoice = getInvoiceById(invoiceId);
    if (invoice == null) {
      throw StateError('Invoice not found');
    }
    if (invoice.status == 'converted') {
      throw StateError('Invoice has already been converted to a sale');
    }
    if (invoice.status == 'cancelled') {
      throw StateError('Cancelled invoices cannot be converted');
    }

    final items = invoice.lines.map((line) {
      final drink = getDrinkById(line.drinkId);
      return {
        'productId': line.drinkId,
        'productName': drink?.name ?? 'Unknown',
        'quantity': line.quantityBottles,
        'unitPrice': line.unitPrice,
        'total': line.lineTotal(),
      };
    }).toList();

    for (final line in invoice.lines) {
      final drink = getDrinkById(line.drinkId);
      final stock = getStock(line.drinkId);
      if (drink == null || stock == null) {
        throw StateError('Stock item not found for ${line.drinkId}');
      }
      if (stock.totalBottles(drink.bottlesPerCarton) < line.quantityBottles) {
        throw StateError('Insufficient stock for ${drink.name}');
      }
    }

    if (repository == null) {
      throw StateError('No repository configured');
    }

    final saleData = {
      'businessId': businessId,
      'items': items,
      'subtotal': invoice.subtotal,
      'tax': invoice.tax,
      'discount': invoice.discount,
      'total': invoice.total,
      'totalAmount': invoice.total,
      'finalAmount': invoice.total,
      'status': 'completed',
      'paymentMethod': paymentMethod,
      'customerId': invoice.customerId,
      'workerId': workerId ?? invoice.workerId,
      'workerName': workerName ?? invoice.workerName,
      'storeId': invoice.storeId,
      'notes': invoice.notes,
    };

    final created = await repository!.createSale(saleData);
    final saleId = created['id']?.toString() ?? '';

    // Deduct stock when invoice is converted to sale (payment received)
    _applyStockConsumption(invoice.lines);
    for (final line in invoice.lines) {
      final stock = getStock(line.drinkId);
      if (stock != null) {
        await _persistStockItem(line.drinkId, stock);
      }
    }

    final convertedInvoice = invoice.copyWith(
      status: 'converted',
      convertedAt: DateTime.now(),
      linkedSaleId: saleId,
      paymentMethod: paymentMethod,
    );

    await _persistInvoice(convertedInvoice);

    final invoiceIndex = invoices.indexWhere((item) => item.id == invoice.id);
    if (invoiceIndex >= 0) {
      invoices[invoiceIndex] = convertedInvoice;
    }

    if (invoice.customerId != null && invoice.customerId!.isNotEmpty) {
      await _updateCustomerAfterSale(
        invoice.customerId!,
        invoice.total,
        tableLabel: invoice.tableLabel,
        lines: invoice.lines,
      );
    }

    notifyListeners();

    return {
      'id': saleId,
      'items': items,
      'subtotal': invoice.subtotal,
      'tax': invoice.tax,
      'discount': invoice.discount,
      'total': invoice.total,
      'totalAmount': invoice.total,
      'finalAmount': invoice.total,
      'paymentMethod': paymentMethod,
      'timestamp': DateTime.now().toIso8601String(),
      'customerName': invoice.customerName,
      'customerId': invoice.customerId,
      'customerEmail': invoice.customerEmail,
      'customerPhone': invoice.customerPhone,
      'tableLabel': invoice.tableLabel,
      'invoiceId': invoice.id,
      'invoiceNumber': invoice.invoiceNumber,
      if ((workerId ?? invoice.workerId) != null)
        'workerId': workerId ?? invoice.workerId,
      if ((workerName ?? invoice.workerName) != null)
        'workerName': workerName ?? invoice.workerName,
    };
  }

  Future<void> cancelInvoice(String invoiceId) async {
    final invoice = getInvoiceById(invoiceId);
    if (invoice == null || invoice.status == 'converted') return;
    if (_businessId == null || _businessId!.isEmpty) return;

    final cancelledInvoice = invoice.copyWith(status: 'cancelled');
    await _persistInvoice(cancelledInvoice);

    final index = invoices.indexWhere((item) => item.id == invoice.id);
    if (index >= 0) {
      invoices[index] = cancelledInvoice;
      notifyListeners();
    }
  }

  Future<void> _updateCustomerAfterSale(
    String customerId,
    double purchaseAmount, {
    String? tableLabel,
    List<OrderLine> lines = const [],
  }) async {
    if (_businessId == null || _businessId!.isEmpty || repository == null) return;

    // total_transactions/total_spent/average_order_value were already
    // bumped when the sale was created (createSale carries the customer
    // id); only the bar-specific common-purchases tally needs a read here,
    // to merge quantities rather than overwrite them.
    try {
      final existing = await Supabase.instance.client
              .from('customers')
              .select('metadata')
              .eq('id', customerId)
              .maybeSingle() ??
          <String, dynamic>{};
      final existingMetadata = Map<String, dynamic>.from(existing['metadata'] as Map? ?? {});
      final commonPurchases =
          Map<String, dynamic>.from(existingMetadata['barCommonPurchases'] as Map? ?? {});
      for (final line in lines) {
        final drink = getDrinkById(line.drinkId);
        final key = line.drinkId;
        final current = Map<String, dynamic>.from(
          commonPurchases[key] as Map? ?? const <String, dynamic>{},
        );
        commonPurchases[key] = {
          'drinkId': line.drinkId,
          'name': drink?.name ?? current['name'] ?? line.drinkId,
          'quantity': ((current['quantity'] as num?)?.toInt() ?? 0) +
              line.quantityBottles,
          'lastPurchasedAt': DateTime.now().toIso8601String(),
        };
      }

      final metadata = {
        if ((tableLabel ?? '').trim().isNotEmpty) 'preferredBarTable': tableLabel!.trim(),
        if (commonPurchases.isNotEmpty) 'barCommonPurchases': commonPurchases,
      };
      if (metadata.isNotEmpty) {
        await repository!.mergeCustomerMetadata(customerId, metadata);
      }
    } catch (e) {
      if (kDebugMode) print('DrinkProvider._updateCustomerAfterSale error: $e');
    }
  }

  double getTotalSales() {
    return orders.fold<double>(
        0.0, (sum, o) => sum + (o.status == 'paid' ? o.total() : 0.0));
  }

  Future<double> getTotalSalesFromRemote() async {
    if (_businessId == null || repository == null) {
      // Fallback to in-memory orders
      return getTotalSales();
    }

    try {
      final totalSales = await repository!.getSalesTotal();
      debugPrint('[DrinkProvider] Remote total sales: \u20a6$totalSales');
      return totalSales;
    } catch (e) {
      debugPrint(
          '[DrinkProvider] Error fetching remote sales total: $e, falling back to in-memory');
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

  /// Get today's sales total from the backend's sales summary route.
  Future<double> getTodaysSalesTotal() async {
    if (_businessId == null || _businessId!.isEmpty || repository == null) {
      return 0.0;
    }

    try {
      final totalSales = await repository!.getSalesTotal(period: 'today');
      debugPrint('[DrinkProvider] Today\'s sales total: ₦$totalSales');
      return totalSales;
    } catch (e) {
      debugPrint('[DrinkProvider] Error fetching today\'s sales: $e');
      return 0.0;
    }
  }
}
