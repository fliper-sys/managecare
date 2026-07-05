import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/business_provider.dart';
import '../../../../providers/retail_provider.dart';
import '../utils/pump_config_cache.dart';

class PumpConfigurationScreen extends StatefulWidget {
  const PumpConfigurationScreen({super.key});

  @override
  State<PumpConfigurationScreen> createState() =>
      _PumpConfigurationScreenState();
}

class _PumpConfigurationScreenState extends State<PumpConfigurationScreen> {
  List<Map<String, dynamic>> _cachedPumps = [];
  bool _cacheLoaded = false;
  bool _isRefreshing = false;

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
      final cachedPumps = await PumpConfigCache.load(businessId);
      if (mounted) {
        setState(() {
          _cachedPumps = cachedPumps;
          _cacheLoaded = true;
        });
      }
      await retail.initialize(businessId);
    });
  }

  Future<void> _showPumpDialog({
    DocumentSnapshot<Map<String, dynamic>>? doc,
    Map<String, dynamic>? cachedPump,
  }) async {
    final data = doc?.data() ?? cachedPump ?? {};
    final pumpId = doc?.id ?? cachedPump?['id']?.toString();
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
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (pumps == null || businessId == null || businessId.isEmpty) return;
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

    if (pumpId == null || pumpId.isEmpty) {
      final docRef = pumps.doc();
      final pumpData = {
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };
      await PumpConfigCache.upsert(businessId, docRef.id, pumpData);
      if (mounted) {
        setState(() {
          _cachedPumps = PumpConfigCache.sort([
            ..._cachedPumps.where((pump) => pump['id'] != docRef.id),
            {
              ...pumpData,
              'id': docRef.id,
            },
          ]);
        });
      }
      await docRef.set(pumpData);
    } else {
      final pumpData = {
        ...data,
        ...payload,
        'id': pumpId,
        'isActive': data['isActive'] ?? true,
      };
      await PumpConfigCache.upsert(businessId, pumpId, pumpData);
      if (mounted) {
        setState(() {
          _cachedPumps = PumpConfigCache.sort([
            ..._cachedPumps.where((pump) => pump['id'] != pumpId),
            pumpData,
          ]);
        });
      }
      await pumps.doc(pumpId).set(payload, SetOptions(merge: true));
    }
  }

  void _syncCacheFromSnapshot(
    String businessId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final remotePumps = PumpConfigCache.sort(
      docs.map(PumpConfigCache.fromDoc).toList(),
    );
    if (remotePumps.isEmpty || PumpConfigCache.same(remotePumps, _cachedPumps)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await PumpConfigCache.save(businessId, remotePumps);
      if (!mounted) return;
      setState(() {
        _cachedPumps = remotePumps;
        _cacheLoaded = true;
      });
    });
  }

  Future<void> _deletePump(Map<String, dynamic> data) async {
    final pumpId = data['id']?.toString();
    if (pumpId == null || pumpId.isEmpty) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete pump'),
            content: Text('Delete pump ${data['pumpNumber'] ?? ''}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    final pumps = _pumpCollection();
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (pumps == null || businessId == null || businessId.isEmpty) return;

    try {
      await pumps.doc(pumpId).set({'isActive': false}, SetOptions(merge: true));
      await PumpConfigCache.remove(businessId, pumpId);
      if (!mounted) return;
      setState(() {
        _cachedPumps = PumpConfigCache.sort(
          _cachedPumps.where((pump) => pump['id'] != pumpId).toList(),
        );
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pump deleted')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete pump: $error')),
      );
    }
  }

  Future<void> _refreshPumps() async {
    final pumps = _pumpCollection();
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (pumps == null || businessId == null || businessId.isEmpty) return;

    setState(() => _isRefreshing = true);
    try {
      await context.read<RetailProvider>().loadProducts(forceRefresh: true);
      final snapshot =
          await pumps.where('isActive', isEqualTo: true).get();
      final activePumps = PumpConfigCache.sort(
        snapshot.docs.map(PumpConfigCache.fromDoc).toList(),
      );
      await PumpConfigCache.save(businessId, activePumps);
      if (!mounted) return;
      setState(() {
        _cachedPumps = activePumps;
        _cacheLoaded = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pumps refreshed')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh pumps: $error')),
      );
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pumps = _pumpCollection();
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pump Configuration'),
        actions: [
          IconButton(
            tooltip: 'Refresh pumps',
            onPressed: _isRefreshing ? null : _refreshPumps,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
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
                  .snapshots(includeMetadataChanges: true),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                if (businessId != null && businessId.isNotEmpty) {
                  _syncCacheFromSnapshot(businessId, docs);
                }
                final remotePumps = PumpConfigCache.sort(
                  docs.map(PumpConfigCache.fromDoc).toList(),
                );
                final displayPumps =
                    remotePumps.isNotEmpty ? remotePumps : _cachedPumps;
                if (snapshot.connectionState == ConnectionState.waiting &&
                    displayPumps.isEmpty &&
                    !_cacheLoaded) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (displayPumps.isEmpty) {
                  return const Center(
                    child: Text('No pumps configured yet'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: displayPumps.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final data = displayPumps[index];
                    DocumentSnapshot<Map<String, dynamic>>? doc;
                    for (final item in docs) {
                      if (item.id == data['id']) {
                        doc = item;
                        break;
                      }
                    }
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit pump',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showPumpDialog(
                                doc: doc,
                                cachedPump: data,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Delete pump',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deletePump(data),
                            ),
                          ],
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
