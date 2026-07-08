import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../providers/business_provider.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/datetime_utils.dart';
import '../../../../data/repositories/procurement_repository.dart';

class BakeryProcurementHistoryScreen extends StatelessWidget {
  const BakeryProcurementHistoryScreen({Key? key}) : super(key: key);

  Map<String, dynamic> _safeData(DocumentSnapshot doc) {
    final d = doc.data();
    if (d is Map) return Map<String, dynamic>.from(d);
    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null) return const Scaffold(body: Center(child: Text('No business selected')));

    return Scaffold(
      appBar: AppBar(title: const Text('Bakery Procurements')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('businesses').doc(businessId).collection('procurements').where('sourceType', isEqualTo: 'bakery').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text('Error loading')); 
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return Center(child: Text('No bakery procurements', style: AppTextStyles.subtitle1));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final d = docs[i];
              final data = _safeData(d);
              final createdAt = parseTimestamp(data['createdAt'] ?? DateTime.now());
              final total = (data['totalCost'] as num?)?.toDouble() ?? 0.0;
              final items = (data['items'] as List?) ?? [];
              return Card(
                child: ListTile(
                  title: Text('Procurement ${d.id} • ${DateFormat.yMMMd().format(createdAt)}'),
                  subtitle: Text('${items.length} item(s) • ₦${total.toStringAsFixed(2)}'),
                  onTap: () => showDialog(context: context, builder: (_) => AlertDialog(
                    title: Text('Procurement ${d.id}'),
                    content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Supplier: ${data['supplierName'] ?? ''}'),
                        const SizedBox(height: 8),
                        ...items.map((it) {
                          final m = it is Map ? Map<String, dynamic>.from(it) : <String, dynamic>{};
                          return ListTile(
                            title: Text(m['name'] ?? 'unnamed'),
                            subtitle: Text('Qty: ${m['quantity'] ?? 0} ${m['unit'] ?? ''} • Cost: ₦${(m['cost'] ?? 0).toStringAsFixed(2)}'),
                          );
                        }).toList(),
                      ],
                    ))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
