import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../widgets/custom_button.dart';
import '../providers/wholesale_provider.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  String _statusFilter = 'all'; // all, pending, confirmed, delivered

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WholesaleProvider>().loadPurchaseOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Purchase Orders'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateOrderDialog(context),
          ),
        ],
      ),
      body: Consumer<WholesaleProvider>(
        builder: (context, provider, _) {
          var orders = provider.purchaseOrders;

          if (_statusFilter != 'all') {
            orders = orders.where((o) => o.status == _statusFilter).toList();
          }

          return Column(
            children: [
              // Status Filter
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      isActive: _statusFilter == 'all',
                      onTap: () => setState(() => _statusFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Pending',
                      isActive: _statusFilter == 'pending',
                      onTap: () => setState(() => _statusFilter = 'pending'),
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Confirmed',
                      isActive: _statusFilter == 'confirmed',
                      onTap: () => setState(() => _statusFilter = 'confirmed'),
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Delivered',
                      isActive: _statusFilter == 'delivered',
                      onTap: () => setState(() => _statusFilter = 'delivered'),
                      color: Colors.green,
                    ),
                  ],
                ),
              ),

              // Orders List
              Expanded(
                child: orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shopping_cart_outlined,
                                size: 64, color: AppColors.border),
                            const SizedBox(height: 16),
                            Text(
                              'No purchase orders',
                              style: AppTextStyles.body1.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return _OrderCard(
                            order: order,
                            onStatusChange: (newStatus) {
                              context
                                  .read<WholesaleProvider>()
                                  .updatePurchaseOrderStatus(
                                      order.id, newStatus);
                            },
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

  void _showCreateOrderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CreateOrderDialog(
        products: context.read<WholesaleProvider>().products,
        onCreate: (order) {
          context.read<WholesaleProvider>().createPurchaseOrder(order);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase order created')),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.white,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final PurchaseOrder order;
  final Function(String) onStatusChange;

  const _OrderCard({
    required this.order,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(order.status);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outline.withOpacity(0.24)),
      ),
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PO #${order.id.substring(order.id.length - 6)}',
                    style: AppTextStyles.body1
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    order.supplier,
                    style: AppTextStyles.body2
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCurrency(order.total),
                  style:
                      AppTextStyles.body1.copyWith(fontWeight: FontWeight.bold),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    order.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                    label: 'Date',
                    value: DateFormat('MMM dd, yyyy').format(order.createdAt)),
                if (order.expectedDelivery != null)
                  _InfoRow(
                    label: 'Expected Delivery',
                    value: DateFormat('MMM dd, yyyy')
                        .format(order.expectedDelivery!),
                  ),
                const SizedBox(height: 12),
                Text('Items (${order.items.length})',
                    style: AppTextStyles.body2
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...order.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.quantity}x ${item.productName}',
                            style: AppTextStyles.body2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          formatCurrency(item.total),
                          style: AppTextStyles.body2
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal', style: AppTextStyles.body2),
                          Text(formatCurrency(order.subtotal),
                              style: AppTextStyles.body2),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tax', style: AppTextStyles.body2),
                          Text(formatCurrency(order.tax),
                              style: AppTextStyles.body2),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: AppTextStyles.body1),
                          Text(
                            formatCurrency(order.total),
                            style: AppTextStyles.body1
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (order.status == 'pending')
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'Confirm',
                          backgroundColor: Colors.blue,
                          onPressed: () => onStatusChange('confirmed'),
                        ),
                      ),
                    ],
                  )
                else if (order.status == 'confirmed')
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'Mark as Delivered',
                          backgroundColor: Colors.green,
                          onPressed: () => onStatusChange('delivered'),
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
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
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
          Text(value,
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _CreateOrderDialog extends StatefulWidget {
  final List<WholesaleProduct> products;
  final Function(PurchaseOrder) onCreate;

  const _CreateOrderDialog({
    required this.products,
    required this.onCreate,
  });

  @override
  State<_CreateOrderDialog> createState() => _CreateOrderDialogState();
}

class _CreateOrderDialogState extends State<_CreateOrderDialog> {
  late TextEditingController _supplierCtrl;
  late TextEditingController _notesCtrl;
  final List<OrderItem> _items = [];
  DateTime? _expectedDelivery;
  String? _selectedWarehouseId;

  @override
  void initState() {
    super.initState();
    _supplierCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _supplierCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double subtotal = _items.fold(0, (sum, item) => sum + item.total);
    double tax = subtotal * 0.08;
    double total = subtotal + tax;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create Purchase Order',
                  style: AppTextStyles.heading3),
              const SizedBox(height: 16),

              // Supplier
              TextField(
                controller: _supplierCtrl,
                decoration: InputDecoration(
                  labelText: 'Supplier Name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),

              // Receiving Warehouse
              Builder(builder: (ctx) {
                final provider = ctx.read<WholesaleProvider>();
                final warehouses = provider.warehouses;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Receiving Warehouse', style: AppTextStyles.body2),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedWarehouseId,
                      items: warehouses
                          .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedWarehouseId = v),
                      decoration: InputDecoration(
                        hintText: 'Select a warehouse (optional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }),

              // Expected Delivery
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) {
                    setState(() => _expectedDelivery = picked);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _expectedDelivery == null
                            ? 'Expected Delivery'
                            : DateFormat('MMM dd, yyyy')
                                .format(_expectedDelivery!),
                        style: AppTextStyles.body2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Add Items
              const Text('Items', style: AppTextStyles.body1),
              const SizedBox(height: 8),
              if (_items.isEmpty)
                Text('No items added',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary))
              else
                ...List.generate(
                  _items.length,
                  (index) {
                    final item = _items[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productName,
                                    style: AppTextStyles.body2),
                                Text('x @ '),
                                Text('${item.quantity}x @ ₦${item.unitPrice}',
                                    style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            onPressed: () =>
                                setState(() => _items.removeAt(index)),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              CustomButton(
                text: 'Add Item',
                backgroundColor: Colors.blue,
                onPressed: () => _showAddItemDialog(context),
              ),
              const SizedBox(height: 16),

              // Notes
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),

              // Totals
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal'),
                        Text('₦${subtotal.toStringAsFixed(2)}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tax (8%)'),
                        Text('₦${tax.toStringAsFixed(2)}'),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: AppTextStyles.body1),
                        Text('₦${total.toStringAsFixed(2)}',
                            style: AppTextStyles.body1
                                .copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
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
                      text: 'Create',
                      backgroundColor: AppColors.primary,
                      onPressed: _items.isEmpty || _supplierCtrl.text.isEmpty
                          ? null
                          : () {
                              final order = PurchaseOrder(
                                id: 'po_${DateTime.now().millisecondsSinceEpoch}',
                                supplier: _supplierCtrl.text,
                                items: _items,
                                subtotal: subtotal,
                                tax: tax,
                                total: total,
                                receivingWarehouseId: _selectedWarehouseId,
                                expectedDelivery: _expectedDelivery,
                                notes: _notesCtrl.text.isEmpty
                                    ? null
                                    : _notesCtrl.text,
                              );
                              widget.onCreate(order);
                            },
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

  void _showAddItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AddItemDialog(
        products: widget.products,
        onAdd: (item) {
          setState(() => _items.add(item));
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  final List<WholesaleProduct> products;
  final Function(OrderItem) onAdd;

  const _AddItemDialog({required this.products, required this.onAdd});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  WholesaleProduct? _selectedProduct;
  late TextEditingController _quantityCtrl;
  late TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _quantityCtrl = TextEditingController(text: '1');
    _priceCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<WholesaleProduct>(
            value: _selectedProduct,
            hint: const Text('Select Product'),
            isExpanded: true,
            items: widget.products
                .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                .toList(),
            onChanged: (product) {
              setState(() {
                _selectedProduct = product;
                _priceCtrl.text = product?.costPrice.toString() ?? '';
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quantityCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Unit Price'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _selectedProduct == null
              ? null
              : () {
                  final quantity = int.parse(_quantityCtrl.text);
                  final unitPrice = double.parse(_priceCtrl.text);
                  final item = OrderItem(
                    productId: _selectedProduct!.id,
                    productName: _selectedProduct!.name,
                    quantity: quantity,
                    unitPrice: unitPrice,
                    total: (quantity * unitPrice).toDouble(),
                  );
                  widget.onAdd(item);
                },
          child: const Text('Add'),
        ),
      ],
    );
  }
}



