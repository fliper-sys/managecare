import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/retail_provider.dart';
import '../../../../core/utils/worker_permissions.dart';

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
        normalized.contains('petroleum') ||
        normalized.contains('petrol') ||
        normalized.contains('diesel') ||
        normalized.contains('kerosene') ||
        normalized.contains('gas');
  }

  bool _isFuelProduct(Product product) {
    final normalized = [
      product.category,
      product.name,
      product.unit,
    ].join(' ').trim().toLowerCase();
    return _isFuelCategory(normalized);
  }

  CollectionReference<Map<String, dynamic>>? _historyCollection() {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('fuel_stock_procurement_history');
  }

  Future<void> _recordFuelStockHistory({
    required Product product,
    required double previousStock,
    required double nextStock,
    required double previousPrice,
    required double nextPrice,
    required double previousCost,
    required double nextCost,
    required String action,
    required double quantityChange,
  }) async {
    final history = _historyCollection();
    if (history == null) return;
    final user = context.read<AuthProvider>().currentUser;
    await history.add({
      'productId': product.id,
      'productName': product.name,
      'category': product.category,
      'unit': product.unit,
      'action': action,
      'quantityChange': quantityChange,
      'previousStock': previousStock,
      'nextStock': nextStock,
      'previousPrice': previousPrice,
      'nextPrice': nextPrice,
      'previousCost': previousCost,
      'nextCost': nextCost,
      'priceChanged': (previousPrice - nextPrice).abs() > 0.0001,
      'stockChanged': (previousStock - nextStock).abs() > 0.0001,
      'createdBy': user?.id,
      'createdById': user?.id,
      'createdByName': user?.fullName ?? user?.email,
      'createdByEmail': user?.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _openProcurementHistory() {
    final history = _historyCollection();
    if (history == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FuelStockProcurementHistoryScreen(history: history),
      ),
    );
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
                        DropdownMenuItem(
                          value: 'kerosene',
                          child: Text('Kerosene'),
                        ),
                        DropdownMenuItem(
                          value: 'petroleum',
                          child: Text('Petroleum'),
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
                        DropdownMenuItem(
                          value: 'gal',
                          child: Text('Gallons (gal)'),
                        ),
                        DropdownMenuItem(value: 'drum', child: Text('Drum')),
                        DropdownMenuItem(
                          value: 'kg',
                          child: Text('Kilogram (kg)'),
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

    await _recordFuelStockHistory(
      product: Product(
        id: '',
        name: name,
        price: price,
        cost: cost,
        stock: stock,
        category: category,
        unit: unit,
      ),
      previousStock: 0,
      nextStock: stock,
      previousPrice: 0,
      nextPrice: price,
      previousCost: 0,
      nextCost: cost,
      action: 'add_product',
      quantityChange: stock,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name added to fuel stock'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _showAdjustStockDialog(Product product) async {
    final quantityController = TextEditingController(text: '0');
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
    await _recordFuelStockHistory(
      product: product,
      previousStock: product.stock,
      nextStock: nextStock,
      previousPrice: product.price,
      nextPrice: price,
      previousCost: product.cost,
      nextCost: cost,
      action: addToStock ? 'add_stock' : 'set_stock',
      quantityChange: addToStock ? quantity : nextStock - product.stock,
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
    final auth = context.watch<AuthProvider>();
    final role = auth.currentUser?.role ?? '';
    final permissions = auth.currentUser?.permissions ?? [];
    final canAccessFuelStock = WorkerPermissions.canAccessFuelStockForUser(role, permissions);

    if (!canAccessFuelStock) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Fuel Stock'),
          backgroundColor: AppColors.primary,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text('Access denied', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('You do not have permission to view Fuel Stock.'),
              ],
            ),
          ),
        ),
      );
    }

    return Consumer<RetailProvider>(
      builder: (context, retail, _) {
        final fuelProducts = retail.products
            .where(_isFuelProduct)
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
            title: const Text('Fuel Stock'),
            backgroundColor: AppColors.primary,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Procurement history',
                icon: const Icon(Icons.history_rounded),
                onPressed: _openProcurementHistory,
              ),
              IconButton(
                tooltip: 'Procurement',
                icon: const Icon(Icons.shopping_bag_outlined),
                onPressed: () =>
                    Navigator.pushNamed(context, Routes.procurement),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showAddFuelDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Fuel Product'),
          ),
          body: RefreshIndicator(
            onRefresh: retail.loadProducts,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _GasHeader(
                  products: fuelProducts.length,
                  fuelStock: totalStock,
                  stockValue: stockValue,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'Search fuel products',
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.16),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (fuelProducts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.14),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.local_gas_station_outlined,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No fuel products found yet.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add petrol, diesel, kerosene, or gas stock to get started.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                else
                  ...fuelProducts.map(
                    (product) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _FuelProductCard(
                        product: product,
                        onUpdate: () => _showAdjustStockDialog(product),
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

class _GasHeader extends StatelessWidget {
  const _GasHeader({
    required this.products,
    required this.fuelStock,
    required this.stockValue,
  });

  final int products;
  final double fuelStock;
  final double stockValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fuel inventory overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Clean summary of products, stock levels, and valuation.',
            style: TextStyle(color: Colors.white.withOpacity(0.9)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _GasStatPill(
                  label: 'Products',
                  value: products.toString(),
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GasStatPill(
                  label: 'Fuel Stock',
                  value: fuelStock.toStringAsFixed(1),
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GasStatPill(
                  label: 'Stock Value',
                  value: formatCurrency(stockValue),
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GasStatPill extends StatelessWidget {
  const _GasStatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.88),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _FuelProductCard extends StatelessWidget {
  const _FuelProductCard({
    required this.product,
    required this.onUpdate,
  });

  final Product product;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: scheme.outline.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.orange.withOpacity(0.12),
                child: Text(
                  product.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product.category} • ${product.stock.toStringAsFixed(2)} ${product.unit}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: onUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Update'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PriceBadge(
                  label: 'Sell',
                  value: formatCurrency(product.price),
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PriceBadge(
                  label: 'Cost',
                  value: formatCurrency(product.cost),
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceBadge extends StatelessWidget {
  const _PriceBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _FuelStockProcurementHistoryScreen extends StatelessWidget {
  const _FuelStockProcurementHistoryScreen({required this.history});

  final CollectionReference<Map<String, dynamic>> history;

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  double _readDouble(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fuel Procurement History'),
        backgroundColor: AppColors.primary,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: history
            .orderBy('createdAt', descending: true)
            .limit(200)
            .snapshots(includeMetadataChanges: true),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          if (snapshot.connectionState == ConnectionState.waiting &&
              docs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (docs.isEmpty) {
            return const Center(
              child: Text('No fuel stock changes recorded yet.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final createdAt = _readDate(data['createdAt']);
              final quantityChange = _readDouble(data, 'quantityChange');
              final previousStock = _readDouble(data, 'previousStock');
              final nextStock = _readDouble(data, 'nextStock');
              final previousPrice = _readDouble(data, 'previousPrice');
              final nextPrice = _readDouble(data, 'nextPrice');
              final unit = data['unit']?.toString() ?? '';
              final recordedBy = (data['createdByName'] ?? data['createdBy'] ?? data['createdByEmail'])?.toString() ?? '';

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    child: const Icon(Icons.inventory_2_outlined),
                  ),
                  title: Text(data['productName']?.toString() ?? 'Fuel'),
                  subtitle: Text(
                    '${data['action'] ?? 'stock_change'}'
                    '${createdAt == null ? '' : ' • ${createdAt.toLocal()}'}'
                    '${recordedBy.isNotEmpty ? '\nBy: $recordedBy' : ''}'
                    '\nStock: ${previousStock.toStringAsFixed(2)} → ${nextStock.toStringAsFixed(2)} $unit\n'
                    'Price: ${formatCurrency(previousPrice)} → ${formatCurrency(nextPrice)}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    '${quantityChange >= 0 ? '+' : ''}${quantityChange.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: quantityChange >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
