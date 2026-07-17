import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/datetime_utils.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/retail_provider.dart';

class ReturnRefundScreen extends StatefulWidget {
  final Map<String, dynamic>? sale;

  const ReturnRefundScreen({super.key, this.sale});

  @override
  State<ReturnRefundScreen> createState() => _ReturnRefundScreenState();
}

class _ReturnRefundScreenState extends State<ReturnRefundScreen> {
  late Map<String, dynamic> _sale;
  late List<ReturnItem> _returnItems;
  late TextEditingController _reasonController;
  String _refundMethod = 'original'; // 'original', 'credit', 'cash'
  bool _isProcessing = false;
  double _totalRefundAmount = 0;
  bool _excludeFromTotals = true;

  final List<String> _returnReasons = [
    'Defective',
    'Wrong Item',
    'Not as Described',
    'Changed Mind',
    'Damaged in Transit',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _sale = widget.sale ?? {};
    _reasonController = TextEditingController();
    _initializeReturnItems();
  }

  void _initializeReturnItems() {
    final items = _sale['items'] as List? ?? [];
    _returnItems = items
        .map((item) => ReturnItem(
              productId: item['productId'] ?? '',
              productName: item['name'] ?? 'Unknown',
              quantity: item['quantity'] ?? 0,
              price: ((item['price'] ?? 0) as num).toDouble(),
              selectedQuantity: 0,
            ))
        .toList();
  }

  void _updateTotalRefund() {
    _totalRefundAmount = _returnItems.fold<double>(
      0,
      (sum, item) => sum + (item.price * item.selectedQuantity),
    );
  }

  Future<void> _processReturn() async {
    if (_totalRefundAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select items to return')),
      );
      return;
    }

    if (_reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a return reason')),
      );
      return;
    }

    // Confirm with user before processing return
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm return'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You are about to refund: ${_formatCurrency(_totalRefundAmount)}'),
              const SizedBox(height: 8),
              const Text('Items:'),
              const SizedBox(height: 8),
              ..._returnItems.where((i) => i.selectedQuantity > 0).map((i) =>
                  Text('- ${i.productName} x${i.selectedQuantity}')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Confirm')),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final businessId = context.read<BusinessProvider>().currentBusiness?.id ??
          authProvider.currentUser?.businessId;
      final retailProvider = context.read<RetailProvider>();

      if (businessId == null || businessId.isEmpty) {
        throw Exception('No business ID found');
      }

      // Process return
      final returnData = {
        'saleId': _sale['id'] ?? '',
        'businessId': businessId,
        'reason': _reasonController.text,
        'refundMethod': _refundMethod,
        'refundAmount': _totalRefundAmount,
        'excludeFromTotals': _excludeFromTotals,
        'itemsReturned': _returnItems
            .where((item) => item.selectedQuantity > 0)
            .map((item) => {
                  'productId': item.productId,
                  'quantity': item.selectedQuantity,
                  'amount': item.price * item.selectedQuantity,
                })
            .toList(),
        'processedAt': DateTime.now(),
        'processedBy': authProvider.currentUser?.fullName ?? 'Unknown',
      };

      // Save return to Firestore
      await retailProvider.processReturn(returnData);

      // Restore inventory
      for (final item in _returnItems.where((i) => i.selectedQuantity > 0)) {
        await retailProvider.addInventory(
          item.productId,
          item.selectedQuantity,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Return processed: ${_formatCurrency(_totalRefundAmount)}'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, returnData);
      }
    } catch (e) {
      print('[Return] Error processing return: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String _formatCurrency(double amount) {
    return '₦${NumberFormat('#,##0.00').format(amount)}';
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Process Return'),
        elevation: 0,
        backgroundColor: isDark ? Colors.grey[900] : AppColors.background,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Original Sale Info
              if (_sale.isNotEmpty)
                _buildSaleInfo(isDark).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 24),

              // Return Items Section
              Text(
                'Select Items to Return',
                style: AppTextStyles.headingSmall.copyWith(
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              _buildReturnItems(isDark)
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 100.ms),
              const SizedBox(height: 24),

              // Return Reason
              Text(
                'Return Reason',
                style: AppTextStyles.headingSmall.copyWith(
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  hintText: 'Select reason',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                ),
                items: _returnReasons
                    .map((reason) => DropdownMenuItem(
                          value: reason,
                          child: Text(reason),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    _reasonController.text = value;
                    setState(() {});
                  }
                },
              ),
              if (_reasonController.text == 'Other') ...[
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Explain reason',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  ),
                  maxLines: 3,
                  onChanged: (value) {
                    _reasonController.text = 'Other: $value';
                  },
                ),
              ],
              const SizedBox(height: 24),

              // Refund Method
              Text(
                'Refund Method',
                style: AppTextStyles.headingSmall.copyWith(
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              _buildRefundMethodOptions(isDark),
              const SizedBox(height: 24),

              // Total Refund
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Refund Amount',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatCurrency(_totalRefundAmount),
                          style: AppTextStyles.headingSmall.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Items',
                            style: AppTextStyles.bodySmall.copyWith(
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _returnItems
                                .fold<int>(
                                  0,
                                  (sum, item) => sum + item.selectedQuantity,
                                )
                                .toString(),
                            style: AppTextStyles.headingSmall.copyWith(
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Exclude from totals option
              SwitchListTile(
                value: _excludeFromTotals,
                onChanged: (v) => setState(() => _excludeFromTotals = v),
                title: Text('Exclude from daily sales totals',
                    style: AppTextStyles.body1),
                subtitle: Text(
                    'Do not subtract this refund from daily revenue calculations',
                    style: AppTextStyles.body2),
                activeColor: AppColors.warning,
              ),
              const SizedBox(height: 12),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _processReturn,
                      icon: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(
                          _isProcessing ? 'Processing...' : 'Process Return'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed:
                          _isProcessing ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
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

  Widget _buildSaleInfo(bool isDark) {
    final saleAmount = ((_sale['totalAmount'] ?? 0) as num).toDouble();
    final saleDate = _sale['createdAt'] is DateTime
        ? _sale['createdAt'] as DateTime
        : parseTimestamp(_sale['createdAt']);

    return Card(
      color: isDark ? Colors.grey[800] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Original Sale',
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sale #${_sale['id']?.toString().substring(0, 8) ?? 'N/A'}',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM dd, yyyy • HH:mm').format(saleDate),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatCurrency(saleAmount),
                  style: AppTextStyles.headingSmall.copyWith(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnItems(bool isDark) {
    if (_returnItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No items in this sale',
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
      );
    }

    return Column(
      children: _returnItems.map((item) {
        return Card(
          color: isDark ? Colors.grey[800] : Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Available: ${item.quantity} units',
                            style: AppTextStyles.bodySmall.copyWith(
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatCurrency(item.price),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Qty to Return:',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: item.selectedQuantity > 0
                              ? () {
                                  setState(() {
                                    item.selectedQuantity--;
                                    _updateTotalRefund();
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.remove),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        Container(
                          width: 48,
                          alignment: Alignment.center,
                          child: Text(
                            item.selectedQuantity.toString(),
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: item.selectedQuantity < item.quantity
                              ? () {
                                  setState(() {
                                    item.selectedQuantity++;
                                    _updateTotalRefund();
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.add),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ],
                ),
                if (item.selectedQuantity > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Return Amount: ${_formatCurrency(item.price * item.selectedQuantity)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRefundMethodOptions(bool isDark) {
    return Column(
      children: [
        _buildRefundOption(
          'original',
          'Original Payment Method',
          'Refund to original card/account',
          isDark,
        ),
        const SizedBox(height: 12),
        _buildRefundOption(
          'credit',
          'Store Credit',
          'Credit to customer account',
          isDark,
        ),
        const SizedBox(height: 12),
        _buildRefundOption(
          'cash',
          'Cash',
          'Immediate cash refund',
          isDark,
        ),
      ],
    );
  }

  Widget _buildRefundOption(
    String value,
    String title,
    String subtitle,
    bool isDark,
  ) {
    final isSelected = _refundMethod == value;

    return Card(
      color: isSelected
          ? AppColors.primary.withOpacity(0.1)
          : (isDark ? Colors.grey[800] : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _refundMethod = value),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Radio<String>(
                value: value,
                groupValue: _refundMethod,
                onChanged: (v) {
                  if (v != null) setState(() => _refundMethod = v);
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
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
}

class ReturnItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  int selectedQuantity;

  ReturnItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.selectedQuantity = 0,
  });
}

