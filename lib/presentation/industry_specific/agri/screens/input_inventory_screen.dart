import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../providers/business_provider.dart';

class InputInventoryScreen extends StatefulWidget {
  const InputInventoryScreen({super.key});

  @override
  State<InputInventoryScreen> createState() => _InputInventoryScreenState();
}

class _InputInventoryScreenState extends State<InputInventoryScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _inputs = [];
  Map<String, double> _marketMap = {};

  @override
  void initState() {
    super.initState();
    _loadInputs();
  }

  Future<void> _loadInputs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final businessId = Provider.of<BusinessProvider>(context, listen: false).currentBusiness?.id;
      if (businessId == null) throw Exception('No business selected');

      final inputsSnap = await FirebaseFirestore.instance
          .collection('businesses/$businessId/agri_inputs')
          .orderBy('name')
          .get();
      final inputs = inputsSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      // Load market prices and build a simple map of latest price per item name
      final pricesSnap = await FirebaseFirestore.instance
          .collection('businesses/$businessId/market_prices')
          .orderBy('updatedAt', descending: true)
          .get();

      final Map<String, double> priceMap = {};
      for (final d in pricesSnap.docs) {
        final data = d.data();
        final name = (data['name'] ?? '').toString();
        if (name.isEmpty) continue;
        if (!priceMap.containsKey(name)) {
          final p = (data['price'] is num) ? (data['price'] as num).toDouble() : double.tryParse('${data['price']}') ?? 0.0;
          priceMap[name] = p;
        }
      }

      setState(() {
        _inputs = inputs.cast<Map<String, dynamic>>();
        _marketMap = priceMap;
      });
    } catch (e) {
      setState(() => _error = 'Failed to load input inventory');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addOrEditInput([Map<String, dynamic>? existing]) async {
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final unitCtrl = TextEditingController(text: existing?['unit'] as String? ?? '');
    final qtyCtrl = TextEditingController(text: existing?['quantity']?.toString() ?? '0');
    final priceCtrl = TextEditingController(text: existing?['purchasePrice']?.toString() ?? '0.0');
    final formKey = GlobalKey<FormState>();

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Input' : 'Edit Input'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null),
              TextFormField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Unit (e.g., kg, L)')),
              TextFormField(controller: qtyCtrl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity')),
              TextFormField(controller: priceCtrl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Purchase Price')),
              if (existing != null) const SizedBox(height: 12),
              if (existing != null)
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    final businessId = Provider.of<BusinessProvider>(context, listen: false).currentBusiness?.id;
                    if (businessId == null) return;
                    try {
                      await FirebaseFirestore.instance.collection('businesses/$businessId/agri_inputs').doc(existing['id'] as String).delete();
                      Navigator.of(ctx).pop(true);
                      _loadInputs();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete input')));
                    }
                  },
                )
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final businessId = Provider.of<BusinessProvider>(context, listen: false).currentBusiness?.id;
              if (businessId == null) return;
              final name = nameCtrl.text.trim();
              final unit = unitCtrl.text.trim();
              final qty = double.tryParse(qtyCtrl.text) ?? 0.0;
              final price = double.tryParse(priceCtrl.text) ?? 0.0;
              try {
                final col = FirebaseFirestore.instance.collection('businesses/$businessId/agri_inputs');
                if (existing == null) {
                  await col.add({'name': name, 'unit': unit, 'quantity': qty, 'purchasePrice': price, 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
                } else {
                  await col.doc(existing['id'] as String).set({'name': name, 'unit': unit, 'quantity': qty, 'purchasePrice': price, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                }
                Navigator.of(ctx).pop(true);
                _loadInputs();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save input')));
              }
            },
            child: const Text('Save'),
          )
        ],
      ),
    );

    nameCtrl.dispose();
    unitCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();

    if (res == true) await _loadInputs();
  }

  Future<void> _applyMarketPrice(Map<String, dynamic> input) async {
    final name = (input['name'] ?? '').toString();
    final businessId = Provider.of<BusinessProvider>(context, listen: false).currentBusiness?.id;
    if (businessId == null) return;
    final market = _marketMap[name];
    if (market == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No market price available for this item')));
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('businesses/$businessId/agri_inputs').doc(input['id'] as String).set({'purchasePrice': market, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Applied market price')));
      await _loadInputs();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to apply market price')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Input Inventory'), backgroundColor: AppColors.agri),
      body: RefreshIndicator(
        onRefresh: _loadInputs,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!)))])
                : _inputs.isEmpty
                    ? ListView(children: const [SizedBox(height: 100), Center(child: Text('No inputs yet'))])
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _inputs.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, i) {
                          final it = _inputs[i];
                          final name = it['name'] as String? ?? '';
                          final qty = it['quantity'] is num ? (it['quantity'] as num).toDouble() : double.tryParse('${it['quantity']}') ?? 0.0;
                          final unit = it['unit'] as String? ?? '';
                          final purchase = it['purchasePrice'] is num ? (it['purchasePrice'] as num).toDouble() : double.tryParse('${it['purchasePrice']}') ?? 0.0;
                          final market = _marketMap[name];
                          return ListTile(
                            leading: const Icon(Icons.inventory_2),
                            title: Text(name),
                            subtitle: Text('Qty: ${qty.toStringAsFixed(2)} ${unit.isNotEmpty ? unit : ''} • Purchase: ₦${purchase.toStringAsFixed(2)}${market != null ? ' • Market: ₦${market.toStringAsFixed(2)}' : ''}'),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(icon: const Icon(Icons.price_check), onPressed: () => _applyMarketPrice(it), tooltip: 'Apply market price'),
                              IconButton(icon: const Icon(Icons.edit), onPressed: () => _addOrEditInput(it)),
                            ]),
                          );
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditInput(),
        backgroundColor: AppColors.agri,
        child: const Icon(Icons.add),
      ),
    );
  }
}

