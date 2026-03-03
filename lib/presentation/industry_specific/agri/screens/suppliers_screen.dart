import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/colors.dart';
import '../../../../providers/business_provider.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  List<Map<String, dynamic>> _suppliers = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
      if (business == null) return setState(() => _loading = false);
      final snap = await FirebaseFirestore.instance
          .collection('businesses/${business.id}/suppliers')
          .orderBy('name')
          .get();
      setState(() {
        _suppliers = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load suppliers';
        _loading = false;
      });
    }
  }

  Future<void> _showEditDialog([Map<String, dynamic>? supplier]) async {
    final nameCtrl = TextEditingController(text: supplier?['name'] as String? ?? '');
    final contactCtrl = TextEditingController(text: supplier?['contact'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: supplier?['phone'] as String? ?? '');
    final emailCtrl = TextEditingController(text: supplier?['email'] as String? ?? '');
    final notesCtrl = TextEditingController(text: supplier?['notes'] as String? ?? '');
    final formKey = GlobalKey<FormState>();
    final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
    if (business == null) return;

    final res = await showDialog<bool?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(supplier == null ? 'Add Supplier' : 'Edit Supplier'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null),
              TextFormField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'Contact Name')),
              TextFormField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
              TextFormField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
              TextFormField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes')),
              if (supplier != null) const SizedBox(height: 12),
              if (supplier != null)
                ElevatedButton.icon(
                  onPressed: () async {
                    // Delete
                    try {
                      await FirebaseFirestore.instance
                          .collection('businesses/${business.id}/suppliers')
                          .doc(supplier['id'] as String)
                          .delete();
                      Navigator.of(ctx).pop(true);
                      _loadSuppliers();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete supplier')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Delete'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final data = {
                'name': nameCtrl.text.trim(),
                'contact': contactCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
                'notes': notesCtrl.text.trim(),
                'updatedAt': FieldValue.serverTimestamp(),
              };
              try {
                if (supplier == null) {
                  await FirebaseFirestore.instance
                      .collection('businesses/${business.id}/suppliers')
                      .add({...data, 'createdAt': FieldValue.serverTimestamp()});
                } else {
                  await FirebaseFirestore.instance
                      .collection('businesses/${business.id}/suppliers')
                      .doc(supplier['id'] as String)
                      .set(data, SetOptions(merge: true));
                }
                Navigator.of(ctx).pop(true);
                _loadSuppliers();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save supplier')));
              }
            },
            child: Text(supplier == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    contactCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    notesCtrl.dispose();
    if (res == true) _loadSuppliers();
  }

  Future<void> _callNumber(String phone) async {
    if (phone.trim().isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Phone number'),
        content: Text(phone),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: phone));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone copied to clipboard')));
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agri Suppliers'), backgroundColor: AppColors.primary),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _suppliers.isEmpty
                  ? const Center(child: Text('No suppliers yet'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _suppliers.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final s = _suppliers[index];
                        return ListTile(
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(s['name'] as String? ?? 'Supplier'),
                          subtitle: Text((s['phone'] as String? ?? '') + (s['email'] != null && (s['email'] as String).isNotEmpty ? '\n${s['email']}' : '')),
                          isThreeLine: true,
                          trailing: IconButton(icon: const Icon(Icons.phone), onPressed: () => _callNumber(s['phone'] as String? ?? '')),
                          onTap: () => _showEditDialog(s),
                        );
                      },
                    ),
    );
  }
}

