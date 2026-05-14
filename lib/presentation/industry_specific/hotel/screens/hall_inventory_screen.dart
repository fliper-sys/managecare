import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../providers/business_provider.dart';

class HallInventoryScreen extends StatelessWidget {
  const HallInventoryScreen({super.key});

  CollectionReference<Map<String, dynamic>> _collection(String businessId) {
    return FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('halls');
  }

  Future<void> _showAddHallDialog(BuildContext context, String businessId) async {
    final nameCtrl = TextEditingController();
    final capacityCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final decorationCtrl = TextEditingController();
    final featuresCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Add Hall'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Hall Name'),
                  ),
                  TextField(
                    controller: capacityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Capacity'),
                  ),
                  TextField(
                    controller: costCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cost'),
                  ),
                  TextField(
                    controller: decorationCtrl,
                    decoration: const InputDecoration(labelText: 'Decoration'),
                  ),
                  TextField(
                    controller: featuresCtrl,
                    decoration: const InputDecoration(labelText: 'Features (comma separated)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Save'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    await _collection(businessId).add({
      'name': name,
      'capacity': int.tryParse(capacityCtrl.text.trim()) ?? 0,
      'cost': double.tryParse(costCtrl.text.trim()) ?? 0.0,
      'decoration': decorationCtrl.text.trim(),
      'features': featuresCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final business = context.watch<BusinessProvider>().currentBusiness;
    final businessId = business?.id;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hall Inventory'),
        backgroundColor: AppColors.primary,
      ),
      body: businessId == null || businessId.isEmpty
          ? const Center(child: Text('Select a business to continue'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _collection(businessId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No halls registered yet'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    return ListTile(
                      title: Text(data['name'] ?? ''),
                      subtitle: Text('Capacity: ${data['capacity']}, Cost: ₦${data['cost']}'),
                      trailing: Text((data['features'] as List<dynamic>? ?? []).join(', ')),
                    );
                  },
                );
              },
            ),
      floatingActionButton: businessId == null || businessId.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddHallDialog(context, businessId),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add),
              label: const Text('Add Hall'),
            ),
    );
  }
}
