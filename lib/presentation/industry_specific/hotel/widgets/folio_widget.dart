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
            ...charges.map((charge) {
              final items = (charge['items'] as List?) ?? const [];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child:
                                Text(charge['description']?.toString() ?? '')),
                        Text(
                            '₦${_amount(charge['amount']).toStringAsFixed(2)}'),
                      ],
                    ),
                    for (final rawItem in items)
                      if (rawItem is Map)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${rawItem['quantity'] ?? 1} x ${rawItem['name'] ?? rawItem['productName'] ?? 'Item'}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              Text(
                                '₦${_amount(rawItem['total']).toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              );
            }),
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
