import 'package:flutter/material.dart';

class OrderCard extends StatelessWidget {
  final String orderId;
  final String table;
  final String status;
  final VoidCallback? onTap;

  const OrderCard(
      {super.key,
      required this.orderId,
      required this.table,
      required this.status,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.receipt),
        title: Text(orderId),
        subtitle: Text('Table $table • $status'),
        trailing:
            ElevatedButton(onPressed: onTap, child: const Text('Details')),
      ),
    );
  }
}

