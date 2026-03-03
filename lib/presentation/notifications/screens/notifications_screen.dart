import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/constants/routes.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../widgets/profile_avatar.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  bool _isClockedIn = false;
  DateTime? _clockInTime;
  Duration _shiftDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (_isClockedIn && _clockInTime != null) {
        setState(() {
          _shiftDuration = DateTime.now().difference(_clockInTime!);
        });
      }
      return mounted;
    });
  }

  void _toggleClockIn() {
    setState(() {
      if (_isClockedIn) {
        // Clock out
        _isClockedIn = false;
        _clockInTime = null;
        _shiftDuration = Duration.zero;
      } else {
        // Clock in
        _isClockedIn = true;
        _clockInTime = DateTime.now();
      }
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final businessProvider = context.watch<BusinessProvider>();
    final user = authProvider.currentUser;
    final business = businessProvider.currentBusiness;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  ProfileAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    photoUrl: user?.photoUrl,
                    initials: user?.initials ?? 'W',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome back,',
                          style: AppTextStyles.body2Secondary,
                        ),
                        Text(
                          user?.fullName ?? 'Worker',
                          style: AppTextStyles.heading4,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      Navigator.pushNamed(context, Routes.notifications);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Clock In/Out Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: _isClockedIn
                      ? const LinearGradient(
                          colors: [AppColors.success, AppColors.successLight],
                        )
                      : const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                        ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (_isClockedIn ? AppColors.success : AppColors.primary)
                              .withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _isClockedIn
                                ? Icons.access_time_filled
                                : Icons.access_time_outlined,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isClockedIn
                                    ? 'Shift in Progress'
                                    : 'Ready to Start?',
                                style: AppTextStyles.heading4.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                _isClockedIn
                                    ? 'Shift Duration'
                                    : 'Tap to clock in',
                                style: AppTextStyles.body2.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_isClockedIn) ...[
                      const SizedBox(height: 20),
                      Text(
                        _formatDuration(_shiftDuration),
                        style: AppTextStyles.heading1.copyWith(
                          color: Colors.white,
                          fontSize: 48,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _toggleClockIn,
                        icon: Icon(
                          _isClockedIn ? Icons.logout : Icons.login,
                        ),
                        label: Text(
                          _isClockedIn ? 'Clock Out' : 'Clock In',
                          style: AppTextStyles.button,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _isClockedIn
                              ? AppColors.success
                              : AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Today's Summary
              const Text('Today\'s Summary', style: AppTextStyles.heading4),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Sales Made',
                      value: '12',
                      icon: Icons.shopping_cart_outlined,
                      color: AppColors.success,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Revenue',
                      value: '₦45k',
                      icon: Icons.attach_money,
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Quick Actions
              const Text('Quick Actions', style: AppTextStyles.heading4),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _ActionCard(
                    title: 'New Sale',
                    icon: Icons.point_of_sale,
                    color: AppColors.success,
                    onTap: () {
                      Navigator.pushNamed(context, Routes.sales);
                    },
                  ),
                  _ActionCard(
                    title: 'View Inventory',
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.info,
                    onTap: () {
                      Navigator.pushNamed(context, Routes.inventory);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Recent Activity
              Row(
                children: [
                  const Text('Recent Activity', style: AppTextStyles.heading4),
                  const Spacer(),
                  TextButton(
                    onPressed: () {},
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _ActivityCard(
                title: 'Sale Completed',
                subtitle: '3 items • ₦5,500',
                time: '10 mins ago',
                icon: Icons.check_circle_outline,
                color: AppColors.success,
              ),
              const SizedBox(height: 12),
              const _ActivityCard(
                title: 'Inventory Updated',
                subtitle: 'Product X restocked',
                time: '1 hour ago',
                icon: Icons.inventory_2_outlined,
                color: AppColors.info,
              ),

              const SizedBox(height: 24),

              // Business Info
              if (business != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.business,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              business.name,
                              style: AppTextStyles.subtitle1,
                            ),
                            const Text(
                              'Worker Account',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () {
                          Navigator.pushNamed(context, Routes.settings);
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.cardShadow,
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
          Text(value, style: AppTextStyles.heading4),
          Text(label, style: AppTextStyles.body2Secondary),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(title, style: AppTextStyles.heading5),
        ],
      ),
    );

    if (onTap == null) return card;

    return GestureDetector(
      onTap: onTap,
      child: card,
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final Color color;

  const _ActivityCard({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.subtitle1),
                Text(subtitle, style: AppTextStyles.body2Secondary),
              ],
            ),
          ),
          Text(time, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

