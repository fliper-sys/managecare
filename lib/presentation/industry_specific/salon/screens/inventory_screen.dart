import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/salon_provider.dart';
import '../../../../providers/inventory_alerts_provider.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController(text: '0.0');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<SalonProvider>(context, listen: false);
      provider.loadProducts();
    });
  }

  Future<void> _refreshInventory() async {
    final provider = Provider.of<SalonProvider>(context, listen: false);
    await provider.loadProducts();
  }

  void _showAddProductDialog(SalonProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: _qtyCtrl,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number),
            TextField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'Price'),
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
              final price = double.tryParse(_priceCtrl.text) ?? 0.0;
              if (name.isEmpty) return;
              final p =
                  ProductItem(id: id, name: name, quantity: qty, price: price, minStock: 10, reorderQuantity: 50);
              provider.addProduct(p);
              _nameCtrl.clear();
              _qtyCtrl.text = '1';
              _priceCtrl.text = '0.0';
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: _qtyCtrl,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number),
            TextField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () {
                _nameCtrl.clear();
                _qtyCtrl.text = '1';
                _priceCtrl.text = '0.0';
                Navigator.of(context).pop();
              },
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = _nameCtrl.text.trim();
              final qty = int.tryParse(_qtyCtrl.text) ?? 0;
              final price = double.tryParse(_priceCtrl.text) ?? 0.0;
              if (name.isEmpty) return;
              final updated = ProductItem(
                id: product.id,
                name: name,
                quantity: qty,
                price: price,
                minStock: product.minStock,
                reorderQuantity: product.reorderQuantity,
              );
              provider.updateProduct(updated);
              _nameCtrl.clear();
              _qtyCtrl.text = '1';
              _priceCtrl.text = '0.0';
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
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
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

  void _showReorderDialog(SalonProvider provider, InventoryAlertsProvider alertsProvider, ProductItem product) {
    final _reorderCtrl = TextEditingController(text: product.reorderQuantity.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reorder ${product.name}'),
        content: TextField(
          controller: _reorderCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity to reorder'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final qty = int.tryParse(_reorderCtrl.text) ?? product.reorderQuantity;
              await alertsProvider.placeDirectReorderForProduct(product.id, product.name, qty);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reorder placed for ${product.name}')));
            },
            child: const Text('Place Reorder'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SalonProvider>(context);
    final products = provider.products;

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: RefreshIndicator(
        onRefresh: _refreshInventory,
        child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final p = products[index];
          return Card(
            child: ListTile(
              title: Text(p.name),
              subtitle:
                  Text('Qty: ${p.quantity} • \$${p.price.toStringAsFixed(2)}${p.quantity <= p.minStock ? ' • LOW' : ''}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => provider.adjustProductQuantity(p.id, -1),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => provider.adjustProductQuantity(p.id, 1),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    final alertsProvider = Provider.of<InventoryAlertsProvider>(context, listen: false);
                    if (value == 'edit') _showEditProductDialog(provider, p);
                    if (value == 'delete') _confirmDeleteProduct(provider, p);
                    if (value == 'reorder') _showReorderDialog(provider, alertsProvider, p);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                    PopupMenuItem(value: 'reorder', child: Text('Reorder')),
                  ],
                ),
              ]),
            ),
          );
        },
      ),
        ),
    
      
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddProductDialog(provider),
        child: const Icon(Icons.add_shopping_cart),
      ),
    );
  }
}

