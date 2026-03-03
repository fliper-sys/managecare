import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../widgets/custom_button.dart';
import '../providers/wholesale_provider.dart';

class StockTransfersScreen extends StatefulWidget {
  const StockTransfersScreen({super.key});

  @override
  State<StockTransfersScreen> createState() => _StockTransfersScreenState();
}

class _StockTransfersScreenState extends State<StockTransfersScreen> {
  String _statusFilter = 'all'; // all, pending, in-transit, received, cancelled

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WholesaleProvider>().loadStockTransfers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Stock Transfers'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateTransferDialog(context),
          ),
        ],
      ),
      body: Consumer<WholesaleProvider>(
        builder: (context, provider, _) {
          var transfers = provider.stockTransfers;

          if (_statusFilter != 'all') {
            transfers =
                transfers.where((t) => t.status == _statusFilter).toList();
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
                      label: 'In Transit',
                      isActive: _statusFilter == 'in-transit',
                      onTap: () => setState(() => _statusFilter = 'in-transit'),
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Received',
                      isActive: _statusFilter == 'received',
                      onTap: () => setState(() => _statusFilter = 'received'),
                      color: Colors.green,
                    ),
                  ],
                ),
              ),

              // Transfers List
              Expanded(
                child: transfers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.local_shipping_outlined,
                                size: 64, color: AppColors.border),
                            const SizedBox(height: 16),
                            Text(
                              'No stock transfers',
                              style: AppTextStyles.body1.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: transfers.length,
                        itemBuilder: (context, index) {
                          final transfer = transfers[index];
                          return _TransferCard(
                            transfer: transfer,
                            onStatusChange: (newStatus) {
                              context
                                  .read<WholesaleProvider>()
                                  .updateStockTransferStatus(
                                      transfer.id, newStatus);
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

  void _showCreateTransferDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CreateTransferDialog(
        products: context.read<WholesaleProvider>().products,
        onCreate: (transfer) {
          context.read<WholesaleProvider>().createStockTransfer(transfer);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stock transfer created')),
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

class _TransferCard extends StatelessWidget {
  final StockTransfer transfer;
  final Function(String) onStatusChange;

  const _TransferCard({
    required this.transfer,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(transfer.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
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
                    '${transfer.fromWarehouse} → ${transfer.toWarehouse}',
                    style: AppTextStyles.body1
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${transfer.items.length} items',
                    style: AppTextStyles.body2
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    transfer.status.toUpperCase(),
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
                  value: DateFormat('MMM dd, yyyy').format(transfer.createdAt),
                ),
                const SizedBox(height: 12),
                Text(
                  'Items (${transfer.items.length})',
                  style:
                      AppTextStyles.body2.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...transfer.items.map(
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (transfer.status == 'pending')
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'Ship',
                          backgroundColor: Colors.blue,
                          onPressed: () => onStatusChange('in-transit'),
                        ),
                      ),
                    ],
                  )
                else if (transfer.status == 'in-transit')
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'Mark as Received',
                          backgroundColor: Colors.green,
                          onPressed: () {
                            _showReceiptDialog(context, transfer);
                          },
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

  void _showReceiptDialog(BuildContext context, StockTransfer transfer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Receipt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Receiving ${transfer.items.length} items from ${transfer.fromWarehouse}'),
            const SizedBox(height: 12),
            ...transfer.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${item.quantity}x ${item.productName}',
                    style: AppTextStyles.body2),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onStatusChange('received');
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Transfer received and inventory updated')),
              );
            },
            child: const Text('Confirm Receipt'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in-transit':
        return Colors.blue;
      case 'received':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
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

class _CreateTransferDialog extends StatefulWidget {
  final List<WholesaleProduct> products;
  final Function(StockTransfer) onCreate;

  const _CreateTransferDialog({
    required this.products,
    required this.onCreate,
  });

  @override
  State<_CreateTransferDialog> createState() => _CreateTransferDialogState();
}

class _CreateTransferDialogState extends State<_CreateTransferDialog> {
  String? _selectedFromWarehouseId;
  String? _selectedToWarehouseId;
  final List<OrderItem> _items = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create Stock Transfer',
                  style: AppTextStyles.heading3),
              const SizedBox(height: 16),

              // From Warehouse
              Builder(
                builder: (ctx) {
                  final wh = Provider.of<WholesaleProvider>(ctx).warehouses;
                  final value = _selectedFromWarehouseId ?? (wh.isNotEmpty ? wh.first.id : null);
                  return DropdownButtonFormField<String>(
                    value: value,
                    decoration: InputDecoration(
                      labelText: 'From Warehouse',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: wh.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                    onChanged: (value) => setState(() => _selectedFromWarehouseId = value),
                    validator: (value) => value == null ? 'Required' : null,
                  );
                },
              ),
              const SizedBox(height: 12),

              // To Warehouse
              Builder(
                builder: (ctx) {
                  final wh = Provider.of<WholesaleProvider>(ctx).warehouses;
                  final value = _selectedToWarehouseId ?? (wh.isNotEmpty ? wh.first.id : null);
                  return DropdownButtonFormField<String>(
                    value: value,
                    decoration: InputDecoration(
                      labelText: 'To Warehouse',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: wh.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                    onChanged: (value) => setState(() => _selectedToWarehouseId = value),
                    validator: (value) => value == null ? 'Required' : null,
                  );
                },
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
                                    style: AppTextStyles.body2
                                        .copyWith(fontWeight: FontWeight.bold)),
                                Text('Qty: ${item.quantity}',
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
              const SizedBox(height: 24),

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
                      onPressed: _items.isEmpty ||
                              _selectedFromWarehouseId == null ||
                              _selectedToWarehouseId == null
                          ? null
                          : () {
                              final transfer = StockTransfer(
                                id: 'st_${DateTime.now().millisecondsSinceEpoch}',
                                fromWarehouse: _selectedFromWarehouseId!,
                                toWarehouse: _selectedToWarehouseId!,
                                items: _items,
                                status: 'pending',
                              );
                              widget.onCreate(transfer);
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

  @override
  void initState() {
    super.initState();
    _quantityCtrl = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
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
              setState(() => _selectedProduct = product);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quantityCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity'),
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
                  final item = OrderItem(
                    productId: _selectedProduct!.id,
                    productName: _selectedProduct!.name,
                    quantity: int.parse(_quantityCtrl.text),
                    unitPrice: 0,
                    total: 0,
                  );
                  widget.onAdd(item);
                },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

