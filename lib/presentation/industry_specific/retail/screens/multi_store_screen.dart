import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../providers/retail_provider.dart';
import '../../../../providers/business_provider.dart';

class MultiStoreScreen extends StatefulWidget {
  const MultiStoreScreen({super.key});

  @override
  State<MultiStoreScreen> createState() => _MultiStoreScreenState();
}

class _MultiStoreScreenState extends State<MultiStoreScreen> {
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

  Future<void> _showAddEditStoreDialog(BuildContext context, RetailProvider provider, {StoreLocation? store}) async {
    if (store != null) {
      _nameController.text = store.name;
      _locationController.text = store.location;
      _addressController.text = store.address ?? '';
      _phoneController.text = store.phone ?? '';
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
        title: Text(store == null ? 'Add Store' : 'Edit Store'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Store Name'),
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

              // Re-check subscription and store limits before saving
              final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
              final isTier1 = (business?.subscriptionTier ?? '').toString().toLowerCase() == 'tier1';
              if (store == null && isTier1 && provider.stores.length >= 1) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your subscription allows only one store. Upgrade to add more stores.')));
                return;
              }

              try {
                if (store == null) {
                  await provider.addStore(name: name, location: location, address: address.isEmpty ? null : address, phone: phone.isEmpty ? null : phone);
                } else {
                  await provider.updateStore(store.id, name: name, location: location, address: address.isEmpty ? null : address, phone: phone.isEmpty ? null : phone);
                }
                Navigator.of(ctx).pop(true);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save store: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      // Refresh handled by provider; show feedback
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store saved'), backgroundColor: AppColors.success));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RetailProvider>(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          title: const Text('Multi-Store'),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.black)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: provider.stores
            .map((s) => Card(
                  child: ListTile(
                    title: Text(s.name,
                        style: AppTextStyles.body2
                            .copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text(s.location,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                    trailing: PopupMenuButton<String>(
                      onSelected: (val) async {
                        if (val == 'edit') {
                          await _showAddEditStoreDialog(context, provider, store: s);
                        } else if (val == 'delete') {
                          final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Store'),
                                    content: const Text('Are you sure you want to delete this store? This will not delete inventory but will remove the store reference.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                      ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                                    ],
                                  ));
                          if (confirmed == true) {
                            await provider.deleteStore(s.id);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store deleted'), backgroundColor: AppColors.success));
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
      floatingActionButton: Builder(builder: (ctx) {
        final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
        final isTier1 = (business?.subscriptionTier ?? '').toString().toLowerCase() == 'tier1';
        final canAdd = !(isTier1 && provider.stores.length >= 1);
        return FloatingActionButton(
          onPressed: canAdd
              ? () => _showAddEditStoreDialog(context, provider)
              : () {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Your subscription allows only one store. Upgrade to add more stores.'),
                  ));
                },
          tooltip: canAdd ? 'Add Store' : 'Upgrade to add store',
          child: const Icon(Icons.add),
        );
      }),
    );
  }
}

