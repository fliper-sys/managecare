import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';

class HotelServicesScreen extends StatelessWidget {
  const HotelServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Services'), backgroundColor: AppColors.primary),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: const [
          Card(child: ListTile(title: Text('Room Service'))),
          Card(child: ListTile(title: Text('Laundry'))),
          Card(child: ListTile(title: Text('Spa & Wellness'))),
        ],
      ),
    );
  }
}

