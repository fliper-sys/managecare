import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/currency.dart';
import '../providers/barber_shop_provider.dart';

class BarberCommissionScreen extends StatefulWidget {
  const BarberCommissionScreen({super.key});

  @override
  State<BarberCommissionScreen> createState() => _BarberCommissionScreenState();
}

class _BarberCommissionScreenState extends State<BarberCommissionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BarberShopProvider>();
      provider.loadBarbers();
      provider.loadSales();
      provider.loadAppointments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Commissions')),
      body: Consumer<BarberShopProvider>(builder: (context, provider, _) {
        final barbers = provider.barbers;
        if (barbers.isEmpty) {
          return const Center(child: Text('No barbers found'));
        }

        final totalCommission =
            barbers.map((b) => provider.getBarberCommissionTotal(b.id)).fold<double>(0.0, (a, b) => a + b);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Barber', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Owed', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: barbers.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final b = barbers[index];
                  final owed = provider.getBarberCommissionTotal(b.id);
                  final completed = provider.appointments.where((a) => a.barberId == b.id && a.status == 'completed').toList();

                  return ExpansionTile(
                    title: Text(b.name),
                    subtitle: Text(b.specialization),
                    trailing: Text(formatCurrency(owed)),
                    children: [
                      if (completed.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Text('No completed bookings'),
                        )
                      else
                        ...completed.map((a) {
                          final amount = (a.amountPaid != null && a.amountPaid! > 0) ? a.amountPaid! : a.servicePrice;
                          final commission = amount * ((b.commissionPercentage ?? 0.0) / 100.0);
                          final date = DateFormat('MMM dd, yyyy').format(a.appointmentTime);
                          final time = DateFormat('HH:mm').format(a.appointmentTime);
                          return ListTile(
                            title: Text('${a.serviceName} - ${a.clientName}'),
                            subtitle: Text('$date - $time'),
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatCurrency(amount)),
                                Text('Comm: ${formatCurrency(commission)}', style: const TextStyle(fontSize: 12)),
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
                    Text(formatCurrency(totalCommission)),
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
