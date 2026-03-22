import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../providers/hotel_provider.dart';

class HotelServicesScreen extends StatefulWidget {
  const HotelServicesScreen({super.key});

  @override
  State<HotelServicesScreen> createState() => _HotelServicesScreenState();
}

class _HotelServicesScreenState extends State<HotelServicesScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    return Consumer<HotelProvider>(
      builder: (context, provider, _) {
        var orders = provider.serviceOrders;
        if (_filter != 'all') {
          orders = orders.where((order) => order.status == _filter).toList();
        }
        orders = [...orders]
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

        final counts = provider.serviceStatusCounts;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Hotel Services'),
            backgroundColor: AppColors.primary,
          ),
          backgroundColor: Colors.grey[50],
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            onPressed: () => _showCreateServiceDialog(context, provider),
            icon: const Icon(Icons.add),
            label: const Text('New Request'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MetricChip(
                      title: 'Pending',
                      value: counts['pending'] ?? 0,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricChip(
                      title: 'In Progress',
                      value: counts['in-progress'] ?? 0,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricChip(
                      title: 'Completed',
                      value: counts['completed'] ?? 0,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all'),
                    ),
                    _FilterChip(
                      label: 'Pending',
                      selected: _filter == 'pending',
                      onTap: () => setState(() => _filter = 'pending'),
                    ),
                    _FilterChip(
                      label: 'In Progress',
                      selected: _filter == 'in-progress',
                      onTap: () => setState(() => _filter = 'in-progress'),
                    ),
                    _FilterChip(
                      label: 'Completed',
                      selected: _filter == 'completed',
                      onTap: () => setState(() => _filter = 'completed'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (orders.isEmpty)
                const _EmptyState(
                  message: 'No service requests match this filter.',
                )
              else
                ...orders.map((order) {
                  final room = provider.getRoomById(order.roomId);
                  final estimated = provider.estimateServiceCharge(
                    order.serviceName,
                    priority: order.priority,
                  );
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${order.serviceName} • Room ${room?.number ?? order.roomId}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              _StatusBadge(status: order.status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(order.description),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                label: Text('Priority: ${order.priority}'),
                                backgroundColor: Colors.grey[100],
                              ),
                              Chip(
                                label: Text(
                                  'Est. Charge: ₦${estimated.toStringAsFixed(0)}',
                                ),
                                backgroundColor: const Color(0xFFEAF7EC),
                              ),
                              Chip(
                                label: Text(
                                  DateFormat('MMM d, h:mm a').format(order.requestedAt),
                                ),
                                backgroundColor: const Color(0xFFF4F6FA),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (order.status == 'pending')
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      provider.updateServiceOrderStatus(
                                        order.id,
                                        'in-progress',
                                      );
                                    },
                                    child: const Text('Start'),
                                  ),
                                ),
                              if (order.status == 'pending') const SizedBox(width: 10),
                              if (order.status != 'completed')
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      provider.updateServiceOrderStatus(
                                        order.id,
                                        'completed',
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                    child: const Text('Complete'),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCreateServiceDialog(
    BuildContext context,
    HotelProvider provider,
  ) async {
    final descriptionController = TextEditingController();
    String? roomId = provider.rooms.isNotEmpty ? provider.rooms.first.id : null;
    String serviceName = 'housekeeping';
    String priority = 'medium';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Create Service Request'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: roomId,
                      items: provider.rooms
                          .map(
                            (room) => DropdownMenuItem(
                              value: room.id,
                              child: Text('Room ${room.number}'),
                            ),
                          )
                          .toList(),
                      decoration: const InputDecoration(labelText: 'Room'),
                      onChanged: (value) => setDialogState(() => roomId = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: serviceName,
                      items: const [
                        DropdownMenuItem(
                          value: 'housekeeping',
                          child: Text('Housekeeping'),
                        ),
                        DropdownMenuItem(
                          value: 'laundry',
                          child: Text('Laundry'),
                        ),
                        DropdownMenuItem(
                          value: 'room service',
                          child: Text('Room Service'),
                        ),
                        DropdownMenuItem(
                          value: 'maintenance',
                          child: Text('Maintenance'),
                        ),
                        DropdownMenuItem(
                          value: 'spa & wellness',
                          child: Text('Spa & Wellness'),
                        ),
                      ],
                      decoration: const InputDecoration(labelText: 'Service'),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => serviceName = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: priority,
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                      ],
                      decoration: const InputDecoration(labelText: 'Priority'),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => priority = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe what the guest needs',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: roomId == null
                      ? null
                      : () {
                          provider.createServiceOrder(
                            roomId: roomId!,
                            serviceName: serviceName,
                            description: descriptionController.text.trim().isEmpty
                                ? 'No description provided'
                                : descriptionController.text.trim(),
                            priority: priority,
                          );
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String title;
  final int value;
  final Color color;

  const _MetricChip({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
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

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'completed':
        color = Colors.green;
        break;
      case 'in-progress':
        color = Colors.blue;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    return Chip(
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      backgroundColor: color,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: TextStyle(color: Colors.grey[600])),
    );
  }
}
