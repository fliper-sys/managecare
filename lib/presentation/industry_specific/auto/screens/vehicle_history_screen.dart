import 'package:flutter/material.dart';
import '../../../../core/constants/routes.dart';

class VehicleHistoryScreen extends StatefulWidget {
  const VehicleHistoryScreen({super.key});

  @override
  State<VehicleHistoryScreen> createState() => _VehicleHistoryScreenState();
}

class _VehicleHistoryScreenState extends State<VehicleHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle History')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Search past jobs and service history for a vehicle.'),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search by plate or VIN',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) {
                // placeholder: in future wire to provider/search
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Searching for: $v')));
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, Routes.autoServiceOrders),
                child: const Text('View All Repair Jobs')),
          ],
        ),
      ),
    );
  }
}

