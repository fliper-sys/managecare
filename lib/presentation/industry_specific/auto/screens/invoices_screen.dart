import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
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
                subtitle: Text(
                  'Amount: ${formatCurrency(((inv['totalAmount'] as num?) ?? 0).toDouble())}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => _showInvoiceDetails(context, inv),
                ),
                onTap: () => _showInvoiceDetails(context, inv),
              ),
            );
          },
        );
      }),
    );
  }

  void _showInvoiceDetails(BuildContext context, Map<String, dynamic> invoice) {
    final amount = ((invoice['totalAmount'] as num?) ?? 0).toDouble();
    final issuedAt = invoice['createdAt'] ?? invoice['issuedAt'] ?? invoice['date'];
    String issuedLabel = 'Unknown';
    if (issuedAt != null) {
      final date = issuedAt is DateTime
          ? issuedAt
          : issuedAt is Timestamp
              ? issuedAt.toDate()
          : issuedAt is String
              ? DateTime.tryParse(issuedAt)
              : null;
      if (date != null) {
        issuedLabel = DateFormat('MMM d, yyyy h:mm a').format(date);
      } else {
        issuedLabel = issuedAt.toString();
      }
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(invoice['invoiceNumber'] as String? ?? invoice['id'] ?? 'Invoice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ${formatCurrency(amount)}'),
            Text('Issued: $issuedLabel'),
            if ((invoice['customerName'] ?? '').toString().isNotEmpty)
              Text('Customer: ${invoice['customerName']}'),
            if ((invoice['status'] ?? '').toString().isNotEmpty)
              Text('Status: ${invoice['status']}'),
            if ((invoice['notes'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Notes: ${invoice['notes']}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

