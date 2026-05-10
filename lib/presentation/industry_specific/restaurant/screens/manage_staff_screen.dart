import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../providers/business_provider.dart';
import '../providers/restaurant_provider.dart';

class ManageStaffScreen extends StatefulWidget {
  const ManageStaffScreen({super.key});

  @override
  State<ManageStaffScreen> createState() => _ManageStaffScreenState();
}

class _ManageStaffScreenState extends State<ManageStaffScreen> {
  static const List<String> _availableSections = [
    'kitchen',
    'waiter',
    'cashier',
    'staff',
  ];

  static const List<String> _availablePermissions = [
    'sales',
    'manage_menu',
    'procurement_management',
    'table_management',
    'view_orders',
    'view_reports',
    'view_low_stock',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final business =
          Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
      if (business != null) {
        context.read<RestaurantProvider>().setBusinessId(business.id);
        context.read<RestaurantProvider>().initializeServers(
              businessId: business.id,
            );
      } else {
        context.read<RestaurantProvider>().initializeServers();
      }
    });
  }

  Future<void> _showStaffDialog({Server? editing}) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final phoneCtrl = TextEditingController(text: editing?.phone ?? '');
    String role = editing?.role ?? 'waiter';
    final selectedSections = {...(editing?.sections ?? const <String>[])};
    final selectedPermissions = {
      ...(editing?.permissions ?? const <String>[])
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(editing == null ? 'Add Staff' : 'Edit Staff'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: role,
                  items: const [
                    DropdownMenuItem(
                      value: 'sub_admin',
                      child: Text('Sub Admin'),
                    ),
                    DropdownMenuItem(value: 'manager', child: Text('Manager')),
                    DropdownMenuItem(value: 'waiter', child: Text('Waiter')),
                    DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                    DropdownMenuItem(value: 'chef', child: Text('Chef')),
                    DropdownMenuItem(value: 'staff', child: Text('Staff')),
                  ],
                  onChanged: (v) => setDialogState(() => role = v ?? 'waiter'),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sections',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableSections.map((section) {
                    return FilterChip(
                      label: Text(section),
                      selected: selectedSections.contains(section),
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            selectedSections.add(section);
                          } else {
                            selectedSections.remove(section);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Permissions',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ..._availablePermissions.map(
                  (permission) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: selectedPermissions.contains(permission),
                    title: Text(
                      permission.replaceAll('_', ' ').toUpperCase(),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          selectedPermissions.add(permission);
                        } else {
                          selectedPermissions.remove(permission);
                        }
                      });
                    },
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
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final provider = Provider.of<RestaurantProvider>(context, listen: false);
    if (editing == null) {
      await provider.addServer(
        Server(
          id: '',
          name: nameCtrl.text.trim(),
          phone: phoneCtrl.text.trim(),
          role: role,
          sections: selectedSections.toList(),
          permissions: selectedPermissions.toList(),
        ),
      );
    } else {
      await provider.updateServer(
        Server(
          id: editing.id,
          name: nameCtrl.text.trim(),
          phone: phoneCtrl.text.trim(),
          role: role,
          active: editing.active,
          sections: selectedSections.toList(),
          permissions: selectedPermissions.toList(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      body: Consumer<RestaurantProvider>(
        builder: (ctx, prov, _) {
          final servers = prov.servers;
          if (servers.isEmpty) {
            return const Center(child: Text('No staff added'));
          }
          return ListView.builder(
            itemCount: servers.length,
            itemBuilder: (ctx, i) {
              final s = servers[i];
              final subtitleParts = <String>[
                s.role,
                if (s.sections.isNotEmpty) s.sections.join(', '),
                if (s.phone.isNotEmpty) s.phone,
              ];
              return ListTile(
                title: Text(s.name, style: AppTextStyles.subtitle1),
                subtitle: Text(subtitleParts.join(' • ')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showStaffDialog(editing: s),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => prov.deleteServer(s.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showStaffDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
