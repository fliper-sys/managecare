import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';

class PromotionsScreen extends StatelessWidget {
  const PromotionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Promotions'), backgroundColor: AppColors.primary),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: const [
          Card(child: ListTile(title: Text('Buy 1 Get 1 Free'))),
          Card(child: ListTile(title: Text('20% off selected items'))),
          Card(child: ListTile(title: Text('Seasonal sale'))),
        ],
      ),
    );
  }
}

