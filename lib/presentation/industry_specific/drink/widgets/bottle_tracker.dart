import 'package:flutter/material.dart';

class BottleTracker extends StatelessWidget {
  final String bottleId;
  final String status;
  final DateTime dateOpened;

  const BottleTracker(
      {super.key,
      required this.bottleId,
      required this.status,
      required this.dateOpened});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('Bottle: $bottleId'),
        subtitle: Text('Status: $status'),
        trailing: Text(dateOpened.toString().split(' ')[0]),
      ),
    );
  }
}

