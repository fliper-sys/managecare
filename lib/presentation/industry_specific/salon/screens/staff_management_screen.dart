import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/salon_provider.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final _nameCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _commissionCtrl = TextEditingController(text: '10.0');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _commissionCtrl.dispose();
    super.dispose();
  }

  void _showAddStaffDialog(SalonProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Stylist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: _roleCtrl,
                decoration: const InputDecoration(labelText: 'Specialization')),
            TextField(
                controller: _commissionCtrl,
                decoration: const InputDecoration(labelText: 'Commission %'),
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final id = DateTime.now().millisecondsSinceEpoch.toString();
              final name = _nameCtrl.text.trim();
              final specialization = _roleCtrl.text.trim();
              final commission = double.tryParse(_commissionCtrl.text) ?? 0.0;
              if (name.isEmpty || specialization.isEmpty) return;
              final s = Stylist(
                id: id,
                name: name,
                email: '',
                phone: null,
                specialization: specialization,
                serviceIds: [],
                commissionPercentage: commission,
                isActive: true,
                createdAt: DateTime.now(),
              );
              provider.addStylist(s);
              _nameCtrl.clear();
              _roleCtrl.clear();
              _commissionCtrl.text = '10.0';
              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditCommissionDialog(SalonProvider provider, Stylist s) {
    final ctrl = TextEditingController(text: (s.commissionPercentage ?? 0.0).toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Commission'),
        content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Commission %')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text) ?? (s.commissionPercentage ?? 0.0);
              final updated = s.copyWith(commissionPercentage: val);
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
    final provider = Provider.of<SalonProvider>(context);
    final staff = provider.stylists;

    return Scaffold(
      appBar: AppBar(title: const Text('Staff Management')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: staff.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final s = staff[index];
          return Card(
            child: ListTile(
              title: Text(s.name),
              subtitle: Text(s.specialization),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Commission: ${((s.commissionPercentage ?? 0.0)).toStringAsFixed(1)}%'),
                    const SizedBox(height: 4),
                    Text(
                        'Earned: ₦${provider.getStylistCommissionTotal(s.id).toStringAsFixed(2)}'),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showEditCommissionDialog(provider, s),
                ),
              ]),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (ctx) => Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Specialization: ${s.specialization}'),
                          const SizedBox(height: 8),
                          Text('Active: ${s.isActive ? 'Yes' : 'No'}'),
                          const SizedBox(height: 8),
                          Text(
                              'Commission: ${((s.commissionPercentage ?? 0.0)).toStringAsFixed(1)}%'),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Close'),
                          )
                        ]),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddStaffDialog(provider),
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

