import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/auto_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../services/thermal_printing_service.dart';

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
              const SizedBox(height: 4),
              Text('Commission: ${job.commissionStatus}'),
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
                          : () async {
                              final ok = await auto.updateJobStatus(job.id, 'completed');
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Marked completed' : 'Failed to update')));
                            },
                      child: const Text('Mark Completed')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                      onPressed: job.status == 'invoiced'
                          ? null
                          : () async {
                              final ok = await auto.updateJobStatus(job.id, 'invoiced');
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Marked invoiced' : 'Failed to update')));
                            },
                      child: const Text('Mark Invoiced')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _printReceipt(context, job),
                    child: const Text('Print Receipt'),
                  ),
                ],
              )
            ],
          ),
        ),
      );
    });
  }

  Future<void> _printReceipt(BuildContext context, Job job) async {
    final businessName = context.read<BusinessProvider>().currentBusiness?.name ?? 'Workshop';
    final receipt = StringBuffer()
      ..writeln(businessName)
      ..writeln('JOB RECEIPT')
      ..writeln('Job: ${job.id}')
      ..writeln('Vehicle: ${job.vehicleId}')
      ..writeln('Status: ${job.status}')
      ..writeln('Commission: ${job.commissionStatus}')
      ..writeln('Subtotal: ${formatCurrency(job.totalCost - job.workmanshipAmount)}')
      ..writeln('Workmanship: ${formatCurrency(job.workmanshipAmount)}')
      ..writeln('Total: ${formatCurrency(job.totalCost)}');

    final ok = await ThermalPrintingService().printTextReceipt(
      receiptText: receipt.toString(),
      businessName: businessName,
      paperWidth: 80,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Receipt sent to printer' : 'Printing failed')),
    );
  }
}

