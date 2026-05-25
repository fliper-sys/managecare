import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/retail_provider.dart';
import '../providers/restaurant_provider.dart';

class RestaurantStockScreen extends StatefulWidget {
  const RestaurantStockScreen({super.key});

  @override
  State<RestaurantStockScreen> createState() => _RestaurantStockScreenState();
}

class _RestaurantStockScreenState extends State<RestaurantStockScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  bool _isSupplyProduct(Product product) {
    final category = product.category.toLowerCase();
    return category.contains('raw') ||
        category.contains('ingredient') ||
        category.contains('supply') ||
        category.contains('kitchen') ||
        category.contains('food');
  }

  bool _isLowStock(Product product) => product.stock <= 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final business = context.read<BusinessProvider>().currentBusiness;
      if (business == null) return;

      final retail = context.read<RetailProvider>();
      final restaurant = context.read<RestaurantProvider>();
      restaurant.setBusinessId(business.id);
      await retail.initialize(business.id);
      await restaurant.initializeWasteRecords(businessId: business.id);
    });
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openWasteDialog(Product product) async {
    final quantityController = TextEditingController();
    final reasonController = TextEditingController();
    String type = 'spoilage';

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setDialogState) => AlertDialog(
              title: Text('Record Stock Loss: ${product.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(
                          value: 'spoilage',
                          child: Text('Spoilage'),
                        ),
                        DropdownMenuItem(
                          value: 'leftover',
                          child: Text('Leftover'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => type = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        hintText: 'Available: ${product.stock}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        hintText: 'Explain why this stock is being removed',
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
            ),
          ),
        ) ??
        false;

    if (!confirmed) return;

    final quantity = double.tryParse(quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final restaurant = context.read<RestaurantProvider>();
    final retail = context.read<RetailProvider>();

    try {
      final record = await restaurant.recordWaste(
        productId: product.id,
        productName: product.name,
        quantity: quantity,
        type: type,
        reason: reasonController.text.trim().isEmpty
            ? 'No reason supplied'
            : reasonController.text.trim(),
        unit: product.unit,
        recordedById: auth.currentUser?.id,
        recordedByName: auth.currentUser?.fullName,
      );
      await retail.loadProducts();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${record.type.toUpperCase()} saved for ${product.name}. Remaining stock: ${record.remainingQuantity.toStringAsFixed(2)}',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save stock loss: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<RestaurantProvider, RetailProvider>(
      builder: (context, restaurant, retail, _) {
        final role = context.watch<AuthProvider>().currentUser?.role ?? '';
        final canViewLowStock = WorkerPermissions.hasPermission(
              role,
              'view_low_stock',
            ) ||
            WorkerPermissions.canManageInventory(role);
        final canManageInventory = WorkerPermissions.canManageInventory(role);
        final products = retail.products
            .where((product) {
              if (_query.isEmpty) return true;
              return product.name.toLowerCase().contains(_query) ||
                  product.category.toLowerCase().contains(_query);
            })
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        final supplyProducts = products.where(_isSupplyProduct).toList();
        final resaleProducts =
            products.where((product) => !_isSupplyProduct(product)).toList();
        final lowSupplyProducts =
            supplyProducts.where(_isLowStock).toList();
        final menuShortages = restaurant.menuItems.where((item) {
          if (!item.available) return true;
          final linkedStock = item.inventoryStock;
          if (linkedStock != null && linkedStock <= 0) return true;
          for (final ingredient in item.ingredients) {
            final matches =
                retail.products.where((p) => p.id == ingredient.productId);
            if (matches.isNotEmpty &&
                matches.first.stock < ingredient.quantityPerPortion) {
              return true;
            }
          }
          return false;
        }).toList();

        final wasteRecords = restaurant.wasteRecords.take(8).toList();
        final totalStockCount = products.fold<double>(
          0,
          (sum, product) => sum + product.stock,
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Restaurant Stock'),
            backgroundColor: AppColors.primary,
          ),
          backgroundColor: Colors.grey[50],
          body: RefreshIndicator(
            onRefresh: () async {
              final business = context.read<BusinessProvider>().currentBusiness;
              if (business == null) return;
              await retail.initialize(business.id);
              await restaurant.initializeWasteRecords(businessId: business.id);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StockStat(
                        label: 'Products',
                        value: products.length.toString(),
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StockStat(
                        label: 'Stock Units',
                        value: totalStockCount.toStringAsFixed(0),
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StockStat(
                        label: 'Loss Logs',
                        value: restaurant.wasteRecords.length.toString(),
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search products or categories',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 20),
                if (wasteRecords.isNotEmpty) ...[
                  const Text('Recent Leftovers / Spoilage',
                      style: AppTextStyles.heading5),
                  const SizedBox(height: 12),
                  ...wasteRecords.map((record) {
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: record.type == 'spoilage'
                              ? Colors.red.withOpacity(0.12)
                              : Colors.orange.withOpacity(0.12),
                          child: Icon(
                            record.type == 'spoilage'
                                ? Icons.delete_outline
                                : Icons.inventory_2_outlined,
                            color: record.type == 'spoilage'
                                ? Colors.red
                                : Colors.orange,
                          ),
                        ),
                        title: Text(record.productName),
                        subtitle: Text(
                          '${record.type} • ${record.quantity.toStringAsFixed(2)} ${record.unit} • ${record.reason}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatCurrency(record.costImpact),
                              style: AppTextStyles.body2.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Left: ${record.remainingQuantity.toStringAsFixed(2)}',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ],
                if (canViewLowStock) ...[
                  const Text('Menu Shortages', style: AppTextStyles.heading5),
                  const SizedBox(height: 12),
                  if (menuShortages.isEmpty)
                    const _InlineNotice(
                      text: 'No menu shortages detected from linked stock.',
                    )
                  else
                    ...menuShortages.map(
                      (item) => Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.restaurant_menu),
                          ),
                          title: Text(item.name),
                          subtitle: Text(
                            item.ingredients.isEmpty
                                ? 'Linked stock unavailable or item marked unavailable'
                                : item.ingredients
                                    .map((ingredient) =>
                                        '${ingredient.productName}: ${ingredient.quantityPerPortion} ${ingredient.unit}/portion')
                                    .join(', '),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Text('Supply Shortages', style: AppTextStyles.heading5),
                  const SizedBox(height: 12),
                  if (lowSupplyProducts.isEmpty)
                    const _InlineNotice(text: 'No low supply stock right now.')
                  else
                    ...lowSupplyProducts.map(
                      (product) => _stockTile(
                        product,
                        canManageInventory: canManageInventory,
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
                const Text('Inventory', style: AppTextStyles.heading5),
                const SizedBox(height: 12),
                if (products.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.24),
                      ),
                    ),
                    child: const Text('No restaurant inventory found yet.'),
                  )
                else
                  ...products.map((product) {
                    return Card(
                      child: ListTile(
                        title: Text(product.name),
                        subtitle: Text(
                          '${product.category} • ${product.stock.toStringAsFixed(2)} ${product.unit}',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              formatCurrency(product.price),
                              style: AppTextStyles.body2.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (canManageInventory)
                              OutlinedButton.icon(
                                onPressed: () => _openWasteDialog(product),
                                icon: const Icon(Icons.remove_circle_outline),
                                label: const Text('Log Loss'),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _stockTile(Product product, {required bool canManageInventory}) {
    return Card(
      child: ListTile(
        title: Text(product.name),
        subtitle: Text(
          '${product.category} - ${product.stock.toStringAsFixed(2)} ${product.unit}',
        ),
        trailing: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              formatCurrency(product.price),
              style: AppTextStyles.body2.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (canManageInventory)
              OutlinedButton.icon(
                onPressed: () => _openWasteDialog(product),
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('Log Loss'),
              ),
          ],
        ),
      ),
    );
  }
}

class _StockStat extends StatelessWidget {
  const _StockStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.24),
        ),
      ),
      child: Text(text),
    );
  }
}
