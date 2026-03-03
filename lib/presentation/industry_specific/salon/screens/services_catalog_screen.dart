import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../providers/salon_provider.dart';

class ServicesCatalogScreen extends StatelessWidget {
  const ServicesCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SalonProvider>(context);

    return Scaffold(
      appBar: AppBar(
          title: const Text('Services'), backgroundColor: AppColors.primary),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: provider.services.length,
        itemBuilder: (context, index) {
          final s = provider.services[index];
          return Card(
            child: ListTile(
              title: Text(s.name),
              subtitle: Text(
                  '${s.durationMinutes} mins • \₦${s.price.toStringAsFixed(2)}'),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}

