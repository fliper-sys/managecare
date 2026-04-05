import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/reports_provider.dart';
import '../../../core/constants/routes.dart';
import '../../../core/utils/formatters.dart';
import '../widgets/date_range_picker.dart';
import '../widgets/report_card.dart';
import '../widgets/report_theme.dart';

class FinancialReportScreen extends StatefulWidget {
  const FinancialReportScreen({super.key});

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen> {
  String? _lastBusinessId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final businessId = context.read<BusinessProvider>().currentBusiness?.id ??
          authProvider.currentUser?.businessId;
      if (businessId != null && businessId.isNotEmpty) {
        context
            .read<ReportsProvider>()
            .subscribeToFinancialReports(businessId: businessId);
        _lastBusinessId = businessId;
      }
    });
  }

  @override
  void dispose() {
    context.read<ReportsProvider>().unsubscribeFromFinancialReports();
    super.dispose();
  }

  Future<Map<String, dynamic>> _getInventoryCosts(
      ReportsProvider reportsProvider) async {
    try {
      final inventorySummary = reportsProvider.getInventorySummary();
      // Calculate total cost from inventory (quantity * cost price)
      final totalItems = inventorySummary['totalItems'] as int? ?? 0;

      // In a real scenario, you'd fetch actual cost data
      // For now, using a placeholder that can be enhanced
      return {
        'totalCost': inventorySummary['inventoryValue'] as double? ?? 0.0,
        'itemCount': totalItems,
      };
    } catch (e) {
      return {
        'totalCost': 0.0,
        'itemCount': 0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final businessProvider = context.watch<BusinessProvider>();
    final currentBusinessId = businessProvider.currentBusiness?.id ??
        authProvider.currentUser?.businessId;
    if (currentBusinessId == null || currentBusinessId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Financial Report'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.business_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('No business selected',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, Routes.businessSelection),
                child: const Text('Select Business'),
              ),
            ],
          ),
        ),
      );
    }
    if (_lastBusinessId != currentBusinessId) {
      _lastBusinessId = currentBusinessId;
      if (currentBusinessId.isNotEmpty) {
        context
            .read<ReportsProvider>()
            .subscribeToFinancialReports(businessId: currentBusinessId);
      }
    }
    return Scaffold(
      backgroundColor: context.reportBackground,
      appBar: AppBar(
        title: const Text('Financial Report'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showProfitHelpDialog,
            tooltip: 'What is Gross vs Net profit?',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _showExportOptions(context),
          ),
        ],
      ),
      body: Consumer<ReportsProvider>(
        builder: (context, reportsProvider, _) {
          if (reportsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (reportsProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${reportsProvider.error}'),
                ],
              ),
            );
          }

          final financialSummary = reportsProvider.getFinancialSummary();

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Range Picker
                  DateRangePicker(
                    startDate: reportsProvider.financialStartDate,
                    endDate: reportsProvider.financialEndDate,
                    onDateRangeChanged: (start, end) {
                      final authProvider = context.read<AuthProvider>();
                      final businessId = context
                              .read<BusinessProvider>()
                              .currentBusiness
                              ?.id ??
                          authProvider.currentUser?.businessId;
                      reportsProvider.setFinancialDateRange(start, end);
                      // Regenerate report with new date range
                      if (businessId != null && businessId.isNotEmpty) {
                        reportsProvider.subscribeToFinancialReports(
                            businessId: businessId);
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // Financial Summary Cards
                  Row(
                    children: [
                      Text('Financial Summary', style: AppTextStyles.heading2),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Gross = Revenue - COGS; Net = Revenue - (COGS + Other Expenses)',
                        child: IconButton(
                          icon: const Icon(Icons.info_outline, size: 18),
                          onPressed: _showProfitHelpDialog,
                          tooltip: 'Gross vs Net profit',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ReportCard(
                          title: 'Total Revenue',
                          value: formatCurrency((financialSummary['totalRevenue'] as num?)?.toDouble() ?? 0.0),
                          icon: Icons.trending_up,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ReportCard(
                          title: 'Total Expenses',
                          value: formatCurrency((financialSummary['totalExpenses'] as num?)?.toDouble() ?? 0.0),
                          icon: Icons.trending_down,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // If current business is a barbershop, show payment method breakdown
                  Builder(builder: (ctx) {
                    final businessType = context.read<BusinessProvider>().currentBusiness?.businessType ?? '';
                    final isBarberBusiness = businessType == 'barber' || businessType == 'barbershop';
                    if (!isBarberBusiness) return const SizedBox.shrink();
                    return FutureBuilder<Map<String, double>>(
                      future: reportsProvider.getPaymentMethodBreakdown(businessId: currentBusinessId),
                      builder: (context, snap) {
                        if (!snap.hasData) return const SizedBox.shrink();
                        final map = snap.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            Text('Payment Method Breakdown', style: AppTextStyles.heading3),
                            const SizedBox(height: 8),
                            Row(
                              children: map.entries.map((e) => Expanded(
                                child: Column(
                                  children: [
                                    Text(e.key.toUpperCase(), style: AppTextStyles.caption),
                                    const SizedBox(height: 4),
                                    Text(formatCurrency(e.value), style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )).toList(),
                            ),
                          ],
                        );
                      }
                    );
                  }),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ReportCard(
                          title: 'Gross Profit',
                          value: reportsProvider.isComputingFinancials
                              ? 'Calculating...'
                              : formatCurrency((financialSummary['grossProfit'] as num?)?.toDouble() ?? 0.0),
                          icon: Icons.money_off, // indicates COGS adjusted
                          color: AppColors.primary,
                          subtitle: reportsProvider.isComputingFinancials
                              ? 'Processing...'
                              : '${(financialSummary['grossMargin'] as double).toStringAsFixed(1)}% margin',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ReportCard(
                          title: 'Net Profit',
                          value: reportsProvider.isComputingFinancials
                              ? 'Calculating...'
                              : formatCurrency((financialSummary['profit'] as num?)?.toDouble() ?? 0.0),
                          icon: Icons.trending_down, // net after expenses
                          color: AppColors.info,
                          subtitle: reportsProvider.isComputingFinancials
                              ? 'Processing...'
                              : '${(financialSummary['profitMargin'] as double).toStringAsFixed(1)}% margin',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Inventory Costs Card
                  FutureBuilder<Map<String, dynamic>>(
                    future: _getInventoryCosts(reportsProvider),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final inventoryCosts = snapshot.data ?? {};
                      final totalCost =
                          (inventoryCosts['totalCost'] as double?) ?? 0.0;
                      final itemCount =
                          (inventoryCosts['itemCount'] as int?) ?? 0;

                      return ReportCard(
                        title: 'Inventory Value (Cost)',
                        value: formatCurrency(totalCost),
                        icon: Icons.warehouse,
                        color: AppColors.warning,
                        subtitle: '$itemCount items in stock',
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Revenue Trend
                  _buildRevenueTrendChart(reportsProvider),
                  const SizedBox(height: 24),

                  // Expense Breakdown
                  _buildExpenseBreakdown(reportsProvider),
                  const SizedBox(height: 24),

                  // Monthly Comparison Table
                  _buildMonthlyTable(reportsProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRevenueTrendChart(ReportsProvider reportsProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Revenue Trend', style: AppTextStyles.heading2)),
                Tooltip(
                  message: 'Gross = Revenue - COGS; Net = Revenue - (COGS + Other Expenses)',
                  child: IconButton(
                    icon: const Icon(Icons.info_outline, size: 18),
                    onPressed: _showProfitHelpDialog,
                    tooltip: 'Profit help',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildRevenueChart(reportsProvider.financialReports),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfitHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Gross vs Net Profit'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Gross Profit = Revenue − Cost of Goods Sold (COGS)'),
                SizedBox(height: 8),
                Text('Net Profit = Revenue − (COGS + Other Expenses)'),
                SizedBox(height: 12),
                Text('Example:'),
                Text('• Revenue: ₦100,000'),
                Text('• COGS: ₦40,000 → Gross Profit: ₦60,000'),
                Text('• Other Expenses (rent, utilities, salaries): ₦20,000 → Net Profit: ₦40,000'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRevenueChart(List<FinancialReport> data) {
    if (data.isEmpty) return const Center(child: Text('No data available'));

    final maxRevenue = data.fold<double>(
        0, (max, report) => report.revenue > max ? report.revenue : max);

    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i].revenue));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxRevenue,
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 48,
                  getTitlesWidget: (value, meta) {
                    return Text(value.toStringAsFixed(0),
                        style: Theme.of(context).textTheme.bodySmall);
                  })),
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= data.length)
                      return const SizedBox.shrink();
                    return Text('${data[idx].month}',
                        style: Theme.of(context).textTheme.bodySmall);
                  },
                  reservedSize: 24)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.12)),
          )
        ],
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildExpenseBreakdown(ReportsProvider reportsProvider) {
    if (reportsProvider.financialReports.isEmpty) {
      return const SizedBox.shrink();
    }

    final firstReport = reportsProvider.financialReports.first;
    final totalExpenses = firstReport.expenses;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Expense Breakdown', style: AppTextStyles.heading2),
            const SizedBox(height: 16),
            _buildExpenseItem('Salaries', firstReport.salaries, totalExpenses),
            const Divider(),
            _buildExpenseItem(
                'Utilities', firstReport.utilities, totalExpenses),
            const Divider(),
            _buildExpenseItem(
                'Other',
                firstReport.expenses -
                    firstReport.salaries -
                    firstReport.utilities,
                totalExpenses),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseItem(String label, double amount, double total) {
    final percentage = total == 0 ? 0 : (amount / total) * 100;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('₦${amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 6,
              backgroundColor: Theme.of(context).dividerColor,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.error),
            ),
          ),
          const SizedBox(height: 2),
          Text('${percentage.toStringAsFixed(1)}%',
              style: AppTextStyles.caption
                  .copyWith(color: context.reportMutedText)),
        ],
      ),
    );
  }

  Widget _buildMonthlyTable(ReportsProvider reportsProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monthly Breakdown', style: AppTextStyles.heading2),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                    AppColors.primary.withOpacity(0.1)),
                columns: const [
                  DataColumn(label: Text('Month')),
                  DataColumn(label: Text('Revenue')),
                  DataColumn(label: Text('Expenses')),
                  DataColumn(label: Text('Profit')),
                  DataColumn(label: Text('Margin')),
                ],
                rows: reportsProvider.financialReports
                    .map(
                      (report) => DataRow(
                        cells: [
                          DataCell(Text('Month ${report.month}')),
                          DataCell(
                              Text('₦${report.revenue.toStringAsFixed(2)}')),
                          DataCell(
                              Text('₦${report.expenses.toStringAsFixed(2)}')),
                          DataCell(
                              Text('₦${report.profit.toStringAsFixed(2)}')),
                          DataCell(Text(
                              '${report.profitMargin.toStringAsFixed(1)}%')),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
    final pageContext = context;
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Export As',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF'),
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  final fileName = await pageContext
                      .read<ReportsProvider>()
                      .exportFinancialReportToPDF();
                  if (!mounted) return;
                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    SnackBar(
                      content: Text('Financial report exported: $fileName'),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    SnackBar(
                      content: Text('Failed to export financial report: $e'),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<Offset> points;
  final List<FinancialReport> data;
  final double maxRevenue;
  final double chartHeight;
  final Color gridColor;
  final Color labelColor;

  LineChartPainter({
    required this.points,
    required this.data,
    required this.maxRevenue,
    required this.chartHeight,
    this.gridColor = const Color(0x1A94A3B8),
    this.labelColor = const Color(0xFF64748B),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 4; i++) {
      final y = (chartHeight / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.length < 2) return;

    // Draw filled area under line
    final path = Path();
    path.moveTo(points.first.dx, chartHeight);
    for (var point in points) {
      path.lineTo(point.dx, point.dy);
    }
    path.lineTo(points.last.dx, chartHeight);
    path.close();
    canvas.drawPath(path, fillPaint);

    // Draw line
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }

    // Draw points and labels
    const radius = 4.0;
    final pointPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      // Draw point circle
      canvas.drawCircle(point, radius, pointPaint);

      // Draw label
      final label = 'M${data[i].month}';
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(color: labelColor, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(point.dx - textPainter.width / 2, chartHeight + 10),
      );

      // Draw value tooltip on hover (simplified - shows on top)
      if (i == 0 || i == points.length - 1) {
        final valueLabel = '₦${data[i].revenue.toStringAsFixed(0)}';
        textPainter.text = TextSpan(
          text: valueLabel,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(point.dx - textPainter.width / 2, point.dy - 20),
        );
      }
    }
  }

  @override
  bool shouldRepaint(LineChartPainter oldDelegate) => false;
}


