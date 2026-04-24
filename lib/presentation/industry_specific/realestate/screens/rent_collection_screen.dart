import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/context_extensions.dart';
import '../providers/real_estate_provider.dart';
import '../../../../widgets/lottie_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:business_manager/services/email_service.dart';

class RentCollectionScreen extends StatelessWidget {
  const RentCollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final prov = context.tryRead<RealEstateProvider>();
    if (prov == null) {
      return Scaffold(
        appBar: AppBar(
            title: const Text('Rent Collection'),
            backgroundColor: AppColors.primary),
        body: const Center(child: Text('Service not available. Try again.')),
      );
    }

    final payments = prov.rentPayments;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
          title: const Text('Rent Collection'),
          backgroundColor: AppColors.primary),
      body: payments.isEmpty
          ? Center(
              child: Text(
                'No payments recorded',
                style: TextStyle(color: scheme.onSurface),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: payments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final p = payments[index];
                final tenantObj = prov.tenants.firstWhere(
                    (t) => t.id == p.tenantId,
                    orElse: () => Tenant.empty());
                final tenant =
                    tenantObj.name.isNotEmpty ? tenantObj.name : 'Tenant';
                final amount = p.amount.toStringAsFixed(0);
                final date =
                    (p.paidDate ?? p.createdAt).toLocal().toIso8601String();
                return Card(
                  color: theme.cardColor,
                  child: ListTile(
                    leading: Icon(Icons.receipt_long, color: scheme.primary),
                    title: Text(
                      tenant,
                      style: TextStyle(color: scheme.onSurface),
                    ),
                    subtitle: Text('₦$amount • $date'),
                    trailing: ElevatedButton(
                        onPressed: () async {
                          // View details / mark as paid
                          if (p.status.toLowerCase() != 'paid') {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Mark payment as paid?'),
                                content: Text(
                                    'Mark ₦${p.amount.toStringAsFixed(0)} from ${tenantObj.name} as paid?'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel')),
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Confirm')),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await prov.updateRentPaymentStatus(p.id, 'paid',
                                  paidDate: DateTime.now());
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Payment marked as paid')));
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Payment already marked paid')));
                          }
                        },
                        child: const Text('View')),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Add a new payment using existing tenants/leases
          if (prov.tenants.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('No tenants found. Add a tenant first.')));
            return;
          }

          final _formKey = GlobalKey<FormState>();
          String selectedTenantId = prov.tenants.first.id;
          double amount = 0;
          final amountController = TextEditingController();
          String paymentMethod = 'cash';
          int durationMonths = 1;
          DateTime dueDate = DateTime.now().add(const Duration(days: 30));
          String? receiptUrl;

          // If tenant has a lease, default to that rent amount
          final defaultTenant = prov.tenants.first;
          final leaseForDefault = prov.leases.firstWhere(
              (l) => l.tenantId == defaultTenant.id,
              orElse: () => Lease.empty());
          if (leaseForDefault.id.isNotEmpty) {
            amount = leaseForDefault.monthlyRent;
            amountController.text = amount.toStringAsFixed(0);
          }

          final res = await showDialog<bool>(
            context: context,
            builder: (ctx) => StatefulBuilder(
              builder: (context, setState) => AlertDialog(
                title: const Text('Record Rent Payment'),
                content: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedTenantId,
                          items: prov.tenants
                              .map((t) => DropdownMenuItem(
                                  value: t.id,
                                  child: Text('${t.name} (${t.email})')))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              selectedTenantId = v;
                              final l = prov.leases.firstWhere(
                                  (l) => l.tenantId == v,
                                  orElse: () => Lease.empty());
                              if (l.id.isNotEmpty) {
                                amount = l.monthlyRent;
                                amountController.text =
                                    amount.toStringAsFixed(0);
                              }
                            }
                          },
                          decoration:
                              const InputDecoration(labelText: 'Tenant'),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Amount (₦)'),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Enter amount' : null,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: durationMonths,
                          items: [1, 2, 3, 6, 12]
                              .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text('$m month${m > 1 ? 's' : ''}')))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              durationMonths = v;
                              dueDate = DateTime.now()
                                  .add(Duration(days: 30 * durationMonths));
                              setState(() {});
                            }
                          },
                          decoration:
                              const InputDecoration(labelText: 'Duration'),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Due date: '),
                            Expanded(
                              child: Text(
                                dueDate
                                    .toLocal()
                                    .toIso8601String()
                                    .split('T')
                                    .first,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: paymentMethod,
                          items: ['cash', 'transfer', 'card', 'cheque']
                              .map((m) =>
                                  DropdownMenuItem(value: m, child: Text(m)))
                              .toList(),
                          onChanged: (v) => paymentMethod = v ?? paymentMethod,
                          decoration: const InputDecoration(
                              labelText: 'Payment method'),
                        ),
                        const SizedBox(height: 8),
                        // Receipt upload
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                receiptUrl != null
                                    ? 'Receipt uploaded'
                                    : 'No receipt uploaded',
                                style: TextStyle(
                                    color: receiptUrl != null
                                        ? Colors.green
                                        : scheme.onSurface.withOpacity(0.64)),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                try {
                                  final result =
                                      await FilePicker.platform.pickFiles(
                                    allowMultiple: false,
                                    type: FileType.custom,
                                    allowedExtensions: [
                                      'pdf',
                                      'jpg',
                                      'jpeg',
                                      'png'
                                    ],
                                  );
                                  if (result != null &&
                                      result.files.isNotEmpty) {
                                    final picked = result.files.single;
                                    final bytes = picked.bytes;
                                    final filename = picked.name;
                                    if (bytes != null && bytes.isNotEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Uploading receipt...')));
                                      final url = await EmailService()
                                          .uploadBytes(bytes, filename);
                                      if (url != null) {
                                        setState(() => receiptUrl = url);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content:
                                                    Text('Receipt uploaded')));
                                      }
                                    }
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('Upload failed: $e')));
                                }
                              },
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Upload Receipt'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Display tenant contact info
                        Builder(
                          builder: (context) {
                            final tenant = prov.tenants.firstWhere(
                                (t) => t.id == selectedTenantId,
                                orElse: () => Tenant.empty());
                            if (tenant.id.isNotEmpty) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Tenant Contact Info:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text('Email: ${tenant.email}'),
                                  Text('Phone: ${tenant.phone}'),
                                  if (tenant.whatsapp != null &&
                                      tenant.whatsapp!.isNotEmpty)
                                    Text('WhatsApp: ${tenant.whatsapp}'),
                                ],
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () async {
                        if (!_formKey.currentState!.validate()) return;
                        final parsedAmount =
                            double.tryParse(amountController.text) ?? 0;
                        if (parsedAmount <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text('Enter a valid amount.')),
                          );
                          return;
                        }
                        final tenant = prov.tenants
                            .firstWhere((t) => t.id == selectedTenantId);
                        final l = prov.leases.firstWhere(
                            (x) => x.tenantId == selectedTenantId,
                            orElse: () => Lease.empty());
                        final now = DateTime.now();
                        final paymentDueDate =
                            now.add(Duration(days: 30 * durationMonths));
                        final payment = RentPayment(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          leaseId: l.id,
                          tenantId: tenant.id,
                          amount: parsedAmount,
                          paymentMethod: paymentMethod,
                          dueDate: paymentDueDate,
                          paidDate: now,
                          durationMonths: durationMonths,
                          status: 'paid',
                          receiptUrl: receiptUrl,
                          createdAt: now,
                        );

                        Navigator.pop(ctx, true);

                        final ok = await runWithLottieErrorHandling<bool>(
                          context,
                          () async {
                            await prov.recordRentPayment(payment);
                            return true;
                          },
                          errorTitle: 'Payment Failed',
                        );
                        if (ok == true) {
                          await showSuccessLottieDialog(context,
                              title: 'Payment Saved',
                              message: 'Payment recorded successfully');
                        }
                      },
                      child: const Text('Save')),
                ],
              ),
            ),
          );

          if (res == true) {
            // nothing else needed - dialog already handled success
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
