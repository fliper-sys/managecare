import 'package:flutter/material.dart';

class BarcodeScannerView extends StatelessWidget {
  const BarcodeScannerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.qr_code_2,
              size: 100,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text('Point camera at barcode'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.camera),
              label: const Text('Start Scanner'),
            ),
          ],
        ),
      ),
    );
  }
}

