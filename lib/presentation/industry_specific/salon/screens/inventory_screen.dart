import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/inventory_alerts_provider.dart';
import '../providers/salon_provider.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalonProvider>().loadProducts();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshInventory() async {
    await context.read<SalonProvider>().loadProducts();
  }

  void _resetForm() {
    _nameCtrl.clear();
    _qtyCtrl.text = '1';
    _priceCtrl.text = '0';
  }

  void _showAddProductDialog(SalonProvider provider) {
    _resetForm();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: _qtyCtrl,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final product = ProductItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: _nameCtrl.text.trim(),
                quantity: int.tryParse(_qtyCtrl.text) ?? 0,
                price: double.tryParse(_priceCtrl.text) ?? 0.0,
                minStock: 10,
                reorderQuantity: 50,
              );
              if (product.name.isEmpty) return;
              provider.addProduct(product);
              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditProductDialog(SalonProvider provider, ProductItem product) {
    _nameCtrl.text = product.name;
    _qtyCtrl.text = product.quantity.toString();
    _priceCtrl.text = product.price.toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: _qtyCtrl,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _resetForm();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final updated = ProductItem(
                id: product.id,
                name: _nameCtrl.text.trim(),
                quantity: int.tryParse(_qtyCtrl.text) ?? 0,
                price: double.tryParse(_priceCtrl.text) ?? 0.0,
                minStock: product.minStock,
                reorderQuantity: product.reorderQuantity,
              );
              if (updated.name.isEmpty) return;
              provider.updateProduct(updated);
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProduct(SalonProvider provider, ProductItem product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteProduct(product.id);
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showReorderDialog(
    SalonProvider provider,
    InventoryAlertsProvider alertsProvider,
    ProductItem product,
  ) {
    final reorderCtrl =
        TextEditingController(text: product.reorderQuantity.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reorder ${product.name}'),
        content: TextField(
          controller: reorderCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity to reorder'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final qty =
                  int.tryParse(reorderCtrl.text) ?? product.reorderQuantity;
              await alertsProvider.placeDirectReorderForProduct(
                product.id,
                product.name,
                qty,
              );
              if (!mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Reorder placed for ${product.name}')),
              );
            },
            child: const Text('Place Reorder'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SalonProvider>(
      builder: (context, provider, _) {
        final products = provider.products;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Inventory'),
            backgroundColor: AppColors.primary,
          ),
          backgroundColor: Colors.grey[50],
          body: RefreshIndicator(
            onRefresh: _refreshInventory,
            child: products.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 180),
                      Center(
                        child: Text(
                          'No inventory products yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final lowStock = product.quantity <= product.minStock;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: lowStock
                                ? Colors.orange.withOpacity(0.12)
                                : AppColors.primary.withOpacity(0.12),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: lowStock ? Colors.orange : AppColors.primary,
                            ),
                          ),
                          title: Text(product.name),
                          subtitle: Text(
                            'Qty: ${product.quantity} - ${formatCurrency(product.price)}${lowStock ? ' - LOW' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () =>
                                    provider.adjustProductQuantity(product.id, -1),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () =>
                                    provider.adjustProductQuantity(product.id, 1),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  final alertsProvider =
                                      context.read<InventoryAlertsProvider>();
                                  if (value == 'edit') {
                                    _showEditProductDialog(provider, product);
                                  }
                                  if (value == 'delete') {
                                    _confirmDeleteProduct(provider, product);
                                  }
                                  if (value == 'reorder') {
                                    _showReorderDialog(
                                      provider,
                                      alertsProvider,
                                      product,
                                    );
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                  PopupMenuItem(
                                    value: 'reorder',
                                    child: Text('Reorder'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddProductDialog(provider),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Add Product'),
          ),
        );
      },
    );
  }
}
