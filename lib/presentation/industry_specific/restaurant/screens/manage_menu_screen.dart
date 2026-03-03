import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/currency.dart';
import '../providers/restaurant_provider.dart';
import '../../../../providers/retail_provider.dart';

class ManageMenuScreen extends StatefulWidget {
  const ManageMenuScreen({super.key});

  @override
  State<ManageMenuScreen> createState() => _ManageMenuScreenState();
}

class _ManageMenuScreenState extends State<ManageMenuScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['openAdd'] == true) {
        _showEditDialog();
      }
    });
  }

  Future<void> _showEditDialog({MenuItem? item}) async {
    final isNew = item == null;
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final categoryCtrl = TextEditingController(text: item?.category ?? '');
    final priceCtrl = TextEditingController(text: item != null ? item.price.toString() : '0');
    final costCtrl = TextEditingController(text: item?.cost?.toString() ?? '0');
    final prepCtrl = TextEditingController(text: item?.preparationTime.toString() ?? '15');
    final descCtrl = TextEditingController(text: item?.description ?? '');
    String? selectedProductId = item?.inventoryProductId;

    final retail = Provider.of<RetailProvider>(context, listen: false);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNew ? 'Add Menu Item' : 'Edit Menu Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Category')),
              TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Selling price')),
              TextField(controller: costCtrl, decoration: const InputDecoration(labelText: 'Cost price (for inventory)')),
              TextField(controller: prepCtrl, decoration: const InputDecoration(labelText: 'Preparation time (mins)')),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 8),
              if (retail.products.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: selectedProductId,
                  items: retail.products
                      .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                      .toList(),
                  onChanged: (v) => selectedProductId = v,
                  decoration: const InputDecoration(labelText: 'Link Inventory Product (optional)'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: _loading ? null : () async {
              final name = nameCtrl.text.trim();
              final category = categoryCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              final cost = double.tryParse(costCtrl.text.trim());
              final prep = int.tryParse(prepCtrl.text.trim()) ?? 15;
              final desc = descCtrl.text.trim();
              if (name.isEmpty) return; // validation minimal

              final provider = Provider.of<RestaurantProvider>(context, listen: false);
              final newItem = MenuItem(
                id: item?.id ?? '',
                name: name,
                category: category,
                price: price,
                cost: cost,
                description: desc.isEmpty ? null : desc,
                preparationTime: prep,
                available: item?.available ?? true,
                inventoryProductId: selectedProductId,
              );

              setState(() => _loading = true);
              if (isNew) {
                await provider.addMenuItem(newItem);
              } else {
                await provider.updateMenuItem(item.id, newItem);
              }
              setState(() => _loading = false);
              if (mounted) Navigator.pop(ctx);
            },
            child: _loading ? const SizedBox(width:20, height:20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RestaurantProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Menu'), backgroundColor: AppColors.primary),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Menu Items', style: AppTextStyles.heading4),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showEditDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                )
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: provider.menuItems.isEmpty
                  ? const Center(child: Text('No menu items'))
                  : ListView.builder(
                      itemCount: provider.menuItems.length,
                      itemBuilder: (context, i) {
                        final m = provider.menuItems[i];
                        return Card(
                          child: ListTile(
                            title: Text(m.name, style: AppTextStyles.body1),
                            subtitle: Text('${m.category} • ${formatCurrency(m.price)} • Cost: ${m.cost != null ? formatCurrency(m.cost!) : '—'}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showEditDialog(item: m),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Confirm Delete'),
                                        content: const Text('Delete this menu item?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      await provider.deleteMenuItem(m.id);
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
      ),
    );
  }
}
