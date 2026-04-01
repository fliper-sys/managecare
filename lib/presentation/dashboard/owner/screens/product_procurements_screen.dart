import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/text_styles.dart';

import '../../../../data/repositories/procurement_repository.dart';
import '../../../../core/utils/datetime_utils.dart';
import '../../../../core/utils/inventory_utils.dart';

class ProductProcurementsScreen extends StatelessWidget {
  final String businessId;
  final String productId;
  final String productName;

  const ProductProcurementsScreen({Key? key, required this.businessId, required this.productId, this.productName = ''}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMd().add_jm();
    final repo = ProcurementRepository();
    return Scaffold(
      appBar: AppBar(
        title: Text('Procurements for ${productName.isNotEmpty ? productName : productId}'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: repo.productProcurementsStream(businessId: businessId, productId: productId),
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text('Error loading procurements'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;
          if (docs.isEmpty) return Center(child: Text('No procurement records for this product', style: AppTextStyles.subtitle1));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, idx) {
              final d = docs[idx];
              final createdAt = parseTimestamp(d['createdAt'] ?? DateTime.now());
              final qty = (d['quantity'] as num?) ?? 0;
              final cost = ((d['cost'] ?? 0) as num).toDouble();
              final total = ((d['total'] ?? (qty.toDouble() * cost)) as num).toDouble();
              final procurementId = d['procurementId'] ?? '';

              return ListTile(
                title: Text('Qty: ${formatInventoryQuantity(qty)} • ₦${cost.toStringAsFixed(2)}'),
                subtitle: Text('${procurementId.isNotEmpty ? 'Batch: $procurementId • ' : ''}${dateFmt.format(createdAt)}'),
                trailing: Text('₦${total.toStringAsFixed(2)}'),
                onTap: () {
                  // navigate to procurement details: open parent procurement doc
                  if (procurementId.isNotEmpty) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ProcurementDetailViewer(businessId: businessId, productId: productId, procurementId: procurementId)));
                  }
                },
              );
            },
            separatorBuilder: (_, __) => const Divider(),
            itemCount: docs.length,
          );
        },
      ),
    );
  }
}

class _ProcurementDetailViewer extends StatelessWidget {
  final String businessId;
  final String productId;
  final String procurementId;

  const _ProcurementDetailViewer({Key? key, required this.businessId, required this.productId, required this.procurementId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final repo = ProcurementRepository();
    final dateFmt = DateFormat.yMMMd().add_jm();

    return Scaffold(
      appBar: AppBar(title: Text('Procurement $procurementId')),
      body: FutureBuilder<DocumentSnapshot>(
        future: repo.getProcurementById(businessId: businessId, procurementId: procurementId),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError || snap.data == null) return const Center(child: Text('Not found'));
          final d = snap.data!;
          final createdAt = parseTimestamp(d['createdAt'] ?? DateTime.now());
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Quantity: ${formatInventoryQuantity((d['totalQuantity'] as num?) ?? 0)}'),
                const SizedBox(height: 8),
                Text('Total Cost: ₦${(d['totalCost'] ?? 0).toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                Text('Items: ', style: AppTextStyles.caption),
                const SizedBox(height: 8),
                ...(d['items'] as List? ?? []).map((it) => ListTile(
                      dense: true,
                      title: Text(it['name'] ?? ''),
                      subtitle: Text('Qty: ${formatInventoryQuantity((it['quantity'] as num?) ?? 0)} • Unit Cost: ₦${(it['cost'] ?? 0).toStringAsFixed(2)}'),
                      trailing: Text('₦${(it['total'] ?? 0).toStringAsFixed(2)}'),
                    )),
                const SizedBox(height: 8),
                Text('Created: ${dateFmt.format(createdAt)}'),
              ],
            ),
          );
        },
      ),
    );
  }
}
