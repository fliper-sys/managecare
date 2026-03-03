import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../core/theme/colors.dart';

import '../../../../core/constants/routes.dart';
import '../../../../providers/hotel_provider.dart';

class HotelDashboardScreen extends StatelessWidget {
  const HotelDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine permissions once to keep build method clean
    final auth = Provider.of<AuthProvider>(context);
    final role = auth.currentUser?.role ?? '';
    final canBook = auth.isOwnerUser ||
        WorkerPermissions.hasPermission(role, 'bookings') ||
        WorkerPermissions.hasPermission(role, 'guest_checkin') ||
        WorkerPermissions.canManageStaff(role);
    final canViewService = auth.isOwnerUser ||
        WorkerPermissions.hasPermission(role, 'guest_checkin') ||
        WorkerPermissions.canManageStaff(role) ||
        WorkerPermissions.canViewInventory(role);
    final canManageStaff =
        auth.isOwnerUser || WorkerPermissions.canManageStaff(role);

    return Scaffold(
      backgroundColor: Colors.grey[50], // Modern light background
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
                // 1. REVENUE HEADER (High Priority)
                _buildRevenueHeader(provider),
                const SizedBox(height: 24),

                // 2. KPI GRID
                Row(
                  children: [
                    Expanded(
                        child: _buildMetricTile(
                      icon: Icons.pie_chart_outline,
                      title: 'Occupancy',
                      value: '${provider.occupancy.toStringAsFixed(1)}%',
                      color: Colors.blue,
                    )),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildMetricTile(
                      icon: Icons.bed_outlined,
                      title: 'Total Rooms',
                      value: '${provider.totalRooms}',
                      color: Colors.purple,
                    )),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _buildMetricTile(
                      icon: Icons.check_circle_outline,
                      title: 'Occupied',
                      value: '${provider.occupiedRooms}',
                      color: Colors.green,
                    )),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildMetricTile(
                      icon: Icons.star_border_rounded,
                      title: 'Rating',
                      value: provider.getAverageRating().toStringAsFixed(1),
                      color: Colors.orange,
                    )),
                  ],
                ),
                const SizedBox(height: 24),

                // 3. ROOM STATUS VISUALIZATION
                const Text('Room Status Distribution',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildRoomStatusBar(provider),
                const SizedBox(height: 24),

                // 4. TODAY'S ACTIVITY
                const Text('Today\'s Activity',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildTodaysSummaryRow(provider),
                const SizedBox(height: 24),

                // 5. QUICK ACTIONS GRID
                const Text('Quick Actions',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildActionGrid(context, canBook, canViewService, canManageStaff),
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
        final sales = snapshot.data ?? 0.0;
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
                    '₦${sales.toStringAsFixed(0)}',
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
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        ],
      ),
    );
  }

  Widget _buildRoomStatusBar(HotelProvider provider) {
    final dist = provider.getRoomStatusDistribution();


    // Calculate Flex values
    final availFlex = dist['available'] ?? 0;
    final occFlex = dist['occupied'] ?? 0;
    final maintFlex = dist['maintenance'] ?? 0;
    final resFlex = dist['reserved'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                        child: Container(color: Colors.grey[300])),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem('Available', availFlex, Colors.green),
              _buildLegendItem('Occupied', occFlex, Colors.blue),
              _buildLegendItem('Reserved', resFlex, Colors.orange),
              _buildLegendItem('Maint.', maintFlex, Colors.red),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int count, Color color) {
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
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
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
      BuildContext context, bool canBook, bool canViewService, bool canManageStaff) {
    List<Widget> actions = [];

    if (canBook) {
      actions.add(_buildActionCard(
        context,
        icon: Icons.login,
        label: 'Check-In',
        color: Colors.blue,
        onTap: () => Navigator.pushNamed(context, Routes.hotelBookings, arguments: {'initialFilter': 'confirmed'}),
      ));
      actions.add(_buildActionCard(
        context,
        icon: Icons.logout,
        label: 'Check-Out',
        color: Colors.orange,
        onTap: () => Navigator.pushNamed(context, Routes.hotelBookings, arguments: {'initialFilter': 'checked-in'}),
      ));
      actions.add(_buildActionCard(
        context,
        icon: Icons.calendar_month,
        label: 'Reservations',
        color: Colors.teal,
        onTap: () => Navigator.pushNamed(context, Routes.hotelBookings, arguments: {'initialFilter': 'reserved'}),
      ));

      // Guests management
      actions.add(_buildActionCard(
        context,
        icon: Icons.people_outline,
        label: 'Guests',
        color: Colors.indigo,
        onTap: () => Navigator.pushNamed(context, Routes.hotelGuests),
      ));
    }

    // Rooms management actions (owner / staff only)
    if (canManageStaff) {
      actions.add(_buildActionCard(
        context,
        icon: Icons.bed_outlined,
        label: 'Rooms',
        color: Colors.brown,
        onTap: () => Navigator.pushNamed(context, Routes.hotelRooms),
      ));
      actions.add(_buildActionCard(
        context,
        icon: Icons.add_box_outlined,
        label: 'Create Room',
        color: Colors.green,
        onTap: () => Navigator.pushNamed(context, Routes.hotelCreateRoom),
      ));
    }

    if (canViewService) {
      actions.add(_buildActionCard(
        context,
        icon: Icons.room_service,
        label: 'Room Services',
        color: Colors.purple,
        onTap: () => Navigator.pushNamed(context, Routes.hotelFrontDesk),
      ));

    // Printer Settings (general quick action)
    actions.add(_buildActionCard(
      context,
      icon: Icons.print,
      label: 'Printer Settings',
      color: Colors.teal,
      onTap: () => Navigator.pushNamed(context, Routes.printerSettings),
    ));

      actions.add(_buildActionCard(
        context,
        icon: Icons.cleaning_services,
        label: 'Housekeeping',
        color: Colors.teal,
        onTap: () => Navigator.pushNamed(context, Routes.hotelHousekeeping),
      ));

      actions.add(_buildActionCard(
        context,
        icon: Icons.receipt_long,
        label: 'Billing',
        color: Colors.deepOrange,
        onTap: () => Navigator.pushNamed(context, Routes.hotelBilling),
      ));
    }

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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
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