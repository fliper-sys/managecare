import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/reports_provider.dart';
import '../../../providers/business_provider.dart';
import '../../reports/widgets/report_theme.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  String _selectedMetric = 'sales';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metric Selector
          Text(
            'Analytics Dashboard',
            style: AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MetricTab(
                label: 'Sales',
                value: _selectedMetric,
                onTap: () => setState(() => _selectedMetric = 'sales'),
              ),
              const SizedBox(width: 8),
              _MetricTab(
                label: 'Financial',
                value: _selectedMetric,
                onTap: () => setState(() => _selectedMetric = 'financial'),
              ),
              const SizedBox(width: 8),
              _MetricTab(
                label: 'Inventory',
                value: _selectedMetric,
                onTap: () => setState(() => _selectedMetric = 'inventory'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Consumer for real data from providers
          Consumer2<ReportsProvider, BusinessProvider>(
            builder: (context, reportsProvider, businessProvider, _) {
              final salesSummary = reportsProvider.getSalesSummary();
              final financialSummary = reportsProvider.getFinancialSummary();
              final inventorySummary = reportsProvider.getInventorySummary();

              // Sales Chart
              if (_selectedMetric == 'sales') {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales Performance',
                      style: AppTextStyles.heading5
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.reportSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.reportBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Sales: ₦${(salesSummary['totalSales'] ?? 0).toStringAsFixed(0)}',
                            style: AppTextStyles.body2
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _AnalyticsStat(
                                label: 'Total Transactions',
                                value:
                                    '${salesSummary['totalTransactions'] ?? 0}',
                              ),
                              _AnalyticsStat(
                                label: 'Average Sale',
                                value:
                                    '₦${(salesSummary['averageSale'] ?? 0).toStringAsFixed(0)}',
                              ),
                              _AnalyticsStat(
                                label: 'Trend',
                                value:
                                    '${(salesSummary['trend'] ?? 0).toStringAsFixed(1)}%',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.reportSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.reportBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top Products',
                            style: AppTextStyles.body2
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          if (reportsProvider.salesReports.isNotEmpty)
                            ...reportsProvider.salesReports
                                .take(3)
                                .map((sale) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            sale.category,
                                            style: AppTextStyles.body2,
                                          ),
                                          Text(
                                            '₦${sale.totalAmount.toStringAsFixed(0)}',
                                            style: AppTextStyles.body2.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                          else
                            const Text('No sales data available'),
                        ],
                      ),
                    ),
                  ],
                );
              }

              // Financial Chart
              if (_selectedMetric == 'financial') {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Financial Overview',
                      style: AppTextStyles.heading5
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.reportSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.reportBorder),
                      ),
                      child: Column(
                        children: [
                          _KeyMetricRow(
                            label: 'Total Revenue',
                            value:
                                '₦${(financialSummary['totalRevenue'] ?? 0).toStringAsFixed(0)}',
                            icon: Icons.trending_up,
                          ),
                          const Divider(),
                          _KeyMetricRow(
                            label: 'Total Expenses',
                            value:
                                '₦${(financialSummary['totalExpenses'] ?? 0).toStringAsFixed(0)}',
                            icon: Icons.trending_down,
                          ),
                          const Divider(),
                          _KeyMetricRow(
                            label: 'Net Profit',
                            value:
                                '₦${(financialSummary['profit'] ?? 0).toStringAsFixed(0)}',
                            icon: Icons.money,
                          ),
                          const Divider(),
                          _KeyMetricRow(
                            label: 'Profit Margin',
                            value:
                                '${(financialSummary['profitMargin'] ?? 0).toStringAsFixed(1)}%',
                            icon: Icons.percent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.reportSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.reportBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monthly Breakdown',
                            style: AppTextStyles.body2
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          if (reportsProvider.financialReports.isNotEmpty)
                            ...reportsProvider.financialReports
                                .take(3)
                                .map((report) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Month ${report.month}',
                                            style: AppTextStyles.body2,
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '₦${report.revenue.toStringAsFixed(0)}',
                                                style: AppTextStyles.caption,
                                              ),
                                              Text(
                                                'Profit: ₦${(report.revenue - report.expenses).toStringAsFixed(0)}',
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                  color: AppColors.success,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ))
                          else
                            const Text('No financial data available'),
                        ],
                      ),
                    ),
                  ],
                );
              }

              // Inventory Chart
              if (_selectedMetric == 'inventory') {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inventory Status',
                      style: AppTextStyles.heading5
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.reportSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.reportBorder),
                      ),
                      child: Column(
                        children: [
                          _KeyMetricRow(
                            label: 'Total Items',
                            value: '${inventorySummary['totalItems'] ?? 0}',
                            icon: Icons.inventory_2,
                          ),
                          const Divider(),
                          _KeyMetricRow(
                            label: 'Total Value',
                            value:
                                '₦${(inventorySummary['totalValue'] ?? 0).toStringAsFixed(0)}',
                            icon: Icons.monetization_on,
                          ),
                          const Divider(),
                          _KeyMetricRow(
                            label: 'Low Stock Items',
                            value: '${inventorySummary['lowStockCount'] ?? 0}',
                            icon: Icons.warning,
                          ),
                          const Divider(),
                          _KeyMetricRow(
                            label: 'Stock Turnover',
                            value:
                                '${(inventorySummary['turnoverRate'] ?? 0).toStringAsFixed(1)}x',
                            icon: Icons.cached,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.reportSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.reportBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top Items',
                            style: AppTextStyles.body2
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          if (reportsProvider.inventoryReports.isNotEmpty)
                            ...reportsProvider.inventoryReports
                                .take(3)
                                .map((item) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.productName,
                                                  style: AppTextStyles.body2,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  'Stock: ${item.quantity}',
                                                  style: AppTextStyles.caption,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '₦${item.totalValue.toStringAsFixed(0)}',
                                            style: AppTextStyles.body2.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                          else
                            const Text('No inventory data available'),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

class _MetricTab extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _MetricTab({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value.toLowerCase() == label.toLowerCase();

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:
                isSelected ? AppColors.primary : context.reportChipSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : context.reportBorder,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : context.reportMutedText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsStat extends StatelessWidget {
  final String label;
  final String value;

  const _AnalyticsStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: context.reportMutedText),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _KeyMetricRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _KeyMetricRow({
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
            child: Text(label, style: AppTextStyles.body2),
          ),
          Text(
            value,
            style: AppTextStyles.heading5.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

