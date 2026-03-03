import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _range = DateTimeRange(start: start, end: end);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SalonProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    final start = _range!.start;
    final end = DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59);

    // If worker, show only their stylist record
    final isWorker = auth.isWorkerUser;
    final stylistForWorker = isWorker
        ? provider.stylists.firstWhere((s) => s.email == auth.currentUser?.email || s.id == auth.currentUser?.id, orElse: () => Stylist(
            id: auth.currentUser?.id ?? 'unknown',
            name: auth.currentUser?.email ?? 'Worker',
            email: auth.currentUser?.email ?? '',
            phone: auth.currentUser?.phoneNumber ?? null,
            specialization: 'stylist',
            serviceIds: [],
            commissionPercentage: 0.0,
            createdAt: DateTime.now(),
          ))
        : null;

    final commissions = isWorker && stylistForWorker != null
        ? {stylistForWorker.id: provider.getStylistCommissionTotalForPeriod(stylistForWorker.id, start, end)}
        : provider.getCommissionsByStylistForPeriod(start, end);

    final stylists = provider.stylists.where((s) => !isWorker || s.id == stylistForWorker?.id).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Commission Tracker')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                ElevatedButton(onPressed: _pickRange, child: const Text('Select range')),
                const SizedBox(width: 12),
                Text('${_range!.start.toLocal().toString().split(' ')[0]} → ${_range!.end.toLocal().toString().split(' ')[0]}'),
                const Spacer(),
                Text('Total: ₦${commissions.values.fold(0.0, (a, b) => a + b).toStringAsFixed(2)}')
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: stylists.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final s = stylists[index];
                final val = commissions[s.id] ?? 0.0;
                return Card(
                  child: ListTile(
                    title: Text(s.name),
                    subtitle: Text('${s.specialization} • ${((s.commissionPercentage ?? 0.0)).toStringAsFixed(1)}%'),
                    trailing: Text('₦${val.toStringAsFixed(2)}'),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (ctx) {
                          final appointments = provider.getAppointmentsForStylistInPeriod(s.id, start, end);
                          return Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${s.name} — Appointments', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                if (appointments.isEmpty) const Text('No appointments in selected period'),
                                ...appointments.map((a) => ListTile(
                                      title: Text(a.serviceName),
                                      subtitle: Text('${a.clientName} • ${a.appointmentTime.toLocal().toString().split(' ')[0]}'),
                                      trailing: Text('₦${a.servicePrice.toStringAsFixed(2)}'),
                                    )),
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
          )
        ],
      ),
    );
  }
}
