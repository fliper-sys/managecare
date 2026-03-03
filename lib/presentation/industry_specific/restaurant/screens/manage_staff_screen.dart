import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/text_styles.dart';
import '../providers/restaurant_provider.dart';

class ManageStaffScreen extends StatefulWidget {
  const ManageStaffScreen({super.key});

  @override
  State<ManageStaffScreen> createState() => _ManageStaffScreenState();
}

class _ManageStaffScreenState extends State<ManageStaffScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RestaurantProvider>(context, listen: false).initializeServers();
    });
  }

  Future<void> _showStaffDialog({Server? editing}) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final phoneCtrl = TextEditingController(text: editing?.phone ?? '');
    String role = editing?.role ?? 'waiter';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(editing == null ? 'Add Staff' : 'Edit Staff'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: role,
              items: const [
                DropdownMenuItem(value: 'waiter', child: Text('Waiter')),
                DropdownMenuItem(value: 'chef', child: Text('Chef')),
                DropdownMenuItem(value: 'manager', child: Text('Manager')),
              ],
              onChanged: (v) => role = v ?? 'waiter',
              decoration: const InputDecoration(labelText: 'Role'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (confirmed != true) return;

    final provider = Provider.of<RestaurantProvider>(context, listen: false);
    if (editing == null) {
      final s = Server(id: '', name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim(), role: role);
      await provider.addServer(s);
    } else {
      final s = Server(id: editing.id, name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim(), role: role, active: editing.active);
      await provider.updateServer(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      body: Consumer<RestaurantProvider>(builder: (ctx, prov, _) {
        final servers = prov.servers;
        if (servers.isEmpty) return const Center(child: Text('No staff added'));
        return ListView.builder(
          itemCount: servers.length,
          itemBuilder: (ctx, i) {
            final s = servers[i];
            return ListTile(
              title: Text(s.name, style: AppTextStyles.subtitle1),
              subtitle: Text('${s.role} • ${s.phone}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit), onPressed: () => _showStaffDialog(editing: s)),
                IconButton(icon: const Icon(Icons.delete), onPressed: () => prov.deleteServer(s.id)),
              ]),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(onPressed: () => _showStaffDialog(), child: const Icon(Icons.add)),
    );
  }
}
