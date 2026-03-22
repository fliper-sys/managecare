import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
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
      appBar: AppBar(
        title: const Text('Commission'),
        backgroundColor: AppColors.primary,
      ),
      body: Consumer<SalonProvider>(
        builder: (context, provider, _) {
          final stylists = provider.stylists;
          if (stylists.isEmpty) {
            return const Center(child: Text('No stylists found'));
          }

          final totalCommission = stylists
              .map((stylist) => provider.getStylistCommissionTotal(stylist.id))
              .fold<double>(0.0, (sum, value) => sum + value);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Stylist', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Owed', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: stylists.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final stylist = stylists[index];
                    final owed = provider.getStylistCommissionTotal(stylist.id);
                    final completed = provider.appointments.where((appointment) {
                      return appointment.stylistId == stylist.id &&
                          appointment.status == 'completed';
                    }).toList();

                    return ExpansionTile(
                      title: Text(stylist.name),
                      subtitle: Text(stylist.specialization),
                      trailing: Text(formatCurrency(owed)),
                      children: [
                        if (completed.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('No completed bookings'),
                          )
                        else
                          ...completed.map((appointment) {
                            final amount = (appointment.amountPaid != null &&
                                    appointment.amountPaid! > 0)
                                ? appointment.amountPaid!
                                : appointment.servicePrice;
                            final commission = amount *
                                ((stylist.commissionPercentage ?? 0.0) / 100.0);
                            final date = DateFormat('MMM dd, yyyy')
                                .format(appointment.appointmentTime);
                            final time =
                                DateFormat('HH:mm').format(appointment.appointmentTime);

                            return ListTile(
                              title: Text(
                                  '${appointment.serviceName} - ${appointment.clientName}'),
                              subtitle: Text('$date - $time'),
                              trailing: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(formatCurrency(amount)),
                                  Text(
                                    'Comm: ${formatCurrency(commission)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    );
                  },
                ),
              ),
              Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Commission Owed'),
                      Text(formatCurrency(totalCommission)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
