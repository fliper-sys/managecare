import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/gym_provider.dart';

class EquipmentManagementScreen extends StatefulWidget {
  const EquipmentManagementScreen({super.key});

  @override
  State<EquipmentManagementScreen> createState() => _EquipmentManagementScreenState();
}

class _EquipmentManagementScreenState extends State<EquipmentManagementScreen> {
  String _selectedCategory = 'All';
  String _selectedStatus = 'All';

  final List<String> _categories = ['All', 'Cardio', 'Strength', 'Free Weights', 'Machines', 'Accessories'];
  final List<String> _statuses = ['All', 'available', 'in-use', 'maintenance', 'out-of-order'];

  @override
  Widget build(BuildContext context) {
    return Consumer<GymProvider>(
      builder: (context, provider, _) {
        final auth = context.watch<AuthProvider>();
        final role = auth.currentUser?.role ?? '';
        final canManageEquipment = auth.isOwnerUser ||
            WorkerPermissions.canManageGymBookings(role) ||
            WorkerPermissions.canManageStaff(role);
        final filteredEquipment = provider.equipment.where((eq) {
          final categoryMatch = _selectedCategory == 'All' || eq.category == _selectedCategory;
          final statusMatch = _selectedStatus == 'All' || eq.status == _selectedStatus;
          return categoryMatch && statusMatch;
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Equipment Management'),
            backgroundColor: AppColors.primary,
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () => _showFilters(context),
              ),
            ],
          ),
          body: Column(
            children: [
              // Status summary
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[100],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatusSummary(
                      label: 'Available',
                      count: provider.equipment.where((e) => e.status == 'available').length,
                      color: Colors.green,
                    ),
                    _StatusSummary(
                      label: 'In Use',
                      count: provider.equipment.where((e) => e.status == 'in-use').length,
                      color: Colors.blue,
                    ),
                    _StatusSummary(
                      label: 'Maintenance',
                      count: provider.equipment.where((e) => e.status == 'maintenance').length,
                      color: Colors.orange,
                    ),
                    _StatusSummary(
                      label: 'Out of Order',
                      count: provider.equipment.where((e) => e.status == 'out-of-order').length,
                      color: Colors.red,
                    ),
                  ],
                ),
              ),

              // Equipment list
              Expanded(
                child: filteredEquipment.isEmpty
                    ? const Center(child: Text('No equipment found'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredEquipment.length,
                        itemBuilder: (context, index) {
                          final equipment = filteredEquipment[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(equipment.status),
                                child: Icon(
                                  _getStatusIcon(equipment.status),
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(equipment.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Category: ${equipment.category}'),
                                  if (equipment.nextMaintenance != null)
                                    Text(
                                      'Next Maintenance: ${_formatDate(equipment.nextMaintenance!)}',
                                      style: TextStyle(
                                        color: _isMaintenanceDue(equipment.nextMaintenance!)
                                            ? Colors.red
                                            : Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                enabled: canManageEquipment,
                                onSelected: (action) => _handleEquipmentAction(context, provider, equipment, action),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  const PopupMenuItem(value: 'maintenance', child: Text('Schedule Maintenance')),
                                  const PopupMenuItem(value: 'status', child: Text('Change Status')),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              ),
                              onTap: () => _showEquipmentDetails(context, equipment),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: canManageEquipment
                ? () => _showAddEquipmentDialog(context, provider)
                : null,
            icon: const Icon(Icons.add),
            label: const Text('Add Equipment'),
          ),
        );
      },
    );
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Category: '),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                      onChanged: (value) {
                        setState(() => _selectedCategory = value!);
                        this.setState(() {});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Status: '),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedStatus,
                      items: _statuses.map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
                      onChanged: (value) {
                        setState(() => _selectedStatus = value!);
                        this.setState(() {});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = 'All';
                        _selectedStatus = 'All';
                      });
                      this.setState(() {});
                    },
                    child: const Text('Reset'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddEquipmentDialog(BuildContext context, GymProvider provider) {
    final nameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String selectedCategory = _categories[1]; // Default to first category
    String selectedStatus = 'available';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Equipment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Equipment Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories.skip(1).map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                  onChanged: (value) => setState(() => selectedCategory = value!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _statuses.skip(1).map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
                  onChanged: (value) => setState(() => selectedStatus = value!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;

                final equipment = Equipment(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text.trim(),
                  category: selectedCategory,
                  status: selectedStatus,
                  notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                );

                provider.addEquipment(equipment);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Equipment added successfully')),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEquipmentDetails(BuildContext context, Equipment equipment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(equipment.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: ${equipment.category}'),
            Text('Status: ${equipment.status}'),
            if (equipment.lastMaintenance != null)
              Text('Last Maintenance: ${_formatDate(equipment.lastMaintenance!)}'),
            if (equipment.nextMaintenance != null)
              Text('Next Maintenance: ${_formatDate(equipment.nextMaintenance!)}'),
            if (equipment.notes != null && equipment.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(equipment.notes!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handleEquipmentAction(BuildContext context, GymProvider provider, Equipment equipment, String action) {
    switch (action) {
      case 'edit':
        _showEditEquipmentDialog(context, provider, equipment);
        break;
      case 'maintenance':
        _scheduleMaintenance(context, provider, equipment);
        break;
      case 'status':
        _changeEquipmentStatus(context, provider, equipment);
        break;
      case 'delete':
        _confirmDeleteEquipment(context, provider, equipment);
        break;
    }
  }

  void _showEditEquipmentDialog(BuildContext context, GymProvider provider, Equipment equipment) {
    final nameCtrl = TextEditingController(text: equipment.name);
    final notesCtrl = TextEditingController(text: equipment.notes ?? '');
    String selectedCategory = equipment.category;
    String selectedStatus = equipment.status;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Equipment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Equipment Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories.skip(1).map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                  onChanged: (value) => setState(() => selectedCategory = value!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _statuses.skip(1).map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
                  onChanged: (value) => setState(() => selectedStatus = value!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;

                final updatedEquipment = equipment.copyWith(
                  name: nameCtrl.text.trim(),
                  category: selectedCategory,
                  status: selectedStatus,
                  notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                );

                provider.updateEquipment(updatedEquipment);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Equipment updated successfully')),
                );
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleMaintenance(BuildContext context, GymProvider provider, Equipment equipment) {
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Schedule Maintenance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select next maintenance date:'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: equipment.nextMaintenance ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => selectedDate = date);
                  }
                },
                child: Text(selectedDate != null ? _formatDate(selectedDate!) : 'Select Date'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedDate != null) {
                  final updatedEquipment = equipment.copyWith(
                    lastMaintenance: DateTime.now(),
                    nextMaintenance: selectedDate,
                  );
                  provider.updateEquipment(updatedEquipment);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Maintenance scheduled successfully')),
                  );
                }
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  void _changeEquipmentStatus(BuildContext context, GymProvider provider, Equipment equipment) {
    String selectedStatus = equipment.status;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Equipment Status'),
          content: DropdownButtonFormField<String>(
            value: selectedStatus,
            decoration: const InputDecoration(labelText: 'Status'),
            items: _statuses.skip(1).map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
            onChanged: (value) => setState(() => selectedStatus = value!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedStatus != equipment.status) {
                  final updatedEquipment = equipment.copyWith(status: selectedStatus);
                  provider.updateEquipment(updatedEquipment);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Status changed to $selectedStatus')),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteEquipment(BuildContext context, GymProvider provider, Equipment equipment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Equipment'),
        content: Text('Are you sure you want to delete "${equipment.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteEquipment(equipment.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Equipment deleted successfully')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available': return Colors.green;
      case 'in-use': return Colors.blue;
      case 'maintenance': return Colors.orange;
      case 'out-of-order': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'available': return Icons.check_circle;
      case 'in-use': return Icons.access_time;
      case 'maintenance': return Icons.build;
      case 'out-of-order': return Icons.error;
      default: return Icons.help;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isMaintenanceDue(DateTime nextMaintenance) {
    return nextMaintenance.isBefore(DateTime.now().add(const Duration(days: 7)));
  }
}

class _StatusSummary extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusSummary({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
