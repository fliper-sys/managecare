import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/retail_provider.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../core/access_control.dart';
import '../../../../core/constants/routes.dart' show Routes;
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/whatsapp_utils.dart';

class RetailDashboard extends StatefulWidget {
  final bool isBakery;

  const RetailDashboard({super.key}) : isBakery = false;

  const RetailDashboard.bakery({super.key}) : isBakery = true;

  @override
  State<RetailDashboard> createState() => _RetailDashboardState();
}

class _RetailDashboardState extends State<RetailDashboard> {
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();

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
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Bakery and retail share the same Manage Care blue/white branding —
    // only tile labels ("Bakery POS" vs "Open POS") differ, not colors.
    final accentColor = AppColors.primary;

    return Scaffold(
      backgroundColor:
          isDark ? colorScheme.surface : const Color(0xFFF5F8FF),
      body: SafeArea(
        child: Consumer<RetailProvider>(
          builder: (context, retailProvider, _) {
            final lowStockCount =
                retailProvider.products.where((p) => p.stock < 10).length;
            final totalRevenue = retailProvider.products.fold<double>(
              0,
              (sum, p) => sum + (p.price * (100 - p.stock)),
            );
            // No cap: disabled (not-yet-granted) tiles are now shown
            // alongside enabled ones rather than omitted, so cutting the
            // list short would hide tiles a worker should be able to see.
            final quickActions = _getQuickActionItems(context);

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRetailHero(
                    context,
                    accentColor: accentColor,
                    totalRevenue: totalRevenue,
                    userName: user?.fullName ?? 'User',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _RetailStatCard(
                          label: widget.isBakery ? 'Outlets' : 'Stores',
                          value: '${retailProvider.stores.length}',
                          caption: widget.isBakery
                              ? 'Active outlets'
                              : 'Active stores',
                          icon: Icons.storefront_rounded,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RetailStatCard(
                          label: widget.isBakery ? 'Low Batches' : 'Low Stock',
                          value: '$lowStockCount',
                          caption: 'Needs attention',
                          icon: Icons.inventory_2_outlined,
                          color: AppColors.warning,
                          showChevron: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.20 : 0.05),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _RetailSegment(
                          icon: Icons.eco_outlined,
                          label: widget.isBakery ? 'Fresh Items' : 'Top Items',
                          isSelected: _selectedTabIndex == 0,
                          color: accentColor,
                          onTap: () => setState(() => _selectedTabIndex = 0),
                        ),
                        _RetailSegment(
                          icon: Icons.storefront_outlined,
                          label: widget.isBakery ? 'Outlets' : 'Stores',
                          isSelected: _selectedTabIndex == 1,
                          color: accentColor,
                          onTap: () => setState(() => _selectedTabIndex = 1),
                        ),
                        _RetailSegment(
                          icon: Icons.flash_on_rounded,
                          label: 'Actions',
                          isSelected: _selectedTabIndex == 2,
                          color: accentColor,
                          onTap: () => setState(() => _selectedTabIndex = 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSelectedContent(context, retailProvider, quickActions),
                  const SizedBox(height: 24),
                  _RetailCtaCard(
                    title:
                        widget.isBakery ? 'New Bakery Sale' : 'New Retail Sale',
                    subtitle: 'Create a new sale transaction',
                    color: accentColor,
                    onTap: () => Navigator.pushNamed(context, Routes.retailPos),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRetailHero(
    BuildContext context, {
    required Color accentColor,
    required double totalRevenue,
    required String userName,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final heroText = isDark ? colorScheme.onSurface : const Color(0xFF06111F);
    final mutedHeroText =
        isDark ? colorScheme.onSurfaceVariant : Colors.black.withOpacity(0.76);
    final bubbleColor =
        isDark ? colorScheme.surfaceContainerHighest : Colors.white;
    // Same Manage Care blue/white gradient for bakery and retail.
    final heroGradient = isDark
        ? [
            colorScheme.primary.withOpacity(0.24),
            colorScheme.surfaceContainerHighest,
          ]
        : [AppColors.primary.withOpacity(0.18), Colors.white];

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: bubbleColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.isBakery
                      ? Icons.bakery_dining_outlined
                      : Icons.storefront_rounded,
                  color: accentColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good evening',
                      style: TextStyle(
                        color: mutedHeroText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      widget.isBakery ? 'Bakery' : 'Retail Store',
                      style: TextStyle(
                        color: heroText,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: heroText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _RetailCircleButton(
                icon: Icons.notifications_none_rounded,
                onTap: () => Navigator.pushNamed(context, Routes.notifications),
              ),
              const SizedBox(width: 10),
              _RetailCircleButton(
                icon: Icons.logout_rounded,
                onTap: () async {
                  try {
                    await context.read<AuthProvider>().logout();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacementNamed(Routes.login);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Logout failed: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            width: 300,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surface
                  : const Color(0xFF071225),
              borderRadius: BorderRadius.circular(16),
              border: isDark
                  ? Border.all(color: colorScheme.outlineVariant)
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isBakery
                            ? 'Bakery Stock Value'
                            : 'Retail Stock Value',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.68),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'N${(totalRevenue / 1000).toStringAsFixed(1)}k',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total inventory value',
                        style: TextStyle(color: Colors.white.withOpacity(0.60)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.show_chart_rounded, color: accentColor, size: 42),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedContent(
    BuildContext context,
    RetailProvider retailProvider,
    List<Widget> quickActions,
  ) {
    if (_selectedTabIndex == 0) {
      final topProducts = retailProvider.products
          .where((p) => p.stock > 0)
          .toList()
        ..sort((a, b) => b.price.compareTo(a.price));
      final displayed = topProducts.take(10).toList();

      if (displayed.isEmpty) {
        return _buildEmptyState(
          widget.isBakery ? 'No bakery items found' : 'No products found',
        );
      }

      return Column(
        children: [
          for (var index = 0; index < displayed.length; index++)
            _ProductListTile(product: displayed[index], index: index),
        ],
      );
    } else if (_selectedTabIndex == 1) {
      final stores = retailProvider.stores;
      if (stores.isEmpty) {
        return _buildEmptyState(
          widget.isBakery
              ? 'No bakery outlets configured'
              : 'No stores configured',
        );
      }

      return Column(
        children: [
          for (var index = 0; index < stores.length; index++)
            _StoreListTile(store: stores[index], index: index),
        ],
      );
    }

    if (quickActions.isEmpty) return _buildEmptyState('No actions available');

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: quickActions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemBuilder: (context, index) => quickActions[index],
    );
  }

  // Kept for older sliver callers if this dashboard is embedded elsewhere.
  Widget _buildSliverContent(
      BuildContext context, RetailProvider retailProvider) {
    if (_selectedTabIndex == 0) {
      final topProducts = retailProvider.products
          .where((p) => p.stock > 0)
          .toList()
        ..sort((a, b) => b.price.compareTo(a.price));
      final displayed = topProducts.take(10).toList();

      if (displayed.isEmpty) {
        return _buildEmptySliver(
          widget.isBakery ? 'No bakery items found' : 'No products found',
        );
      }

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
      if (stores.isEmpty) {
        return _buildEmptySliver(
          widget.isBakery
              ? 'No bakery outlets configured'
              : 'No stores configured',
        );
      }

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
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.35,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => items[index],
            childCount: items.length,
          ),
        ),
      );
    }
  }

  Widget _buildEmptyState(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
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
    );
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
    final currentPermissions = auth.currentUser?.permissions ?? const <String>[];
    final businessType = Provider.of<BusinessProvider>(context, listen: false)
        .currentBusiness
        ?.businessType
        .toLowerCase() ??
      'retail';
    final isBakeryBusiness = businessType.contains('bakery') || widget.isBakery;
    final normalizedRole = WorkerPermissions.normalizeRole(role);
    final hasFullAccess =
      ['owner', 'admin', 'sub_admin', 'manager'].contains(normalizedRole);
    final items = <Widget>[];
    final bool isOwner = auth.isOwnerUser;

    // Helper permission checks
    bool can(bool Function(String) check) => check(role);

    // Add items helper. Tiles the current user isn't permitted to use are
    // still shown (per admin request) but dimmed, and tapping them explains
    // how to get access instead of silently doing nothing.
    void add(
      IconData icon,
      String label,
      String route,
      Color color, {
      bool enabled = true,
    }) {
      items.add(_QuickActionCard(
        icon: icon,
        label: label,
        color: color,
        enabled: enabled,
        onTap: enabled
            ? () => Navigator.pushNamed(context, route)
            : () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ask your admin to enable "$label"')),
                ),
      ));
    }

    if (isOwner) {
      add(
        Icons.point_of_sale,
        widget.isBakery ? 'Bakery POS' : 'Open POS',
        Routes.retailPos,
        AppColors.primary,
      );
      add(
        Icons.storefront,
        widget.isBakery ? 'Bakery Outlets' : 'Manage Stores',
        Routes.retailStores,
        AppColors.info,
      );
      add(
        Icons.event_busy,
        widget.isBakery ? 'Freshness Tracker' : 'Expiry Tracker',
        Routes.expiryTracker,
        Colors.red,
      );
      add(
        Icons.add_box,
        widget.isBakery ? 'Add Bakery Item' : 'Add Product',
        Routes.retailAddProduct,
        AppColors.success,
      );
      add(
        Icons.local_shipping,
        widget.isBakery ? 'Ingredient Suppliers' : 'Suppliers',
        Routes.retailSuppliers,
        Colors.orange,
      );
      // Bakery-specific navs: inventory, procurements, reports
      if (isBakeryBusiness) {
        add(
          Icons.inventory_2,
          'Inventory',
          Routes.inventory,
          AppColors.primary,
        );
        add(
          Icons.playlist_add_check,
          'Record Resupply',
          Routes.bakeryResupply,
          Colors.brown,
        );
        add(
          Icons.shopping_bag,
          'Bakery Procurements',
          Routes.bakeryProcurements,
          Colors.deepOrange,
        );
        add(
          Icons.history,
          'Procurement History',
          Routes.procurementHistory,
          Colors.blueGrey,
        );
        add(
          Icons.report,
          'Inventory Report',
          Routes.inventoryReport,
          Colors.teal,
        );
        add(
          Icons.trending_up,
          'Baker Performance',
          Routes.bakeryBakerPerformanceReport,
          Colors.purple,
        );
      }
      add(Icons.bar_chart, 'Reports', Routes.retailStoreReports, Colors.teal);
      add(Icons.print, 'Printer Settings', Routes.printerSettings, Colors.teal);
    } else {
      // `view_inventory`/`view_sales_history` are meant for lighter-weight
      // "can see stock/sales info" purposes elsewhere in the app (e.g. POS),
      // not full screen access — a cashier has both by default, so gating
      // whole screens on them was granting inventory/reports access nobody
      // approved. Screen-access tiles below are gated on the permissions
      // actually meant for that (`manage_inventory`/`access_inventory_screen`,
      // `view_reports`/`access_reports_dashboard`), which a cashier starts
      // without and an admin grants explicitly via the worker's permissions.
      final canManageSales =
          WorkerPermissions.canManageSalesForUser(role, currentPermissions);
      final canManageInv =
          WorkerPermissions.canManageInventoryForUser(role, currentPermissions);
      final canViewReports = AccessControl.canViewReports(context);
      final canViewDistributorSales =
          can(WorkerPermissions.canViewAnalytics) || canViewReports;
      final canViewSalesHistory =
          canManageSales || can(WorkerPermissions.canViewAnalytics);

      add(
        Icons.point_of_sale,
        widget.isBakery ? 'Bakery POS' : 'Open POS',
        Routes.bakerySales,
        AppColors.primary,
        enabled: canManageSales,
      );
      add(
        Icons.receipt_long_rounded,
        'Sales History',
        Routes.salesHistory,
        AppColors.info,
        enabled: canViewSalesHistory,
      );
      add(
        Icons.event_busy,
        widget.isBakery ? 'Freshness Tracker' : 'Expiry Tracker',
        Routes.expiryTracker,
        Colors.red,
        enabled: canManageInv,
      );
      add(
        Icons.add_box,
        widget.isBakery ? 'Add Bakery Item' : 'Add Product',
        Routes.retailAddProduct,
        AppColors.success,
        enabled: canManageInv,
      );
      if (isBakeryBusiness) {
        add(
          Icons.inventory_2,
          'Inventory',
          Routes.inventory,
          AppColors.primary,
          enabled: canManageInv,
        );
        add(
          Icons.playlist_add_check,
          'Record Resupply',
          Routes.bakeryResupply,
          Colors.brown,
          enabled: canManageInv,
        );
        add(
          Icons.report,
          'Inventory Report',
          Routes.inventoryReport,
          Colors.teal,
          enabled: canManageInv,
        );
        add(
          Icons.local_shipping,
          'Distributor Sales',
          Routes.distributorSalesReport,
          Colors.deepOrange,
          enabled: canViewDistributorSales,
        );
      }
      add(
        Icons.bar_chart,
        'Reports',
        Routes.retailStoreReports,
        Colors.teal,
        enabled: canViewReports,
      );
    }

    items.add(_QuickActionCard(
      icon: Icons.support_agent_rounded,
      label: 'Customer Care',
      color: Colors.green,
      onTap: () => WhatsAppUtils.openCustomerSupport(context),
    ));
    return items;
  }
}

// --- MODERNIZED COMPONENTS ---

class _RetailCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RetailCircleButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isDark ? colorScheme.onSurface : const Color(0xFF06111F),
        ),
      ),
    );
  }
}

class _RetailStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
  final bool showChevron;

  const _RetailStatCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.06),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const Spacer(),
              if (showChevron)
                Icon(Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const Divider(height: 24),
          Text(
            caption,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _RetailSegment extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _RetailSegment({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unselectedColor = colorScheme.onSurface;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: isSelected ? Colors.white : unselectedColor),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : unselectedColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RetailCtaCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RetailCtaCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.30),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.20),
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  const Icon(Icons.local_fire_department, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.white.withOpacity(0.78)),
                  ),
                ],
              ),
            ),
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFF071225),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isAlert ? color : colorScheme.outlineVariant)
              .withOpacity(isAlert ? 0.45 : 0.85),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(colorScheme.brightness == Brightness.dark ? 0.26 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
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
          const SizedBox(height: 16),
          Text(value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              )),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
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
  final bool enabled;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileColor = enabled ? color : colorScheme.outline;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: colorScheme.outlineVariant.withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.22 : 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: tileColor.withOpacity(isDark ? 0.22 : 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: tileColor, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(
                enabled ? Icons.chevron_right_rounded : Icons.lock_outline_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
