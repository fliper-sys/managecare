import 'package:flutter/material.dart';

class TenantCard extends StatelessWidget {
  final String tenantName;
  final String property;
  final double rentDue;
  final VoidCallback onTap;

  const TenantCard({
    super.key,
    required this.tenantName,
    required this.property,
    required this.rentDue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(tenantName),
        subtitle: Text(property),
        trailing: Text('\$${rentDue.toStringAsFixed(2)}'),
        onTap: onTap,
      ),
    );
  }
}

