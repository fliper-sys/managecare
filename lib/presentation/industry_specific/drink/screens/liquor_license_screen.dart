import 'package:flutter/material.dart';

class LiquorLicenseScreen extends StatefulWidget {
  const LiquorLicenseScreen({super.key});

  @override
  State<LiquorLicenseScreen> createState() => _LiquorLicenseScreenState();
}

class _LiquorLicenseScreenState extends State<LiquorLicenseScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Liquor License')),
      body: const Center(child: Text('Liquor License Screen')),
    );
  }
}

