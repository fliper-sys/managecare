import 'package:flutter/material.dart';
import '../../../../core/utils/currency.dart';

class TabCard extends StatelessWidget {
  final String customerName;
  final double totalAmount;
  final int itemCount;
  final VoidCallback onTap;

  const TabCard({
    super.key,
    required this.customerName,
    required this.totalAmount,
    required this.itemCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(customerName),
        subtitle: Text('$itemCount items'),
        trailing: Text(formatCurrency(totalAmount)),
        onTap: onTap,
      ),
    );
  }
}

