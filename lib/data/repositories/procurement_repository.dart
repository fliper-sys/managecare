import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/datetime_utils.dart';

class ProcurementRepository {
  final FirebaseFirestore _firestore;

  ProcurementRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Creates a batch procurement and per-product procurement records inside a single write batch.
  /// Returns the created procurement doc id.
  Future<String> createBatchProcurement({
    required String businessId,
    required List<Map<String, dynamic>> items,
    String? supplierId,
    String? supplierName,
    String? invoiceRef,
    String? referenceImageUrl,
  }) async {
    final batch = _firestore.batch();
    final procurementRef = _firestore.collection('businesses').doc(businessId).collection('procurements').doc();
    final createdAt = FieldValue.serverTimestamp();

    double totalCost = 0.0;
    int totalQuantity = 0;
    final itemsSnapshot = <Map<String, dynamic>>[];

    for (final it in items) {
      final productId = it['productId'] as String? ?? '';
      final name = it['name'] ?? '';
      final quantity = (it['quantity'] as int?) ?? 0;
      final cost = (it['cost'] as num?)?.toDouble() ?? 0.0;
      final unit = (it['unit'] as String?) ?? '';
      final itemTotal = quantity * cost;

      totalCost += itemTotal;
      totalQuantity += quantity;

      itemsSnapshot.add({
        'productId': productId,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'cost': cost,
        'total': itemTotal,
      });

      if (productId.isNotEmpty) {
        // update inventory quantity and cost (safe to use merge/update)
        final invRef = _firestore.collection('businesses').doc(businessId).collection('inventory').doc(productId);
        // We cannot read in a batch; assume caller provided correct newQuantity if needed, but here we'll increment based on DB read in a transaction instead
        // Simpler: perform update with FieldValue.increment to increase quantity
        batch.update(invRef, {
          'quantity': FieldValue.increment(quantity),
          'cost': cost,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // per-product procurement entry (include supplier/invoice for traceability)
        final prodProcRef = invRef.collection('procurements').doc();
        batch.set(prodProcRef, {
          'procurementId': procurementRef.id,
          'productId': productId,
          'quantity': quantity,
          'unit': unit,
          'cost': cost,
          'total': itemTotal,
          'createdAt': createdAt,
          'supplierId': supplierId,
          'supplierName': supplierName,
          'invoiceRef': invoiceRef,
          'referenceImageUrl': referenceImageUrl,
        });

        // item under procurement master
        final itemRef = procurementRef.collection('items').doc();
        batch.set(itemRef, {
          'productId': productId,
          'name': name,
          'quantity': quantity,
          'unit': unit,
          'cost': cost,
          'total': itemTotal,
        });
      }
    }

    // procurement master doc (include supplier and invoice metadata)
    final masterData = {
      'createdAt': createdAt,
      'totalCost': totalCost,
      'totalQuantity': totalQuantity,
      'itemsCount': itemsSnapshot.length,
      'items': itemsSnapshot,
    };
    if (supplierId != null) masterData['supplierId'] = supplierId;
    if (supplierName != null) masterData['supplierName'] = supplierName;
    if (invoiceRef != null) masterData['invoiceRef'] = invoiceRef;
    if (referenceImageUrl != null) masterData['referenceImageUrl'] = referenceImageUrl;

    batch.set(procurementRef, masterData);

    await batch.commit();
    return procurementRef.id;
  }

  /// Stream procurements for business ordered by createdAt descending
  Stream<QuerySnapshot> procurementsStream({required String businessId}) {
    return _firestore.collection('businesses').doc(businessId).collection('procurements').orderBy('createdAt', descending: true).snapshots();
  }

  /// Export procurements as CSV string using provided docs. This is lightweight and pure string building.
  String procurementsToCsv(List<QueryDocumentSnapshot> docs) {
    final rows = <List<String>>[];
    rows.add(['Procurement ID', 'Date', 'Supplier', 'Invoice', 'Total Quantity', 'Total Cost', 'Item Count']);
    for (final d in docs) {
      final createdAt = parseTimestamp(d.get('createdAt'));
      final data = d.data() as Map<String, dynamic>? ?? {};
      final supplierName = data.containsKey('supplierName') ? (data['supplierName'] ?? '') : '';
      final invoiceRef = data.containsKey('invoiceRef') ? (data['invoiceRef'] ?? '') : '';
      rows.add([
        d.id,
        createdAt.toIso8601String(),
        supplierName,
        invoiceRef,
        '${(d.get('totalQuantity') as num?)?.toInt() ?? 0}',
        '${((d.get('totalCost') as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
        '${(d.get('itemsCount') as num?)?.toInt() ?? (d.get('items') as List?)?.length ?? 0}'
      ]);
      final items = (d.get('items') as List?)?.cast<dynamic>() ?? [];
      if (items.isNotEmpty) {
        rows.add(['-- Item Name', 'Qty', 'Unit Cost', 'Total']);
        for (final it in items) {
          rows.add(['    ${it['name'] ?? ''}', '${it['quantity']}', '${(it['cost'] ?? 0).toStringAsFixed(2)}', '${(it['total'] ?? 0).toStringAsFixed(2)}']);
        }
      }
      rows.add([]);
    }

    final csv = rows.map((r) => r.map((c) => '"${c.toString().replaceAll('"', '""')}"').join(',')).join('\n');
    return csv;
  }

  /// Stream procurements for a product by reading inventory/{productId}/procurements ordered by createdAt desc
  Stream<QuerySnapshot> productProcurementsStream({required String businessId, required String productId}) {
    return _firestore.collection('businesses').doc(businessId).collection('inventory').doc(productId).collection('procurements').orderBy('createdAt', descending: true).snapshots();
  }

  /// Get procurement master document by id
  Future<DocumentSnapshot> getProcurementById({required String businessId, required String procurementId}) {
    return _firestore.collection('businesses').doc(businessId).collection('procurements').doc(procurementId).get();
  }
}
