import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../services/email_service.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/inventory_utils.dart';
import '../../../../core/utils/search_utils.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/pharmacy_provider.dart';
import '../../../industry_specific/retail/screens/add_product_screen.dart';
import '../../../../providers/retail_provider.dart';
import 'package:intl/intl.dart';
import '../../../../services/notification_and_email_service.dart';
import 'procurement_history_screen.dart';
import 'product_procurements_screen.dart';
import '../../../../data/repositories/procurement_repository.dart';
import '../../../../data/local/shared_prefs_helper.dart';

class ProcurementScreen extends StatefulWidget {
  const ProcurementScreen({super.key});

  @override
  State<ProcurementScreen> createState() => _ProcurementScreenState();
}

class _ProcurementScreenState extends State<ProcurementScreen> {
  late TextEditingController _searchController;
  late TextEditingController _barcodeController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _isLoading = true;

  // Selection for batch procurement: productId -> { 'quantity': num/double, 'cost': double, 'product': Map }
  final Map<String, Map<String, dynamic>> _selectedItems = {};
  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  bool _isSubmitting = false; /* quantities can be fractional for liquids */

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _barcodeController = TextEditingController();
    _searchController.addListener(_filterProducts);
    _barcodeController.addListener(_filterByBarcode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _refreshProducts() async {
    // Reset the filtered list and reload all products
    _searchController.clear();
    _barcodeController.clear();
    _selectedCategory = null;
    if (mounted) {
      setState(() => _isLoading = true);
    }
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      // Prefer the currently selected business (supports owners with multiple businesses)
      final businessProvider = context.read<BusinessProvider>();
      final businessId = businessProvider.currentBusiness?.id;

      if (businessId == null || businessId.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      // Load products from inventory
      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('inventory')
          .get();

      final products = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'id': doc.id,
        };
      }).toList();

      // Also load inventory-like items from business documents (e.g., uploaded inventory sheets)
      final docsSnapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('documents')
          .get();

      final documentItems = <Map<String, dynamic>>[];
      for (final d in docsSnapshot.docs) {
        final ddata = d.data();
        // Consider documents that explicitly include inventory lists or items
        if (ddata.containsKey('items') && ddata['items'] is List) {
          final items = (ddata['items'] as List).cast<dynamic>();
          for (var i = 0; i < items.length; i++) {
            final it = items[i];
            if (it is Map<String, dynamic>) {
              documentItems.add({
                'id': '${d.id}_$i',
                ...it,
              });
            }
          }
        } else if (ddata.containsKey('inventory') &&
            ddata['inventory'] is List) {
          final items = (ddata['inventory'] as List).cast<dynamic>();
          for (var i = 0; i < items.length; i++) {
            final it = items[i];
            if (it is Map<String, dynamic>) {
              documentItems.add({
                'id': '${d.id}_$i',
                ...it,
              });
            }
          }
        }
        // If document name suggests inventory (e.g., "inventory.csv"), and contains raw data fields
        else if ((ddata['name'] ?? '')
                .toString()
                .toLowerCase()
                .contains('inventory') &&
            ddata.containsKey('data') &&
            ddata['data'] is List) {
          final items = (ddata['data'] as List).cast<dynamic>();
          for (var i = 0; i < items.length; i++) {
            final it = items[i];
            if (it is Map<String, dynamic>) {
              documentItems.add({
                'id': '${d.id}_$i',
                ...it,
              });
            }
          }
        }
      }

      // Merge and deduplicate using helper: prefer explicit inventory collection items over document-sourced ones
      var allProducts = mergeInventoryMaps(products, documentItems);

      // Include pharmacy drugs as inventory-like products (if any)
      try {
        final pharmacyProvider =
            Provider.of<PharmacyProvider>(context, listen: false);
        final pharmacyItems = pharmacyProvider.drugs
            .map((d) => {
                  'id': 'pharmacy_${d.id}',
                  'name': d.name,
                  'price': d.price,
                  'quantity': d.stock,
                  'category': 'Pharmacy',
                  'emoji': '💊',
                })
            .toList();

        // Merge, preferring explicit inventory collection items when names collide
        final existingNames = allProducts
            .map((p) => (p['name'] ?? '').toString().toLowerCase())
            .toSet();
        for (final pi in pharmacyItems) {
          if (!existingNames
              .contains((pi['name'] ?? '').toString().toLowerCase())) {
            allProducts.add(pi);
          }
        }
      } catch (_) {
        // ignore if provider not available
      }

      if (mounted) {
        // attempt to load saved category for this business
        final key = 'procurement_selected_category_${businessId ?? ''}';
        await SharedPrefsHelper.instance.init();
        final savedCat = SharedPrefsHelper.instance.getStringForKey(key);
        setState(() {
          _products = allProducts;
          _filteredProducts = allProducts;
          // derive categories from products
          final cats = <String>{};
          for (final p in allProducts) {
            final c = (p['category'] ?? 'Uncategorized').toString().trim();
            if (c.isNotEmpty) cats.add(c);
          }
          _categories = ['All', ...cats.toList()..sort()];
          _selectedCategory = (savedCat != null && savedCat.isNotEmpty && _categories.contains(savedCat)) ? savedCat : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ProcurementScreen] Error loading products: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterProducts() {
    final query = _searchController.text;
    setState(() {
      final base = query.isEmpty
          ? _products
          : _products.where((product) {
              final name = (product['name'] ?? '').toString();
              final sku = (product['sku'] ?? '').toString();
              final barcode = (product['barcode'] ?? '').toString();
              final category = (product['category'] ?? '').toString();

              // Use enhanced search for all fields with fuzzy matching
              return SearchUtils.matchesSearchQuery(
                      name, barcode.isNotEmpty ? barcode : null, query) ||
                  SearchUtils.matchesSearchQuery(sku, null, query) ||
                  SearchUtils.matchesSearchQuery(category, null, query);
            }).toList();

      if (_selectedCategory == null || _selectedCategory == 'All') {
        _filteredProducts = base.toList();
      } else {
        _filteredProducts = base
            .where((p) => (p['category'] ?? 'Uncategorized')
                .toString()
                .toLowerCase()
                .trim() == _selectedCategory!.toLowerCase().trim())
            .toList();
      }
    });
  }

  void _filterByBarcode() {
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) {
      _filterProducts();
      return;
    }

    setState(() {
      _filteredProducts = _products.where((product) {
        final productBarcode = (product['barcode'] ?? '').toString();
        // Use fuzzy barcode matching
        return SearchUtils.matchesBarcode(
            productBarcode.isNotEmpty ? productBarcode : null, barcode);
      }).toList();
    });

    // If exactly one product matches, auto-select it
    if (_filteredProducts.length == 1) {
      final product = _filteredProducts[0];
      _toggleSelect(product);
      _barcodeController.clear();
    }
  }

  Future<void> _scanBarcode() async {
    try {
      final navigator = Navigator.of(context);

      final result = await navigator.push<String>(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Scan Barcode'),
              backgroundColor: AppColors.primary,
            ),
            body: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final barcode = barcodes.first.rawValue;
                  if (barcode != null) {
                    navigator.pop(barcode);
                  }
                }
              },
            ),
          ),
        ),
      );

      if (result != null && result.isNotEmpty) {
        _barcodeController.text = result;
        _filterByBarcode();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Barcode scan failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _updateProductQuantity(
    Map<String, dynamic> product,
    num newQuantity,
  ) async {
    if (newQuantity < 0) return;

    try {
      final businessProvider = context.read<BusinessProvider>();
      final businessId = businessProvider.currentBusiness?.id;

      if (businessId == null) return;

      final productId = product['id'] as String?;
      if (productId == null) return;

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('inventory')
          .doc(productId)
          .update({'quantity': newQuantity});

      // Update local state
      final index = _products.indexWhere((p) => p['id'] == productId);
      if (index != -1) {
        _products[index]['quantity'] = newQuantity;
        _filterProducts(); // Refresh filtered list
      }

      if (mounted) {
        final productName = product['name'] ?? 'Product';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$productName quantity updated to $newQuantity'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ProcurementScreen] Error updating quantity: $e');
      if (mounted) {
        final productName = product['name'] ?? 'product';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating $productName'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final canAccess = auth.isOwnerUser ||
        auth.isAdminUser ||
        (user != null &&
            WorkerPermissions.canAccessProcurementForUser(
              user.role,
              user.permissions,
            ));

    if (!canAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Procurement Management')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Access denied: procurement access has not been granted to this worker.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Procurement Management'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
        actions: [
          IconButton(
            tooltip: 'Procurement History',
            icon: const Icon(Icons.history_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const ProcurementHistoryScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddProductScreen(),
            ),
          );
          if (result == true) {
            await _loadProducts();
          }
        },
        backgroundColor: AppColors.primary,
        label: const Text('Add Product'),
        icon: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Search & Barcode Input Section
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Product Name/SKU Search
                TextField(
                  controller: _searchController,
                  style: TextStyle(color: scheme.onPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search by product name, SKU, or category...',
                    hintStyle:
                        TextStyle(color: scheme.onPrimary.withOpacity(0.7)),
                    prefixIcon: Icon(Icons.search, color: scheme.onPrimary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: scheme.onPrimary),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: scheme.onPrimary.withOpacity(0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                // Barcode Input
                TextField(
                  controller: _barcodeController,
                  style: TextStyle(color: scheme.onPrimary),
                  decoration: InputDecoration(
                    hintText: 'Scan or enter barcode...',
                    hintStyle:
                        TextStyle(color: scheme.onPrimary.withOpacity(0.7)),
                    prefixIcon: Icon(Icons.qr_code_2, color: scheme.onPrimary),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_barcodeController.text.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.clear, color: scheme.onPrimary),
                            onPressed: () {
                              _barcodeController.clear();
                              _filterProducts();
                            },
                          ),
                        IconButton(
                          icon: Icon(Icons.camera_alt, color: scheme.onPrimary),
                          onPressed: _scanBarcode,
                          tooltip: 'Scan barcode',
                        ),
                      ],
                    ),
                    filled: true,
                    fillColor: scheme.onPrimary.withOpacity(0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                // Category filter chips
                if (_categories.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(top: 6, bottom: 6),
                      itemBuilder: (context, idx) {
                        final cat = _categories[idx];
                        final isSelected = (_selectedCategory == null && cat == 'All') || (_selectedCategory != null && _selectedCategory == cat);
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (_) async {
                            setState(() {
                              if (cat == 'All') {
                                _selectedCategory = null;
                              } else {
                                _selectedCategory = cat;
                              }
                              _filterProducts();
                            });
                            try {
                              final businessProvider = context.read<BusinessProvider>();
                              final businessIdKey = businessProvider.currentBusiness?.id ?? '';
                              final key = 'procurement_selected_category_$businessIdKey';
                              await SharedPrefsHelper.instance.init();
                              if (_selectedCategory == null) {
                                // clear saved selection
                                await SharedPrefsHelper.instance.setStringForKey(key, '');
                              } else {
                                await SharedPrefsHelper.instance.setStringForKey(key, _selectedCategory!);
                              }
                            } catch (_) {}
                          },
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemCount: _categories.length,
                    ),
                  ),
              ],
            ),
          ),

          // Products List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshProducts,
              color: AppColors.primary,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredProducts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No products found',
                                style: AppTextStyles.subtitle1.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredProducts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            return _ProductCard(
                              product: product,
                              isSelected:
                                  _selectedItems.containsKey(product['id']),
                              onSelectToggle: () => _toggleSelect(product),
                              onCardTap: () =>
                                  _openProductProcurements(product),
                              onIncrease: () {
                                final current =
                                    ((product['quantity'] ?? 0) as num);
                                _updateProductQuantity(product, current + 1);
                              },
                              onDecrease: () {
                                final current =
                                    ((product['quantity'] ?? 0) as num);
                                if (current > 0) {
                                  _updateProductQuantity(product, current - 1);
                                }
                              },
                              onQuantityChanged: (newQuantity) =>
                                  _updateProductQuantity(product, newQuantity),
                              onEdit: () async {
                                // Convert map to Product and open edit screen
                                final p = Product(
                                  id: product['id'] as String? ?? '',
                                  name: (product['name'] ?? '').toString(),
                                  price: ((product['price'] ?? 0) as num)
                                      .toDouble(),
                                  cost: ((product['cost'] ?? 0) as num)
                                      .toDouble(),
                                  wholesalePrice:
                                      (product['wholesalePrice'] as num?)
                                          ?.toDouble(),
                                  stock: ((product['quantity'] ?? 0) as num)
                                      .toDouble(),
                                  category:
                                      (product['category'] ?? 'Uncategorized')
                                          .toString(),
                                  imageUrl: product['imageUrl'] as String?,
                                  barcode: product['barcode'] as String?,
                                  unit: canonicalizeInventoryUnit(
                                    product['unit']?.toString(),
                                  ),
                                  saleUnit: canonicalizeInventoryUnit(
                                    product['saleUnit']?.toString(),
                                  ),
                                  saleUnitMultiplier:
                                      (product['saleUnitMultiplier'] as num?)
                                              ?.toDouble() ??
                                          1.0,
                                  emoji: product['emoji'] as String? ?? '📦',
                                );

                                final result = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AddProductScreen(product: p),
                                  ),
                                );

                                if (result == true) {
                                  await _loadProducts();
                                }
                              },
                            );
                          },
                        ),
            ),
          ),

          // Batch action bar when items are selected
          if (_selectedItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Theme.of(context).cardColor,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_selectedItems.length} items selected',
                            style: AppTextStyles.body2),
                        const SizedBox(height: 4),
                        Text(
                            'Total: ₦${_currencyFormat.format(_selectedItems.values.fold(0.0, (s, e) => s + ((e['quantity'] as num) * (e['cost'] as double))))}',
                            style: AppTextStyles.subtitle2
                                .copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check),
                    label: const Text('Submit Procurement'),
                    onPressed:
                        _isSubmitting ? null : _submitSelectedProcurement,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _toggleSelect(Map<String, dynamic> product) async {
    final id = product['id'] as String? ?? '';
    if (id.isEmpty) return;

    if (_selectedItems.containsKey(id)) {
      setState(() => _selectedItems.remove(id));
    } else {
      final defaultQty = 1;
      final defaultCost =
          ((product['cost'] ?? product['price'] ?? 0) as num).toDouble();
      // default unit is the product's unit if available
      final defaultUnit =
          canonicalizeInventoryUnit(product['unit']?.toString());
      setState(() {
        _selectedItems[id] = {
          'quantity': defaultQty,
          'cost': defaultCost,
          'unit': defaultUnit,
          'batchLabel': '',
          'expiryDate': null,
          'product': product,
        };
      });
      await Future.delayed(const Duration(milliseconds: 150));
      _editSelectedItem(id);
    }
  }

  DateTime? _coerceExpiryDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  Future<void> _editSelectedItem(String id) async {
    final entry = _selectedItems[id];
    if (entry == null) return;

    final product = entry['product'] as Map<String, dynamic>;
    final baseUnit =
        canonicalizeInventoryUnit((product['unit'] ?? '').toString());

    final qtyController =
        TextEditingController(text: (entry['quantity'] as num).toString());
    final costController =
        TextEditingController(text: (entry['cost'] as double).toString());
    final batchLabelController = TextEditingController(
      text: (entry['batchLabel'] ?? '').toString(),
    );
    String selectedUnit = canonicalizeInventoryUnit(
      (entry['unit'] as String?) ?? (baseUnit.isNotEmpty ? baseUnit : 'pc'),
    );
    DateTime? selectedExpiryDate = _coerceExpiryDate(entry['expiryDate']);

    final sortedUnits = getCompatibleProcurementUnits(baseUnit);

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
                title: const Text('Edit selected product'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(entry['product']['name'] ?? ''),
                    const SizedBox(height: 8),
                    TextField(
                      controller: qtyController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Quantity to add'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedUnit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: sortedUnits
                          .map(
                            (u) => DropdownMenuItem(
                              value: u,
                              child: Text(inventoryUnitLabel(u)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() {
                        selectedUnit = v ?? selectedUnit;
                      }),
                    ),
                    const SizedBox(height: 8),
                    // UX hint: show conversion note when user selects 'ton' for products tracked in 'kg'
                    if (selectedUnit == 'ton' && baseUnit == 'kg')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Note: quantities entered in tons will be converted to kilograms on save (1 ton = 1000 kg).',
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (selectedUnit != baseUnit && baseUnit.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Icon(Icons.sync_alt,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Enter the cost per ${inventoryUnitLabel(selectedUnit)}. The app will convert it to ${inventoryUnitLabel(baseUnit)} before saving the batch.',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextField(
                      controller: costController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText:
                            'Cost per ${inventoryUnitLabel(selectedUnit)}',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: batchLabelController,
                      decoration: const InputDecoration(
                        labelText: 'Batch label / code (optional)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_available_outlined),
                      title: const Text('Expiry date'),
                      subtitle: Text(
                        selectedExpiryDate == null
                            ? 'No expiry selected'
                            : DateFormat('dd MMM yyyy')
                                .format(selectedExpiryDate!),
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedExpiryDate ??
                                DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => selectedExpiryDate = picked);
                          }
                        },
                        child: Text(selectedExpiryDate == null
                            ? 'Pick date'
                            : 'Change'),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Save')),
                ],
              )),
    );

    if (result == true) {
      final newQty =
          double.tryParse(qtyController.text) ?? (entry['quantity'] as num);
      final newCost =
          double.tryParse(costController.text) ?? (entry['cost'] as double);
      setState(() {
        _selectedItems[id]!['quantity'] = newQty;
        _selectedItems[id]!['cost'] = newCost;
        _selectedItems[id]!['unit'] = canonicalizeInventoryUnit(selectedUnit);
        _selectedItems[id]!['batchLabel'] = batchLabelController.text.trim();
        _selectedItems[id]!['expiryDate'] = selectedExpiryDate;
      });
    }
  }

  void _openProductProcurements(Map<String, dynamic> product) {
    final id = product['id'] as String? ?? '';
    if (id.isEmpty) return;
    final businessId =
        context.read<BusinessProvider>().currentBusiness?.id ?? '';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductProcurementsScreen(
          businessId: businessId,
          productId: id,
          productName: product['name'] ?? ''),
    ));
  }

  Future<void> _submitSelectedProcurement() async {
    if (_selectedItems.isEmpty) return;
    if (_isSubmitting) return;

    final dialogResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) {
        final suppliers = context.read<RetailProvider>().suppliers;
        String? selectedSupplierId =
            suppliers.isNotEmpty ? suppliers.first.id : null;
        String? selectedSupplierName =
            suppliers.isNotEmpty ? suppliers.first.name : null;
        final invoiceController = TextEditingController();

        // Reference image upload state
        String? uploadedReferenceImageUrl;
        bool isUploadingReferenceImage = false;
        String? referenceImageError;

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Confirm procurement'),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                  minWidth: 280,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        'Are you sure you want to increase stock for ${_selectedItems.length} items and record procurement?'),
                    const SizedBox(height: 16),

                    // Reference Image Upload Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                            width: 1),
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.primary.withOpacity(0.05),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: Row(
                              children: const [
                                Icon(Icons.image_outlined,
                                    size: 18, color: AppColors.primary),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                      'Reference Image (optional)',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Show preview if image uploaded
                          if (uploadedReferenceImageUrl != null) ...[
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: CachedNetworkImage(
                                  imageUrl: uploadedReferenceImageUrl!,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: AppColors.primary.withOpacity(0.1),
                                    child: const Center(
                                        child: CircularProgressIndicator()),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    color: AppColors.error.withOpacity(0.1),
                                    child:
                                        const Center(child: Icon(Icons.error)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Upload button
                          ElevatedButton.icon(
                            onPressed: isUploadingReferenceImage
                                ? null
                                : () async {
                                    try {
                                      final picker = ImagePicker();
                                      final xfile = await picker.pickImage(
                                          source: ImageSource.gallery,
                                          imageQuality: 85);
                                      if (xfile == null) return;

                                      final bytes = await xfile.readAsBytes();
                                      final filename = xfile.name;

                                      setState(() {
                                        isUploadingReferenceImage = true;
                                        referenceImageError = null;
                                      });

                                      final url = await EmailService()
                                          .uploadBytes(bytes, filename);

                                      if (url == null) {
                                        setState(() {
                                          referenceImageError = 'Upload failed';
                                          isUploadingReferenceImage = false;
                                        });
                                        return;
                                      }

                                      final cachebustedUrl =
                                          '$url?t=${DateTime.now().millisecondsSinceEpoch}';
                                      setState(() {
                                        uploadedReferenceImageUrl =
                                            cachebustedUrl;
                                        isUploadingReferenceImage = false;
                                        referenceImageError = null;
                                      });
                                    } catch (e) {
                                      setState(() {
                                        referenceImageError = 'Error: $e';
                                        isUploadingReferenceImage = false;
                                      });
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: uploadedReferenceImageUrl != null
                                  ? AppColors.success
                                  : AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              minimumSize: const Size(double.infinity, 36),
                            ),
                            icon: isUploadingReferenceImage
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Icon(
                                    uploadedReferenceImageUrl != null
                                        ? Icons.check_circle
                                        : Icons.photo_library,
                                    size: 16),
                            label: Text(
                              isUploadingReferenceImage
                                  ? 'Uploading...'
                                  : uploadedReferenceImageUrl != null
                                      ? 'Image Added'
                                      : 'Select Reference Image',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),

                          if (referenceImageError != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline,
                                      color: AppColors.error, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      referenceImageError!,
                                      style: TextStyle(
                                          color: AppColors.error, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Supplier and Invoice fields
                    if (suppliers.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: selectedSupplierId,
                        items: suppliers
                            .map((s) => DropdownMenuItem(
                                value: s.id, child: Text(s.name)))
                            .toList(),
                        onChanged: (v) {
                          final s = suppliers.firstWhere((sup) => sup.id == v,
                              orElse: () => suppliers.first);
                          setState(() {
                            selectedSupplierId = s.id;
                            selectedSupplierName = s.name;
                          });
                        },
                        decoration: const InputDecoration(
                            labelText: 'Supplier (optional)'),
                      ),
                    if (suppliers.isNotEmpty) const SizedBox(height: 12),
                    TextField(
                      controller: invoiceController,
                      decoration: const InputDecoration(
                          labelText: 'Invoice / Reference (optional)'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: isUploadingReferenceImage
                      ? null
                      : () => Navigator.of(context).pop({
                            'supplierId': selectedSupplierId,
                            'supplierName': selectedSupplierName,
                            'invoiceRef': invoiceController.text.isNotEmpty
                                ? invoiceController.text
                                : null,
                            'referenceImageUrl': uploadedReferenceImageUrl,
                          }),
                  child: const Text('Confirm')),
            ],
          );
        });
      },
    );

    if (dialogResult == null) return;

    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final business = context.read<BusinessProvider>().currentBusiness;
      final auth = context.read<AuthProvider>();
      final currentUser = auth.currentUser;
      final procurementCreatedAt = DateTime.now();
      String? storeName;
      if ((currentUser?.storeId ?? '').isNotEmpty) {
        try {
          final storeDoc = await FirebaseFirestore.instance
              .collection('businesses')
              .doc(businessId)
              .collection('stores')
              .doc(currentUser!.storeId)
              .get();
          storeName =
              ((storeDoc.data() ?? const <String, dynamic>{})['name']
                      as String?)
                  ?.trim();
        } catch (e) {
          debugPrint(
              '[ProcurementScreen] Failed to resolve store name: $e');
        }
      }
      final items = _selectedItems.entries.map((e) {
        final prod = e.value['product'] as Map<String, dynamic>;
        final selectedUnit = canonicalizeInventoryUnit(
          (e.value['unit'] as String?) ?? (prod['unit'] ?? ''),
        );
        final baseUnit =
            canonicalizeInventoryUnit((prod['unit'] ?? '').toString());
        final qty = (e.value['quantity'] as num?) ?? 0;
        final rawUnitCost = (e.value['cost'] as num?)?.toDouble() ?? 0.0;
        final normalizedQty = normalizeProcurementQuantity(
          qty,
          selectedUnit,
          baseUnit.isNotEmpty ? baseUnit : selectedUnit,
        );
        final lineTotal = qty.toDouble() * rawUnitCost;
        final normalizedUnitCost = normalizedQty == 0
            ? rawUnitCost
            : lineTotal / (normalizedQty as num).toDouble();
        return {
          'productId': prod['id'] ?? '',
          'name': prod['name'] ?? '',
          'quantity': normalizedQty,
          'unit': baseUnit.isNotEmpty ? baseUnit : selectedUnit,
          'cost': normalizedUnitCost,
          'purchaseQuantity': qty,
          'purchaseUnit': selectedUnit,
          'purchaseUnitCost': rawUnitCost,
          'purchaseTotal': lineTotal,
          'batchLabel': (e.value['batchLabel'] as String?)?.trim(),
          'expiryDate': e.value['expiryDate'],
        };
      }).toList();

      final repo = ProcurementRepository();
      final id = await repo.createBatchProcurement(
        businessId: businessId,
        items: items,
        supplierId: dialogResult['supplierId'],
        supplierName: dialogResult['supplierName'],
        invoiceRef: dialogResult['invoiceRef'],
        referenceImageUrl: dialogResult['referenceImageUrl'],
        createdById: currentUser?.id,
        createdByName: currentUser?.fullName,
        createdByEmail: currentUser?.email,
        storeId: currentUser?.storeId,
        storeName: storeName,
      );

      final totalCost = items.fold<double>(0.0, (sum, item) {
        final value = item['purchaseTotal'] ?? item['total'] ?? 0;
        return sum + ((value is num)
            ? value.toDouble()
            : (double.tryParse(value.toString()) ?? 0.0));
      });
      final totalQuantity = items.fold<double>(0.0, (sum, item) {
        final value = item['purchaseQuantity'] ?? item['quantity'] ?? 0;
        return sum + ((value is num)
            ? value.toDouble()
            : (double.tryParse(value.toString()) ?? 0.0));
      });

      String ownerEmail = '';
      if ((business?.ownerId ?? '').isNotEmpty) {
        try {
          final ownerDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(business!.ownerId)
              .get();
          ownerEmail =
              ((ownerDoc.data() ?? const <String, dynamic>{})['email']
                          as String? ??
                      '')
                  .trim();
        } catch (e) {
          debugPrint(
              '[ProcurementScreen] Failed to resolve owner email: $e');
        }
      }
      if (ownerEmail.isEmpty) {
        ownerEmail = (business?.email ?? '').trim();
      }
      if (ownerEmail.isEmpty &&
          currentUser?.id == business?.ownerId) {
        ownerEmail = (currentUser?.email ?? '').trim();
      }

      if (ownerEmail.isNotEmpty && business != null) {
        final notifier = NotificationAndEmailService();
        final emailSent = await notifier.sendProcurementNotification(
          ownerEmail: ownerEmail,
          businessName: business.name,
          procurementId: id,
          items: items,
          totalCost: totalCost,
          totalQuantity: totalQuantity,
          itemsCount: items.length,
          createdByName:
              currentUser?.fullName?.trim().isNotEmpty == true
                  ? currentUser!.fullName
                  : 'Business Team',
          createdByEmail: currentUser?.email,
          supplierName: dialogResult['supplierName']?.toString(),
          invoiceRef: dialogResult['invoiceRef']?.toString(),
          storeName: storeName,
          referenceImageUrl:
              dialogResult['referenceImageUrl']?.toString(),
          createdAt: procurementCreatedAt,
        );
        try {
          await notifier.logNotificationEvent(
            businessId: businessId,
            type: 'procurement',
            channel: 'email',
            recipient: ownerEmail,
            success: emailSent,
            orderId: id,
          );
        } catch (e) {
          debugPrint(
              '[ProcurementScreen] Procurement notification log failed: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Procurement $id recorded for ${items.length} items'),
            backgroundColor: AppColors.success));
      }

      setState(() {
        _selectedItems.clear();
        _isSubmitting = false;
      });

      await _loadProducts();
    } catch (e) {
      debugPrint('[ProcurementScreen] Error submitting procurement: $e');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Error submitting procurement'),
            backgroundColor: AppColors.error));
      setState(() => _isSubmitting = false);
    }
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final Function(int) onQuantityChanged;
  final VoidCallback? onEdit;

  // New props for selection and tapping
  final bool isSelected;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onCardTap;

  const _ProductCard({
    required this.product,
    required this.onIncrease,
    required this.onDecrease,
    required this.onQuantityChanged,
    this.onEdit,
    this.isSelected = false,
    this.onSelectToggle,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final stock = ((product['quantity'] ?? 0) as num).toInt();
    final lowStock = stock < 10;
    final name = product['name'] ?? 'Unknown Product';
    final category = product['category'] ?? 'General';
    final sku = product['sku'] ?? '';
    final barcode = product['barcode'] ?? '';
    final emoji = product['emoji'] ?? '📦';
    final price = ((product['price'] ?? 0) as num).toDouble();
    final cost = ((product['cost'] ?? 0) as num).toDouble();

    final theme = Theme.of(context);

    return Card(
      color: theme.cardColor,
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: lowStock
            ? BorderSide(color: AppColors.error.withOpacity(0.5), width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onCardTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onSelectToggle?.call(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(emoji.toString(),
                        style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.toString(),
                          style: AppTextStyles.subtitle1
                              .copyWith(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _buildTag(category.toString(), Colors.blue),
                            if (sku.toString().isNotEmpty)
                              _buildTag(sku.toString(), Colors.grey),
                            if (barcode.toString().isNotEmpty)
                              _buildTag(
                                  'BC: ${barcode.toString()}', Colors.purple),
                            if (lowStock)
                              _buildTag('Low Stock', AppColors.error),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit' && onEdit != null) onEdit!();
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Details')
                        ]),
                      ),
                    ],
                    icon: Icon(Icons.more_vert, color: theme.iconTheme.color),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Metrics Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetric('Price', '₦${price.toStringAsFixed(2)}'),
                  _buildMetric('Cost', '₦${cost.toStringAsFixed(2)}'),
                  _buildMetric(
                      'Value', '₦${(price * stock).toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 16),

              // Stock Control Row
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('Current Stock:', style: AppTextStyles.caption),
                    const Spacer(),
                    _buildIconButton(Icons.remove, AppColors.error,
                        stock > 0 ? onDecrease : null),
                    Container(
                      constraints: const BoxConstraints(minWidth: 40),
                      alignment: Alignment.center,
                      child: Text('$stock',
                          style: AppTextStyles.subtitle1
                              .copyWith(fontWeight: FontWeight.bold)),
                    ),
                    _buildIconButton(Icons.add, AppColors.success, onIncrease),
                    const SizedBox(width: 8),
                    // Quick add +10
                    InkWell(
                      onTap: () => onQuantityChanged(stock + 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('+10',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(value,
            style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, Color color, VoidCallback? onPressed) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18),
        color: color,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
