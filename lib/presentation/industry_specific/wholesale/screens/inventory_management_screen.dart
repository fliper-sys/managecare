import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../widgets/custom_button.dart';
import '../providers/wholesale_provider.dart';

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  State<InventoryManagementScreen> createState() =>
      _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  String _searchQuery = '';
  String _categoryFilter = 'All';
  String _sortBy = 'name'; // name, quantity, price

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WholesaleProvider>().loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 222, 227, 231),
      appBar: AppBar(
        title: const Text('Inventory Management'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddProductDialog(context),
          ),
        ],
      ),
      body: Consumer<WholesaleProvider>(
        builder: (context, provider, _) {
          var products = provider.products;

          // Apply filters
          if (_searchQuery.isNotEmpty) {
            products = products
                .where((p) =>
                    p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    p.sku.toLowerCase().contains(_searchQuery.toLowerCase()))
                .toList();
          }

          if (_categoryFilter != 'All') {
            products =
                products.where((p) => p.category == _categoryFilter).toList();
          }

          // Apply sorting
          switch (_sortBy) {
            case 'quantity':
              products.sort((a, b) => b.quantity.compareTo(a.quantity));
              break;
            case 'price':
              products.sort((a, b) => b.costPrice.compareTo(a.costPrice));
              break;
            default:
              products.sort((a, b) => a.name.compareTo(b.name));
          }

          final categories = {
            'All',
            ...provider.products.map((p) => p.category)
          };

          return Column(
            children: [
              // Search & Filter Bar
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Column(
                  children: [
                    // Search
                    TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search by name or SKU...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () =>
                                    setState(() => _searchQuery = ''),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Category & Sort Row
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton<String>(
                            value: _categoryFilter,
                            isExpanded: true,
                            items: categories
                                .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _categoryFilter = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<String>(
                            value: _sortBy,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                  value: 'name', child: Text('By Name')),
                              DropdownMenuItem(
                                  value: 'quantity', child: Text('By Qty')),
                              DropdownMenuItem(
                                  value: 'price', child: Text('By Price')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _sortBy = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Products List
              Expanded(
                child: products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inventory_2,
                                size: 64, color: AppColors.border),
                            const SizedBox(height: 16),
                            Text(
                              'No products found',
                              style: AppTextStyles.body1.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final isLowStock =
                              product.quantity <= product.reorderLevel;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isLowStock
                                    ? Colors.orange
                                    : AppColors.border,
                                width: isLowStock ? 2 : 1,
                              ),
                            ),
                            child: ExpansionTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style: AppTextStyles.body1.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          product.sku,
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isLowStock
                                              ? Colors.orange.shade100
                                              : Colors.green.shade100,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Qty: ${product.quantity}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isLowStock
                                                ? Colors.orange.shade700
                                                : Colors.green.shade700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatCurrency(product.costPrice),
                                        style: AppTextStyles.body2.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _InfoRow(
                                        label: 'Category',
                                        value: product.category,
                                      ),
                                      _InfoRow(
                                        label: 'Cost Price',
                                        value: formatCurrency(product.costPrice),
                                      ),
                                      _InfoRow(
                                        label: 'Selling Price',
                                        value: formatCurrency(product.sellingPrice),
                                      ),
                                      _InfoRow(
                                        label: 'Wholesale Price',
                                        value: formatCurrency(product.wholesalePrice),
                                      ),
                                      _InfoRow(
                                        label: 'Warehouse Allocations',
                                        value: product.warehouseAllocations.isEmpty
                                            ? 'Not allocated'
                                            : provider.warehouses
                                                .map((w) =>
                                                    '${w.name}: ${product.warehouseAllocations[w.id] ?? 0}')
                                                .where((s) => s.isNotEmpty)
                                                .join(' - '),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: CustomButton(
                                              text: 'Allocate',
                                              backgroundColor: Colors.blue,
                                              onPressed: () => _showAllocateDialog(context, product),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: CustomButton(
                                              text: 'Edit',
                                              backgroundColor: Colors.green,
                                              onPressed: () => _showEditProductDialog(context, product),
                                            ),
                                          ),
                                        ],
                                      ),
                                      _InfoRow(
                                        label: 'Stock Level',
                                        value:
                                            '${product.quantity} / ${product.reorderLevel} (reorder at)',
                                      ),
                                      _InfoRow(
                                        label: 'Supplier',
                                        value: product.supplier,
                                      ),
                                      _InfoRow(
                                        label: 'Total Value',
                                        value:
                                            '₦${(product.costPrice * product.quantity).toStringAsFixed(2)}',
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: CustomButton(
                                              text: 'Edit',
                                              backgroundColor: Colors.blue,
                                              onPressed: () =>
                                                  _showEditProductDialog(
                                                      context, product),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: CustomButton(
                                              text: 'Delete',
                                              backgroundColor: Colors.red,
                                              onPressed: () => _confirmDelete(
                                                  context, product),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddProductDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ProductFormDialog(
        onSave: (product) {
          context.read<WholesaleProvider>().addProduct(product);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product added successfully')),
          );
        },
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, WholesaleProduct product) {
    showDialog(
      context: context,
      builder: (context) => _ProductFormDialog(
        initialProduct: product,
        onSave: (updatedProduct) {
          context.read<WholesaleProvider>().updateProduct(updatedProduct);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product updated successfully')),
          );
        },
      ),
    );
  }

  void _showAllocateDialog(BuildContext context, WholesaleProduct product) {
    final provider = context.read<WholesaleProvider>();
    String? selectedWarehouseId = provider.warehouses.isNotEmpty ? provider.warehouses.first.id : null;
    final qtyCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Allocate to Warehouse'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (provider.warehouses.isEmpty) const Text('No warehouses configured'),
            if (provider.warehouses.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                value: selectedWarehouseId,
                items: provider.warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                onChanged: (v) => selectedWarehouseId = v,
                decoration: const InputDecoration(labelText: 'Warehouse'),
              ),
              const SizedBox(height: 8),
              TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity to allocate')),
            ]
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (selectedWarehouseId == null) return;
              final q = int.tryParse(qtyCtrl.text) ?? 0;
              final allocs = Map<String, int>.from(product.warehouseAllocations);
              allocs[selectedWarehouseId!] = (allocs[selectedWarehouseId!] ?? 0) + q;

              final updated = product.copyWith(warehouseAllocations: allocs);
              try {
                await provider.updateProduct(updated);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Allocation saved'), backgroundColor: AppColors.success));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save allocation: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WholesaleProduct product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to delete ${product.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<WholesaleProvider>().deleteProduct(product.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Product deleted successfully')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body2),
          Text(
            value,
            style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  final WholesaleProduct? initialProduct;
  final Function(WholesaleProduct) onSave;

  const _ProductFormDialog({
    this.initialProduct,
    required this.onSave,
  });

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _skuCtrl;
  late TextEditingController _categoryCtrl;
  late TextEditingController _costPriceCtrl;
  late TextEditingController _sellingPriceCtrl;
  late TextEditingController _wholesalePriceCtrl;
  late TextEditingController _quantityCtrl;
  late TextEditingController _reorderLevelCtrl;
  late TextEditingController _supplierCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialProduct?.name ?? '');
    _skuCtrl = TextEditingController(text: widget.initialProduct?.sku ?? '');
    _categoryCtrl =
        TextEditingController(text: widget.initialProduct?.category ?? '');
    _costPriceCtrl = TextEditingController(
      text: widget.initialProduct?.costPrice.toString() ?? '',
    );
    _sellingPriceCtrl = TextEditingController(
      text: widget.initialProduct?.sellingPrice.toString() ?? '',
    );
    _wholesalePriceCtrl = TextEditingController(
      text: widget.initialProduct?.wholesalePrice.toString() ?? '',
    );
    _quantityCtrl = TextEditingController(
      text: widget.initialProduct?.quantity.toString() ?? '',
    );
    _reorderLevelCtrl = TextEditingController(
      text: widget.initialProduct?.reorderLevel.toString() ?? '10',
    );
    _supplierCtrl =
        TextEditingController(text: widget.initialProduct?.supplier ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _categoryCtrl.dispose();
    _costPriceCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _wholesalePriceCtrl.dispose();
    _quantityCtrl.dispose();
    _reorderLevelCtrl.dispose();
    _supplierCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.initialProduct == null ? 'Add Product' : 'Edit Product',
                style: AppTextStyles.heading3,
              ),
              const SizedBox(height: 16),
              _buildTextField('Product Name', _nameCtrl),
              _buildTextField('SKU', _skuCtrl),
              _buildTextField('Category', _categoryCtrl),
              _buildTextField('Cost Price', _costPriceCtrl, isNumber: true),
              _buildTextField('Selling Price', _sellingPriceCtrl,
                  isNumber: true),
              _buildTextField('Wholesale Price', _wholesalePriceCtrl,
                  isNumber: true),
              _buildTextField('Quantity', _quantityCtrl, isNumber: true),
              _buildTextField('Reorder Level', _reorderLevelCtrl,
                  isNumber: true),
              _buildTextField('Supplier', _supplierCtrl),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Cancel',
                      backgroundColor: AppColors.border,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomButton(
                      text: 'Save',
                      backgroundColor: AppColors.primary,
                      onPressed: () => _saveProduct(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  void _saveProduct(BuildContext context) {
    if (_nameCtrl.text.isEmpty ||
        _skuCtrl.text.isEmpty ||
        _costPriceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    final product = WholesaleProduct(
      id: widget.initialProduct?.id ??
          'prod_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text,
      sku: _skuCtrl.text,
      category: _categoryCtrl.text,
      costPrice: double.parse(_costPriceCtrl.text),
      sellingPrice: double.parse(_sellingPriceCtrl.text),
      wholesalePrice: double.parse(_wholesalePriceCtrl.text),
      quantity: int.parse(_quantityCtrl.text),
      reorderLevel: int.parse(_reorderLevelCtrl.text),
      reorderQuantity: 50,
      supplier: _supplierCtrl.text,
    );

    widget.onSave(product);
  }
}


