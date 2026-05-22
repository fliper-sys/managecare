import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/retail_provider.dart';

class GasStockScreen extends StatefulWidget {
  const GasStockScreen({super.key});

  @override
  State<GasStockScreen> createState() => _GasStockScreenState();
}

class _GasStockScreenState extends State<GasStockScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  bool _isFuelCategory(String category) {
    final normalized = category.trim().toLowerCase();
    return normalized.contains('fuel') ||
        normalized.contains('petrol') ||
        normalized.contains('diesel') ||
        normalized.contains('gas');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final business = context.read<BusinessProvider>().currentBusiness;
      if (business == null) return;
      await context.read<RetailProvider>().initialize(business.id);
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

  Future<void> _showAddFuelDialog() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final costController = TextEditingController();
    final stockController = TextEditingController();
    String unit = 'L';
    String category = 'fuel';

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setDialogState) => AlertDialog(
              title: const Text('Add Fuel Product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration:
                          const InputDecoration(labelText: 'Product name'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: const [
                        DropdownMenuItem(value: 'fuel', child: Text('Fuel')),
                        DropdownMenuItem(
                          value: 'petrol',
                          child: Text('Petrol'),
                        ),
                        DropdownMenuItem(
                          value: 'diesel',
                          child: Text('Diesel'),
                        ),
                        DropdownMenuItem(value: 'gas', child: Text('Gas')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => category = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: const [
                        DropdownMenuItem(value: 'L', child: Text('Litres (L)')),
                        DropdownMenuItem(
                          value: 'cyl',
                          child: Text('Cylinder'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => unit = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(labelText: 'Selling price'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: costController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Cost price'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stockController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(labelText: 'Opening stock'),
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

    final name = nameController.text.trim();
    final price = double.tryParse(priceController.text.trim()) ?? 0.0;
    final cost = double.tryParse(costController.text.trim()) ?? 0.0;
    final stock = double.tryParse(stockController.text.trim()) ?? 0.0;

    if (name.isEmpty || price <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid name and price')),
      );
      return;
    }

    await context.read<RetailProvider>().addProduct(
      Product(
        id: '',
        name: name,
        price: price,
        cost: cost,
        stock: stock,
        category: category,
        emoji: unit == 'cyl' ? '🛢' : '⛽',
        unit: unit,
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name added to gas stock'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _showAdjustStockDialog(Product product) async {
    final quantityController = TextEditingController();
    final priceController =
        TextEditingController(text: product.price.toStringAsFixed(2));
    final costController =
        TextEditingController(text: product.cost.toStringAsFixed(2));
    bool addToStock = true;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setDialogState) => AlertDialog(
              title: Text('Update ${product.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Add stock'),
                          icon: Icon(Icons.add_circle_outline),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Set stock'),
                          icon: Icon(Icons.edit_outlined),
                        ),
                      ],
                      selected: {addToStock},
                      onSelectionChanged: (selection) {
                        setDialogState(() => addToStock = selection.first);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: addToStock
                            ? 'Quantity to add'
                            : 'New stock quantity',
                        hintText:
                            'Current stock: ${product.stock.toStringAsFixed(2)}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(labelText: 'Selling price'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: costController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Cost price'),
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
                  child: const Text('Update'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirmed) return;

    final quantity = double.tryParse(quantityController.text.trim());
    final price = double.tryParse(priceController.text.trim()) ?? product.price;
    final cost = double.tryParse(costController.text.trim()) ?? product.cost;

    if (quantity == null || quantity < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity')),
      );
      return;
    }

    final nextStock = addToStock ? product.stock + quantity : quantity;
    await context.read<RetailProvider>().updateProduct(
      product.id,
      Product(
        id: product.id,
        name: product.name,
        price: price,
        cost: cost,
        wholesalePrice: product.wholesalePrice,
        stock: nextStock,
        category: product.category,
        imageUrl: product.imageUrl,
        barcode: product.barcode,
        emoji: product.emoji,
        unit: product.unit,
        saleUnit: product.resolvedSaleUnit,
        saleUnitMultiplier: product.resolvedSaleUnitMultiplier,
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${product.name} stock updated to ${nextStock.toStringAsFixed(2)} ${product.unit}',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RetailProvider>(
      builder: (context, retail, _) {
        final fuelProducts = retail.products
            .where((product) => _isFuelCategory(product.category))
            .where((product) {
              if (_query.isEmpty) return true;
              return product.name.toLowerCase().contains(_query) ||
                  product.category.toLowerCase().contains(_query);
            })
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        final totalStock =
            fuelProducts.fold<double>(0.0, (sum, item) => sum + item.stock);
        final stockValue = fuelProducts.fold<double>(
          0.0,
          (sum, item) => sum + (item.stock * item.cost),
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Gas Stock'),
            backgroundColor: AppColors.primary,
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showAddFuelDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Fuel Product'),
          ),
          body: RefreshIndicator(
            onRefresh: retail.loadProducts,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _GasStockStat(
                        label: 'Products',
                        value: fuelProducts.length.toString(),
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GasStockStat(
                        label: 'Fuel Stock',
                        value: totalStock.toStringAsFixed(1),
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GasStockStat(
                        label: 'Stock Value',
                        value: formatCurrency(stockValue),
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search fuel products',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 20),
                if (fuelProducts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.24),
                      ),
                    ),
                    child: const Text(
                      'No fuel products found yet. Add petrol, diesel, or gas stock here.',
                    ),
                  )
                else
                  ...fuelProducts.map(
                    (product) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.withOpacity(0.12),
                          child: Text(product.emoji),
                        ),
                        title: Text(product.name),
                        subtitle: Text(
                          '${product.category} - ${product.stock.toStringAsFixed(2)} ${product.unit}',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  formatCurrency(product.price),
                                  style: AppTextStyles.body2.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Cost ${formatCurrency(product.cost)}',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showAdjustStockDialog(product),
                              icon: const Icon(Icons.inventory_2_outlined),
                              label: const Text('Update'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GasStockStat extends StatelessWidget {
  const _GasStockStat({
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
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
