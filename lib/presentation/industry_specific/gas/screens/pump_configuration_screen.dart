import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/business_provider.dart';
import '../../../../providers/retail_provider.dart';
import '../../../../services/managecare_api_client.dart';
import '../utils/pump_config_cache.dart';
import '../utils/pump_row_mapper.dart';

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

  // The custom backend doesn't implement Supabase's Realtime protocol, so a
  // genuine `.snapshots()` stream isn't possible here - poll instead, same
  // pattern used by every other migrated repository this session.
  static const _pollInterval = Duration(seconds: 15);

  bool _isFuelProduct(Product product) {
    final category = product.category.toLowerCase();
    return category.contains('fuel') ||
        category.contains('petroleum') ||
        category.contains('petrol') ||
        category.contains('diesel') ||
        category.contains('kerosene') ||
        category.contains('gas');
  }

  Stream<List<Map<String, dynamic>>> _pumpsStream(String businessId) async* {
    while (true) {
      try {
        final response = await ManagecareApiClient.instance
            .get('/api/pumps/$businessId/pumps', query: {'isActive': 'true'});
        final rows = ((response['data'] as List?) ?? []).cast<Map<String, dynamic>>();
        yield rows.map(pumpRowToJson).toList();
      } catch (_) {
        // Swallow transient errors between polls so the stream stays alive.
      }
      await Future.delayed(_pollInterval);
    }
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

  Future<void> _showPumpDialog({Map<String, dynamic>? existingPump}) async {
    final data = existingPump ?? {};
    final pumpId = data['id']?.toString();
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
                  title: Text(pumpId == null ? 'Add Pump' : 'Edit Pump'),
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
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return;
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
      'id': pumpId,
      'pump_number': pumpNumberController.text.trim(),
      'product_id': product.id,
      'product_name': product.name,
      'product_unit': product.unit,
      'product_price': product.price,
      'model': modelController.text.trim(),
      'serial_number': serialController.text.trim(),
      'manufacturer': manufacturerController.text.trim(),
      'manufacture_year': yearController.text.trim(),
    };

    try {
      final response = await ManagecareApiClient.instance
          .post('/api/pumps/$businessId/pumps', body: payload);
      final pumpData = pumpRowToJson(Map<String, dynamic>.from(response as Map));
      await PumpConfigCache.upsert(businessId, pumpData['id'].toString(), pumpData);
      if (mounted) {
        setState(() {
          _cachedPumps = PumpConfigCache.sort([
            ..._cachedPumps.where((pump) => pump['id'] != pumpData['id']),
            pumpData,
          ]);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save pump: $e')),
      );
    }
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

    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return;

    try {
      await ManagecareApiClient.instance.put(
        '/api/pumps/$businessId/pumps/$pumpId',
        body: {'is_active': false},
      );
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
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return;

    setState(() => _isRefreshing = true);
    try {
      await context.read<RetailProvider>().loadProducts(forceRefresh: true);
      final response = await ManagecareApiClient.instance
          .get('/api/pumps/$businessId/pumps', query: {'isActive': 'true'});
      final rows = ((response['data'] as List?) ?? []).cast<Map<String, dynamic>>();
      final activePumps = PumpConfigCache.sort(rows.map(pumpRowToJson).toList());
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
      body: businessId == null || businessId.isEmpty
          ? const Center(child: Text('No business selected'))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _pumpsStream(businessId),
              builder: (context, snapshot) {
                final docs = snapshot.data ?? [];
                if (docs.isNotEmpty) {
                  final remotePumps = PumpConfigCache.sort(docs);
                  if (!PumpConfigCache.same(remotePumps, _cachedPumps)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      await PumpConfigCache.save(businessId, remotePumps);
                      if (!mounted) return;
                      setState(() {
                        _cachedPumps = remotePumps;
                        _cacheLoaded = true;
                      });
                    });
                  }
                }
                final displayPumps =
                    docs.isNotEmpty ? PumpConfigCache.sort(docs) : _cachedPumps;
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
                              onPressed: () => _showPumpDialog(existingPump: data),
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
