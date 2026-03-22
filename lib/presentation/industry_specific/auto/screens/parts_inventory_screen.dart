import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/auto_provider.dart';

class PartsInventoryScreen extends StatefulWidget {
  const PartsInventoryScreen({super.key});

  @override
  State<PartsInventoryScreen> createState() => _PartsInventoryScreenState();
}

class _PartsInventoryScreenState extends State<PartsInventoryScreen> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '10');
  final _costCtrl = TextEditingController(text: '0.0');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  void _showAddPartDialog(AutoProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Part'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Part Name')),
            TextField(
                controller: _qtyCtrl,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number),
            TextField(
                controller: _costCtrl,
                decoration: const InputDecoration(labelText: 'Cost'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final id = DateTime.now().millisecondsSinceEpoch.toString();
              final name = _nameCtrl.text.trim();
              final qty = int.tryParse(_qtyCtrl.text) ?? 0;
              final cost = double.tryParse(_costCtrl.text) ?? 0.0;
              if (name.isEmpty) return;
              final p = Part(id: id, name: name, quantity: qty, cost: cost);
              provider.addPart(p);
              _nameCtrl.clear();
              _qtyCtrl.text = '10';
              _costCtrl.text = '0.0';
              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AutoProvider>(builder: (context, provider, _) {
      if (provider.isLoadingData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (provider.dataError != null) return Scaffold(body: Center(child: Text(provider.dataError!)));

      final parts = provider.parts;

      return Scaffold(
        appBar: AppBar(
            title: const Text('Parts Inventory'),
            backgroundColor: AppColors.primary),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Parts: ${parts.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                          'Total Value: ${formatCurrency(provider.getTotalPartsCost())}'),
                    ],
                  ),
                  Chip(
                    label: Text('${provider.getLowStockPartCount()} Low Stock'),
                    backgroundColor: Colors.orange.withOpacity(0.2),
                  ),
                ],
              ),
            ),
            Expanded(
              child: parts.isEmpty
                  ? const Center(child: Text('No parts in inventory'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: parts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final p = parts[index];
                        final isLowStock = p.quantity < 5;
                        return Card(
                          color: isLowStock ? Colors.red.withOpacity(0.05) : null,
                          child: ListTile(
                            leading: Icon(Icons.precision_manufacturing,
                                color: isLowStock ? Colors.red : Colors.blue),
                            title: Text(p.name),
                            subtitle: Text(
                                'Stock: ${p.quantity} - ${formatCurrency(p.cost)} each'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () {
                                    try {
                                      provider.adjustPartQuantity(p.id, -1);
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () {
                                    try {
                                      provider.adjustPartQuantity(p.id, 1);
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: provider.isLoadingData ? null : () => _showAddPartDialog(provider),
          child: const Icon(Icons.add),
        ),
      );
    });
  }
}

