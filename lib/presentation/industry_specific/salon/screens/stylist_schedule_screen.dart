import 'package:flutter/material.dart';

class StylistScheduleScreen extends StatefulWidget {
  const StylistScheduleScreen({super.key});

  @override
  State<StylistScheduleScreen> createState() => _StylistScheduleScreenState();
}

class _StylistScheduleScreenState extends State<StylistScheduleScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stylist Schedule')),
      body: const Center(child: Text('Stylist Schedule Screen')),
    );
  }
}

