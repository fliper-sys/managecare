import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../providers/salon_provider.dart';
import 'salon_services_screen.dart';

class ServicesCatalogScreen extends StatefulWidget {
  const ServicesCatalogScreen({super.key});

  @override
  State<ServicesCatalogScreen> createState() => _ServicesCatalogScreenState();
}

class _ServicesCatalogScreenState extends State<ServicesCatalogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalonProvider>().loadServices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SalonProvider>(
      builder: (context, provider, _) {
        final services = provider.services;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Services Catalog'),
            backgroundColor: AppColors.primary,
          ),
          backgroundColor: Colors.grey[50],
          body: services.isEmpty
              ? Center(
                  child: Text(
                    'No services available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: services.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final service = services[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.12),
                          child: const Icon(Icons.spa, color: AppColors.primary),
                        ),
                        title: Text(service.name),
                        subtitle: Text(
                          '${service.durationMinutes} mins - ${service.category}',
                        ),
                        trailing: Text(
                          formatCurrency(service.price),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SalonServicesScreen(),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SalonServicesScreen(),
                ),
              );
            },
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add),
            label: const Text('Manage'),
          ),
        );
      },
    );
  }
}
