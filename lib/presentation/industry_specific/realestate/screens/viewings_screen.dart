import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/context_extensions.dart';
import '../providers/real_estate_provider.dart';

class ViewingsScreen extends StatelessWidget {
  const ViewingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.tryRead<RealEstateProvider>();
    if (prov == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Viewings'), backgroundColor: AppColors.primary),
        body: const Center(child: Text('Service not available. Try again.')),
      );
    }

    final bookings = prov.bookings;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Viewings'), backgroundColor: AppColors.primary),
      body: bookings.isEmpty
          ? const Center(child: Text('No scheduled viewings'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final b = bookings[index];
                final title = b.title.isNotEmpty ? b.title : 'Viewing';
                final property =
                    b.propertyName.isNotEmpty ? b.propertyName : b.propertyId;
                final date =
                    b.startAt.toLocal().toIso8601String().split('T').first;
                return Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.visibility),
                    title: Text(title),
                    subtitle: Text('$property • $date'),
                    trailing: ElevatedButton(
                        onPressed: () {}, child: const Text('Details')),
                  ),
                );
              },
            ),
    );
  }
}

