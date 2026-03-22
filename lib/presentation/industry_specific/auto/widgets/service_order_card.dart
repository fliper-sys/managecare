import 'package:flutter/material.dart';

class ServiceOrderCard extends StatelessWidget {
  final String orderId;
  final String customerName;
  final String status;
  final VoidCallback onTap;

  const ServiceOrderCard({
    super.key,
    required this.orderId,
    required this.customerName,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('Order: $orderId'),
        subtitle: Text('$customerName - $status'),
        onTap: onTap,
      ),
    );
  }
}

