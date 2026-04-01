import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../../providers/drink_provider.dart';

DateTime _parseDrinkRepoDate(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is fs.Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.now();
}

class DrinkRepositoryImpl implements DrinkRepository {
  final fs.FirebaseFirestore firestore = fs.FirebaseFirestore.instance;
  final String businessId; // injected business ID

  DrinkRepositoryImpl({required this.businessId});

  @override
  Future<void> saveOrder(Map<String, dynamic> data) async {
    try {
      await firestore
          .collection('businesses')
          .doc(businessId)
          .collection('orders')
          .doc(data['id'])
          .set(data, fs.SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> saveInvoice(Map<String, dynamic> data) async {
    try {
      await firestore
          .collection('businesses')
          .doc(businessId)
          .collection('invoices')
          .doc((data['id'] ?? '').toString())
          .set(data, fs.SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> saveDrink(DrinkItem drink) async {
    try {
      await firestore
          .collection('businesses')
          .doc(businessId)
          .collection('inventory')
          .doc(drink.id)
          .set({
        'name': drink.name,
        'price': drink.pricePerBottle,
        'quantity': 0, // Default quantity when creating
        'emoji': drink.emoji,
        'imageUrl': drink.imageUrl,
        'category': drink.category,
        'description': drink.description,
        'barcode': '', // Default empty for drinks
        'sku': '', // Default empty for drinks
        'cost': 0.0, // Default cost
        'unit': 'bottle', // Default unit for drinks
        'minStock': 10, // Default min stock
        'trackExpiry': false, // Default no expiry tracking
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<DrinkItem>> fetchDrinks() async {
    try {
      final snapshot = await firestore
          .collection('businesses')
          .doc(businessId)
          .collection('inventory')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return DrinkItem(
          id: doc.id,
          name: data['name'] ?? '',
          pricePerBottle: (data['price'] ?? 0).toDouble(),
          bottlesPerCarton: 1,
          emoji: data['emoji'] ?? '🥤',
          imageUrl: data['imageUrl'],
          category: data['category'] ?? 'Drinks',
          description: data['description'] ?? '',
        );
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Stream<List<DrinkItem>> streamDrinks() {
    try {
      return firestore
          .collection('businesses')
          .doc(businessId)
          .collection('inventory')
          .snapshots()
          .map((snap) => snap.docs.map((doc) {
                final data = doc.data();
                return DrinkItem(
                  id: doc.id,
                  name: data['name'] ?? '',
                  pricePerBottle: (data['price'] ?? 0).toDouble(),
                  bottlesPerCarton: 1,
                  emoji: data['emoji'] ?? '🥤',
                  imageUrl: data['imageUrl'],
                  category: data['category'] ?? 'Drinks',
                  description: data['description'] ?? '',
                );
              }).toList());
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<StockItem>> fetchInventory() async {
    try {
      final snapshot = await firestore
          .collection('businesses')
          .doc(businessId)
          .collection('inventory')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        // Map quantity field to bottles to keep consistency
        final bottles = (data['bottles'] as num?)?.toInt() ??
            (data['quantity'] as num?)?.toInt() ??
            0;
        final cartons = (data['cartons'] as num?)?.toInt() ?? 0;
        return StockItem(
          drinkId: doc.id,
          bottles: bottles,
          cartons: cartons,
        );
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Stream<List<StockItem>> streamInventory() {
    try {
      return firestore
          .collection('businesses')
          .doc(businessId)
          .collection('inventory')
          .snapshots()
          .map((snap) => snap.docs.map((doc) {
                final data = doc.data();
                // Map quantity field to bottles to keep consistency
                final bottles = (data['bottles'] as num?)?.toInt() ??
                    (data['quantity'] as num?)?.toInt() ??
                    0;
                final cartons = (data['cartons'] as num?)?.toInt() ?? 0;
                return StockItem(
                  drinkId: doc.id,
                  bottles: bottles,
                  cartons: cartons,
                );
              }).toList());
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateStock(String drinkId, StockItem stock) async {
    try {
      await firestore
          .collection('businesses')
          .doc(businessId)
          .collection('inventory')
          .doc(drinkId)
          .update({
        'bottles': stock.bottles,
        'cartons': stock.cartons,
        'quantity': stock.bottles, // Keep quantity field in sync with bottles
      });
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Order>> fetchOrders() async {
    try {
      final snapshot = await firestore
          .collection('businesses')
          .doc(businessId)
          .collection('orders')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final createdAt = _parseDrinkRepoDate(data['createdAt']);
        final lines = (data['lines'] as List<dynamic>?)
                ?.map((item) =>
                    OrderLine.fromJson(Map<String, dynamic>.from(item as Map)))
                .toList() ??
            const <OrderLine>[];

        return Order(
          id: (data['id'] ?? doc.id).toString(),
          status: (data['status'] ?? 'pending').toString(),
          createdAt: createdAt,
          lines: lines,
        );
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Stream<List<Order>> streamOrders() {
    try {
      return firestore
          .collection('businesses')
          .doc(businessId)
          .collection('orders')
          .snapshots()
          .map((snap) => snap.docs.map((doc) {
                final data = doc.data();
                final createdAt = _parseDrinkRepoDate(data['createdAt']);
                final lines = (data['lines'] as List<dynamic>?)
                        ?.map((item) => OrderLine.fromJson(
                            Map<String, dynamic>.from(item as Map)))
                        .toList() ??
                    const <OrderLine>[];

                return Order(
                  id: (data['id'] ?? doc.id).toString(),
                  status: (data['status'] ?? 'pending').toString(),
                  createdAt: createdAt,
                  lines: lines,
                );
              }).toList());
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<BarInvoice>> fetchInvoices() async {
    try {
      final snapshot = await firestore
          .collection('businesses')
          .doc(businessId)
          .collection('invoices')
          .get();

      final invoices = snapshot.docs
          .map((doc) => BarInvoice.fromJson({...doc.data(), 'id': doc.id}))
          .where((invoice) =>
              invoice.businessId.isEmpty || invoice.businessId == businessId)
          .toList();
      invoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return invoices;
    } on fs.FirebaseException catch (e) {
      if (e.code == 'failed-precondition' ||
          (e.message ?? '').contains('requires an index')) {
        final fallback = await firestore
            .collection('businesses')
            .doc(businessId)
            .collection('invoices')
            .get();
        final invoices = fallback.docs
            .map((doc) => BarInvoice.fromJson({...doc.data(), 'id': doc.id}))
            .where((invoice) =>
                invoice.businessId.isEmpty || invoice.businessId == businessId)
            .toList();
        invoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return invoices;
      }
      rethrow;
    }
  }

  @override
  Stream<List<BarInvoice>> streamInvoices() {
    try {
      return firestore
          .collection('businesses')
          .doc(businessId)
          .collection('invoices')
          .snapshots()
          .map((snap) {
        final invoices = snap.docs
            .map((doc) => BarInvoice.fromJson({...doc.data(), 'id': doc.id}))
            .where((invoice) =>
                invoice.businessId.isEmpty || invoice.businessId == businessId)
            .toList();
        invoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return invoices;
      });
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> startShift(Shift shift) async {
    try {
      await firestore
          .collection('businesses')
          .doc(businessId)
          .collection('shifts')
          .doc(shift.id)
          .set({
        'staffName': shift.staffName,
        'start': shift.start.toIso8601String(),
        'sales': shift.sales,
      });
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteDrink(String drinkId) async {
    try {
      // Delete from inventory collection (official product storage)
      await firestore
          .collection('businesses')
          .doc(businessId)
          .collection('inventory')
          .doc(drinkId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  @override

  /// Delete inventory entry for a drink
  Future<void> deleteInventory(String drinkId) async {
    try {
      await firestore
          .collection('businesses')
          .doc(businessId)
          .collection('inventory')
          .doc(drinkId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }
}

