import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../providers/pharmacy_provider.dart';
import '../../../../providers/auth_provider.dart';

class PrescriptionDetailScreen extends StatelessWidget {
  final String prescriptionId;

  const PrescriptionDetailScreen({super.key, required this.prescriptionId});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PharmacyProvider>(context);
    final matches =
        provider.prescriptions.where((p) => p.id == prescriptionId).toList();
    final pres = matches.isNotEmpty ? matches.first : null;

    if (pres == null) {
      return Scaffold(
        appBar: AppBar(
            title: const Text('Prescription'),
            backgroundColor: AppColors.primary),
        body: const Center(child: Text('Prescription not found')),
      );
    }

    final patient = provider.patients
        .cast<Patient?>()
        .firstWhere((pt) => pt?.id == pres.patientId, orElse: () => null);
    final patientName = patient != null ? patient.name : pres.patientId;

    return Scaffold(
      appBar: AppBar(
          title: const Text('Prescription Details'),
          backgroundColor: AppColors.primary),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient: $patientName',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Prescription ID: ${pres.id}'),
            const SizedBox(height: 8),
            Text('Status: ${pres.status}'),
            const SizedBox(height: 12),
            const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: pres.items.length,
                itemBuilder: (context, idx) {
                  final it = pres.items[idx];
                  final drug = provider.drugs.cast<Drug?>().firstWhere(
                      (d) => d?.id == it['drugId'],
                      orElse: () => null);
                  final drugName =
                      drug != null ? drug.name : (it['drugId'] as String);
                  return ListTile(
                    title: Text(drugName),
                    subtitle: Text('Qty: ${it['qty']}'),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    key: Key('dispense-button-$prescriptionId'),
                    onPressed: pres.status == 'pending'
                        ? () async {
                            // Determine controlled substances involved
                            final controlledIds = pres.items
                                .map((e) => e['drugId'] as String)
                                .where((id) => provider.isControlled(id))
                                .toList();
                            final controlledNames = controlledIds.map((id) {
                              final d = provider.drugs.cast<Drug?>().firstWhere(
                                  (dr) => dr?.id == id,
                                  orElse: () => null);
                              return d?.name ?? id;
                            }).toList();

                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) {
                                return AlertDialog(
                                  title: const Text('Confirm Dispense'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (controlledNames.isNotEmpty) ...[
                                        const Text(
                                            'This prescription contains controlled substances and will be audited.'),
                                        const SizedBox(height: 8),
                                        Text(
                                            'Controlled items: ${controlledNames.join(', ')}'),
                                      ] else ...[
                                        const Text(
                                            'Are you sure you want to dispense this prescription?'),
                                      ],
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel')),
                                    ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        child: const Text('Confirm')),
                                  ],
                                );
                              },
                            );

                            if (confirm == true) {
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              final userId = auth.currentUser?.id;
                              await provider.dispensePrescription(pres.id,
                                  persist: provider.hasRemote, userId: userId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Prescription dispensed')));
                                Navigator.pop(context, {'dispensed': true});
                              }
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary),
                    child: const Text('Dispense'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

