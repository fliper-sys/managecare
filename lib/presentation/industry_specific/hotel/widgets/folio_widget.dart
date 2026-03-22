import 'package:flutter/material.dart';

class FolioWidget extends StatelessWidget {
  final String guestName;
  final List<Map<String, dynamic>> charges;
  final double total;

  const FolioWidget(
      {super.key,
      required this.guestName,
      required this.charges,
      required this.total});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Guest: $guestName',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...charges.map((charge) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(charge['description'] ?? ''),
                      Text('₦${_amount(charge['amount']).toStringAsFixed(2)}'),
                    ])),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Total:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('₦${total.toStringAsFixed(2)}'),
            ]),
          ],
        ),
      ),
    );
  }

  double _amount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}

