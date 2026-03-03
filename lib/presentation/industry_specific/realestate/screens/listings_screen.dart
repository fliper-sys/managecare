import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/context_extensions.dart';
import '../widgets/property_card.dart';
import '../../../../core/theme/colors.dart';
import '../providers/real_estate_provider.dart';
import '../../../../core/constants/routes.dart';

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.tryRead<RealEstateProvider>();
      if (prov != null) {
        prov.loadProperties();
      } else {
        // Try again shortly if provider not yet available (startup timing)
        Future.delayed(const Duration(milliseconds: 150), () {
          final p2 = context.tryRead<RealEstateProvider>();
          p2?.loadProperties();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Listings'), backgroundColor: AppColors.primary),
      body: Consumer<RealEstateProvider>(
        builder: (context, provider, _) {
          final properties = provider.properties;
          if (properties.isEmpty) {
            return const Center(child: Text('No properties available'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: properties.length,
            itemBuilder: (context, index) {
              final property = properties[index];
              return PropertyCard(
                id: property.id,
                title: property.title,
                price: '₦${property.price.toStringAsFixed(0)}',
                location: property.location,
                onTap: () => Navigator.pushNamed(
                    context, Routes.realEstatePropertyDetails,
                    arguments: {'id': property.id}),
              );
            },
          );
        },
      ),
    );
  }
}

