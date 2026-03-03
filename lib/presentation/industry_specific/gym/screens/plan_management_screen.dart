import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/gym_provider.dart';

class PlanManagementScreen extends StatelessWidget {
  const PlanManagementScreen({super.key});

  Future<void> _showEditDialog(BuildContext context, {MembershipPlan? plan}) async {
    final isNew = plan == null;
    final nameCtl = TextEditingController(text: plan?.name ?? '');
    final priceCtl = TextEditingController(text: plan != null ? plan.pricePerMonth.toString() : '0.0');
    final durationCtl = TextEditingController(text: plan?.durationMonths.toString() ?? '1');
    final featuresCtl = TextEditingController(text: plan != null ? plan.features.join(', ') : '');
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
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
                ),
                TextFormField(
                  controller: priceCtl,
                  decoration: const InputDecoration(labelText: 'Monthly price'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => double.tryParse(v ?? '') == null ? 'Enter valid price' : null,
                ),
                TextFormField(
                  controller: durationCtl,
                  decoration: const InputDecoration(labelText: 'Duration (months)'),
                  keyboardType: TextInputType.number,
                  validator: (v) => int.tryParse(v ?? '') == null ? 'Enter valid duration' : null,
                ),
                TextFormField(
                  controller: featuresCtl,
                  decoration: const InputDecoration(labelText: 'Features (comma separated)'),
                  keyboardType: TextInputType.text,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (v) => isActive = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) Navigator.pop(ctx, true);
                },
                child: const Text('Save'))
          ],
        );
      },
    );

    if (result == true) {
      final gp = context.read<GymProvider>();
      final name = nameCtl.text.trim();
      final price = double.tryParse(priceCtl.text.trim()) ?? 0.0;
      final dur = int.tryParse(durationCtl.text.trim()) ?? 1;
      final features = featuresCtl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (isNew) {
        final newPlan = MembershipPlan(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, pricePerMonth: price, durationMonths: dur, features: features, isActive: isActive);
        await gp.addPlan(newPlan);
      } else {
        final pid = plan.id;
        final updated = MembershipPlan(id: pid, name: name, pricePerMonth: price, durationMonths: dur, features: features, isActive: isActive);
        await gp.updatePlan(updated);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GymProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Plans')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showEditDialog(context),
      ),
      body: gp.plans.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('No plans defined'), const SizedBox(height: 8), ElevatedButton(onPressed: () => _showEditDialog(context), child: const Text('Create Plan'))]))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: gp.plans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final p = gp.plans[index];
                return Card(
                  child: ListTile(
                    title: Text(p.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${p.durationMonths} month(s) • \$${p.pricePerMonth.toStringAsFixed(2)}'),
                        if (p.features.isNotEmpty) Text('${p.features.join(', ')}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        if (!p.isActive) Text('Inactive', style: const TextStyle(fontSize: 12, color: Colors.red)),
                      ],
                    ),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => _showEditDialog(context, plan: p)),
                      IconButton(icon: const Icon(Icons.delete), onPressed: () async {
                        final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete plan?'), content: Text('Delete "${p.name}"? This action cannot be undone.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))]));
                        if (ok == true) {
                          try {
                            await gp.deletePlan(p.id);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted ${p.name}')));
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
                          }
                        }
                      })
                    ]),
                  ),
                );
              },
            ),
    );
  }
}