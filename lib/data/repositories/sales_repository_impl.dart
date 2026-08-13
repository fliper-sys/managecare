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
    final inventory = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('inventory');
    final productId = (item['productId'] ??
            item['id'] ??
            item['product_id'] ??
            item['inventoryProductId'] ??
            item['inventory_product_id'] ??
            item['menuItemId'] ??
            item['menu_item_id'] ??
            '')
        .toString()
        .trim();
    if (productId.isNotEmpty) {
      final docRef = inventory.doc(productId);
      final snap = await docRef.get();
      if (snap.exists) return docRef;
    }

    final barcode = (item['barcode'] ?? item['sku'] ?? '').toString().trim();
    if (barcode.isNotEmpty) {
      final barcodeSnap =
          await inventory.where('barcode', isEqualTo: barcode).limit(1).get();
      if (barcodeSnap.docs.isNotEmpty) return barcodeSnap.docs.first.reference;
    }

    final name = (item['name'] ??
            item['productName'] ??
            item['itemName'] ??
            item['menuItemName'] ??
            '')
        .toString()
        .trim();
    if (name.isNotEmpty) {
      final nameSnap =
          await inventory.where('name', isEqualTo: name).limit(1).get();
      if (nameSnap.docs.isNotEmpty) return nameSnap.docs.first.reference;
    }

    return null;
  }

  double _readQuantity(Map<String, dynamic> item) {
    final quantityValue = item['quantity'] ??
        item['qty'] ??
        item['quantitySold'] ??
        item['soldQty'] ??
        0;
    if (quantityValue is num) return quantityValue.toDouble();
    return double.tryParse(quantityValue.toString()) ?? 0.0;
  }

  double _readSaleUnitMultiplier(Map<String, dynamic> item) {
    final multiplierValue =
        item['saleUnitMultiplier'] ?? item['inventoryQuantity'] ?? 1;
    if (multiplierValue is num) return multiplierValue.toDouble();
    return double.tryParse(multiplierValue.toString()) ?? 1.0;
  }

  double _readInventoryDeductionQuantity(Map<String, dynamic> item) {
    final directValue = item['inventoryQuantity'] ??
        item['stockReduction'] ??
        item['stockDeduction'];
    if (directValue is num) return directValue.toDouble();

    final directParsed = double.tryParse(directValue?.toString() ?? '');
    if (directParsed != null) return directParsed;

    return _readQuantity(item) * _readSaleUnitMultiplier(item);
  }

  double _readSaleAmount(Map<String, dynamic> saleData) {
    final value = saleData['finalAmount'] ??
        saleData['totalAmount'] ??
        saleData['total'] ??
        0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  DateTime _readSaleCreatedAt(Map<String, dynamic> saleData) {
    final value = saleData['createdAt'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  String _salesSummaryDayKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
            final pid =
                (raw['productId'] ?? raw['id'] ?? raw['product_id'] ?? '')
                    .toString();
            final qty = _readInventoryDeductionQuantity(raw);

            if (pid.isEmpty || qty <= 0) continue;

            try {
              final invRef = _firestore
                  .collection('businesses')
                  .doc(bid)
                  .collection('inventory')
                  .doc(pid);
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
          final businessSaleRef = _firestore
              .collection('businesses')
              .doc(bid)
              .collection('sales')
              .doc(saleId);
          final bSnap = await tx.get(businessSaleRef);
          if (bSnap.exists) tx.delete(businessSaleRef);

          final saleType =
              (data['saleType'] ?? '').toString().trim().toLowerCase();
          final distributorId = (data['distributorId'] ?? '').toString().trim();
          if (saleType == 'distributor' && distributorId.isNotEmpty) {
            final distributorSaleRef = _firestore
                .collection('businesses')
                .doc(bid)
                .collection('distributor_sales')
                .doc(saleId);
            final distributorSaleSnap = await tx.get(distributorSaleRef);
            if (distributorSaleSnap.exists) tx.delete(distributorSaleRef);

            final distributorDocSaleRef = _firestore
                .collection('businesses')
                .doc(bid)
                .collection('distributors')
                .doc(distributorId)
                .collection('sales')
                .doc(saleId);
            final distributorDocSaleSnap = await tx.get(distributorDocSaleRef);
            if (distributorDocSaleSnap.exists) tx.delete(distributorDocSaleRef);
          }

          // log audit
          final auditRef = _firestore
              .collection('businesses')
              .doc(bid)
              .collection('sale_deletions')
              .doc();
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
      var rootQuery = _firestore
          .collection('sales')
          .where('businessId', isEqualTo: businessId) as dynamic;
      var nestedQuery = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('sales') as dynamic;

      if (filters != null) {
        // Apply additional filters if provided
        if (filters.containsKey('storeId') &&
            filters['storeId'] != null &&
            (filters['storeId'] as String).isNotEmpty) {
          rootQuery = rootQuery.where('storeId', isEqualTo: filters['storeId']);
          nestedQuery =
              nestedQuery.where('storeId', isEqualTo: filters['storeId']);
        }
        if (filters.containsKey('workerId') &&
            filters['workerId'] != null &&
            (filters['workerId'] as String).isNotEmpty) {
          rootQuery =
              rootQuery.where('workerId', isEqualTo: filters['workerId']);
          nestedQuery =
              nestedQuery.where('workerId', isEqualTo: filters['workerId']);
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
  Future<List<Map<String, dynamic>>> fetchSales(
      {String? businessId,
      String? storeId,
      DateTime? start,
      DateTime? end,
      int? limit}) async {
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
      query = query.limit(limit ?? 500);

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
    try {
      final pendingSales = await getPendingOfflineSales();

      for (final saleData in pendingSales) {
        final saleId = saleData['id']?.toString() ?? '';
        if (saleId.isEmpty) continue;

        try {
          await syncSaleToFirestore(saleData);
          await markSaleAsSynced(saleId);
        } catch (e) {
          // Leave the sale pending so it can be retried on the next sync pass.
          print('[SalesRepositoryImpl] Failed to sync sale $saleId: $e');
        }
      }
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
          items
              .addAll(saleItems.map((item) => Map<String, dynamic>.from(item)));
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

      final inventoryTargets = <Map<String, dynamic>>[];
      if (businessId.isNotEmpty && items.isNotEmpty) {
        for (final item in items) {
          final docRef = await _resolveInventoryDocRef(
            businessId: businessId,
            item: item,
          );
          final quantity = _readInventoryDeductionQuantity(item);
          if (docRef == null || quantity <= 0) continue;

          inventoryTargets.add({
            'ref': docRef,
            'quantity': quantity,
          });
        }
      }

      if (saleId != null && saleId.isNotEmpty) {
        final rootRef = _firestore.collection('sales').doc(saleId);
        final businessSaleRef = businessId.isNotEmpty
            ? _firestore
                .collection('businesses')
                .doc(businessId)
                .collection('sales')
                .doc(saleId)
            : null;

        await _firestore.runTransaction((tx) async {
          final rootSnap = await tx.get(rootRef);
          final rootData = rootSnap.data() ?? {};
          final inventoryAlreadyApplied =
              rootData['inventorySyncApplied'] == true;
          final shouldApplyInventory =
              !inventoryAlreadyApplied && inventoryTargets.isNotEmpty;
          final summaryAlreadyApplied = rootData['salesSummaryApplied'] == true;
          final shouldApplySummary = !summaryAlreadyApplied;

          final saleWrite = Map<String, dynamic>.from(saleData);
          saleWrite['id'] = saleId;
          saleWrite['updatedAt'] = FieldValue.serverTimestamp();
          saleWrite['inventorySyncApplied'] =
              inventoryAlreadyApplied || !shouldApplyInventory;
          // The local sale row doesn't carry an `items` column — line items
          // live in the separate `sale_items` table and were fetched above.
          // Without this, a synced offline sale becomes an item-less,
          // effectively blank record in Firestore.
          if (items.isNotEmpty) {
            saleWrite['items'] = items;
          }
          // Local rows store createdAt/updatedAt as ISO-8601 strings; write
          // them back as real DateTimes so Firestore stores a Timestamp
          // (not a String) — Sales History's createdAt range/orderBy
          // queries silently exclude non-Timestamp values.
          final localCreatedAt = saleData['createdAt'];
          if (localCreatedAt is String) {
            final parsed = DateTime.tryParse(localCreatedAt);
            if (parsed != null) saleWrite['createdAt'] = parsed;
          }
          if (shouldApplySummary) {
            saleWrite['salesSummaryApplied'] = true;
          }

          final inventoryUpdates = <Map<String, dynamic>>[];
          if (shouldApplyInventory) {
            for (final target in inventoryTargets) {
              final docRef =
                  target['ref'] as DocumentReference<Map<String, dynamic>>;
              final quantity = (target['quantity'] as num).toDouble();

              final snap = await tx.get(docRef);
              final currentQuantity = ((snap.data()?['quantity'] ??
                      snap.data()?['stock'] ??
                      0) as num)
                  .toDouble();
              final newQuantity =
                  (currentQuantity - quantity).clamp(0.0, 999999.0);
              inventoryUpdates.add({
                'ref': docRef,
                'quantity': newQuantity,
              });
            }
          }

          tx.set(rootRef, saleWrite, SetOptions(merge: true));
          if (businessSaleRef != null) {
            tx.set(businessSaleRef, saleWrite, SetOptions(merge: true));
          }

          if (shouldApplySummary && businessId.isNotEmpty) {
            final saleDate = _readSaleCreatedAt(saleData);
            final dayKey = _salesSummaryDayKey(saleDate);
            final summaryRef = _firestore
                .collection('businesses')
                .doc(businessId)
                .collection('salesSummaries')
                .doc(dayKey);
            tx.set(
              summaryRef,
              {
                'date': dayKey,
                'totalSales': FieldValue.increment(_readSaleAmount(saleData)),
                'totalTransactions': FieldValue.increment(1),
                'lastUpdated': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          }

          if (shouldApplyInventory) {
            for (final update in inventoryUpdates) {
              final docRef =
                  update['ref'] as DocumentReference<Map<String, dynamic>>;
              final newQuantity = update['quantity'] as double;
              tx.set(
                  docRef,
                  {
                    'quantity': newQuantity,
                    'stock': newQuantity,
                    'updatedAt': FieldValue.serverTimestamp(),
                  },
                  SetOptions(merge: true));
            }

            final appliedAt = {
              'inventorySyncApplied': true,
              'inventorySyncAppliedAt': FieldValue.serverTimestamp(),
            };
            tx.set(rootRef, appliedAt, SetOptions(merge: true));
            if (businessSaleRef != null) {
              tx.set(businessSaleRef, appliedAt, SetOptions(merge: true));
            }
          }
        });
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
        final amount = ((doc['finalAmount'] ??
                doc['totalAmount'] ??
                doc['total'] ??
                0) as num)
            .toDouble();
        totalSales += amount;
      }

      return totalSales;
    } catch (e) {
      // Handle Firestore composite index requirement by falling back to a date-only query
      final msg = e.toString();
      if (msg.contains('requires an index') ||
          msg.contains('FAILED_PRECONDITION')) {
        try {
          print(
              '[SalesRepositoryImpl] Composite index required for completed filter; falling back to date-only query for today');
          final fallback = await _firestore
              .collection('businesses')
              .doc(businessId)
              .collection('sales')
              .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
              .where('createdAt', isLessThanOrEqualTo: endOfDay)
              .get();

          double totalSales = 0.0;
          for (final doc in fallback.docs) {
            if ((doc['status'] as String?)?.toLowerCase() != 'completed')
              continue;
            final amount = ((doc['finalAmount'] ??
                    doc['totalAmount'] ??
                    doc['total'] ??
                    0) as num)
                .toDouble();
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
        final amount = ((doc['finalAmount'] ??
                doc['totalAmount'] ??
                doc['total'] ??
                0) as num)
            .toDouble();
        totalSales += amount;
      }

      return totalSales;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('requires an index') ||
          msg.contains('FAILED_PRECONDITION')) {
        try {
          print(
              '[SalesRepositoryImpl] Composite index required for completed filter; falling back to date-only query for range');
          final fallback = await _firestore
              .collection('businesses')
              .doc(businessId)
              .collection('sales')
              .where('createdAt', isGreaterThanOrEqualTo: startDate)
              .where('createdAt', isLessThanOrEqualTo: endDate)
              .get();

          double totalSales = 0.0;
          for (final doc in fallback.docs) {
            if ((doc['status'] as String?)?.toLowerCase() != 'completed')
              continue;
            final amount = ((doc['finalAmount'] ??
                    doc['totalAmount'] ??
                    doc['total'] ??
                    0) as num)
                .toDouble();
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
      final saleId = saleData['id']?.toString() ??
          'SALE-${DateTime.now().millisecondsSinceEpoch}';
      final businessId = saleData['businessId']?.toString() ?? '';
      final customerId = saleData['customerId']?.toString();
      final paymentMethod = saleData['paymentMethod']?.toString() ??
          saleData['payment_method']?.toString() ??
          'Cash';
      final status = saleData['status']?.toString() ?? 'completed';
      final notes = saleData['notes']?.toString();
      final createdBy = saleData['createdBy']?.toString() ??
          saleData['createdById']?.toString() ??
          '';
      final createdAt = DateTime.now().toIso8601String();
      final updatedAt = DateTime.now().toIso8601String();

      final localSale = {
        'id': saleId,
        'businessId': businessId,
        'customerId': customerId,
        'totalAmount': (saleData['totalAmount'] ??
                saleData['finalAmount'] ??
                saleData['total'] ??
                0)
            .toString(),
        'discountAmount':
            (saleData['discountAmount'] ?? saleData['discount'] ?? 0)
                .toString(),
        'taxAmount': (saleData['taxAmount'] ?? saleData['tax'] ?? 0).toString(),
        'finalAmount': (saleData['finalAmount'] ??
                saleData['total'] ??
                saleData['totalAmount'] ??
                0)
            .toString(),
        'paymentMethod': paymentMethod,
        'saleType': saleData['saleType']?.toString() ??
            saleData['sale_type']?.toString() ??
            'retail',
        'status': status,
        'notes': notes,
        'createdBy': createdBy,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'syncStatus': 'pending',
      };

      try {
        await dbHelper.insert('sales', localSale);

        if (saleData['items'] is List) {
          final items = List.from(saleData['items'] as List);
          for (var index = 0; index < items.length; index++) {
            final rawItem = items[index];
            if (rawItem is! Map) continue;
            final itemMap = Map<String, dynamic>.from(rawItem);
            final itemId = itemMap['id']?.toString() ??
                'SI-$saleId-$index-${DateTime.now().microsecondsSinceEpoch}';
            final quantity = (itemMap['quantity'] is num)
                ? (itemMap['quantity'] as num).toDouble()
                : double.tryParse(itemMap['quantity']?.toString() ?? '0') ??
                    0.0;
            final unitPrice = (itemMap['unitPrice'] is num)
                ? (itemMap['unitPrice'] as num).toDouble()
                : double.tryParse(itemMap['unitPrice']?.toString() ??
                        itemMap['price']?.toString() ??
                        '0') ??
                    0.0;
            final total = (itemMap['total'] is num)
                ? (itemMap['total'] as num).toDouble()
                : double.tryParse(itemMap['total']?.toString() ??
                        (unitPrice * quantity).toString()) ??
                    (unitPrice * quantity);

            final localItem = {
              'id': itemId,
              'saleId': saleId,
              'productId': itemMap['productId']?.toString() ??
                  itemMap['inventoryProductId']?.toString() ??
                  itemMap['menuItemId']?.toString() ??
                  itemMap['id']?.toString() ??
                  '',
              'productName': itemMap['productName']?.toString() ??
                  itemMap['menuItemName']?.toString() ??
                  itemMap['name']?.toString() ??
                  '',
              'quantity': quantity,
              'unitPrice': unitPrice,
              'discount': (itemMap['discount'] ?? 0).toString(),
              'total': total,
            };
            await dbHelper.insert('sale_items', localItem);
          }
        }
      } catch (_) {
        await dbHelper
            .delete('sale_items', where: 'saleId = ?', whereArgs: [saleId]);
        await dbHelper.delete('sales', where: 'id = ?', whereArgs: [saleId]);
        rethrow;
      }

      return saleId;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingOfflineSales() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      // Sales that failed a previous sync attempt (e.g. because the device
      // was still offline when the immediate post-checkout sync fired) must
      // be retried too, otherwise they're stuck forever — nothing else ever
      // flips 'failed' back to 'pending'. 'error' sales (repeatedly failed
      // past the retry-attempt cap — see SyncService) are included as well
      // since retries here are infrequent (app start / reconnect / manual
      // tap) rather than a tight poll, so there's no real storm risk, and a
      // human may well have fixed the underlying data since the last try.
      // Three separate equality queries (rather than one IN/OR query)
      // because the web/Hive fallback in DatabaseHelper.query only
      // understands a single `col = ?` clause.
      final pending = await dbHelper
          .query('sales', where: 'syncStatus = ?', whereArgs: ['pending']);
      final failed = await dbHelper
          .query('sales', where: 'syncStatus = ?', whereArgs: ['failed']);
      final errored = await dbHelper
          .query('sales', where: 'syncStatus = ?', whereArgs: ['error']);
      return [...pending, ...failed, ...errored];
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> markSaleAsSynced(String saleId) async {
    try {
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.update('sales', {'syncStatus': 'synced'},
          where: 'id = ?', whereArgs: [saleId]);
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
