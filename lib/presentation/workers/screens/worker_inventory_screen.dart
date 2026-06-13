import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/worker_permissions.dart';
import '../../../providers/auth_provider.dart';
import '../../../data/local/database_helper.dart';
import '../../../services/sync_service.dart';

class WorkerInventoryScreen extends StatefulWidget {
  const WorkerInventoryScreen({super.key});

  @override
  State<WorkerInventoryScreen> createState() => _WorkerInventoryScreenState();
}

class _WorkerInventoryScreenState extends State<WorkerInventoryScreen> {
  final _searchController = TextEditingController();
  String _sortBy = 'name';
  bool _canEdit = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  void _checkPermissions() {
    final user = context.read<AuthProvider>().currentUser;
    _canEdit = user != null &&
        WorkerPermissions.canManageInventoryForUser(
          user.role,
          user.permissions,
        );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null ||
        !WorkerPermissions.canViewInventoryForUser(
          user.role,
          user.permissions,
        )) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Inventory'),
          backgroundColor: AppColors.primary,
        ),
        body: const Center(
          child: Text('You do not have permission to view inventory'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          if (_canEdit)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddProductDialog(),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Search products...',
                    leading: const Icon(Icons.search),
                  ),
                ),
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  initialValue: _sortBy,
                  onSelected: (value) {
                    setState(() => _sortBy = value);
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(
                      value: 'name',
                      child: Text('Sort by Name'),
                    ),
                    const PopupMenuItem(
                      value: 'quantity',
                      child: Text('Sort by Quantity'),
                    ),
                    const PopupMenuItem(
                      value: 'price',
                      child: Text('Sort by Price'),
                    ),
                  ],
                  child: const Icon(Icons.sort),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: 15, // Placeholder
              itemBuilder: (context, index) => _buildInventoryItem(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryItem(int index) {
    final lowStock = index % 5 == 0;
    final outOfStock = index % 7 == 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: outOfStock
          ? Colors.red.shade50
          : lowStock
              ? Colors.orange.shade50
              : null,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.inventory_2, size: 24),
        ),
        title: Text('Product ${index + 1}'),
        subtitle: Row(
          children: [
            Text('SKU: SKU${1000 + index}'),
            const SizedBox(width: 12),
            if (outOfStock)
              const Chip(
                label: Text('Out of Stock',
                    style: TextStyle(fontSize: 10, color: Colors.white)),
                backgroundColor: Colors.red,
              )
            else if (lowStock)
              const Chip(
                label: Text('Low Stock',
                    style: TextStyle(fontSize: 10, color: Colors.white)),
                backgroundColor: Colors.orange,
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Qty: ${100 - (index * 5)}'),
            Text('₦${5000 + (index * 100)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.primary)),
          ],
        ),
        onTap: () => _showProductDetails(index),
      ),
    );
  }

  void _showProductDetails(int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Product ${index + 1}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _detailRow('SKU', 'SKU${1000 + index}'),
              _detailRow('Category', 'General'),
              _detailRow('Current Stock', '${100 - (index * 5)} pcs'),
              _detailRow('Reorder Level', '10 pcs'),
              _detailRow('Cost Price', '₦${3000 + (index * 100)}'),
              _detailRow('Selling Price', '₦${5000 + (index * 100)}'),
              _detailRow('Last Updated', 'Today at 10:30 AM'),
              const SizedBox(height: 16),
              if (_canEdit) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditProductDialog(index);
                        },
                        child: const Text('Edit'),
                      ),
                    ),
                  ],
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final skuController = TextEditingController();
    final quantityController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Product Name'),
              ),
              TextField(
                controller: skuController,
                decoration: const InputDecoration(labelText: 'SKU'),
              ),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Selling Price'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = context.read<AuthProvider>();
              final user = authProvider.currentUser;
              final dbHelper = DatabaseHelper.instance;

              final id = DateTime.now().millisecondsSinceEpoch.toString();
              final name = nameController.text.trim();
              final sku = skuController.text.trim();
              final qty = double.tryParse(quantityController.text) ?? 0.0;
              final price = double.tryParse(priceController.text) ?? 0.0;

              final product = {
                'id': id,
                'businessId': user?.businessId ?? '',
                'storeId': user?.storeId ?? '',
                'name': name,
                'sku': sku,
                'barcode': null,
                'category': null,
                'description': null,
                'unitPrice': price,
                'costPrice': null,
                'quantity': qty,
                'minStockLevel': 0,
                'unit': 'pcs',
                'expiryDate': null,
                'isActive': 1,
                'createdAt': DateTime.now().toIso8601String(),
                'updatedAt': null,
                'syncStatus': 'pending',
              };

              try {
                await dbHelper.insert('inventory', product);
                await dbHelper.addToSyncQueue(
                  entityType: 'inventory',
                  entityId: id,
                  action: 'create',
                  data: product,
                );

                // Best-effort sync
                try {
                  final syncService = SyncService();
                  syncService.syncInventory();
                } catch (_) {}

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product added successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to add product: $e')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditProductDialog(int index) {
    final nameController = TextEditingController(text: 'Product ${index + 1}');
    final quantityController =
        TextEditingController(text: '${100 - (index * 5)}');
    final priceController =
        TextEditingController(text: '${5000 + (index * 100)}');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Product Name'),
              ),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Selling Price'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Product updated successfully')),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}

