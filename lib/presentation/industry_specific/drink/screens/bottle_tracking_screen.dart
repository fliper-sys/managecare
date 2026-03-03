import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../widgets/bottle_card.dart';
import '../../../../providers/drink_provider.dart';

class BottleTrackingScreen extends StatelessWidget {
  const BottleTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DrinkProvider>(context);
    final inventory = provider.inventory;

    return Scaffold(
      appBar: AppBar(
          title: const Text('Bottle Tracking'),
          backgroundColor: AppColors.primary),
      body: inventory.isEmpty
          ? Center(
              child: Text('No inventory records',
                  style: Theme.of(context).textTheme.bodyMedium),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: inventory.length,
              itemBuilder: (context, index) {
                final item = inventory[index];
                final drink = provider.getDrinkById(item.drinkId);
                final id = drink?.name ?? item.drinkId;
                final status = provider.getTotalBottles(item.drinkId) > 0
                    ? 'In stock: ${provider.getTotalBottles(item.drinkId)}'
                    : 'Out of stock';
                return BottleCard(id: id, status: status);
              },
            ),
    );
  }
}

