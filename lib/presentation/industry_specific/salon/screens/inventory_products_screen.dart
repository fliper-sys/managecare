import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../providers/salon_provider.dart';

class InventoryProductsScreen extends StatefulWidget {
  const InventoryProductsScreen({super.key});

  @override
  State<InventoryProductsScreen> createState() => _InventoryProductsScreenState();
}

class _InventoryProductsScreenState extends State<InventoryProductsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalonProvider>().loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        backgroundColor: AppColors.primary,
      ),
      body: Consumer<SalonProvider>(
        builder: (context, provider, _) {
          final products = provider.products;
          return Column(
            children: [
              if (provider.errorMessage != null && provider.errorMessage!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Material(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(child: Text(provider.errorMessage!)),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: provider.loadProducts,
                  child: products.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 180),
                            Center(child: Text('No inventory products yet')),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            final lowStock = product.quantity <= product.minStock;
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: lowStock
                                      ? Colors.orange.withOpacity(0.15)
                                      : AppColors.primary.withOpacity(0.12),
                                  child: Icon(
                                    Icons.inventory_2,
                                    color: lowStock ? Colors.orange : AppColors.primary,
                                  ),
                                ),
                                title: Text(product.name),
                                subtitle: Text(
                                  'Stock: ${product.quantity} - ${formatCurrency(product.price)}',
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      await _showProductDialog(context, provider, product: product);
                                    } else if (value == 'restock') {
                                      await provider.adjustProductQuantity(
                                        product.id,
                                        product.reorderQuantity,
                                      );
                                    } else if (value == 'delete') {
                                      await _confirmDelete(context, provider, product);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    PopupMenuItem(value: 'restock', child: Text('Restock')),
                                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(context, context.read<SalonProvider>()),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    SalonProvider provider,
    ProductItem product,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Product'),
            content: Text('Delete "${product.name}" from inventory?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;
    await provider.deleteProduct(product.id);
  }

  Future<void> _showProductDialog(
    BuildContext context,
    SalonProvider provider, {
    ProductItem? product,
  }) async {
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final qtyCtrl = TextEditingController(text: (product?.quantity ?? 0).toString());
    final priceCtrl = TextEditingController(text: (product?.price ?? 0).toStringAsFixed(2));
    final minStockCtrl = TextEditingController(text: (product?.minStock ?? 10).toString());
    final reorderQtyCtrl = TextEditingController(text: (product?.reorderQuantity ?? 50).toString());

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product == null ? 'Add Product' : 'Edit Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Unit Price'),
              ),
              TextField(
                controller: minStockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Low Stock Threshold'),
              ),
              TextField(
                controller: reorderQtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Reorder Quantity'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final quantity = int.tryParse(qtyCtrl.text.trim()) ?? 0;
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              final minStock = int.tryParse(minStockCtrl.text.trim()) ?? 10;
              final reorderQty = int.tryParse(reorderQtyCtrl.text.trim()) ?? 50;

              if (name.isEmpty) return;

              final payload = ProductItem(
                id: product?.id ?? 'prd_${DateTime.now().millisecondsSinceEpoch}',
                name: name,
                quantity: quantity,
                price: price,
                minStock: minStock,
                reorderQuantity: reorderQty,
              );

              if (product == null) {
                await provider.addProduct(payload);
              } else {
                await provider.updateProduct(payload);
              }

              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(product == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }
}

