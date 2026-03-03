import 'package:flutter/material.dart';
import '../../../../core/utils/context_extensions.dart';
import '../providers/real_estate_provider.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  Future<void> _refreshInventory() async {
    // Simulate refresh with a small delay
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.tryRead<RealEstateProvider>();
    if (prov == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Property Inventory')),
        body: const Center(child: Text('Service not available. Try again.')),
      );
    }

    final items = prov.inventory;
    return Scaffold(
      appBar: AppBar(title: const Text('Property Inventory')),
      body: RefreshIndicator(
        onRefresh: _refreshInventory,
        child: items.isEmpty
          ? const Center(child: Text('No inventory items'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final it = items[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2),
                    title: Text(it.name),
                    subtitle: Text(
                        'Qty: ${it.qty} • Location: ${it.location ?? '-'}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await prov.deleteInventoryItem(it.id);
                      },
                    ),
                  ),
                );
              },
            ),
        ),
      
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // quick add sample
          await prov.saveInventoryItem(InventoryItem(
              id: '',
              name: 'Spare Lockset',
              qty: 2,
              location: 'Storage Room',
              createdAt: DateTime.now()));
        },
        child: const Icon(Icons.add),
    ),
    );
  }
}

