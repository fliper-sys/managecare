import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';

class FarmEditScreen extends StatelessWidget {
  final String name;
  const FarmEditScreen({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name), backgroundColor: AppColors.agri),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Farm', style: AppTextStyles.heading4),
            const SizedBox(height: 12),
            const TextField(
                decoration: InputDecoration(labelText: 'Farm name')),
            const SizedBox(height: 12),
            const TextField(decoration: InputDecoration(labelText: 'Location')),
            const SizedBox(height: 12),
            const TextField(
                decoration: InputDecoration(labelText: 'Size (Acres)')),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: () {},
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.agri),
                child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}

