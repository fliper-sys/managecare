import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/context_extensions.dart';
import '../providers/real_estate_provider.dart';
import '../../../../widgets/lottie_dialog.dart';

class RentCollectionScreen extends StatelessWidget {
  const RentCollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.tryRead<RealEstateProvider>();
    if (prov == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rent Collection'), backgroundColor: AppColors.primary),
        body: const Center(child: Text('Service not available. Try again.')),
      );
    }

    final payments = prov.rentPayments;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Rent Collection'),
          backgroundColor: AppColors.primary),
      body: payments.isEmpty
          ? const Center(child: Text('No payments recorded'))
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
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: Text(tenant),
                    subtitle: Text('₦$amount • $date'),
                    trailing: ElevatedButton(
                        onPressed: () async {
                          // View details / mark as paid
                          if (p.status.toLowerCase() != 'paid') {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Mark payment as paid?'),
                                content: Text('Mark ₦${p.amount.toStringAsFixed(0)} from ${tenantObj.name} as paid?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await prov.updateRentPaymentStatus(p.id, 'paid', paidDate: DateTime.now());
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment marked as paid')));
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment already marked paid')));
                          }
                        }, child: const Text('View')),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Add a new payment using existing tenants/leases
          if (prov.tenants.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tenants found. Add a tenant first.')));
            return;
          }

          final _formKey = GlobalKey<FormState>();
          String selectedTenantId = prov.tenants.first.id;
          double amount = 0;
          String paymentMethod = 'cash';

          // If tenant has a lease, default to that rent amount
          final defaultTenant = prov.tenants.first;
          final leaseForDefault = prov.leases.firstWhere((l) => l.tenantId == defaultTenant.id, orElse: () => Lease.empty());
          if (leaseForDefault.id.isNotEmpty) amount = leaseForDefault.monthlyRent;

          final res = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Record Rent Payment'),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedTenantId,
                      items: prov.tenants.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          selectedTenantId = v;
                          final l = prov.leases.firstWhere((l) => l.tenantId == v, orElse: () => Lease.empty());
                          if (l.id.isNotEmpty) {
                            amount = l.monthlyRent;
                          }
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Tenant'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: amount > 0 ? amount.toStringAsFixed(0) : '',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount (₦)'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter amount' : null,
                      onSaved: (v) => amount = double.tryParse(v ?? '') ?? amount,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: paymentMethod,
                      items: ['cash', 'transfer', 'card'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) => paymentMethod = v ?? paymentMethod,
                      decoration: const InputDecoration(labelText: 'Payment method'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                TextButton(
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;
                      _formKey.currentState!.save();
                      final tenant = prov.tenants.firstWhere((t) => t.id == selectedTenantId);
                      final l = prov.leases.firstWhere((x) => x.tenantId == selectedTenantId, orElse: () => Lease.empty());
                      final now = DateTime.now();
                      final payment = RentPayment(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        leaseId: l.id,
                        tenantId: tenant.id,
                        amount: amount,
                        paymentMethod: paymentMethod,
                        dueDate: now,
                        paidDate: now,
                        status: 'paid',
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
                        await showSuccessLottieDialog(context, title: 'Payment Saved', message: 'Payment recorded successfully');
                      }
                    },
                    child: const Text('Save')),
              ],
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

