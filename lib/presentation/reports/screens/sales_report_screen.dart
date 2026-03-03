import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/reports_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/routes.dart';
import '../widgets/date_range_picker.dart';
import '../widgets/report_card.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  late TextEditingController _searchController;
  String? _lastBusinessId;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final businessId = context.read<BusinessProvider>().currentBusiness?.id ??
          authProvider.currentUser?.businessId;
      if (businessId != null && businessId.isNotEmpty) {
        context
            .read<ReportsProvider>()
            .subscribeToSalesReports(businessId: businessId);
        _lastBusinessId = businessId;
      }
    });
  }

  @override
  void dispose() {
    // cancel subscription on dispose
    context.read<ReportsProvider>().unsubscribeFromSalesReports();
    _searchController.dispose();
    super.dispose();
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
          title: const Text('Sales Report'),
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
            .subscribeToSalesReports(businessId: currentBusinessId);
      }
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sales Report'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
        actions: [
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

          final salesSummary = reportsProvider.getSalesSummary();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Range Picker
                DateRangePicker(
                  startDate: reportsProvider.salesStartDate,
                  endDate: reportsProvider.salesEndDate,
                  onDateRangeChanged: (start, end) {
                    final authProvider = context.read<AuthProvider>();
                    final businessId =
                        context.read<BusinessProvider>().currentBusiness?.id ??
                            authProvider.currentUser?.businessId;
                    reportsProvider.setSalesDateRange(start, end);
                    if (businessId != null && businessId.isNotEmpty) {
                      reportsProvider.subscribeToSalesReports(
                          businessId: businessId);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Search Field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by category...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 24),

                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: ReportCard(
                        title: 'Total Sales',
                        value:
                            '₦${(salesSummary['totalSales'] as double).toStringAsFixed(2)}',
                        icon: Icons.trending_up,
                        color: AppColors.success,
                        trend: salesSummary['trend'],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ReportCard(
                        title: 'Transactions',
                        value: '${salesSummary['totalTransactions']}',
                        icon: Icons.receipt,
                        color: AppColors.info,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ReportCard(
                        title: 'Average Sale',
                        value:
                            '₦${(salesSummary['averageSale'] as double).toStringAsFixed(2)}',
                        icon: Icons.calculate,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ReportCard(
                        title: 'Period',
                        value:
                            '${reportsProvider.salesStartDate.day}-${reportsProvider.salesEndDate.day}',
                        icon: Icons.calendar_today,
                        color: AppColors.primary,
                        subtitle: 'days',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Sales Trend Chart
                _buildChartSection(
                  title: 'Sales Trend',
                  data: reportsProvider.salesReports,
                  context: context,
                ),
                const SizedBox(height: 24),

                // Sales by Category
                _buildCategorySection(reportsProvider),
                const SizedBox(height: 24),

                // Payment Method Breakdown
                _buildPaymentMethodSection(reportsProvider),
                const SizedBox(height: 24),

                // Detailed Table
                _buildDetailedTable(reportsProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChartSection({
    required String title,
    required List<SaleReport> data,
    required BuildContext context,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.heading2),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildBarChart(data),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(List<SaleReport> data) {
    if (data.isEmpty) return const Center(child: Text('No data available'));

    final Map<String, double> dailyTotals = {};
    final Map<String, DateTime> dateMap = {};
    for (var report in data) {
      final dateKey =
          '${report.date.year}-${report.date.month.toString().padLeft(2, '0')}-${report.date.day.toString().padLeft(2, '0')}';
      dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + report.totalAmount;
      dateMap[dateKey] = report.date;
    }

    final sortedDates = dailyTotals.keys.toList()..sort();
    final last7Days = sortedDates.length > 7
        ? sortedDates.sublist(sortedDates.length - 7)
        : sortedDates;

    final maxAmount = dailyTotals.values.isEmpty
        ? 1.0
        : dailyTotals.values.reduce((a, b) => a > b ? a : b);

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < last7Days.length; i++) {
      final key = last7Days[i];
      final amount = dailyTotals[key] ?? 0;
      groups.add(
        BarChartGroupData(x: i, barRods: [
          BarChartRodData(
            toY: amount,
            width: 16,
            borderRadius: BorderRadius.circular(4),
            color: Theme.of(context).colorScheme.primary,
            backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxAmount,
                color: Theme.of(context).dividerColor),
          ),
        ]),
      );
    }

    return BarChart(BarChartData(
      maxY: maxAmount,
      alignment: BarChartAlignment.spaceEvenly,
      barGroups: groups,
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= last7Days.length)
                    return const SizedBox.shrink();
                  final dt = dateMap[last7Days[idx]];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text('${dt?.day}',
                        style: Theme.of(context).textTheme.bodySmall),
                  );
                },
                reservedSize: 24)),
      ),
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      barTouchData: const BarTouchData(enabled: true),
    ));
  }

  Widget _buildCategorySection(ReportsProvider reportsProvider) {
    final categories = <String, double>{};

    for (var report in reportsProvider.salesReports) {
      categories[report.category] =
          (categories[report.category] ?? 0) + report.totalAmount;
    }

    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalAmount = categories.values.reduce((a, b) => a + b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sales by Category', style: AppTextStyles.heading2),
            const SizedBox(height: 16),
            ...categories.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(entry.key)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: entry.value / totalAmount,
                          minHeight: 8,
                          backgroundColor: Colors.grey[300],
                          valueColor:
                              const AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('₦${entry.value.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedTable(ReportsProvider reportsProvider) {
    // Filter sales based on search term (category, cashier, product names)
    final query = _searchController.text.toLowerCase();
    final filteredReports = reportsProvider.salesReports.where((report) {
      if (query.isEmpty) return true;
      if (report.category.toLowerCase().contains(query)) return true;
      if (report.cashier.toLowerCase().contains(query)) return true;
      if (report.productNames.any((p) => p.toLowerCase().contains(query)))
        return true;
      return false;
    }).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Detailed Report', style: AppTextStyles.heading2),
                if (filteredReports.length !=
                    reportsProvider.salesReports.length)
                  Text(
                    '${filteredReports.length} of ${reportsProvider.salesReports.length}',
                    style: AppTextStyles.caption,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (filteredReports.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text('No sales matching your search'),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(
                      AppColors.primary.withOpacity(0.1)),
                  columns: const [
                    DataColumn(
                        label: Text('Date', style: AppTextStyles.labelSmall)),
                    DataColumn(
                        label:
                            Text('Products', style: AppTextStyles.labelSmall)),
                    DataColumn(
                        label: Text('Amount', style: AppTextStyles.labelSmall)),
                    DataColumn(
                        label: Text('Items', style: AppTextStyles.labelSmall)),
                    DataColumn(
                        label:
                            Text('Payment', style: AppTextStyles.labelSmall)),
                    DataColumn(
                        label:
                            Text('Cashier', style: AppTextStyles.labelSmall)),
                    DataColumn(
                        label:
                            Text('Customer', style: AppTextStyles.labelSmall)),
                    DataColumn(
                        label:
                            Text('Actions', style: AppTextStyles.labelSmall)),
                  ],
                  rows: filteredReports
                      .map(
                        (report) => DataRow(
                          cells: [
                            DataCell(Text(DateFormat('MMM dd, yyyy')
                                .format(report.date))),
                            DataCell(
                              SizedBox(
                                width: 260,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: report.products
                                          .map((p) => Chip(
                                                backgroundColor:
                                                    AppColors.lightGrey,
                                                label: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Flexible(
                                                        child: Text(
                                                            p['name']
                                                                    ?.toString() ??
                                                                'Item',
                                                            style: AppTextStyles
                                                                .body2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis)),
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppColors
                                                            .primaryLight
                                                            .withOpacity(0.15),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      child: Text(
                                                          'x${p['quantity'] ?? 1}',
                                                          style: AppTextStyles
                                                              .captionBold
                                                              .copyWith(
                                                                  color: AppColors
                                                                      .primary)),
                                                    ),
                                                  ],
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                    const SizedBox(height: 6),
                                    Text('${report.products.length} items',
                                        style: AppTextStyles.caption),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(Text(
                                '₦${report.totalAmount.toStringAsFixed(2)}',
                                style: AppTextStyles.priceSmall)),
                            DataCell(Text('${report.itemsCount}',
                                style: AppTextStyles.caption)),
                            DataCell(Chip(
                              backgroundColor: AppColors.successLight,
                              label: Text(report.paymentMethod,
                                  style: AppTextStyles.captionBold
                                      .copyWith(color: AppColors.success)),
                            )),
                            DataCell(Chip(
                              backgroundColor:
                                  AppColors.primaryLight.withOpacity(0.15),
                              label: Text(report.cashier,
                                  style: AppTextStyles.captionBold
                                      .copyWith(color: AppColors.primary)),
                            )),
                            DataCell(Text(report.customerName.isNotEmpty
                                ? report.customerName
                                : (report.customerId.isNotEmpty
                                    ? report.customerId
                                    : 'Walk-in'))),
                            DataCell(Row(
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      _showProductDetails(context, report),
                                  child: const Text('View'),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'View receipt',
                                  icon: const Icon(Icons.receipt_long),
                                  onPressed: () {
                                    Navigator.pushNamed(
                                        context, Routes.salesReceipt,
                                        arguments: {
                                          'saleId': report.receiptId ?? ''
                                        });
                                  },
                                ),
                              ],
                            )),
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
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Export As',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF (includes item rows)'),
              onTap: () async {
                Navigator.pop(context);
                final name = await context
                    .read<ReportsProvider>()
                    .exportSalesReportToPDF();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Exported PDF: $name')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('CSV (includes item rows)'),
              onTap: () async {
                Navigator.pop(context);
                final name = await context
                    .read<ReportsProvider>()
                    .exportSalesReportToCSV();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Exported CSV: $name')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showProductDetails(BuildContext ctx, SaleReport report) async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id ??
        context.read<AuthProvider>().currentUser?.businessId;
    if (businessId == null || businessId.isEmpty) return;

    showDialog(
      context: ctx,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Expanded(
                  child: Text(
                      'Products — ${DateFormat('MMM dd, yyyy').format(report.date)}',
                      style: AppTextStyles.heading5)),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: report.products.map((p) {
                  return FutureBuilder<int?>(
                    future: _fetchRemainingStock(businessId,
                        p['id']?.toString() ?? '', p['name']?.toString() ?? ''),
                    builder: (context, snapshot) {
                      final qty = p['quantity']?.toString() ?? '1';
                      final stock =
                          snapshot.connectionState == ConnectionState.waiting
                              ? 'loading...'
                              : (snapshot.hasData
                                  ? snapshot.data.toString()
                                  : 'unknown');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(p['name'] ?? 'Product',
                                    style: AppTextStyles.body2)),
                            const SizedBox(width: 8),
                            Text('Sold: $qty', style: AppTextStyles.caption),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text('Remaining: $stock',
                                  style: AppTextStyles.caption),
                            ),
                            const SizedBox(width: 8),
                            Text(
                                '₦${((p['unitPrice'] ?? 0) as double).toStringAsFixed(2)}',
                                style: AppTextStyles.captionBold),
                          ],
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
          ],
        );
      },
    );
  }

  Widget _buildPaymentMethodSection(ReportsProvider reportsProvider) {
    final paymentMethods = <String, double>{};

    for (var report in reportsProvider.salesReports) {
      paymentMethods[report.paymentMethod] =
          (paymentMethods[report.paymentMethod] ?? 0) + report.totalAmount;
    }

    if (paymentMethods.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalAmount = paymentMethods.values.reduce((a, b) => a + b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment Method Breakdown', style: AppTextStyles.heading2),
            const SizedBox(height: 16),
            ...paymentMethods.entries.map(
              (entry) {
                final percentage = (entry.value / totalAmount * 100);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(entry.key, style: AppTextStyles.body1),
                      ),
                      Expanded(
                        flex: 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: entry.value / totalAmount,
                            minHeight: 8,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation(
                              entry.key.toLowerCase().contains('cash')
                                  ? Colors.green[600]
                                  : entry.key.toLowerCase().contains('card')
                                      ? Colors.blue[600]
                                      : Colors.orange[600],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₦${entry.value.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('${percentage.toStringAsFixed(1)}%',
                                style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<int?> _fetchRemainingStock(
      String businessId, String productId, String productName) async {
    try {
      if (productId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessId)
            .collection('inventory')
            .doc(productId)
            .get();
        if (doc.exists) return (doc.data()?['quantity'] as num?)?.toInt();
      }

      // Fallback: query by name
      final query = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('inventory')
          .where('name', isEqualTo: productName)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty)
        return (query.docs.first.data()['quantity'] as num?)?.toInt();
      return null;
    } catch (e) {
      return null;
    }
  }
}

