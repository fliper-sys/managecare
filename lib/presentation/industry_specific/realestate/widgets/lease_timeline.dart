import 'package:flutter/material.dart';

class LeaseTimeline extends StatelessWidget {
  final DateTime startDate;
  final DateTime? endDate;

  const LeaseTimeline({super.key, required this.startDate, this.endDate});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start: ${startDate.toString().split(' ')[0]}'),
            if (endDate != null)
              Text('End: ${endDate.toString().split(' ')[0]}'),
          ],
        ),
      ),
    );
  }
}

