import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/routes.dart';
import '../../../providers/reports_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/business_provider.dart';

class DistributorSalesReportScreen extends StatefulWidget {
  const DistributorSalesReportScreen({super.key});

  @override
  State<DistributorSalesReportScreen> createState() => _DistributorSalesReportScreenState();
}

class _DistributorSalesReportScreenState extends State<DistributorSalesReportScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _sales = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final businessId = context.read<BusinessProvider>().currentBusiness?.id ?? '';
      if (businessId.isEmpty) {
        throw Exception('No business selected');
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('distributor_sales')
          .orderBy('createdAt', descending: true)
          .get();

      final sales = snapshot.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{'id': doc.id, ...data};
      }).toList();

      setState(() {
        _sales = sales;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Distributor Sales Report'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error, style: AppTextStyles.body1),
                  ),
                )
              : _sales.isEmpty
                  ? const Center(child: Text('No distributor sales yet'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sales.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final sale = _sales[index];
                        final createdAt = sale['createdAt'];
                        final label = createdAt is Timestamp
                            ? createdAt.toDate().toLocal().toString().split('.').first
                            : createdAt?.toString() ?? '—';
                        final total = (sale['totalAmount'] as num?)?.toDouble() ?? 0.0;
                        return Card(
                          child: ListTile(
                            title: Text(sale['productName']?.toString() ?? 'Unknown product'),
                            subtitle: Text(
                              '${sale['distributorName'] ?? 'Unknown distributor'} • Qty ${sale['quantity'] ?? 0} • ${sale['discountPercent'] ?? 0}% off',
                            ),
                            trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('₦${total.toStringAsFixed(2)}', style: AppTextStyles.heading5),
                                          Text(label, style: AppTextStyles.caption),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      PopupMenuButton<String>(
                                        onSelected: (v) async {
                                          final saleId = sale['id']?.toString() ?? '';
                                          if (v == 'view') {
                                            if (saleId.isNotEmpty) {
                                              Navigator.pushNamed(context, Routes.salesReceipt, arguments: {'saleId': saleId});
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt not available')));
                                            }
                                          } else if (v == 'delete') {
                                            final confirm = await showDialog<bool?>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Delete sale'),
                                                content: const Text('Are you sure you want to delete this sale? This will restock the items.'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                                ],
                                              ),
                                            );
                                            if (confirm == true && saleId.isNotEmpty) {
                                              try {
                                                final reports = context.read<ReportsProvider>();
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleting sale...')));
                                                final res = await reports.deleteSale(saleId);
                                                if (res == null || res['success'] != true) {
                                                  final msg = res != null && res['error'] != null ? res['error'].toString() : 'Delete failed';
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete sale: $msg'), backgroundColor: Colors.red));
                                                } else {
                                                  setState(() {
                                                    _sales.removeAt(index);
                                                  });
                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale deleted')));
                                                }
                                              } catch (e) {
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete error: $e'), backgroundColor: Colors.red));
                                              }
                                            }
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(value: 'view', child: Text('View Receipt')),
                                          const PopupMenuItem(value: 'delete', child: Text('Delete Sale')),
                                        ],
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
    );
  }
}
