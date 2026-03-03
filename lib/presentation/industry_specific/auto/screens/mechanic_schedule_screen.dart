import 'package:flutter/material.dart';
import '../../../../core/constants/routes.dart';
import 'create_service_order_screen.dart';


class MechanicScheduleScreen extends StatefulWidget {
  const MechanicScheduleScreen({super.key});

  @override
  State<MechanicScheduleScreen> createState() => _MechanicScheduleScreenState();
}

class _MechanicScheduleScreenState extends State<MechanicScheduleScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mechanic Schedule')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('View mechanics schedule, assign jobs and manage shifts.'),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, Routes.autoJobCards),
                child: const Text('Open Repair Jobs')),
            const SizedBox(height: 8),
            ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateServiceOrderScreen())),
                child: const Text('Create Service Order')),
          ],
        ),
      ),
    );
  }
}

