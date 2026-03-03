import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../providers/business_provider.dart';

class MarketPricesScreen extends StatefulWidget {
  const MarketPricesScreen({super.key});

  @override
  State<MarketPricesScreen> createState() => _MarketPricesScreenState();
}

class _MarketPricesScreenState extends State<MarketPricesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _prices = [];

  @override
  void initState() {
    super.initState();
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final businessId =
          Provider.of<BusinessProvider>(context, listen: false).currentBusiness?.id;
      if (businessId == null) throw Exception('No business selected');
      final snap = await FirebaseFirestore.instance
          .collection('businesses/$businessId/market_prices')
          .orderBy('updatedAt', descending: true)
          .get();
      _prices = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
    } catch (e) {
      _error = 'Failed to load market prices';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addOrEditPrice({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final priceCtrl = TextEditingController(text: existing?['price']?.toString() ?? '');
    final res = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(existing == null ? 'Add Price' : 'Edit Price'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item')),
                TextField(controller: priceCtrl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price')),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save'))
              ],
            ));
    if (res == true) {
      final businessId =
          Provider.of<BusinessProvider>(context, listen: false).currentBusiness?.id;
      if (businessId == null) return;
      final docRef = existing == null
          ? FirebaseFirestore.instance.collection('businesses/$businessId/market_prices').doc()
          : FirebaseFirestore.instance.collection('businesses/$businessId/market_prices').doc(existing['id']);
      final price = double.tryParse(priceCtrl.text) ?? 0.0;
      await docRef.set({'name': nameCtrl.text.trim(), 'price': price, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      await _loadPrices();
    }
  }

  Future<void> _deletePrice(String id) async {
    final businessId =
        Provider.of<BusinessProvider>(context, listen: false).currentBusiness?.id;
    if (businessId == null) return;
    await FirebaseFirestore.instance.collection('businesses/$businessId/market_prices').doc(id).delete();
    await _loadPrices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Market Prices'), backgroundColor: AppColors.agri),
      body: RefreshIndicator(
        onRefresh: _loadPrices,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _prices.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 100),
                          Center(child: Text('No market prices yet'))
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _prices.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, i) {
                          final p = _prices[i];
                          return ListTile(
                            leading: const Icon(Icons.price_check),
                            title: Text(p['name'] ?? ''),
                            subtitle: Text('Price: ₦${(p['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(icon: const Icon(Icons.edit), onPressed: () => _addOrEditPrice(existing: p)),
                              IconButton(icon: const Icon(Icons.delete), onPressed: () => _deletePrice(p['id'])),
                            ]),
                          );
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.agri,
        child: const Icon(Icons.add),
        onPressed: () => _addOrEditPrice(),
      ),
    );
  }
}

