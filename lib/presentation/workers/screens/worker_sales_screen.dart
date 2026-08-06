import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/connectivity_helper.dart';
import '../../../core/utils/worker_permissions.dart';
import '../../../core/extensions/list_extensions.dart';
import '../../../providers/auth_provider.dart';
import '../../../data/local/database_helper.dart';
import '../../../services/sync_service.dart';
import '../../../data/repositories/sales_repository_supabase.dart';
import '../../../widgets/async_button.dart';

class CartItem {
  final String id;
  final String name;
  final double price;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
  });
}

class WorkerSalesScreen extends StatefulWidget {
  const WorkerSalesScreen({super.key});

  @override
  State<WorkerSalesScreen> createState() => _WorkerSalesScreenState();
}

class _WorkerSalesScreenState extends State<WorkerSalesScreen> {
  final List<CartItem> _cartItems = [];
  final _searchController = TextEditingController();

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
        !WorkerPermissions.canManageSalesForUser(
          user.role,
          user.permissions,
        )) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sales'),
          backgroundColor: AppColors.primary,
        ),
        body: const Center(
          child: Text('You do not have permission to process sales'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Sales'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Search products...',
                    onChanged: (query) {
                      // Filter logic can be implemented here if needed
                    },
                    leading: const Icon(Icons.search),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: 10,
                    itemBuilder: (context, index) => _buildProductTile(
                      'Product ${index + 1}',
                      'SKU${1000 + index}',
                      5000.0 + (index * 100),
                      () => _addToCart(
                        'Product ${index + 1}',
                        5000.0 + (index * 100),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey.shade100,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Cart (${_cartItems.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _cartItems.isEmpty
                        ? const Center(child: Text('No items'))
                        : ListView.builder(
                            itemCount: _cartItems.length,
                            itemBuilder: (context, index) =>
                                _buildCartItem(_cartItems[index], index),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              '₦${_calculateTotal().toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed:
                              _cartItems.isEmpty ? null : () => _processSale(),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            backgroundColor: AppColors.primary,
                          ),
                          child: const Text('Checkout'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTile(
    String name,
    String sku,
    double price,
    VoidCallback onAdd,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(name),
        subtitle: Text('SKU: $sku'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('₦$price',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            IconButton(
              icon: const Icon(Icons.add_circle, color: AppColors.primary),
              onPressed: onAdd,
              iconSize: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(CartItem item, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('₦${item.price}', style: const TextStyle(fontSize: 10)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 14),
                      onPressed: () => _removeFromCart(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    Text('${item.quantity}',
                        style: const TextStyle(fontSize: 10)),
                    IconButton(
                      icon: const Icon(Icons.add, size: 14),
                      onPressed: () => _incrementQuantity(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(String productName, double price) {
    final existingItem =
        _cartItems.firstWhereOrNull((item) => item.name == productName);

    if (existingItem != null) {
      setState(() => existingItem.quantity++);
    } else {
      setState(() {
        _cartItems.add(CartItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: productName,
          price: price,
          quantity: 1,
        ));
      });
    }
  }

  void _removeFromCart(int index) {
    setState(() {
      if (_cartItems[index].quantity > 1) {
        _cartItems[index].quantity--;
      } else {
        _cartItems.removeAt(index);
      }
    });
  }

  void _incrementQuantity(int index) {
    setState(() => _cartItems[index].quantity++);
  }

  double _calculateTotal() {
    return _cartItems.fold(
        0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  void _processSale() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Sale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Items: ${_cartItems.length}'),
            Text('Total: ₦${_calculateTotal().toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            const Text('Payment method:'),
            const SizedBox(height: 8),
            DropdownButton<String>(
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'card', child: Text('Card')),
                DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
              ],
              value: 'cash',
              onChanged: null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          AsyncButton(
            onPressed: () async {
              Navigator.pop(context);
              await _completeSale();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Complete Sale'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeSale() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    final dbHelper = DatabaseHelper.instance;
    final total = _calculateTotal();

    final saleId = DateTime.now().millisecondsSinceEpoch.toString();

    // Build sale payload for server
    final saleForServer = {
      'id': saleId,
      'businessId': user?.businessId ?? '',
      'storeId': user?.storeId ?? '',
      'customerId': null,
      'items': _cartItems
          .map((i) => {
                'productId': i.id,
                'productName': i.name,
                'quantity': i.quantity,
                'unitPrice': i.price,
                'total': i.price * i.quantity,
              })
          .toList(),
      'totalAmount': total,
      'discountAmount': 0.0,
      'taxAmount': 0.0,
      'finalAmount': total,
      'paymentMethod': 'cash',
      'status': 'completed',
      'notes': null,
      'createdBy': user?.id ?? '',
      'createdAt': DateTime.now().toIso8601String(),
    };

    // Check connectivity up front rather than relying on the online write to
    // throw — with Firestore offline persistence enabled, writes resolve
    // locally without an exception even with no network, so that would
    // almost never trigger the offline fallback for genuinely offline sales.
    final hasNetwork = await ConnectivityHelper.hasInternetConnection();

    // Try to use domain use-case (CreateSale) first when online; fallback to
    // local DB + queue otherwise (or if the online attempt fails).
    if (hasNetwork) {
      try {
        final repo = SalesRepositorySupabase();
        await repo.createSale({
          'id': saleId,
          'businessId': saleForServer['businessId'],
          'store_id': saleForServer['storeId'],
          'customer_id': null,
          'total_amount': total,
          'discount_amount': 0.0,
          'tax_amount': 0.0,
          'final_amount': total,
          'payment_method': 'cash',
          'status': 'completed',
          'created_by': user?.id,
          'sale_type': 'retail',
          'items': (saleForServer['items'] as List).map((raw) {
            final item = raw as Map<String, dynamic>;
            return {
              'product_id': item['productId'],
              'product_name': item['productName'],
              'quantity': item['quantity'],
              'unit_price': item['unitPrice'],
              'discount': 0,
              'total': item['total'],
            };
          }).toList(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Sale completed and saved to server. Total: ₦${total.toStringAsFixed(2)}'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() => _cartItems.clear());
        return;
      } catch (e) {
        // Fallback: persist locally and queue for sync
      }
    }

    // Fallback path (offline or server error): persist locally and enqueue for sync
    final saleData = {
      'id': saleId,
      'businessId': user?.businessId ?? '',
      'storeId': user?.storeId ?? '',
      'customerId': null,
      'totalAmount': total,
      'discountAmount': 0.0,
      'taxAmount': 0.0,
      'finalAmount': total,
      'paymentMethod': 'cash',
      'status': 'completed',
      'notes': null,
      'createdBy': user?.id ?? '',
      'createdAt': DateTime.now().toIso8601String(),
      'syncStatus': 'pending',
    };

    try {
      await dbHelper.insert('sales', saleData);

      for (final item in _cartItems) {
        final itemId =
            DateTime.now().millisecondsSinceEpoch.toString() + item.id;
        final itemData = {
          'id': itemId,
          'saleId': saleId,
          'productId': item.id,
          'productName': item.name,
          'quantity': item.quantity,
          'unitPrice': item.price,
          'discount': 0.0,
          'total': item.price * item.quantity,
        };
        await dbHelper.insert('sale_items', itemData);
      }

      await dbHelper.addToSyncQueue(
        entityType: 'sale',
        entityId: saleId,
        action: 'create',
        data: saleData,
      );

      try {
        final syncService = SyncService();
        syncService.syncSales();
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Sale recorded offline and will sync when online. Total: ₦${total.toStringAsFixed(2)}'),
          backgroundColor: AppColors.warning,
        ),
      );

      setState(() => _cartItems.clear());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to record sale: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

