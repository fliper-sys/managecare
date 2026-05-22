import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/repositories/analytics_repository_impl.dart';
import '../../../providers/business_provider.dart';

class BusinessOverviewTab extends StatefulWidget {
  const BusinessOverviewTab({super.key});

  @override
  State<BusinessOverviewTab> createState() => _BusinessOverviewTabState();
}

class _BusinessOverviewTabState extends State<BusinessOverviewTab> {
  String _selectedPeriod = 'month';
  late AnalyticsRepositoryImpl _analytics;
  Map<String, dynamic>? _metrics;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _analytics = AnalyticsRepositoryImpl(firestore: FirebaseFirestore.instance);
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final business =
          Provider.of<BusinessProvider>(context, listen: false).currentBusiness;

      if (business == null) {
        setState(() => _isLoading = false);
        return;
      }

      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      final salesAnalytics = await _analytics.getSalesAnalytics(
        business.id,
        startDate: monthStart,
        endDate: now,
      );

      final inventoryAnalytics =
          await _analytics.getInventoryAnalytics(business.id);
      final customerAnalytics =
          await _analytics.getCustomerAnalytics(business.id);

      setState(() {
        _metrics = {
          ...salesAnalytics,
          ...inventoryAnalytics,
          ...customerAnalytics,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Selector
          _PeriodSelector(
            selectedPeriod: _selectedPeriod,
            onPeriodChanged: (period) =>
                setState(() => _selectedPeriod = period),
          ),
          const SizedBox(height: 24),

          // Revenue Summary
          Text(
            'Revenue Summary',
            style: AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RevenueCard(
                  label: 'Total Revenue',
                  value: _metrics != null
                      ? '₦${(_metrics!['totalSales'] ?? 0).toStringAsFixed(0)}'
                      : '₦0',
                  change: '+12.5%',
                  isPositive: true,
                  icon: Icons.trending_up,
                  isLoading: _isLoading,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RevenueCard(
                  label: 'Avg. Daily Sales',
                  value: _metrics != null
                      ? '₦${((_metrics!['totalSales'] ?? 0) / DateTime.now().day).toStringAsFixed(0)}'
                      : '₦0',
                  change: '+5.2%',
                  isPositive: true,
                  icon: Icons.show_chart,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RevenueCard(
                  label: 'Total Transactions',
                  value: '${_metrics?['totalTransactions'] ?? 0}',
                  change: '+8.1%',
                  isPositive: true,
                  icon: Icons.receipt_long,
                  isLoading: _isLoading,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RevenueCard(
                  label: 'Avg. Transaction',
                  value: _metrics != null
                      ? '₦${((_metrics!['averageTransactionValue'] ?? 0) as num).toStringAsFixed(0)}'
                      : '₦0',
                  change: '+2.3%',
                  isPositive: true,
                  icon: Icons.calculate,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Business Metrics
          Text(
            'Business Metrics',
            style: AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outline.withOpacity(0.24)),
            ),
            child: Column(
              children: [
                _MetricRow(
                  label: 'Inventory Value',
                  value: _metrics != null
                      ? '₦${(_metrics!['totalItems'] ?? 0) * 1000}'
                      : '₦0',
                  icon: Icons.inventory_2,
                ),
                const Divider(),
                _MetricRow(
                  label: 'Active Customers',
                  value: '${_metrics?['activeCustomers'] ?? 0}',
                  icon: Icons.people,
                ),
                const Divider(),
                _MetricRow(
                  label: 'Low Stock Items',
                  value: '${_metrics?['lowStockItems'] ?? 0}',
                  icon: Icons.hourglass_bottom,
                ),
                const Divider(),
                _MetricRow(
                  label: 'Expired Items',
                  value: '${_metrics?['expiredItems'] ?? 0}',
                  icon: Icons.warning,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Top Products
          Text(
            'Top Performing Products',
            style: AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const _ProductItem(
            rank: 1,
            name: 'Premium Laptop',
            sales: 45,
            revenue: '₦450,000',
            trend: '+15%',
          ),
          const SizedBox(height: 8),
          const _ProductItem(
            rank: 2,
            name: 'Wireless Headphones',
            sales: 128,
            revenue: '₦128,000',
            trend: '+8%',
          ),
          const SizedBox(height: 8),
          const _ProductItem(
            rank: 3,
            name: 'USB-C Cable',
            sales: 234,
            revenue: '₦23,400',
            trend: '-2%',
          ),
          const SizedBox(height: 24),

          // Recent Transactions
          Text(
            'Recent Transactions',
            style: AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const _TransactionItem(
            id: 'TXN-001234',
            customer: 'Chioma Okafor',
            amount: '₦15,500',
            date: 'Today, 2:45 PM',
            status: 'Completed',
          ),
          const SizedBox(height: 8),
          const _TransactionItem(
            id: 'TXN-001233',
            customer: 'Adeyemi Johnson',
            amount: '₦8,200',
            date: 'Today, 1:20 PM',
            status: 'Completed',
          ),
          const SizedBox(height: 8),
          const _TransactionItem(
            id: 'TXN-001232',
            customer: 'Mercy Ibe',
            amount: '₦22,400',
            date: 'Yesterday',
            status: 'Pending',
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final String selectedPeriod;
  final Function(String) onPeriodChanged;

  const _PeriodSelector({
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: ['day', 'week', 'month', 'year'].map((period) {
        final isSelected = selectedPeriod == period;
        return Expanded(
          child: GestureDetector(
            onTap: () => onPeriodChanged(period),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : theme.cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : scheme.outline.withOpacity(0.24),
                ),
              ),
              child: Center(
                child: Text(
                  period[0].toUpperCase() + period.substring(1),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final String label;
  final String value;
  final String change;
  final bool isPositive;
  final IconData icon;
  final bool isLoading;

  const _RevenueCard({
    required this.label,
    required this.value,
    required this.change,
    required this.isPositive,
    required this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.24)),
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
                      : AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  change,
                  style: AppTextStyles.caption.copyWith(
                    color: isPositive ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
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

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style:
                      AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductItem extends StatelessWidget {
  final int rank;
  final String name;
  final int sales;
  final String revenue;
  final String trend;

  const _ProductItem({
    required this.rank,
    required this.name,
    required this.sales,
    required this.revenue,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style:
                      AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '$sales units sold',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                revenue,
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                trend,
                style: AppTextStyles.caption.copyWith(
                  color: trend.startsWith('+')
                      ? AppColors.success
                      : AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final String id;
  final String customer;
  final String amount;
  final String date;
  final String status;

  const _TransactionItem({
    required this.id,
    required this.customer,
    required this.amount,
    required this.date,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = status == 'Completed';
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.24)),
      ),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.schedule,
            color: isCompleted ? AppColors.success : AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer,
                  style:
                      AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '$id • $date',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

