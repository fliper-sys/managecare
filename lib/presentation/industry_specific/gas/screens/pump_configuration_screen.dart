import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/business_provider.dart';
import '../../../../providers/retail_provider.dart';

class PumpConfigurationScreen extends StatefulWidget {
  const PumpConfigurationScreen({super.key});

  @override
  State<PumpConfigurationScreen> createState() =>
      _PumpConfigurationScreenState();
}

class _PumpConfigurationScreenState extends State<PumpConfigurationScreen> {
  bool _isFuelProduct(Product product) {
    final category = product.category.toLowerCase();
    return category.contains('fuel') ||
        category.contains('petroleum') ||
        category.contains('petrol') ||
        category.contains('diesel') ||
        category.contains('kerosene') ||
        category.contains('gas');
  }

  CollectionReference<Map<String, dynamic>>? _pumpCollection() {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('pump_configurations');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final businessId = context.read<BusinessProvider>().currentBusiness?.id;
      if (businessId == null || businessId.isEmpty) return;
      final retail = context.read<RetailProvider>();
      await retail.initialize(businessId);
    });
  }

  Future<void> _showPumpDialog({DocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final data = doc?.data() ?? {};
    final pumpNumberController =
        TextEditingController(text: data['pumpNumber']?.toString() ?? '');
    final modelController =
        TextEditingController(text: data['model']?.toString() ?? '');
    final serialController =
        TextEditingController(text: data['serialNumber']?.toString() ?? '');
    final manufacturerController =
        TextEditingController(text: data['manufacturer']?.toString() ?? '');
    final yearController =
        TextEditingController(text: data['manufactureYear']?.toString() ?? '');
    var selectedProductId = data['productId']?.toString();

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (dialogContext, setDialogState) {
                final products = context
                    .read<RetailProvider>()
                    .products
                    .where(_isFuelProduct)
                    .toList();
                if (selectedProductId == null && products.isNotEmpty) {
                  selectedProductId = products.first.id;
                }

                return AlertDialog(
                  title: Text(doc == null ? 'Add Pump' : 'Edit Pump'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: pumpNumberController,
                          decoration:
                              const InputDecoration(labelText: 'Pump number'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedProductId,
                          decoration: const InputDecoration(
                            labelText: 'Dispensing product',
                          ),
                          items: products
                              .map(
                                (product) => DropdownMenuItem(
                                  value: product.id,
                                  child: Text(
                                    '${product.name} (${product.unit})',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedProductId = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: modelController,
                          decoration:
                              const InputDecoration(labelText: 'Pump model'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: serialController,
                          decoration:
                              const InputDecoration(labelText: 'Serial number'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: manufacturerController,
                          decoration:
                              const InputDecoration(labelText: 'Manufacturer'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: yearController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Year of manufacture',
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Save'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;

    if (!confirmed) return;
    final pumps = _pumpCollection();
    if (pumps == null) return;
    final retail = context.read<RetailProvider>();
    final product = retail.products.firstWhere(
      (item) => item.id == selectedProductId,
      orElse: () => Product(
        id: selectedProductId ?? '',
        name: '',
        price: 0,
        stock: 0,
        category: 'Fuel',
      ),
    );

    final payload = {
      'pumpNumber': pumpNumberController.text.trim(),
      'productId': product.id,
      'productName': product.name,
      'productUnit': product.unit,
      'productPrice': product.price,
      'model': modelController.text.trim(),
      'serialNumber': serialController.text.trim(),
      'manufacturer': manufacturerController.text.trim(),
      'manufactureYear': yearController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (doc == null) {
      await pumps.add({
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
    } else {
      await pumps.doc(doc.id).set(payload, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pumps = _pumpCollection();
    return Scaffold(
      appBar: AppBar(title: const Text('Pump Configuration')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPumpDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Pump'),
      ),
      body: pumps == null
          ? const Center(child: Text('No business selected'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: pumps
                  .where('isActive', isEqualTo: true)
                  .orderBy('pumpNumber')
                  .snapshots(includeMetadataChanges: true),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                if (snapshot.connectionState == ConnectionState.waiting &&
                    docs.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No pumps configured yet'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.local_gas_station_rounded),
                        ),
                        title: Text('Pump ${data['pumpNumber'] ?? ''}'),
                        subtitle: Text(
                          '${data['productName'] ?? 'Fuel'}'
                          ' • ${data['manufacturer'] ?? ''}'
                          ' ${data['model'] ?? ''}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Edit pump',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _showPumpDialog(doc: doc),
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
