import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/pharmacy_provider.dart';

class PharmacyTreatmentsScreen extends StatefulWidget {
  const PharmacyTreatmentsScreen({super.key});

  @override
  State<PharmacyTreatmentsScreen> createState() =>
      _PharmacyTreatmentsScreenState();
}

class _PharmacyTreatmentsScreenState extends State<PharmacyTreatmentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final business = context.read<BusinessProvider>().currentBusiness;
      if (business != null) {
        context.read<PharmacyProvider>().loadFromRepository(
              businessId: business.id,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final business = context.watch<BusinessProvider>().currentBusiness;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Treatments'),
        backgroundColor: AppColors.pharmacy,
      ),
      body: Consumer<PharmacyProvider>(
        builder: (context, provider, _) {
          final treatments = provider.treatments.toList()
            ..sort((a, b) => b.startDate.compareTo(a.startDate));
          if (treatments.isEmpty) {
            return const Center(child: Text('No treatments recorded'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: treatments.length,
            itemBuilder: (context, index) {
              final treatment = treatments[index];
              final patient = provider.getPatientById(treatment.patientId);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(treatment.name,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(patient?.name ?? 'Unknown patient'),
                      Text('${treatment.drugName} - ${treatment.dosage}'),
                      Text(
                        '${treatment.frequencyPerDay} sessions/day for ${treatment.durationDays} days · ${treatment.dosesGiven}/${treatment.totalDosesExpected} completed',
                      ),
                      if (treatment.inventoryItems.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(treatment.inventoryItems.map((item) {
                            final quantity = item['quantity'] ?? 1;
                            return '${item['name'] ?? 'Item'} x$quantity';
                          }).join(', ')),
                        ),
                      if (treatment.consultationFee > 0)
                        Text(
                          'Consultation: ₦${treatment.consultationFee.toStringAsFixed(2)}',
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: treatment.sessions.map((session) {
                          final sessionIndex = session['index'] as int;
                          final status = session['status']?.toString() ?? 'pending';
                          return PopupMenuButton<String>(
                            tooltip: 'Update session status',
                            onSelected: (nextStatus) async {
                              try {
                                await provider.updateTreatmentSessionStatus(
                                  treatment.id,
                                  sessionIndex,
                                  nextStatus,
                                  persist: provider.hasRemote,
                                  businessId: business?.id,
                                );
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Could not update session: $error',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'pending',
                                child: Text('Pending'),
                              ),
                              PopupMenuItem(
                                value: 'completed',
                                child: Text('Completed / Confirmed'),
                              ),
                              PopupMenuItem(
                                value: 'missed',
                                child: Text('Missed'),
                              ),
                            ],
                            child: Chip(
                              label: Text(
                                '${session['label']}: ${_statusLabel(status)}',
                              ),
                              backgroundColor: _statusColor(status),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'missed':
        return 'Missed';
      default:
        return 'Pending';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green.shade100;
      case 'missed':
        return Colors.red.shade100;
      default:
        return Colors.amber.shade100;
    }
  }
}