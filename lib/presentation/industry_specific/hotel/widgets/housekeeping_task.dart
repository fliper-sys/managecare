import 'package:flutter/material.dart';

class HousekeepingTask extends StatelessWidget {
  final String roomNumber;
  final String taskType;
  final String status;
  final VoidCallback onComplete;

  const HousekeepingTask({
    super.key,
    required this.roomNumber,
    required this.taskType,
    required this.status,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('Room $roomNumber'),
        subtitle: Text(taskType),
        trailing: ElevatedButton(onPressed: onComplete, child: Text(status)),
      ),
    );
  }
}

