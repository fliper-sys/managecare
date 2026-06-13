import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/sales_repository.dart';
import '../../data/local/database_helper.dart';

/// Firebase implementation of sales repository
class SalesRepositoryImpl implements SalesRepository {
  final FirebaseFirestore _firestore;

  SalesRepositoryImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  Future<DocumentReference<Map<String, dynamic>>?> _resolveInventoryDocRef({
    required String businessId,
    required Map<String, dynamic> item,
  }) async {
    final inventory = _firestore.collection('businesses').doc(businessId).collection('inventory');
    final productId = (item['productId'] ?? item['id'] ?? item['product_id'] ?? '').toString().trim();
    if (productId.isNotEmpty) {
      final docRef = inventory.doc(productId);
      final snap = await docRef.get();
      if (snap.exists) return docRef;
    }

    final barcode = (item['barcode'] ?? item['sku'] ?? '').toString().trim();
    if (barcode.isNotEmpty) {
      final barcodeSnap = await inventory.where('barcode', isEqualTo: barcode).limit(1).get();
      if (barcodeSnap.docs.isNotEmpty) return barcodeSnap.docs.first.reference;
    }

    final name = (item['name'] ?? item['productName'] ?? item['itemName'] ?? '').toString().trim();
    if (name.isNotEmpty) {
      final nameSnap = await inventory.where('name', isEqualTo: name).limit(1).get();
      if (nameSnap.docs.isNotEmpty) return nameSnap.docs.first.reference;
    }

    return null;
  }

  double _readQuantity(Map<String, dynamic> item) {
    final quantityValue = item['quantity'] ?? item['qty'] ?? item['quantitySold'] ?? item['soldQty'] ?? 0;
    if (quantityValue is num) return quantityValue.toDouble();
    return double.tryParse(quantityValue.toString()) ?? 0.0;
  }

  double _readSaleUnitMultiplier(Map<String, dynamic> item) {
    final multiplierValue = item['saleUnitMultiplier'] ?? item['inventoryQuantity'] ?? 1;
    if (multiplierValue is num) return multiplierValue.toDouble();
    return double.tryParse(multiplierValue.toString()) ?? 1.0;
  }

  @override
  Future<dynamic> createSale(Map<String, dynamic> saleData) async {
    try {
      saleData['createdAt'] = DateTime.now();
      saleData['updatedAt'] = DateTime.now();
      final docRef = await _firestore.collection('sales').add(saleData);
      return {'id': docRef.id, ...saleData};
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateSale(String saleId, Map<String, dynamic> saleData) async {
    try {
      saleData['updatedAt'] = DateTime.now();
      await _firestore.collection('sales').doc(saleId).update(saleData);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteSale(String saleId) async {
    try {
      // Attempt to atomically restock inventory and remove both root and business-level sale docs
      await _firestore.runTransaction((tx) async {
        final rootRef = _firestore.collection('sales').doc(saleId);
        final rootSnap = await tx.get(rootRef);
        if (!rootSnap.exists) {
          // Nothing to do
          return;
        }

        final data = rootSnap.data() ?? {};
        final bid = data['businessId']?.toString();
        final items = (data['items'] as List<dynamic>?) ?? [];

        if (bid != null && bid.isNotEmpty) {
          final List<Map<String, dynamic>> _deleteErrors = [];
          for (final raw in items) {
            if (raw is! Map<String, dynamic>) continue;
            final pid = (raw['productId'] ?? raw['id'] ?? raw['product_id'] ?? '').toString();
            final qtyNum = (raw['quantity'] ?? raw['qty'] ?? raw['quantitySold'] ?? 0);
            double qty;
            try {
              if (qtyNum is num) qty = qtyNum.toDouble();
              else {
                final cleaned = qtyNum?.toString().replaceAll(RegExp(r'[^0-9.\-]'), '');
                qty = double.tryParse(cleaned!) ?? 0.0;
              }
            } catch (_) {
              qty = 0.0;
            }

            if (pid.isEmpty || qty <= 0) continue;

            try {
              final invRef = _firestore.collection('businesses').doc(bid).collection('inventory').doc(pid);
              final invSnap = await tx.get(invRef);
              if (invSnap.exists) {
                tx.update(invRef, {
                  'quantity': FieldValue.increment(qty),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              } else {
                tx.set(invRef, {
                  'quantity': qty,
                  'name': (raw['name'] ?? raw['productName'] ?? '').toString(),
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              }
            } catch (e) {
              _deleteErrors.add({'productId': pid, 'error': e.toString()});
            }
          }

          // delete business-level sale doc if present
          final businessSaleRef = _firestore.collection('businesses').doc(bid).collection('sales').doc(saleId);
          final bSnap = await tx.get(businessSaleRef);
          if (bSnap.exists) tx.delete(businessSaleRef);

          // log audit
          final auditRef = _firestore.collection('businesses').doc(bid).collection('sale_deletions').doc();
          tx.set(auditRef, {
            'saleId': saleId,
            'deletedBy': 'system',
            'items': items,
            'errors': _deleteErrors,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // finally delete root sale doc
        tx.delete(rootRef);
      });
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> getSales(String businessId,
      {Map<String, dynamic>? filters}) async {
    try {
      // Try root collection 'sales' and nested 'businesses/{businessId}/sales'
      var rootQuery = _firestore.collection('sales').where('businessId', isEqualTo: businessId) as dynamic;
      var nestedQuery = _firestore.collection('businesses').doc(businessId).collection('sales') as dynamic;

      if (filters != null) {
        // Apply additional filters if provided
        if (filters.containsKey('storeId') && filters['storeId'] != null && (filters['storeId'] as String).isNotEmpty) {
          rootQuery = rootQuery.where('storeId', isEqualTo: filters['storeId']);
          nestedQuery = nestedQuery.where('storeId', isEqualTo: filters['storeId']);
        }
        if (filters.containsKey('workerId') && filters['workerId'] != null && (filters['workerId'] as String).isNotEmpty) {
          rootQuery = rootQuery.where('workerId', isEqualTo: filters['workerId']);
          nestedQuery = nestedQuery.where('workerId', isEqualTo: filters['workerId']);
        }
      }

      final rootSnapshot = await rootQuery.get();
      final nestedSnapshot = await nestedQuery.get(); 

      final List<Map<String, dynamic>> listRoot = rootSnapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList()
          .cast<Map<String, dynamic>>();
      final List<Map<String, dynamic>> listNested = nestedSnapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList()
          .cast<Map<String, dynamic>>();

      // Combine and dedupe by id (nested takes precedence)
      final Map<String, Map<String, dynamic>> combined = {};
      for (var s in listRoot) {
        combined[s['id'] as String] = s;
      }
      for (var s in listNested) {
        combined[s['id'] as String] = s;
      }

      return combined.values.toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<dynamic> getSaleById(String saleId) async {
    try {
      final doc = await _firestore.collection('sales').doc(saleId).get();
      return doc.data();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSales({String? businessId, String? storeId, DateTime? start, DateTime? end}) async {
    try {
      // Start with base query - businessId is critical for filtering
      if (businessId == null || businessId.isEmpty) {
        throw Exception('Business ID is required to fetch sales');
      }

      var query = _firestore
          .collection('sales')
          .where('businessId', isEqualTo: businessId) as dynamic;
      
      // Add optional store filter
      if (storeId != null && storeId.isNotEmpty) {
        query = query.where('storeId', isEqualTo: storeId);
      }
      
      // Add date range filters - Firebase will use the index efficiently
      if (start != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: start);
      }
      
      if (end != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: end);
      }

      // Order by most recent first for better UX
      query = query.orderBy('createdAt', descending: true);
      
      // Limit to prevent loading massive datasets - can be paginated if needed
      query = query.limit(500);
      
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => {...(doc.data() as Map<String, dynamic>), 'id': doc.id})
          .toList()
          .cast<Map<String, dynamic>>();
    } on FirebaseException catch (e) {
      throw Exception('Firebase error (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch sales: $e');
    }
  }

  @override
  Future<void> syncSales() async {
    // TODO: Implement sync logic for sales
    try {
      // Sync pending sales to Firestore
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> getReceipt(String id) async {
    try {
      final doc = await _firestore.collection('sales').doc(id).get();
      return doc.data();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> syncSaleToFirestore(Map<String, dynamic> saleData) async {
    try {
      final saleId = saleData['id'] as String?;
      final businessId = saleData['businessId']?.toString() ?? '';
      final items = <Map<String, dynamic>>[];

      if (saleId != null && saleId.isNotEmpty) {
        try {
          final dbHelper = DatabaseHelper.instance;
          final saleItems = await dbHelper.query(
            'sale_items',
            where: 'saleId = ?',
            whereArgs: [saleId],
          );
          items.addAll(saleItems.map((item) => Map<String, dynamic>.from(item)));
        } catch (_) {}
      }

      if (items.isEmpty && saleData['items'] is List) {
        for (final raw in saleData['items'] as List) {
          if (raw is Map<String, dynamic>) {
            items.add(raw);
          } else if (raw is Map) {
            items.add(Map<String, dynamic>.from(raw));
          }
        }
      }

      if (saleId != null && saleId.isNotEmpty) {
        await _firestore
            .collection('sales')
            .doc(saleId)
            .set(saleData, SetOptions(merge: true));
        if (businessId.isNotEmpty) {
          await _firestore
              .collection('businesses')
              .doc(businessId)
              .collection('sales')
              .doc(saleId)
              .set(saleData, SetOptions(merge: true));
        }
      } else {
        final docRef = await _firestore.collection('sales').add(saleData);
        if (businessId.isNotEmpty) {
          await _firestore
              .collection('businesses')
              .doc(businessId)
              .collection('sales')
              .doc(docRef.id)
              .set({...saleData, 'id': docRef.id}, SetOptions(merge: true));
        }
      }

      if (businessId.isNotEmpty && items.isNotEmpty) {
        for (final item in items) {
          final docRef = await _resolveInventoryDocRef(
            businessId: businessId,
            item: item,
          );
          if (docRef == null) continue;

          final quantity = _readQuantity(item) * _readSaleUnitMultiplier(item);
          if (quantity <= 0) continue;

          final snap = await docRef.get();
          final currentQuantity = ((snap.data()?['quantity'] ?? snap.data()?['stock'] ?? 0) as num).toDouble();
          final newQuantity = (currentQuantity - quantity).clamp(0.0, 999999.0);
          await docRef.update({
            'quantity': newQuantity,
            'stock': newQuantity,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get today's sales total for a specific business
  Future<double> getTodaysSalesTotal(String businessId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    try {
      // Primary attempt: query for status==completed (may require composite index)
      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('sales')
          .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
          .where('createdAt', isLessThanOrEqualTo: endOfDay)
          .where('status', isEqualTo: 'completed')
          .get();

      double totalSales = 0.0;
      for (final doc in snapshot.docs) {
        final amount = ((doc['finalAmount'] ?? doc['totalAmount'] ?? doc['total'] ?? 0) as num).toDouble();
        totalSales += amount;
      }

      return totalSales;
    } catch (e) {
      // Handle Firestore composite index requirement by falling back to a date-only query
      final msg = e.toString();
      if (msg.contains('requires an index') || msg.contains('FAILED_PRECONDITION')) {
        try {
          print('[SalesRepositoryImpl] Composite index required for completed filter; falling back to date-only query for today');
          final fallback = await _firestore
              .collection('businesses')
              .doc(businessId)
              .collection('sales')
              .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
              .where('createdAt', isLessThanOrEqualTo: endOfDay)
              .get();

          double totalSales = 0.0;
          for (final doc in fallback.docs) {
            if ((doc['status'] as String?)?.toLowerCase() != 'completed') continue;
            final amount = ((doc['finalAmount'] ?? doc['totalAmount'] ?? doc['total'] ?? 0) as num).toDouble();
            totalSales += amount;
          }

          return totalSales;
        } catch (e2) {
          print('[SalesRepositoryImpl] Fallback date-only query failed: $e2');
          rethrow;
        }
      }

      rethrow;
    }
  }

  /// Get sales total for a date range for a specific business
  Future<double> getSalesTotalForDateRange({
    required String businessId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('sales')
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThanOrEqualTo: endDate)
          .where('status', isEqualTo: 'completed')
          .get();

      double totalSales = 0.0;
      for (final doc in snapshot.docs) {
        final amount = ((doc['finalAmount'] ?? doc['totalAmount'] ?? doc['total'] ?? 0) as num).toDouble();
        totalSales += amount;
      }

      return totalSales;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('requires an index') || msg.contains('FAILED_PRECONDITION')) {
        try {
          print('[SalesRepositoryImpl] Composite index required for completed filter; falling back to date-only query for range');
          final fallback = await _firestore
              .collection('businesses')
              .doc(businessId)
              .collection('sales')
              .where('createdAt', isGreaterThanOrEqualTo: startDate)
              .where('createdAt', isLessThanOrEqualTo: endDate)
              .get();

          double totalSales = 0.0;
          for (final doc in fallback.docs) {
            if ((doc['status'] as String?)?.toLowerCase() != 'completed') continue;
            final amount = ((doc['finalAmount'] ?? doc['totalAmount'] ?? doc['total'] ?? 0) as num).toDouble();
            totalSales += amount;
          }

          return totalSales;
        } catch (e2) {
          print('[SalesRepositoryImpl] Fallback date-only query failed: $e2');
        }
      }

      rethrow;
    }
  }

  // Offline support methods
  @override
  Future<String> createSaleOffline(Map<String, dynamic> saleData) async {
    try {
      final dbHelper = DatabaseHelper.instance;
      saleData['createdAt'] = DateTime.now().toIso8601String();
      saleData['updatedAt'] = DateTime.now().toIso8601String();
      saleData['syncStatus'] = 'pending';

      final id = await dbHelper.insert('sales', saleData);
      return id.toString();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingOfflineSales() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      return await dbHelper.query('sales', where: 'syncStatus = ?', whereArgs: ['pending']);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> markSaleAsSynced(String saleId) async {
    try {
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.update('sales', {'syncStatus': 'synced'}, where: 'id = ?', whereArgs: [saleId]);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteOfflineSale(String saleId) async {
    try {
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.delete('sales', where: 'id = ?', whereArgs: [saleId]);
    } catch (e) {
      rethrow;
    }
  }
}

