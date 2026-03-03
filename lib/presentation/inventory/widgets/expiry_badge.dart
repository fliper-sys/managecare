import 'package:flutter/material.dart';

class ExpiryBadge extends StatelessWidget {
  final DateTime expiryDate;

  const ExpiryBadge({super.key, required this.expiryDate});

  @override
  Widget build(BuildContext context) {
    final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
    final isExpired = daysUntilExpiry < 0;
    final isExpiringSoon = daysUntilExpiry < 7;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isExpired
            ? Colors.red
            : isExpiringSoon
                ? Colors.orange
                : Colors.green,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isExpired
            ? 'Expired'
            : isExpiringSoon
                ? 'Expires in $daysUntilExpiry days'
                : 'Valid',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

