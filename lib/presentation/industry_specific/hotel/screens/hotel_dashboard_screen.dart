import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/whatsapp_utils.dart';

import '../../../../core/constants/routes.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/hotel_provider.dart';

class HotelDashboardScreen extends StatelessWidget {

    // --- SUMMARY HEADER (Revenue, Active Occupancy/Rooms, Customers, Workers) ---
    // Per the requirements doc: swap "Sales" for "Revenue" (done previously),
    // rename "Orders" / "Active Rooms" to "Active Occupancy/Rooms", keep
    // "Customers", and ADD "Workers" so all four required tiles are present.
    Widget _buildSummaryHeader(BuildContext context, HotelProvider provider) {
      return FutureBuilder<double>(
        future: provider.getTodaysSalesTotal(),
        builder: (context, snapshot) {
          final todaysRevenue = snapshot.data ?? 0.0;
          final workersCount = context
                  .watch<BusinessProvider>()
                  .currentBusiness
                  ?.totalWorkers ??
              0;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withOpacity(0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 5))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryTile(
                  icon: Icons.payments_outlined,
                  label: 'Revenue (Today)',
                  value: formatCurrency(todaysRevenue, decimalDigits: 0),
                  color: Colors.greenAccent.shade100,
                ),
                _buildSummaryTile(
                  icon: Icons.hotel_outlined,
                  label: 'Active Occupancy',
                  value: '${provider.occupiedRooms}/${provider.totalRooms}',
                  color: Colors.blue.shade100,
                ),
                _buildSummaryTile(
                  icon: Icons.people_alt_outlined,
                  label: 'Customers',
                  value: '${provider.guestProfiles.length}',
                  color: Colors.amber.shade100,
                ),
                _buildSummaryTile(
                  icon: Icons.badge_outlined,
                  label: 'Workers',
                  value: '$workersCount',
                  color: Colors.purple.shade100,
                ),
              ],
            ),
          );
        },
      );
    }

    Widget _buildSummaryTile({
      required IconData icon,
      required String label,
      required String value,
      required Color color,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.black87, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      );
    }
  const HotelDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final auth = Provider.of<AuthProvider>(context);
    final role = auth.currentUser?.role ?? '';
    final permissions = auth.currentUser?.permissions ?? const <String>[];
    final canBook = WorkerPermissions.hasEffectivePermission(
      role,
      permissions,
      'bookings',
    );
    final canAccessOperations =
        WorkerPermissions.hasEffectivePermission(role, permissions, 'guest_checkin') ||
        WorkerPermissions.hasEffectivePermission(role, permissions, 'guest_checkout') ||
        WorkerPermissions.hasEffectivePermission(role, permissions, 'billing') ||
        WorkerPermissions.hasEffectivePermission(role, permissions, 'manage_rooms') ||
        WorkerPermissions.hasEffectivePermission(role, permissions, 'room_service') ||
        WorkerPermissions.hasEffectivePermission(role, permissions, 'maintenance_requests') ||
        WorkerPermissions.hasEffectivePermission(role, permissions, 'manage_pool_bookings') ||
        WorkerPermissions.canManageSalesForUser(role, permissions) ||
        WorkerPermissions.canViewInventoryForUser(role, permissions);
    final canManageStaff = auth.isOwnerUser ||
        WorkerPermissions.canManageStaffForUser(role, permissions);

    return Scaffold(
      backgroundColor: colorScheme.surface, // Modern light background
      appBar: AppBar(
        title: const Column(
          children: [
            Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Overview & Quick Actions',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        elevation: 0,
        actions: [
          if (canManageStaff)
            IconButton(
              icon: const Icon(Icons.people_alt_outlined),
              tooltip: 'Manage Workers',
              onPressed: () => Navigator.pushNamed(context, Routes.workers),
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
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
                      SnackBar(content: Text('Logout failed: $e')));
                }
              }
            },
          ),
        ],
      ),
      body: Consumer<HotelProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. SUMMARY HEADER (Revenue, Active Occupancy, Customers, Workers)
                _buildSummaryHeader(context, provider),
                const SizedBox(height: 24),

                // 2. KPI GRID
                Row(
                  children: [
                    Expanded(
                        child: _buildMetricTile(
                      context: context,
                      icon: Icons.pie_chart_outline,
                      title: 'Occupancy',
                      value: '${provider.occupancy.toStringAsFixed(1)}%',
                      color: Colors.blue,
                    )),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildMetricTile(
                      context: context,
                      icon: Icons.bed_outlined,
                      title: 'Active Occupancy/Rooms',
                      value: '${provider.occupiedRooms}/${provider.totalRooms}',
                      color: Colors.purple,
                    )),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _buildMetricTile(
                      context: context,
                      icon: Icons.check_circle_outline,
                      title: 'Occupied',
                      value: '${provider.occupiedRooms}',
                      color: Colors.green,
                    )),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildMetricTile(
                      context: context,
                      icon: Icons.star_border_rounded,
                      title: 'Rating',
                      value: provider.getAverageRating().toStringAsFixed(1),
                      color: Colors.orange,
                    )),
                  ],
                ),
                const SizedBox(height: 24),

                // 3. ROOM STATUS VISUALIZATION
                Text('Room Status Distribution',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildRoomStatusBar(context, provider),
                const SizedBox(height: 24),

                // 4. TODAY'S ACTIVITY
                Text('Today\'s Activity',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildTodaysSummaryRow(provider),
                const SizedBox(height: 24),

                // 5. QUICK ACTIONS GRID
                Text('Quick Actions',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildActionGrid(
                  context,
                  canBook,
                  canAccessOperations,
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildRevenueHeader(HotelProvider provider) {
    return FutureBuilder<double>(
      future: provider.getTodaysSalesTotal(),
      builder: (context, snapshot) {
        final todaysRevenue = snapshot.data ?? 0.0;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Revenue (Today)',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.9), fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                    formatCurrency(todaysRevenue, decimalDigits: 0),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle),
                child: const Icon(Icons.attach_money,
                    color: Colors.white, size: 30),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              )),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        ],
      ),
    );
  }

  Widget _buildRoomStatusBar(BuildContext context, HotelProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final dist = provider.getRoomStatusDistribution();


    // Calculate Flex values
    final availFlex = dist['available'] ?? 0;
    final occFlex = dist['occupied'] ?? 0;
    final maintFlex = dist['maintenance'] ?? 0;
    final resFlex = dist['reserved'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // Visual Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (availFlex > 0)
                    Expanded(
                        flex: availFlex,
                        child: Container(color: Colors.green)),
                  if (occFlex > 0)
                    Expanded(
                        flex: occFlex,
                        child: Container(color: Colors.blue)),
                  if (resFlex > 0)
                    Expanded(
                        flex: resFlex,
                        child: Container(color: Colors.orange)),
                  if (maintFlex > 0)
                    Expanded(
                        flex: maintFlex,
                        child: Container(color: Colors.red)),
                  // Fallback if empty to prevent error
                  if (availFlex + occFlex + resFlex + maintFlex == 0)
                    Expanded(
                        child: Container(color: colorScheme.outlineVariant)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem(context, 'Available', availFlex, Colors.green),
              _buildLegendItem(context, 'Occupied', occFlex, Colors.blue),
              _buildLegendItem(context, 'Reserved', resFlex, Colors.orange),
              _buildLegendItem(context, 'Maint.', maintFlex, Colors.red),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, int count, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(count.toString(),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        Text(label,
            style:
                TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10)),
      ],
    );
  }

  Widget _buildTodaysSummaryRow(HotelProvider provider) {
    final checkOuts = provider.getTodayCheckOuts().length;
    final checkIns =
        provider.getUpcomingCheckIns(const Duration(hours: 24)).length;
    final pending =
        provider.serviceOrders.where((s) => s.status == 'pending').length;

    return Row(
      children: [
        Expanded(
            child: _buildSummaryPill(
                'Check-ins', checkIns.toString(), Colors.blue)),
        const SizedBox(width: 10),
        Expanded(
            child: _buildSummaryPill(
                'Check-outs', checkOuts.toString(), Colors.orange)),
        const SizedBox(width: 10),
        Expanded(
            child: _buildSummaryPill(
                'Services', pending.toString(), Colors.purple)),
      ],
    );
  }

  Widget _buildSummaryPill(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(count,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(color: color, fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildActionGrid(
    BuildContext context,
    bool canBook,
    bool canAccessOperations,
  ) {
    List<Widget> actions = [];

    if (canBook) {
      actions.add(_buildActionCard(
        context,
        icon: Icons.login,
        label: 'Check-In / Guests',
        color: Colors.blue,
        // Routes to the new CheckInHubScreen (Available / Reserved /
        // Checked-In tabs with New Booking + Reserve Room FABs + history).
        // Replaces the old bookings screen as the single reception hub.
        onTap: () => Navigator.pushNamed(context, Routes.hotelCheckIn),
      ));
    }

    // Room, guest, and housekeeping management moved to work page (removed from home)

    if (canAccessOperations) {
      actions.add(_buildActionCard(
        context,
        icon: Icons.restaurant_menu,
        label: 'Restaurant',
        color: Colors.redAccent,
        onTap: () => Navigator.pushNamed(context, Routes.hotelRestaurant),
      ));

      actions.add(_buildActionCard(
        context,
        icon: Icons.kitchen_outlined,
        label: 'Kitchen',
        color: Colors.deepOrange,
        onTap: () => Navigator.pushNamed(context, Routes.restaurantKitchen),
      ));

      // Merge Bar POS and Bar Orders into one Bar button
      actions.add(_buildActionCard(
        context,
        icon: Icons.local_bar_outlined,
        label: 'Bar',
        color: Colors.indigo,
        onTap: () => Navigator.pushNamed(context, Routes.hotelBar),
      ));

      actions.add(_buildActionCard(
        context,
        icon: Icons.receipt_long,
        label: 'Billing',
        color: Colors.deepOrange,
        onTap: () => Navigator.pushNamed(context, Routes.hotelBilling),
      ));

      actions.add(_buildActionCard(
        context,
        icon: Icons.trending_down,
        label: 'Expenses',
        color: Colors.red,
        // Routes to the hotel-specific expenses screen (Stage 4) with
        // hospitality categories, MTD/week KPIs, and category breakdown.
        onTap: () => Navigator.pushNamed(context, Routes.hotelExpenses),
      ));

      actions.add(_buildActionCard(
        context,
        icon: Icons.insights_outlined,
        label: 'Analytics',
        color: Colors.indigo,
        // Routes to the hotel-specific analytics screen (Stage 3):
        //   room revenue trend, room type comparison, top rooms leaderboard,
        //   best day/week/month, booking source pie.
        onTap: () => Navigator.pushNamed(context, Routes.hotelAnalytics),
      ));

      actions.add(_buildActionCard(
        context,
        icon: Icons.apartment_outlined,
        label: 'Hall Bookings',
        color: Colors.blueGrey,
        onTap: () => Navigator.pushNamed(context, Routes.hotelHallBookings),
      ));

      actions.add(_buildActionCard(
        context,
        icon: Icons.pool_outlined,
        label: 'Pool Bookings',
        color: Colors.lightBlue,
        onTap: () => Navigator.pushNamed(context, Routes.hotelPoolBookings),
      ));

      // Add Printer Settings quick action
      actions.add(_buildActionCard(
        context,
        icon: Icons.print,
        label: 'Printer Settings',
        color: Colors.teal,
        onTap: () => Navigator.pushNamed(context, Routes.printerSettings),
      ));

    }

    actions.add(_buildActionCard(
      context,
      icon: Icons.support_agent_rounded,
      label: 'Customer Care',
      color: Colors.green,
      onTap: () => WhatsAppUtils.openCustomerSupport(context),
    ));

    // Use GridView for cleaner layout
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.5, // Makes them rectangular buttons
      children: actions,
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
