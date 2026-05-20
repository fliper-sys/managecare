import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/gym_provider.dart';

class PlanManagementScreen extends StatelessWidget {
  const PlanManagementScreen({super.key});

  Future<void> _showEditDialog(
    BuildContext context, {
    MembershipPlan? plan,
  }) async {
    final isNew = plan == null;
    final nameCtl = TextEditingController(text: plan?.name ?? '');
    final priceCtl = TextEditingController(
      text: plan != null ? plan.pricePerMonth.toString() : '0.0',
    );
    final durationCtl = TextEditingController(
      text: plan?.durationMonths.toString() ?? '1',
    );
    final featuresCtl = TextEditingController(
      text: plan != null ? plan.features.join(', ') : '',
    );
    bool isActive = plan?.isActive ?? true;

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isNew ? 'Create Plan' : 'Edit Plan'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter name';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: priceCtl,
                  decoration: const InputDecoration(labelText: 'Monthly price'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (double.tryParse(value ?? '') == null) {
                      return 'Enter valid price';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: durationCtl,
                  decoration: const InputDecoration(labelText: 'Duration (months)'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (int.tryParse(value ?? '') == null) {
                      return 'Enter valid duration';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: featuresCtl,
                  decoration: const InputDecoration(
                    labelText: 'Features (comma separated)',
                  ),
                ),
                StatefulBuilder(
                  builder: (context, setDialogState) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (value) => setDialogState(() => isActive = value),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final gymProvider = context.read<GymProvider>();
      final name = nameCtl.text.trim();
      final price = double.tryParse(priceCtl.text.trim()) ?? 0.0;
      final duration = int.tryParse(durationCtl.text.trim()) ?? 1;
      final features = featuresCtl.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

      if (isNew) {
        final newPlan = MembershipPlan(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          pricePerMonth: price,
          durationMonths: duration,
          features: features,
          isActive: isActive,
        );
        await gymProvider.addPlan(newPlan);
      } else {
        final updated = MembershipPlan(
          id: plan.id,
          name: name,
          pricePerMonth: price,
          durationMonths: duration,
          features: features,
          isActive: isActive,
        );
        await gymProvider.updatePlan(updated);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gymProvider = context.watch<GymProvider>();
    final auth = context.watch<AuthProvider>();
    final canManagePlans =
        WorkerPermissions.canManageStaff(auth.currentUser?.role ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Plans'),
        backgroundColor: AppColors.primary,
      ),
      backgroundColor: Colors.grey[50],
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Plan'),
        backgroundColor: AppColors.primary,
        onPressed: canManagePlans ? () => _showEditDialog(context) : null,
      ),
      body: gymProvider.plans.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No plans defined'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: canManagePlans
                        ? () => _showEditDialog(context)
                        : null,
                    child: const Text('Create Plan'),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: gymProvider.plans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final plan = gymProvider.plans[index];
                return Card(
                  child: ListTile(
                    title: Text(plan.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${plan.durationMonths} month(s) - ${formatCurrency(plan.pricePerMonth)}',
                        ),
                        if (plan.features.isNotEmpty)
                          Text(
                            plan.features.join(', '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        if (!plan.isActive)
                          const Text(
                            'Inactive',
                            style: TextStyle(fontSize: 12, color: Colors.red),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: canManagePlans
                              ? () => _showEditDialog(context, plan: plan)
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: !canManagePlans
                              ? null
                              : () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete plan?'),
                                content: Text(
                                  'Delete "${plan.name}"? This action cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              try {
                                await gymProvider.deletePlan(plan.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Deleted ${plan.name}'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to delete: $e'),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
