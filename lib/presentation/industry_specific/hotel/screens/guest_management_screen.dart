import 'package:flutter/material.dart';

class GuestManagementScreen extends StatefulWidget {
  const GuestManagementScreen({super.key});

  @override
  State<GuestManagementScreen> createState() => _GuestManagementScreenState();
}

class _GuestManagementScreenState extends State<GuestManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guest Management')),
      body: const Center(child: Text('Guest Management Screen')),
    );
  }
}

