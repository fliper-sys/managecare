import 'package:flutter/material.dart';

class BottleCard extends StatelessWidget {
  final String id;
  final String status;
  final VoidCallback? onTap;

  const BottleCard(
      {super.key, required this.id, required this.status, this.onTap});

  @override
  Widget build(BuildContext context) {
    final inStock = status.toLowerCase().contains('stock');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.wine_bar),
        title: Text(id),
        subtitle: Text(status),
        trailing: Icon(Icons.circle,
            color: inStock ? Colors.green : Colors.orange, size: 12),
        onTap: onTap,
      ),
    );
  }
}

