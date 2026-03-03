import 'package:flutter/material.dart';

class RestaurantPosScreen extends StatefulWidget {
  const RestaurantPosScreen({super.key});

  @override
  State<RestaurantPosScreen> createState() => _RestaurantPosScreenState();
}

class _RestaurantPosScreenState extends State<RestaurantPosScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant POS')),
      body: const Center(child: Text('Restaurant POS Screen')),
    );
  }
}

