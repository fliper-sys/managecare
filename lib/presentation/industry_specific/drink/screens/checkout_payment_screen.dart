import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../services/receipt_manager.dart';
import 'package:provider/provider.dart';
import '../../../../providers/drink_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../widgets/custom_button.dart';

class CheckoutPaymentScreen extends StatefulWidget {
  final Map<String, int> cart;
  final DrinkProvider provider;

  const CheckoutPaymentScreen({
    super.key,
    required this.cart,
    required this.provider,
  });

  @override
  State<CheckoutPaymentScreen> createState() => _CheckoutPaymentScreenState();
}

class _CheckoutPaymentScreenState extends State<CheckoutPaymentScreen> {
  String _selectedPaymentMethod = 'cash';
  double _discount = 0;
  bool _isProcessing = false;

  double get _subtotal => widget.cart.entries.fold<double>(0.0, (sum, e) {
        final d = widget.provider.getDrinkById(e.key);
        if (d == null) return sum;
        return sum + (d.pricePerBottle * e.value);
      });

  double get _tax => _subtotal * 0.0; // 0% tax for now
  double get _total => _subtotal - _discount + _tax;

  int get _itemCount => widget.cart.values.fold(0, (a, b) => a + b);

  Future<void> _processPayment(BuildContext context) async {
    setState(() => _isProcessing = true);

    try {
      // Build order
      final lines = widget.cart.entries.map((e) {
        final d = widget.provider.getDrinkById(e.key)!;
        return OrderLine(
          drinkId: d.id,
          quantityBottles: e.value,
          unitPrice: d.pricePerBottle,
        );
      }).toList();

      final order = Order(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        lines: lines,
      );

      // Save order to Firestore
      widget.provider.createOrder(order);

      // Build sale map for receipt
      final saleMap = {
        'id': order.id,
        'items': order.lines.map((l) {
          final d = widget.provider.getDrinkById(l.drinkId)!;
          return {
            'name': d.name,
            'quantity': l.quantityBottles,
            'price': d.pricePerBottle
          };
        }).toList(),
        'subtotal': _subtotal,
        'discount': _discount,
        'tax': _tax,
        'total': _total,
        'paymentMethod': _getPaymentMethodName(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Persist sale to Firestore so payment and final amount are recorded
      try {
        final businessProvider =
            Provider.of<BusinessProvider>(context, listen: false);
        final authProvider =
            Provider.of<AuthProvider>(context, listen: false);
        final businessId = businessProvider.currentBusiness?.id ??
            authProvider.currentUser?.businessId;

        if (businessId != null && businessId.isNotEmpty) {
          final firestore = FirebaseFirestore.instance;
          final docRef = await firestore
              .collection('businesses')
              .doc(businessId)
              .collection('sales')
              .add({
            'items': saleMap['items'],
            'subtotal': _subtotal,
            'discount': _discount,
            'tax': _tax,
            'total': _total,
            'totalAmount': _total,
            'finalAmount': _total,
            'paymentMethod': _getPaymentMethodName(),
            'category': 'Drinks/Bar',
            'createdAt': FieldValue.serverTimestamp(),
            if (authProvider.currentUser?.id != null)
              'workerId': authProvider.currentUser!.id,
            if (authProvider.currentUser?.fullName != null)
              'workerName': authProvider.currentUser!.fullName,
          });
          // Attach generated id
          await docRef.update({'orderId': docRef.id});
          // Reflect id in saleMap
          saleMap['id'] = docRef.id;
          saleMap['finalAmount'] = _total;
          saleMap['paymentMethod'] = _getPaymentMethodName();
        }

        // Show receipt manager (handles print/share/email)
        if (!mounted) return;
        await ReceiptManager.handlePostSale(context, saleMap);
      } catch (e) {
        debugPrint('[CheckoutPayment] Error saving sale: $e');
        // Still show receipt manager even if save fails
        if (!mounted) return;
        await ReceiptManager.handlePostSale(context, saleMap);
      }

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Payment successful! Order processed.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Close dialog and go back
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String _getPaymentMethodName() {
    switch (_selectedPaymentMethod) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Debit/Credit Card';
      case 'wallet':
        return 'Digital Wallet';
      default:
        return 'Cash';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Checkout & Payment'),
        backgroundColor: Colors.brown.shade700,
        elevation: 2,
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.brown.shade700,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Processing Payment...',
                    style: AppTextStyles.subtitle1.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Summary Header
                    _buildOrderHeader(),
                    const SizedBox(height: 24),

                    // Order Items
                    _buildOrderItems(),
                    const SizedBox(height: 24),

                    // Discount Section
                    _buildDiscountSection(),
                    const SizedBox(height: 24),

                    // Order Total
                    _buildOrderTotal(),
                    const SizedBox(height: 24),

                    // Payment Method Selection
                    _buildPaymentMethodSection(),
                    const SizedBox(height: 32),

                    // Action Buttons
                    CustomButton(
                      text: 'Complete Payment - ₦${_total.toStringAsFixed(2)}',
                      backgroundColor: Colors.green.shade600,
                      onPressed:
                          _isProcessing ? null : () => _processPayment(context),
                    ),
                    const SizedBox(height: 8),
                    CustomButton(
                      text: 'Cancel',
                      backgroundColor: AppColors.border,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOrderHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.brown.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order #${DateTime.now().millisecondsSinceEpoch}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateTime.now().toString().split('.')[0],
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Chip(
            label: Text('$_itemCount items'),
            backgroundColor: Colors.brown.shade100,
            labelStyle: AppTextStyles.caption.copyWith(
              color: Colors.brown.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Items',
          style: AppTextStyles.heading5.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: widget.cart.entries.map((e) {
              final d = widget.provider.getDrinkById(e.key)!;
              final lineTotal = d.pricePerBottle * e.value;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: widget.cart.entries.last.key == e.key
                          ? Colors.transparent
                          : AppColors.border,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Drink Image
                    if (d.imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: d.imageUrl!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 50,
                        height: 50,
                        alignment: Alignment.center,
                        child:
                            Text(d.emoji, style: const TextStyle(fontSize: 28)),
                      ),
                    const SizedBox(width: 12),

                    // Drink Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.name,
                            style: AppTextStyles.body2.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'x${e.value} @ ₦${d.pricePerBottle.toStringAsFixed(2)}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Line Total
                    Text(
                      '₦${lineTotal.toStringAsFixed(2)}',
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.brown.shade700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDiscountSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Apply Discount',
            style: AppTextStyles.subtitle2.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Discount amount (₦)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _discount = double.tryParse(value) ?? 0;
                      if (_discount > _subtotal) {
                        _discount = _subtotal;
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '-₦${_discount.toStringAsFixed(2)}',
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTotal() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.brown.shade200, width: 2),
      ),
      child: Column(
        children: [
          _TotalRow(
              label: 'Subtotal', value: '₦${_subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          if (_discount > 0)
            _TotalRow(
              label: 'Discount',
              value: '-₦${_discount.toStringAsFixed(2)}',
              isDiscount: true,
            ),
          if (_discount > 0) const SizedBox(height: 8),
          if (_tax > 0)
            _TotalRow(label: 'Tax (0%)', value: '₦${_tax.toStringAsFixed(2)}'),
          if (_tax > 0) const SizedBox(height: 8),
          const Divider(height: 16),
          _TotalRow(
            label: 'Total Amount',
            value: '₦${_total.toStringAsFixed(2)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Method',
          style: AppTextStyles.heading5.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _PaymentMethodOption(
          title: 'Cash',
          icon: Icons.money,
          value: 'cash',
          isSelected: _selectedPaymentMethod == 'cash',
          onChanged: (value) {
            setState(() => _selectedPaymentMethod = value);
          },
        ),
        const SizedBox(height: 8),
        _PaymentMethodOption(
          title: 'Debit/Credit Card',
          icon: Icons.credit_card,
          value: 'card',
          isSelected: _selectedPaymentMethod == 'card',
          onChanged: (value) {
            setState(() => _selectedPaymentMethod = value);
          },
        ),
        const SizedBox(height: 8),
        _PaymentMethodOption(
          title: 'Digital Wallet',
          icon: Icons.account_balance_wallet,
          value: 'wallet',
          isSelected: _selectedPaymentMethod == 'wallet',
          onChanged: (value) {
            setState(() => _selectedPaymentMethod = value);
          },
        ),
      ],
    );
  }
}

class _PaymentMethodOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final String value;
  final bool isSelected;
  final Function(String) onChanged;

  const _PaymentMethodOption({
    required this.title,
    required this.icon,
    required this.value,
    required this.isSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade400 : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.blue.shade100 : AppColors.border,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: isSelected ? Colors.blue : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.body2.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color:
                      isSelected ? Colors.blue.shade900 : AppColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Colors.blue.shade600,
              ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;
  final bool isDiscount;

  const _TotalRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.isDiscount = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold)
              : AppTextStyles.body2,
        ),
        Text(
          value,
          style: isTotal
              ? AppTextStyles.heading4.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.brown.shade700,
                )
              : isDiscount
                  ? AppTextStyles.body2.copyWith(color: Colors.green)
                  : AppTextStyles.body2,
        ),
      ],
    );
  }
}

