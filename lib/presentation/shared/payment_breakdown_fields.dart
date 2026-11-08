import 'package:flutter/material.dart';
import '../../core/utils/currency.dart';
import '../../data/models/payment_breakdown.dart';

class PaymentBreakdownFields extends StatelessWidget {
  final TextEditingController cashController;
  final TextEditingController cardController;
  final TextEditingController transferController;
  final ValueChanged<PaymentBreakdown>? onChanged;
  final bool showTotal;

  const PaymentBreakdownFields({
    super.key,
    required this.cashController,
    required this.cardController,
    required this.transferController,
    this.onChanged,
    this.showTotal = true,
  });

  PaymentBreakdown get breakdown => PaymentBreakdown(
        cash: double.tryParse(cashController.text.trim()) ?? 0,
        card: double.tryParse(cardController.text.trim()) ?? 0,
        transfer: double.tryParse(transferController.text.trim()) ?? 0,
      );

  Widget _amountField(
    String label,
    TextEditingController controller,
    ValueChanged<PaymentBreakdown>? onChanged,
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixText: '₦ ',
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged == null ? null : (_) => onChanged(breakdown),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return null;
        final amount = double.tryParse(value.trim());
        if (amount == null || !amount.isFinite || amount < 0) {
          return 'Enter a valid non-negative amount';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _amountField('Cash', cashController, onChanged),
        const SizedBox(height: 10),
        _amountField('Card', cardController, onChanged),
        const SizedBox(height: 10),
        _amountField('Transfer', transferController, onChanged),
        if (showTotal) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Payment total',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                formatCurrency(breakdown.total),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
