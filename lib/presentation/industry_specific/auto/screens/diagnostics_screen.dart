import 'package:flutter/material.dart';
import '../../../../core/constants/routes.dart';
import 'create_service_order_screen.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Run vehicle diagnostics, attach findings and create follow-up jobs.'),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateServiceOrderScreen())),
                child: const Text('Create Follow-up Service Order')),
            const SizedBox(height: 8),
            ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, Routes.autoPartsInventory),
                child: const Text('Open Parts Inventory')),
          ],
        ),
      ),
    );
  }
}

