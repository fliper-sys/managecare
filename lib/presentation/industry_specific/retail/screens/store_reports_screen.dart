import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/reports_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';

class StoreReportsScreen extends StatefulWidget {
  const StoreReportsScreen({super.key});

  @override
  State<StoreReportsScreen> createState() => _StoreReportsScreenState();
}

class _StoreReportsScreenState extends State<StoreReportsScreen> {
  DateTimeRange? _range;
  bool _loading = false;
  List<StoreSales> _breakdown = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );
    _loadBreakdown();
  }

  Future<void> _loadBreakdown() async {
    setState(() => _loading = true);
    try {
      final provider = context.read<ReportsProvider>();
      final results = await provider.getStoreSalesBreakdown(
        start: _range?.start,
        end: _range?.end,
      );
      if (mounted) setState(() => _breakdown = results);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load store reports: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _breakdown.fold(0.0, (s, e) => s + e.total);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Per-Store Sales Report'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBreakdown,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date range: ${_range?.start.toLocal().toIso8601String().split('T').first} - ${_range?.end.toLocal().toIso8601String().split('T').first}', style: AppTextStyles.body2),
            const SizedBox(height: 12),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading)
              Expanded(
                child: _breakdown.isEmpty
                    ? const Center(child: Text('No sales for selected period'))
                    : ListView.builder(
                        itemCount: _breakdown.length,
                        itemBuilder: (context, i) {
                          final s = _breakdown[i];
                          final pct = total > 0 ? (s.total / total) * 100 : 0;
                          return ListTile(
                            title: Text(s.storeName),
                            subtitle: Text('Store ID: ${s.storeId}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('\u20a6${s.total.toStringAsFixed(2)}', style: AppTextStyles.heading5),
                                Text('${pct.toStringAsFixed(1)}%')
                              ],
                            ),
                          );
                        },
                      ),
              ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: AppTextStyles.heading5),
                  Text('\u20a6${total.toStringAsFixed(2)}', style: AppTextStyles.heading4),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
