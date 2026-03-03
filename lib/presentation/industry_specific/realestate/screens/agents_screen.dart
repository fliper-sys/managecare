import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';

class AgentsScreen extends StatelessWidget {
  const AgentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Agents'), backgroundColor: AppColors.primary),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: 8,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) => ListTile(
          leading: CircleAvatar(child: Text('A${index + 1}')),
          title: Text('Agent ${index + 1}'),
          subtitle: Text('Phone: +1-555-02$index'),
          trailing:
              ElevatedButton(onPressed: () {}, child: const Text('Contact')),
        ),
      ),
    );
  }
}

