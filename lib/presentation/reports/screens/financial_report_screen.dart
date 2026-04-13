import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/reports_provider.dart';
import '../../../services/financial_report_pdf_service.dart';
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

  String _formatMonthLabel(int month) {
    return DateFormat.MMM().format(DateTime(2000, month));
  }

  DateTime _parseTransactionDate(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.now();
    }
    return DateTime.now();
  }

  List<FinancialReportTransactionRow> _buildTransactionRows(
      ReportsProvider reportsProvider) {
    final rawTransactions = reportsProvider.getDetailedTransactions() ?? [];
    return rawTransactions.map((transaction) {
      return FinancialReportTransactionRow(
        date: _parseTransactionDate(transaction['date']),
        description: (transaction['description'] ?? 'Sale').toString(),
        type: (transaction['type'] ?? 'Sale').toString(),
        amount: ((transaction['amount'] ?? 0) as num).toDouble(),
        paymentMethod: (transaction['paymentMethod'] ?? 'N/A').toString(),
        cashier: (transaction['cashier'] ?? 'N/A').toString(),
        itemCount: (transaction['items'] as num?)?.toInt() ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  FinancialReportPdfData _buildPdfData({
    required ReportsProvider reportsProvider,
    required Map<String, double> paymentBreakdown,
  }) {
    final business = context.read<BusinessProvider>().currentBusiness;
    final authProvider = context.read<AuthProvider>();
    final financialSummary = reportsProvider.getFinancialSummary();
    final inventorySummary = reportsProvider.getInventorySummary();
    final periodRows = [...reportsProvider.financialReports]
      ..sort((a, b) => a.month.compareTo(b.month));

    return FinancialReportPdfData(
      businessName:
          business?.name ?? authProvider.currentUser?.fullName ?? 'Business',
      businessAddress: business?.address,
      businessPhone: business?.phone,
      businessEmail: business?.email,
      businessTaxId: business?.taxId,
      businessLogoUrl: business?.logoUrl,
      subscriptionTier: business?.subscriptionTier,
      businessClass: business?.businessClass,
      startDate: reportsProvider.financialStartDate,
      endDate: reportsProvider.financialEndDate,
      generatedAt: DateTime.now(),
      generatedBy: authProvider.currentUser?.fullName,
      totalRevenue:
          (financialSummary['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      totalCogs: (financialSummary['totalCogs'] as num?)?.toDouble() ?? 0.0,
      totalOperatingExpenses:
          (financialSummary['totalExpenses'] as num?)?.toDouble() ?? 0.0,
      grossProfit:
          (financialSummary['grossProfit'] as num?)?.toDouble() ?? 0.0,
      netProfit: (financialSummary['profit'] as num?)?.toDouble() ?? 0.0,
      grossMargin:
          (financialSummary['grossMargin'] as num?)?.toDouble() ?? 0.0,
      netProfitMargin:
          (financialSummary['profitMargin'] as num?)?.toDouble() ?? 0.0,
      inventoryValue:
          (inventorySummary['inventoryValue'] as num?)?.toDouble() ?? 0.0,
      inventoryItemCount: (inventorySummary['totalItems'] as num?)?.toInt() ?? 0,
      periods: periodRows
          .map(
            (report) => FinancialReportPeriodRow(
              label: _formatMonthLabel(report.month),
              revenue: report.revenue,
              cogs: report.cogs,
              operatingExpenses: report.expenses,
              salariesEstimate: report.salaries,
              utilitiesEstimate: report.utilities,
            ),
          )
          .toList(),
      transactions: _buildTransactionRows(reportsProvider),
      paymentBreakdown: paymentBreakdown,
    );
  }

  Future<void> _exportFinancialReport(
    FinancialReportPdfOptions options,
  ) async {
    final reportsProvider = context.read<ReportsProvider>();
    final authProvider = context.read<AuthProvider>();
    final businessProvider = context.read<BusinessProvider>();
    final businessId =
        businessProvider.currentBusiness?.id ?? authProvider.currentUser?.businessId;

    if (businessId == null || businessId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No business selected for export')),
      );
      return;
    }

    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Building your custom financial PDF...'),
            ],
          ),
        ),
      ),
    );

    try {
      Map<String, double> paymentBreakdown = <String, double>{};
      if (options.includePaymentBreakdown) {
        try {
          paymentBreakdown = await reportsProvider.getPaymentMethodBreakdown(
            businessId: businessId,
            start: reportsProvider.financialStartDate,
            end: reportsProvider.financialEndDate,
          );
        } catch (_) {
          paymentBreakdown = <String, double>{};
        }
      }

      final data = _buildPdfData(
        reportsProvider: reportsProvider,
        paymentBreakdown: paymentBreakdown,
      );

      final result = await FinancialReportPdfService.exportPdf(
        data: data,
        options: options,
        fileBaseName: options.title.trim().isEmpty
            ? 'Financial_Report'
            : options.title.trim(),
      );

      reportsProvider.addExportHistory(
        fileName: result.fileName,
        format: 'pdf',
        reportType: 'financial',
        bytes: result.bytes,
      );

      if (navigator.canPop()) {
        navigator.pop();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Financial report ready: ${result.fileName}'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (navigator.canPop()) {
        navigator.pop();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export financial report: $e'),
          backgroundColor: AppColors.error,
        ),
      );
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
                          subtitle: 'Operating expenses excluding Cost of Goods Sold (COGS)',
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
                  _buildEnhancedMonthlyTable(reportsProvider),
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
                    return Text(_formatMonthLabel(data[idx].month),
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

    final summary = reportsProvider.getFinancialSummary();
    final totalCogs = (summary['totalCogs'] as num?)?.toDouble() ?? 0.0;
    final totalOperating =
        (summary['totalExpenses'] as num?)?.toDouble() ?? 0.0;
    final totalTrackedExpenses =
        (summary['totalAllExpenses'] as num?)?.toDouble() ?? 0.0;
    final estimatedSalaries = reportsProvider.financialReports.fold<double>(
      0,
      (sum, report) => sum + report.salaries,
    );
    final estimatedUtilities = reportsProvider.financialReports.fold<double>(
      0,
      (sum, report) => sum + report.utilities,
    );

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
            Text(
              'COGS comes from sold inventory. Salaries and utilities are estimated from recorded operating expenses.',
              style:
                  AppTextStyles.caption.copyWith(color: context.reportMutedText),
            ),
            const SizedBox(height: 12),
            _buildExpenseBreakdownItem(
              'Cost of Goods Sold',
              totalCogs,
              totalTrackedExpenses,
            ),
            const Divider(),
            _buildExpenseBreakdownItem(
              'Operating Expenses',
              totalOperating,
              totalTrackedExpenses,
            ),
            const Divider(),
            _buildExpenseBreakdownItem(
              'Estimated Salaries',
              estimatedSalaries,
              totalTrackedExpenses,
            ),
            const Divider(),
            _buildExpenseBreakdownItem(
              'Estimated Utilities',
              estimatedUtilities,
              totalTrackedExpenses,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseBreakdownItem(String label, double amount, double total) {
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
              Text(
                formatCurrency(amount),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
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
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style:
                AppTextStyles.caption.copyWith(color: context.reportMutedText),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
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

  Widget _buildEnhancedMonthlyTable(ReportsProvider reportsProvider) {
    final monthlyReports = [...reportsProvider.financialReports]
      ..sort((a, b) => a.month.compareTo(b.month));

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
                  AppColors.primary.withOpacity(0.1),
                ),
                columns: const [
                  DataColumn(label: Text('Month')),
                  DataColumn(label: Text('Revenue')),
                  DataColumn(label: Text('COGS')),
                  DataColumn(label: Text('OpEx')),
                  DataColumn(label: Text('Gross')),
                  DataColumn(label: Text('Net')),
                  DataColumn(label: Text('Margin')),
                ],
                rows: monthlyReports
                    .map(
                      (report) => DataRow(
                        cells: [
                          DataCell(Text(_formatMonthLabel(report.month))),
                          DataCell(Text(formatCurrency(report.revenue))),
                          DataCell(Text(formatCurrency(report.cogs))),
                          DataCell(Text(formatCurrency(report.expenses))),
                          DataCell(Text(formatCurrency(report.grossProfit))),
                          DataCell(
                            Text(
                              formatCurrency(report.profit),
                              style: TextStyle(
                                color: report.profit >= 0
                                    ? AppColors.success
                                    : AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DataCell(
                            Text('${report.profitMargin.toStringAsFixed(1)}%'),
                          ),
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

  // ignore: unused_element
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

  Future<void> _showExportOptions(BuildContext context) async {
    final reportsProvider = context.read<ReportsProvider>();
    final transactionCount = reportsProvider.getDetailedTransactions()?.length ?? 0;

    final options = await showModalBottomSheet<FinancialReportPdfOptions>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FinancialReportExportSheet(
        initialOptions: const FinancialReportPdfOptions(),
        startDate: reportsProvider.financialStartDate,
        endDate: reportsProvider.financialEndDate,
        monthCount: reportsProvider.financialReports.length,
        transactionCount: transactionCount,
      ),
    );

    if (!mounted || options == null) return;
    await _exportFinancialReport(options);
  }
}

class _FinancialReportExportSheet extends StatefulWidget {
  final FinancialReportPdfOptions initialOptions;
  final DateTime startDate;
  final DateTime endDate;
  final int monthCount;
  final int transactionCount;

  const _FinancialReportExportSheet({
    required this.initialOptions,
    required this.startDate,
    required this.endDate,
    required this.monthCount,
    required this.transactionCount,
  });

  @override
  State<_FinancialReportExportSheet> createState() =>
      _FinancialReportExportSheetState();
}

class _FinancialReportExportSheetState
    extends State<_FinancialReportExportSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late FinancialReportPdfOptions _options;

  @override
  void initState() {
    super.initState();
    _options = widget.initialOptions;
    _titleController = TextEditingController(text: widget.initialOptions.title);
    _noteController = TextEditingController(text: widget.initialOptions.note);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${DateFormat('dd MMM yyyy').format(widget.startDate)} - ${DateFormat('dd MMM yyyy').format(widget.endDate)}';

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: context.reportSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.reportBorder,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Custom Financial PDF',
                style: AppTextStyles.heading3,
              ),
              const SizedBox(height: 6),
              Text(
                'The export uses the date range currently selected on this page.',
                style: AppTextStyles.body2
                    .copyWith(color: context.reportMutedText),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.calendar_today_outlined,
                    label: dateLabel,
                  ),
                  _InfoChip(
                    icon: Icons.bar_chart_outlined,
                    label: '${widget.monthCount} monthly records',
                  ),
                  _InfoChip(
                    icon: Icons.receipt_long_outlined,
                    label: '${widget.transactionCount} transactions loaded',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Report title',
                  hintText: 'Financial Performance Report',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Prepared notes',
                  hintText:
                      'Optional commentary to include at the top of the PDF',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.reportBorder),
                ),
                child: Column(
                  children: [
                    _ExportSwitchTile(
                      title: 'Performance snapshot',
                      subtitle: 'Revenue, margins, expenses, and inventory value',
                      value: _options.includeSummary,
                      onChanged: (value) => setState(
                        () => _options =
                            _options.copyWith(includeSummary: value),
                      ),
                    ),
                    const Divider(height: 1),
                    _ExportSwitchTile(
                      title: 'Insights',
                      subtitle: 'Auto-generated summary observations',
                      value: _options.includeInsights,
                      onChanged: (value) => setState(
                        () => _options =
                            _options.copyWith(includeInsights: value),
                      ),
                    ),
                    const Divider(height: 1),
                    _ExportSwitchTile(
                      title: 'Expense structure',
                      subtitle: 'COGS, operating expenses, and estimates',
                      value: _options.includeExpenseBreakdown,
                      onChanged: (value) => setState(
                        () => _options = _options.copyWith(
                          includeExpenseBreakdown: value,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    _ExportSwitchTile(
                      title: 'Payment mix',
                      subtitle: 'How revenue is distributed by payment method',
                      value: _options.includePaymentBreakdown,
                      onChanged: (value) => setState(
                        () => _options = _options.copyWith(
                          includePaymentBreakdown: value,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    _ExportSwitchTile(
                      title: 'Inventory snapshot',
                      subtitle: 'Current stock value and item count',
                      value: _options.includeInventorySummary,
                      onChanged: (value) => setState(
                        () => _options = _options.copyWith(
                          includeInventorySummary: value,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    _ExportSwitchTile(
                      title: 'Monthly table',
                      subtitle: 'Month-by-month revenue, COGS, and profit',
                      value: _options.includeMonthlyBreakdown,
                      onChanged: (value) => setState(
                        () => _options = _options.copyWith(
                          includeMonthlyBreakdown: value,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    _ExportSwitchTile(
                      title: 'Transaction ledger',
                      subtitle:
                          'Append the most recent loaded transactions to the PDF',
                      value: _options.includeTransactions,
                      onChanged: (value) => setState(
                        () => _options = _options.copyWith(
                          includeTransactions: value,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(
                          _options.copyWith(
                            title: _titleController.text.trim().isEmpty
                                ? 'Financial Performance Report'
                                : _titleController.text.trim(),
                            note: _noteController.text.trim(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Generate PDF'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.reportBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: context.reportMutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ExportSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      title: Text(title, style: AppTextStyles.body2),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.caption.copyWith(color: context.reportMutedText),
      ),
      activeColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
      textDirection: ui.TextDirection.ltr,
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
