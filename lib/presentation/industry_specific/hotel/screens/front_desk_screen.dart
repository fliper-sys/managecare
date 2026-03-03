import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';

class FrontDeskScreen extends StatelessWidget {
  const FrontDeskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Front Desk'), backgroundColor: AppColors.primary),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: const [
          Card(
              child: ListTile(
                  title: Text('Check-ins'), subtitle: Text('5 waiting'))),
          SizedBox(height: 8),
          Card(
              child: ListTile(
                  title: Text('Check-outs'), subtitle: Text('2 today'))),
        ],
      ),
    );
  }
}

