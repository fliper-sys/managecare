import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../providers/salon_provider.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final _nameCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _commissionCtrl = TextEditingController(text: '10');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalonProvider>().loadStylists();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _emailCtrl.dispose();
    _commissionCtrl.dispose();
    super.dispose();
  }

  void _resetForm() {
    _nameCtrl.clear();
    _roleCtrl.clear();
    _emailCtrl.clear();
    _commissionCtrl.text = '10';
  }

  void _showAddStaffDialog(SalonProvider provider) {
    _resetForm();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Stylist'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: _roleCtrl,
                decoration: const InputDecoration(labelText: 'Specialization'),
              ),
              TextField(
                controller: _commissionCtrl,
                decoration: const InputDecoration(labelText: 'Commission %'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final stylist = Stylist(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: _nameCtrl.text.trim(),
                email: _emailCtrl.text.trim(),
                phone: null,
                specialization: _roleCtrl.text.trim(),
                serviceIds: const [],
                commissionPercentage: double.tryParse(_commissionCtrl.text) ?? 0.0,
                isActive: true,
                createdAt: DateTime.now(),
              );
              if (stylist.name.isEmpty || stylist.specialization.isEmpty) return;
              provider.addStylist(stylist);
              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditCommissionDialog(SalonProvider provider, Stylist stylist) {
    final ctrl = TextEditingController(
      text: (stylist.commissionPercentage ?? 0.0).toStringAsFixed(0),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Commission'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Commission %'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final updated = stylist.copyWith(
                commissionPercentage:
                    double.tryParse(ctrl.text) ?? stylist.commissionPercentage,
              );
              provider.updateStylist(updated);
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SalonProvider>(
      builder: (context, provider, _) {
        final staff = provider.stylists;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Staff Management'),
            backgroundColor: AppColors.primary,
          ),
          backgroundColor: Colors.grey[50],
          body: staff.isEmpty
              ? Center(
                  child: Text(
                    'No stylists found',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: staff.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final stylist = staff[index];
                    final earned = provider.getStylistCommissionTotal(stylist.id);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.12),
                          child: Text(
                            stylist.name.isNotEmpty ? stylist.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(stylist.name),
                        subtitle: Text(
                          '${stylist.specialization}\nCommission ${((stylist.commissionPercentage ?? 0.0)).toStringAsFixed(1)}%',
                        ),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatCurrency(earned),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEditCommissionDialog(provider, stylist),
                            ),
                          ],
                        ),
                        onTap: () {
                          showModalBottomSheet<void>(
                            context: context,
                            builder: (ctx) => Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stylist.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Email: ${stylist.email.isEmpty ? 'Not set' : stylist.email}'),
                                  const SizedBox(height: 8),
                                  Text('Specialization: ${stylist.specialization}'),
                                  const SizedBox(height: 8),
                                  Text('Commission: ${((stylist.commissionPercentage ?? 0.0)).toStringAsFixed(1)}%'),
                                  const SizedBox(height: 8),
                                  Text('Earned: ${formatCurrency(earned)}'),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.of(ctx).pop(),
                                      child: const Text('Close'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddStaffDialog(provider),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.person_add),
            label: const Text('Add Stylist'),
          ),
        );
      },
    );
  }
}
