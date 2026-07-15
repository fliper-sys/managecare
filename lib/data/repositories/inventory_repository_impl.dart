import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/inventory_repository.dart';

/// Firebase implementation of inventory repository
/// Stores all inventory in business-specific collections: businesses/{businessId}/inventory
class InventoryRepositoryImpl implements InventoryRepository {
  final FirebaseFirestore _firestore;

  InventoryRepositoryImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  /// Get business-specific inventory collection path
  String _getInventoryPath(String businessId) =>
      'businesses/$businessId/inventory';

  @override
  Future<dynamic> addInventory(Map<String, dynamic> inventoryData) async {
    try {
      final businessId = inventoryData['businessId'] as String?;
      if (businessId == null || businessId.isEmpty) {
        throw Exception('businessId is required to add inventory');
      }

      // Generate SKU if not provided: uses an atomic counter on the business document (lastSkuNumber).
      final skuProvided = (inventoryData['sku'] as String?)?.trim() ?? '';
      if (skuProvided.isEmpty) {
        final businessRef = _firestore.collection('businesses').doc(businessId);
        await _firestore.runTransaction((tx) async {
          final bsnap = await tx.get(businessRef);
          final bdata = bsnap.data() ?? {};
          final last = (bdata['lastSkuNumber'] as int?) ?? 0;
          final next = last + 1;
          tx.set(businessRef, {'lastSkuNumber': next}, SetOptions(merge: true));
          inventoryData['sku'] = 'SKU-${next.toString().padLeft(5, '0')}';
        });
      } else {
        inventoryData['sku'] = skuProvided;
      }

      // Store timestamps as DateTime so Firestore stores them as Timestamp
      inventoryData['createdAt'] = DateTime.now();
      inventoryData['updatedAt'] = DateTime.now();

      // Preserve optional storeId field so items can be scoped to a store
      final docRef = await _firestore
          .collection(_getInventoryPath(businessId))
          .add(inventoryData);
      return <String, dynamic>{'id': docRef.id, ...inventoryData};
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateInventory(
      String inventoryId, Map<String, dynamic> inventoryData) async {
    try {
      final businessId = inventoryData['businessId'] as String?;
      if (businessId == null || businessId.isEmpty) {
        throw Exception('businessId is required to update inventory');
      }

      inventoryData['updatedAt'] = DateTime.now();
      await _firestore
          .collection(_getInventoryPath(businessId))
          .doc(inventoryId)
          .update(inventoryData);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteInventory(String inventoryId) async {
    try {
      throw Exception(
          'deleteInventory() requires businessId context. Use deleteInventoryForBusiness() instead.');
    } catch (e) {
      rethrow;
    }
  }

  /// Add a history log entry under businesses/{businessId}/inventory/{inventoryId}/history
  Future<void> addHistoryEntry(String businessId, String inventoryId, Map<String, dynamic> entry) async {
    try {
      if (businessId.isEmpty || inventoryId.isEmpty) throw Exception('businessId and inventoryId required');
      final ref = _firestore.collection(_getInventoryPath(businessId)).doc(inventoryId).collection('history');
      entry['createdAt'] = DateTime.now();
      await ref.add(entry);
    } catch (e) {
      rethrow;
    }
  }

  /// Stream history entries for an inventory item
  Stream<List<Map<String, dynamic>>> streamInventoryHistory(String businessId, String inventoryId) {
    if (businessId.isEmpty || inventoryId.isEmpty) return Stream.value([]);
    final ref = _firestore.collection(_getInventoryPath(businessId)).doc(inventoryId).collection('history').orderBy('createdAt', descending: true);
    return ref.snapshots().map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  @override
  Future<void> recordBakeryResupply({
    required String businessId,
    required String inventoryId,
    required num quantity,
    String? bakerId,
    String? bakerName,
    String? notes,
    String? performedById,
    String? performedByName,
    num? expectedProductionAmount,
    num? actualProductionAmount,
    String? productionUnit,
    String? productionItemName,
  }) async {
    if (businessId.isEmpty || inventoryId.isEmpty) {
      throw Exception('businessId and inventoryId are required');
    }
    if (quantity <= 0) {
      throw Exception('quantity must be greater than zero');
    }

    final inventoryRef = _firestore.collection(_getInventoryPath(businessId)).doc(inventoryId);
    final resupplyRef = _firestore.collection('businesses').doc(businessId).collection('bakery_resupplies').doc();

    await _firestore.runTransaction((tx) async {
      final invSnap = await tx.get(inventoryRef);
      final invData = invSnap.data() as Map<String, dynamic>? ?? {};
      final currentQuantity = ((invData['quantity'] as num?) ?? (invData['stock'] as num?) ?? 0).toDouble();
      final updatedQuantity = currentQuantity - quantity.toDouble();

      tx.set(
        inventoryRef,
        {
          'quantity': updatedQuantity,
          'stock': updatedQuantity,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final resupplyData = <String, dynamic>{
        'id': resupplyRef.id,
        'businessId': businessId,
        'inventoryId': inventoryId,
        'inventoryName': invData['name'] ?? '',
        'quantity': quantity,
        'unit': invData['unit'] ?? '',
        'bakerId': bakerId ?? '',
        'bakerName': bakerName ?? '',
        'notes': notes ?? '',
        'performedById': performedById ?? '',
        'performedByName': performedByName ?? '',
        'expectedProductionAmount': expectedProductionAmount?.toDouble() ?? 0.0,
        'actualProductionAmount': actualProductionAmount?.toDouble() ?? 0.0,
        'productionUnit': productionUnit ?? invData['unit'] ?? '',
        'productionItemName': productionItemName ?? invData['name'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      };
      tx.set(resupplyRef, resupplyData);

      final historyRef = inventoryRef.collection('history').doc();
      tx.set(historyRef, {
        'action': 'bakery_resupply',
        'performedBy': performedById ?? '',
        'performedByName': performedByName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'details': {
          'quantity': quantity,
          'bakerId': bakerId ?? '',
          'bakerName': bakerName ?? '',
          'notes': notes ?? '',
        },
      });
    });
  }

  /// Delete inventory item for a specific business
  Future<void> deleteInventoryForBusiness(
      String businessId, String inventoryId) async {
    try {
      await _firestore
          .collection(_getInventoryPath(businessId))
          .doc(inventoryId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> getInventory(String businessId,
      {Map<String, dynamic>? filters, String? storeId}) async {
    try {
      if (businessId.isEmpty) {
        return [];
      }

      // Load from inventory collection (official product storage)
      Query query = _firestore.collection(_getInventoryPath(businessId));
      if (storeId != null && storeId.isNotEmpty) {
        // Filter inventory to a specific store
        query = query.where('storeId', isEqualTo: storeId);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return <String, dynamic>{
          ...data,
          'id': doc.id,
        };
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<dynamic> getInventoryById(String inventoryId) async {
    try {
      throw Exception(
          'getInventoryById() requires businessId context. Use getInventoryByIdForBusiness() instead.');
    } catch (e) {
      rethrow;
    }
  }

  /// Get inventory item by ID for a specific business
  Future<dynamic> getInventoryByIdForBusiness(
      String businessId, String inventoryId) async {
    try {
      final doc = await _firestore
          .collection(_getInventoryPath(businessId))
          .doc(inventoryId)
          .get();
      return doc.data();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> getLowStockItems(String businessId, {String? storeId}) async {
    try {
      if (businessId.isEmpty) {
        return [];
      }

      Query query = _firestore.collection(_getInventoryPath(businessId)).where('quantity', isLessThan: 10);
      if (storeId != null && storeId.isNotEmpty) {
        query = query.where('storeId', isEqualTo: storeId);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> getExpiredItems(String businessId, {String? storeId}) async {
    try {
      if (businessId.isEmpty) {
        return [];
      }

      final now = DateTime.now();
      Query query = _firestore.collection(_getInventoryPath(businessId)).where('expiryDate', isLessThan: now);
      if (storeId != null && storeId.isNotEmpty) {
        query = query.where('storeId', isEqualTo: storeId);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchInventory({String? businessId, String? storeId}) async {
    try {
      if (businessId == null || businessId.isEmpty) {
        return [];
      }

      Query query = _firestore.collection(_getInventoryPath(businessId));
      if (storeId != null && storeId.isNotEmpty) {
        query = query.where('storeId', isEqualTo: storeId);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final d = doc.data() as Map<String, dynamic>? ?? {};
        return <String, dynamic>{...d, 'id': doc.id};
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> expiredItems(String businessId) async {
    return getExpiredItems(businessId);
  }

  @override
  Future<void> syncInventoryToFirestore(
      Map<String, dynamic> inventoryData) async {
    try {
      final businessId = inventoryData['businessId'] as String?;
      if (businessId == null || businessId.isEmpty) {
        throw Exception(
            'businessId is required to sync inventory to Firestore');
      }

      final inventoryId = inventoryData['id'] as String?;
      inventoryData['updatedAt'] = DateTime.now();

      // Allow optional storeId to be saved on the inventory item
      if (inventoryId != null && inventoryId.isNotEmpty) {
        // Update existing document
        await _firestore
            .collection(_getInventoryPath(businessId))
            .doc(inventoryId)
            .set(inventoryData, SetOptions(merge: true));
      } else {
        // Add new document
        await _firestore
            .collection(_getInventoryPath(businessId))
            .add(inventoryData);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Stream real-time inventory updates for a business
  Stream<List<Map<String, dynamic>>> streamInventory(String businessId, {String? storeId}) {
    if (businessId.isEmpty) {
      return Stream.value([]);
    }

    Query query = _firestore.collection(_getInventoryPath(businessId));
    if (storeId != null && storeId.isNotEmpty) query = query.where('storeId', isEqualTo: storeId);

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>? ?? {};
          return <String, dynamic>{...d, 'id': doc.id};
        }).toList());
  }

  @override
  Future<int> assignAllInventoryToStore(String businessId, String storeId) async {
    try {
      if (businessId.isEmpty) return 0;
      final snapshot = await _firestore.collection(_getInventoryPath(businessId)).get();
      int updated = 0;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'storeId': storeId});
        updated++;
      }
      await batch.commit();
      return updated;
    } catch (e) {
      rethrow;
    }
  }
}

