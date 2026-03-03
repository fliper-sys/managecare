import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/salon_provider.dart';

class CommissionScreen extends StatefulWidget {
  const CommissionScreen({super.key});

  @override
  State<CommissionScreen> createState() => _CommissionScreenState();
}

class _CommissionScreenState extends State<CommissionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SalonProvider>();
      provider.loadStylists();
      provider.loadAppointments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Commission')),
      body: Consumer<SalonProvider>(builder: (context, provider, _) {
        final stylists = provider.stylists;
        if (stylists.isEmpty) {
          return const Center(child: Text('No stylists found'));
        }

        final totalCommission = stylists
            .map((s) => provider.getStylistCommissionTotal(s.id))
            .fold<double>(0.0, (a, b) => a + b);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Stylist', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text('Owed', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: stylists.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final s = stylists[index];
                  final owed = provider.getStylistCommissionTotal(s.id);
                  final completed = provider.appointments.where((a) => a.stylistId == s.id && a.status == 'completed').toList();

                  return ExpansionTile(
                    title: Text(s.name),
                    subtitle: Text(s.specialization),
                    trailing: Text('₦${owed.toStringAsFixed(2)}'),
                    children: [
                      if (completed.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Text('No completed bookings'),
                        )
                      else
                        ...completed.map((a) {
                          final amount = (a.amountPaid != null && a.amountPaid! > 0) ? a.amountPaid! : a.servicePrice;
                          final commission = amount * ((s.commissionPercentage ?? 0.0) / 100.0);
                          final date = DateFormat('MMM dd, yyyy').format(a.appointmentTime);
                          final time = DateFormat('HH:mm').format(a.appointmentTime);
                          return ListTile(
                            title: Text('${a.serviceName} • ${a.clientName}'),
                            subtitle: Text('$date • $time'),
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('₦${amount.toStringAsFixed(2)}'),
                                Text('Comm: ₦${commission.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          );
                        }).toList(),
                    ],
                  );
                },

              ),
            ),
            Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Commission Owed'),
                    Text('₦${totalCommission.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            )
          ],
        );
      }),
    );
  }
}

