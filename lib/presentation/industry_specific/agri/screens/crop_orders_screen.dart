import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/colors.dart';
import '../../../../providers/business_provider.dart';

class CropOrdersScreen extends StatefulWidget {
  const CropOrdersScreen({super.key});

  @override
  State<CropOrdersScreen> createState() => _CropOrdersScreenState();
}

class _CropOrdersScreenState extends State<CropOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final business =
          Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
      if (business == null) return setState(() => _isLoading = false);

      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('businessId', isEqualTo: business.id)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _orders = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load orders';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Crop Orders'), backgroundColor: AppColors.primary),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _orders.isEmpty
                  ? const Center(child: Text('No orders'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final o = _orders[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.shopping_basket),
                            title: Text(
                                'Order #${o['orderId'] as String? ?? o['id']}'),
                            subtitle: Text(
                                'Crop: ${o['cropType'] as String? ?? 'N/A'} • Qty: ${o['quantity'] as int? ?? 0}'),
                            trailing: Text(
                                'Status: ${o['status'] as String? ?? 'Pending'}'),
                          ),
                        );
                      },
                    ),
    );
  }
}

