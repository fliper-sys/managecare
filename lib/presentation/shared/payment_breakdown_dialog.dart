import 'package:flutter/material.dart';
import '../../core/utils/currency.dart';
import '../../data/models/payment_breakdown.dart';
import 'payment_breakdown_fields.dart';

Future<PaymentBreakdown?> showPaymentBreakdownDialog(
  BuildContext context, {
  required String title,
  required double amountDue,
  bool allowPartial = false,
}) async {
  final cashController = TextEditingController(
    text: allowPartial || amountDue <= 0 ? '' : amountDue.toStringAsFixed(2),
  );
  final cardController = TextEditingController();
  final transferController = TextEditingController();
  PaymentBreakdown current = const PaymentBreakdown();

  try {
    return await showDialog<PaymentBreakdown>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Balance: ${formatCurrency(amountDue)}'),
                const SizedBox(height: 14),
                PaymentBreakdownFields(
                  cashController: cashController,
                  cardController: cardController,
                  transferController: transferController,
                  onChanged: (value) => setDialogState(() => current = value),
                ),
                if (allowPartial) ...[
                  const SizedBox(height: 8),
                  const Text('Enter any amount up to the balance due.'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                current = PaymentBreakdown(
                  cash: double.tryParse(cashController.text.trim()) ?? 0,
                  card: double.tryParse(cardController.text.trim()) ?? 0,
                  transfer:
                      double.tryParse(transferController.text.trim()) ?? 0,
                );
                final validTotal = current.isValid &&
                    (allowPartial
                        ? current.total > 0 &&
                            current.total <= amountDue + 0.01
                        : (current.total - amountDue).abs() <= 0.01);
                if (!validTotal) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        allowPartial
                            ? 'Payment must be greater than zero and no more than the balance.'
                            : 'Payment total must equal ${formatCurrency(amountDue)}.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, current);
              },
              child: const Text('Confirm payment'),
            ),
          ],
        ),
      ),
    );
  } finally {
    cashController.dispose();
    cardController.dispose();
    transferController.dispose();
  }
}
