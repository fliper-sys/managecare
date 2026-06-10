import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:business_manager/core/utils/datetime_utils.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../../../providers/auth_provider.dart';
import '../providers/salon_provider.dart';

class SalonDashboardScreen extends StatefulWidget {
  const SalonDashboardScreen({super.key});

  @override
  State<SalonDashboardScreen> createState() => _SalonDashboardScreenState();
}

class _SalonDashboardScreenState extends State<SalonDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SalonProvider>();
      provider.loadServices();
      provider.loadStylists();
      provider.loadAppointments();
      provider.loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface, // Lighter background for contrast
      appBar: AppBar(
        elevation: 0,
        title: const Text('Salon Dashboard'),
        backgroundColor: AppColors.primary,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {}, // Placeholder for notifications
          ),
          const SizedBox(width: 8),
          IconButton(
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
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Consumer<SalonProvider>(
        builder: (context, provider, _) {
          final upcoming = provider.getUpcomingAppointments();

          return RefreshIndicator(
            onRefresh: () async {
              await provider.loadAppointments();
              await provider.loadServices();
              await provider.loadStylists();
              await provider.loadProducts();
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Welcome / Header Section
                  Text(
                    'Good Morning, Manager',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Overview', style: AppTextStyles.heading5),
                  
                  const SizedBox(height: 20),

                  // 2. Metrics Grid (Refactored for cleaner layout)
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Upcoming',
                          value: '${upcoming.length}',
                          icon: Icons.calendar_today,
                          color: Colors.blue.shade50,
                          iconColor: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Stylists',
                          value: '${provider.stylists.length}',
                          icon: Icons.content_cut,
                          color: Colors.orange.shade50,
                          iconColor: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Services',
                          value: '${provider.services.length}',
                          icon: Icons.spa,
                          color: Colors.purple.shade50,
                          iconColor: Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FutureBuilder<double>(
                          future: provider.getTodaysSalesTotal(),
                          builder: (context, snapshot) {
                            final todaysSales = snapshot.data ?? 0.0;
                            // Special styling for Sales card
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.monetization_on, color: Colors.white70),
                                  const Spacer(),
                                  const Text(
                                    'Today\'s Sales',
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatCurrency(todaysSales),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 3. Quick Actions
                  const Text('Quick Actions', style: AppTextStyles.heading5),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 90,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none, // Allows shadow to show
                      children: [
                        _QuickActionButton(
                          icon: Icons.add,
                          label: 'New Appt',
                          onTap: () => Navigator.pushNamed(context, Routes.salonAppointments),
                          isPrimary: true,
                        ),
                        _QuickActionButton(
                          icon: Icons.people_outline,
                          label: 'Workers',
                          onTap: () => Navigator.pushNamed(context, Routes.workers),
                        ),
                        const SizedBox(width: 12),
                        _QuickActionButton(
                          icon: Icons.person_add,
                          label: 'Add Worker',
                          onTap: () => Navigator.pushNamed(context, Routes.workersAdd),
                        ),
                        _QuickActionButton(
                          icon: Icons.list_alt,
                          label: 'Services',
                          onTap: () => Navigator.pushNamed(context, Routes.salonServices),
                        ),
                        _QuickActionButton(
                          icon: Icons.print,
                          label: 'Printer Settings',
                          onTap: () => Navigator.pushNamed(context, Routes.printerSettings),
                        ),
                        _QuickActionButton(
                          icon: Icons.percent,
                          label: 'Commissions',
                          onTap: () => Navigator.pushNamed(context, Routes.salonCommissionTracker),
                        ),
                        const SizedBox(width: 12),
                        _QuickActionButton(
                          icon: Icons.point_of_sale,
                          label: 'POS',
                          onTap: () => Navigator.pushNamed(context, Routes.sales),
                        ),
                        const SizedBox(width: 12),
                        _QuickActionButton(
                          icon: Icons.support_agent_rounded,
                          label: 'Customer Care',
                          onTap: () => WhatsAppUtils.openCustomerSupport(context),
                        ),
                        const SizedBox(width: 12),
                        _QuickActionButton(
                          icon: Icons.inventory,
                          label: 'Inventory',
                          onTap: () => Navigator.pushNamed(context, Routes.inventory),
                        ),
                        const SizedBox(width: 12),
                        _QuickActionButton(
                          icon: Icons.people,
                          label: 'Customers',
                          onTap: () => Navigator.pushNamed(context, Routes.customers),
                        ),
                        const SizedBox(width: 12),
                        _QuickActionButton(
                          icon: Icons.bar_chart,
                          label: 'Reports',
                          onTap: () => Navigator.pushNamed(context, Routes.reports),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Appointment List (Modernized)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Upcoming Appointments', style: AppTextStyles.heading5),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, Routes.salonAppointments),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  
                  if (upcoming.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.event_busy,
                              size: 48, color: colorScheme.onSurfaceVariant),
                          const SizedBox(height: 8),
                          Text(
                            'No upcoming appointments',
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  else
                    Builder(builder: (context) {
                      final upcomingList = upcoming.take(5).toList();
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: upcomingList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final appointment = upcomingList[index];
                          return InkWell(
                            onTap: () => Navigator.pushNamed(context, Routes.salonAppointments),
                            child: _AppointmentCard(appointment: appointment),
                          );
                        },
                      );
                    }),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------- Helper Widgets ----------------

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color iconColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.18 : 0.06,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
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

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: isPrimary
                    ? AppColors.primary
                    : colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: isPrimary
                    ? null
                    : Border.all(color: colorScheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: isPrimary ? Colors.white : colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final dynamic appointment; // Replace 'dynamic' with your Appointment model type

  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          // Time Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Builder(builder: (_) {
              try {
                final dt = appointment.appointmentTime is DateTime
                    ? appointment.appointmentTime as DateTime
                    : parseTimestamp(appointment.appointmentTime);
                final timeStr = DateFormat('hh:mm').format(dt);
                final ampm = DateFormat('a').format(dt);
                return Column(
                  children: [
                    Text(timeStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(ampm,
                        style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant)),
                  ],
                );
              } catch (e) {
                return Column(
                  children: [
                    const Text("--:--",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("",
                        style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant)),
                  ],
                );
              }
            }),
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.clientName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  "${appointment.serviceName} • with ${appointment.stylistName}",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Status Indicator
          Container(
            height: 10,
            width: 10,
            decoration: const BoxDecoration(
              color: Colors.green, // Change based on appointment.status
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
