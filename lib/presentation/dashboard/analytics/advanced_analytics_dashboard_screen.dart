import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:business_manager/core/utils/formatters.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../providers/analytics_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../widgets/date_range_selector.dart';

class AdvancedAnalyticsDashboardScreen extends StatefulWidget {
  const AdvancedAnalyticsDashboardScreen({super.key});

  @override
  State<AdvancedAnalyticsDashboardScreen> createState() =>
      _AdvancedAnalyticsDashboardScreenState();
}

class _AdvancedAnalyticsDashboardScreenState
    extends State<AdvancedAnalyticsDashboardScreen> {
  late AnalyticsProvider analyticsProvider;
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  String _selectedPeriod = 'monthly';

  Color get _screenBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardSurface => Theme.of(context).cardColor;
  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get _textMuted =>
      Theme.of(context).colorScheme.onSurface.withOpacity(0.68);
  Color get _softBorder => Theme.of(context).dividerColor.withOpacity(0.24);
  List<BoxShadow> get _cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(
            Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.05,
          ),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  @override
  void initState() {
    super.initState();
    analyticsProvider = context.read<AnalyticsProvider>();
    _loadAnalytics();
    analyticsProvider.subscribeToSalesUpdates(
        _selectedDateRange.start, _selectedDateRange.end);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final businessProvider = context.watch<BusinessProvider?>();
    final bid = businessProvider?.currentBusiness?.id;
    if (bid != null && bid.isNotEmpty) {
      analyticsProvider.setBusinessId(bid);
      analyticsProvider.subscribeToSalesUpdates(
          _selectedDateRange.start, _selectedDateRange.end);
    }
  }

  @override
  void dispose() {
    analyticsProvider.unsubscribeFromSalesUpdates();
    analyticsProvider.unsubscribeFromProductUpdates();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    await analyticsProvider.calculateAnalytics(
      _selectedDateRange.start,
      _selectedDateRange.end,
    );
    await analyticsProvider.getTopProducts(
      _selectedDateRange.start,
      _selectedDateRange.end,
    );
    await analyticsProvider.getRevenueTrend(
      _selectedDateRange.start,
      _selectedDateRange.end,
      period: _selectedPeriod,
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _onDateRangeChanged(DateTimeRange newRange) {
    setState(() {
      _selectedDateRange = newRange;
    });
    _loadAnalytics();
    analyticsProvider.unsubscribeFromSalesUpdates();
    analyticsProvider.subscribeToSalesUpdates(
        _selectedDateRange.start, _selectedDateRange.end);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBackground,
      appBar: CustomAppBar(
        title: 'Advanced Analytics',
        onBackPressed: () => Navigator.pop(context),
        backgroundColor: _cardSurface,
        elevation: 0,
      ),
      body: Consumer<AnalyticsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.currentAnalytics == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final analytics = provider.currentAnalytics;
          if (analytics == null) {
            return Center(
              child: Text(
                'No analytics data available',
                style: GoogleFonts.poppins(color: _textMuted),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadAnalytics,
            backgroundColor: _cardSurface,
            color: AppColors.primary,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  DateRangeSelector(
                    initialRange: _selectedDateRange,
                    onRangeChanged: _onDateRangeChanged,
                    backgroundColor: _cardSurface,
                  ),
                  const SizedBox(height: 28),
                  _buildKPIGrid(analytics)
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 200.ms),
                  const SizedBox(height: 28),
                  _buildRevenueGrowthCard(analytics)
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 300.ms),
                  const SizedBox(height: 28),
                  _buildRevenueTrendCard(provider)
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 400.ms),
                  const SizedBox(height: 28),
                  _buildCustomerAnalyticsCard(analytics)
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 500.ms),
                  const SizedBox(height: 28),
                  _buildTopProductsCard(provider)
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 600.ms),
                  const SizedBox(height: 28),
                  _buildPerformanceMetricsCard(analytics)
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 700.ms),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 300.ms);
        },
      ),
    );
  }

  Widget _buildKPIGrid(dynamic analytics) {
    final kpiData = [
      {
        'title': 'Total Revenue',
        'value': formatCurrency(analytics.totalRevenue, decimalDigits: 0),
        'color': const Color(0xFF00B2FF),
        'icon': Icons.trending_up,
        'subtitle': formatPercent(analytics.revenueGrowth, decimalDigits: 1),
      },
      {
        'title': 'Transactions',
        'value': '${analytics.totalTransactions}',
        'color': const Color(0xFF22C55E),
        'icon': Icons.shopping_cart,
        'subtitle': '+${analytics.transactionGrowth}',
      },
      {
        'title': 'Avg Order Value',
        'value': formatCurrency(analytics.averageOrderValue, decimalDigits: 0),
        'color': const Color(0xFFEAB308),
        'icon': Icons.receipt,
        'subtitle': 'Per Order',
      },
      {
        'title': 'New Customers',
        'value': '${analytics.newCustomers}',
        'color': const Color(0xFF8B5CF6),
        'icon': Icons.person_add,
        'subtitle': '+${analytics.newCustomers}',
      },
      {
        'title': 'Cost of Goods Sold',
        'value': formatCurrency(analytics.totalCogs, decimalDigits: 0),
        'color': const Color(0xFFEF4444),
        'icon': Icons.money_off,
        'subtitle': 'COGS',
      },
      {
        'title': 'Gross Margin',
        'value': formatCurrency(analytics.grossProfit, decimalDigits: 0),
        'color': const Color(0xFF14B8A6),
        'icon': Icons.account_balance_wallet,
        'subtitle': 'Revenue − COGS',
      },
    ];

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 2.6,
      ),
      itemCount: kpiData.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final item = kpiData[index];
        return _buildKPICard(
          item['title'] as String,
          item['value'] as String,
          item['color'] as Color,
          item['icon'] as IconData,
          item['subtitle'] as String,
        ).animate().slideY(
            duration: 500.ms,
            delay: (100 * index).ms,
            begin: 0.2,
            curve: Curves.easeOut);
      },
    );
  }

  Widget _buildKPICard(
    String title,
    String value,
    Color color,
    IconData icon,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _softBorder),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(color: _textMuted, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 24),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: _textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.poppins(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueGrowthCard(dynamic analytics) {
    final isPositiveGrowth = analytics.revenueGrowth >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _softBorder),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue Growth',
            style: GoogleFonts.poppins(
              color: _textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                isPositiveGrowth ? Icons.trending_up : Icons.trending_down,
                color: isPositiveGrowth ? Colors.greenAccent : Colors.redAccent,
                size: 36,
              ),
              const SizedBox(width: 12),
              Text(
                '${analytics.revenueGrowth.toStringAsFixed(1)}%',
                style: GoogleFonts.poppins(
                  color: isPositiveGrowth ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                'vs Previous Period',
                style: GoogleFonts.poppins(color: _textMuted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerAnalyticsCard(dynamic analytics) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _softBorder),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer Analytics',
            style: GoogleFonts.poppins(
              color: _textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem(
                'New',
                '${analytics.newCustomers}',
                const Color(0xFF00B2FF),
              ),
              _buildMetricItem(
                'Returning',
                '${analytics.returningCustomers}',
                const Color(0xFF22C55E),
              ),
              _buildMetricItem(
                'Retention',
                '${analytics.customerRetentionRate.toStringAsFixed(1)}%',
                const Color(0xFFEAB308),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(color: _textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTopProductsCard(AnalyticsProvider provider) {
    final products = provider.topProducts;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _softBorder),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Selling Products',
            style: GoogleFonts.poppins(
              color: _textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (products.isEmpty)
            Center(
              child: Text(
                'No product data available for this period.',
                style: GoogleFonts.poppins(color: _textMuted),
              ),
            )
          else
            ...List.generate(products.length, (index) {
              final product = products[index];
              final revenue = (product['revenue'] as num?)?.toDouble() ?? 0.0;
              final quantity = product['quantity'] ?? 0;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2_outlined,
                              color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['name'] ?? 'Unknown Product',
                                style: GoogleFonts.poppins(
                                    color: _textPrimary,
                                    fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '$quantity units sold',
                                style: GoogleFonts.poppins(
                                    color: _textMuted,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '₦${NumberFormat.compact().format(revenue)}',
                          style: GoogleFonts.poppins(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index != products.length - 1)
                    Divider(color: _softBorder),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRevenueTrendCard(AnalyticsProvider provider) {
    final trend = provider.revenueTrend;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _softBorder),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Revenue Trend',
                style: GoogleFonts.poppins(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              DropdownButton<String>(
                value: _selectedPeriod,
                dropdownColor: _cardSurface,
                style: GoogleFonts.poppins(color: _textPrimary),
                icon: Icon(Icons.arrow_drop_down, color: _textMuted),
                underline: const SizedBox.shrink(),
                items: ['daily', 'weekly', 'monthly']
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e.replaceFirst(e[0], e[0].toUpperCase())),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPeriod = value;
                    });
                    _loadAnalytics();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: trend.isEmpty
                ? Center(
                    child: Text(
                      'No trend data available.',
                      style: GoogleFonts.poppins(color: _textMuted),
                    ),
                  )
                : _buildLineChart(trend),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<Map<String, dynamic>> trendData) {
    final spots = trendData.asMap().entries.map((entry) {
      final index = entry.key;
      final revenue =
          (entry.value['revenue'] as num?)?.toDouble() ?? 0.0;
      return FlSpot(index.toDouble(), revenue);
    }).toList();

    double maxRevenue = 0;
    for (var item in trendData) {
      final revenue = (item['revenue'] as num?)?.toDouble() ?? 0.0;
      if (revenue > maxRevenue) maxRevenue = revenue;
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= trendData.length) return const SizedBox();
                final item = trendData[index];
                String label = '';

                if (_selectedPeriod == 'daily') {
                  label = DateFormat('d MMM').format(item['date']);
                } else if (_selectedPeriod == 'weekly') {
                  label = 'W${index + 1}';
                } else {
                  label = DateFormat('MMM').format(item['date']);
                }
                
                if (trendData.length > 5 && index % 2 != 0) {
                  return const SizedBox();
                }

                return SideTitleWidget(
                  meta: meta,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      label,
                      style: GoogleFonts.poppins(
                          color: _textMuted, fontSize: 10),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.4),
                  AppColors.primary.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final revenue = spot.y;
                return LineTooltipItem(
                  '₦${NumberFormat.compact().format(revenue)}',
                  GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceMetricsCard(dynamic analytics) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _softBorder),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Highlights',
            style: GoogleFonts.poppins(
              color: _textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          _buildHighlightRow(
            Icons.star_border,
            'Top Product',
            analytics.topProductName,
            '${analytics.topProductSales} units',
            Colors.amber,
          ),
          const SizedBox(height: 16),
          _buildHighlightRow(
            Icons.person_outline,
            'Top Performer',
            analytics.topWorkerName,
            '₦${NumberFormat.compact().format(analytics.topWorkerSales)}',
            const Color(0xFF00B2FF),
          ),
          const SizedBox(height: 16),
           _buildHighlightRow(
            Icons.info_outline,
            'COGS Info',
            'How is COGS calculated?',
            'Tap for details',
            Colors.grey.shade400,
            onTap: _showCogsExplanation,
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightRow(IconData icon, String label, String value,
      String subtitle, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent, // For hit testing
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(color: _textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      color: _textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (onTap == null)
              Text(
                subtitle,
                style: GoogleFonts.poppins(color: color, fontSize: 13),
              )
            else
              Icon(Icons.arrow_forward_ios, color: _textMuted, size: 14),
          ],
        ),
      ),
    );
  }

  void _showCogsExplanation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardSurface,
        title: Text('How COGS Is Calculated', style: GoogleFonts.poppins(color: _textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'Cost of Goods Sold (COGS) is the total direct stock cost tied to items sold in the selected date range.\n\nIt is calculated by summing (quantity sold × unit cost) for each sale item.\n\nThe app now checks cost in this order:\n1. Cost saved directly on the sale item.\n2. Cost stored on the linked inventory product.\n3. Weighted procurement cost tracked from batch replenishment.\n\nIf no cost is available after those checks, the item falls back to 0.',
          style: GoogleFonts.poppins(color: _textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('GOT IT', style: GoogleFonts.poppins(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _softBorder),
        ),
      ),
    );
  }
}
