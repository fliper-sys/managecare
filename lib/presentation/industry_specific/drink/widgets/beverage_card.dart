import 'package:flutter/material.dart';
import '../../../../core/utils/currency.dart';

class BeverageCard extends StatelessWidget {
  final String name;
  final String category;
  final double price;
  final VoidCallback onTap;

  const BeverageCard({
    super.key,
    required this.name,
    required this.category,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(name),
        subtitle: Text(category),
        trailing: Text(formatCurrency(price)),
        onTap: onTap,
      ),
    );
  }
}

