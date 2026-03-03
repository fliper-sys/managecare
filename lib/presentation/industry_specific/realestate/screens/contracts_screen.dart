import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';

class ContractsScreen extends StatelessWidget {
  const ContractsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Contracts'), backgroundColor: AppColors.primary),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 6,
        itemBuilder: (context, index) => Card(
          child: ListTile(
            leading: const Icon(Icons.description),
            title: Text('Contract #${400 + index}'),
            subtitle: Text('Property: P-${300 + index} • Status: Signed'),
            trailing:
                IconButton(icon: const Icon(Icons.download), onPressed: () {}),
          ),
        ),
      ),
    );
  }
}

