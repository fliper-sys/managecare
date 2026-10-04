import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/currency.dart';
import '../../../../data/repositories/sales_repository_supabase.dart';
import '../../../../providers/business_provider.dart';

class DrinkOrdersHistoryScreen extends StatefulWidget {
  const DrinkOrdersHistoryScreen({super.key});

  @override
  State<DrinkOrdersHistoryScreen> createState() =>
      _DrinkOrdersHistoryScreenState();
}

class _DrinkOrdersHistoryScreenState extends State<DrinkOrdersHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _salesFuture;
  String _period = 'today';
  DateTime? _customDate;

  @override
  void initState() {
    super.initState();
    _salesFuture = _loadBarSales();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bar Sales History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _salesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load bar sales: ${snapshot.error}'));
          }

          final sales = _filterSales(
            snapshot.data ?? const <Map<String, dynamic>>[],
          );
          final total = sales.fold<double>(
            0,
            (sum, sale) => sum + _saleTotal(sale),
          );
          final paymentTotals = _paymentTotals(sales);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                DropdownButtonFormField<String>(
                  value: _period,
                  decoration: const InputDecoration(labelText: 'Date range'),
                  items: const [
                    DropdownMenuItem(value: 'today', child: Text('Today')),
                    DropdownMenuItem(value: 'week', child: Text('This week')),
                    DropdownMenuItem(value: 'month', child: Text('This month')),
                    DropdownMenuItem(value: 'custom', child: Text('Select date')),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    if (value == 'custom') {
                      final date = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDate: _customDate ?? DateTime.now(),
                      );
                      if (date == null) return;
                      setState(() {
                        _period = value;
                        _customDate = date;
                      });
                    } else {
                      setState(() => _period = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryValue(label: 'Sales', value: '${sales.length}'),
                        _SummaryValue(
                          label: 'Total',
                          value: formatCurrency(total),
                        ),
                        _SummaryValue(
                          label: 'Cash',
                          value: formatCurrency(paymentTotals['cash']!),
                        ),
                        _SummaryValue(
                          label: 'Card',
                          value: formatCurrency(paymentTotals['card']!),
                        ),
                        _SummaryValue(
                          label: 'Mixed',
                          value: formatCurrency(paymentTotals['mixed']!),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (sales.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No bar sales for this period')),
                  )
                else
                  ...sales.asMap().entries.expand((entry) {
                    final sale = entry.value;
                    final items = (sale['items'] as List?) ?? const [];
                    final payment = (sale['payment_method'] ??
                            sale['paymentMethod'] ??
                            'cash')
                        .toString();
                    final created = _saleDate(sale)
                        .toLocal()
                        .toString()
                        .replaceFirst('T', ' ')
                        .split('.')
                        .first;
                    return [
                      ListTile(
                        leading: const Icon(Icons.local_bar_outlined),
                        title: Text(
                          'Sale #${sale['id'] ?? entry.key + 1}',
                          style: AppTextStyles.subtitle1,
                        ),
                        subtitle: Text(
                          '${items.length} item${items.length == 1 ? '' : 's'} • '
                          '${payment.toUpperCase()} • $created',
                        ),
                        trailing: Text(
                          formatCurrency(_saleTotal(sale)),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onTap: () => _showSaleDetails(context, sale, items),
                      ),
                      const Divider(),
                    ];
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _filterSales(List<Map<String, dynamic>> sales) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;
    if (_period == 'custom' && _customDate != null) {
      start = DateTime(_customDate!.year, _customDate!.month, _customDate!.day);
      end = start.add(const Duration(days: 1));
    } else if (_period == 'week') {
      start = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
    } else if (_period == 'month') {
      start = DateTime(now.year, now.month);
    } else {
      start = DateTime(now.year, now.month, now.day);
    }
    return sales.where((sale) {
      final date = _saleDate(sale);
      return !date.isBefore(start) && date.isBefore(end);
    }).toList();
  }

  DateTime _saleDate(Map<String, dynamic> sale) {
    return DateTime.tryParse(
          (sale['created_at'] ?? sale['createdAt'] ?? '').toString(),
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  double _saleTotal(Map<String, dynamic> sale) {
    final value = sale['final_amount'] ??
        sale['finalAmount'] ??
        sale['total_amount'] ??
        sale['total'] ??
        0;
    return double.tryParse(value.toString()) ?? 0;
  }

  Map<String, double> _paymentTotals(List<Map<String, dynamic>> sales) {
    final totals = {'cash': 0.0, 'card': 0.0, 'mixed': 0.0};
    for (final sale in sales) {
      final breakdown = sale['payment_breakdown'] ?? sale['paymentBreakdown'];
      final allocations = <String, double>{};
      if (breakdown is String) {
        try {
          final decoded = jsonDecode(breakdown);
          if (decoded is List) {
            for (final entry in decoded.whereType<Map>()) {
              final method = (entry['method'] ?? entry['paymentMethod'] ?? '')
                  .toString()
                  .toLowerCase();
              final amount = double.tryParse(
                    (entry['amount'] ?? entry['value'] ?? 0).toString(),
                  ) ??
                  0;
              if (amount > 0) allocations[method] = amount;
            }
          }
        } catch (_) {}
      } else if (breakdown is List) {
        for (final entry in breakdown.whereType<Map>()) {
          final method = (entry['method'] ?? entry['paymentMethod'] ?? '')
              .toString()
              .toLowerCase();
          final amount = double.tryParse(
                (entry['amount'] ?? entry['value'] ?? 0).toString(),
              ) ??
              0;
          if (amount > 0) allocations[method] = amount;
        }
      }

      if (allocations.isNotEmpty) {
        final amount = allocations.values.fold<double>(0, (sum, value) => sum + value);
        final methods = allocations.keys.toList();
        if (methods.length > 1) {
          totals['mixed'] = totals['mixed']! + amount;
        } else if (_isCardMethod(methods.first)) {
          totals['card'] = totals['card']! + amount;
        } else {
          totals['cash'] = totals['cash']! + amount;
        }
        continue;
      }

      final method = (sale['payment_method'] ?? sale['paymentMethod'] ?? 'cash')
          .toString()
          .toLowerCase();
      final amount = _saleTotal(sale);
      if (method.contains('mixed') || method.contains('split')) {
        totals['mixed'] = totals['mixed']! + amount;
      } else if (_isCardMethod(method)) {
        totals['card'] = totals['card']! + amount;
      } else {
        totals['cash'] = totals['cash']! + amount;
      }
    }
    return totals;
  }

  bool _isCardMethod(String method) {
    return method.contains('card') ||
        method == 'pos' ||
        method.contains('debit') ||
        method.contains('credit');
  }

  Future<List<Map<String, dynamic>>> _loadBarSales() async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return [];

    final rows = await SalesRepositorySupabase().getSales(businessId);
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((sale) {
          final type = (sale['sale_type'] ?? sale['saleType'] ?? '')
              .toString()
              .toLowerCase();
          return type == 'bar' || type == 'drink';
        })
        .toList();
  }

  Future<void> _refresh() async {
    setState(() => _salesFuture = _loadBarSales());
    await _salesFuture;
  }

  void _showSaleDetails(
    BuildContext context,
    Map<String, dynamic> sale,
    List<dynamic> items,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bar Sale Details', style: AppTextStyles.heading5),
              const SizedBox(height: 8),
              ...items.map((raw) {
                final item = raw is Map ? Map<String, dynamic>.from(raw) : {};
                final name = (item['product_name'] ?? item['productName'] ??
                        'Drink')
                    .toString();
                final quantity = item['quantity'] ?? 0;
                final amount = (item['total'] as num?)?.toDouble() ?? 0;
                return ListTile(
                  dense: true,
                  title: Text(name),
                  subtitle: Text('Quantity: $quantity'),
                  trailing: Text(formatCurrency(amount)),
                );
              }),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _SummaryValue extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
