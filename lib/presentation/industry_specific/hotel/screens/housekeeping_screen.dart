import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/hotel_provider.dart';
import '../widgets/housekeeping_task.dart';

class HousekeepingScreen extends StatefulWidget {
  const HousekeepingScreen({super.key});

  @override
  State<HousekeepingScreen> createState() => _HousekeepingScreenState();
}

class _HousekeepingScreenState extends State<HousekeepingScreen> {
  String _selectedStatus = 'pending';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.currentUser?.role ?? '';
    final canManageHousekeeping =
        WorkerPermissions.canManageHousekeeping(role);

    return Consumer<HotelProvider>(
      builder: (context, provider, _) {
        final tasks = provider.serviceOrders.where((order) {
          final isHousekeepingType = order.serviceName == 'housekeeping' ||
              order.serviceName == 'laundry' ||
              order.serviceName == 'maintenance';
          if (!isHousekeepingType) return false;
          if (_selectedStatus == 'all') return true;
          return order.status == _selectedStatus;
        }).toList()
          ..sort((a, b) => a.requestedAt.compareTo(b.requestedAt));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Housekeeping'),
            backgroundColor: AppColors.primary,
          ),
          backgroundColor: Colors.grey[50],
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            onPressed: canManageHousekeeping
                ? () => _showNewTaskDialog(context, provider)
                : null,
            icon: const Icon(Icons.cleaning_services_outlined),
            label: const Text('Assign Task'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusFilter(
                    label: 'Pending',
                    selected: _selectedStatus == 'pending',
                    onTap: () => setState(() => _selectedStatus = 'pending'),
                  ),
                  _StatusFilter(
                    label: 'In Progress',
                    selected: _selectedStatus == 'in-progress',
                    onTap: () => setState(() => _selectedStatus = 'in-progress'),
                  ),
                  _StatusFilter(
                    label: 'Completed',
                    selected: _selectedStatus == 'completed',
                    onTap: () => setState(() => _selectedStatus = 'completed'),
                  ),
                  _StatusFilter(
                    label: 'All',
                    selected: _selectedStatus == 'all',
                    onTap: () => setState(() => _selectedStatus = 'all'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (tasks.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.24),
                    ),
                  ),
                  child: Text(
                    'No housekeeping tasks for this filter.',
                    style: TextStyle(
                      color:
                          Theme.of(context).colorScheme.onSurface.withOpacity(0.68),
                    ),
                  ),
                )
              else
                ...tasks.map((task) {
                  final room = provider.getRoomById(task.roomId);
                  return Column(
                    children: [
                      HousekeepingTask(
                        roomNumber: room?.number ?? task.roomId,
                        taskType: '${task.serviceName} • ${task.priority}',
                        status: task.status,
                        onComplete: canManageHousekeeping
                            ? () {
                                final nextStatus = task.status == 'pending'
                                    ? 'in-progress'
                                    : 'completed';
                                provider.updateServiceOrderStatus(
                                  task.id,
                                  nextStatus,
                                );
                              }
                            : null,
                      ),
                      Card(
                        margin: const EdgeInsets.only(top: 8, bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.description,
                                style: TextStyle(color: Colors.grey[800]),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(task.status.toUpperCase()),
                                    backgroundColor: task.status == 'completed'
                                        ? const Color(0xFFE4F4E8)
                                        : task.status == 'in-progress'
                                            ? const Color(0xFFE8F0FF)
                                            : const Color(0xFFFFF3E8),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: task.status == 'completed' ||
                                            !canManageHousekeeping
                                        ? null
                                        : () {
                                            provider.updateServiceOrderStatus(
                                              task.id,
                                              'completed',
                                            );
                                          },
                                    child: const Text('Mark Complete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showNewTaskDialog(
    BuildContext context,
    HotelProvider provider,
  ) async {
    String? roomId = provider.rooms.isNotEmpty ? provider.rooms.first.id : null;
    String serviceName = 'housekeeping';
    String priority = 'medium';
    final descriptionController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Assign Housekeeping Task'),
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
                      onChanged: (value) => setDialogState(() => roomId = value),
                      decoration: const InputDecoration(labelText: 'Room'),
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
                          value: 'maintenance',
                          child: Text('Maintenance'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => serviceName = value);
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Task Type'),
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
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => priority = value);
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Priority'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe the housekeeping request',
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
                  child: const Text('Create Task'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatusFilter extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
