import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';

class InventoryProductsScreen extends StatelessWidget {
  const InventoryProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Inventory'), backgroundColor: AppColors.primary),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 14,
        itemBuilder: (context, index) => Card(
          child: ListTile(
            leading: const Icon(Icons.inventory_2),
            title: Text('Product ${index + 1}'),
            subtitle: Text('Stock: ${30 - index}'),
            trailing:
                IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
          ),
        ),
      ),
    );
  }
}

