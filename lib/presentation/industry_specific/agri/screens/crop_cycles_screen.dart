import 'package:flutter/material.dart';

class CropCyclesScreen extends StatefulWidget {
  const CropCyclesScreen({super.key});

  @override
  State<CropCyclesScreen> createState() => _CropCyclesScreenState();
}

class _CropCyclesScreenState extends State<CropCyclesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crop Cycles')),
      body: const Center(child: Text('Crop Cycles Screen')),
    );
  }
}

