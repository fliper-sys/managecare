import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/auth_provider.dart';

class BusinessSwitcherScreen extends StatelessWidget {
  const BusinessSwitcherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final businessProvider = context.watch<BusinessProvider>();
    final authProvider = context.read<AuthProvider>();
    final businesses = businessProvider.userBusinesses;

    return Scaffold(
      appBar: AppBar(title: const Text('Switch Business')),
      body: businesses.isEmpty
          ? const Center(child: Text('No businesses found'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: businesses.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, idx) {
                final b = businesses[idx];
                final isCurrent = businessProvider.currentBusiness?.id == b.id;
                return ListTile(
                  title: Text(b.name),
                  subtitle: Text(b.businessType),
                  trailing: isCurrent ? const Icon(Icons.check_circle) : null,
                  onTap: () async {
                    // Prefer to persist preference if user is available
                    final userId = authProvider.currentUser?.id;
                    if (userId != null) {
                      await businessProvider.setCurrentBusinessAndSave(
                          userId, b);
                    } else {
                      await businessProvider.setCurrentBusiness(b);
                    }
                    Navigator.of(context).pop(true);
                  },
                );
              },
            ),
    );
  }
}

