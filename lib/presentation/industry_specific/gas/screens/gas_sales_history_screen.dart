import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../providers/retail_provider.dart';
import '../../../../services/receipt_manager.dart';

class GasSalesHistoryScreen extends StatefulWidget {
  const GasSalesHistoryScreen({super.key});

  @override
  State<GasSalesHistoryScreen> createState() => _GasSalesHistoryScreenState();
}

class _GasSalesHistoryScreenState extends State<GasSalesHistoryScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _sales = [];
  double _totalAmount = 0.0;
  double _totalVolume = 0.0;
  int _transactions = 0;

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({
    DateTime? start,
    DateTime? end,
    int limit = 100,
  }) async {
    setState(() => _loading = true);
    final retail = context.read<RetailProvider>();
    final metrics = await retail.getFuelMetrics(start: start, end: end);
    final history =
        await retail.getFuelSalesHistory(start: start, end: end, limit: limit);

    setState(() {
      _totalAmount = metrics['totalAmount'] ?? 0.0;
      _totalVolume = metrics['totalVolume'] ?? 0.0;
      _transactions = metrics['transactions'] ?? 0;
      _sales = history;
      _loading = false;
    });
  }

  Future<void> _handleReceiptAction(
    BuildContext context,
    String action,
    String saleId,
  ) async {
    if (saleId.trim().isEmpty) return;

    if (action == 'view') {
      await Navigator.pushNamed(
        context,
        Routes.salesReceipt,
        arguments: saleId,
      );
      return;
    }

    final sale = await context.read<RetailProvider>().getSaleById(saleId);
    if (!context.mounted) return;
    if (sale == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load this receipt yet'),
        ),
      );
      return;
    }

    await ReceiptManager.handlePostSale(context, sale);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fuel Sales History')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(
                          () => _startDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                          ),
                        );
                      }
                    },
                    child: Text(
                      _startDate == null
                          ? 'Start date'
                          : DateFormat.yMd().format(_startDate!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(
                          () => _endDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            23,
                            59,
                            59,
                          ),
                        );
                      }
                    },
                    child: Text(
                      _endDate == null
                          ? 'End date'
                          : DateFormat.yMd().format(_endDate!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _loadData(start: _startDate, end: _endDate),
                  child: const Text('Load'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                    _loadData(limit: 500);
                  },
                  child: const Text('Load All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _metricCard('Revenue', 'NGN ${_totalAmount.toStringAsFixed(2)}'),
                const SizedBox(width: 8),
                _metricCard('Volume', '${_totalVolume.toStringAsFixed(3)} L'),
                const SizedBox(width: 8),
                _metricCard('Txns', '$_transactions'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _sales.isEmpty
                      ? const Center(child: Text('No fuel sales yet'))
                      : ListView.separated(
                          itemCount: _sales.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final sale = _sales[index];
                            final created = sale['createdAt'] as DateTime?;
                            final dateText = created != null
                                ? DateFormat.yMd().add_jm().format(created)
                                : (sale['createdAtRaw']?.toString() ?? '');
                            final saleId = sale['id']?.toString() ?? '';

                            return ListTile(
                              onTap: saleId.isEmpty
                                  ? null
                                  : () => Navigator.pushNamed(
                                        context,
                                        Routes.salesReceipt,
                                        arguments: saleId,
                                      ),
                              leading: saleId.isEmpty
                                  ? const CircleAvatar(
                                      child: Icon(Icons.local_gas_station),
                                    )
                                  : PopupMenuButton<String>(
                                      onSelected: (value) => _handleReceiptAction(
                                        context,
                                        value,
                                        saleId,
                                      ),
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'view',
                                          child: Text('View Receipt'),
                                        ),
                                        PopupMenuItem(
                                          value: 'reprint',
                                          child: Text('Reprint Receipt'),
                                        ),
                                      ],
                                      child: const CircleAvatar(
                                        child: Icon(Icons.receipt_long),
                                      ),
                                    ),
                              title: Text(
                                saleId.isEmpty ? 'Fuel sale' : 'Sale - $saleId',
                              ),
                              subtitle: Text(dateText),
                              trailing: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'NGN ${(sale['totalAmount'] ?? 0.0).toStringAsFixed(2)}',
                                    style: AppTextStyles.body1.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(sale['fuelVolume'] ?? 0.0).toStringAsFixed(3)} L',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: Theme.of(context).brightness == Brightness.light
              ? [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption),
            const SizedBox(height: 6),
            Text(value, style: AppTextStyles.heading5),
          ],
        ),
      ),
    );
  }
}
