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
    final accentColor =
        widget.isBakery ? const Color(0xFFFF8A18) : AppColors.primary;

    return Scaffold(
      backgroundColor:
          widget.isBakery ? const Color(0xFFF8F6F1) : const Color(0xFFF5F8FF),
      body: SafeArea(
        child: Consumer<RetailProvider>(
          builder: (context, retailProvider, _) {
            final lowStockCount =
                retailProvider.products.where((p) => p.stock < 10).length;
            final totalRevenue = retailProvider.products.fold<double>(
              0,
              (sum, p) => sum + (p.price * (100 - p.stock)),
            );
            final quickActions = _getQuickActionItems(context).take(6).toList();

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
                          caption: widget.isBakery ? 'Active outlets' : 'Active stores',
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
                          color: widget.isBakery
                              ? const Color(0xFFEBA33A)
                              : AppColors.warning,
                          showChevron: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
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
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: quickActions.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.95,
                    ),
                    itemBuilder: (context, index) => quickActions[index],
                  ),
                  const SizedBox(height: 24),
                  _RetailCtaCard(
                    title: widget.isBakery ? 'New Bakery Sale' : 'New Retail Sale',
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
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isBakery
              ? const [Color(0xFFFFF2D8), Color(0xFFFFC56F), Color(0xFFD97706)]
              : [AppColors.primary.withOpacity(0.18), Colors.white],
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
                decoration: const BoxDecoration(
                  color: Colors.white,
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
                        color: Colors.black.withOpacity(0.76),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      widget.isBakery ? 'Bakery' : 'Retail Store',
                      style: const TextStyle(
                        color: Color(0xFF06111F),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF06111F),
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
              color: const Color(0xFF071225),
              borderRadius: BorderRadius.circular(16),
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
      add(
        Icons.point_of_sale,
        widget.isBakery ? 'Bakery POS' : 'Open POS',
        Routes.retailPos,
        widget.isBakery ? const Color(0xFFD97706) : AppColors.primary,
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
      add(Icons.bar_chart, 'Reports', Routes.retailStoreReports, Colors.teal);
      add(Icons.print, 'Printer Settings', Routes.printerSettings, Colors.teal);
    } else {
      if (WorkerPermissions.canManageSalesForUser(role, currentPermissions)) {
        add(
          Icons.point_of_sale,
          widget.isBakery ? 'Bakery POS' : 'Open POS',
          Routes.retailPos,
          widget.isBakery ? const Color(0xFFD97706) : AppColors.primary,
        );
      }
      if (WorkerPermissions.canViewInventoryForUser(role, currentPermissions)) {
        add(
          Icons.event_busy,
          widget.isBakery ? 'Freshness Tracker' : 'Expiry Tracker',
          Routes.expiryTracker,
          Colors.red,
        );
      }
      if (WorkerPermissions.canManageInventoryForUser(
        role,
        currentPermissions,
      )) {
        add(
          Icons.add_box,
          widget.isBakery ? 'Add Bakery Item' : 'Add Product',
          Routes.retailAddProduct,
          AppColors.success,
        );
      }
      if (can(WorkerPermissions.canViewAnalytics) ||
          AccessControl.canViewReports(context)) {
        add(Icons.bar_chart, 'Reports', Routes.retailStoreReports, Colors.teal);
      }
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF06111F)),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF687082)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF06111F),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF06111F),
            ),
          ),
          const Divider(height: 24),
          Text(
            caption,
            style: TextStyle(color: Colors.black.withOpacity(0.48)),
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
                  color: isSelected ? Colors.white : const Color(0xFF06111F)),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        isSelected ? Colors.white : const Color(0xFF06111F),
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

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF06111F),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quick access',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.black.withOpacity(0.48)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF687082)),
          ],
        ),
      ),
    );
  }
}
