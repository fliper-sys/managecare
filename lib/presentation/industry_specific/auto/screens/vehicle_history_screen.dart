import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/auto_provider.dart';
import 'job_card_screen.dart';

class VehicleHistoryScreen extends StatefulWidget {
  const VehicleHistoryScreen({super.key});

  @override
  State<VehicleHistoryScreen> createState() => _VehicleHistoryScreenState();
}

class _VehicleHistoryScreenState extends State<VehicleHistoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<AutoProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (provider.dataError != null) {
          return Scaffold(body: Center(child: Text(provider.dataError!)));
        }

        final jobs = provider.jobs.where((job) {
          final vehicle = provider.getVehicleById(job.vehicleId);
          final haystack = [
            job.id,
            job.vehicleId,
            job.customerId ?? '',
            job.assignedWorkerName ?? '',
            job.assignedWorkerId ?? '',
            job.description ?? '',
            vehicle?.make ?? '',
            vehicle?.model ?? '',
            vehicle?.licensePlate ?? '',
            vehicle?.vin ?? '',
            vehicle?.ownerName ?? '',
            vehicle?.ownerPhone ?? '',
          ].join(' ').toLowerCase();
          return _query.trim().isEmpty || haystack.contains(_query.trim().toLowerCase());
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Customer & Vehicle History'),
            backgroundColor: AppColors.primary,
          ),
          body: RefreshIndicator(
            onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 200)),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo.shade700, Colors.blueGrey.shade900],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    'Search by plate, VIN, customer, worker, or job number to find previous jobs quickly.',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Search history',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onChanged: (value) => setState(() => _query = value.trim()),
                ),
                const SizedBox(height: 12),
                Text(
                  '${jobs.length} matching job${jobs.length == 1 ? '' : 's'}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                if (jobs.isEmpty)
                  _EmptyHistory(
                    title: 'No history found',
                    subtitle: 'Try searching a different plate, customer, or VIN.',
                  )
                else
                  ...jobs.map(
                    (job) {
                      final vehicle = provider.getVehicleById(job.vehicleId);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(14),
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigo.shade100,
                              child: const Icon(Icons.directions_car_outlined),
                            ),
                            title: Text(
                              vehicle == null
                                  ? job.vehicleId
                                  : '${vehicle.year} ${vehicle.make} ${vehicle.model}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                [
                                  if (vehicle?.licensePlate?.isNotEmpty == true) 'Plate: ${vehicle!.licensePlate}',
                                  if ((job.customerId ?? '').isNotEmpty) 'Customer: ${job.customerId}',
                                  if ((job.description ?? '').isNotEmpty) job.description!,
                                  'Status: ${job.status}',
                                  'Total: ${formatCurrency(job.totalCost)}',
                                ].join(' • '),
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => JobCardScreen(jobId: job.id),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyHistory({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.history_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
