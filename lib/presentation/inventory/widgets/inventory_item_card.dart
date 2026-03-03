import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

class InventoryItemCard extends StatelessWidget {
  final String name;
  final int quantity;
  final String price;
  final VoidCallback onTap;

  const InventoryItemCard({
    super.key,
    required this.name,
    required this.quantity,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLowStock = quantity < 10;
    return Card(
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isLowStock
                ? Colors.orange.withOpacity(0.2)
                : AppColors.lightGrey,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.inventory_2,
            color: isLowStock ? Colors.orange : AppColors.darkGrey,
          ),
        ),
        title: Text(name),
        subtitle: Text('Stock: $quantity units'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(price, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (isLowStock)
              const Text('Low Stock',
                  style: TextStyle(color: Colors.orange, fontSize: 12)),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

