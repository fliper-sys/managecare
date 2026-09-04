import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/routes.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/worker_permissions.dart';

import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../industry_specific/drink/screens/drink_dashboard_screen.dart';
import '../../industry_specific/restaurant/screens/restaurant_owner_dashboard.dart';
import '../../industry_specific/hotel/screens/hotel_dashboard_screen.dart';
import '../../industry_specific/agri/screens/agri_dashboard_screen.dart';
import '../../industry_specific/salon/screens/salon_dashboard_screen.dart';
import '../../industry_specific/gym/screens/gym_dashboard_screen.dart';
import '../../industry_specific/auto/screens/worker_jobs_screen.dart';
import '../../industry_specific/realestate/screens/realestate_dashboard_screen.dart'
    as re;
import '../../industry_specific/pharmacy/screens/pharmacy_dashboard.dart';
import '../../industry_specific/retail/screens/retail_dashboard.dart';
import '../../industry_specific/gas/screens/gas_dashboard_screen.dart';
import '../../industry_specific/gas/utils/fuel_station_scope.dart';
import '../../industry_specific/wholesale/screens/warehouse_dashboard_screen.dart';
import '../../industry_specific/barber_shop/screens/barber_shop_dashboard_screen.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureBusinessLoaded();
    });
  }

  Future<void> _ensureBusinessLoaded() async {
    final authProvider = context.read<AuthProvider>();
    final businessProvider = context.read<BusinessProvider>();

    print('[WorkerDashboard] Initializing worker dashboard');
    print('[WorkerDashboard] Current user: ${authProvider.currentUser?.id}');
    print(
        '[WorkerDashboard] Current business: ${businessProvider.currentBusiness?.id}');
    print(
        '[WorkerDashboard] Business type: ${businessProvider.currentBusiness?.businessType}');

    // If no business is loaded, try to load it from the worker's businessId
    if (businessProvider.currentBusiness == null) {
      final workerBusinessId = authProvider.currentUser?.businessId;
      bool resolved = false;
      if (workerBusinessId != null && workerBusinessId.isNotEmpty) {
        print('[WorkerDashboard] Loading worker business: $workerBusinessId');
        await businessProvider.loadBusinessById(workerBusinessId);
        resolved = businessProvider.currentBusiness != null;
      } else {
        // Attempt to find the worker's business via the workers collection
        print('[WorkerDashboard] Attempting to resolve worker business via workers collection');
        resolved = await businessProvider.ensureBusinessForWorker(
          authProvider.currentUser?.id ?? '',
          workerEmail: authProvider.currentUser?.email,
        );
      }

      // If we resolved a business, rebuild so the proper dashboard is shown
      if (resolved && mounted) {
        setState(() {});
      }
    }
  }

  /// Pull-to-refresh handler that refreshes the user's document from the
  /// server and attempts to (re)resolve and load the worker's business.
  Future<void> _refreshForWorker() async {
    final authProvider = context.read<AuthProvider>();
    final businessProvider = context.read<BusinessProvider>();
    try {
      // Refresh the user document to pick up any new businessId changes
      await authProvider.refresh();

      final refreshedUser = authProvider.currentUser;
      final businessId = refreshedUser?.businessId;
      bool resolved = false;

      if (businessId != null && businessId.isNotEmpty) {
        await businessProvider.loadBusinessById(businessId);
        resolved = businessProvider.currentBusiness != null;
      } else if (refreshedUser != null) {
        resolved = await businessProvider.ensureBusinessForWorker(
          refreshedUser.id,
          workerEmail: refreshedUser.email,
        );
      }

      if (resolved) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Business loaded')),
          );
          setState(() {});
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No business found for this user')),
          );
        }
      }
    } catch (e) {
      print('[WorkerDashboard] Refresh failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Refresh failed: $e')),
        );
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
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
  }

  @override
  Widget build(BuildContext context) {
    // final authProvider = Provider.of<AuthProvider>(context);
    final businessProvider = context.watch<BusinessProvider>();
    final business = businessProvider.currentBusiness;

    print(
        '[WorkerDashboard] Building - Business: ${business?.id} (${business?.businessType})');

    // Show loading state while business is being loaded
    if (businessProvider.isLoading) {
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
          appBar: AppBar(
            title: const Text('Loading...'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Logout',
                onPressed: () => _handleLogout(context),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refreshForWorker,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 200),
                Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      );
    }

    // If no business is available, show error
    if (business == null) {
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
            appBar: AppBar(
              title: const Text('Worker Dashboard'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Logout',
                  onPressed: () => _handleLogout(context),
                ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: _refreshForWorker,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text('No Business Assigned'),
                        const SizedBox(height: 8),
                        const Text(
                          'Please contact your manager to assign a business',
                          style: AppTextStyles.body2Secondary,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ));
    }

    // Extract the primary business type (handle composite types like 'bar/drink')
    final businessTypeStr = business.businessType.toLowerCase();
    final primaryType = businessTypeStr.contains('/')
        ? businessTypeStr.split('/').last
        : businessTypeStr;

    print('[WorkerDashboard] Loading dashboard for type: $primaryType');
    final currentUser = context.watch<AuthProvider>().currentUser;
    final workerRole = WorkerPermissions.normalizeRole(currentUser?.role ?? '');

    // Route to industry-specific dashboard
    Widget? dashboard;
    switch (primaryType) {
      case 'drink':
      case 'bar':
        print('[WorkerDashboard] Showing Drink Dashboard');
        dashboard = const DrinkDashboardScreen();
        break;
      case 'restaurant':
        print('[WorkerDashboard] Showing Restaurant Dashboard');
        dashboard = const RestaurantDashboardScreen();
        break;
      case 'hotel':
        print('[WorkerDashboard] Showing Hotel Dashboard');
        dashboard = const HotelDashboardScreen();
        break;
      case 'agri':
      case 'agriculture':
        print('[WorkerDashboard] Showing Agri Dashboard');
        dashboard = const AgriDashboardScreen();
        break;
      case 'salon':
        print('[WorkerDashboard] Showing Salon Dashboard');
        dashboard = const SalonDashboardScreen();
        break;
      case 'barber':
      case 'barbershop':
        print('[WorkerDashboard] Showing Barbershop Dashboard');
        dashboard = const BarberShopDashboardScreen();
        break;
      case 'wholesale':
        print('[WorkerDashboard] Showing Wholesale/Warehouse Dashboard');
        dashboard = const WarehouseDashboardScreen();
        break;
      case 'gym':
        print('[WorkerDashboard] Showing Gym Dashboard');
        dashboard = const GymDashboardScreen();
        break;
      case 'auto':
      case 'auto repair':
        print('[WorkerDashboard] Showing Auto Dashboard');
        dashboard = const AutoWorkerJobsScreen();
        break;
      case 'realestate':
      case 'real estate':
        print('[WorkerDashboard] Showing Real Estate Dashboard');
        dashboard = const re.RealestateDashboardScreen();
        break;
      case 'pharmacy':
        print('[WorkerDashboard] Showing Pharmacy Dashboard');
        dashboard = const PharmacyDashboard();
        break;
      case 'retail':
        print('[WorkerDashboard] Showing Retail Dashboard');
        dashboard = const RetailDashboard();
        break;
      case 'bakery':
        print('[WorkerDashboard] Showing Bakery Dashboard');
        dashboard = const RetailDashboard.bakery();
        break;
      case 'gas':
      case 'petroleum':
      case 'petrol station':
      case 'petroleum station':
      case 'filling station':
      case 'petrol_station':
      case 'petroleum_station':
      case 'filling_station':
      case 'petrolstation':
      case 'petroleumstation':
      case 'fillingstation':
        final isPetroleumStation = FuelStationScope.isPetroleumBusiness(
          primaryType,
        );
        final hasGlobalStationAccess = [
          'owner',
          'admin',
          'sub_admin',
          'manager',
          'fuel_manager',
        ].contains(workerRole);
        if (hasGlobalStationAccess) {
          print('[WorkerDashboard] Showing full station dashboard');
          dashboard = GasDashboardScreen(
            mode: isPetroleumStation
                ? FuelStationMode.petroleum
                : FuelStationMode.gas,
          );
        } else if (workerRole == 'pump_operator') {
          print('[WorkerDashboard] Showing Pump Operator Dashboard');
          dashboard = const _PumpOperatorDashboard(
            canUploadReadings: true,
            canViewDeclinedUploads: true,
          );
        } else if (workerRole == 'sales_rep' || workerRole == 'cashier') {
          print(
              '[WorkerDashboard] Showing Mini Mart Dashboard for station sales rep');
          dashboard = const _StationSalesRepDashboard();
        } else {
          print('[WorkerDashboard] Showing limited station worker dashboard');
          dashboard = const _PumpOperatorDashboard(
            canUploadReadings: false,
            canViewDeclinedUploads: false,
          );
        }
        break;
    }

    if (dashboard == null) {
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
            appBar: AppBar(title: const Text('Worker Dashboard')),
            body: RefreshIndicator(
              onRefresh: _refreshForWorker,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.help, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text('Unknown Business Type'),
                        const SizedBox(height: 8),
                        Text(
                          'Business type "$primaryType" is not supported',
                          style: AppTextStyles.body2Secondary,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ));
    }

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
      child: RefreshIndicator(
        onRefresh: _refreshForWorker,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (currentUser != null)
              _GrantedAdminQuickNav(
                role: workerRole,
                permissions: currentUser.permissions,
              ),
            SizedBox(
              height: MediaQuery.of(context).size.height,
              child: dashboard,
            ),
          ],
        ),
      ),
    );
  }
}

class _GrantedAdminQuickNav extends StatelessWidget {
  const _GrantedAdminQuickNav({
    required this.role,
    required this.permissions,
  });

  final String role;
  final List<String> permissions;

  @override
  Widget build(BuildContext context) {
    final shortcuts = _buildShortcuts();
    if (shortcuts.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Granted Admin Access',
            style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Shortcuts approved by your admin for this business.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: shortcuts
                  .map(
                    (shortcut) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        avatar: Icon(shortcut.icon, size: 18),
                        label: Text(shortcut.label),
                        onPressed: () =>
                            Navigator.pushNamed(context, shortcut.route),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<_GrantedAdminShortcut> _buildShortcuts() {
    bool can(String permission) => WorkerPermissions.hasEffectivePermission(
          role,
          permissions,
          permission,
        );

    final shortcuts = <_GrantedAdminShortcut>[];
    if (can('access_owner_dashboard')) {
      shortcuts.add(
        const _GrantedAdminShortcut(
          label: 'Dashboard',
          route: Routes.ownerDashboard,
          icon: Icons.dashboard_rounded,
        ),
      );
    }
    if (can('access_inventory_screen') ||
        can('manage_inventory') ||
        can('view_inventory')) {
      shortcuts.add(
        const _GrantedAdminShortcut(
          label: 'Inventory',
          route: Routes.inventory,
          icon: Icons.inventory_2_rounded,
        ),
      );
    }
    if (can('access_fuel_stock_screen')) {
      shortcuts.add(
        const _GrantedAdminShortcut(
          label: 'Fuel Stock',
          route: Routes.gasStock,
          icon: Icons.inventory_2_rounded,
        ),
      );
    }
    if (can('access_pump_configuration_screen')) {
      shortcuts.add(
        const _GrantedAdminShortcut(
          label: 'Pump Config',
          route: Routes.gasPumpConfiguration,
          icon: Icons.tune_outlined,
        ),
      );
    }
    if (can('access_procurement_screen') || can('procurement_management')) {
      shortcuts.add(
        const _GrantedAdminShortcut(
          label: 'Procurement',
          route: Routes.procurement,
          icon: Icons.shopping_bag_rounded,
        ),
      );
    }
    if (can('access_reports_dashboard') || can('view_reports')) {
      shortcuts.add(
        const _GrantedAdminShortcut(
          label: 'Reports',
          route: Routes.reports,
          icon: Icons.bar_chart_rounded,
        ),
      );
    }
    if (can('access_analytics_dashboard')) {
      shortcuts.add(
        const _GrantedAdminShortcut(
          label: 'Analytics',
          route: Routes.advancedAnalytics,
          icon: Icons.insights_rounded,
        ),
      );
    }
    if (can('access_expenses_screen')) {
      shortcuts.add(
        const _GrantedAdminShortcut(
          label: 'Expenses',
          route: Routes.expenseReport,
          icon: Icons.receipt_long_rounded,
        ),
      );
    }
    if (can('attendance')) {
      shortcuts.add(
        const _GrantedAdminShortcut(
          label: 'Attendance',
          route: Routes.attendance,
          icon: Icons.fingerprint_rounded,
        ),
      );
    }
    if (can('access_workers_screen') || can('manage_staff')) {
      shortcuts.add(
        const _GrantedAdminShortcut(
          label: 'Workers',
          route: Routes.workers,
          icon: Icons.groups_rounded,
        ),
      );
    }
    shortcuts.add(
      const _GrantedAdminShortcut(
        label: 'Settings',
        route: Routes.settings,
        icon: Icons.settings_rounded,
      ),
    );
    return shortcuts;
  }
}

class _GrantedAdminShortcut {
  const _GrantedAdminShortcut({
    required this.label,
    required this.route,
    required this.icon,
  });

  final String label;
  final String route;
  final IconData icon;
}

class _PumpOperatorDashboard extends StatelessWidget {
  const _PumpOperatorDashboard({
    required this.canUploadReadings,
    required this.canViewDeclinedUploads,
  });

  final bool canUploadReadings;
  final bool canViewDeclinedUploads;

  @override
  Widget build(BuildContext context) {
    final businessType =
        context.watch<BusinessProvider>().currentBusiness?.businessType.toLowerCase() ??
            'gas';
    final isPetroleumStation = businessType.contains('petroleum') ||
        businessType.contains('petrol') ||
        businessType.contains('filling');
    final pumpRoute =
        isPetroleumStation ? Routes.petroleumPump : Routes.gasPump;
    final pumpUploadRoute =
        isPetroleumStation ? Routes.petroleumPumpUpload : Routes.gasPumpUpload;

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
                    child: const Text('No'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Yes'),
                  ),
                ],
              ),
            ) ??
            false;
        if (shouldExit) await SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pump Operator'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              isPetroleumStation ? 'Petroleum Pump Sales' : 'Gas Pump Sales',
              style: AppTextStyles.heading5,
            ),
            const SizedBox(height: 8),
            Text(
              'This account is limited to dispensing and recording fuel sales only.',
              style: AppTextStyles.body2Secondary,
            ),
            const SizedBox(height: 16),
            _PumpOperatorActionCard(
              title: 'Pump Sale',
              subtitle: 'Record individual fuel sales by amount or volume',
              icon: Icons.local_gas_station_rounded,
              onTap: () => Navigator.pushNamed(context, pumpRoute),
            ),
            if (canUploadReadings) ...[
              const SizedBox(height: 12),
              _PumpOperatorActionCard(
                title: 'Pump Upload',
                subtitle: 'Submit end-of-shift readings for manager review',
                icon: Icons.cloud_upload_rounded,
                onTap: () => Navigator.pushNamed(context, pumpUploadRoute),
              ),
            ],
            if (isPetroleumStation && canViewDeclinedUploads) ...[
              const SizedBox(height: 12),
              _PumpOperatorActionCard(
                title: 'Upload Status',
                subtitle: 'Correct rejected uploads and reregister them',
                icon: Icons.assignment_return_rounded,
                onTap: () => Navigator.pushNamed(
                  context,
                  Routes.petroleumDeclinedPumpUploads,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StationSalesRepDashboard extends StatelessWidget {
  const _StationSalesRepDashboard();

  @override
  Widget build(BuildContext context) {
    final businessType =
        context.watch<BusinessProvider>().currentBusiness?.businessType.toLowerCase() ??
            'gas';
    final isOwner = context.watch<AuthProvider>().currentUser?.isOwner == true;
    final isPetroleumStation = businessType.contains('petroleum') ||
        businessType.contains('petrol') ||
        businessType.contains('filling');
    final historyRoute = isPetroleumStation
        ? Routes.petroleumSalesHistory
        : Routes.gasSalesHistory;

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
                    child: const Text('No'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Yes'),
                  ),
                ],
              ),
            ) ??
            false;
        if (shouldExit) await SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mini Mart Sales'),
          actions: [
            IconButton(
              tooltip: 'Sales History',
              icon: const Icon(Icons.history_rounded),
              onPressed: () => Navigator.pushNamed(context, historyRoute),
            ),
          ],
        ),
        floatingActionButton: isOwner
            ? FloatingActionButton.extended(
                onPressed: () => Navigator.pushNamed(context, Routes.procurement),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Procurement'),
              )
            : null,
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Station Mini Mart',
              style: AppTextStyles.heading5,
            ),
            const SizedBox(height: 8),
            Text(
              'Sell cylinders, oils, accessories, bakery or retail items without accessing pump upload tools.',
              style: AppTextStyles.body2Secondary,
            ),
            const SizedBox(height: 16),
            _StationSalesRepActionCard(
              title: 'Mini Mart Sale',
              subtitle: 'Open POS for shop and retail products',
              icon: Icons.point_of_sale_rounded,
              color: Colors.green,
              onTap: () => Navigator.pushNamed(context, Routes.retailPos),
            ),
            _StationSalesRepActionCard(
              title: 'Mini Mart Inventory',
              subtitle: 'Check available retail stock',
              icon: Icons.inventory_2_rounded,
              color: Colors.blue,
              onTap: () => Navigator.pushNamed(context, Routes.inventory),
            ),
            _StationSalesRepActionCard(
              title: 'Sales History',
              subtitle: 'Review recorded station sales',
              icon: Icons.receipt_long_rounded,
              color: Colors.orange,
              onTap: () => Navigator.pushNamed(context, historyRoute),
            ),
          ],
        ),
      ),
    );
  }
}

class _PumpOperatorActionCard extends StatelessWidget {
  const _PumpOperatorActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: AppTextStyles.body1),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _StationSalesRepActionCard extends StatelessWidget {
  const _StationSalesRepActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: AppTextStyles.body1),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
