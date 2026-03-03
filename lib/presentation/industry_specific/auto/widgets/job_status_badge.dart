import 'package:flutter/material.dart';

class JobStatusBadge extends StatelessWidget {
  final String status;

  const JobStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status),
      backgroundColor: _getStatusColor(),
    );
  }

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in-progress':
        return Colors.orange;
      case 'pending':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }
}

