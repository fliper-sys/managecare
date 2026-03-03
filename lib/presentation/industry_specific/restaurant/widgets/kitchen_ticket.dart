import 'package:flutter/material.dart';

class KitchenTicket extends StatelessWidget {
  final String orderId;
  final List<Map<String, dynamic>> items;
  final VoidCallback onComplete;

  const KitchenTicket(
      {super.key,
      required this.orderId,
      required this.items,
      required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order: $orderId',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...items
                .map((item) => Text('${item['name']} x${item['quantity']}')),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: onComplete, child: const Text('Mark Complete'))
          ],
        ),
      ),
    );
  }
}

