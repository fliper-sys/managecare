import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/currency.dart';
import '../providers/barber_shop_provider.dart';

class BarberShopSalesHistoryScreen extends StatefulWidget {
  const BarberShopSalesHistoryScreen({super.key});

  @override
  State<BarberShopSalesHistoryScreen> createState() => _BarberShopSalesHistoryScreenState();
}

class _BarberShopSalesHistoryScreenState extends State<BarberShopSalesHistoryScreen> {
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BarberShopProvider>();
    final sales = provider.sales;

    final filtered = (_range == null)
        ? sales
        : sales.where((s) => s.saleDate.isAfter(_range!.start.subtract(const Duration(seconds:1))) && s.saleDate.isBefore(_range!.end.add(const Duration(seconds:1)))).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _pickRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.loadSales(),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: filtered.isEmpty
            ? const Center(child: Text('No sales found'))
            : ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final s = filtered[i];
                  return Card(
                    child: ListTile(
                      title: Text(s.clientName),
                      subtitle: Text('${s.barberName} - ${s.paymentMethod}'),
                      trailing: Text(formatCurrency(s.total)),
                      onTap: () => _showSaleDetails(s),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _range = picked);
  }

  void _showSaleDetails(dynamic sale) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sale ${sale.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client: ${sale.clientName}'),
            Text('Barber: ${sale.barberName}'),
            Text('Payment: ${sale.paymentMethod}'),
            Text('Total: ${formatCurrency(sale.total)}'),
            const SizedBox(height: 8),
            const Text('Services:'),
            ...sale.services.map<Widget>(
              (sv) => Text(
                '${sv['serviceName']} - ${formatCurrency(((sv['price'] ?? 0) as num).toDouble())}',
              ),
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
