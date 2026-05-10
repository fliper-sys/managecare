import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui'; // For glassmorphism effects
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/retail_provider.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../core/access_control.dart';
import '../../../../core/constants/routes.dart' show Routes;
import '../../../../core/theme/colors.dart';


class RetailDashboard extends StatefulWidget {
  const RetailDashboard({super.key});

  @override
  State<RetailDashboard> createState() => _RetailDashboardState();
}

class _RetailDashboardState extends State<RetailDashboard>
    with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 0;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final businessId = Provider.of<BusinessProvider>(context, listen: false)
          .currentBusiness
          ?.id;
      final retailProvider =
          Provider.of<RetailProvider>(context, listen: false);

      if (businessId != null) {
        retailProvider.initialize(businessId);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface, // Softer background
      body: Consumer<RetailProvider>(
        builder: (context, retailProvider, _) {
          // Pre-calculate stats
          final lowStockCount =
              retailProvider.products.where((p) => p.stock < 10).length;
          final totalRevenue = retailProvider.products.fold<double>(
            0,
            (sum, p) => sum + (p.price * (100 - p.stock)),
          );

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Modern Sliver Header with Revenue
              SliverAppBar(
                expandedHeight: 200.0,
                floating: false,
                pinned: true,
                backgroundColor: AppColors.primary,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          AppColors.primaryDark,
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Decorative Circle
                        Positioned(
                          right: -30,
                          top: -30,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        // Revenue Content
                        Positioned(
                          bottom: 60,
                          left: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Estimated Revenue',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '₦${(totalRevenue / 1000).toStringAsFixed(1)}k',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_outlined,
                          color: Colors.white),
                      onPressed: () {},
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
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
              ),
              // 2. Horizontal Stats Row (Overlapping the header slightly)
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -40),
                  child: SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _HorizontalStatCard(
                          label: 'Products',
                          value: '${retailProvider.products.length}',
                          icon: Icons.inventory_2_outlined,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        _HorizontalStatCard(
                          label: 'Stores',
                          value: '${retailProvider.stores.length}',
                          icon: Icons.storefront_outlined,
                          color: Colors.purple,
                        ),
                        const SizedBox(width: 12),
                        _HorizontalStatCard(
                          label: 'Low Stock',
                          value: '$lowStockCount',
                          icon: Icons.warning_amber_rounded,
                          color: Colors.orange,
                          isAlert: lowStockCount > 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Tab Selector
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        _SegmentedTab(
                          label: 'Top Items',
                          isSelected: _selectedTabIndex == 0,
                          onTap: () => setState(() => _selectedTabIndex = 0),
                        ),
                        _SegmentedTab(
                          label: 'Stores',
                          isSelected: _selectedTabIndex == 1,
                          onTap: () => setState(() => _selectedTabIndex = 1),
                        ),
                        _SegmentedTab(
                          label: 'Actions',
                          isSelected: _selectedTabIndex == 2,
                          onTap: () => setState(() => _selectedTabIndex = 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverPadding(padding: EdgeInsets.only(top: 20)),

              // 4. Dynamic Content Area
              _buildSliverContent(context, retailProvider),

              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, Routes.retailPos),
        backgroundColor: AppColors.primary,
        elevation: 4,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('New Sale'),
      ),
    );
  }

  // Helper to switch content based on tabs using Slivers
  Widget _buildSliverContent(
      BuildContext context, RetailProvider retailProvider) {
    if (_selectedTabIndex == 0) {
      // --- Top Products List ---
      final topProducts = retailProvider.products
          .where((p) => p.stock > 0)
          .toList()
        ..sort((a, b) => b.price.compareTo(a.price));
      final displayed = topProducts.take(10).toList();

      if (displayed.isEmpty) return _buildEmptySliver('No products found');

      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return _ProductListTile(product: displayed[index], index: index);
            },
            childCount: displayed.length,
          ),
        ),
      );
    } else if (_selectedTabIndex == 1) {
      // --- Stores List ---
      final stores = retailProvider.stores;
      if (stores.isEmpty) return _buildEmptySliver('No stores configured');

      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return _StoreListTile(store: stores[index], index: index);
            },
            childCount: stores.length,
          ),
        ),
      );
    } else {
      // --- Quick Actions Grid ---
      final items = _getQuickActionItems(context);
      if (items.isEmpty) return _buildEmptySliver('No actions available');

      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => items[index],
            childCount: items.length,
          ),
        ),
      );
    }
  }

  Widget _buildEmptySliver(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox_outlined,
                  size: 48, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 10),
              Text(message,
                  style: TextStyle(color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _getQuickActionItems(BuildContext context) {
    // Logic extracted from original code to keep build clean
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final role = auth.currentUser?.role ?? '';
    final items = <Widget>[];
    final bool isOwner = auth.isOwnerUser;

    // Helper permission checks
    bool can(bool Function(String) check) => check(role);

    // Add items helper
    void add(IconData icon, String label, String route, Color color) {
      items.add(_QuickActionCard(
        icon: icon,
        label: label,
        color: color,
        onTap: () => Navigator.pushNamed(context, route),
      ));
    }

    if (isOwner) {
      add(Icons.point_of_sale, 'Open POS', Routes.retailPos, AppColors.primary);
      add(Icons.storefront, 'Manage Stores', Routes.retailStores,
          AppColors.info);
      add(Icons.inventory_2, 'Catalog', Routes.retailCatalog, Colors.indigo);
      add(Icons.event_busy, 'Expiry Tracker', Routes.expiryTracker, Colors.red);
      add(Icons.add_box, 'Add Product', Routes.retailAddProduct,
          AppColors.success);
      add(Icons.local_shipping, 'Suppliers', Routes.retailSuppliers,
          Colors.orange);
      add(Icons.bar_chart, 'Reports', Routes.retailStoreReports, Colors.teal);
      add(Icons.print, 'Printer Settings', Routes.printerSettings, Colors.teal);
    } else {
      if (WorkerPermissions.canManageSales(role)) {
        add(Icons.point_of_sale, 'Open POS', Routes.retailPos,
            AppColors.primary);
      }
      if (WorkerPermissions.canViewInventory(role)) {
        add(Icons.inventory_2, 'Catalog', Routes.retailCatalog, Colors.indigo);
        add(Icons.event_busy, 'Expiry Tracker', Routes.expiryTracker,
            Colors.red);
      }
      if (WorkerPermissions.canManageInventory(role)) {
        add(Icons.add_box, 'Add Product', Routes.retailAddProduct,
            AppColors.success);
      }
      if (can(WorkerPermissions.canViewAnalytics) ||
          AccessControl.canViewReports(context)) {
        add(Icons.bar_chart, 'Reports', Routes.retailStoreReports, Colors.teal);
      }
    }
    return items;
  }
}

// --- MODERNIZED COMPONENTS ---

class _HorizontalStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isAlert;

  const _HorizontalStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: isAlert ? Border.all(color: color.withOpacity(0.5)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              if (isAlert)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentedTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.surfaceContainerHighest
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? AppColors.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductListTile extends StatelessWidget {
  final dynamic product;
  final int index;

  const _ProductListTile({required this.product, required this.index});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '#${index + 1}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: product.stock < 10
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${product.stock} Left',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: product.stock < 10
                              ? Colors.orange
                              : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '₦${product.price.toStringAsFixed(0)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreListTile extends StatelessWidget {
  final dynamic store;
  final int index;

  const _StoreListTile({required this.store, required this.index});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(store.location,
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
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
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
