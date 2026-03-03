import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';

class DistributionOrdersScreen extends StatelessWidget {
  const DistributionOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Distribution Orders'),
          backgroundColor: AppColors.primary),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 8,
        itemBuilder: (context, index) => Card(
          child: ListTile(
            leading: const Icon(Icons.local_shipping),
            title: Text('Order #${400 + index}'),
            subtitle: Text('Qty: ${50 + index * 10}'),
            trailing:
                ElevatedButton(onPressed: () {}, child: const Text('Track')),
          ),
        ),
      ),
    );
  }
}

