import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/datetime_utils.dart';
import '../../../services/web_download.dart' as web_download;
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

  String _escapeCsv(String value) => '"${value.replaceAll('"', '""')}"';

  String _buildCsv(List<Map<String, dynamic>> sales) {
    final buffer = StringBuffer();
    buffer.writeln([
      'Sale ID',
      'Date',
      'Quantity',
      'Unit Price',
      'Total',
      'Payment Method',
    ].join(','));

    for (final sale in sales) {
      buffer.writeln([
        _escapeCsv((sale['saleId'] ?? '').toString()),
        _escapeCsv(DateFormat('yyyy-MM-dd HH:mm:ss').format(sale['date'] as DateTime)),
        _escapeCsv((sale['quantity'] ?? 0).toString()),
        _escapeCsv((sale['price'] ?? 0).toString()),
        _escapeCsv((sale['total'] ?? 0).toString()),
        _escapeCsv((sale['paymentMethod'] ?? '').toString()),
      ].join(','));
    }

    return buffer.toString();
  }

  Future<void> _exportHistory(List<Map<String, dynamic>> sales) async {
    if (sales.isEmpty) return;
    final fileName =
        '${(widget.productName ?? widget.productId).replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')}_history.csv';
    final csv = _buildCsv(sales);
    final bytes = Uint8List.fromList(utf8.encode(csv));

    if (kIsWeb) {
      web_download.downloadBytes(bytes, fileName, 'text/csv');
    } else {
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: fileName,
            mimeType: 'text/csv',
          ),
        ],
        text: 'Product history for ${widget.productName ?? widget.productId}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _prov,
      child: Consumer<ProductHistoryProvider>(builder: (context, prov, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.productName ?? 'Product History'),
            actions: [
              IconButton(
                tooltip: 'Download history',
                icon: const Icon(Icons.download_outlined),
                onPressed: prov.sales.isEmpty ? null : () => _exportHistory(prov.sales),
              ),
            ],
          ),
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

                                    return StreamBuilder<List<Map<String, dynamic>>>(
                                      stream: prov.procurementsStream(businessId: businessId, productId: widget.productId),
                                      builder: (context, snap) {
                                        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                                        if (!snap.hasData || snap.data!.isEmpty) return const Text('No procurements found');

                                        final filtered = snap.data!.where((d) {
                                          final created = parseTimestamp(d['createdAt']);
                                          return !created.isBefore(prov.start) && !created.isAfter(prov.end);
                                        }).toList();

                                        if (filtered.isEmpty) return const Text('No procurements in the selected range');

                                        return Column(
                                            children: filtered.map((d) {
                                          final created = parseTimestamp(d['createdAt']);
                                          return ListTile(
                                            title: Text('${d['quantity'] ?? ''} units @ ₦${(d['cost'] ?? 0).toStringAsFixed(2)}'),
                                            subtitle: Text('${DateFormat.yMMMd().add_jm().format(created)} • ${d['procurementId'] ?? ''}'),
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
