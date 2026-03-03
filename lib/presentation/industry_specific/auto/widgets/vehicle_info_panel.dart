import 'package:flutter/material.dart';

class VehicleInfoPanel extends StatelessWidget {
  final String make;
  final String model;
  final String licensePlate;

  const VehicleInfoPanel({
    super.key,
    required this.make,
    required this.model,
    required this.licensePlate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$make $model'),
            Text('Plate: $licensePlate'),
          ],
        ),
      ),
    );
  }
}

