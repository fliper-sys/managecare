import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';

class EquipmentRentalScreen extends StatelessWidget {
  const EquipmentRentalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Equipment Rental'),
          backgroundColor: AppColors.primary),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 6,
        itemBuilder: (context, index) => Card(
          child: ListTile(
            leading: const Icon(Icons.build),
            title: Text('Equipment ${index + 1}'),
            subtitle: Text('Available: ${index.isEven ? 'Yes' : 'No'}'),
            trailing:
                ElevatedButton(onPressed: () {}, child: const Text('Rent')),
          ),
        ),
      ),
    );
  }
}

