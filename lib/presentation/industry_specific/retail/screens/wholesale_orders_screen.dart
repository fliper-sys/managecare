import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/colors.dart';
import '../../../../providers/business_provider.dart';

class WholesaleOrdersScreen extends StatefulWidget {
  const WholesaleOrdersScreen({super.key});

  @override
  State<WholesaleOrdersScreen> createState() => _WholesaleOrdersScreenState();
}

class _WholesaleOrdersScreenState extends State<WholesaleOrdersScreen> {
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
          .collection('wholesaleOrders')
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
          title: const Text('Wholesale Orders'),
          backgroundColor: AppColors.primary),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _orders.isEmpty
                  ? const Center(child: Text('No wholesale orders'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final o = _orders[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.local_shipping),
                            title: Text(
                                'Order #${o['orderNumber'] as String? ?? o['id']}'),
                            subtitle: Text(
                                'Items: ${o['itemCount'] as int? ?? 0} • Status: ${o['status'] as String? ?? 'Pending'}'),
                            trailing: IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: () {}),
                          ),
                        );
                      },
                    ),
    );
  }
}

