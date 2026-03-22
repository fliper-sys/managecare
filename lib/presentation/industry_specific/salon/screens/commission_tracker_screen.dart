import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/auth_provider.dart';
import '../providers/salon_provider.dart';

class CommissionTrackerScreen extends StatefulWidget {
  const CommissionTrackerScreen({super.key});

  @override
  State<CommissionTrackerScreen> createState() => _CommissionTrackerScreenState();
}

class _CommissionTrackerScreenState extends State<CommissionTrackerScreen> {
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() => _range = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SalonProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    final start = _range!.start;
    final end = DateTime(
      _range!.end.year,
      _range!.end.month,
      _range!.end.day,
      23,
      59,
      59,
    );

    final isWorker = auth.isWorkerUser;
    final stylistForWorker = isWorker
        ? provider.stylists.firstWhere(
            (stylist) =>
                stylist.email == auth.currentUser?.email ||
                stylist.id == auth.currentUser?.id,
            orElse: () => Stylist(
              id: auth.currentUser?.id ?? 'unknown',
              name: auth.currentUser?.email ?? 'Worker',
              email: auth.currentUser?.email ?? '',
              phone: auth.currentUser?.phoneNumber,
              specialization: 'stylist',
              serviceIds: const [],
              commissionPercentage: 0.0,
              createdAt: DateTime.now(),
            ),
          )
        : null;

    final commissions = isWorker && stylistForWorker != null
        ? {
            stylistForWorker.id: provider.getStylistCommissionTotalForPeriod(
              stylistForWorker.id,
              start,
              end,
            ),
          }
        : provider.getCommissionsByStylistForPeriod(start, end);

    final stylists = provider.stylists
        .where((stylist) => !isWorker || stylist.id == stylistForWorker?.id)
        .toList();

    final total = commissions.values.fold<double>(0.0, (sum, value) => sum + value);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commission Tracker'),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _pickRange,
                  child: const Text('Select range'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${DateFormat('yyyy-MM-dd').format(_range!.start)} -> ${DateFormat('yyyy-MM-dd').format(_range!.end)}',
                  ),
                ),
                Text('Total: ${formatCurrency(total)}'),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: stylists.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final stylist = stylists[index];
                final commission = commissions[stylist.id] ?? 0.0;
                return Card(
                  child: ListTile(
                    title: Text(stylist.name),
                    subtitle: Text(
                      '${stylist.specialization} - ${(stylist.commissionPercentage ?? 0.0).toStringAsFixed(1)}%',
                    ),
                    trailing: Text(formatCurrency(commission)),
                    onTap: () {
                      showModalBottomSheet<void>(
                        context: context,
                        builder: (ctx) {
                          final appointments =
                              provider.getAppointmentsForStylistInPeriod(
                            stylist.id,
                            start,
                            end,
                          );
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${stylist.name} - Appointments',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (appointments.isEmpty)
                                  const Text('No appointments in selected period'),
                                ...appointments.map(
                                  (appointment) => ListTile(
                                    title: Text(appointment.serviceName),
                                    subtitle: Text(
                                      '${appointment.clientName} - ${DateFormat('yyyy-MM-dd').format(appointment.appointmentTime)}',
                                    ),
                                    trailing: Text(
                                      formatCurrency(appointment.servicePrice),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
