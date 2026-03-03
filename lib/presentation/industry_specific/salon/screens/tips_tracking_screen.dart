import 'package:flutter/material.dart';

class TipsTrackingScreen extends StatefulWidget {
  const TipsTrackingScreen({super.key});

  @override
  State<TipsTrackingScreen> createState() => _TipsTrackingScreenState();
}

class _TipsTrackingScreenState extends State<TipsTrackingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tips Tracking')),
      body: const Center(child: Text('Tips Tracking Screen')),
    );
  }
}

