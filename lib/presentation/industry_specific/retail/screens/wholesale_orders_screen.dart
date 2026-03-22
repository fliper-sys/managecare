import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
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
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final business =
          Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
      if (business == null) {
        setState(() => _isLoading = false);
        return;
      }

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
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
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
                        final order = _orders[index];
                        final itemCount =
                            (order['itemCount'] as int?) ?? ((order['items'] as List?)?.length ?? 0);
                        final total = ((order['totalAmount'] ??
                                    order['total'] ??
                                    order['amount'] ??
                                    0) as num?)
                                ?.toDouble() ??
                            0.0;

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.local_shipping),
                            title: Text(
                              'Order #${order['orderNumber'] as String? ?? order['id']}',
                            ),
                            subtitle: Text(
                              'Items: $itemCount - Status: ${order['status'] as String? ?? 'Pending'}',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatCurrency(total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () => _showOrderDetails(order),
                          ),
                        );
                      },
                    ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    final items = (order['items'] as List?) ?? const [];
    final total =
        ((order['totalAmount'] ?? order['total'] ?? 0) as num?)?.toDouble() ??
            0.0;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order #${order['orderNumber'] ?? order['id'] ?? '-'}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${order['status'] ?? 'Pending'}'),
                const SizedBox(height: 8),
                Text(
                  'Customer: ${order['customerName'] ?? order['customer'] ?? 'Walk-in'}',
                ),
                const SizedBox(height: 8),
                Text('Total: ${formatCurrency(total)}'),
                const SizedBox(height: 12),
                const Text(
                  'Items',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...items.map((item) {
                  final map = item is Map<String, dynamic>
                      ? item
                      : Map<String, dynamic>.from(item as Map);
                  final qty = (map['quantity'] ?? map['qty'] ?? 1).toString();
                  final name = (map['name'] ??
                          map['productName'] ??
                          map['title'] ??
                          'Item')
                      .toString();
                  final lineTotal =
                      ((map['total'] ?? map['lineTotal'] ?? 0) as num?)
                              ?.toDouble() ??
                          0.0;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(name),
                    subtitle: Text('Qty $qty'),
                    trailing: Text(formatCurrency(lineTotal)),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
