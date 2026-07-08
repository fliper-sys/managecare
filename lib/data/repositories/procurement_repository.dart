import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../core/utils/datetime_utils.dart';
import '../../core/utils/inventory_utils.dart';

class ProcurementRepository {
  Map<String, dynamic> buildBakeryProcurementMetadata({
    String? bakerId,
    String? bakerName,
    String? salesRepId,
    String? salesRepName,
  }) {
    final metadata = <String, dynamic>{};
    if ((bakerId ?? '').trim().isNotEmpty) {
      metadata['bakerId'] = bakerId!.trim();
      metadata['sourceType'] = 'bakery';
    }
    if ((bakerName ?? '').trim().isNotEmpty) {
      metadata['bakerName'] = bakerName!.trim();
    }
    if ((salesRepId ?? '').trim().isNotEmpty) {
      metadata['salesRepId'] = salesRepId!.trim();
    }
    if ((salesRepName ?? '').trim().isNotEmpty) {
      metadata['salesRepName'] = salesRepName!.trim();
    }
    return metadata;
  }
  final FirebaseFirestore? _firestore;

  ProcurementRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get _effectiveFirestore {
    return _firestore ?? FirebaseFirestore.instance;
  }

  /// Creates a procurement plus batch-aware inventory/procurement records in a single transaction.
  /// Returns the created procurement doc id.
  Future<String> createBatchProcurement({
    required String businessId,
    required List<Map<String, dynamic>> items,
    String? supplierId,
    String? supplierName,
    String? invoiceRef,
    String? referenceImageUrl,
    String? createdById,
    String? createdByName,
    String? createdByEmail,
    String? storeId,
    String? storeName,
    String? bakerId,
    String? bakerName,
    String? salesRepId,
    String? salesRepName,
  }) async {
    final procurementRef = _effectiveFirestore.collection('businesses').doc(businessId).collection('procurements').doc();
    final createdAt = FieldValue.serverTimestamp();

    double totalCost = 0.0;
    num totalQuantity = 0;
    final itemsSnapshot = <Map<String, dynamic>>[];

    await _effectiveFirestore.runTransaction((tx) async {
      final inventoryRefsByProductId = <String, DocumentReference>{};
      final inventoryDataByProductId = <String, Map<String, dynamic>>{};

      for (final it in items) {
        final productId = it['productId'] as String? ?? '';
        if (productId.isEmpty) continue;
        if (!inventoryRefsByProductId.containsKey(productId)) {
          final invRef = _effectiveFirestore
              .collection('businesses')
              .doc(businessId)
              .collection('inventory')
              .doc(productId);
          inventoryRefsByProductId[productId] = invRef;
          final invSnap = await tx.get(invRef);
          inventoryDataByProductId[productId] = invSnap.data() as Map<String, dynamic>? ?? {};
        }
      }

      for (final it in items) {
        final productId = it['productId'] as String? ?? '';
        final name = it['name'] ?? '';
        final quantity = (it['quantity'] as num?) ?? 0;
        final cost = (it['cost'] as num?)?.toDouble() ?? 0.0;
        final unit = (it['unit'] as String?) ?? '';
        final purchaseQuantity = (it['purchaseQuantity'] as num?) ?? quantity;
        final purchaseUnit = (it['purchaseUnit'] as String?) ?? unit;
        final purchaseUnitCost =
            (it['purchaseUnitCost'] as num?)?.toDouble() ?? cost;
        final batchLabel =
            ((it['batchLabel'] as String?) ?? '').trim();
        final expiryDate = _normalizeStoredDate(it['expiryDate']);
        final itemTotal =
            (it['purchaseTotal'] as num?)?.toDouble() ??
            (purchaseQuantity.toDouble() * purchaseUnitCost);

        totalCost += itemTotal;
        totalQuantity += quantity;

        final itemSnapshot = <String, dynamic>{
          'productId': productId,
          'name': name,
          'quantity': _normalizeStoredQuantity(quantity),
          'unit': unit,
          'cost': cost,
          'total': itemTotal,
          'purchaseQuantity': _normalizeStoredQuantity(purchaseQuantity),
          'purchaseUnit': purchaseUnit,
          'purchaseUnitCost': purchaseUnitCost,
        };
        if (batchLabel.isNotEmpty) itemSnapshot['batchLabel'] = batchLabel;
        if (expiryDate != null) itemSnapshot['expiryDate'] = expiryDate;
        itemsSnapshot.add(itemSnapshot);

        if (productId.isEmpty) {
          continue;
        }

        final invRef = inventoryRefsByProductId[productId]!;
        final invData = inventoryDataByProductId[productId] ?? {};
        final existingQuantity =
            (invData['quantity'] as num?)?.toDouble() ??
                (invData['stock'] as num?)?.toDouble() ??
                0.0;
        final existingCost =
            ((invData['averageCost'] ?? invData['cost'] ?? invData['lastProcurementCost'])
                    as num?)
                ?.toDouble() ??
                0.0;
        final updatedQuantity = existingQuantity + quantity.toDouble();
        final weightedCost = updatedQuantity <= 0
            ? cost
            : ((existingQuantity * existingCost) +
                    (quantity.toDouble() * cost)) /
                updatedQuantity;

        tx.set(
          invRef,
          {
            'quantity': _normalizeStoredQuantity(updatedQuantity),
            'stock': _normalizeStoredQuantity(updatedQuantity),
            'cost': weightedCost,
            'averageCost': weightedCost,
            'lastProcurementCost': cost,
            'lastProcurementQuantity': _normalizeStoredQuantity(quantity),
            'lastProcurementAt': createdAt,
            'updatedAt': createdAt,
            'hasBatchTracking': true,
            if (unit.isNotEmpty) 'unit': unit,
          },
          SetOptions(merge: true),
        );

        final batchRef = invRef.collection('batches').doc();
        final effectiveBatchLabel = batchLabel.isNotEmpty
            ? batchLabel
            : 'BATCH-${batchRef.id.substring(0, 6).toUpperCase()}';
        final batchData = <String, dynamic>{
          'procurementId': procurementRef.id,
          'productId': productId,
          'name': name,
          'quantity': _normalizeStoredQuantity(quantity),
          'remainingQuantity': _normalizeStoredQuantity(quantity),
          'unit': unit,
          'cost': cost,
          'total': itemTotal,
          'purchaseQuantity': _normalizeStoredQuantity(purchaseQuantity),
          'purchaseUnit': purchaseUnit,
          'purchaseUnitCost': purchaseUnitCost,
          'batchLabel': effectiveBatchLabel,
          'createdAt': createdAt,
          'updatedAt': createdAt,
        };
        if (supplierId != null) batchData['supplierId'] = supplierId;
        if (supplierName != null) batchData['supplierName'] = supplierName;
        if (invoiceRef != null) batchData['invoiceRef'] = invoiceRef;
        if (referenceImageUrl != null) {
          batchData['referenceImageUrl'] = referenceImageUrl;
        }
        if (expiryDate != null) batchData['expiryDate'] = expiryDate;
        tx.set(batchRef, batchData);

        final prodProcRef = invRef.collection('procurements').doc();
        tx.set(prodProcRef, {
          'procurementId': procurementRef.id,
          'batchId': batchRef.id,
          'batchLabel': effectiveBatchLabel,
          'productId': productId,
          'quantity': _normalizeStoredQuantity(quantity),
          'unit': unit,
          'cost': cost,
          'total': itemTotal,
          'purchaseQuantity': _normalizeStoredQuantity(purchaseQuantity),
          'purchaseUnit': purchaseUnit,
          'purchaseUnitCost': purchaseUnitCost,
          'createdAt': createdAt,
          'supplierId': supplierId,
          'supplierName': supplierName,
          'invoiceRef': invoiceRef,
          'referenceImageUrl': referenceImageUrl,
          if (expiryDate != null) 'expiryDate': expiryDate,
        });

        final itemRef = procurementRef.collection('items').doc();
        tx.set(itemRef, {
          'productId': productId,
          'name': name,
          'quantity': _normalizeStoredQuantity(quantity),
          'unit': unit,
          'cost': cost,
          'total': itemTotal,
          'purchaseQuantity': _normalizeStoredQuantity(purchaseQuantity),
          'purchaseUnit': purchaseUnit,
          'purchaseUnitCost': purchaseUnitCost,
          'batchId': batchRef.id,
          'batchLabel': effectiveBatchLabel,
          if (expiryDate != null) 'expiryDate': expiryDate,
        });
      }

      final masterData = <String, dynamic>{
        'createdAt': createdAt,
        'totalCost': totalCost,
        'totalQuantity': _normalizeStoredQuantity(totalQuantity),
        'itemsCount': itemsSnapshot.length,
        'items': itemsSnapshot,
      };
      if (supplierId != null) masterData['supplierId'] = supplierId;
      if (supplierName != null) masterData['supplierName'] = supplierName;
      if (invoiceRef != null) masterData['invoiceRef'] = invoiceRef;
      if (referenceImageUrl != null) {
        masterData['referenceImageUrl'] = referenceImageUrl;
      }
      if (createdById != null) masterData['createdById'] = createdById;
      if (createdByName != null) masterData['createdByName'] = createdByName;
      if (createdByEmail != null) masterData['createdByEmail'] = createdByEmail;
      if (storeId != null) masterData['storeId'] = storeId;
      if (storeName != null) masterData['storeName'] = storeName;
      final bakeryMetadata = buildBakeryProcurementMetadata(
        bakerId: bakerId,
        bakerName: bakerName,
        salesRepId: salesRepId,
        salesRepName: salesRepName,
      );
      if (bakeryMetadata.isNotEmpty) {
        masterData.addAll(bakeryMetadata);
      }
      tx.set(procurementRef, masterData);
    });

    return procurementRef.id;
  }

  /// Stream procurements for business ordered by createdAt descending
  Stream<QuerySnapshot> procurementsStream({required String businessId}) {
    return _effectiveFirestore.collection('businesses').doc(businessId).collection('procurements').orderBy('createdAt', descending: true).snapshots();
  }

  /// Export procurements as CSV string using provided docs. This is lightweight and pure string building.
  String procurementsToCsv(List<QueryDocumentSnapshot> docs) {
    final rows = <List<String>>[];
    rows.add(['Procurement ID', 'Date', 'Supplier', 'Invoice', 'Baker', 'Sales Rep', 'Total Quantity', 'Total Cost', 'Item Count']);
    for (final d in docs) {
      final createdAt = parseTimestamp(d.get('createdAt'));
      final data = d.data() as Map<String, dynamic>? ?? {};
      final supplierName = data.containsKey('supplierName') ? (data['supplierName'] ?? '') : '';
      final invoiceRef = data.containsKey('invoiceRef') ? (data['invoiceRef'] ?? '') : '';
      final bakerName = data.containsKey('bakerName') ? (data['bakerName'] ?? '') : '';
      final salesRepName = data.containsKey('salesRepName') ? (data['salesRepName'] ?? '') : '';
      rows.add([
        d.id,
        createdAt.toIso8601String(),
        supplierName,
        invoiceRef,
        bakerName,
        salesRepName,
        formatInventoryQuantity((d.get('totalQuantity') as num?) ?? 0),
        '${((d.get('totalCost') as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
        '${(d.get('itemsCount') as num?)?.toInt() ?? (d.get('items') as List?)?.length ?? 0}'
      ]);
      final items = (d.get('items') as List?)?.cast<dynamic>() ?? [];
      if (items.isNotEmpty) {
        rows.add(['-- Item Name', 'Qty', 'Purchase Unit', 'Purchase Unit Cost', 'Per Kg Cost', 'Unit Cost', 'Total']);
        for (final it in items) {
          final purchaseUnit = (it['purchaseUnit'] ?? '').toString();
          final purchaseUnitCost = (it['purchaseUnitCost'] as num?)?.toDouble() ?? 0.0;
          final bagWeightKg = (it['bagWeightKg'] as num?)?.toDouble() ?? 0.0;
          String perKg = '';
          if (purchaseUnit.toLowerCase() == 'bag' && bagWeightKg > 0) {
            perKg = (purchaseUnitCost / bagWeightKg).toStringAsFixed(2);
          } else if (purchaseUnit.toLowerCase() == 'kg' || purchaseUnit.toLowerCase() == 'kilogram' || purchaseUnit.toLowerCase() == 'kgs') {
            perKg = purchaseUnitCost.toStringAsFixed(2);
          }
          rows.add([
            '    ${it['name'] ?? ''}',
            formatInventoryQuantity((it['quantity'] as num?) ?? 0),
            purchaseUnit,
            '${purchaseUnitCost.toStringAsFixed(2)}',
            perKg,
            '${(it['cost'] ?? 0).toStringAsFixed(2)}',
            '${(it['total'] ?? 0).toStringAsFixed(2)}'
          ]);
        }
      }
      rows.add([]);
    }

    final csv = rows.map((r) => r.map((c) => '"${c.toString().replaceAll('"', '""')}"').join(',')).join('\n');
    return csv;
  }

  /// Stream procurements for a product by reading inventory/{productId}/procurements ordered by createdAt desc
  Stream<QuerySnapshot> productProcurementsStream({required String businessId, required String productId}) {
    return _effectiveFirestore.collection('businesses').doc(businessId).collection('inventory').doc(productId).collection('procurements').orderBy('createdAt', descending: true).snapshots();
  }

  /// Get procurement master document by id
  Future<DocumentSnapshot> getProcurementById({required String businessId, required String procurementId}) {
    return _effectiveFirestore.collection('businesses').doc(businessId).collection('procurements').doc(procurementId).get();
  }

  dynamic _normalizeStoredQuantity(num quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt();
    }
    return quantity.toDouble();
  }

  dynamic _normalizeStoredDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) {
        return Timestamp.fromDate(parsed);
      }
    }
    return null;
  }
}
