import 'package:flutter/material.dart';

class PrescriptionCard extends StatelessWidget {
  final String id;
  final String patientName;
  final String? prescriber;
  final String? status;
  final DateTime date;
  final VoidCallback? onTap;

  const PrescriptionCard({
    super.key,
    required this.id,
    required this.patientName,
    this.prescriber,
    this.status,
    required this.date,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = (prescriber != null && prescriber!.isNotEmpty)
        ? 'Prescribed by $prescriber • ${date.toIso8601String().split('T')[0]}'
        : (status != null && status!.isNotEmpty)
            ? 'Status: $status • ${date.toIso8601String().split('T')[0]}'
            : date.toIso8601String().split('T')[0];

    return Card(
      child: ListTile(
        title: Text('Prescription for $patientName'),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

