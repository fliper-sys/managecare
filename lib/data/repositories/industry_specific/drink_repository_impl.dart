import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../../providers/drink_provider.dart';

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
        final raw = doc['createdAt'];
        DateTime createdAt;
        try {
          if (raw == null) {
            createdAt = DateTime.now();
          } else if (raw is fs.Timestamp) {
            createdAt = raw.toDate();
          } else if (raw is String) {
            createdAt = DateTime.tryParse(raw) ?? DateTime.now();
          } else if (raw is DateTime) {
            createdAt = raw;
          } else {
            createdAt = DateTime.now();
          }
        } catch (_) {
          createdAt = DateTime.now();
        }

        return Order(
          id: doc['id'],
          status: doc['status'] ?? 'pending',
          createdAt: createdAt,
          lines: [],
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
                final raw = doc['createdAt'];
                DateTime createdAt;
                try {
                  if (raw == null) {
                    createdAt = DateTime.now();
                  } else if (raw is fs.Timestamp) {
                    createdAt = raw.toDate();
                  } else if (raw is String) {
                    createdAt = DateTime.tryParse(raw) ?? DateTime.now();
                  } else if (raw is DateTime) {
                    createdAt = raw;
                  } else {
                    createdAt = DateTime.now();
                  }
                } catch (_) {
                  createdAt = DateTime.now();
                }

                return Order(
                  id: doc.id,
                  status: doc['status'] ?? 'pending',
                  createdAt: createdAt,
                  lines: [],
                );
              }).toList());
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

