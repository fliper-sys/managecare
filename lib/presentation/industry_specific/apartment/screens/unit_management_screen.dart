import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../data/models/apartment_model.dart';
import '../../../../providers/apartment_provider.dart';
import '../../../../providers/business_provider.dart';
import 'add_edit_unit_screen.dart';

class UnitManagementScreen extends StatefulWidget {
  final Apartment apartment;

  const UnitManagementScreen({super.key, required this.apartment});

  @override
  State<UnitManagementScreen> createState() => _UnitManagementScreenState();
}

class _UnitManagementScreenState extends State<UnitManagementScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshUnits());
  }

  Future<void> _refreshUnits() async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null) {
      return;
    }

    setState(() => _isLoading = true);
    await context
        .read<ApartmentProvider>()
        .loadUnits(businessId, widget.apartment.id);
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _toggleUnitActive(String unitId, bool active) async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null) {
      return;
    }

    await context.read<ApartmentProvider>().updateUnit(
          businessId,
          widget.apartment.id,
          unitId,
          {'active': active},
        );
  }

  Future<void> _deleteUnit(String unitId) async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete unit'),
              content: const Text(
                'Are you sure you want to delete this unit? This action cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    try {
      await context
          .read<ApartmentProvider>()
          .deleteUnit(businessId, widget.apartment.id, unitId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unit deleted')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete unit: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final apartmentProvider = context.watch<ApartmentProvider>();
    final units = apartmentProvider.units[widget.apartment.id] ?? const [];
    final activeUnits = units.where((unit) => unit.active).length;

    return Scaffold(
      appBar: AppBar(title: Text(widget.apartment.title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool?>(
            context,
            MaterialPageRoute(
              builder: (_) => AddEditUnitScreen(apartmentId: widget.apartment.id),
            ),
          );
          if (result == true) {
            await _refreshUnits();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Unit'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshUnits,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.meeting_room_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Unit Overview',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text('${units.length} total units • $activeUnits active'),
                      ],
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading && units.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (units.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  children: [
                    const Icon(Icons.meeting_room_outlined, size: 46, color: AppColors.primary),
                    const SizedBox(height: 12),
                    const Text(
                      'No units yet',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add units to start taking bookings for this apartment.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final result = await Navigator.push<bool?>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AddEditUnitScreen(apartmentId: widget.apartment.id),
                          ),
                        );
                        if (result == true) {
                          await _refreshUnits();
                        }
                      },
                      child: const Text('Add Unit'),
                    ),
                  ],
                ),
              )
            else
              ...units.map((unit) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              unit.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (unit.active ? Colors.green : Colors.grey)
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              unit.active ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: unit.active ? Colors.green : Colors.grey,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _UnitInfoPill(
                            icon: Icons.payments_rounded,
                            label: '${formatCurrency(unit.pricePerNight, decimalDigits: 0)}/night',
                          ),
                          _UnitInfoPill(
                            icon: Icons.groups_rounded,
                            label: 'Capacity ${unit.capacity}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Text(
                            'Available for booking',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Switch(
                            value: unit.active,
                            onChanged: (value) => _toggleUnitActive(unit.id, value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push<bool?>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddEditUnitScreen(
                                    apartmentId: widget.apartment.id,
                                    unit: unit,
                                  ),
                                ),
                              );
                              if (result == true) {
                                await _refreshUnits();
                              }
                            },
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _deleteUnit(unit.id),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _UnitInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _UnitInfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
