import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/apartment_model.dart';
import '../../../../providers/apartment_provider.dart';
import '../../../../providers/business_provider.dart';
import 'add_edit_unit_screen.dart';

class UnitManagementScreen extends StatefulWidget {
  final Apartment apartment;
  const UnitManagementScreen({Key? key, required this.apartment}) : super(key: key);

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
    if (businessId == null) return;
    setState(() => _isLoading = true);
    await context.read<ApartmentProvider>().loadUnits(businessId, widget.apartment.id);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final aptProv = context.watch<ApartmentProvider>();
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    final units = aptProv.units[widget.apartment.id] ?? [];

    return Scaffold(
      appBar: AppBar(title: Text('Units — ${widget.apartment.title}')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemBuilder: (_, idx) {
                        final u = units[idx];
                        return ListTile(
                          title: Text(u.name),
                          subtitle: Text('₦${u.pricePerNight.toStringAsFixed(2)} • Capacity ${u.capacity}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () async {
                                  final res = await Navigator.push<bool?>(context, MaterialPageRoute(builder: (_) => AddEditUnitScreen(apartmentId: widget.apartment.id, unit: u)));
                                  if (res == true) {
                                    await _refreshUnits();
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unit updated')));
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  if (businessId == null) return;
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Unit'),
                                      content: const Text('Are you sure you want to delete this unit? This action cannot be undone.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                      ],
                                    ),
                                  );
                                  if (confirm != true) return;
                                  // show progress
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (ctx) => const Center(child: CircularProgressIndicator()),
                                  );
                                  try {
                                    await context.read<ApartmentProvider>().deleteUnit(businessId, widget.apartment.id, u.id);
                                    Navigator.pop(context); // close progress
                                    await _refreshUnits();
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unit deleted')));
                                  } catch (e) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete unit: $e')));
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemCount: units.length,
                    ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Unit'),
              onPressed: () async {
                if (businessId == null) return;
                final res = await Navigator.push<bool?>(context, MaterialPageRoute(builder: (_) => AddEditUnitScreen(apartmentId: widget.apartment.id)));
                if (res == true) {
                  await _refreshUnits();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unit added')));
                }
              },
            )
          ],
        ),
      ),
    );
  }
}
