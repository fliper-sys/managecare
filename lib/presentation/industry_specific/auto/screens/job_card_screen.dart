import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/auto_provider.dart';

class JobCardScreen extends StatelessWidget {
  final String jobId;
  const JobCardScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context) {
    return Consumer<AutoProvider>(builder: (context, auto, _) {
      if (auto.isLoadingData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (auto.dataError != null) return Scaffold(body: Center(child: Text(auto.dataError!)));

      final job = auto.jobs.firstWhere((j) => j.id == jobId, orElse: () => Job(id: jobId, vehicleId: '', createdAt: DateTime.now()));

      if (auto.jobs.every((j) => j.id != jobId)) {
        return Scaffold(
          appBar: AppBar(title: Text('Job $jobId')),
          body: const Center(child: Text('Job not found')),
        );
      }

      return Scaffold(
        appBar: AppBar(title: Text('Job ${job.id}')),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vehicle: ${job.vehicleId}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Status: ${job.status}'),
              const SizedBox(height: 8),
              const Text('Services', style: TextStyle(fontWeight: FontWeight.bold)),
              ...job.tasks.map((t) => ListTile(title: Text(t.name), subtitle: Text('Cost: ${formatCurrency(t.laborCost)}'))),
              const SizedBox(height: 8),
              const Text('Parts', style: TextStyle(fontWeight: FontWeight.bold)),
              ...job.usedParts.map((p) => ListTile(title: Text(p.name), subtitle: Text('Qty: ${p.quantity}  Cost/unit: ${formatCurrency(p.cost)}'))),
              const Spacer(),
              Row(
                children: [
                  ElevatedButton(
                      onPressed: job.status == 'completed'
                          ? null
                          : () {
                              final ok = auto.updateJobStatus(job.id, 'completed');
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Marked completed' : 'Failed to update')));
                            },
                      child: const Text('Mark Completed')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                      onPressed: job.status == 'invoiced'
                          ? null
                          : () {
                              final ok = auto.updateJobStatus(job.id, 'invoiced');
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Marked invoiced' : 'Failed to update')));
                            },
                      child: const Text('Mark Invoiced'))
                ],
              )
            ],
          ),
        ),
      );
    });
  }
}

