import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/colors.dart';
import '../../../core/config.dart';
import '../../../core/utils/worker_permissions.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/constants/routes.dart';
import '../../../providers/business_provider.dart';
import '../../../widgets/profile_avatar.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final businessProvider = context.watch<BusinessProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not authenticated')),
      );
    }

    final businessName =
        businessProvider.currentBusiness?.name ?? 'Unknown Business';
    final currentRole = user.role;
    final permissions =
        WorkerPermissions.getEffectivePermissions(currentRole, user.permissions);
    bool can(String permission) => WorkerPermissions.hasEffectivePermission(
          currentRole,
          user.permissions,
          permission,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Dashboard'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Card
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ProfileAvatar(
                    photoUrl: user.photoUrl,
                    initials: user.initials,
                    radius: 40,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.fullName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${WorkerPermissions.getRoleDisplayName(currentRole)} at $businessName',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Actions
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      if (can('sales'))
                        _buildActionCard(
                          context,
                          'Sales',
                          Icons.shopping_cart,
                          AppColors.primary,
                          () => _navigateToSales(context),
                        ),
                      if (can('view_inventory'))
                        _buildActionCard(
                          context,
                          'Inventory',
                          Icons.inventory_2,
                          Colors.orange,
                          () => _navigateToInventory(context),
                        ),
                      if (can('attendance'))
                        _buildActionCard(
                          context,
                          'Attendance',
                          Icons.calendar_today,
                          Colors.green,
                          () => _navigateToAttendance(context),
                        ),
                      // Hotel-specific management quick actions
                      if (can('manage_rooms') || can('room_status'))
                        _buildActionCard(
                          context,
                          'Room Management',
                          Icons.bed_outlined,
                          Colors.brown,
                          () => Navigator.pushNamed(context, Routes.hotelRooms),
                        ),
                      if (can('manage_guests') ||
                          can('guest_checkin') ||
                          can('guest_checkout'))
                        _buildActionCard(
                          context,
                          'Guest Management',
                          Icons.people_outline,
                          Colors.indigo,
                          () => Navigator.pushNamed(context, Routes.hotelGuests),
                        ),
                      if (can('room_service') || can('maintenance_requests'))
                        _buildActionCard(
                          context,
                          'Housekeeping',
                          Icons.cleaning_services,
                          Colors.teal,
                          () => Navigator.pushNamed(
                              context, Routes.hotelHousekeeping),
                        ),
                      if (can('manage_prescriptions'))
                        _buildActionCard(
                          context,
                          'Prescriptions',
                          Icons.local_pharmacy,
                          Colors.blue,
                          () => _navigateToPrescriptions(context),
                        ),
                      if (can('view_orders'))
                        _buildActionCard(
                          context,
                          'Orders',
                          Icons.receipt_long,
                          Colors.purple,
                          () => _navigateToOrders(context),
                        ),
                      // Quick access to Menu for restaurant workers
                      if (can('view_orders') &&
                          Provider.of<BusinessProvider>(context, listen: false).currentBusiness?.businessType == 'restaurant')
                        _buildActionCard(
                          context,
                          'Menu',
                          Icons.restaurant_menu,
                          Colors.teal,
                          () => Navigator.pushNamed(context, Routes.restaurantMenu),
                        ),
                      if (can('appointments'))
                        _buildActionCard(
                          context,
                          'Appointments',
                          Icons.event,
                          Colors.teal,
                          () => _navigateToAppointments(context),
                        ),
                      _buildActionCard(
                        context,
                        'Printer Settings',
                        Icons.print,
                        Colors.teal,
                        () => Navigator.pushNamed(context, Routes.printerSettings),
                      ),
                      _buildActionCard(
                        context,
                        'Customer Support',
                        Icons.support_agent,
                        Colors.green,
                        () => _openCustomerSupport(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Today's Summary
                  const Text(
                    'Today\'s Activity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildActivitySummary(),
                  const SizedBox(height: 24),
                  // Permissions Info
                  _buildPermissionsCard(permissions),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivitySummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildActivityItem('Sales Count', '0', Icons.trending_up),
            const Divider(),
            _buildActivityItem('Items Sold', '0', Icons.shopping_bag),
            const Divider(),
            _buildActivityItem('Check-ins', '0', Icons.check_circle),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String label, String value, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsCard(List<String> permissions) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Permissions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: permissions
                  .map(
                    (permission) => Chip(
                      label: Text(
                        WorkerPermissions.getPermissionLabel(permission),
                      ),
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                      labelStyle: const TextStyle(fontSize: 10),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToSales(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to Sales Screen')),
    );
  }

  void _navigateToInventory(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to Inventory Screen')),
    );
  }

  void _navigateToAttendance(BuildContext context) {
    Navigator.pushNamed(context, Routes.attendance);
  }

  void _navigateToPrescriptions(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to Prescriptions Screen')),
    );
  }

  void _navigateToOrders(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to Orders Screen')),
    );
  }

  void _navigateToAppointments(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to Appointments Screen')),
    );
  }

  Future<void> _openCustomerSupport(BuildContext context) async {
    const supportPhone = AppConfig.ownerWhatsappNumber;
    final businessName =
        context.read<BusinessProvider>().currentBusiness?.name ?? 'my business';
    final message = Uri.encodeComponent(
      'Hello, I need support for $businessName on Manage Care.',
    );
    final phoneDigits = supportPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$phoneDigits?text=$message');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open customer support.')),
    );
  }
}

