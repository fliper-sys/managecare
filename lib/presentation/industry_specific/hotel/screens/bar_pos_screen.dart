import 'package:flutter/material.dart';

class BarPosScreen extends StatefulWidget {
  const BarPosScreen({super.key});

  @override
  State<BarPosScreen> createState() => _BarPosScreenState();
}

class _BarPosScreenState extends State<BarPosScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bar POS')),
      body: const Center(child: Text('Bar POS Screen')),
    );
  }
}

