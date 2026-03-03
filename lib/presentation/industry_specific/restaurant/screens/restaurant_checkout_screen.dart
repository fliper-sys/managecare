import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../widgets/async_button.dart';
import '../../../../widgets/custom_button.dart';
import '../../../../services/receipt_manager.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../services/email_service.dart';
import '../providers/restaurant_provider.dart';

class RestaurantCheckoutScreen extends StatefulWidget {
  const RestaurantCheckoutScreen({super.key});

  @override
  State<RestaurantCheckoutScreen> createState() =>
      _RestaurantCheckoutScreenState();
}

class _RestaurantCheckoutScreenState extends State<RestaurantCheckoutScreen> {
  String? _selectedOrderId;
  String _searchQuery = '';
  DateTime? _selectedDate;
  String _paymentMethod = 'cash';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
      if (business != null) {
        context.read<RestaurantProvider>().setBusinessId(business.id);
        context.read<RestaurantProvider>().initializeOrders(businessId: business.id);
      } else {
        context.read<RestaurantProvider>().initializeOrders();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Orders - Checkout'),
        elevation: 0,
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                // Search Field
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search order ID or table number...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Date Filter
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate ?? DateTime.now(),
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 30)),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 18, color: AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Text(
                                _selectedDate == null
                                    ? 'Select Date'
                                    : DateFormat('MMM dd, yyyy')
                                        .format(_selectedDate!),
                                style: AppTextStyles.body2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_selectedDate != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () => setState(() => _selectedDate = null),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Orders List
          Expanded(
            child: Consumer<RestaurantProvider>(
              builder: (context, provider, _) {
                var filteredOrders =
                    provider.orders.where((o) => o.status == 'ready').toList();

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  filteredOrders = filteredOrders
                      .where((o) =>
                          o.id.contains(_searchQuery) ||
                          o.tableNumber.toString().contains(_searchQuery))
                      .toList();
                }

                // Apply date filter
                if (_selectedDate != null) {
                  final startOfDay = DateTime(
                    _selectedDate!.year,
                    _selectedDate!.month,
                    _selectedDate!.day,
                  );
                  final endOfDay = startOfDay.add(const Duration(days: 1));
                  filteredOrders = filteredOrders
                      .where((o) =>
                          o.createdAt.isAfter(startOfDay) &&
                          o.createdAt.isBefore(endOfDay))
                      .toList();
                }

                return filteredOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: AppColors.border,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No ready orders found',
                              style: AppTextStyles.body1.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filteredOrders.length,
                        itemBuilder: (context, index) {
                          final order = filteredOrders[index];
                          final isSelected = _selectedOrderId == order.id;
                          return _OrderCheckoutCard(
                            order: order,
                            isSelected: isSelected,
                            onTap: () =>
                                setState(() => _selectedOrderId = order.id),
                            onCheckout: () =>
                                _showCheckoutDialog(context, order),
                          );
                        },
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCheckoutDialog(BuildContext context, RestaurantOrder order) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order #${order.id.length >= 6 ? order.id.substring(order.id.length - 6) : order.id}',
                            style: AppTextStyles.heading3,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'READY',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.table_restaurant,
                                  color: Colors.brown.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Table ${order.tableNumber ?? 'N/A'}',
                                style: AppTextStyles.body2.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.people, color: Colors.brown.shade700),
                              const SizedBox(width: 8),
                              Text(
                                '${order.items.fold(0, (sum, item) => sum + item.quantity)} items',
                                style: AppTextStyles.body2.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Order Summary
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Order Items', style: AppTextStyles.heading5),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...order.items.asMap().entries.map((e) {
                              final item = e.value;
                              final isLast = e.key == order.items.length - 1;
                              return Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.menuItemName,
                                              style:
                                                  AppTextStyles.body2.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (item.specialInstructions !=
                                                null)
                                              Text(
                                                'Note: ${item.specialInstructions}',
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                  color: Colors.orange,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${item.quantity}x ₦${item.price.toStringAsFixed(2)}',
                                        style: AppTextStyles.body2.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!isLast)
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 8),
                                      child: Divider(height: 1),
                                    ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Totals
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            _SummaryRow(
                              label: 'Subtotal',
                              value: '₦${order.subtotal.toStringAsFixed(2)}',
                            ),
                            const Divider(),
                            _SummaryRow(
                              label: 'Tax',
                              value: '₦${order.tax.toStringAsFixed(2)}',
                            ),
                            const Divider(),
                            _SummaryRow(
                              label: 'Discount',
                              value: '-₦${order.discount.toStringAsFixed(2)}',
                            ),
                            const Divider(height: 2),
                            const SizedBox(height: 8),
                            _SummaryRow(
                              label: 'Total',
                              value: '₦${order.total.toStringAsFixed(2)}',
                              isTotal: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Payment Method Selection
                      const Text('Payment Method', style: AppTextStyles.body1),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _paymentMethod,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: ['cash', 'card', 'transfer', 'cheque']
                              .map((method) => DropdownMenuItem(
                                    value: method,
                                    child: Text(method.toUpperCase()),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _paymentMethod = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CustomButton(
                        text: 'Print Receipt',
                        backgroundColor: Colors.blue,
                        onPressed: () {
                          _printReceipt(context, order);
                        },
                      ),
                      const SizedBox(height: 8),
                      CustomButton(
                        text: 'Send Receipt via Email (PDF)',
                        backgroundColor: Colors.green,
                        onPressed: () {
                          _sendReceiptEmail(context, order);
                        },
                      ),
                      const SizedBox(height: 8),
                      CustomButton(
                        text: 'Close',
                        backgroundColor: AppColors.border,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _printReceipt(
      BuildContext context, RestaurantOrder order) async {
    try {
      // Show receipt manager dialog
      Navigator.pop(context); // Close current dialog
      if (!mounted) return;

      final saleMap = {
        'id': order.id,
        'items': order.items
            .map((item) => {
                  'productName': item.menuItemName,
                  'quantity': item.quantity,
                  'unitPrice': item.price,
                  'total': item.subtotal,
                })
            .toList(),
        'subtotal': order.subtotal,
        'tax': order.tax,
        'discount': order.discount,
        'total': order.total,
        'paymentMethod': _paymentMethod,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await ReceiptManager.handlePostSale(context, saleMap);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt sent to printer'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('[RestaurantCheckout] Print error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _sendReceiptEmail(
      BuildContext context, RestaurantOrder order) async {
    try {
      // Get business ID from BusinessProvider, fall back to auth
      final businessProvider =
          Provider.of<BusinessProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final businessId = businessProvider.currentBusiness?.id ??
          authProvider.currentUser?.businessId;

      if (businessId == null || businessId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business ID not found')),
        );
        return;
      }

      // Build receipt content
      final receiptContent = _buildReceiptContent(order);

      // Send via email service
      final emailService = EmailService();
      await emailService.sendReceiptEmail(
        recipient: order.customerEmail ?? 'customer@example.com', // Get from order if available
        businessName: Provider.of<BusinessProvider>(context, listen: false).currentBusiness?.name ?? 'Restaurant',
        receiptText: receiptContent,
        orderId: order.id,
        items: order.items.map((e) => {
          'name': e.menuItemName,
          'quantity': e.quantity,
          'price': e.price,
        }).toList(),
        subtotal: order.subtotal,
        tax: order.tax,
        total: order.total,
        paymentMethod: _paymentMethod,
        paymentBreakdown: order.paymentBreakdown.isNotEmpty ? order.paymentBreakdown : null,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt sent via email successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('[RestaurantCheckout] Email error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending email: $e')),
      );
    }
  }

  String _buildReceiptContent(RestaurantOrder order) {
    final buffer = StringBuffer();
    buffer.writeln('=== RESTAURANT RECEIPT ===\n');
    buffer.writeln('Order #${order.id.length >= 6 ? order.id.substring(order.id.length - 6) : order.id}');
    buffer.writeln('Table ${order.tableNumber ?? 'N/A'}');
    buffer.writeln(
        'Date: ${DateFormat('MMM dd, yyyy HH:mm').format(order.createdAt)}\n');
    buffer.writeln('--- ITEMS ---');

    for (final item in order.items) {
      buffer.writeln('${item.quantity}x ${item.menuItemName}');
      buffer.writeln(
          '  ₦${item.price} x ${item.quantity} = ₦${item.subtotal.toStringAsFixed(2)}');
    }

    buffer.writeln('\n--- TOTALS ---');
    buffer.writeln('Subtotal: ₦${order.subtotal.toStringAsFixed(2)}');
    buffer.writeln('Tax: ₦${order.tax.toStringAsFixed(2)}');
    if (order.discount > 0) {
      buffer.writeln('Discount: -₦${order.discount.toStringAsFixed(2)}');
    }
    buffer.writeln('TOTAL: ₦${order.total.toStringAsFixed(2)}');
    if (order.paymentBreakdown.isNotEmpty) {
      buffer.writeln('\n--- PAYMENTS ---');
      for (final pb in order.paymentBreakdown) {
        final m = (pb['method'] ?? '').toString().toUpperCase();
        final amt = (pb['amount'] ?? 0.0);
        final tx = pb['transactionId'] ?? '';
        buffer.writeln('$m${tx != null && tx.toString().isNotEmpty ? ' • ${tx.toString()}' : ''} : ₦${(amt as num).toDouble().toStringAsFixed(2)}');
      }
    } else {
      buffer.writeln('Payment: ${_paymentMethod.toUpperCase()}');
    }
    buffer.writeln('\nThank you!');

    return buffer.toString();
  }
}

class _OrderCheckoutCard extends StatelessWidget {
  final RestaurantOrder order;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onCheckout;

  const _OrderCheckoutCard({
    required this.order,
    required this.isSelected,
    required this.onTap,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                  )
                ]
              : [],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.id.length >= 6 ? order.id.substring(order.id.length - 6) : order.id}',
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.table_restaurant,
                            size: 16, color: Colors.brown.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Table ${order.tableNumber ?? 'N/A'}',
                          style: AppTextStyles.body2,
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'READY',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('HH:mm').format(order.createdAt),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Items Preview
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${order.items.length} items • ${order.items.fold(0, (sum, item) => sum + item.quantity)} servings',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...order.items.take(2).map((item) => Text(
                        '• ${item.quantity}x ${item.menuItemName}',
                        style: AppTextStyles.body2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )),
                  if (order.items.length > 2)
                    Text(
                      '+ ${order.items.length - 2} more',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Total & Checkout Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Amount',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '₦${order.total.toStringAsFixed(2)}',
                      style: AppTextStyles.heading4.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                AsyncCustomButton(
                  text: 'Checkout',
                  backgroundColor: AppColors.primary,
                  onPressed: () async => onCheckout(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? AppTextStyles.body1.copyWith(fontWeight: FontWeight.bold)
              : AppTextStyles.body2,
        ),
        Text(
          value,
          style: isTotal
              ? AppTextStyles.heading5.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                )
              : AppTextStyles.body2,
        ),
      ],
    );
  }
}

