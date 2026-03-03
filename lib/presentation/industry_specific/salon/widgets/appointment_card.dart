import 'package:flutter/material.dart';

class AppointmentCard extends StatelessWidget {
  final String clientName;
  final String service;
  final DateTime appointmentTime;
  final String status;
  final VoidCallback onTap;

  const AppointmentCard({
    super.key,
    required this.clientName,
    required this.service,
    required this.appointmentTime,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(clientName),
        subtitle:
            Text('$service • ${appointmentTime.toString().split('.')[0]}'),
        trailing: Chip(label: Text(status)),
        onTap: onTap,
      ),
    );
  }
}

