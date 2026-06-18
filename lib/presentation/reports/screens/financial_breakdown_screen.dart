import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/reports_provider.dart';

class FinancialBreakdownScreen extends StatelessWidget {
  const FinancialBreakdownScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportsProvider>(
      builder: (context, reportsProvider, _) {
        final authProvider = context.read<AuthProvider>();
        final businessId = context.read<BusinessProvider>().currentBusiness?.id ??
            authProvider.currentUser?.businessId;
        final deepDive = reportsProvider.getFinancialDeepDive();
        final summary = (deepDive['summary'] as Map?)?.cast<String, dynamic>() ?? {};
        final sales = (deepDive['sales'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final expenses = (deepDive['expenses'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        final totalRevenue = (deepDive['calculatedRevenue'] as num?)?.toDouble() ??
            (summary['totalRevenue'] as num?)?.toDouble() ??
            0.0;
        final totalCogs = (deepDive['calculatedCogs'] as num?)?.toDouble() ??
            (summary['totalCogs'] as num?)?.toDouble() ??
            0.0;
        final operatingExpenses = (deepDive['operatingExpenses'] as num?)?.toDouble() ??
            (summary['totalExpenses'] as num?)?.toDouble() ??
            0.0;
        final grossProfit = (deepDive['grossProfit'] as num?)?.toDouble() ??
            (summary['grossProfit'] as num?)?.toDouble() ??
            0.0;
        final netProfit = (deepDive['netProfit'] as num?)?.toDouble() ??
            (summary['netProfit'] as num?)?.toDouble() ??
            0.0;
        final grossMargin = (deepDive['grossMargin'] as num?)?.toDouble() ??
            (summary['grossMargin'] as num?)?.toDouble() ??
            0.0;
        final netMargin = (deepDive['netMargin'] as num?)?.toDouble() ??
            (summary['netProfitMargin'] as num?)?.toDouble() ??
            0.0;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Financial Breakdown'),
            actions: [
              IconButton(
                tooltip: 'Refresh breakdown',
                icon: const Icon(Icons.refresh),
                onPressed: reportsProvider.isLoading || businessId == null || businessId.isEmpty
                    ? null
                    : () {
                        reportsProvider.generateFinancialReport(businessId: businessId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Refreshing breakdown...')),
                        );
                      },
              ),
            ],
          ),
          body: reportsProvider.isLoading || reportsProvider.isComputingFinancials
              ? const Center(child: CircularProgressIndicator())
              : sales.isEmpty
                  ? const Center(
                      child: Text('No financial data found for the selected period'),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PeriodHeader(
                            start: reportsProvider.financialStartDate,
                            end: reportsProvider.financialEndDate,
                          ),
                          const SizedBox(height: 16),
                          _SummaryGrid(
                            totalRevenue: totalRevenue,
                            totalCogs: totalCogs,
                            operatingExpenses: operatingExpenses,
                            grossProfit: grossProfit,
                            netProfit: netProfit,
                            grossMargin: grossMargin,
                            netMargin: netMargin,
                          ),
                          const SizedBox(height: 16),
                          _BuildFormulaCard(
                            totalRevenue: totalRevenue,
                            totalCogs: totalCogs,
                            operatingExpenses: operatingExpenses,
                            grossProfit: grossProfit,
                            netProfit: netProfit,
                          ),
                          const SizedBox(height: 16),
                          _SectionTitle(
                            title: 'Sales Breakdown',
                            subtitle:
                                '${sales.length} sale record(s) with line-by-line COGS',
                          ),
                          const SizedBox(height: 8),
                          ...sales.map(
                            (sale) => _SaleBreakdownCard(sale: sale),
                          ),
                          const SizedBox(height: 16),
                          _SectionTitle(
                            title: 'Expense Breakdown',
                            subtitle:
                                '${expenses.length} operating expense record(s)',
                          ),
                          const SizedBox(height: 8),
                          if (expenses.isEmpty)
                            const Text('No operating expenses were captured in this period.')
                          else
                            ...expenses.map(
                              (expense) => _ExpenseCard(expense: expense),
                            ),
                          const SizedBox(height: 24),
                          Text(
                            'Profit margin = Net Profit ÷ Revenue × 100',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
        );
      },
    );
  }
}

class _PeriodHeader extends StatelessWidget {
  final DateTime start;
  final DateTime end;

  const _PeriodHeader({
    required this.start,
    required this.end,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected Time Range',
            style: AppTextStyles.caption.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            '${DateFormat('dd MMM yyyy').format(start)} → ${DateFormat('dd MMM yyyy').format(end)}',
            style: AppTextStyles.heading4.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'COGS is calculated per sold line item using the recorded cost fields or linked inventory cost.',
            style: AppTextStyles.body2.copyWith(color: Colors.white.withOpacity(0.92)),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final double totalRevenue;
  final double totalCogs;
  final double operatingExpenses;
  final double grossProfit;
  final double netProfit;
  final double grossMargin;
  final double netMargin;

  const _SummaryGrid({
    required this.totalRevenue,
    required this.totalCogs,
    required this.operatingExpenses,
    required this.grossProfit,
    required this.netProfit,
    required this.grossMargin,
    required this.netMargin,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCard(
        label: 'Total Sales',
        value: formatCurrency(totalRevenue),
        subtitle: 'All completed sales in the range',
        color: AppColors.success,
      ),
      _MetricCard(
        label: 'COGS',
        value: formatCurrency(totalCogs),
        subtitle: 'Quantity × cost per unit',
        color: AppColors.warning,
      ),
      _MetricCard(
        label: 'Gross Profit',
        value: formatCurrency(grossProfit),
        subtitle: '${grossMargin.toStringAsFixed(1)}% gross margin',
        color: AppColors.primary,
      ),
      _MetricCard(
        label: 'Operating Expenses',
        value: formatCurrency(operatingExpenses),
        subtitle: 'Rent, salaries, utilities, and other expenses',
        color: AppColors.error,
      ),
      _MetricCard(
        label: 'Net Profit',
        value: formatCurrency(netProfit),
        subtitle: '${netMargin.toStringAsFixed(1)}% net margin',
        color: AppColors.info,
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards
          .map(
            (card) => SizedBox(
              width: MediaQuery.of(context).size.width >= 700
                  ? (MediaQuery.of(context).size.width - 44) / 2
                  : double.infinity,
              child: card,
            ),
          )
          .toList(),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.16)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.heading3.copyWith(color: color),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _BuildFormulaCard extends StatelessWidget {
  final double totalRevenue;
  final double totalCogs;
  final double operatingExpenses;
  final double grossProfit;
  final double netProfit;

  const _BuildFormulaCard({
    required this.totalRevenue,
    required this.totalCogs,
    required this.operatingExpenses,
    required this.grossProfit,
    required this.netProfit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How the numbers are calculated', style: AppTextStyles.heading4),
          const SizedBox(height: 12),
          _formulaLine('Revenue', formatCurrency(totalRevenue)),
          _formulaLine('− COGS', formatCurrency(totalCogs)),
          const Divider(height: 24),
          _formulaLine('Gross Profit', formatCurrency(grossProfit), highlight: true),
          const SizedBox(height: 8),
          _formulaLine('− Operating Expenses', formatCurrency(operatingExpenses)),
          const Divider(height: 24),
          _formulaLine('Net Profit', formatCurrency(netProfit), highlight: true),
          const SizedBox(height: 8),
          Text(
            'COGS = sum of each item quantity × its unit cost. Wholesale items are flagged and included in the sale view for clarity.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _formulaLine(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.body2.copyWith(
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.body2.copyWith(
            fontWeight: FontWeight.w700,
            color: highlight ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.heading3),
        const SizedBox(height: 4),
        Text(subtitle, style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _SaleBreakdownCard extends StatelessWidget {
  final Map<String, dynamic> sale;

  const _SaleBreakdownCard({required this.sale});

  @override
  Widget build(BuildContext context) {
    final items = (sale['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final revenue = (sale['revenue'] as num?)?.toDouble() ?? 0.0;
    final cogs = (sale['cogs'] as num?)?.toDouble() ?? 0.0;
    final grossProfit = (sale['grossProfit'] as num?)?.toDouble() ?? 0.0;
    final grossMargin = (sale['grossMargin'] as num?)?.toDouble() ?? 0.0;
    final isWholesale = sale['isWholesale'] == true;
    final date = sale['date'] as DateTime? ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Expanded(
              child: Text(
                sale['receiptNumber']?.toString().isNotEmpty == true
                    ? 'Receipt #${sale['receiptNumber']}'
                    : 'Sale #${sale['id'].toString().substring(0, 8).toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (isWholesale)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Wholesale items',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${DateFormat('dd MMM yyyy, h:mm a').format(date)} • ${sale['customerName'] ?? 'Walk-in'}',
        ),
        children: [
          _saleMiniStatRow('Revenue', formatCurrency(revenue), AppColors.success),
          _saleMiniStatRow('COGS', formatCurrency(cogs), AppColors.warning),
          _saleMiniStatRow('Gross Profit', formatCurrency(grossProfit), AppColors.primary),
          _saleMiniStatRow('Gross Margin', '${grossMargin.toStringAsFixed(1)}%', AppColors.info),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Line items', style: AppTextStyles.heading5),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['name']?.toString() ?? 'Item',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (item['isWholesale'] == true)
                        const _WholesaleBadge(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _ItemChip(label: 'Qty', value: _formatNumber(item['quantity'])),
                      _ItemChip(label: 'Unit price', value: formatCurrency((item['unitPrice'] as num?)?.toDouble() ?? 0.0)),
                      _ItemChip(label: 'Cost/unit', value: formatCurrency((item['costPerUnit'] as num?)?.toDouble() ?? 0.0)),
                      _ItemChip(label: 'Revenue', value: formatCurrency((item['revenue'] as num?)?.toDouble() ?? 0.0)),
                      _ItemChip(label: 'COGS', value: formatCurrency((item['cogs'] as num?)?.toDouble() ?? 0.0)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pricing mode: ${(item['pricingMode'] ?? 'retail').toString().toUpperCase()}${(item['saleUnit'] ?? '').toString().trim().isNotEmpty ? ' • Sold in ${item['saleUnit']}' : ''}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saleMiniStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body2),
          Text(value, style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  String _formatNumber(dynamic value) {
    final numValue = (value as num?)?.toDouble() ?? 0.0;
    if (numValue == numValue.roundToDouble()) return numValue.toInt().toString();
    return numValue.toStringAsFixed(2);
  }
}

class _WholesaleBadge extends StatelessWidget {
  const _WholesaleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Wholesale',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.warning,
        ),
      ),
    );
  }
}

class _ItemChip extends StatelessWidget {
  final String label;
  final String value;

  const _ItemChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final Map<String, dynamic> expense;

  const _ExpenseCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final amount = (expense['amount'] as num?)?.toDouble() ?? 0.0;
    final date = expense['date'] as DateTime? ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long, color: AppColors.error, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense['category']?.toString() ?? 'Expense',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  expense['description']?.toString().isNotEmpty == true
                      ? expense['description'].toString()
                      : DateFormat('dd MMM yyyy, h:mm a').format(date),
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            formatCurrency(amount),
            style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
