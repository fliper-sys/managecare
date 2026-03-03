import 'package:flutter/material.dart';

class PaymentDialog extends StatelessWidget {
  final String totalAmount;
  final VoidCallback onConfirm;

  const PaymentDialog({
    super.key,
    required this.totalAmount,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Total Amount:'),
          const SizedBox(height: 12),
          Text(
            totalAmount,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

