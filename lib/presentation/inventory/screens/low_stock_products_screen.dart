import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../presentation/inventory/widgets/expiry_badge.dart';
import '../../../providers/business_provider.dart';
import '../../../services/low_stock_detection_service.dart';

/// Enhanced Low Stock Products Screen
/// 
/// Displays products with inventory below a configurable threshold.
/// Uses the unified LowStockDetectionService for consistent detection logic.
/// 
/// Features:
/// - Dynamic threshold adjustment (1-100 units)
/// - Real-time filtering with Firestore
/// - Automatic sorting (lowest stock first)
/// - Color-coded stock status (red/orange/green)
/// - Comprehensive product details
/// - Quick reorder actions
/// - Detailed statistics dashboard
enum InventoryAlertMode { lowStock, expiry }

class LowStockProductsScreen extends StatefulWidget {
  const LowStockProductsScreen({super.key});

  @override
  State<LowStockProductsScreen> createState() => _LowStockProductsScreenState();
}

class _LowStockProductsScreenState extends State<LowStockProductsScreen> {
  late LowStockDetectionService _detectionService;
  late Future<List<LowStockProduct>> _lowStockProducts;
  late Future<List<ExpiringProduct>> _expiringProducts;
  late Future<LowStockSummary> _stockSummary;
  InventoryAlertMode _selectedMode = InventoryAlertMode.lowStock;
  int _minStockThreshold = 10;
  int _expiringThresholdDays = 7;
  bool _showStatistics = true;

  @override
  void initState() {
    super.initState();
    _detectionService = LowStockDetectionService();
    _loadItems();
  }

  void _loadItems() {
    final businessProvider = context.read<BusinessProvider>();
    final businessId = businessProvider.currentBusiness?.id;

    if (businessId == null) {
      setState(() {
        _lowStockProducts = Future.error('No business selected');
        _stockSummary = Future.error('No business selected');
        _expiringProducts = Future.error('No business selected');
      });
      return;
    }

    setState(() {
      _lowStockProducts = _detectionService.detectLowStockProducts(
        businessId: businessId,
        threshold: _minStockThreshold,
        sortByQuantity: true,
      );
      _stockSummary = _detectionService.getLowStockSummary(
        businessId: businessId,
        threshold: _minStockThreshold,
      );
      _expiringProducts = _detectionService.detectExpiringProducts(
        businessId: businessId,
        daysThreshold: _expiringThresholdDays,
        includeExpired: true,
        sortByExpiryDate: true,
      );
    });
  }

  void _updateThreshold(int newThreshold) {
    setState(() {
      _minStockThreshold = newThreshold;
      if (_selectedMode == InventoryAlertMode.lowStock) {
        _loadItems();
      }
    });
  }

  void _updateExpiryThreshold(int newDays) {
    setState(() {
      _expiringThresholdDays = newDays;
      if (_selectedMode == InventoryAlertMode.expiry) {
        _loadItems();
      }
    });
  }

  void _toggleStatistics() {
    setState(() {
      _showStatistics = !_showStatistics;
    });
  }

  void _selectMode(InventoryAlertMode mode) {
    if (_selectedMode == mode) return;
    setState(() {
      _selectedMode = mode;
      _loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text('Low Stock Products'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadItems,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(_showStatistics ? Icons.bar_chart : Icons.visibility),
            onPressed: _toggleStatistics,
            tooltip: _showStatistics ? 'Hide Stats' : 'Show Stats',
          ),
        ],
      ),
      floatingActionButton: _buildExpiryTrackerFab(context),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 📊 Statistics Dashboard (if enabled)
              if (_showStatistics)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FutureBuilder<LowStockSummary>(
                    future: _stockSummary,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final summary = snapshot.data!;
                        return _buildStatisticsDashboard(summary, isDark);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),

              // 🎚️ Threshold Filter Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  elevation: 0,
                  color: isDark ? Colors.grey[800] : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Stock Threshold',
                              style: AppTextStyles.heading5.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withAlpha(50),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$_minStockThreshold units',
                                style: AppTextStyles.body2.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Slider(
                          value: _minStockThreshold.toDouble(),
                          min: 1,
                          max: 100,
                          divisions: 99,
                          label: '$_minStockThreshold units',
                          activeColor: AppColors.warning,
                          inactiveColor: Colors.grey[300],
                          onChanged: (value) {
                            _updateThreshold(value.toInt());
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('1 unit', style: AppTextStyles.caption),
                            Text('100 units', style: AppTextStyles.caption),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // 📦 Low Stock Products List
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FutureBuilder<List<LowStockProduct>>(
                  future: _lowStockProducts,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading products...',
                              style: AppTextStyles.body2Secondary,
                            ),
                          ],
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading products',
                              style: AppTextStyles.heading5,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.error.toString(),
                              style: AppTextStyles.caption,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              onPressed: _loadItems,
                            ),
                          ],
                        ),
                      );
                    }

                    final products = snapshot.data ?? [];

                    if (products.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'All Set! 🎉',
                              style: AppTextStyles.heading4.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No products below $_minStockThreshold units',
                              style: AppTextStyles.body2Secondary,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Adjust the threshold slider to see more products',
                              style: AppTextStyles.caption,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Results header
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            children: [
                              Text(
                                '${products.length} Product${products.length != 1 ? 's' : ''}',
                                style: AppTextStyles.heading5.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withAlpha(50),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '⚠️ Below threshold',
                                  style: AppTextStyles.caption.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Products list
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return _buildProductCard(product, isDark);
                          },
                        ),

                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build statistics dashboard card
  Widget _buildStatisticsDashboard(LowStockSummary summary, bool isDark) {
    return Card(
      elevation: 2,
      color: isDark ? Colors.grey[800] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Inventory Health',
                  style: AppTextStyles.heading5.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getHealthColor(summary.percentageLow).withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    summary.healthStatus,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _getHealthColor(summary.percentageLow),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatTile(
                  icon: '📦',
                  label: 'Total',
                  value: '${summary.totalProducts}',
                  isDark: isDark,
                ),
                _buildStatTile(
                  icon: '⚠️',
                  label: 'Low Stock',
                  value: '${summary.lowStockCount}',
                  isDark: isDark,
                ),
                _buildStatTile(
                  icon: '🔴',
                  label: 'Critical',
                  value: '${summary.criticalCount}',
                  isDark: isDark,
                ),
                _buildStatTile(
                  icon: '💰',
                  label: 'Loss Value',
                  value: '₦${summary.potentialLoss.toStringAsFixed(0)}',
                  isDark: isDark,
                  small: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: summary.percentageLow / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation(
                  _getHealthColor(summary.percentageLow),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${summary.percentageLow.toStringAsFixed(1)}% of inventory is below threshold',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }

  /// Build individual product card
  Widget _buildProductCard(LowStockProduct product, bool isDark) {
    final statusColor = _getStockStatusColor(product.status);
    final statusLabel = _getStockStatusLabel(product.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      color: isDark ? Colors.grey[800] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withAlpha(50),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status indicator
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                // Product name and status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: AppTextStyles.heading5.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            statusLabel,
                            style: AppTextStyles.caption.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              product.category,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Quick actions
                PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Text('Edit Product'),
                      onTap: () {
                        // TODO: Navigate to edit product screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Edit product feature coming soon')),
                        );
                      },
                    ),
                    PopupMenuItem(
                      child: const Text('Place Reorder'),
                      onTap: () {
                        // TODO: Navigate to reorder screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reorder feature coming soon')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Product details grid
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    icon: '📊',
                    label: 'Current',
                    value: '${product.quantity} ${product.unit}',
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailItem(
                    icon: '🔄',
                    label: 'Reorder Level',
                    value: '${product.reorderLevel} ${product.unit}',
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailItem(
                    icon: '📋',
                    label: 'Suggested',
                    value: '${product.recommendedReorderQuantity} ${product.unit}',
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Cost details
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    icon: '💵',
                    label: 'Cost Price',
                    value: '₦${product.costPrice.toStringAsFixed(2)}',
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailItem(
                    icon: '🏷️',
                    label: 'Selling Price',
                    value: '₦${product.sellingPrice.toStringAsFixed(2)}',
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailItem(
                    icon: '🚨',
                    label: 'Loss Value',
                    value: '₦${product.potentialLoss.toStringAsFixed(0)}',
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Supplier and restocked info
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    icon: '🚚',
                    label: 'Supplier',
                    value: product.supplier,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailItem(
                    icon: '📅',
                    label: 'Last Restocked',
                    value: product.formattedLastRestocked,
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Place Reorder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  // TODO: Navigate to procurement/reorder screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Reorder ${product.name}'),
                      action: SnackBarAction(
                        label: 'Details',
                        onPressed: () {
                          // Show reorder details
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build detail item widget
  Widget _buildDetailItem({
    required String icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[700] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$icon $label',
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.body1.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Build statistic tile
  Widget _buildStatTile({
    required String icon,
    required String label,
    required String value,
    required bool isDark,
    bool small = false,
  }) {
    return Column(
      children: [
        Text(
          icon,
          style: TextStyle(fontSize: small ? 20 : 24),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: (small ? AppTextStyles.body1 : AppTextStyles.body2).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(fontSize: 10),
        ),
      ],
    );
  }

  /// Get stock status color
  Color _getStockStatusColor(StockStatus status) {
    switch (status) {
      case StockStatus.outOfStock:
        return Colors.red;
      case StockStatus.critical:
        return Colors.deepOrange;
      case StockStatus.low:
        return Colors.orange;
      case StockStatus.normal:
        return Colors.green;
      case StockStatus.overstock:
        return Colors.blue;
    }
  }

  /// Get stock status label
  String _getStockStatusLabel(StockStatus status) {
    switch (status) {
      case StockStatus.outOfStock:
        return '❌ Out of Stock';
      case StockStatus.critical:
        return '🔴 Critical';
      case StockStatus.low:
        return '🟠 Low';
      case StockStatus.normal:
        return '🟢 Normal';
      case StockStatus.overstock:
        return '🔵 Overstock';
    }
  }

  /// Build bakery-only expiry tracker FAB
  Widget? _buildExpiryTrackerFab(BuildContext context) {
    final businessType = context.read<BusinessProvider>().currentBusiness?.businessType?.toString().toLowerCase() ?? '';
    final isBakeryBusiness = businessType == 'bakery' || businessType == 'bakeryshop' || businessType == 'bakeshop';

    if (!isBakeryBusiness) return null;

    return FloatingActionButton.extended(
      backgroundColor: Colors.red,
      icon: const Icon(Icons.event_busy_rounded),
      label: const Text('Freshness Tracker'),
      onPressed: () {
        Navigator.pushNamed(context, Routes.expiryTracker);
      },
    );
  }

  /// Get health color based on percentage
  Color _getHealthColor(double percentage) {
    if (percentage > 50) {
      return Colors.red;
    } else if (percentage > 20) {
      return Colors.orange;
    } else if (percentage > 0) {
      return Colors.amber;
    } else {
      return Colors.green;
    }
  }
}
