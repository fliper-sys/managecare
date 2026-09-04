import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/constants/routes.dart';
import '../../../core/access_control.dart';
import '../../../core/utils/worker_permissions.dart';
import '../../../providers/reports_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/auth_provider.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/formatters.dart';
import '../widgets/report_theme.dart';

class ReportsDashboardScreen extends StatefulWidget {
  const ReportsDashboardScreen({super.key});

  @override
  State<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends State<ReportsDashboardScreen> {
  String _selectedPeriod = 'month';
  String? _lastBusinessId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final businessProvider = context.read<BusinessProvider>();
      final authProvider = context.read<AuthProvider>();
      final businessId = businessProvider.currentBusiness?.id ??
          authProvider.currentUser?.businessId;
      if (businessId != null && businessId.isNotEmpty) {
        _loadReports(businessId);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadReports(String businessId) async {
    final reportsProvider = context.read<ReportsProvider>();
    await reportsProvider.generateSalesReport(businessId: businessId);
    await reportsProvider.generateFinancialReport(businessId: businessId);
    await reportsProvider.generateInventoryReport(businessId: businessId);
    await reportsProvider.generateExpenseReport(businessId: businessId);
    await reportsProvider.generateCustomerReport(businessId: businessId);
  }

  String _formatReadableDate(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final dt = DateTime.tryParse(raw) ??
          DateTime.fromMillisecondsSinceEpoch(int.tryParse(raw) ?? 0);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays == 0) {
        final time = DateFormat('h:mm a').format(dt);
        return 'Today, $time';
      }
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return DateFormat('yyyy-MM-dd').format(dt);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final businessProvider = context.watch<BusinessProvider>();
    final currentBusinessId = businessProvider.currentBusiness?.id ??
        authProvider.currentUser?.businessId;
    final businessType =
        businessProvider.currentBusiness?.businessType.toLowerCase() ?? '';
    final isFuelStation = businessType.contains('gas') ||
        businessType.contains('petroleum') ||
        businessType.contains('petrol') ||
        businessType.contains('filling');
    final isPetroleumStation = businessType.contains('petroleum') ||
        businessType.contains('petrol') ||
        businessType.contains('filling');
    final role =
        WorkerPermissions.normalizeRole(authProvider.currentUser?.role ?? '');
    final hasGlobalStationAccess = authProvider.currentUser?.isOwner == true ||
        ['owner', 'admin', 'sub_admin', 'manager', 'fuel_manager']
            .contains(role);
    final normalizedBusinessType =
        businessType.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final isBakery = normalizedBusinessType == 'bakery' ||
        normalizedBusinessType == 'bakeryshop' ||
        normalizedBusinessType == 'bakeshop';
    if (currentBusinessId == null || currentBusinessId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Reports & Analytics'),
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
      Future.microtask(() {
        if (currentBusinessId.isNotEmpty) {
          _loadReports(currentBusinessId);
        }
      });
    }
    if (!AccessControl.canViewReports(context)) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Reports & Analytics'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
                'Access denied: Reports are available to business administrators and owners only.'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.reportBackground,
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            // Period Selector
            Text(
              'Report Period',
              style:
                  AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: ['day', 'week', 'month', 'year'].map((period) {
                final isSelected = _selectedPeriod == period;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedPeriod = period);

                      // Calculate date range based on selected period
                      final now = DateTime.now();
                      DateTime startDate;
                      DateTime endDate = now;

                      switch (period) {
                        case 'day':
                          startDate = DateTime(now.year, now.month, now.day);
                          endDate = DateTime(
                              now.year, now.month, now.day, 23, 59, 59);
                          break;
                        case 'week':
                          final weekStart =
                              now.subtract(Duration(days: now.weekday - 1));
                          startDate = DateTime(
                              weekStart.year, weekStart.month, weekStart.day);
                          break;
                        case 'month':
                          startDate = DateTime(now.year, now.month, 1);
                          break;
                        case 'year':
                          startDate = DateTime(now.year, 1, 1);
                          break;
                        default:
                          startDate = now.subtract(const Duration(days: 30));
                      }

                      // Update date range and refresh both reports
                      final reportsProvider = context.read<ReportsProvider>();
                      reportsProvider.setSalesDateRange(startDate, endDate);
                      reportsProvider.setFinancialDateRange(startDate, endDate);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : context.reportChipSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : context.reportBorder,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          period[0].toUpperCase() + period.substring(1),
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : context.reportMutedText,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Key Metrics Overview
            Text(
              'Key Metrics',
              style:
                  AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Consumer<ReportsProvider>(
              builder: (context, reportsProvider, _) {
                final salesSummary = reportsProvider.getSalesSummary();
                final financialSummary = reportsProvider.getFinancialSummary();

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            title: 'Total Revenue',
                            value: formatCurrency((financialSummary['totalRevenue'] as num?)?.toDouble() ?? 0.0, decimalDigits: 0),
                            change:
                                '+${(financialSummary['revenueChange'] ?? 0).toStringAsFixed(1)}%',
                            isPositive: true,
                            icon: Icons.trending_up,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            title: 'Total Expenses',
                            value: formatCurrency((financialSummary['totalExpenses'] as num?)?.toDouble() ?? 0.0, decimalDigits: 0),
                            change:
                                '+${(financialSummary['expensesChange'] ?? 0).toStringAsFixed(1)}%',
                            isPositive: false,
                            icon: Icons.trending_down,                          tooltip: 'Total operating expenses for the selected period. Excludes Cost of Goods Sold (COGS).',                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            title: 'Gross Profit',
                            value: reportsProvider.isComputingFinancials ? 'Calculating...' : formatCurrency((financialSummary['grossProfit'] as num?)?.toDouble() ?? 0.0, decimalDigits: 0),
                            change:
                                '+${(financialSummary['grossChange'] ?? 0).toStringAsFixed(1)}%',
                            isPositive: (financialSummary['grossProfit'] ?? 0) >= 0,
                            icon: Icons.money_off,
                            tooltip: 'Gross = Revenue - Cost of Goods Sold (COGS)',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            title: 'Net Profit',
                            value: reportsProvider.isComputingFinancials ? 'Calculating...' : formatCurrency((financialSummary['netProfit'] as num?)?.toDouble() ?? (financialSummary['profit'] as num?)?.toDouble() ?? 0.0, decimalDigits: 0),
                            change:
                                '+${(financialSummary['profitChange'] ?? 0).toStringAsFixed(1)}%',
                            isPositive: ((financialSummary['netProfit'] ?? financialSummary['profit']) ?? 0) >= 0,
                            icon: Icons.trending_down,
                            tooltip: 'Net = Revenue - (COGS + Other Expenses)',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            title: 'Transactions',
                            value: '${salesSummary['totalTransactions'] ?? 0}',
                            change:
                                '+${(salesSummary['transactionChange'] ?? 0).toStringAsFixed(1)}%',
                            isPositive: true,
                            icon: Icons.receipt,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Report Categories
            Text(
              'Generate Reports',
              style:
                  AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _ReportCategoryCard(
              title: 'Sales Report',
              description: 'Detailed analysis of sales performance',
              icon: Icons.trending_up,
              color: AppColors.primary,
              onTap: () => Navigator.pushNamed(context, Routes.salesReport),
            ),
            const SizedBox(height: 12),
            _ReportCategoryCard(
              title: 'Financial Report',
              description: 'Revenue, expenses, and profit analysis',
              icon: Icons.account_balance,
              color: AppColors.success,
              onTap: () => Navigator.pushNamed(context, Routes.financialReport),
            ),
            const SizedBox(height: 12),
            _ReportCategoryCard(
              title: 'Inventory Report',
              description: 'Stock levels and inventory management',
              icon: Icons.inventory_2,
              color: AppColors.info,
              onTap: () => Navigator.pushNamed(context, Routes.inventoryReport),
            ),
            const SizedBox(height: 12),
            _ReportCategoryCard(
              title: 'Expense Report',
              description: 'Track and manage business expenses',
              icon: Icons.receipt_long,
              color: Colors.orange,
              onTap: () => Navigator.pushNamed(context, Routes.expenseReport),
            ),
            const SizedBox(height: 12),
            _ReportCategoryCard(
              title: 'Customer Report',
              description: 'Customer behavior and purchase patterns',
              icon: Icons.people,
              color: AppColors.warning,
              onTap: () => Navigator.pushNamed(context, Routes.customerReport),
            ),
            const SizedBox(height: 12),
            _ReportCategoryCard(
              title: 'Export Report',
              description: 'Export data to various formats',
              icon: Icons.download,
              color: AppColors.error,
              onTap: () => Navigator.pushNamed(context, Routes.exportReport),
            ),
            if (isFuelStation) ...[
              const SizedBox(height: 12),
              _FuelStationReportSplitCard(businessId: currentBusinessId),
            ],
            if (isPetroleumStation && hasGlobalStationAccess) ...[
              const SizedBox(height: 12),
              _ReportCategoryCard(
                title: 'Petroleum Cash Tracking',
                description:
                    'Approved pump cash, bank deposits, admin cash and balance',
                icon: Icons.payments_outlined,
                color: Colors.green.shade700,
                onTap: () =>
                    Navigator.pushNamed(context, Routes.petroleumCashTracking),
              ),
              const SizedBox(height: 12),
              _ReportCategoryCard(
                title: 'Petroleum Bank Deposits',
                description:
                    'Deposited cash entries, receipts and cash-at-hand balance',
                icon: Icons.account_balance_outlined,
                color: Colors.teal.shade700,
                onTap: () =>
                    Navigator.pushNamed(context, Routes.petroleumBankDeposits),
              ),
            ],
            if (isBakery) ...[
              const SizedBox(height: 12),
              _ReportCategoryCard(
                title: 'Bakery Performance',
                description: 'Baker output and product profitability ranking',
                icon: Icons.bakery_dining,
                color: const Color(0xFFD97706),
                onTap: () => Navigator.pushNamed(
                  context,
                  Routes.bakeryBakerPerformanceReport,
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Recent Reports
            Text(
              'Recent Reports',
              style:
                  AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final reportsProvider = context.watch<ReportsProvider>();
              final recents = reportsProvider.getDetailedTransactions() ?? [];

              if (recents.isEmpty) {
                return const Column(
                  children: [
                    SizedBox(height: 8),
                    _RecentReportItem(
                      title: 'No recent transactions',
                      date: '-',
                      status: '-',
                      icon: Icons.history,
                    ),
                    SizedBox(height: 32),
                  ],
                );
              }

              // Show up to 5 recent transactions
              final items = recents.take(5).toList();

              return Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    const SizedBox(height: 8),
                    Builder(builder: (ctx) {
                      final entry = items[i];
                      final saleId = (entry['id'] ?? entry['orderId'] ?? entry['saleId'])?.toString() ?? '';
                      final amountRaw = entry['total'] ?? entry['amount'] ?? entry['totalAmount'] ?? 0.0;
                      final amount = (amountRaw is num) ? amountRaw.toDouble() : double.tryParse(amountRaw?.toString() ?? '0') ?? 0.0;
                      final cashier = entry['cashier']?.toString() ?? entry['workerName']?.toString() ?? '';

                      return _RecentReportItem(
                        title: entry['description']?.toString() ?? 'Sale',
                        date: _formatReadableDate(entry['date']?.toString() ?? ''),
                        status: entry['type']?.toString() ?? 'Sale',
                        icon: Icons.receipt_long,
                        amount: amount,
                        cashier: cashier,
                        onTap: saleId.isNotEmpty
                            ? () => Navigator.pushNamed(ctx, Routes.salesReceipt, arguments: {'saleId': saleId})
                            : null,
                      );
                    }),
                  ],
                  const SizedBox(height: 32),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String change;
  final bool isPositive;
  final IconData icon;
  final String? tooltip;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.change,
    required this.isPositive,
    required this.icon,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.reportCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPositive
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  change,
                  style: AppTextStyles.caption.copyWith(
                    color: isPositive ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.caption
                      .copyWith(color: context.reportMutedText),
                ),
              ),
              if (tooltip != null)
                Tooltip(
                  message: tooltip!,
                  child: Icon(Icons.info_outline, size: 16, color: context.reportMutedText),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ReportCategoryCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ReportCategoryCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.reportCardShadow,
      ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body2
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: AppTextStyles.caption.copyWith(
                      color: context.reportMutedText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.reportMutedText.withOpacity(0.8)),
          ],
        ),
      ),
    );
  }
}

class _FuelStationReportSplitCard extends StatelessWidget {
  const _FuelStationReportSplitCard({required this.businessId});

  final String businessId;

  bool _isPumpSale(Map<String, dynamic> data) {
    final category = (data['category'] ?? '').toString().toLowerCase();
    final orderType = (data['order_type'] ?? data['orderType'] ?? '')
        .toString()
        .toLowerCase();
    return category.contains('fuel') ||
        category.contains('pump') ||
        orderType.contains('fuel');
  }

  double _readAmount(Map<String, dynamic> data) {
    return (data['totalAmount'] as num?)?.toDouble() ??
        (data['total'] as num?)?.toDouble() ??
        (data['expectedAmount'] as num?)?.toDouble() ??
        0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_gas_station_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fuel Station Report Split',
                    style: AppTextStyles.heading5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('businesses')
                  .doc(businessId)
                  .collection('sales')
                  .snapshots(includeMetadataChanges: true),
              builder: (context, salesSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('businesses')
                      .doc(businessId)
                      .collection('pump_daily_uploads')
                      .snapshots(includeMetadataChanges: true),
                  builder: (context, uploadSnapshot) {
                    final sales = salesSnapshot.data?.docs ?? [];
                    final uploads = uploadSnapshot.data?.docs ?? [];
                    var pumpRevenue = 0.0;
                    var minimartRevenue = 0.0;
                    for (final sale in sales) {
                      final data = sale.data();
                      if (_isPumpSale(data)) {
                        pumpRevenue += _readAmount(data);
                      } else {
                        minimartRevenue += _readAmount(data);
                      }
                    }
                    for (final upload in uploads) {
                      pumpRevenue += _readAmount(upload.data());
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: _MiniSplitMetric(
                            title: 'Pump Revenue',
                            value: formatCurrency(pumpRevenue),
                            subtitle: '${uploads.length} daily uploads',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniSplitMetric(
                            title: 'Minimart Revenue',
                            value: formatCurrency(minimartRevenue),
                            subtitle: 'Retail/non-pump sales',
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniSplitMetric extends StatelessWidget {
  const _MiniSplitMetric({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: context.reportBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.caption),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.heading5),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _RecentReportItem extends StatelessWidget {
  final String title;
  final String date;
  final String status;
  final IconData icon;
  final double? amount;
  final String? cashier;
  final VoidCallback? onTap;

  const _RecentReportItem({
    required this.title,
    required this.date,
    required this.status,
    required this.icon,
    this.amount,
    this.cashier,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final amountStr = amount != null && amount! > 0
        ? NumberFormat.currency(locale: 'en_NG', symbol: '₦').format(amount)
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: context.reportCardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.success, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(date, style: AppTextStyles.caption.copyWith(color: context.reportMutedText)),
                    if (cashier != null && cashier!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.reportChipSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Cashier: $cashier', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ]
                  ])
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (amountStr != null)
                  Text(amountStr, style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(status.toUpperCase(), style: AppTextStyles.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

