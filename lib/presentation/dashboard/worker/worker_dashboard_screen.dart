import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/routes.dart';
import '../../../core/theme/text_styles.dart';

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
      case 'gas':
        print('[WorkerDashboard] Showing Gas Dashboard');
        dashboard = const GasDashboardScreen();
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

