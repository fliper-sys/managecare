import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';

class PropertyDetailsScreen extends StatelessWidget {
  final String propertyId;

  const PropertyDetailsScreen({super.key, required this.propertyId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('Property $propertyId'),
          backgroundColor: AppColors.primary),
      body: const Padding(
        padding: EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('3 Bed • 2 Bath • 1,400 sqft',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
                'Description: Comfortable family home in a quiet neighborhood.'),
          ],
        ),
      ),
    );
  }
}

