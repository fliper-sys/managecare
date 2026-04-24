import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/constants/routes.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../../../providers/auth_provider.dart';
import '../providers/real_estate_provider.dart';

class RealestateDashboardScreen extends StatefulWidget {
  const RealestateDashboardScreen({super.key});

  @override
  State<RealestateDashboardScreen> createState() =>
      _RealestateDashboardScreenState();
}

class _RealestateDashboardScreenState extends State<RealestateDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load all real estate datasets once the widget mounts when provider is ready
      final provider = context.tryRead<RealEstateProvider>();
      if (provider != null) {
        provider.loadAll();
      } else {
        // Try shortly after in case providers are attached slightly later
        Future.delayed(const Duration(milliseconds: 150), () {
          final p2 = context.tryRead<RealEstateProvider>();
          p2?.loadAll();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Real Estate Management'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Manage Workers',
            onPressed: () => Navigator.pushNamed(context, Routes.workers),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () => Navigator.pushNamed(context, Routes.notifications),
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
      ),
      body: Consumer<RealEstateProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Welcome Message
                _buildWelcomeHeader(),
                const SizedBox(height: 24),

                // Key Metrics Row 1
                _buildMetricsRow1(provider),
                const SizedBox(height: 16),

                // Key Metrics Row 2
                _buildMetricsRow2(provider),
                const SizedBox(height: 24),

                // Property Status Overview
                _buildPropertyStatusOverview(provider),
                const SizedBox(height: 24),

                // Financial Overview
                _buildFinancialOverview(provider),
                const SizedBox(height: 24),

                // Tenant Status
                _buildTenantStatusOverview(provider),
                const SizedBox(height: 24),

                // Rent reminders
                _buildRentReminders(provider),
                const SizedBox(height: 24),

                // Quick Actions Grid
                _buildQuickActionsHeader(),
                const SizedBox(height: 12),
                _buildQuickActionsGrid(),
                const SizedBox(height: 24),

                // Recent Activity
                _buildRecentActivitySection(provider),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () =>
            Navigator.pushNamed(context, Routes.realEstateAddProperty),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome Back!',
            style: AppTextStyles.heading3.copyWith(color: Colors.white),
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 8),
          Text(
            'Here\'s your real estate portfolio overview',
            style: AppTextStyles.body2.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ).animate().fadeIn(duration: 800.ms, delay: 100.ms),
        ],
      ),
    );
  }

  Widget _buildMetricsRow1(RealEstateProvider provider) {
    final activeProperties = provider.properties.length;
    // Use bookings/owners as a proxy for tenants count
    final activeTenants = provider.tenants.length;

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.apartment,
            title: 'Active Properties',
            value: '$activeProperties',
            color: Colors.blue,
            delay: 0,
          ).animate().fade(duration: 600.ms).scale(duration: 600.ms),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icon: Icons.people,
            title: 'Active Tenants',
            value: '$activeTenants',
            color: Colors.green,
            delay: 1,
          ).animate().fade(duration: 600.ms).scale(duration: 600.ms),
        ),
      ],
    );
  }

  Widget _buildMetricsRow2(RealEstateProvider provider) {
    // Calculate simple monthly revenue from payments
    double monthlyRevenue = 0.0;
    try {
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;
      for (final payment in provider.rentPayments) {
        final paidDate = payment.paidDate;
        if (paidDate != null &&
            paidDate.month == currentMonth &&
            paidDate.year == currentYear) {
          monthlyRevenue += payment.amount;
        }
      }
    } catch (_) {
      // Silently handle errors
    }

    final occupancyRate = provider.properties.isEmpty
        ? 0.0
        : (provider.leases.length / provider.properties.length * 100);

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.monetization_on,
            title: 'Monthly Revenue',
            value: '₦${monthlyRevenue.toStringAsFixed(0)}',
            color: Colors.purple,
            delay: 2,
          ).animate().fade(duration: 600.ms).scale(duration: 600.ms),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icon: Icons.percent,
            title: 'Occupancy Rate',
            value: '${occupancyRate.toStringAsFixed(1)}%',
            color: Colors.orange,
            delay: 3,
          ).animate().fade(duration: 600.ms).scale(duration: 600.ms),
        ),
      ],
    );
  }

  Widget _buildPropertyStatusOverview(RealEstateProvider provider) {
    final occupied = provider.properties
        .where((p) => (p.status).toLowerCase() == 'occupied')
        .length;
    final vacant = provider.properties
        .where((p) => (p.status).toLowerCase() == 'vacant')
        .length;
    final maintenance = provider.properties
        .where((p) => (p.status).toLowerCase() == 'maintenance')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Property Status', style: AppTextStyles.heading5)
            .animate()
            .fadeIn(duration: 600.ms),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.28),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            children: [
              _buildStatusRow('Occupied', '$occupied', Colors.green),
              const Divider(height: 16),
              _buildStatusRow('Vacant', '$vacant', Colors.orange),
              const Divider(height: 16),
              _buildStatusRow('Maintenance', '$maintenance', Colors.red),
            ],
          ),
        ).animate().fadeIn(duration: 700.ms, delay: 100.ms),
      ],
    );
  }

  Widget _buildStatusRow(String label, String count, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 12),
            Text(label, style: AppTextStyles.body1),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            count,
            style: AppTextStyles.subtitle2.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialOverview(RealEstateProvider provider) {
    final now = DateTime.now();
    double monthlyRevenue = 0.0;
    double outstanding = 0.0;
    double maintenanceExpenses = 0.0;

    // No dynamic conversion required for typed RentPayment model fields

    for (final p in provider.rentPayments) {
      final amount = p.amount;
      final date = p.paidDate ?? p.createdAt;
      final status = p.status.toLowerCase();

      if (date.month == now.month && date.year == now.year) {
        monthlyRevenue += amount;
      }
      if (status != 'paid') outstanding += amount;
      // Rent payments don't track maintenance category directly
    }

    final net = monthlyRevenue - maintenanceExpenses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Financial Summary', style: AppTextStyles.heading5)
            .animate()
            .fadeIn(duration: 600.ms),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green.withOpacity(0.1),
                Colors.green.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              _buildFinancialRow('Total Rent Collected (This Month)',
                  '₦${monthlyRevenue.toStringAsFixed(0)}'),
              const Divider(height: 16),
              _buildFinancialRow(
                  'Outstanding Payments', '₦${outstanding.toStringAsFixed(0)}'),
              const Divider(height: 16),
              _buildFinancialRow('Maintenance Expenses',
                  '₦${maintenanceExpenses.toStringAsFixed(0)}'),
              const Divider(height: 16),
              _buildFinancialRow(
                'Net Income',
                '₦${net.toStringAsFixed(0)}',
                isTotal: true,
              ),
            ],
          ),
        ).animate().fadeIn(duration: 700.ms, delay: 100.ms),
      ],
    );
  }

  Widget _buildFinancialRow(
    String label,
    String amount, {
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.w600)
              : AppTextStyles.body1,
        ),
        Text(
          amount,
          style: isTotal
              ? AppTextStyles.heading5.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w700,
                )
              : AppTextStyles.subtitle2,
        ),
      ],
    );
  }

  Widget _buildQuickActionsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Quick Actions', style: AppTextStyles.heading5),
        TextButton(
          onPressed: () =>
              Navigator.pushNamed(context, Routes.realEstateProperties),
          child: const Text('View all'),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid() {
    final items = [
      _buildActionCard(context, 'Properties', Icons.apartment, Colors.blue,
          Routes.realEstateProperties, 0),
      _buildActionCard(context, 'Add Property', Icons.add_business_outlined,
          Colors.teal, Routes.realEstateAddProperty, 4),
      _buildActionCard(context, 'Tenants', Icons.people, Colors.green,
          Routes.realEstateTenants, 1),
      _buildActionCard(context, 'Rent Collection', Icons.account_balance_wallet,
          Colors.purple, Routes.realEstateRentCollection, 2),
      _buildActionCard(context, 'Maintenance', Icons.build, Colors.orange,
          Routes.realEstateMaintenance, 3),
      _buildActionCard(context, 'Printer Settings', Icons.print, Colors.teal, Routes.printerSettings, 5),
    ];

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items,
    );
  }

  Widget _buildRentReminders(RealEstateProvider provider) {
    final now = DateTime.now();
    final dueSoon = provider.rentPayments.where((p) {
      final days = p.dueDate.difference(now).inDays;
      return p.status.toLowerCase() != 'paid' && days >= 0 && days <= 7;
    }).toList();

    if (dueSoon.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rent Reminders', style: AppTextStyles.heading5),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.28),
                width: 1,
              ),
            ),
            child: const Center(
              child: Text('No rent due in the next 7 days',
                  style: AppTextStyles.body2Secondary),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Rent Reminders', style: AppTextStyles.heading5),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.28),
            ),
          ),
          child: Column(
            children: dueSoon.map((p) {
              final tenantIdx =
                  provider.tenants.indexWhere((t) => t.id == p.tenantId);
              final tenantName =
                  tenantIdx != -1 ? provider.tenants[tenantIdx].name : '';
              final leaseIdx =
                  provider.leases.indexWhere((l) => l.id == p.leaseId);
              String propertyTitle = '';
              if (leaseIdx != -1) {
                final lease = provider.leases[leaseIdx];
                final propIdx = provider.properties
                    .indexWhere((pt) => pt.id == lease.propertyId);
                if (propIdx != -1)
                  propertyTitle = provider.properties[propIdx].title;
              }
              final days = p.dueDate.difference(now).inDays;
              return ListTile(
                leading: CircleAvatar(
                    backgroundColor: Colors.orange.withOpacity(0.15),
                    child: const Icon(Icons.schedule, color: Colors.orange)),
                title: Text('₦${p.amount.toStringAsFixed(0)} due',
                    style: AppTextStyles.subtitle2
                        .copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    '${tenantName.isNotEmpty ? tenantName : 'Unknown tenant'} • ${propertyTitle.isNotEmpty ? '$propertyTitle • ' : ''}${p.dueDate.toLocal().toString().split(' ').first} • $days days',
                    style: AppTextStyles.body2Secondary),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Notify tenant',
                      icon: const Icon(Icons.notifications_active_outlined,
                          color: Colors.blue),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Notification sent to tenant')));
                      },
                    ),
                    IconButton(
                      tooltip: 'Mark as paid',
                      icon: const Icon(Icons.check_circle_outline,
                          color: Colors.green),
                      onPressed: () async {
                        await provider.updateRentPaymentStatus(p.id, 'paid',
                            paidDate: DateTime.now());
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Payment marked as paid')));
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ).animate().fadeIn(duration: 600.ms).scale(duration: 400.ms),
      ],
    );
  }

  Widget _buildTenantStatRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(label, style: AppTextStyles.body1),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            value,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTenantStatusOverview(RealEstateProvider provider) {
    final leaseCount = provider.leases.length;

    // No dynamic conversion needed

    final now = DateTime.now();
    final rentDueSoon = provider.rentPayments.where((p) {
      final due = p.dueDate;
      final diff = due.difference(now).inDays;
      return diff >= 0 && diff <= 7 && p.status.toLowerCase() != 'paid';
    }).length;

    final arrears = provider.rentPayments
        .where((p) => p.status.toLowerCase() != 'paid')
        .fold<double>(0, (s, p) => s + (p.amount));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tenant Management', style: AppTextStyles.heading5)
            .animate()
            .fadeIn(duration: 600.ms),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.28),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            children: [
              _buildTenantStatRow(
                'Lease Agreements',
                '$leaseCount Active',
                Icons.description,
                Colors.blue,
              ),
              const Divider(height: 16),
              _buildTenantStatRow(
                'Rent Due Soon',
                '$rentDueSoon Properties',
                Icons.schedule,
                Colors.orange,
              ),
              const Divider(height: 16),
              _buildTenantStatRow(
                'Arrears',
                '₦${arrears.toStringAsFixed(0)}',
                Icons.error_outline,
                Colors.red,
              ),
            ],
          ),
        ).animate().fadeIn(duration: 700.ms, delay: 100.ms),
      ],
    );
  }
}

Widget _buildActionCard(
  BuildContext context,
  String label,
  IconData icon,
  Color color,
  String route,
  int index,
) {
  return GestureDetector(
    onTap: () => Navigator.pushNamed(context, route),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, route),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitle2.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  )
      .animate()
      .fade(duration: 500.ms, delay: Duration(milliseconds: index * 100))
      .scale(duration: 500.ms, delay: Duration(milliseconds: index * 100));
}

Widget _buildRecentActivitySection(RealEstateProvider provider) {
  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  final activities = <Widget>[];

  // Recent rent payments (most recent first)
  final recentPayments = [...provider.rentPayments]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  for (final p in recentPayments) {
    final tenantObj = provider.tenants.firstWhere((t) => t.id == p.tenantId,
        orElse: () => Tenant.empty());
    final title = p.status.toLowerCase() == 'paid' ? 'Rent Collected' : 'Rent Payment';
    final desc = '${tenantObj.name.isNotEmpty ? tenantObj.name : 'Tenant'} • ₦${p.amount.toStringAsFixed(0)}';
    activities.add(_buildActivityItem(
      title,
      desc,
      _timeAgo(p.paidDate ?? p.createdAt),
      Icons.account_balance_wallet,
      Colors.purple,
    ));
    if (activities.length >= 4) break;
  }

  // Fallback to recent leases if not enough activities
  if (activities.length < 4) {
    final recentLeases = [...provider.leases]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final l in recentLeases) {
      final tenantObj = provider.tenants.firstWhere((t) => t.id == l.tenantId,
          orElse: () => Tenant.empty());
      final title = 'Lease ${l.status == 'active' ? 'Signed' : l.status}';
      final desc = '${tenantObj.name.isNotEmpty ? tenantObj.name : 'Tenant'} • ₦${l.monthlyRent.toStringAsFixed(0)}';
      activities.add(_buildActivityItem(
        title,
        desc,
        _timeAgo(l.createdAt),
        Icons.check_circle,
        Colors.green,
      ));
      if (activities.length >= 4) break;
    }
  }

  if (activities.isEmpty) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Activity', style: AppTextStyles.heading5)
            .animate()
            .fadeIn(duration: 600.ms),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.28),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: Text('No recent activity', style: AppTextStyles.body2Secondary),
            ),
          ),
        ).animate().fadeIn(duration: 700.ms, delay: 100.ms),
      ],
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Recent Activity', style: AppTextStyles.heading5)
          .animate()
          .fadeIn(duration: 600.ms),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.28),
            width: 1,
          ),
        ),
        child: Column(
          children: activities
              .map((w) => Column(children: [w, const Divider(height: 1)]))
              .toList(),
        ),
      ).animate().fadeIn(duration: 700.ms, delay: 100.ms),
    ],
  );
}

Widget _buildActivityItem(
  String title,
  String description,
  String time,
  IconData icon,
  Color color,
) {
  return Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.subtitle2.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTextStyles.body2Secondary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          time,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final int delay;

  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
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
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.heading4.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTextStyles.body2.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

