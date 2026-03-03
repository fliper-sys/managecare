import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../providers/salon_provider.dart';
import 'package:intl/intl.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SalonProvider>(context);
    final upcoming = provider.getUpcomingAppointments().take(50).toList();

    return Scaffold(
      appBar: AppBar(
          title: const Text('Appointments'),
          backgroundColor: AppColors.primary),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: upcoming.length,
        itemBuilder: (context, index) {
          final a = upcoming[index];
          final customerName = a.clientName;
          final stylistName = a.stylistName;
          final serviceName = a.serviceName;
          return Card(
            child: ListTile(
              leading: const Icon(Icons.event),
              title: Text('$customerName • $serviceName with $stylistName'),
              subtitle:
                  Text(DateFormat('MMM d, yyyy HH:mm').format(a.appointmentTime)),
              trailing: Text('\₦${a.servicePrice.toStringAsFixed(2)}'),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: show new appointment form
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

