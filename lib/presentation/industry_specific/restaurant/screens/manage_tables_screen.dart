import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../providers/business_provider.dart';
import '../providers/restaurant_provider.dart';

class ManageTablesScreen extends StatefulWidget {
  const ManageTablesScreen({super.key});

  @override
  State<ManageTablesScreen> createState() => _ManageTablesScreenState();
}

class _ManageTablesScreenState extends State<ManageTablesScreen> {
  bool _openedFromRouteArgs = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<RestaurantProvider>(context, listen: false);
      provider.initializeTables();
      final args = ModalRoute.of(context)?.settings.arguments;
      if (!_openedFromRouteArgs && args is Map && args['openAdd'] == true) {
        _openedFromRouteArgs = true;
        _showTableDialog();
      }
    });
  }

  Future<void> _showBlockedDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<bool> _ensureCanManageTables({required bool isNew}) async {
    final businessProvider = context.read<BusinessProvider>();
    final access = await businessProvider.canAccessFeatureEnhanced(
      'basic_sales',
      context: 'restaurant_manage_tables',
    );

    if (!mounted) return false;
    if (!(access['ok'] as bool? ?? false)) {
      await _showBlockedDialog(
        title: 'Subscription required',
        message: businessProvider.getSubscriptionBlockedMessage(
          feature: 'basic_sales',
        ),
      );
      return false;
    }

    if (isNew) {
      final currentCount = context.read<RestaurantProvider>().tables.length;
      if (!businessProvider.isWithinLimit('tables', currentCount)) {
        await _showBlockedDialog(
          title: 'Table limit reached',
          message: businessProvider.getLimitReachedMessage('tables'),
        );
        return false;
      }
    }

    return true;
  }

  Future<void> _showTableDialog({TableInfo? editing}) async {
    final isNew = editing == null;
    if (!await _ensureCanManageTables(isNew: isNew)) return;

    final numberCtrl =
        TextEditingController(text: editing?.tableNumber.toString() ?? '');
    final capacityCtrl =
        TextEditingController(text: editing?.capacity.toString() ?? '');
    int? selectedPresetCapacity = editing?.capacity;
    const presetCapacities = [2, 3, 4, 6, 8, 10];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    editing == null ? 'Add Table' : 'Edit Table',
                    style: AppTextStyles.heading5,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set up the table number and seating capacity used by your restaurant team.',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: numberCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Table Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: capacityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Capacity',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  StatefulBuilder(
                    builder: (context, setInnerState) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: presetCapacities.map((capacity) {
                          final isSelected = selectedPresetCapacity == capacity;
                          return ChoiceChip(
                            label: Text('Table for $capacity'),
                            selected: isSelected,
                            onSelected: (_) {
                              setInnerState(() {
                                selectedPresetCapacity = capacity;
                                capacityCtrl.text = capacity.toString();
                              });
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    final number = int.tryParse(numberCtrl.text) ?? 0;
    final capacity = int.tryParse(capacityCtrl.text) ?? 0;

    final provider = Provider.of<RestaurantProvider>(context, listen: false);
    if (number <= 0 || capacity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid table number and capacity'),
        ),
      );
      return;
    }

    final duplicateNumber = provider.tables.any(
      (table) => table.tableNumber == number && table.id != editing?.id,
    );
    if (duplicateNumber) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Table $number already exists')),
      );
      return;
    }

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

  Future<void> _deleteTable(TableInfo table) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete table?'),
            content: Text(
              'Table ${table.tableNumber} will be removed from your restaurant setup.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;
    await context.read<RestaurantProvider>().deleteTable(table.id);
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'occupied':
        return Colors.orange;
      case 'reserved':
        return Colors.deepPurple;
      case 'available':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1724) : const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Manage Tables'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _showTableDialog(),
            icon: const Icon(Icons.add),
            tooltip: 'Add table',
          ),
        ],
      ),
      body: Consumer<RestaurantProvider>(
        builder: (ctx, prov, _) {
          final tables = prov.tables;
          if (tables.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : AppColors.border,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.table_restaurant,
                          size: 34,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tables yet',
                        style: AppTextStyles.heading5.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your dining tables so orders and seating can be tracked properly.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: () => _showTableDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Table'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: tables.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final table = tables[i];
              final statusColor = _statusColor(table.status);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : AppColors.border.withOpacity(0.7),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.14 : 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Table ${table.tableNumber}',
                          style: AppTextStyles.subtitle1.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            table.status.toUpperCase(),
                            style: AppTextStyles.caption.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MetaChip(
                          icon: Icons.event_seat_outlined,
                          label: 'Capacity ${table.capacity}',
                        ),
                        if ((table.assignedWaiterName ?? '').isNotEmpty)
                          _MetaChip(
                            icon: Icons.person_outline,
                            label: table.assignedWaiterName!,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showTableDialog(editing: table),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _deleteTable(table),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTableDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Table'),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.body2,
          ),
        ],
      ),
    );
  }
}
