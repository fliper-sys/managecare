import 'package:flutter/material.dart';

class BarTabsScreen extends StatefulWidget {
  const BarTabsScreen({super.key});

  @override
  State<BarTabsScreen> createState() => _BarTabsScreenState();
}

class _BarTabsScreenState extends State<BarTabsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bar Tabs')),
      body: const Center(child: Text('Bar Tabs Screen')),
    );
  }
}

