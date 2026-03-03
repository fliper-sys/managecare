import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:business_manager/core/utils/datetime_utils.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/retail_provider.dart';
import '../../../widgets/date_range_selector.dart';

class WorkerLeaderboardScreen extends StatefulWidget {
  const WorkerLeaderboardScreen({super.key});

  @override
  State<WorkerLeaderboardScreen> createState() =>
      _WorkerLeaderboardScreenState();
}

class _WorkerLeaderboardScreenState extends State<WorkerLeaderboardScreen> {
  late DateTimeRange _selectedDateRange;
  List<WorkerMetrics> _workerMetrics = [];
  bool _isLoading = true;
  String _sortBy = 'sales'; // 'sales', 'count', 'average'
  final Map<String, String> _medalEmojis = {
    '1': '🥇',
    '2': '🥈',
    '3': '🥉',
  };

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: now.add(const Duration(days: 1)),
    );
    _loadWorkerMetrics();
  }

  Future<void> _loadWorkerMetrics() async {
    try {
      final businessId = context.read<BusinessProvider>().currentBusiness?.id;

      if (businessId == null) {
        print('[Leaderboard] No business ID found');
        return;
      }

      final retailProvider = context.read<RetailProvider>();

      // Get all sales for the date range
      final sales = await retailProvider.getSalesHistory();
      final filteredSales = sales.where((sale) {
        final saleDate = sale['createdAt'] is DateTime
            ? sale['createdAt'] as DateTime
            : parseTimestamp(sale['createdAt']);
        return saleDate.isAfter(_selectedDateRange.start) &&
            saleDate.isBefore(_selectedDateRange.end);
      }).toList();

      // Group by worker and calculate metrics
      final Map<String, WorkerMetrics> metricsMap = {};

      for (final sale in filteredSales) {
        final workerId = sale['workerId'] ?? 'unknown';
        final workerName = sale['workerName'] ?? 'Unknown Worker';
        final amount = ((sale['totalAmount'] ?? 0) as num).toDouble();

        if (!metricsMap.containsKey(workerId)) {
          metricsMap[workerId] = WorkerMetrics(
            workerId: workerId,
            workerName: workerName,
            totalSales: 0,
            transactionCount: 0,
            averageSale: 0,
          );
        }

        metricsMap[workerId]!.totalSales += amount;
        metricsMap[workerId]!.transactionCount += 1;
      }

      // Calculate averages
      for (final metrics in metricsMap.values) {
        metrics.averageSale = metrics.transactionCount > 0
            ? metrics.totalSales / metrics.transactionCount
            : 0;
      }

      // Sort based on selected criteria
      final sortedMetrics = metricsMap.values.toList();
      _sortWorkers(sortedMetrics);

      if (mounted) {
        setState(() {
          _workerMetrics = sortedMetrics;
          _isLoading = false;
          print('[Leaderboard] Loaded ${_workerMetrics.length} workers');
        });
      }
    } catch (e) {
      print('[Leaderboard] Error loading worker metrics: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _sortWorkers(List<WorkerMetrics> workers) {
    switch (_sortBy) {
      case 'count':
        workers
            .sort((a, b) => b.transactionCount.compareTo(a.transactionCount));
        break;
      case 'average':
        workers.sort((a, b) => b.averageSale.compareTo(a.averageSale));
        break;
      case 'sales':
      default:
        workers.sort((a, b) => b.totalSales.compareTo(a.totalSales));
    }
  }

  String _formatCurrency(double amount) {
    return '₦${NumberFormat('#,##0.00').format(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Leaderboard'),
        elevation: 0,
        backgroundColor: isDark ? Colors.grey[900] : AppColors.background,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Range Selector
              DateRangeSelector(
                onRangeChanged: (newRange) {
                  setState(() {
                    _selectedDateRange = newRange;
                    _isLoading = true;
                  });
                  _loadWorkerMetrics();
                },
                initialRange: _selectedDateRange,
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 24),

              // Sort Options
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSortButton('sales', 'Total Sales'),
                    const SizedBox(width: 12),
                    _buildSortButton('count', 'Transactions'),
                    const SizedBox(width: 12),
                    _buildSortButton('average', 'Avg Sale'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Summary Stats
              if (!_isLoading && _workerMetrics.isNotEmpty)
                _buildSummaryStats()
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 100.ms),

              const SizedBox(height: 24),

              // Leaderboard List
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                )
              else if (_workerMetrics.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No workers found',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _workerMetrics.length,
                  itemBuilder: (context, index) {
                    final metrics = _workerMetrics[index];
                    final rank = (index + 1).toString();
                    final medal = _medalEmojis[rank] ?? '  ';

                    return _buildWorkerCard(
                      rank: rank,
                      medal: medal,
                      metrics: metrics,
                      isDark: isDark,
                      index: index,
                    )
                        .animate()
                        .fadeIn(
                          duration: 300.ms,
                          delay: Duration(milliseconds: 50 * index),
                        )
                        .slideX(
                          begin: -0.1,
                          duration: 300.ms,
                          delay: Duration(milliseconds: 50 * index),
                        );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortButton(String sortValue, String label) {
    final isSelected = _sortBy == sortValue;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FilterChip(
      label: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white70 : Colors.black87),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _sortBy = sortValue;
          _sortWorkers(_workerMetrics);
        });
      },
      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
      selectedColor: AppColors.primary,
      side: BorderSide(
        color: isSelected ? AppColors.primary : Colors.transparent,
      ),
    );
  }

  Widget _buildSummaryStats() {
    if (_workerMetrics.isEmpty) return const SizedBox.shrink();
    final totalSales = _workerMetrics.fold<double>(
      0,
      (sum, w) => sum + w.totalSales,
    );
    final totalTransactions = _workerMetrics.fold<int>(
      0,
      (sum, w) => sum + w.transactionCount,
    );
    final avgWorkerSales = _workerMetrics.isNotEmpty
        ? totalSales / _workerMetrics.length.toDouble()
        : 0.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Team Summary',
            style: AppTextStyles.headingSmall.copyWith(
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                label: 'Total Team Sales',
                value: _formatCurrency(totalSales),
                isDark: isDark,
              ),
              _buildStatItem(
                label: 'Total Transactions',
                value: totalTransactions.toString(),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                label: 'Workers Active',
                value: _workerMetrics.length.toString(),
                isDark: isDark,
              ),
              _buildStatItem(
                label: 'Avg Per Worker',
                value: _formatCurrency(avgWorkerSales),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkerCard({
    required String rank,
    required String medal,
    required WorkerMetrics metrics,
    required bool isDark,
    required int index,
  }) {
    final isTopThree = index < 3;
    final borderColor = isTopThree
        ? AppColors.primary.withOpacity(0.3)
        : (isDark ? Colors.grey[700]! : Colors.grey[200]!);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? Colors.grey[800] : Colors.white,
      elevation: isTopThree ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Rank Medal
                Text(
                  medal,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 16),

                // Worker Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#$rank • ${metrics.workerName}',
                        style: AppTextStyles.headingSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${metrics.transactionCount} transactions',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Total Sales
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(metrics.totalSales),
                      style: AppTextStyles.headingSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isTopThree
                            ? AppColors.primary
                            : (isDark ? Colors.white : Colors.black),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Avg: ${_formatCurrency(metrics.averageSale)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Performance Bar
            if (metrics.totalSales > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: metrics.totalSales /
                      (_workerMetrics.first.totalSales * 1.1),
                  minHeight: 6,
                  backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class WorkerMetrics {
  final String workerId;
  final String workerName;
  double totalSales;
  int transactionCount;
  double averageSale;

  WorkerMetrics({
    required this.workerId,
    required this.workerName,
    required this.totalSales,
    required this.transactionCount,
    required this.averageSale,
  });
}

