import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/marketer_provider.dart';
import '../../core/constants/routes.dart';
import '../../models/marketer_model.dart';

class MarketerDashboardScreen extends StatefulWidget {
  const MarketerDashboardScreen({Key? key}) : super(key: key);

  @override
  State<MarketerDashboardScreen> createState() => _MarketerDashboardScreenState();
}

class _MarketerDashboardScreenState extends State<MarketerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    final marketer = context.read<MarketerProvider>().currentMarketer;
    if (marketer != null) {
      context.read<MarketerProvider>().fetchMarketerReferrals(marketer.email);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketer Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<MarketerProvider>().logoutMarketer();
              Navigator.of(context).pushReplacementNamed(Routes.adminLogin);
            },
          )
        ],
      ),
      body: Consumer<MarketerProvider>(builder: (context, prov, _) {
        final marketer = prov.currentMarketer;
        if (marketer == null) {
          return const Center(child: Text('No marketer logged in'));
        }
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: ${marketer.fullName}'),
              Text('Email: ${marketer.email}'),
              if (marketer.phoneNumber != null) Text('Phone: ${marketer.phoneNumber}'),
              const SizedBox(height: 8),
              Text('Balance: ₦${marketer.balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Referrals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: prov.referrals.isEmpty
                    ? const Center(child: Text('No referred users yet'))
                    : ListView.builder(
                        itemCount: prov.referrals.length,
                        itemBuilder: (ctx, i) {
                          final r = prov.referrals[i];
                          return ListTile(
                            title: Text(r.userEmail),
                            subtitle: Text(r.status),
                            trailing: Text('₦${r.commissionAmount.toStringAsFixed(0)}'),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      }),
    );
  }
}