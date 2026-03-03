import 'package:flutter/material.dart';
import '../../../../core/constants/routes.dart';
import 'create_service_order_screen.dart';

class ServiceOrdersScreen extends StatefulWidget {
  const ServiceOrdersScreen({super.key});

  @override
  State<ServiceOrdersScreen> createState() => _ServiceOrdersScreenState();
}

class _ServiceOrdersScreenState extends State<ServiceOrdersScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service Orders')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Manage service orders and create new work orders.'),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateServiceOrderScreen())),
                child: const Text('Create Service Order')),
            const SizedBox(height: 8),
            ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, Routes.autoServiceOrders),
                child: const Text('View Repair Jobs')),
            const SizedBox(height: 8),
            ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, Routes.autoBookings),
                child: const Text('View Bookings')),
            const SizedBox(height: 8),
            ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, Routes.autoInvoices),
                child: const Text('View Invoices')),
          ],
        ),
      ),
    );
  }
}

