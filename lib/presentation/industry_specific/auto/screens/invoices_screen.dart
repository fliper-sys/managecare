import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../providers/auto_provider.dart';

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoices'), backgroundColor: AppColors.primary),
      body: Consumer<AutoProvider>(builder: (context, provider, _) {
        if (provider.isLoadingData) return const Center(child: CircularProgressIndicator());
        if (provider.dataError != null) return Center(child: Text(provider.dataError!));
        final invoices = provider.invoices;
        if (invoices.isEmpty) return const Center(child: Text('No invoices'));
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: invoices.length,
          itemBuilder: (context, index) {
            final inv = invoices[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text(inv['invoiceNumber'] as String? ?? inv['id']),
                subtitle: Text('Amount: \$${(inv['totalAmount'] as num? ?? 0).toStringAsFixed(2)}'),
                trailing: IconButton(icon: const Icon(Icons.download), onPressed: () {}),
              ),
            );
          },
        );
      }),
    );
  }
}

