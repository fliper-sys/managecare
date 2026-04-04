import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/business_provider.dart';
import '../providers/restaurant_provider.dart';
import '../../../../providers/retail_provider.dart';

class ManageMenuScreen extends StatefulWidget {
  const ManageMenuScreen({super.key});

  @override
  State<ManageMenuScreen> createState() => _ManageMenuScreenState();
}

class _ManageMenuScreenState extends State<ManageMenuScreen> {
  bool _loading = false;

  List<MenuOptionChoice> _parseOptionChoices(String raw) {
    return raw
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .map((entry) {
          final parts = entry.split(':');
          final name = parts.first.trim();
          final price = parts.length > 1
              ? double.tryParse(parts.sublist(1).join(':').trim()) ?? 0.0
              : 0.0;
          return MenuOptionChoice(
            id: '${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${price.toStringAsFixed(2)}',
            name: name,
            priceModifier: price,
          );
        })
        .toList();
  }

  String _serializeOptionChoices(List<MenuOptionChoice> choices) {
    return choices
        .map((choice) => choice.priceModifier == 0
            ? choice.name
            : '${choice.name}:${choice.priceModifier}')
        .join(', ');
  }

  MenuOption? _findOption(List<MenuOption> options, String name) {
    for (final option in options) {
      if (option.name.toLowerCase() == name.toLowerCase()) {
        return option;
      }
    }
    return null;
  }

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

  Future<void> _showBlockedDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<bool> _ensureCanManageMenu({required bool isNew}) async {
    final businessProvider = context.read<BusinessProvider>();
    final access = await businessProvider.canAccessFeatureEnhanced(
      'product_management',
      context: 'restaurant_manage_menu',
    );

    if (!mounted) return false;
    if (!(access['ok'] as bool? ?? false)) {
      await _showBlockedDialog(
        title: 'Subscription required',
        message: businessProvider.getSubscriptionBlockedMessage(
          feature: 'product_management',
        ),
      );
      return false;
    }

    if (isNew) {
      final currentCount = context.read<RestaurantProvider>().menuItems.length;
      if (!businessProvider.isWithinLimit('menu_items', currentCount)) {
        await _showBlockedDialog(
          title: 'Menu limit reached',
          message: businessProvider.getLimitReachedMessage('menu_items'),
        );
        return false;
      }
    }

    return true;
  }

  Future<void> _showEditDialog({MenuItem? item}) async {
    final isNew = item == null;
    if (!await _ensureCanManageMenu(isNew: isNew)) return;

    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final categoryCtrl = TextEditingController(text: item?.category ?? '');
    final priceCtrl = TextEditingController(text: item != null ? item.price.toString() : '0');
    final costCtrl = TextEditingController(text: item?.cost?.toString() ?? '0');
    final prepCtrl = TextEditingController(text: item?.preparationTime.toString() ?? '15');
    final descCtrl = TextEditingController(text: item?.description ?? '');
    final soupCtrl = TextEditingController(
      text: _serializeOptionChoices(
        _findOption(item?.options ?? const [], 'Soup / Stew')?.choices ?? const [],
      ),
    );
    final proteinCtrl = TextEditingController(
      text: _serializeOptionChoices(
        _findOption(item?.options ?? const [], 'Protein Quantity')?.choices ??
            const [],
      ),
    );
    final serviceCtrl = TextEditingController(
      text: _serializeOptionChoices(
        _findOption(item?.options ?? const [], 'Service Style')?.choices ??
            const [],
      ),
    );
    String? selectedProductId = item?.inventoryProductId;

    final retail = Provider.of<RetailProvider>(context, listen: false);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) => AlertDialog(
          title: Text(isNew ? 'Add Menu Item' : 'Edit Menu Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    onChanged: (v) => setInnerState(() => selectedProductId = v),
                    decoration: const InputDecoration(labelText: 'Link Inventory Product (optional)'),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Kitchen Extras',
                      style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        setInnerState(() {
                          if (soupCtrl.text.trim().isEmpty) {
                            soupCtrl.text =
                                'Tomato Stew, Egusi, Ogbono, Okro, Vegetable Soup';
                          }
                          if (proteinCtrl.text.trim().isEmpty) {
                            proteinCtrl.text = 'Regular Meat, Double Meat, Triple Meat';
                          }
                          if (serviceCtrl.text.trim().isEmpty) {
                            serviceCtrl.text = 'Dine-in, Take-away';
                          }
                        });
                      },
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('Use Meal Preset'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: soupCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Soup / Stew Options',
                    helperText: 'Comma separated. Example: Egusi, Ogbono, Tomato Stew',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: proteinCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Protein Quantity Options',
                    helperText: 'Use name or name:price. Example: Double Meat:500',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: serviceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Service Style Options',
                    helperText: 'Example: Dine-in, Take-away',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: _loading ? null : () async {
              if (!await _ensureCanManageMenu(isNew: isNew)) return;

              final name = nameCtrl.text.trim();
              final category = categoryCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              final cost = double.tryParse(costCtrl.text.trim());
              final prep = int.tryParse(prepCtrl.text.trim()) ?? 15;
              final desc = descCtrl.text.trim();
              final options = <MenuOption>[
                if (soupCtrl.text.trim().isNotEmpty)
                  MenuOption(
                    id: 'soup_stew',
                    name: 'Soup / Stew',
                    choices: _parseOptionChoices(soupCtrl.text),
                  ),
                if (proteinCtrl.text.trim().isNotEmpty)
                  MenuOption(
                    id: 'protein_quantity',
                    name: 'Protein Quantity',
                    choices: _parseOptionChoices(proteinCtrl.text),
                  ),
                if (serviceCtrl.text.trim().isNotEmpty)
                  MenuOption(
                    id: 'service_style',
                    name: 'Service Style',
                    choices: _parseOptionChoices(serviceCtrl.text),
                  ),
              ];
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Menu item name is required')),
                );
                return;
              }
              if (price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Menu item price must be greater than zero'),
                  ),
                );
                return;
              }
              if (prep <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Preparation time must be greater than zero'),
                  ),
                );
                return;
              }

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
                options: options,
              );

              try {
                setState(() => _loading = true);
                if (isNew) {
                  await provider.addMenuItem(newItem);
                } else {
                  await provider.updateMenuItem(item.id, newItem);
                }
                if (mounted) Navigator.pop(ctx);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to save menu item: $e')),
                );
              } finally {
                if (mounted) {
                  setState(() => _loading = false);
                }
              }
            },
            child: _loading ? const SizedBox(width:20, height:20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
          ),
          ],
        ),
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
