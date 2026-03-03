import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/datetime_utils.dart';
import '../../../../core/constants/routes.dart';

class PharmacySalesHistoryScreen extends StatelessWidget {
  const PharmacySalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sales History'), backgroundColor: AppColors.pharmacy),
        body: const Center(child: Text('No business selected')),
      );
    }

    final salesRef = FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('sales')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Sales History'), backgroundColor: AppColors.pharmacy),
      body: StreamBuilder<QuerySnapshot>(
        stream: salesRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error loading sales'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No sales recorded yet'));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final total = ((data['total'] ?? data['finalAmount'] ?? data['amount'] ?? 0) as num).toDouble();
              final createdAt = parseTimestamp(data['createdAt']);
              final items = (data['items'] as List<dynamic>?) ?? [];

              return Card(
                child: ListTile(
                  title: Text('₦${total.toStringAsFixed(2)}'),
                  subtitle: Text('${items.length} item(s) • ${createdAt.toLocal().toString().split('.')[0]}'),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, Routes.salesReceipt, arguments: {'saleId': doc.id});
                    },
                    child: const Text('View'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
