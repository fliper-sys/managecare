import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/text_styles.dart';

import '../providers/restaurant_provider.dart';

class ManageTablesScreen extends StatefulWidget {
  const ManageTablesScreen({super.key});

  @override
  State<ManageTablesScreen> createState() => _ManageTablesScreenState();
}

class _ManageTablesScreenState extends State<ManageTablesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<RestaurantProvider>(context, listen: false);
      provider.initializeTables();
    });
  }

  Future<void> _showTableDialog({TableInfo? editing}) async {
    final numberCtrl = TextEditingController(text: editing?.tableNumber.toString() ?? '');
    final capacityCtrl = TextEditingController(text: editing?.capacity.toString() ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(editing == null ? 'Add Table' : 'Edit Table'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Table Number'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: capacityCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Capacity'),
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

    final number = int.tryParse(numberCtrl.text) ?? 0;
    final capacity = int.tryParse(capacityCtrl.text) ?? 0;

    final provider = Provider.of<RestaurantProvider>(context, listen: false);
    if (editing == null) {
      final table = TableInfo(id: '', tableNumber: number, capacity: capacity);
      await provider.addTable(table);
    } else {
      final updated = TableInfo(
        id: editing.id,
        tableNumber: number,
        capacity: capacity,
        status: editing.status,
        assignedWaiterId: editing.assignedWaiterId,
        assignedWaiterName: editing.assignedWaiterName,
        reservedUntil: editing.reservedUntil,
      );
      await provider.updateTable(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Tables')),
      body: Consumer<RestaurantProvider>(builder: (ctx, prov, _) {
        final tables = prov.tables;
        if (tables.isEmpty) {
          return const Center(child: Text('No tables yet'));
        }

        return ListView.builder(
          itemCount: tables.length,
          itemBuilder: (ctx, i) {
            final t = tables[i];
            return ListTile(
              title: Text('Table ${t.tableNumber}', style: AppTextStyles.subtitle1),
              subtitle: Text('Capacity: ${t.capacity} • Status: ${t.status}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showTableDialog(editing: t),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => prov.deleteTable(t.id),
                ),
              ]),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTableDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
