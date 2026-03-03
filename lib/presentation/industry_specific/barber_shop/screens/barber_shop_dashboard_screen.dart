import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/constants/routes.dart';
import '../../../../providers/auth_provider.dart';
import '../providers/barber_shop_provider.dart';

class BarberShopDashboardScreen extends StatefulWidget {
  const BarberShopDashboardScreen({super.key});

  @override
  State<BarberShopDashboardScreen> createState() =>
      _BarberShopDashboardScreenState();
}

class _BarberShopDashboardScreenState extends State<BarberShopDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BarberShopProvider>();
      provider.loadAppointments();
      provider.loadServices();
      provider.loadBarbers();
      provider.loadSales();
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
    // Get current date for the header
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMM d').format(now);

    return Scaffold(
      backgroundColor: Colors.grey[50], // Softer background
      body: Consumer<BarberShopProvider>(
        builder: (context, provider, _) {
          final monthlyRevenue = provider.getMonthlyRevenue();
          final todayAppointments = provider.getTodayAppointments();

          return CustomScrollView(
            slivers: [
              // 1. Custom App Bar / Header
              SliverAppBar(
                expandedHeight: 120.0,
                floating: true,
                pinned: true,
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.people_outline),
                    tooltip: 'Manage Workers',
                    onPressed: () => Navigator.pushNamed(context, Routes.workers),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
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
                ],
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 20),
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Barbershop',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(24),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -20,
                          top: -20,
                          child: Icon(
                            Icons.cut,
                            size: 150,
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // 2. Metrics Grid
                    _AnimatedSection(
                      controller: _controller,
                      index: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Overview',
                              style: AppTextStyles.heading3.copyWith(
                                color: Colors.grey[800],
                              )),
                          const SizedBox(height: 16),
                          GridView(
                            padding: EdgeInsets.zero,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.5,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              FutureBuilder<double>(
                                future: provider.getTodaysSalesTotal(),
                                builder: (context, snapshot) {
                                  final todayRevenue = snapshot.data ?? 0.0;
                                  return _MetricCard(
                                    label: 'Today\'s Sales',
                                    value: '₦${todayRevenue.toStringAsFixed(0)}',
                                    icon: Icons.payments_outlined,
                                    color: Colors.green,
                                    isPrimary: true,
                                    onTap: () => Navigator.pushNamed(context, Routes.sales),
                                  );
                                },
                              ),
                              _MetricCard(
                                label: 'Appointments',
                                value: '${todayAppointments.length}',
                                icon: Icons.calendar_today_outlined,
                                color: Colors.orange,
                                onTap: () => Navigator.pushNamed(context, Routes.barberShopAppointments),
                              ),
                              _MetricCard(
                                label: 'Monthly',
                                value: '₦${monthlyRevenue.toStringAsFixed(0)}',
                                icon: Icons.trending_up,
                                color: Colors.blue,
                                onTap: () => Navigator.pushNamed(context, Routes.reports),
                              ),
                              _MetricCard(
                                label: 'Services',
                                value: '${provider.services.length}',
                                icon: Icons.content_cut_outlined,
                                color: Colors.purple,
                                onTap: () => Navigator.pushNamed(context, Routes.barberShopServices),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 3. Quick Actions (Horizontal Scroll)
                    _AnimatedSection(
                      controller: _controller,
                      index: 1,
                      child: SizedBox(
                        height: 100,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _QuickActionButton(
                              label: 'New Booking',
                              icon: Icons.add_circle_outline,
                              color: AppColors.primary,
                              onTap: () => Navigator.pushNamed(
                                  context, Routes.barberShopAppointments),
                            ),
                            const SizedBox(width: 12),
                            _QuickActionButton(
                              label: 'Payments',
                              icon: Icons.payment_outlined,
                              color: Colors.teal,
                              onTap: () => Navigator.pushNamed(
                                  context, Routes.barberShopPayments),
                            ),
                            const SizedBox(width: 12),
                            _QuickActionButton(
                              label: 'History',
                              icon: Icons.history_outlined,
                              color: Colors.indigo,
                              onTap: () => Navigator.pushNamed(
                                  context, Routes.barberShopSalesHistory),
                            ),
                            const SizedBox(width: 12),
                            _QuickActionButton(
                              label: 'Services',
                              icon: Icons.content_cut,
                              color: Colors.purple,
                              onTap: () => Navigator.pushNamed(
                                  context, Routes.barberShopServices),
                            ),
                            const SizedBox(width: 12),
                            _QuickActionButton(
                              label: 'New Service',
                              icon: Icons.add,
                              color: Colors.green,
                              onTap: () => Navigator.pushNamed(
                                  context, Routes.barberShopCreateService),
                            ),
                            const SizedBox(width: 12),
                            _QuickActionButton(
                              label: 'Add Worker',
                              icon: Icons.person_add,
                              color: Colors.teal,
                              onTap: () => Navigator.pushNamed(context, Routes.workersAdd),
                            ),
                            const SizedBox(width: 12),
                            _QuickActionButton(
                              label: 'Commissions',
                              icon: Icons.monetization_on,
                              color: Colors.orange,
                              onTap: () => Navigator.pushNamed(context, Routes.barberCommission),
                            ),
                            const SizedBox(width: 12),
                            _QuickActionButton(
                              label: 'POS',
                              icon: Icons.point_of_sale,
                              color: Colors.blue,
                              onTap: () => Navigator.pushNamed(context, Routes.sales),
                            ),
                            const SizedBox(width: 12),
                            _QuickActionButton(
                              label: 'Inventory',
                              icon: Icons.inventory,
                              color: Colors.green,
                              onTap: () => Navigator.pushNamed(context, Routes.inventory),
                            ),
                            const SizedBox(width: 12),
                            _QuickActionButton(
                              label: 'Customers',
                              icon: Icons.people,
                              color: Colors.purple,
                              onTap: () => Navigator.pushNamed(context, Routes.customers),
                            ),
                            const SizedBox(width: 12),
                            _QuickActionButton(
                              label: 'Reports',
                              icon: Icons.bar_chart,
                              color: Colors.cyan,
                              onTap: () => Navigator.pushNamed(context, Routes.reports),
                            ),
                            const SizedBox(width: 12),
                            _QuickActionButton(
                              label: 'Printer Settings',
                              icon: Icons.print,
                              color: Colors.teal,
                              onTap: () => Navigator.pushNamed(context, Routes.printerSettings),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 4. Today's Appointments List
                    _AnimatedSection(
                      controller: _controller,
                      index: 2,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Today\'s Schedule',
                                  style: AppTextStyles.heading3),
                              if (todayAppointments.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${todayAppointments.length} Total',
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (todayAppointments.isEmpty)
                            _EmptyState(
                              message: 'No appointments for today',
                              icon: Icons.event_available,
                            )
                          else
                            ...todayAppointments.take(3).map(
                                (apt) => _AppointmentCard(appointment: apt)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 5. Available Barbers
                    _AnimatedSection(
                      controller: _controller,
                      index: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Staff', style: AppTextStyles.heading3),
                          const SizedBox(height: 12),
                          if (provider.barbers.isEmpty)
                            _EmptyState(
                              message: 'No barbers registered',
                              icon: Icons.people_outline,
                            )
                          else
                            SizedBox(
                              height: 140, // Height for horizontal cards
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: provider.barbers.length,
                                physics: const BouncingScrollPhysics(),
                                itemBuilder: (context, index) {
                                  final barber = provider.barbers[index];
                                  return _BarberCard(barber: barber);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Extra padding at bottom for safe area
                    const SizedBox(height: 40),
                  ]),
                ),
              )
    ]);
        },));}}
    
// --- WIDGETS ---

class _AnimatedSection extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final Widget child;

  const _AnimatedSection({
    required this.controller,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.2),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: controller,
          curve: Interval(
            index * 0.1, // Stagger effect
            1.0,
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(index * 0.1, 1.0, curve: Curves.easeOut),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isPrimary;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isPrimary = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
        border: isPrimary ? Border.all(color: color.withOpacity(0.3)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (isPrimary)
                Icon(Icons.arrow_forward_ios,
                    size: 12, color: Colors.grey[400]),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTextStyles.heading3.copyWith(
                  color: Colors.black87,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // If onTap provided, wrap with InkWell to show affordance
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: content,
      );
    }

    return content;
  }
} 

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final dynamic appointment; // dynamic to avoid type errors without model import

  const _AppointmentCard({required this.appointment});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(appointment.status);
    final timeFormat =
        DateFormat('h:mm a').format(appointment.appointmentTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Time Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  timeFormat.split(' ')[0],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: statusColor,
                  ),
                ),
                Text(
                  timeFormat.split(' ')[1],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.clientName,
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.content_cut, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      appointment.serviceName,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'With ${appointment.barberName}',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Status Dot
          Container(
            height: 10,
            width: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarberCard extends StatelessWidget {
  final dynamic barber;

  const _BarberCard({required this.barber});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(
              barber.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            barber.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            barber.specialization,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${barber.commissionPercentage ?? 0}% Comm.',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const _EmptyState({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}