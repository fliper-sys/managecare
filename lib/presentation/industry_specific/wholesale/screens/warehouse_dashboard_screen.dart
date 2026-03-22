import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/constants/routes.dart' show Routes;
import '../../../../providers/auth_provider.dart';
import '../providers/wholesale_provider.dart';

class WarehouseDashboardScreen extends StatefulWidget {
  const WarehouseDashboardScreen({super.key});

  @override
  State<WarehouseDashboardScreen> createState() =>
      _WarehouseDashboardScreenState();
}

class _WarehouseDashboardScreenState extends State<WarehouseDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<WholesaleProvider>();
      provider.loadProducts();
      provider.loadWarehouses();
      provider.loadPurchaseOrders();
      provider.loadStockTransfers();
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer<WholesaleProvider>(
        builder: (context, provider, _) {
          final totalItems = provider.getTotalItems();
          final inventoryValue = provider.getTotalInventoryValue();
          final lowStockCount = provider.getLowStockProducts().length;
          final totalProducts = provider.products.length;
          final pendingOrders = provider.getPendingPurchaseOrdersCount();
          final inTransitTransfers = provider.getInTransitTransfersCount();

          return Stack(
            children: [
              // 1. Top Gradient Background
              Container(
                height: 280,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                      Colors.blueAccent.shade700,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
              ),

              // 2. Main Content
              SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Text
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Warehouse',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Text(
                                    'Overview',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                                      onPressed: () => _showWholesaleAlerts(provider),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.logout, color: Colors.white),
                                      onPressed: () async {
                                        try {
                                          await context.read<AuthProvider>().logout();
                                          if (context.mounted) Navigator.of(context).pushReplacementNamed(Routes.login);
                                        } catch (e) {
                                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Hero Value Card
                          _HeroValueCard(value: inventoryValue),

                          const SizedBox(height: 24),

                          // Quick Stats Row (Scrollable if needed, or fixed)
                          Row(
                            children: [
                              Expanded(
                                child: _CompactStatCard(
                                  label: 'Products',
                                  value: totalProducts.toString(),
                                  icon: Icons.qr_code_2,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _CompactStatCard(
                                  label: 'Total Items',
                                  value: totalItems.toString(),
                                  icon: Icons.layers,
                                  color: Colors.indigo,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FutureBuilder<double>(
                                  future: provider.getTodaysSalesTotal(),
                                  builder: (context, snapshot) {
                                    final sales = snapshot.data ?? 0.0;
                                    return _CompactStatCard(
                                      label: 'Sold Today',
                                      value: formatCurrency(sales, decimalDigits: 0),
                                      icon: Icons.trending_up,
                                      color: Colors.green,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Alert Banner
                          if (lowStockCount > 0)
                            _LowStockBanner(count: lowStockCount),

                          const SizedBox(height: 24),

                          // Operations Grid
                          const Text(
                            'Operations',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.4,
                            children: [
                              _OperationCard(
                                title: 'Inventory',
                                icon: Icons.inventory_2_outlined,
                                color: Colors.blue,
                                onTap: () => _navigateTo('inventory'),
                              ),
                              _OperationCard(
                                title: 'POS / Sales',
                                icon: Icons.point_of_sale,
                                color: Colors.purple,
                                onTap: () => _navigateTo('pos'),
                              ),
                              _OperationCard(
                                title: 'Purchase Orders',
                                icon: Icons.shopping_bag_outlined,
                                color: Colors.orange,
                                onTap: () => _navigateTo('purchase'),
                              ),
                              _OperationCard(
                                title: 'Transfers',
                                icon: Icons.local_shipping_outlined,
                                color: Colors.teal,
                                onTap: () => _navigateTo('transfer'),
                              ),
                              _OperationCard(
                                title: 'Reports',
                                icon: Icons.analytics_outlined,
                                color: Colors.cyan,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  Routes.wholesaleReports,
                                ),
                              ),
                              _OperationCard(
                                title: 'Manage Warehouses',
                                icon: Icons.store_mall_directory_outlined,
                                color: Colors.brown,
                                onTap: () => Navigator.pushNamed(context, Routes.wholesaleWarehouses),
                              ),
                              _OperationCard(
                                title: 'Create Warehouse',
                                icon: Icons.add_business_outlined,
                                color: Colors.deepOrange,
                                onTap: () => Navigator.pushNamed(context, Routes.wholesaleWarehouses, arguments: {'openAdd': true}),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Recent Activity Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Recent Orders',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  Routes.wholesalePurchaseOrders,
                                ),
                                child: const Text('View All'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _CompactStatCard(
                                  label: 'Pending POs',
                                  value: pendingOrders.toString(),
                                  icon: Icons.assignment_late_outlined,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _CompactStatCard(
                                  label: 'Transfers',
                                  value: inTransitTransfers.toString(),
                                  icon: Icons.local_shipping_outlined,
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                          
                          // Recent List
                          if (provider.purchaseOrders.isEmpty)
                            _EmptyState()
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: provider.purchaseOrders.take(3).length,
                              itemBuilder: (context, index) {
                                final order = provider.purchaseOrders[index];
                                return _OrderListTile(order: order);
                              },
                            ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _navigateTo(String route) {
    switch (route) {
      case 'inventory':
        Navigator.pushNamed(context, Routes.wholesaleInventory);
        break;
      case 'pos':
        Navigator.pushNamed(context, Routes.wholesalePos);
        break;
      case 'purchase':
        Navigator.pushNamed(context, Routes.wholesalePurchaseOrders);
        break;
      case 'transfer':
        Navigator.pushNamed(context, Routes.wholesaleTransfers);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening $route...')),
        );
    }
  }

  void _showWholesaleAlerts(WholesaleProvider provider) {
    final lowStock = provider.getLowStockProducts();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Wholesale Alerts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                lowStock.isEmpty
                    ? 'No low-stock alerts right now.'
                    : '${lowStock.length} products need attention.',
              ),
              const SizedBox(height: 12),
              ...lowStock.take(5).map(
                (product) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                  ),
                  title: Text(product.name),
                  subtitle: Text(
                    'Qty ${product.quantity} / Reorder ${product.reorderLevel}',
                  ),
                ),
              ),
              if (lowStock.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'And ${lowStock.length - 5} more products.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- WIDGETS ---

class _HeroValueCard extends StatelessWidget {
  final double value;

  const _HeroValueCard({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.monetization_on,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Total Inventory Value',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            formatCurrency(value, decimalDigits: 0), // Requires intl package or simple formatting
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.arrow_upward, size: 16, color: Colors.green),
              const SizedBox(width: 4),
              Text(
                'Updated just now',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _CompactStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LowStockBanner extends StatelessWidget {
  final int count;

  const _LowStockBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.white],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber_rounded, color: Colors.orange[800]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Low Stock Alert',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
                Text(
                  '$count items are running low',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.orange[300]),
        ],
      ),
    );
  }
}

class _OperationCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _OperationCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderListTile extends StatelessWidget {
  final dynamic order; // Replace dynamic with PurchaseOrder model

  const _OrderListTile({required this.order});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long, color: Colors.grey),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PO #${order.id.substring(order.id.length - 6).toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${order.items.length} Items',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(order.total),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text(
              'No recent activity',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

