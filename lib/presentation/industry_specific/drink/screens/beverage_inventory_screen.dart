import 'package:flutter/material.dart';

class BeverageInventoryScreen extends StatefulWidget {
  const BeverageInventoryScreen({super.key});

  @override
  State<BeverageInventoryScreen> createState() =>
      _BeverageInventoryScreenState();
}

class _BeverageInventoryScreenState extends State<BeverageInventoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beverage Inventory')),
      body: const Center(child: Text('Beverage Inventory Screen')),
    );
  }
}

