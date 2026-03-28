import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/routes.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/analytics_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/report_theme.dart';

class AggregatedReportsScreen extends StatefulWidget {
  const AggregatedReportsScreen({super.key});

  @override
  State<AggregatedReportsScreen> createState() =>
      _AggregatedReportsScreenState();
}

class _AggregatedReportsScreenState extends State<AggregatedReportsScreen> {
  DateTimeRange? _range;
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];

  Future<void> _loadAggregated() async {
    final businessProvider = context.read<BusinessProvider>();
    final analyticsProvider = context.read<AnalyticsProvider>();
    final businesses = businessProvider.userBusinesses;

    if (businesses.isEmpty) return;

    final range = _range ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 30)),
          end: DateTime.now(),
        );

    setState(() {
      _loading = true;
      _results = [];
    });

    double totalRevenue = 0.0;
    int totalTransactions = 0;

    for (final b in businesses) {
      analyticsProvider.setBusinessId(b.id);
      final model =
          await analyticsProvider.calculateAnalytics(range.start, range.end);
      if (model != null) {
        _results.add({
          'businessId': b.id,
          'businessName': b.name,
          'revenue': model.totalRevenue,
          'transactions': model.totalTransactions,
        });
        totalRevenue += model.totalRevenue;
        totalTransactions += model.totalTransactions;
      }
    }

    // Add combined summary at top
    _results.insert(0, {
      'businessId': '_combined',
      'businessName': 'All Businesses',
      'revenue': totalRevenue,
      'transactions': totalTransactions,
    });

    // sort results (combined stays first)
    final combined = _results.removeAt(0);
    _results.sort(
        (a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
    _results.insert(0, combined);

    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aggregated Reports')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: _range,
                    );
                    if (picked != null) setState(() => _range = picked);
                  },
                  icon: const Icon(Icons.date_range),
                  label: Text(_range == null
                      ? 'Select range'
                      : '${_range!.start.toLocal().toString().split(' ')[0]} → ${_range!.end.toLocal().toString().split(' ')[0]}'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _loadAggregated,
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Load Aggregated'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(Routes.businessSwitcher),
                  child: const Text('Switch Business'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_results.isNotEmpty)
              SizedBox(
                height: 160,
                child: _buildRevenueBarChart(),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: _results.isEmpty
                  ? const Center(
                      child:
                          Text('No data. Select range and tap Load Aggregated'))
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, idx) {
                        final r = _results[idx];
                        final isCombined = r['businessId'] == '_combined';
                        final revenue = (r['revenue'] as double);
                        final maxRevenue = _results
                            .where((e) => e['businessId'] != '_combined')
                            .fold<double>(
                                0.0,
                                (p, e) => p > (e['revenue'] as double)
                                    ? p
                                    : (e['revenue'] as double));

                        return ListTile(
                          tileColor:
                              isCombined ? Theme.of(context).cardColor : null,
                          title: Text(r['businessName'] ?? ''),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Transactions: ${r['transactions']}'),
                              const SizedBox(height: 8),
                              // simple bar visualization
                              LinearProgressIndicator(
                                value: maxRevenue == 0
                                    ? 0
                                    : (revenue / maxRevenue).clamp(0.0, 1.0),
                                minHeight: 8,
                                color: Theme.of(context).colorScheme.primary,
                                backgroundColor: Theme.of(context).dividerColor,
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('₦${revenue.toStringAsFixed(2)}'),
                              if (!isCombined)
                                Text(
                                    '${(maxRevenue == 0 ? 0 : (revenue / maxRevenue * 100)).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.color ??
                                            context.reportMutedText)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: _results.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _exportCsv,
              icon: const Icon(Icons.download),
              label: const Text('Export CSV'),
            ),
    );
  }

  Widget _buildRevenueBarChart() {
    final items =
        _results.where((r) => r['businessId'] != '_combined').toList();
    if (items.isEmpty) return const Center(child: Text('No chart data'));

    final maxRevenue = items.fold<double>(
        0.0,
        (prev, e) =>
            e['revenue'] as double > prev ? e['revenue'] as double : prev);

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < items.length; i++) {
      final e = items[i];
      final val = (e['revenue'] as double);
      groups.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: val,
          width: 16,
          borderRadius: BorderRadius.circular(6),
          color: Theme.of(context).colorScheme.primary,
        ),
      ]));
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revenue by Business',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: BarChart(
                BarChartData(
                  maxY: maxRevenue,
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: groups,
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(value.toStringAsFixed(0),
                                  style: Theme.of(context).textTheme.bodySmall);
                            })),
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= items.length)
                                return const SizedBox.shrink();
                              final label =
                                  (items[idx]['businessName'] as String? ?? '')
                                      .split(' ')
                                      .map((s) => s[0])
                                      .join();
                              return Text(label,
                                  style: Theme.of(context).textTheme.bodySmall);
                            })),
                  ),
                  gridData:
                      const FlGridData(show: true, drawVerticalLine: false),
                  barTouchData: const BarTouchData(enabled: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv() async {
    if (_results.isEmpty) return;
    final header = ['BusinessId,BusinessName,Revenue,Transactions'];
    final rows = _results
        .map((r) =>
            '${r['businessId']},"${r['businessName']}",${(r['revenue'] as double).toStringAsFixed(2)},${r['transactions']}')
        .toList();
    final content = (header + rows).join('\n');

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/aggregated_reports_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(content);
    await Share.shareXFiles([XFile(file.path)], text: 'Aggregated Reports CSV');
  }
}

