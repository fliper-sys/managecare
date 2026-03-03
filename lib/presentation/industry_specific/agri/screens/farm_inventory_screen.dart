import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/colors.dart';
import '../../../../providers/business_provider.dart';

class FarmInventoryScreen extends StatefulWidget {
  const FarmInventoryScreen({super.key});

  @override
  State<FarmInventoryScreen> createState() => _FarmInventoryScreenState();
}

class _FarmInventoryScreenState extends State<FarmInventoryScreen> {
  List<Map<String, dynamic>> _inventory = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final business =
          Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
      if (business == null) return setState(() => _isLoading = false);

      final snap = await FirebaseFirestore.instance
          .collection('businesses/${business.id}/inventory')
          .orderBy('name')
          .get();

      setState(() {
        _inventory = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load inventory';
        _isLoading = false;
      });
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> item) async {
    final nameCtrl = TextEditingController(text: item['name'] as String? ?? '');
    final qtyCtrl = TextEditingController(text: '${(item['quantity'] as num?)?.toInt() ?? 0}');
    final formKey = GlobalKey<FormState>();
    final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
    if (business == null) return;

    final result = await showDialog<bool?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Inventory Item'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
              ),
              TextFormField(
                controller: qtyCtrl,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
                validator: (v) => int.tryParse(v ?? '') == null ? 'Enter valid number' : null,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () async {
                  // Delete
                  try {
                    await FirebaseFirestore.instance
                        .collection('businesses/${business.id}/inventory')
                        .doc(item['id'] as String)
                        .delete();
                    Navigator.of(context).pop(true);
                    _loadInventory();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete item')));
                  }
                },
                icon: const Icon(Icons.delete_forever),
                label: const Text('Delete'),
              )
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final name = nameCtrl.text.trim();
              final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
              try {
                await FirebaseFirestore.instance
                    .collection('businesses/${business.id}/inventory')
                    .doc(item['id'] as String)
                    .set({'name': name, 'quantity': qty, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                Navigator.of(context).pop(true);
                _loadInventory();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update item')));
              }
            },
            child: const Text('Save'),
          )
        ],
      ),
    );

    nameCtrl.dispose();
    qtyCtrl.dispose();
    if (result == true) {
      // refresh
      _loadInventory();
    }
  }

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();
    final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
    if (business == null) return;

    final res = await showDialog<bool?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Inventory Item'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
              ),
              TextFormField(
                controller: qtyCtrl,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
                validator: (v) => int.tryParse(v ?? '') == null ? 'Enter valid number' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final name = nameCtrl.text.trim();
              final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
              try {
                await FirebaseFirestore.instance
                    .collection('businesses/${business.id}/inventory')
                    .add({'name': name, 'quantity': qty, 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
                Navigator.of(context).pop(true);
                _loadInventory();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add item')));
              }
            },
            child: const Text('Add'),
          )
        ],
      ),
    );

    nameCtrl.dispose();
    qtyCtrl.dispose();
    if (res == true) _loadInventory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Farm Inventory'),
          backgroundColor: AppColors.primary),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _inventory.isEmpty
                  ? const Center(child: Text('No inventory items'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _inventory.length,
                      itemBuilder: (context, index) {
                        final item = _inventory[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.agriculture),
                            title: Text(item['name'] as String? ?? 'Item'),
                            subtitle: Text(
                                'Stock: ${(item['quantity'] as num?)?.toInt() ?? 0}'),
                            trailing: IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showEditDialog(item)),
                          ),
                        );
                      },
                    ),
    );
  }
}

