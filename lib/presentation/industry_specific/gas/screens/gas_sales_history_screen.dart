import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../providers/retail_provider.dart';

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

  Future<void> _loadData({DateTime? start, DateTime? end, int limit = 100}) async {
    setState(() => _loading = true);
    final retail = context.read<RetailProvider>();
    final metrics = await retail.getFuelMetrics(start: start, end: end);
    final history = await retail.getFuelSalesHistory(start: start, end: end, limit: limit);

    setState(() {
      _totalAmount = metrics['totalAmount'] ?? 0.0;
      _totalVolume = metrics['totalVolume'] ?? 0.0;
      _transactions = metrics['transactions'] ?? 0;
      _sales = history;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fuel Sales History')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date range controls
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(context: context, initialDate: _startDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now());
                    if (picked != null) {
                      setState(() => _startDate = DateTime(picked.year, picked.month, picked.day));
                    }
                  },
                  child: Text(_startDate == null ? 'Start date' : DateFormat.yMd().format(_startDate!)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(context: context, initialDate: _endDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now());
                    if (picked != null) {
                      setState(() => _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
                    }
                  },
                  child: Text(_endDate == null ? 'End date' : DateFormat.yMd().format(_endDate!)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: () => _loadData(start: _startDate, end: _endDate), child: const Text('Load')),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () { setState(() { _startDate = null; _endDate = null; }); _loadData(limit: 500); }, child: const Text('Load All')),
            ]),
            const SizedBox(height: 12),

            Row(
              children: [
                _metricCard('Revenue', '₦${_totalAmount.toStringAsFixed(2)}'),
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
                          itemBuilder: (ctx, i) {
                            final s = _sales[i];
                            final created = s['createdAt'] as DateTime?;
                            final dateStr = created != null
                                ? DateFormat.yMd().add_jm().format(created)
                                : (s['createdAtRaw']?.toString() ?? '');
                            return ListTile(
                              title: Text('Sale • ${s['id'] ?? ''}'),
                              subtitle: Text(dateStr),
                              trailing: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('₦${(s['totalAmount'] ?? 0.0).toStringAsFixed(2)}', style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('${(s['fuelVolume'] ?? 0.0).toStringAsFixed(3)} L', style: AppTextStyles.caption),
                                ],
                              ),
                            );
                          },
                          separatorBuilder: (_, __) => const Divider(),
                          itemCount: _sales.length,
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
          boxShadow: Theme.of(context).brightness == Brightness.light ? [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 5, offset: const Offset(0, 2))] : [],
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
