import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../providers/wholesale_provider.dart';

class WarehousesScreen extends StatefulWidget {
  final bool openAdd;
  const WarehousesScreen({Key? key, this.openAdd = false}) : super(key: key);

  @override
  State<WarehousesScreen> createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends State<WarehousesScreen> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _showAddEditDialog(BuildContext context, WholesaleProvider provider, {WarehouseLocation? warehouse}) async {
    if (warehouse != null) {
      _nameController.text = warehouse.name;
      _locationController.text = warehouse.location;
      _addressController.text = warehouse.address ?? '';
      _phoneController.text = warehouse.phone ?? '';
    } else {
      _nameController.clear();
      _locationController.clear();
      _addressController.clear();
      _phoneController.clear();
    }

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(warehouse == null ? 'Add Warehouse' : 'Edit Warehouse'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Warehouse Name'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address (optional)'),
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone (optional)'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final name = _nameController.text.trim();
              final location = _locationController.text.trim();
              final address = _addressController.text.trim();
              final phone = _phoneController.text.trim();

              try {
                if (warehouse == null) {
                  final id = 'wh_${DateTime.now().millisecondsSinceEpoch}';
                  final w = WarehouseLocation(id: id, name: name, location: location, address: address.isEmpty ? null : address, phone: phone.isEmpty ? null : phone);
                  await provider.addWarehouse(w);
                } else {
                  final updated = WarehouseLocation(id: warehouse.id, name: name, location: location, address: address.isEmpty ? null : address, phone: phone.isEmpty ? null : phone);
                  await provider.updateWarehouse(updated);
                }
                Navigator.of(ctx).pop(true);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save warehouse: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Warehouse saved'), backgroundColor: AppColors.success));
    }
  }

  @override
  void initState() {
    super.initState();
    // If screen was opened with openAdd true, schedule the add dialog to appear
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.openAdd) {
        final provider = Provider.of<WholesaleProvider>(context, listen: false);
        _showAddEditDialog(context, provider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WholesaleProvider>(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          title: const Text('Warehouses'),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.black)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: provider.warehouses
            .map((w) => Card(
                  child: ListTile(
                    title: Text(w.name, style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text(w.location, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    trailing: PopupMenuButton<String>(
                      onSelected: (val) async {
                        if (val == 'edit') {
                          await _showAddEditDialog(context, provider, warehouse: w);
                        } else if (val == 'delete') {
                          final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Warehouse'),
                                    content: const Text('Are you sure you want to delete this warehouse? This will not delete inventory but will remove the warehouse reference.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                      ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                                    ],
                                  ));
                          if (confirmed == true) {
                            await provider.deleteWarehouse(w.id);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Warehouse deleted'), backgroundColor: AppColors.success));
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(context, provider),
        child: const Icon(Icons.add),
      ),
    );
  }
}
