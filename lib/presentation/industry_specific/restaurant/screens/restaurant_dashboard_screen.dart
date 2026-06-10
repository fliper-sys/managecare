import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/email_service.dart';
import '../providers/restaurant_provider.dart';

class RestaurantDashboardScreen extends StatelessWidget {
  const RestaurantDashboardScreen({super.key});

  Map<String, String> _buildInsights(RestaurantProvider provider) {
    final mealCounts = <String, int>{};
    final mealMargin = <String, double>{};
    final waiterCounts = <String, int>{};
    final tableCounts = <String, int>{};
    final menuCostById = {
      for (final item in provider.menuItems) item.id: item.cost ?? 0.0,
    };

    for (final order in provider.orders) {
      if (order.status == 'cancelled') continue;
      final tableKey = order.orderTargetLabel ??
          (order.tableNumber != null ? 'Table ${order.tableNumber}' : 'Walk-in');
      tableCounts[tableKey] = (tableCounts[tableKey] ?? 0) + 1;

      String? waiterName;
      for (final server in provider.servers) {
        if (server.id == order.assignedWaiterId && server.name.isNotEmpty) {
          waiterName = server.name;
          break;
        }
      }
      if (waiterName != null) {
        waiterCounts[waiterName] = (waiterCounts[waiterName] ?? 0) + 1;
      }

      for (final item in order.items) {
        mealCounts[item.menuItemName] =
            (mealCounts[item.menuItemName] ?? 0) + item.quantity;
        final baseCost = menuCostById[item.menuItemId] ?? 0.0;
        mealMargin[item.menuItemName] =
            (mealMargin[item.menuItemName] ?? 0.0) +
                ((item.price - baseCost) * item.quantity);
      }
    }

    String topLabel<T extends num>(Map<String, T> source, String fallback) {
      if (source.isEmpty) return fallback;
      final sorted = source.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sorted.first.key;
    }

    return {
      'topMeal': topLabel(mealCounts, 'No sales yet'),
      'bestMarginMeal': topLabel(mealMargin, 'No margin data'),
      'topWaiter': topLabel(waiterCounts, 'Unassigned'),
      'busiestTable': topLabel(tableCounts, 'No table activity'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1724) : const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text(
          'Restaurant Overview',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              Icons.people_outline,
              color: theme.colorScheme.onSurface,
            ),
            tooltip: 'Manage Workers',
            onPressed: () => Navigator.pushNamed(context, Routes.workers),
          ),
          IconButton(
            icon: Icon(
              Icons.logout,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            tooltip: 'Logout',
            onPressed: () async {
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
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<RestaurantProvider>(
        builder: (context, provider, _) {
          final pendingOrders =
              provider.orders
                  .where((o) => o.status == 'pending' || o.status == 'confirmed')
                  .length;
          final completedOrders =
              provider.orders.where((o) => o.status == 'completed').toList();
          final totalOrders = provider.orders.length;
          final occupiedTables =
              provider.tables.where((t) => t.status == 'occupied').length;
          final avgOrderValue = completedOrders.isNotEmpty
              ? completedOrders.fold<double>(
                    0,
                    (sum, order) => sum + order.total,
                  ) /
                  completedOrders.length
              : 0.0;
          final insights = _buildInsights(provider);

          const lowThreshold = 5;
          final lowStockItems = provider.menuItems
              .where(
                (m) => m.inventoryStock != null && m.inventoryStock! <= lowThreshold,
              )
              .toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final statusCardWidth = constraints.maxWidth < 720
                  ? constraints.maxWidth
                  : ((constraints.maxWidth - 12) / 2);
              final actionTileWidth = constraints.maxWidth < 900
                  ? constraints.maxWidth
                  : ((constraints.maxWidth - 12) / 2);
              final summaryCardWidth = constraints.maxWidth < 560
                  ? constraints.maxWidth
                  : ((constraints.maxWidth - 24) / 3);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Live Status', style: AppTextStyles.heading5),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: statusCardWidth,
                          child: _LiveStatusCard(
                            title: 'Pending Orders',
                            value: '$pendingOrders',
                            icon: Icons.notifications_active,
                            color: Colors.orange,
                            isUrgent: pendingOrders > 0,
                          ),
                        ),
                        SizedBox(
                          width: statusCardWidth,
                          child: _LiveStatusCard(
                            title: 'Active Tables',
                            value: '$occupiedTables',
                            icon: Icons.table_restaurant,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(
                          width: statusCardWidth,
                          child: _LiveStatusCard(
                            title: 'Total Orders',
                            value: '$totalOrders',
                            icon: Icons.receipt_long,
                            color: Colors.green,
                            isSecondary: true,
                          ),
                        ),
                        SizedBox(
                          width: statusCardWidth,
                          child: _LiveStatusCard(
                            title: 'Awaiting Payment',
                            value:
                                '${provider.pendingPaymentOrders.where((o) => o.status == 'ready' || o.status == 'served').length}',
                            icon: Icons.payments_outlined,
                            color: Colors.deepPurple,
                            isSecondary: true,
                          ),
                        ),
                        SizedBox(
                          width: statusCardWidth,
                          child: _LiveStatusCard(
                            title: 'Avg. Value',
                            value: formatCurrency(avgOrderValue),
                            icon: Icons.analytics,
                            color: Colors.purple,
                            isSecondary: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Management', style: AppTextStyles.heading5),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final auth = Provider.of<AuthProvider>(context);
                        final role = auth.currentUser?.role ?? '';
                        final actions = <Widget>[];

                        if (auth.isOwnerUser ||
                            WorkerPermissions.hasPermission(role, 'manage_menu') ||
                            WorkerPermissions.canManageStaff(role)) {
                          actions.add(
                            _ActionTile(
                              icon: Icons.kitchen,
                              color: Colors.redAccent,
                              label: 'Kitchen Display',
                              subtitle: 'View active tickets',
                              onTap: () => Navigator.pushNamed(
                                context,
                                Routes.restaurantKitchen,
                              ),
                            ),
                          );
                        }

                        if (auth.isOwnerUser ||
                            WorkerPermissions.hasPermission(role, 'view_orders') ||
                            WorkerPermissions.canManageSales(role)) {
                          actions.add(
                            _ActionTile(
                              icon: Icons.post_add,
                              color: AppColors.primary,
                              label: 'New Order',
                              subtitle: 'Take a dine-in or takeaway order',
                              onTap: () => Navigator.pushNamed(
                                context,
                                Routes.restaurantMenu,
                              ),
                            ),
                          );
                          actions.add(
                            _ActionTile(
                              icon: Icons.post_add,
                              color: Colors.deepPurple,
                              label: 'Add Menu Item',
                              subtitle: 'Register meals and combos',
                              onTap: () => Navigator.pushNamed(
                                context,
                                Routes.restaurantManageMenu,
                                arguments: {'openAdd': true},
                              ),
                            ),
                          );
                        }

                        actions.add(
                          _ActionTile(
                            icon: Icons.print,
                            color: Colors.teal,
                            label: 'Printer Settings',
                            subtitle: 'Configure printers',
                            onTap: () => Navigator.pushNamed(
                              context,
                              Routes.printerSettings,
                            ),
                          ),
                        );

                        if (auth.isOwnerUser ||
                            WorkerPermissions.hasPermission(role, 'view_orders') ||
                            WorkerPermissions.canManageSales(role)) {
                          actions.add(
                            _ActionTile(
                              icon: Icons.receipt_long,
                              color: Colors.green,
                              label: 'Orders',
                              subtitle: 'View and manage orders',
                              onTap: () => Navigator.pushNamed(
                                context,
                                Routes.restaurantOrders,
                              ),
                            ),
                          );
                        }

                        if (auth.isOwnerUser ||
                            WorkerPermissions.canManageStaff(role) ||
                            WorkerPermissions.canManageSales(role)) {
                          actions.add(
                            _ActionTile(
                              icon: Icons.table_restaurant,
                              color: Colors.brown,
                              label: 'Tables',
                              subtitle: 'Manage table seating',
                              onTap: () => Navigator.pushNamed(
                                context,
                                Routes.restaurantTables,
                              ),
                            ),
                          );
                          actions.add(
                            _ActionTile(
                              icon: Icons.add_business,
                              color: Colors.blueGrey,
                              label: 'Register Table',
                              subtitle: 'Add a new table size/setup',
                              onTap: () => Navigator.pushNamed(
                                context,
                                Routes.restaurantTables,
                                arguments: {'openAdd': true},
                              ),
                            ),
                          );
                          actions.add(
                            _ActionTile(
                              icon: Icons.inventory_2_outlined,
                              color: Colors.teal,
                              label: 'Restaurant Stock',
                              subtitle: 'Track stock and spoilage',
                              onTap: () => Navigator.pushNamed(
                                context,
                                Routes.restaurantStock,
                              ),
                            ),
                          );
                        }

                        if (auth.isOwnerUser ||
                            WorkerPermissions.hasPermission(role, 'bookings')) {
                          actions.add(
                            _ActionTile(
                              icon: Icons.event,
                              color: Colors.indigo,
                              label: 'Reservations',
                              subtitle: 'View bookings',
                              onTap: () => Navigator.pushNamed(
                                context,
                                Routes.restaurantReservations,
                              ),
                            ),
                          );
                        }

                        if (auth.isOwnerUser ||
                            WorkerPermissions.hasPermission(role, 'sales') ||
                            WorkerPermissions.hasPermission(role, 'manage_menu')) {
                          actions.add(
                            _ActionTile(
                              icon: Icons.delivery_dining,
                              color: Colors.cyan,
                              label: 'Delivery',
                              subtitle: 'Manage deliveries',
                              onTap: () => Navigator.pushNamed(
                                context,
                                Routes.restaurantDelivery,
                              ),
                            ),
                          );
                        }

                        if (auth.isOwnerUser ||
                            WorkerPermissions.canManageStaff(role)) {
                          actions.add(
                            _ActionTile(
                              icon: Icons.person,
                              color: Colors.deepOrange,
                              label: 'Staff',
                              subtitle: 'Manage waiters',
                              onTap: () => Navigator.pushNamed(
                                context,
                                Routes.restaurantWaiters,
                              ),
                            ),
                          );
                        }

                        if (auth.isOwnerUser ||
                            WorkerPermissions.canManageSales(role) ||
                            WorkerPermissions.hasPermission(role, 'sales')) {
                          actions.add(
                            _ActionTile(
                              icon: Icons.receipt_long,
                              color: Colors.blue,
                              label: 'Orders History',
                              subtitle: 'Track service flow and checkout',
                              onTap: () => Navigator.pushNamed(
                                context,
                                Routes.restaurantOrders,
                              ),
                            ),
                          );
                        }

                        if (auth.isOwnerUser ||
                            WorkerPermissions.canViewInventory(role) ||
                            WorkerPermissions.hasPermission(role, 'inventory')) {
                          actions.add(
                            _ActionTile(
                              icon: Icons.inventory,
                              color: Colors.green,
                              label: 'Inventory',
                              subtitle: 'Manage stock',
                              onTap: () => Navigator.pushNamed(
                                context,
                                Routes.inventory,
                              ),
                            ),
                          );
                        }

                        if (auth.isOwnerUser ||
                            WorkerPermissions.hasPermission(role, 'customers')) {
                          actions.add(
                            _ActionTile(
                              icon: Icons.people,
                              color: Colors.purple,
                              label: 'Customers',
                              subtitle: 'View customers',
                              onTap: () => Navigator.pushNamed(
                                context,
                                Routes.customers,
                              ),
                            ),
                          );
                        }

                        if (auth.isOwnerUser ||
                            WorkerPermissions.hasPermission(role, 'view_reports')) {
                          actions.add(
                            _ActionTile(
                              icon: Icons.bar_chart,
                              color: Colors.cyan,
                              label: 'Reports',
                              subtitle: 'View reports',
                              onTap: () => Navigator.pushNamed(
                                context,
                                Routes.reports,
                              ),
                            ),
                          );
                        }

                        actions.add(
                          _ActionTile(
                            icon: Icons.support_agent_rounded,
                            color: Colors.green,
                            label: 'Customer Care',
                            subtitle: 'Chat on WhatsApp',
                            onTap: () => WhatsAppUtils.openCustomerSupport(context),
                          ),
                        );

                        if (actions.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: const Text(
                              'No actions available',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: actions
                              .map(
                                (action) => SizedBox(
                                  width: actionTileWidth,
                                  child: action,
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                    if (lowStockItems.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Inventory Alerts (${lowStockItems.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...lowStockItems.map((item) => _LowStockCard(item: item)),
                    ],
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Service Insights', style: AppTextStyles.heading5),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _InsightChip(
                                label: 'Top Meal',
                                value: insights['topMeal'] as String,
                              ),
                              _InsightChip(
                                label: 'Best Margin',
                                value: insights['bestMarginMeal'] as String,
                              ),
                              _InsightChip(
                                label: 'Top Waiter',
                                value: insights['topWaiter'] as String,
                              ),
                              _InsightChip(
                                label: 'Busiest Table',
                                value: insights['busiestTable'] as String,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Menu Overview',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: summaryCardWidth,
                                child: _SummaryStat(
                                  'Total Items',
                                  '${provider.menuItems.length}',
                                ),
                              ),
                              SizedBox(
                                width: summaryCardWidth,
                                child: _SummaryStat(
                                  'Available',
                                  '${provider.menuItems.where((m) => m.available).length}',
                                  color: Colors.green,
                                ),
                              ),
                              SizedBox(
                                width: summaryCardWidth,
                                child: _SummaryStat(
                                  'Sold Out',
                                  '${provider.menuItems.where((m) => !m.available).length}',
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LiveStatusCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isSecondary;
  final bool isUrgent;

  const _LiveStatusCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isSecondary = false,
    this.isUrgent = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUrgent
            ? color
            : (isDark ? const Color(0xFF162033) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.16 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: isUrgent
            ? null
            : Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.grey.shade100,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isUrgent
                      ? Colors.white.withOpacity(0.2)
                      : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isUrgent ? Colors.white : color,
                ),
              ),
              if (isUrgent)
                const Icon(
                  Icons.priority_high,
                  size: 16,
                  color: Colors.white70,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isUrgent
                  ? Colors.white
                  : (isDark ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isUrgent
                  ? Colors.white.withOpacity(0.9)
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF162033) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.14 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  final dynamic item;

  const _LowStockCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Colors.redAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.brown,
                  ),
                ),
                Text(
                  'Only ${item.inventoryStock} left in stock',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              elevation: 0,
              side: BorderSide(color: Colors.red.shade200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: () {
              final userEmail = context.read<AuthProvider>().currentUser?.email;
              if (userEmail != null && userEmail.isNotEmpty) {
                EmailService().sendLowStockAlert(userEmail, {
                  'product': item.name,
                  'current': (item.inventoryStock ?? 0).toString(),
                  'minimum': '5',
                  'reorderQuantity': '50',
                }).then((sent) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        sent
                            ? 'Reorder email sent'
                            : 'Reorder placed (email failed)',
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }).catchError((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reorder placed'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reorder placed'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Reorder'),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryStat(this.label, this.value, {this.color = Colors.black87});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color == Colors.black87 && isDark ? Colors.white : color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey.shade400 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightChip extends StatelessWidget {
  final String label;
  final String value;

  const _InsightChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
