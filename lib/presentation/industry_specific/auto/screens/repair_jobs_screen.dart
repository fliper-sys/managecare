import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/auto_provider.dart';
import 'job_card_screen.dart';

class RepairJobsScreen extends StatefulWidget {
  const RepairJobsScreen({super.key});

  @override
  State<RepairJobsScreen> createState() => _RepairJobsScreenState();
}

class _RepairJobsScreenState extends State<RepairJobsScreen> {
  String _filterStatus = 'all'; // all, pending, in-progress, completed

  @override
  Widget build(BuildContext context) {
    return Consumer<AutoProvider>(builder: (context, provider, _) {
      if (provider.isLoadingData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (provider.dataError != null) return Scaffold(body: Center(child: Text(provider.dataError!)));

      final jobs = _filterStatus == 'all'
          ? provider.jobs
          : provider.jobs.where((j) => j.status == _filterStatus).toList();

      return Scaffold(
        appBar: AppBar(
            title: const Text('Repair Jobs'), backgroundColor: AppColors.primary),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['all', 'pending', 'in-progress', 'completed']
                      .map((status) => Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              label:
                                  Text(status.replaceAll('_', ' ').toUpperCase()),
                              selected: _filterStatus == status,
                              onSelected: (selected) =>
                                  setState(() => _filterStatus = status),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
            Expanded(
              child: jobs.isEmpty
                  ? const Center(child: Text('No jobs'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: jobs.length,
                      itemBuilder: (context, index) {
                        final job = jobs[index];
                        final vehicle = provider.getVehicleById(job.vehicleId);
                        return Card(
                          child: ListTile(
                            leading: Icon(Icons.build_circle,
                                color: _statusColor(job.status)),
                            title: Text('Job #${job.id}'),
                            subtitle: Text(
                                '${vehicle?.make ?? "Unknown"} ${vehicle?.model ?? ""} - ${job.status}'),
                            trailing: Text(formatCurrency(job.totalCost)),
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => JobCardScreen(jobId: job.id)));
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.grey;
      case 'in-progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'invoiced':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }
}

