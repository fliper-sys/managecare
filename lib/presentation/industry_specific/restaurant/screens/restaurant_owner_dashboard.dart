import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../providers/restaurant_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../services/email_service.dart';

class RestaurantDashboardScreen extends StatelessWidget {
  const RestaurantDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Restaurant Overview', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.people_outline, color: Colors.grey[800]),
            tooltip: 'Manage Workers',
            onPressed: () => Navigator.pushNamed(context, Routes.workers),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.grey),
            tooltip: 'Logout',
            onPressed: () async {
              try {
                await context.read<AuthProvider>().logout();
                if (context.mounted) Navigator.of(context).pushReplacementNamed(Routes.login);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<RestaurantProvider>(
        builder: (context, provider, _) {
          // --- Calculations ---
          final pendingOrders = provider.orders.where((o) => o.status == 'pending').length;
          final pendingPaymentOrders = provider.pendingPaymentOrders;
          final readyToBill = pendingPaymentOrders.where((o) => o.status == 'ready').length;
          final totalOrders = provider.orders.length;
          final occupiedTables = provider.tables.where((t) => t.status == 'occupied').length;
          final recentOrders = provider.recentOrders.take(5).toList();
          
          final paidOrders = provider.orders.where((o) => o.paymentStatus == 'paid').toList();
          final avgOrderValue = paidOrders.isNotEmpty
              ? paidOrders.fold<double>(0, (sum, order) => sum + order.total) / paidOrders.length
              : 0.0;

          // Placeholder for logic since MenuItem usually doesn't have a direct stock int in some models, 
          // but assuming the original code had a list:
          final lowStockItems = []; 
          // (Populate lowStockItems based on your actual data model logic here if available)

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Status Overview
                const Text('Live Status', style: AppTextStyles.heading5),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: _LiveStatusCard(
                        title: 'Pending Orders',
                        value: '$pendingOrders',
                        icon: Icons.notifications_active,
                        color: Colors.orange,
                        isUrgent: pendingOrders > 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LiveStatusCard(
                        title: 'Active Tables',
                        value: '$occupiedTables',
                        icon: Icons.table_restaurant,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _LiveStatusCard(
                        title: 'Pending Payment',
                        value: '${pendingPaymentOrders.length}',
                        icon: Icons.payments_outlined,
                        color: Colors.redAccent,
                        isSecondary: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LiveStatusCard(
                        title: 'Ready to Bill',
                        value: '$readyToBill',
                        icon: Icons.receipt_long,
                        color: Colors.green,
                        isSecondary: true,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 2. Quick Actions (Permission Based)
                const Text('Management', style: AppTextStyles.heading5),
                const SizedBox(height: 12),
                Builder(builder: (context) {
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
                        onTap: () => Navigator.pushNamed(context, Routes.restaurantKitchen),
                      ),
                    );
                  }

                  if (auth.isOwnerUser ||
                      WorkerPermissions.hasPermission(role, 'view_orders') ||
                      WorkerPermissions.canManageSales(role)) {
                    actions.add(
                      _ActionTile(
                        icon: Icons.menu_book,
                        color: AppColors.primary,
                        label: 'Create Order',
                        subtitle: 'Take a new restaurant order',
                        onTap: () => Navigator.pushNamed(context, Routes.restaurantMenu),
                      ),
                    );

                    actions.add(
                      _ActionTile(
                        icon: Icons.payments_outlined,
                        color: Colors.green,
                        label: 'Pending Payment',
                        subtitle: 'Process open restaurant bills',
                        onTap: () => Navigator.pushNamed(context, Routes.restaurantOrders),
                      ),
                    );
                  }

                  // Management actions for menu editing and quick add
                  if (auth.isOwnerUser || WorkerPermissions.hasPermission(role, 'manage_menu')) {
                    actions.add(
                      _ActionTile(
                        icon: Icons.manage_accounts,
                        color: AppColors.primary,
                        label: 'Manage Menu',
                        subtitle: 'Add / Edit menu items',
                        onTap: () => Navigator.pushNamed(context, Routes.restaurantManageMenu),
                      ),
                    );

                    actions.add(
                      _ActionTile(
                        icon: Icons.add_circle_outline,
                        color: Colors.green,
                        label: 'Add Menu Item',
                        subtitle: 'Quickly add a new item',
                        onTap: () => Navigator.pushNamed(context, Routes.restaurantManageMenu, arguments: {'openAdd': true}),
                      ),
                    );
                  }

                  if (auth.isOwnerUser ||
                      WorkerPermissions.hasPermission(role, 'bookings')) {
                    actions.add(
                      _ActionTile(
                        icon: Icons.event_seat,
                        color: Colors.indigo,
                        label: 'Reservations',
                        subtitle: 'Manage seating reservations',
                        onTap: () => Navigator.pushNamed(context, Routes.restaurantReservations),
                      ),
                    );
                  }

                  if (auth.isOwnerUser ||
                      WorkerPermissions.canManageSales(role)) {
                    actions.add(
                      _ActionTile(
                        icon: Icons.table_restaurant,
                        color: Colors.brown,
                        label: 'Tables',
                        subtitle: 'Track occupied and open tables',
                        onTap: () => Navigator.pushNamed(context, Routes.restaurantTables),
                      ),
                    );
                    actions.add(
                      _ActionTile(
                        icon: Icons.inventory_2_outlined,
                        color: Colors.teal,
                        label: 'Restaurant Stock',
                        subtitle: 'View stock and loss logs',
                        onTap: () => Navigator.pushNamed(context, Routes.restaurantStock),
                      ),
                    );
                  }

                  if (auth.isOwnerUser || WorkerPermissions.canManageStaff(role)) {
                    actions.add(
                      _ActionTile(
                        icon: Icons.groups_2_outlined,
                        color: Colors.deepOrange,
                        label: 'Staff',
                        subtitle: 'Assign kitchen and floor staff',
                        onTap: () => Navigator.pushNamed(context, Routes.restaurantWaiters),
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
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: const Text('No actions available', textAlign: TextAlign.center),
                    );
                  }
                  
                  // Wrap actions in a Grid-like column
                  return Column(
                    children: actions.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: e,
                    )).toList(),
                  );
                }),

                const SizedBox(height: 24),

                // 3. Recent Orders
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recent Orders', style: AppTextStyles.heading5),
                      const SizedBox(height: 8),
                      Text(
                        '$totalOrders total orders | NGN ${avgOrderValue.toStringAsFixed(0)} average paid ticket',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      if (recentOrders.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'No restaurant orders yet.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      else
                        ...recentOrders.map((order) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _RecentOrderTile(order: order),
                            )),
                    ],
                  ),
                ),

                // 4. Low Stock Alerts
                if (lowStockItems.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red),
                      const SizedBox(width: 8),
                      Text('Inventory Alerts (${lowStockItems.length})', 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...lowStockItems.map((item) => _LowStockCard(item: item)),
                ],

                const SizedBox(height: 24),

                // 5. Menu Summary
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Menu Overview', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SummaryStat('Total Items', '${provider.menuItems.length}'),
                          _VerticalDivider(),
                          _SummaryStat('Available', '${provider.menuItems.where((m) => m.available).length}', color: Colors.green),
                          _VerticalDivider(),
                          _SummaryStat('Sold Out', '${provider.menuItems.where((m) => !m.available).length}', color: Colors.grey),
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
      ),
    );
  }
}

// ---------------- Helper Widgets ----------------

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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUrgent ? color : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: isUrgent ? null : Border.all(color: Colors.grey.shade100),
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
                  color: isUrgent ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: isUrgent ? Colors.white : color),
              ),
              if (isUrgent)
                 const Icon(Icons.priority_high, size: 16, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isUrgent ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isUrgent ? Colors.white.withOpacity(0.9) : Colors.grey.shade600,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
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
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  final RestaurantOrder order;

  const _RecentOrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final statusColor = order.paymentStatus == 'paid'
        ? AppColors.success
        : order.status == 'ready'
            ? Colors.orange
            : AppColors.primary;
    final timeLabel =
        '${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_long, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customerName ?? 'Walk-in order',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Table ${order.tableNumber ?? 'N/A'} | ${order.items.length} items | $timeLabel',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'NGN ${order.total.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${order.status.toUpperCase()} | ${order.paymentStatus.toUpperCase()}',
                style: TextStyle(color: statusColor, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  final dynamic item; // Replace with your MenuItem type

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
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Text(item.emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                Text('Only ${item.stock} left in stock', 
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
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
              // Reorder Logic preserved exactly
              final userEmail = context.read<AuthProvider>().currentUser?.email;
              if (userEmail != null && userEmail.isNotEmpty) {
                EmailService().sendLowStockAlert(userEmail, {
                  'product': item.name,
                  'current': item.stock.toString(),
                  'minimum': '5',
                  'reorderQuantity': '50',
                }).then((sent) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(sent ? 'Reorder email sent' : 'Reorder placed (email failed)'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }).catchError((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reorder placed'), backgroundColor: AppColors.success),
                  );
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reorder placed'), backgroundColor: AppColors.success),
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
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 30, width: 1, color: Colors.grey.shade200);
  }
}
