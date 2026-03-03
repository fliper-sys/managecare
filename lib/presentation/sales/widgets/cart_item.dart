import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

class CartItem extends StatelessWidget {
  final String name;
  final String price;
  final int quantity;
  final VoidCallback onRemove;

  const CartItem({
    super.key,
    required this.name,
    required this.price,
    required this.quantity,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          color: AppColors.lightGrey,
        ),
        title: Text(name),
        subtitle: Text('$price x $quantity'),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle),
          onPressed: onRemove,
        ),
      ),
    );
  }
}

