import 'package:flutter/material.dart';

class ExpiryWarningBadge extends StatelessWidget {
  final DateTime expiryDate;

  const ExpiryWarningBadge({super.key, required this.expiryDate});

  @override
  Widget build(BuildContext context) {
    final daysLeft = expiryDate.difference(DateTime.now()).inDays;
    final color = daysLeft <= 30
        ? Colors.red
        : (daysLeft <= 90 ? Colors.orange : Colors.green);
    return Chip(
      label: Text(daysLeft <= 0 ? 'Expired' : '$daysLeft days'),
      backgroundColor: color.withOpacity(0.15),
      labelStyle: TextStyle(color: color),
    );
  }
}

