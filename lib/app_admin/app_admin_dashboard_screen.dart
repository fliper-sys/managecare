import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/datetime_utils.dart';
import '../providers/admin_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency.dart';
import '../core/constants/routes.dart';
import '../routes/app_router.dart';
import 'admin_theme.dart';
import 'pages/admin_notifications_page.dart';
import 'pages/all_businesses_page.dart';
import 'pages/admin_payments_page.dart';
import 'pages/business_subscription_overview_page.dart';
import 'pages/marketers_page.dart';
import '../providers/marketer_provider.dart';

class AdminDashboardApp extends StatelessWidget {
  final int initialIndex;

  const AdminDashboardApp({
    super.key,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final appRouter = AppRouter();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MarketerProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'Manage Care ',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: DashboardHome(initialIndex: initialIndex),
          onGenerateRoute: appRouter.onGenerateRoute,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

class DashboardHome extends StatefulWidget {
  final int initialIndex;

  const DashboardHome({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  late int _selectedIndex;

  final List<Widget> _pages = [
    const DashboardPage(),
    const BusinessesPage(),
    const PaymentsPage(),
    const UsersAndWorkersPage(),
    const MarketersPage(),
    const SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex =
        widget.initialIndex.clamp(0, _pages.length - 1).toInt();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminProvider>().fetchAdminStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WillPopScope(
        onWillPop: () async {
          final shouldExit = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Exit App'),
                  content: const Text('Do you want to exit the app?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('No')),
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Yes')),
                  ],
                ),
              ) ??
              false;
          if (shouldExit) await SystemNavigator.pop();
          return false;
        },
        child: Scaffold(
          backgroundColor: context.adminBackground,
          body: DecoratedBox(
            decoration: BoxDecoration(
              color: context.adminBackground,
            ),
            child: _pages[_selectedIndex],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: context.adminCardDecoration(
                color: theme.navigationBarTheme.backgroundColor ??
                    context.adminSurface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) =>
                    setState(() => _selectedIndex = index),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard_rounded),
                    label: 'Dashboard',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.business_outlined),
                    selectedIcon: Icon(Icons.business_rounded),
                    label: 'Business',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.payments_outlined),
                    selectedIcon: Icon(Icons.payments_rounded),
                    label: 'Payments',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.groups_outlined),
                    selectedIcon: Icon(Icons.groups_rounded),
                    label: 'Users',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.campaign_outlined),
                    selectedIcon: Icon(Icons.campaign_rounded),
                    label: 'Marketers',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings_rounded),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

String _formatTimestamp(dynamic value) {
  if (value == null) return '-';
  try {
    if (value is Timestamp) {
      final dt = value.toDate();
      return '${dt.day}/${dt.month}/${dt.year}';
    }
    if (value is DateTime) {
      return '${value.day}/${value.month}/${value.year}';
    }
    final parsed = DateTime.tryParse(value.toString());
    if (parsed != null) {
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    }
    return value.toString();
  } catch (_) {
    return value.toString();
  }
}

class _DashboardPageState extends State<DashboardPage> {
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // Fetch admin stats after widget is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AdminProvider>().fetchAdminStats();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.adminBackground,
      child: SafeArea(
        child: RefreshIndicator(
        onRefresh: () =>
            context.read<AdminProvider>().fetchAdminStats(force: true),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Consumer<AdminProvider>(
          builder: (context, admin, _) {
            final activeBusinesses = admin.activeBusinessesCount;
            final restrictedBusinesses = admin.restrictedBusinessesCount;
            final activeSubscriptions = admin.activeSubscriptionsCount;
            final pendingApprovals = admin.pendingSubscriptionApprovalsCount;
            final marketers = admin.marketersCount;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ManageCare',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: context.adminTextPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Platform Overview',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.adminTextSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Consumer<AdminProvider>(builder: (ctx, admin, _) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, Routes.installationRequestsAdmin);
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF4C1D95).withOpacity(0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.build_rounded, color: Colors.white),
                                ),
                                if (admin.pendingInstallationRequestsCount > 0)
                                  Positioned(
                                    top: -6,
                                    right: -6,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                      child: Center(
                                        child: Text(
                                          admin.pendingInstallationRequestsCount > 99 ? '99+' : admin.pendingInstallationRequestsCount.toString(),
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => const AdminNotificationsPage(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              ),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1)
                                      .withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.notifications_rounded, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, Routes.adminSubscriptions);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF22C55E), Color(0xFF84CC16)],
                              ),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF22C55E).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.subscriptions_rounded, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: context.adminTextTertiary,
                    ),
                    hintText: 'Search businesses, users...',
                    hintStyle: TextStyle(color: context.adminTextTertiary),
                    filled: true,
                    fillColor: context.adminSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                const SizedBox(height: 24),

                // Stats Cards - showing real data from AdminProvider
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Businesses',
                        admin.stats.totalBusinesses.toString(),
                        Icons.business_rounded,
                        const Color(0xFF3B82F6),
                        '$activeBusinesses active',
                        onTap: () => Navigator.pushNamed(
                          context,
                          Routes.allBusinessesAdmin,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Active Users',
                        admin.stats.activeUsers.toString(),
                        Icons.groups_rounded,
                        const Color(0xFF10B981),
                        '24h live',
                        onTap: () => Navigator.pushNamed(
                          context,
                          Routes.adminUsersAndWorkers,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Pending Reviews',
                        pendingApprovals.toString(),
                        Icons.fact_check_rounded,
                        const Color(0xFFF97316),
                        pendingApprovals > 0 ? 'Needs action' : 'Clear',
                        onTap: () =>
                            Navigator.pushNamed(context, Routes.adminSubscriptions),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Restricted',
                        restrictedBusinesses.toString(),
                        Icons.gpp_bad_rounded,
                        const Color(0xFFEF4444),
                        restrictedBusinesses > 0 ? 'Follow up' : 'Healthy',
                        onTap: () => Navigator.pushNamed(
                          context,
                          Routes.allBusinessesAdmin,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Revenue',
                        formatCurrency(admin.stats.totalRevenue.toDouble()),
                        Icons.attach_money_rounded,
                        const Color(0xFF8B5CF6),
                        '${admin.stats.pendingPayments} payment issues',
                        onTap: () =>
                            Navigator.pushNamed(context, Routes.adminPayments),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Live Subscriptions',
                        activeSubscriptions.toString(),
                        Icons.workspace_premium_rounded,
                        const Color(0xFF14B8A6),
                        '$marketers marketers',
                        onTap: () =>
                            Navigator.pushNamed(context, Routes.adminPayments),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Transactions',
                        admin.stats.totalTransactions.toString(),
                        Icons.receipt_long_rounded,
                        const Color(0xFFF59E0B),
                        'Platform-wide',
                        onTap: () =>
                            Navigator.pushNamed(context, Routes.adminPayments),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Marketers',
                        marketers.toString(),
                        Icons.campaign_rounded,
                        const Color(0xFF6366F1),
                        'Growth partners',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) =>
                                const AdminDashboardApp(initialIndex: 4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Admin Operations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.adminTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildQuickActionTile(
                      context,
                      title: 'Subscription Queue',
                      subtitle: 'Approve or decline pending requests',
                      icon: Icons.fact_check_rounded,
                      color: const Color(0xFFF97316),
                      onTap: () =>
                          Navigator.pushNamed(context, Routes.adminSubscriptions),
                    ),
                    _buildQuickActionTile(
                      context,
                      title: 'Business Control',
                      subtitle: 'Edit details and restrict access',
                      icon: Icons.business_center_rounded,
                      color: const Color(0xFF3B82F6),
                      onTap: () => Navigator.pushNamed(
                        context,
                        Routes.allBusinessesAdmin,
                      ),
                    ),
                    _buildQuickActionTile(
                      context,
                      title: 'User Access',
                      subtitle: 'Approve yearly access for teams',
                      icon: Icons.groups_rounded,
                      color: const Color(0xFF10B981),
                      onTap: () => Navigator.pushNamed(
                        context,
                        Routes.adminUsersAndWorkers,
                      ),
                    ),
                    _buildQuickActionTile(
                      context,
                      title: 'Marketer Hub',
                      subtitle: 'Manage partners, payouts and activity',
                      icon: Icons.campaign_rounded,
                      color: const Color(0xFF6366F1),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) =>
                                const AdminDashboardApp(initialIndex: 4),
                          ),
                        );
                      },
                    ),
                    _buildQuickActionTile(
                      context,
                      title: 'Subscription Overview',
                      subtitle: 'See owners, start dates, and due dates',
                      icon: Icons.manage_accounts_rounded,
                      color: const Color(0xFF14B8A6),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) =>
                                const BusinessSubscriptionOverviewPage(),
                          ),
                        );
                      },
                    ),
                    _buildQuickActionTile(
                      context,
                      title: 'Notifications',
                      subtitle: 'Broadcast admin notices quickly',
                      icon: Icons.notifications_active_rounded,
                      color: const Color(0xFF8B5CF6),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => const AdminNotificationsPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                if (pendingApprovals > 0 || restrictedBusinesses > 0) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: context.adminSurfaceStrong,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.priority_high_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Needs Attention',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$pendingApprovals subscription reviews and $restrictedBusinesses restricted businesses need admin follow-up.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.78),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),

                // Recent Activity Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.adminTextPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => const AllBusinessesPage(),
                          ),
                        );
                      },
                      child: const Text('See all', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Activity List - Show filtered businesses from admin.allBusinesses
                if (admin.allBusinesses.isNotEmpty)
                  ..._getFilteredBusinesses(admin.allBusinesses)
                      .take(3)
                      .map((business) {
                    final businessName = business['name'] ?? 'Unknown Business';
                    final ownerName = business['email'] ?? 'Unknown Owner';
                    final businessType = business['businessType'] ?? 'General';
                    final isActive = business['isActive'] ?? true;
                    final createdAt = business['createdAt'];

                    String timeAgo = 'Recently';
                    if (createdAt != null) {
                      try {
                        DateTime? date;
                        if (createdAt is Timestamp) {
                          date = createdAt.toDate();
                        } else if (createdAt is DateTime) {
                          date = createdAt;
                        } else {
                          date = DateTime.tryParse(createdAt.toString());
                        }
                        if (date != null) {
                          final now = DateTime.now();
                          final diff = now.difference(date);
                          if (diff.inHours < 1) {
                            timeAgo = '${diff.inMinutes}m ago';
                          } else if (diff.inHours < 24) {
                            timeAgo = '${diff.inHours}h ago';
                          } else {
                            timeAgo = '${diff.inDays}d ago';
                          }
                        }
                      } catch (e) {
                        timeAgo = 'Recently';
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) =>
                                  BusinessDetailPage(business: business),
                            ),
                          );
                        },
                        child: _buildActivityCard(
                          businessName,
                          ownerName,
                          businessType,
                          timeAgo,
                          _getColorForBusinessType(businessType),
                          isActive,
                        ),
                      ),
                    );
                  })
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No businesses yet',
                        style: TextStyle(color: context.adminTextSecondary),
                      ),
                    ),
                  ),
                const SizedBox(height: 28),

                // Tier Distribution
                Text(
                  'Business Type Distribution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.adminTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ..._buildBusinessTypeDistribution(admin.allBusinesses),
              ],
            );
          },
        ),
      ),
    )));
  }

  Widget _buildStatCard(
      String title,
      String value,
      IconData icon,
      Color color,
      String badge, {
      VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: context.adminCardDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badge == 'Live'
                        ? const Color(0xFF10B981).withOpacity(0.1)
                        : badge == 'Urgent'
                            ? const Color(0xFFF59E0B).withOpacity(0.1)
                            : color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: badge == 'Live'
                          ? const Color(0xFF10B981)
                          : badge == 'Urgent'
                              ? const Color(0xFFF59E0B)
                              : color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: context.adminTextPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.adminTextSecondary,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'View details',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: color,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final width = MediaQuery.of(context).size.width;
    final tileWidth = width > 760 ? (width - 64) / 2 : width - 40;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: tileWidth,
        padding: const EdgeInsets.all(18),
        decoration: context.adminCardDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.adminTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.adminTextSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(String name, String owner, String tier, String time,
      Color color, bool isOnline) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.adminCardDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.adminTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      owner,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.adminTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tier,
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isOnline ? const Color(0xFF10B981) : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  fontSize: 12,
                  color: isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Filter businesses based on search query
  List<Map<String, dynamic>> _getFilteredBusinesses(
      List<Map<String, dynamic>> businesses) {
    if (_searchQuery.isEmpty) {
      return businesses;
    }

    return businesses.where((business) {
      final name = business['name']?.toString().toLowerCase() ?? '';
      final owner = business['email']?.toString().toLowerCase() ?? '';
      final type = business['businessType']?.toString().toLowerCase() ?? '';

      return name.contains(_searchQuery) ||
          owner.contains(_searchQuery) ||
          type.contains(_searchQuery);
    }).toList();
  }

  /// Get color for business type
  Color _getColorForBusinessType(String businessType) {
    final type = businessType.toLowerCase();
    if (type.contains('drink') || type.contains('bar')) {
      return const Color(0xFF8B5CF6);
    } else if (type.contains('restaurant')) {
      return const Color(0xFFF59E0B);
    } else if (type.contains('retail')) {
      return const Color(0xFF10B981);
    } else if (type.contains('hotel')) {
      return const Color(0xFF3B82F6);
    } else if (type.contains('salon')) {
      return const Color(0xFFEC4899);
    } else if (type.contains('gym')) {
      return const Color(0xFF06B6D4);
    } else if (type.contains('auto')) {
      return const Color(0xFF6366F1);
    } else if (type.contains('pharmacy')) {
      return const Color(0xFF14B8A6);
    } else if (type.contains('agri')) {
      return const Color(0xFF84CC16);
    } else {
      return const Color(0xFF64748B);
    }
  }

  /// Build business type distribution list
  List<Widget> _buildBusinessTypeDistribution(
      List<Map<String, dynamic>> businesses) {
    final typeCount = <String, int>{};

    for (var business in businesses) {
      final type = business['businessType'] ?? 'Other';
      typeCount[type] = (typeCount[type] ?? 0) + 1;
    }

    if (typeCount.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text(
              'No business types recorded',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ),
        ),
      ];
    }

    final total = businesses.length;
    final widgets = <Widget>[];

    typeCount.forEach((type, count) {
      widgets.add(
        _buildTierProgress(type, count, total, _getColorForBusinessType(type)),
      );
      widgets.add(const SizedBox(height: 12));
    });

    return widgets;
  }

  Widget _buildTierProgress(String name, int count, int total, Color color) {
    final percentage = (count / total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            Text(
              '$count businesses',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: FractionallySizedBox(
            widthFactor: percentage,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class BusinessesPage extends StatelessWidget {
  const BusinessesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _BusinessesPageStateful();
  }
}

class _BusinessesPageStateful extends StatefulWidget {
  const _BusinessesPageStateful();

  @override
  State<_BusinessesPageStateful> createState() => __BusinessesPageStatefulState();
}

class __BusinessesPageStatefulState extends State<_BusinessesPageStateful> {
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredBusinesses(List<Map<String, dynamic>> businesses) {
    if (_searchQuery.isEmpty) return businesses;
    return businesses.where((business) {
      final name = business['name']?.toString().toLowerCase() ?? '';
      final owner = business['email']?.toString().toLowerCase() ?? '';
      final type = business['businessType']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery) || owner.contains(_searchQuery) || type.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.adminBackground,
      child: SafeArea(
        child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.adminSurface,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(context.isAdminDark ? 0.22 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Consumer<AdminProvider>(
              builder: (context, admin, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All Businesses',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: context.adminTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${admin.allBusinesses.length} registered businesses',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.adminTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                        decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: context.adminTextTertiary,
                        ),
                        hintText: 'Search businesses...',
                        hintStyle:
                            TextStyle(color: context.adminTextTertiary),
                        filled: true,
                        fillColor: context.adminSurfaceAlt,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildBusinessesSummaryChip(
                          'Active',
                          admin.activeBusinessesCount.toString(),
                          const Color(0xFF10B981),
                        ),
                        _buildBusinessesSummaryChip(
                          'Restricted',
                          admin.restrictedBusinessesCount.toString(),
                          const Color(0xFFEF4444),
                        ),
                        _buildBusinessesSummaryChip(
                          'Live Plans',
                          admin.activeSubscriptionsCount.toString(),
                          const Color(0xFF8B5CF6),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: Consumer<AdminProvider>(
              builder: (context, admin, _) {
                if (admin.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (admin.allBusinesses.isEmpty) {
                  if (admin.allBusinesses.isEmpty && !admin.isLoading) {
                    // Defer the fetch to next frame to avoid calling during build
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      admin.fetchAdminStats();
                    });
                  }
                  return Center(
                        child: Text(
                      'No businesses found',
                      style: TextStyle(color: context.adminTextSecondary),
                    ),
                  );
                }

                final filtered = _getFilteredBusinesses(admin.allBusinesses);

                return RefreshIndicator(
                  onRefresh: () => admin.fetchAdminStats(force: true),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: filtered.map((business) {
                    // Convert Timestamp to String if needed
                    String updatedAtStr = 'Recently';
                    if (business['updatedAt'] != null) {
                      if (business['updatedAt'] is Timestamp) {
                        final date =
                            (business['updatedAt'] as Timestamp).toDate();
                        updatedAtStr = '${date.month}/${date.day}/${date.year}';
                      } else {
                        updatedAtStr = business['updatedAt'].toString();
                      }
                    }

                    // Get subscription tier for pricing
                    final subscriptionTier = business['subscriptionTier']
                            ?.toString()
                            .toLowerCase() ??
                        'basic';
                    final subscriptionPricing = {
                      'basic': '₦10,000',
                      'pro': '₦20,000',
                      'enterprise': '₦100,000',
                    };

                    return Column(
                      children: [
                        _buildBusinessCard(
                          context,
                          business['name'] ?? 'Unknown',
                          business['ownerName'] ?? 'Unknown',
                          subscriptionTier,
                          business['totalWorkers'] ?? 0,
                          updatedAtStr,
                          business['isActive'] ?? true,
                          subscriptionPricing[subscriptionTier] ?? '₦10,000',
                          business,
                        ),
                        
                      ],
                    );
                  }).toList(),
                ));
              },
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildBusinessesSummaryChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showBusinessInfoDialog(
      BuildContext context, Map<String, dynamic> business) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(business['name'] ?? 'Business Info'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Owner: ${business['ownerName'] ?? '-'}'),
                Text('Email: ${business['email'] ?? '-'}'),
                Text('Phone: ${business['phone'] ?? '-'}'),
                Text('Type: ${business['businessType'] ?? '-'}'),
                Text('Address: ${business['address'] ?? '-'}'),
                Text('Tier: ${business['subscriptionTier'] ?? '-'}'),
                Text('Subscription Status: ${business['subscriptionStatus'] ?? business['subscriptionReviewStatus'] ?? 'n/a'}'),
                Text('Restricted: ${business['isRestricted'] == true ? 'Yes' : 'No'}'),
                if ((business['restrictionReason'] ?? '').toString().isNotEmpty)
                  Text('Restriction Reason: ${business['restrictionReason']}'),
                Text('Active: ${business['isActive'] ?? true}'),
                Text('Total Workers: ${business['totalWorkers'] ?? 0}'),
                Text('Created: ${_formatTimestamp(business['createdAt'])}'),
                Text('Updated: ${_formatTimestamp(business['updatedAt'])}'),
                Text('ID: ${business['id'] ?? '-'}'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _showEditBusinessDialog(BuildContext context, AdminProvider admin,
      Map<String, dynamic> business) {
    final nameController = TextEditingController(text: business['name'] ?? '');
    final ownerController =
        TextEditingController(text: business['ownerName'] ?? '');
    final emailController =
        TextEditingController(text: business['email'] ?? '');
    final phoneController =
        TextEditingController(text: business['phone'] ?? '');
    final typeController =
        TextEditingController(text: business['businessType'] ?? '');
    final addressController =
        TextEditingController(text: business['address'] ?? '');
    String rawTier =
        business['subscriptionTier']?.toString().toLowerCase() ?? 'basic';
    // Normalize tier to valid values
    String tier = (rawTier == 'professional')
        ? 'pro'
        : (rawTier == 'starter')
            ? 'basic'
            : rawTier;
    // Ensure tier is one of the valid options
    if (!['basic', 'pro', 'enterprise'].contains(tier)) {
      tier = 'basic';
    }
    // Business class (new): tier1, tier2, tier3
    String selectedClass = business['businessClass']?.toString().toLowerCase() ?? 'tier1';
    bool isActive = business['isActive'] ?? true;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Business'),
        content: StatefulBuilder(builder: (ctx, setState) {
          return SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: nameController,
                      decoration:
                          const InputDecoration(labelText: 'Business Name')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: ownerController,
                      decoration:
                          const InputDecoration(labelText: 'Owner Name')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: emailController,
                      decoration:
                          const InputDecoration(labelText: 'Owner Email')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: phoneController,
                      decoration:
                          const InputDecoration(labelText: 'Phone Number')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: typeController,
                      decoration:
                          const InputDecoration(labelText: 'Business Type')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: addressController,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(labelText: 'Business Address')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedClass,
                    items: const [
                      DropdownMenuItem(value: 'tier1', child: Text('Tier1 (Basic only)')),
                      DropdownMenuItem(value: 'tier2', child: Text('Tier2 (Basic & Pro)')),
                      DropdownMenuItem(value: 'tier3', child: Text('Tier3 (Basic & Pro)')),
                    ],
                    onChanged: (v) => setState(() => selectedClass = v ?? 'tier1'),
                    decoration:
                        const InputDecoration(labelText: 'Business Class'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: tier,
                    items: const [
                      DropdownMenuItem(
                          value: 'basic', child: Text('Basic - ₦10,000')),
                      DropdownMenuItem(
                          value: 'pro', child: Text('Pro - ₦20,000')),
                      DropdownMenuItem(
                          value: 'enterprise',
                          child: Text('Enterprise - ₦100,000')),
                    ],
                    onChanged: (v) => setState(() => tier = v ?? 'basic'),
                    decoration:
                        const InputDecoration(labelText: 'Subscription Tier'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Active'),
                      const SizedBox(width: 12),
                      Switch(
                          value: isActive,
                          onChanged: (v) => setState(() => isActive = v)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final updates = {
                'name': nameController.text.trim(),
                'ownerName': ownerController.text.trim(),
                'email': emailController.text.trim(),
                'phone': phoneController.text.trim(),
                'businessType': typeController.text.trim(),
                'address': addressController.text.trim(),
                'subscriptionTier': tier,
                'businessClass': selectedClass,
                'isActive': isActive,
                'updatedAt': DateTime.now().toIso8601String(),
              };
              final ok =
                  await admin.updateBusiness(business['id'] as String, updates);
              if (ok && context.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Business updated')));
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Update failed')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRestrictionDialog(
    BuildContext context,
    AdminProvider admin,
    Map<String, dynamic> business,
  ) {
    final isRestricted = business['isRestricted'] == true;
    final reasonController = TextEditingController(
      text: (business['restrictionReason'] ?? '').toString(),
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isRestricted ? 'Restore Business' : 'Restrict Business'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRestricted
                  ? 'Restore ${business['name'] ?? 'this business'} and allow access again.'
                  : 'Restrict ${business['name'] ?? 'this business'} from using the app until admin review is complete.',
            ),
            if (!isRestricted) ...[
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Restriction reason',
                  hintText: 'Explain why access is being restricted',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ok = await admin.setBusinessRestriction(
                businessId: business['id'] as String,
                restricted: !isRestricted,
                reason: reasonController.text.trim(),
              );
              if (!context.mounted) return;
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? isRestricted
                            ? 'Business restored successfully'
                            : 'Business restricted successfully'
                        : 'Unable to update business restriction',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isRestricted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
            child: Text(isRestricted ? 'Restore' : 'Restrict'),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessCard(
      BuildContext context,
      String name,
      String owner,
      String tier,
      int users,
      String lastLogin,
      bool isActive,
      String pricing,
      Map<String, dynamic> business) {
    Color tierColor;
    String tierName;

    final businessClass = business['businessClass']?.toString().toLowerCase();
    if (businessClass == 'tier3') {
      tierColor = const Color(0xFFF59E0B);
      tierName = 'Tier3 - $pricing';
    } else if (businessClass == 'tier2') {
      tierColor = const Color(0xFF8B5CF6);
      tierName = 'Tier2 - $pricing';
    } else if (businessClass == 'tier1') {
      tierColor = const Color(0xFF3B82F6);
      tierName = 'Tier1 - $pricing';
    } else {
      // Fallback to older 'tier' value if businessClass not set
      if (tier.toLowerCase().contains('enterprise')) {
        tierColor = const Color(0xFFF59E0B);
        tierName = 'Enterprise - $pricing';
      } else if (tier.toLowerCase().contains('pro')) {
        tierColor = const Color(0xFF8B5CF6);
        tierName = 'Pro - $pricing';
      } else {
        tierColor = const Color(0xFF3B82F6);
        tierName = 'Basic - $pricing';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: context.adminCardDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: tierColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0] : '?',
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.adminTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      owner,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.adminTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildBusinessesSummaryChip(
                          'Access',
                          business['isRestricted'] == true
                              ? 'Locked'
                              : isActive
                                  ? 'Live'
                                  : 'Paused',
                          business['isRestricted'] == true
                              ? const Color(0xFFEF4444)
                              : isActive
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF64748B),
                        ),
                        _buildBusinessesSummaryChip(
                          'Plan',
                          (business['subscriptionStatus'] ??
                                  business['subscriptionReviewStatus'] ??
                                  (business['isSubscriptionActive'] == true
                                      ? 'approved'
                                      : 'inactive'))
                              .toString()
                              .toUpperCase(),
                          const Color(0xFF8B5CF6),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF10B981) : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: tierColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        tierName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tierColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Subscription',
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: context.adminSurfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$users',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.adminTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Users',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.adminTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: context.adminSurfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        lastLogin,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? const Color(0xFF10B981)
                              : context.adminTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last Login',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.adminTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showBusinessInfoDialog(context, business),
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('View'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final admin = context.read<AdminProvider>();
                    _showEditBusinessDialog(context, admin, business);
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B5CF6),
                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final admin = context.read<AdminProvider>();
                    _showRestrictionDialog(context, admin, business);
                  },
                  icon: Icon(
                    business['isRestricted'] == true
                        ? Icons.lock_open_rounded
                        : Icons.gpp_bad_rounded,
                    size: 18,
                  ),
                  label: Text(
                    business['isRestricted'] == true ? 'Restore' : 'Restrict',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: business['isRestricted'] == true
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    side: BorderSide(
                      color: business['isRestricted'] == true
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if ((business['restrictionReason'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.isAdminDark
                    ? const Color(0xFF3A1318)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Restriction note: ${business['restrictionReason']}',
                style: const TextStyle(
                  color: Color(0xFF991B1B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Payments Page - Uses AdminPaymentsPage to display all subscription payments
class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminPaymentsPage();
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _notificationTitleController = TextEditingController();
  final _notificationBodyController = TextEditingController();
  final _emailSubjectController = TextEditingController();
  final _emailBodyController = TextEditingController();
  final _customerCareWhatsappController = TextEditingController();
  bool _isSending = false;
  bool _pushNotificationsEnabled = true;
  bool _twoFactorEnabled = false;
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  @override
  void dispose() {
    _notificationTitleController.dispose();
    _notificationBodyController.dispose();
    _emailSubjectController.dispose();
    _emailBodyController.dispose();
    _customerCareWhatsappController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final admin = context.read<AdminProvider>();
    final settings = await admin.getAdminSettings();
    if (!mounted) return;
    setState(() {
      _pushNotificationsEnabled =
          (settings['pushNotificationsEnabled'] as bool?) ?? true;
      _twoFactorEnabled = (settings['twoFactorEnabled'] as bool?) ?? false;
      _selectedLanguage = (settings['language'] as String?) ?? 'en';
      _customerCareWhatsappController.text =
          (settings['customerCareWhatsapp'] as String?) ??
              (settings['supportWhatsapp'] as String?) ??
              '';
    });
  }

  Future<void> _saveAdminSettings(Map<String, dynamic> settings) async {
    final admin = context.read<AdminProvider>();
    final ok = await admin.saveAdminSettings(settings);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Settings saved' : 'Failed to save settings'),
      ),
    );
  }

  Future<void> _sendBroadcastNotification() async {
    if (_notificationTitleController.text.isEmpty ||
        _notificationBodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please fill notification title and body')));
      return;
    }
    setState(() => _isSending = true);
    final admin = context.read<AdminProvider>();
    final ok = await admin.sendBroadcastNotification(
        title: _notificationTitleController.text,
        body: _notificationBodyController.text);
    setState(() => _isSending = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              ok ? 'Notification queued' : 'Failed to queue notification')));
      if (ok) {
        _notificationTitleController.clear();
        _notificationBodyController.clear();
      }
    }
  }

  Future<void> _showSpecificUserNotificationPicker() async {
    if (_notificationTitleController.text.isEmpty ||
        _notificationBodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a notification title and body first'),
        ),
      );
      return;
    }

    final admin = context.read<AdminProvider>();
    if (admin.allUsers.isEmpty) {
      await admin.fetchAdminStats(force: true);
    }
    if (!mounted) return;

    String query = '';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.adminSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final users = admin.allUsers.where((user) {
            if (query.isEmpty) return true;
            final name = (user['name'] ?? '').toString().toLowerCase();
            final email = (user['email'] ?? '').toString().toLowerCase();
            return name.contains(query) || email.contains(query);
          }).toList();

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Send To Specific User',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.adminTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (value) => setSheetState(
                    () => query = value.trim().toLowerCase(),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Search by name or email',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 360,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary.withOpacity(0.12),
                          child: Text(
                            (user['name']?.toString().isNotEmpty ?? false)
                                ? user['name'].toString()[0].toUpperCase()
                                : 'U',
                          ),
                        ),
                        title: Text(
                          (user['name'] ?? 'Unknown').toString(),
                          style: TextStyle(color: context.adminTextPrimary),
                        ),
                        subtitle: Text(
                          (user['email'] ?? 'No email').toString(),
                          style: TextStyle(color: context.adminTextSecondary),
                        ),
                        trailing: FilledButton(
                          onPressed: () async {
                            final ok = await admin.sendNotificationToUsers(
                              title: _notificationTitleController.text.trim(),
                              body: _notificationBodyController.text.trim(),
                              userIds: [(user['id'] ?? '').toString()],
                            );
                            if (!mounted) return;
                            Navigator.of(sheetContext).pop();
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Notification sent to ${(user['name'] ?? 'user').toString()}'
                                      : 'Failed to send notification',
                                ),
                              ),
                            );
                          },
                          child: const Text('Send'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _sendBroadcastEmail() async {
    if (_emailSubjectController.text.isEmpty ||
        _emailBodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill email subject and body')));
      return;
    }
    setState(() => _isSending = true);
    final admin = context.read<AdminProvider>();
    final ok = await admin.sendBroadcastEmail(
        subject: _emailSubjectController.text, body: _emailBodyController.text);
    setState(() => _isSending = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? (admin.errorMessage ?? 'Emails sent successfully')
              : (admin.errorMessage ?? 'Failed to send email'))));
      if (ok) {
        _emailSubjectController.clear();
        _emailBodyController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return ColoredBox(
      color: context.adminBackground,
      child: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: context.adminTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Platform administration and communication tools',
              style: TextStyle(color: context.adminTextSecondary),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: context.adminCardDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      themeProvider.isDarkMode
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dark Mode',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.adminTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          themeProvider.isDarkMode
                              ? 'Admin screens use the dark appearance'
                              : 'Admin screens use the light appearance',
                          style: TextStyle(color: context.adminTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: themeProvider.isDarkMode,
                    onChanged: themeProvider.setDarkMode,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Admin Communication
            Text(
              'Admin Communications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.adminTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: _notificationTitleController,
                decoration:
                    const InputDecoration(labelText: 'Notification Title')),
            const SizedBox(height: 8),
            TextField(
                controller: _notificationBodyController,
                decoration:
                    const InputDecoration(labelText: 'Notification Body'),
                maxLines: 3),
            const SizedBox(height: 8),
            ElevatedButton.icon(
                onPressed: _isSending ? null : _sendBroadcastNotification,
                icon: const Icon(Icons.notifications),
                label: Text(
                    _isSending ? 'Sending...' : 'Send Notification to all'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isSending ? null : _showSpecificUserNotificationPicker,
              icon: const Icon(Icons.person_pin_circle_outlined),
              label: const Text('Send Notification to Specific User'),
            ),
            const SizedBox(height: 20),
            TextField(
                controller: _emailSubjectController,
                decoration: const InputDecoration(labelText: 'Email Subject')),
            const SizedBox(height: 8),
            TextField(
                controller: _emailBodyController,
                decoration: const InputDecoration(labelText: 'Email Body'),
                maxLines: 4),
            const SizedBox(height: 8),
            ElevatedButton.icon(
                onPressed: _isSending ? null : _sendBroadcastEmail,
                icon: const Icon(Icons.email),
                label: Text(_isSending ? 'Sending...' : 'Send Email to all'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
            ),
            const SizedBox(height: 24),

            Text(
              'Restricted Account Support',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.adminTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customerCareWhatsappController,
              decoration: const InputDecoration(
                labelText: 'Customer care WhatsApp',
                hintText: '+2348063124936',
                helperText:
                    'Shown to restricted businesses so they know who to contact.',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _saveAdminSettings({
                'customerCareWhatsapp':
                    _customerCareWhatsappController.text.trim(),
              }),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save support contact'),
            ),
            const SizedBox(height: 24),

            // Existing settings (kept simple)
            _buildSettingItem(Icons.notifications_rounded, 'Notifications',
              _pushNotificationsEnabled ? 'Push notifications enabled' : 'Push notifications disabled', const Color(0xFF3B82F6), onTap: () => _showNotificationSettingsDialog(context)),
            _buildSettingItem(Icons.security_rounded, 'Security',
              _twoFactorEnabled ? 'Two-factor authentication enabled' : 'Two-factor authentication disabled', const Color(0xFF10B981), onTap: () => _showSecurityDialog(context)),
            _buildSettingItem(Icons.language_rounded, 'Language',
              _selectedLanguage == 'en' ? 'English (US)' : 'Spanish', const Color(0xFF8B5CF6), onTap: () => _showLanguageDialog(context)),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
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
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildSettingItem(
      IconData icon, String title, String subtitle, Color color,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: context.adminCardDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.adminTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.adminTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400]),
        ],
      ),
    ));
  }

  void _showNotificationSettingsDialog(BuildContext context) {
    bool enabled = _pushNotificationsEnabled;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notification Settings'),
        content: StatefulBuilder(builder: (ctx, setState) {
          return SwitchListTile(
            title: const Text('Enable push notifications'),
            value: enabled,
            onChanged: (v) => setState(() => enabled = v),
          );
        }),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () async {
                setState(() => _pushNotificationsEnabled = enabled);
                await _saveAdminSettings({
                  'pushNotificationsEnabled': enabled,
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Save'))
        ],
      ),
    );
  }

  void _showSecurityDialog(BuildContext context) {
    bool enabled = _twoFactorEnabled;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Security'),
        content: StatefulBuilder(
          builder: (ctx, setStateDialog) => SwitchListTile(
            title: const Text('Enable two-factor authentication'),
            subtitle: const Text('Require an extra verification step for admin access.'),
            value: enabled,
            onChanged: (value) => setStateDialog(() => enabled = value),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
          ElevatedButton(
              onPressed: () async {
                setState(() => _twoFactorEnabled = enabled);
                await _saveAdminSettings({
                  'twoFactorEnabled': enabled,
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Save'))
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    String lang = _selectedLanguage;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Language'),
        content: StatefulBuilder(builder: (ctx, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                value: 'en',
                groupValue: lang,
                title: const Text('English (US)'),
                onChanged: (v) => setState(() => lang = v ?? 'en'),
              ),
              RadioListTile<String>(
                value: 'es',
                groupValue: lang,
                title: const Text('Spanish'),
                onChanged: (v) => setState(() => lang = v ?? 'es'),
              ),
            ],
          );
        }),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () async {
                setState(() => _selectedLanguage = lang);
                await _saveAdminSettings({
                  'language': lang,
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Set'))
        ],
      ),
    );
  }
}

/// Users and Workers Page - Displays users and allows one-year subscription approval
class UsersAndWorkersPage extends StatefulWidget {
  const UsersAndWorkersPage({super.key});

  @override
  State<UsersAndWorkersPage> createState() => _UsersAndWorkersPageState();
}

class _UsersAndWorkersPageState extends State<UsersAndWorkersPage> {
  String _searchQuery = '';
  String _filterType = 'all'; // all, users, workers

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.adminBackground,
      child: SafeArea(
        child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.adminSurface,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(context.isAdminDark ? 0.22 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Users & Workers',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: context.adminTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Consumer<AdminProvider>(
                  builder: (context, admin, _) {
                    return Text(
                      '${admin.allUsers.length} unique records across ${admin.usersTableCount} users and ${admin.workersTableCount} workers rows',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.adminTextSecondary,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Search Field
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: Icon(Icons.search, color: context.adminTextSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.adminBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.adminBorder),
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 16),
                // Filter Buttons
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterButton('All', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterButton('Users', 'users'),
                      const SizedBox(width: 8),
                      _buildFilterButton('Workers', 'workers'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Consumer<AdminProvider>(
                  builder: (context, admin, _) => Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildHeaderChip(
                        label: 'Pending Reviews',
                        value: admin.pendingSubscriptionApprovalsCount.toString(),
                        color: const Color(0xFFF97316),
                      ),
                      _buildHeaderChip(
                        label: 'Restricted Businesses',
                        value: admin.restrictedBusinessesCount.toString(),
                        color: const Color(0xFFEF4444),
                      ),
                      _buildHeaderChip(
                        label: 'Active Users',
                        value: admin.stats.activeUsers.toString(),
                        color: const Color(0xFF10B981),
                      ),
                      _buildHeaderChip(
                        label: 'Users Table',
                        value: admin.usersTableCount.toString(),
                        color: const Color(0xFF2563EB),
                      ),
                      _buildHeaderChip(
                        label: 'Workers Table',
                        value: admin.workersTableCount.toString(),
                        color: const Color(0xFF6B7280),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Users List
          Expanded(
            child: Consumer<AdminProvider>(
              builder: (context, admin, _) {
                if (admin.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filter users based on search and type
                List<Map<String, dynamic>> filteredUsers = admin.allUsers.where((user) {
                  final matchesSearch = _searchQuery.isEmpty ||
                      (user['name']?.toString() ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      (user['email']?.toString() ?? '').toLowerCase().contains(_searchQuery.toLowerCase());

                  final isWorker = user['isWorker'] == true ||
                      user['role'] == 'worker' ||
                      user['type'] == 'worker';
                  final matchesType = _filterType == 'all' ||
                      (_filterType == 'workers' && isWorker) ||
                      (_filterType == 'users' && !isWorker);

                  return matchesSearch && matchesType;
                }).toList();

                if (filteredUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: TextStyle(
                            fontSize: 18,
                            color: context.adminTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return _buildUserCard(context, user);
                  },
                );
              },
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildFilterButton(String label, String value) {
    final isSelected = _filterType == value;
    return ElevatedButton(
      onPressed: () => setState(() => _filterType = value),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primary
            : context.adminSurfaceAlt,
        foregroundColor:
            isSelected ? Colors.white : context.adminTextSecondary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(label),
    );
  }

  Widget _buildHeaderChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.92),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, Map<String, dynamic> user) {
    final isWorker = user['isWorker'] == true ||
        user['role'] == 'worker' ||
        user['type'] == 'worker';
    final isDeleted = user['isDeleted'] == true;
    final businessName = (user['businessName'] ?? user['businessId'] ?? 'No business')
        .toString();
    final businessRestricted = user['businessRestricted'] == true;
    final tableSource = (user['tableSource'] ?? 'users').toString();
    // Handle isSubscriptionActive as either boolean or string
    final subscriptionValue = user['isSubscriptionActive'];
    final hasActiveSubscription = subscriptionValue == true || 
        subscriptionValue == 'true' || 
        subscriptionValue == 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.adminBorder),
      ),
      color: context.adminSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isWorker ? const Color(0xFF6B7280) : const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      (user['name']?.toString().isNotEmpty ?? false)
                          ? user['name'].toString()[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user['name'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.adminTextPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isWorker
                                  ? const Color(0xFF6B7280).withOpacity(0.16)
                                  : const Color(0xFF3B82F6).withOpacity(0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isWorker ? 'Worker' : 'User',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isWorker
                                    ? const Color(0xFF6B7280)
                                    : const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['email'] ?? 'No email',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.adminTextSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildHeaderChip(
                            label: isWorker ? 'Worker' : 'User',
                            value: businessRestricted ? 'Restricted' : 'Ready',
                            color: businessRestricted
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
                          ),
                          _buildHeaderChip(
                            label: 'Business',
                            value: businessName.length > 12
                                ? '${businessName.substring(0, 12)}...'
                                : businessName,
                            color: const Color(0xFF3B82F6),
                          ),
                          _buildHeaderChip(
                            label: 'Tables',
                            value: tableSource,
                            color: const Color(0xFF8B5CF6),
                          ),
                          if (isDeleted)
                            _buildHeaderChip(
                              label: 'Recovery',
                              value: 'Deleted',
                              color: const Color(0xFFF97316),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Subscription Status
            if (hasActiveSubscription)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Text(
                      'Active - ${_getSubscriptionTier(user)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hourglass_empty, size: 14, color: Color(0xFFEF4444)),
                    const SizedBox(width: 6),
                    const Text(
                      'No Active Subscription',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            // Divider
            Container(
              height: 1,
              color: context.adminBorder,
            ),
            const SizedBox(height: 12),
            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 150,
                  child: OutlinedButton.icon(
                    onPressed: () => _showNotifyUserDialog(context, user),
                    icon: const Icon(Icons.notifications_active_outlined, size: 16),
                    label: const Text('Notify'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: OutlinedButton.icon(
                    onPressed: () => _showUserDetails(context, user),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.adminTextPrimary,
                      side: BorderSide(color: context.adminBorder),
                    ),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: ElevatedButton.icon(
                    onPressed: hasActiveSubscription
                        ? null
                        : () => _showSubscriptionDialog(context, user),
                    icon: const Icon(Icons.card_giftcard, size: 16),
                    label: Text(hasActiveSubscription ? 'Active' : 'Approve 1Y'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          hasActiveSubscription ? Colors.grey[300] : const Color(0xFF10B981),
                      foregroundColor:
                          hasActiveSubscription ? Colors.grey[600] : Colors.white,
                    ),
                  ),
                ),
                if ((user['businessId'] ?? '').toString().isNotEmpty && !hasActiveSubscription)
                  SizedBox(
                    width: 150,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showDeclineSubscriptionDialog(context, user),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Decline'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                      ),
                    ),
                  ),
                if ((user['businessId'] ?? '').toString().isNotEmpty)
                  SizedBox(
                    width: 170,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showUserRestrictionDialog(context, user),
                      icon: Icon(
                        businessRestricted
                            ? Icons.lock_open_rounded
                            : Icons.gpp_bad_rounded,
                        size: 16,
                      ),
                      label: Text(businessRestricted ? 'Restore Biz' : 'Restrict Biz'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: businessRestricted
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        side: BorderSide(
                          color: businessRestricted
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ),
                SizedBox(
                  width: 150,
                  child: OutlinedButton.icon(
                    onPressed: () => isDeleted
                        ? _showRestoreUserDialog(context, user)
                        : _showDeleteUserDialog(context, user),
                    icon: Icon(
                      isDeleted
                          ? Icons.restore_rounded
                          : Icons.delete_outline_rounded,
                      size: 16,
                    ),
                    label: Text(isDeleted ? 'Restore' : 'Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDeleted
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      side: BorderSide(
                        color: isDeleted
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getSubscriptionTier(Map<String, dynamic> user) {
    final tier = user['subscriptionTier']?.toString() ?? 'basic';
    switch (tier.toLowerCase()) {
      case 'pro':
        return 'Pro';
      case 'enterprise':
        return 'Enterprise';
      default:
        return 'Basic';
    }
  }

  void _showUserDetails(BuildContext context, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('User Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Name', user['name'] ?? 'N/A'),
              _buildDetailRow('Email', user['email'] ?? 'N/A'),
              _buildDetailRow('Referral Email', user['referralEmail'] ?? 'N/A'),
              _buildDetailRow('Phone', user['phone'] ?? 'N/A'),
              _buildDetailRow(
                'Type',
                (user['isWorker'] == true || user['role'] == 'worker')
                    ? 'Worker'
                    : 'User',
              ),
              _buildDetailRow(
                'Tables',
                user['tableSource']?.toString() ?? 'users',
              ),
              _buildDetailRow(
                'Business',
                user['businessName'] ?? user['businessId'] ?? 'N/A',
              ),
              _buildDetailRow(
                'Joined',
                user['createdAt'] != null
                    ? _formatTimestamp(user['createdAt'])
                    : 'N/A',
              ),
              _buildDetailRow(
                'Last Active',
                user['lastActive'] != null
                    ? _formatTimestamp(user['lastActive'])
                    : 'N/A',
              ),
              _buildDetailRow(
                'Subscription',
                user['isSubscriptionActive'] == true ? 'Active - ${_getSubscriptionTier(user)}' : 'Inactive',
              ),
              if ((user['businessRestrictionReason'] ?? '').toString().isNotEmpty)
                _buildDetailRow(
                  'Restriction Reason',
                  user['businessRestrictionReason'].toString(),
                ),
              if ((user['serviceNames'] as List?)?.isNotEmpty ?? false)
                _buildDetailRow(
                  'Services',
                  (user['serviceNames'] as List).join(', '),
                ),
              if (user['commissionPercentage'] != null)
                _buildDetailRow(
                  'Commission',
                  '${user['commissionPercentage']}%',
                ),
              if (user['isDeleted'] == true)
                _buildDetailRow('Deletion Status', 'Deleted'),
              if ((user['deletedByType'] ?? '').toString().isNotEmpty)
                _buildDetailRow(
                  'Deleted By',
                  (user['deletedByType'] ?? '').toString(),
                ),
              if (user['recoveryDeadlineAt'] != null)
                _buildDetailRow(
                  'Recovery Deadline',
                  _formatTimestamp(user['recoveryDeadlineAt']),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  bool _hasActiveRecoveryWindow(Map<String, dynamic> user) {
    if (user['isDeleted'] != true || user['recoveryDeadlineAt'] == null) {
      return false;
    }

    try {
      return parseTimestamp(user['recoveryDeadlineAt']).isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  void _showDeleteUserDialog(BuildContext context, Map<String, dynamic> user) {
    final userId = (user['id'] ?? '').toString();
    final displayName = (user['name'] ?? user['email'] ?? 'this user').toString();
    if (userId.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'This will permanently delete $displayName from the users and workers collections where present. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );

              final ok = await context.read<AdminProvider>().deleteUserWithRecovery(
                    userId,
                  );

              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? '$displayName deleted permanently.'
                        : 'Failed to delete user.',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRestoreUserDialog(BuildContext context, Map<String, dynamic> user) {
    final userId = (user['id'] ?? '').toString();
    final displayName = (user['name'] ?? user['email'] ?? 'this user').toString();
    if (userId.isEmpty) return;

    final withinRecoveryWindow = _hasActiveRecoveryWindow(user);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore User'),
        content: Text(
          withinRecoveryWindow
              ? 'Restore $displayName and re-enable account access?'
              : 'This account appears to be outside the 30-day recovery window.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: !withinRecoveryWindow
                ? null
                : () async {
                    Navigator.of(ctx).pop();
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) =>
                          const Center(child: CircularProgressIndicator()),
                    );

                    final ok = await context
                        .read<AdminProvider>()
                        .restoreDeletedUserAccount(userId);

                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? '$displayName restored successfully.'
                              : 'Failed to restore user.',
                        ),
                      ),
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _showNotifyUserDialog(BuildContext context, Map<String, dynamic> user) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final recipientId = (user['id'] ?? '').toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Notify ${user['name'] ?? 'User'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: recipientId.isEmpty
                ? null
                : () async {
                    if (titleController.text.trim().isEmpty ||
                        bodyController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enter both a title and a message'),
                        ),
                      );
                      return;
                    }
                    final ok = await context
                        .read<AdminProvider>()
                        .sendNotificationToUsers(
                          title: titleController.text.trim(),
                          body: bodyController.text.trim(),
                          userIds: [recipientId],
                        );
                    if (!context.mounted) return;
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Notification sent to ${(user['name'] ?? 'user').toString()}'
                              : 'Failed to send notification',
                        ),
                      ),
                    );
                  },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionDialog(BuildContext context, Map<String, dynamic> user) {
    String selectedTier = user['subscriptionTier']?.toString().toLowerCase() ?? 'basic';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Approve 1-Year Subscription'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User: ${user['name'] ?? 'Unknown'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Subscription Tier:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                RadioListTile<String>(
                  value: 'basic',
                  groupValue: selectedTier,
                  title: const Text('Basic - ₦10,000/year'),
                  onChanged: (v) => setState(() => selectedTier = v ?? 'basic'),
                ),
                RadioListTile<String>(
                  value: 'pro',
                  groupValue: selectedTier,
                  title: const Text('Pro - ₦20,000/year'),
                  onChanged: (v) => setState(() => selectedTier = v ?? 'pro'),
                ),
                RadioListTile<String>(
                  value: 'enterprise',
                  groupValue: selectedTier,
                  title: const Text('Enterprise - ₦100,000/year'),
                  onChanged: (v) => setState(() => selectedTier = v ?? 'enterprise'),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDEEBFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info, size: 18, color: Color(0xFF1E40AF)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Subscription valid for 365 days from today',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _approveSubscription(context, user, selectedTier);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
              ),
              child: const Text('Approve'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeclineSubscriptionDialog(
    BuildContext context,
    Map<String, dynamic> user,
  ) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business: ${user['businessName'] ?? user['name'] ?? 'Unknown'}'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Tell the team why this approval was declined',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final businessId = (user['businessId'] ?? '').toString();
              if (businessId.isEmpty) {
                Navigator.of(ctx).pop();
                return;
              }
              final ok = await context.read<AdminProvider>().declineOneYearSubscription(
                    businessId: businessId,
                    businessName:
                        (user['businessName'] ?? user['name'] ?? 'Unknown').toString(),
                    reason: reasonController.text.trim(),
                  );
              if (!context.mounted) return;
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Subscription review declined'
                        : 'Unable to decline subscription review',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  void _showUserRestrictionDialog(
    BuildContext context,
    Map<String, dynamic> user,
  ) {
    final businessId = (user['businessId'] ?? '').toString();
    if (businessId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No linked business found for this user')),
      );
      return;
    }

    final businessRestricted = user['businessRestricted'] == true;
    final reasonController = TextEditingController(
      text: (user['businessRestrictionReason'] ?? '').toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          businessRestricted ? 'Restore Business Access' : 'Restrict Business Access',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business: ${user['businessName'] ?? businessId}'),
            if (!businessRestricted) ...[
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Restriction reason',
                  hintText: 'Explain why this business should be restricted',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ok = await context.read<AdminProvider>().setBusinessRestriction(
                    businessId: businessId,
                    restricted: !businessRestricted,
                    reason: reasonController.text.trim(),
                  );
              if (!context.mounted) return;
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? businessRestricted
                            ? 'Business access restored'
                            : 'Business restricted'
                        : 'Unable to update business access',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: businessRestricted
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
            ),
            child: Text(businessRestricted ? 'Restore' : 'Restrict'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveSubscription(
    BuildContext context,
    Map<String, dynamic> user,
    String tier,
  ) async {
    final admin = context.read<AdminProvider>();

    // Get the business ID - users have a businessId field
    String businessId = user['businessId'] ?? user['id'] ?? '';

    if (businessId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No business ID found for this user'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get navigator and messenger before async operations
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Approving subscription...'),
          ],
        ),
      ),
    );

    try {
      final success = await admin.approveOneYearSubscription(
        businessId: businessId,
        businessName: user['businessName'] ?? user['name'] ?? 'Unknown',
        tier: tier,
      );

      if (!mounted) return;
      
      // Close loading dialog
      try {
        navigator.pop();
      } catch (_) {
        // Navigator might be in a different state
      }

      if (success) {
        if (!mounted) return;
        
        // Show success message
        messenger.showSnackBar(
          SnackBar(
            content: Text('✓ ${user['name']} approved for ${tier.toUpperCase()} subscription (1 year)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Don't call fetchAdminStats() - it causes cascade of other fetches
        // The local cache was already updated in approveOneYearSubscription()
        // Consumer will rebuild automatically when AdminProvider calls notifyListeners()
      } else {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: ${admin.errorMessage ?? 'Failed to approve subscription'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      // Try to close loading dialog
      try {
        navigator.pop();
      } catch (_) {
        // Navigator might be in a different state
      }
      
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
  
