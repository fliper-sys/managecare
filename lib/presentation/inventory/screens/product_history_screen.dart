import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/datetime_utils.dart';
import 'package:provider/provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/product_history_provider.dart';

class ProductHistoryScreen extends StatefulWidget {
  final String productId;
  final String? productName;

  const ProductHistoryScreen({super.key, required this.productId, this.productName});

  @override
  State<ProductHistoryScreen> createState() => _ProductHistoryScreenState();
}

class _ProductHistoryScreenState extends State<ProductHistoryScreen> {
  late ProductHistoryProvider _prov;

  @override
  void initState() {
    super.initState();
    _prov = ProductHistoryProvider();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final businessProvider = context.read<BusinessProvider>();
      final businessId = businessProvider.currentBusiness?.id;
      
      if (businessId == null || businessId.isEmpty) {
        _prov.error = 'No active business selected. Please select a business first.';
        return;
      }
      
      _prov.loadSales(businessId: businessId, productId: widget.productId);
    });
  }


  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _prov.start, end: _prov.end),
    );
    if (picked != null) {
      _prov.setRange(picked.start, picked.end);
      final businessId = context.read<BusinessProvider>().currentBusiness?.id;
      _prov.loadSales(businessId: businessId, productId: widget.productId);
    }
  }

  String _fmt(DateTime d) => DateFormat.yMMMd().format(d);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _prov,
      child: Consumer<ProductHistoryProvider>(builder: (context, prov, _) {
        return Scaffold(
          appBar: AppBar(title: Text(widget.productName ?? 'Product History')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text('From: ${_fmt(prov.start)}', style: AppTextStyles.body2)),
                    Expanded(child: Text('To: ${_fmt(prov.end)}', style: AppTextStyles.body2)),
                    IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickRange)
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: prov.loading
                      ? const Center(child: CircularProgressIndicator())
                      : prov.error != null
                          ? SingleChildScrollView(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error_outline, size: 48, color: AppColors.error),
                                      const SizedBox(height: 16),
                                      Text('Error Loading Sales History', style: AppTextStyles.heading5.copyWith(color: AppColors.error)),
                                      const SizedBox(height: 12),
                                      Text(prov.error!, style: AppTextStyles.body2, textAlign: TextAlign.center),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          final businessId = context.read<BusinessProvider>().currentBusiness?.id;
                                          prov.loadSales(businessId: businessId, productId: widget.productId);
                                        },
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Sales', style: AppTextStyles.heading5),
                                  const SizedBox(height: 8),
                                  if (prov.sales.isEmpty)
                                    const Text('No sales found in the selected range', style: AppTextStyles.body2)
                                  else
                                    ...prov.sales.map((s) => ListTile(
                                          title: Text('${s['quantity']} × ₦${(s['price'] as double).toStringAsFixed(2)} = ₦${(s['total'] as double).toStringAsFixed(2)}'),
                                          subtitle: Text('${DateFormat.yMMMd().add_jm().format(s['date'] as DateTime)} • ${s['paymentMethod'] ?? ''}'),
                                          trailing: Text(s['saleId'] ?? ''),
                                        )),
                                  const SizedBox(height: 18),
                                  Text('Procurements', style: AppTextStyles.heading5),
                                  const SizedBox(height: 8),
                                  Builder(builder: (context) {
                                    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
                                    if (businessId == null || businessId.isEmpty) return const Text('No business selected');

                                    return StreamBuilder<QuerySnapshot>(
                                      stream: prov.procurementsStream(businessId: businessId, productId: widget.productId),
                                      builder: (context, snap) {
                                        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                                        if (!snap.hasData || snap.data!.docs.isEmpty) return const Text('No procurements found');

                                        final filtered = snap.data!.docs.where((d) {
                                          final created = parseTimestamp(d.get('createdAt'));
                                          return !created.isBefore(prov.start) && !created.isAfter(prov.end);
                                        }).toList();

                                        if (filtered.isEmpty) return const Text('No procurements in the selected range');

                                        return Column(
                                            children: filtered.map((d) {
                                          final created = parseTimestamp(d.get('createdAt'));
                                          return ListTile(
                                            title: Text('${d.get('quantity') ?? ''} units @ ₦${(d.get('cost') ?? 0).toStringAsFixed(2)}'),
                                            subtitle: Text('${DateFormat.yMMMd().add_jm().format(created)} • ${d.get('procurementId') ?? ''}'),
                                          );
                                        }).toList());
                                      },
                                    );
                                  })
                                ],
                              ),
                            ),
                )
              ],
            ),
          ),
        );
      }),
    );
  }
}
