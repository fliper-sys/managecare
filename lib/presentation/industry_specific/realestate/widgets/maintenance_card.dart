import 'package:flutter/material.dart';

class MaintenanceCard extends StatelessWidget {
  final String ticketId;
  final String description;
  final String status;
  final VoidCallback onTap;

  const MaintenanceCard({
    super.key,
    required this.ticketId,
    required this.description,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('Ticket: $ticketId'),
        subtitle: Text(description),
        trailing: Chip(label: Text(status)),
        onTap: onTap,
      ),
    );
  }
}

