import '../../core/utils/inventory_utils.dart';
import '../../services/managecare_api_client.dart';

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

  final ManagecareApiClient _api;

  ProcurementRepository({ManagecareApiClient? api}) : _api = api ?? ManagecareApiClient.instance;

  // The custom backend doesn't implement Supabase's Realtime protocol, so
  // genuine `.snapshots()`-style streams aren't possible - poll instead,
  // same pattern used by every other migrated repository this session.
  static const _pollInterval = Duration(seconds: 15);

  Map<String, dynamic> _procurementRowToJson(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'businessId': row['business_id'],
      'supplierName': row['supplier_name'],
      'totalCost': row['total_amount'],
      'totalQuantity': row['total_quantity'],
      'itemsCount': row['items_count'],
      'status': row['status'],
      'notes': row['notes'],
      'invoiceRef': row['invoice_ref'],
      'referenceImageUrl': row['reference_image_url'],
      'storeId': row['store_id'],
      'storeName': row['store_name'],
      'sourceType': row['source_type'],
      'createdById': row['created_by'],
      'createdByName': row['created_by_name'],
      'createdByEmail': row['created_by_email'],
      'bakerId': row['baker_id'],
      'bakerName': row['baker_name'],
      'salesRepId': row['sales_rep_id'],
      'salesRepName': row['sales_rep_name'],
      'createdAt': row['created_at'],
      'items': row['items'],
    };
  }

  Map<String, dynamic> _batchRowToJson(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'procurementId': row['procurement_id'],
      'productId': row['inventory_id'],
      'batchLabel': row['batch_label'],
      'quantity': row['quantity'],
      'remainingQuantity': row['remaining_quantity'],
      'unit': row['unit'],
      'cost': row['cost'],
      'total': row['total'],
      'purchaseQuantity': row['purchase_quantity'],
      'purchaseUnit': row['purchase_unit'],
      'purchaseUnitCost': row['purchase_unit_cost'],
      'expiryDate': row['expiry_date'],
      'supplierName': row['supplier_name'],
      'invoiceRef': row['invoice_ref'],
      'referenceImageUrl': row['reference_image_url'],
      'createdAt': row['created_at'],
    };
  }

  /// Creates a procurement plus batch-aware inventory/procurement records in
  /// a single backend transaction. Returns the created procurement's id.
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
    final bakeryMetadata = buildBakeryProcurementMetadata(
      bakerId: bakerId,
      bakerName: bakerName,
      salesRepId: salesRepId,
      salesRepName: salesRepName,
    );

    final response = await _api.post('/api/procurement/$businessId', body: {
      'items': items.map((it) => {
            'product_id': it['productId'],
            'name': it['name'],
            'quantity': it['quantity'],
            'unit': it['unit'],
            'cost': it['cost'],
            'purchase_quantity': it['purchaseQuantity'],
            'purchase_unit': it['purchaseUnit'],
            'purchase_unit_cost': it['purchaseUnitCost'],
            'purchase_total': it['purchaseTotal'],
            'batch_label': it['batchLabel'],
            'expiry_date': it['expiryDate'],
          }).toList(),
      'supplier_name': supplierName,
      'invoice_ref': invoiceRef,
      'reference_image_url': referenceImageUrl,
      'created_by': createdById,
      'created_by_name': createdByName,
      'created_by_email': createdByEmail,
      'store_id': storeId,
      'store_name': storeName,
      'source_type': bakeryMetadata['sourceType'],
      'baker_id': bakeryMetadata['bakerId'],
      'baker_name': bakeryMetadata['bakerName'],
      'sales_rep_id': bakeryMetadata['salesRepId'],
      'sales_rep_name': bakeryMetadata['salesRepName'],
    });
    final row = Map<String, dynamic>.from(response as Map);
    return row['id'].toString();
  }

  Future<List<Map<String, dynamic>>> fetchProcurements({required String businessId, String? sourceType}) async {
    final response = await _api.get(
      '/api/procurement/$businessId',
      query: sourceType != null ? {'sourceType': sourceType} : null,
    );
    final rows = ((response['data'] as List?) ?? []).cast<Map<String, dynamic>>();
    return rows.map(_procurementRowToJson).toList();
  }

  /// Poll procurements for the business, newest first.
  Stream<List<Map<String, dynamic>>> procurementsStream({required String businessId, String? sourceType}) async* {
    while (true) {
      try {
        yield await fetchProcurements(businessId: businessId, sourceType: sourceType);
      } catch (_) {
        // Swallow transient errors between polls so the stream stays alive.
      }
      await Future.delayed(_pollInterval);
    }
  }

  /// Export procurements as CSV string.
  String procurementsToCsv(List<Map<String, dynamic>> procurements) {
    double asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value.replaceAll(',', '')) ?? 0.0;
      return 0.0;
    }

    String itemValue(Map item, List<String> keys) {
      for (final key in keys) {
        final value = item[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return '';
    }

    final rows = <List<String>>[];
    rows.add(['Procurement ID', 'Date', 'Supplier', 'Invoice', 'Baker', 'Sales Rep', 'Total Quantity', 'Total Cost', 'Item Count']);
    for (final d in procurements) {
      final createdAt = DateTime.tryParse(d['createdAt']?.toString() ?? '') ?? DateTime.now();
      rows.add([
        (d['id'] ?? '').toString(),
        createdAt.toIso8601String(),
        (d['supplierName'] ?? '').toString(),
        (d['invoiceRef'] ?? '').toString(),
        (d['bakerName'] ?? '').toString(),
        (d['salesRepName'] ?? '').toString(),
        formatInventoryQuantity((d['totalQuantity'] as num?) ?? 0),
        ((d['totalCost'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
        '${(d['itemsCount'] as num?)?.toInt() ?? (d['items'] as List?)?.length ?? 0}',
      ]);
      final items = (d['items'] as List?)?.cast<dynamic>() ?? [];
      if (items.isNotEmpty) {
        rows.add(['-- Date', 'Item Name', 'Qty', 'Unit', 'Purchase Unit', 'Purchase Unit Cost', 'Per Kg Cost', 'Unit Cost', 'Total']);
        for (final it in items) {
          final item = it is Map ? it : <String, dynamic>{};
          final itemDate = DateTime.tryParse(
                (item['createdAt'] ?? item['created_at'] ?? d['createdAt'] ?? '')
                    .toString(),
              ) ??
              createdAt;
          final purchaseUnit = itemValue(item, ['purchaseUnit', 'purchase_unit']);
          final unit = itemValue(item, ['unit', 'inventoryUnit', 'inventory_unit']);
          final purchaseUnitCost = asDouble(item['purchaseUnitCost'] ?? item['purchase_unit_cost']);
          final bagWeightKg = asDouble(item['bagWeightKg'] ?? item['bag_weight_kg']);
          String perKg = '';
          if (purchaseUnit.toLowerCase() == 'bag' && bagWeightKg > 0) {
            perKg = (purchaseUnitCost / bagWeightKg).toStringAsFixed(2);
          } else if (purchaseUnit.toLowerCase() == 'kg' || purchaseUnit.toLowerCase() == 'kilogram' || purchaseUnit.toLowerCase() == 'kgs') {
            perKg = purchaseUnitCost.toStringAsFixed(2);
          }
          rows.add([
            itemDate.toIso8601String(),
            itemValue(item, ['name', 'productName', 'product_name', 'itemName', 'item_name']),
            formatInventoryQuantity(asDouble(item['quantity'] ?? item['purchaseQuantity'] ?? item['purchase_quantity'])),
            unit,
            purchaseUnit,
            purchaseUnitCost.toStringAsFixed(2),
            perKg,
            asDouble(item['cost'] ?? item['unit_cost']).toStringAsFixed(2),
            asDouble(item['total'] ?? item['purchase_total']).toStringAsFixed(2),
          ]);
        }
      }
      rows.add([]);
    }

    return rows.map((r) => r.map((c) => '"${c.toString().replaceAll('"', '""')}"').join(',')).join('\n');
  }

  Future<List<Map<String, dynamic>>> fetchProductBatches({required String businessId, required String productId}) async {
    final response = await _api.get('/api/procurement/$businessId/product/$productId');
    final rows = ((response['data'] as List?) ?? []).cast<Map<String, dynamic>>();
    return rows.map(_batchRowToJson).toList();
  }

  /// Poll batches for a product ordered newest-first.
  Stream<List<Map<String, dynamic>>> productProcurementsStream({required String businessId, required String productId}) async* {
    while (true) {
      try {
        yield await fetchProductBatches(businessId: businessId, productId: productId);
      } catch (_) {
        // Swallow transient errors between polls so the stream stays alive.
      }
      await Future.delayed(_pollInterval);
    }
  }

  /// Get procurement master record by id.
  Future<Map<String, dynamic>?> getProcurementById({required String businessId, required String procurementId}) async {
    try {
      final response = await _api.get('/api/procurement/$businessId/$procurementId');
      return _procurementRowToJson(Map<String, dynamic>.from(response as Map));
    } catch (_) {
      return null;
    }
  }
}
