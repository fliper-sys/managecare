import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../providers/salon_provider.dart';
import 'salon_appointments_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalonProvider>().loadAppointments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SalonProvider>(
      builder: (context, provider, _) {
        var appointments = provider.appointments;
        if (_statusFilter != 'all') {
          appointments =
              appointments.where((item) => item.status == _statusFilter).toList();
        }

        appointments = [...appointments]
          ..sort((a, b) => a.appointmentTime.compareTo(b.appointmentTime));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Appointments'),
            backgroundColor: AppColors.primary,
          ),
          backgroundColor: Colors.grey[50],
          body: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _statusFilter == 'all',
                      onTap: () => setState(() => _statusFilter = 'all'),
                    ),
                    _FilterChip(
                      label: 'Pending',
                      selected: _statusFilter == 'pending',
                      onTap: () => setState(() => _statusFilter = 'pending'),
                    ),
                    _FilterChip(
                      label: 'Confirmed',
                      selected: _statusFilter == 'confirmed',
                      onTap: () => setState(() => _statusFilter = 'confirmed'),
                    ),
                    _FilterChip(
                      label: 'Completed',
                      selected: _statusFilter == 'completed',
                      onTap: () => setState(() => _statusFilter = 'completed'),
                    ),
                    _FilterChip(
                      label: 'Cancelled',
                      selected: _statusFilter == 'cancelled',
                      onTap: () => setState(() => _statusFilter = 'cancelled'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: appointments.isEmpty
                    ? Center(
                        child: Text(
                          'No appointments found',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: appointments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final appointment = appointments[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    _statusColor(appointment.status).withOpacity(0.12),
                                child: Icon(
                                  Icons.event,
                                  color: _statusColor(appointment.status),
                                ),
                              ),
                              title: Text(
                                '${appointment.clientName} - ${appointment.serviceName}',
                              ),
                              subtitle: Text(
                                '${appointment.stylistName}\n${DateFormat('MMM d, yyyy h:mm a').format(appointment.appointmentTime)}',
                              ),
                              isThreeLine: true,
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusColor(appointment.status)
                                          .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      appointment.status.toUpperCase(),
                                      style: TextStyle(
                                        color: _statusColor(appointment.status),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    formatCurrency(appointment.servicePrice),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SalonAppointmentsScreen(),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SalonAppointmentsScreen(),
                ),
              );
            },
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add),
            label: const Text('Manage'),
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'confirmed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
