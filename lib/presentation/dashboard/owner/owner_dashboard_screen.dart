import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/routes.dart';
import '../../../core/constants/business_types.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/settings_provider.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/drink_provider.dart';
import '../../../providers/workers_provider.dart';
import '../../../providers/customer_provider.dart';
import '../../../providers/analytics_provider.dart';
import '../../../providers/agri_provider.dart';
import '../../../providers/auto_provider.dart';
import '../../../providers/gym_provider.dart';
import '../../../providers/hotel_provider.dart';
import '../../../providers/pharmacy_provider.dart';
import '../../../providers/retail_provider.dart';
import 'package:business_manager/presentation/industry_specific/salon/providers/salon_provider.dart';
import '../../industry_specific/realestate/providers/real_estate_provider.dart';
import '../../../services/analytics_service.dart';
import '../../../data/models/business_model.dart';
import '../../../data/repositories/analytics_repository_impl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/date_range_selector.dart';
import '../../../widgets/business_switcher.dart';
// App header is inlined via _buildUserHeader; no import required

// Industry Dashboard Imports
import '../../industry_specific/drink/screens/drink_dashboard_screen.dart';
import '../../industry_specific/restaurant/screens/restaurant_owner_dashboard.dart';
import '../../industry_specific/hotel/screens/hotel_dashboard_screen.dart';
import '../../industry_specific/agri/screens/agri_dashboard_screen.dart';
import '../../industry_specific/salon/screens/salon_dashboard_screen.dart';
import '../../industry_specific/barber_shop/screens/barber_shop_dashboard_screen.dart';
import '../../industry_specific/wholesale/screens/warehouse_dashboard_screen.dart';
import '../../industry_specific/gym/screens/gym_dashboard_screen.dart';
import '../../industry_specific/auto/screens/auto_dashboard_screen.dart';
import '../../industry_specific/realestate/screens/realestate_dashboard_screen.dart'
    as re;
import '../../industry_specific/pharmacy/screens/pharmacy_dashboard.dart';
import '../../industry_specific/retail/screens/retail_dashboard.dart';
import '../../industry_specific/gas/screens/gas_dashboard_screen.dart';
import '../../industry_specific/apartment/screens/apartment_dashboard_screen.dart';
import '../../reports/screens/reports_dashboard_screen.dart';
import '../../settings/screens/profile_screen.dart';
import 'package:business_manager/core/utils/formatters.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  int _selectedTabIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBusinessData();
    });
  }

  void _initializeBusinessData() {
    final authProvider = context.read<AuthProvider>();
    final businessProvider = context.read<BusinessProvider>();

    if (authProvider.currentUser != null) {
      final userId = authProvider.currentUser!.id;
      final preferredBusinessId = authProvider.currentUser?.preferredBusinessId;

      print('[OwnerDashboard] Initializing business data');
      print('[OwnerDashboard] User ID: $userId');
      print('[OwnerDashboard] Preferred Business ID: $preferredBusinessId');

      // Load user's businesses immediately (include businessIds from user doc when available)
      businessProvider.loadUserBusinesses(
        userId,
        preferredBusinessId: preferredBusinessId,
        userBusinessIds: authProvider.currentUser?.businessIds,
      );
    } else {
      print('[OwnerDashboard] No current user found');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();

    return WillPopScope(
        onWillPop: () async {
          // Prevent navigating back to login; confirm exit instead
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

          if (shouldExit) {
            // Exit the app instead of popping to login
            await SystemNavigator.pop();
          }
          return false;
        },
        child: Scaffold(
          backgroundColor: isDark ? Colors.grey[900] : AppColors.background,
          extendBody: true,
          body: SafeArea(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) =>
                  setState(() => _selectedTabIndex = index),
              children: [
                _HomeTab(onOpenWorkTab: () {
                  _pageController.animateToPage(2,
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeInOutCubic);
                }),
                _buildReportsTab(
                    authProvider.isAdminUser || authProvider.isOwnerUser),
                const _MenuTab(),
                const _ProfileTab(),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNavBar(context),
        ));
  }

  Widget _buildBottomNavBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navigationItems = [
      _BottomNavItem(icon: Icons.home_rounded, label: 'Home', index: 0),
      _BottomNavItem(icon: Icons.analytics_rounded, label: 'Reports', index: 1),
      _BottomNavItem(icon: Icons.apps_rounded, label: 'Work', index: 2),
      _BottomNavItem(icon: Icons.person_rounded, label: 'Profile', index: 3),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 24),
      color: Colors.transparent,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: navigationItems
                .map((item) => Expanded(child: _buildNavBarItem(item, isDark)))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBarItem(_BottomNavItem item, bool isDark) {
    final isSelected = item.index == _selectedTabIndex;
    final activeColor = AppColors.primary;
    final inactiveColor = isDark ? Colors.grey[500] : Colors.grey[400];

    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          item.index,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? activeColor.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              item.icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 20,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: AppTextStyles.caption.copyWith(
              color: isSelected ? activeColor : inactiveColor,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 10,
            ),
            child: Text(item.label),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsTab(bool isAdmin) {
    return const _ReportsTab();
  }
}

// ============================================================================
// HOME TAB
// ============================================================================

class _HomeTab extends StatefulWidget {
  final VoidCallback? onOpenWorkTab;
  const _HomeTab({this.onOpenWorkTab});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  late TextEditingController _searchController;
  final List<_QuickActionItem> _allItems = _getQuickActionItems();
  late List<_QuickActionItem> _filteredItems;

  // Saved provider references (for safe use in async callbacks)
  late WorkersProvider _workersProvider;
  late CustomerProvider _customerProvider;

  // Sales metrics state
  double _todaySales = 0.0;
  int _todayTransactions = 0;
  double _todayRevenue = 0.0;
  bool _loadingSalesMetrics = true;

  // Counts (customers & workers)
  int _customersCount = 0;
  int _workersCount = 0;
  bool _loadingCounts = true;

  // Date range state
  late DateTimeRange _selectedDateRange;
  String? _lastBusinessId;
  bool _isLoadingMetrics = false; // Prevent simultaneous loads
  
  // Debounce timer for sales metrics loading
  Timer? _metricsDebounceTimer;
  static const Duration _metricsDebounceInterval = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredItems = _allItems;
    _searchController.addListener(_filterItems);

    // Save references to providers for safe use in async callbacks
    _workersProvider = context.read<WorkersProvider>();
    _customerProvider = context.read<CustomerProvider>();

    // Initialize date range to today
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: now.add(const Duration(days: 1)),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSalesMetrics();
    });
    // Capture current business id to detect changes later
    final bp = context.read<BusinessProvider>();
    _lastBusinessId = bp.currentBusiness?.id;
  }

  @override
  void dispose() {
    _metricsDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = query.isEmpty
          ? _allItems
          : _allItems
              .where((item) =>
                  item.title.toLowerCase().contains(query) ||
                  item.subtitle.toLowerCase().contains(query))
              .toList();
    });
  }

  /// Debounced sales metrics reload
  void _debouncedLoadSalesMetrics() {
    _metricsDebounceTimer?.cancel();
    _metricsDebounceTimer = Timer(_metricsDebounceInterval, () {
      if (mounted) {
        _loadSalesMetrics();
      }
    });
  }

  Future<void> _loadSalesMetrics() async {
    // 🔥 OPTIMIZATION: Prevent simultaneous metric loads
    if (_isLoadingMetrics) {
      print('[Dashboard] Metrics load already in progress, skipping');
      return;
    }

    try {
      _isLoadingMetrics = true;
      final businessId = context.read<BusinessProvider>().currentBusiness?.id;

      if (businessId == null) {
        print('[Dashboard] No business ID found');
        return;
      }

      final repo = AnalyticsRepositoryImpl(
        firestore: FirebaseFirestore.instance,
      );

      // Use selected date range
      final analytics = await repo.getSalesAnalytics(
        businessId,
        startDate: _selectedDateRange.start,
        endDate: _selectedDateRange.end,
      );

      if (mounted) {
        setState(() {
          _todaySales = (analytics?['totalSales'] as num?)?.toDouble() ?? 0.0;
          _todayTransactions =
              (analytics?['totalTransactions'] as num?)?.toInt() ?? 0;
          _todayRevenue = _todaySales;
          _loadingSalesMetrics = false;
          // Keep counts loading until we fetch them below
          _loadingCounts = true;
          print(
              '[Dashboard] Sales loaded for range ${_selectedDateRange.start} - ${_selectedDateRange.end}: ₦$_todaySales, Transactions: $_todayTransactions');
        });
      }

      // Fetch customers and workers counts (use providers that already cache/refresh per business)
      // 🔥 OPTIMIZATION: Only call setBusinessId if business actually changed
      try {
        await _workersProvider.setBusinessId(businessId);
        _customerProvider.setBusinessId(businessId);
        await _customerProvider.loadCustomers();

        if (mounted) {
          setState(() {
            _workersCount = _workersProvider.workers.length;
            _customersCount = _customerProvider.customers.length;
            _loadingCounts = false;
          });
        }
      } catch (e) {
        print('[Dashboard] Error loading counts: $e');
        if (mounted) {
          setState(() {
            _loadingCounts = false;
          });
        }
      }
    } catch (e) {
      print('[Dashboard] Error loading sales metrics: $e');
      if (mounted) {
        setState(() {
          _loadingSalesMetrics = false;
        });
      }
    } finally {
      _isLoadingMetrics = false;
    }
  }

  Future<void> _handleRefresh() async {
    try {
      final auth = context.read<AuthProvider>();
      final businessProv = context.read<BusinessProvider>();

      // Refresh auth provider first so we have latest user document
      try {
        await auth.refresh();
      } catch (_) {}

      final user = auth.currentUser;
      if (user == null) return;

      final userId = user.id;

      // Reload user's businesses from backend (or cache)
      await businessProv.loadUserBusinesses(userId,
          preferredBusinessId: user.preferredBusinessId,
          userBusinessIds: user.businessIds);

      // If no current business was selected but user has businessId on profile, try to load that
      if (businessProv.currentBusiness == null && user.businessId.isNotEmpty) {
        await businessProv.loadBusinessById(user.businessId);
      }

      final businessId = businessProv.currentBusiness?.id ?? user.businessId;

      if (businessId.isNotEmpty) {
        // 🔥 OPTIMIZATION: Only update providers if business actually changed
        final businessIdChanged = _lastBusinessId != businessId;
        
        if (businessIdChanged) {
          print('[Dashboard] Business changed from $_lastBusinessId to $businessId, updating providers');
          _lastBusinessId = businessId;

          // Update domain-specific providers ONLY on business change
          final setters = [
            () => Future.sync(() => context.read<DrinkProvider>().setBusinessId(businessId)),
            () => Future.sync(() => context.read<AgriProvider>().setBusinessId(businessId)),
            () => Future.sync(() => context.read<AutoProvider>().setBusinessId(businessId)),
            () => Future.sync(() => context.read<GymProvider>().setBusinessId(businessId)),
            () => Future.sync(() => context.read<HotelProvider>().setBusinessId(businessId)),
            () => Future.sync(() => context.read<PharmacyProvider>().setBusinessId(businessId)),
            () => Future.sync(() => context.read<RetailProvider>().setBusinessId(businessId)),
            () => Future.sync(() => context.read<SalonProvider>().setBusinessId(businessId)),
            () => context.read<RealEstateProvider>().setBusinessId(businessId),
            () => Future.sync(() => context.read<CustomerProvider>().setBusinessId(businessId)),
            () => Future.sync(() => context.read<AnalyticsProvider>().setBusinessId(businessId)),
          ];

          for (final s in setters) {
            try {
              s();
            } catch (_) {}
          }
        } else {
          print('[Dashboard] Business unchanged ($businessId), skipping provider updates');
        }

        // Some providers have refresh methods (these don't need business ID passed)
        try {
          await context.read<WorkersProvider>().refreshForBusiness(businessId);
        } catch (_) {}

        // Update analytics with current user & business
        try {
          final analytics = AnalyticsService();
          await analytics.setUserId(userId);
          await analytics.setUserProperties({'businessId': businessId});
        } catch (_) {}
      }

      // Ensure user's preferred business is persisted to their profile if we resolved one
      try {
        final resolved = businessProv.currentBusiness;
        if (resolved != null && resolved.id != user.preferredBusinessId) {
          await businessProv.setCurrentBusinessAndSave(userId, resolved);
        }
      } catch (_) {}

      // Reload UI-specific metrics after refresh
      if (mounted) {
        await _loadSalesMetrics();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Refresh failed: $e')));
      }
      print('[Dashboard] Refresh error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final businessProvider = context.watch<BusinessProvider>();
    final user = authProvider.currentUser;
    final business = businessProvider.currentBusiness;
    final userBusinesses = businessProvider.userBusinesses;

    // 🔥 OPTIMIZATION: If business selection changed, debounce metrics reload
    // This prevents excessive queries when switching businesses quickly
    final currentBusinessId = business?.id;
    if (_lastBusinessId != currentBusinessId && currentBusinessId != null) {
      print('[Dashboard] Business changed to $currentBusinessId, scheduling metrics reload');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _debouncedLoadSalesMetrics();
      });
    }

    return RefreshIndicator(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with User Info
              const SizedBox(height: 4),
              _buildUserHeader(user, isDark),
              const SizedBox(height: 24),

              // Search Bar
              _buildSearchBar(isDark)
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 100.ms)
                  .slideY(begin: -0.1),
              const SizedBox(height: 24),

              // Business Info Card or Switcher
              if (business != null) ...[
                _buildBusinessCard(business, isDark)
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 200.ms)
                    .scale(begin: const Offset(0.5, 0.5)),
                const SizedBox(height: 20),

                // Date Range Selector
                DateRangeSelector(
                  onRangeChanged: (newRange) {
                    setState(() {
                      _selectedDateRange = newRange;
                      _loadingSalesMetrics = true;
                    });
                    // 🔥 OPTIMIZATION: Debounce sales metrics reload on date change
                    _debouncedLoadSalesMetrics();
                  },
                  initialRange: _selectedDateRange, backgroundColor: const Color.fromARGB(255, 31, 54, 104),
                ).animate().fadeIn(duration: 500.ms, delay: 250.ms),
                const SizedBox(height: 20),

                // Quick Metrics
                _buildQuickMetrics(
                  isDark,
                  sales: _todaySales,
                  transactions: _todayTransactions,
                  revenue: _todayRevenue,
                  isLoading: _loadingSalesMetrics,
                  customersCount: _customersCount,
                  workersCount: _workersCount,
                  isLoadingCounts: _loadingCounts,
                )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 300.ms)
                    .slideY(begin: 0.1),
                const SizedBox(height: 24),
              ] else if (userBusinesses.isNotEmpty) ...[
                // Show business switcher if user has businesses but none selected
                _buildBusinessSwitcher(userBusinesses, isDark)
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 200.ms),
                const SizedBox(height: 24),
              ] else ...[
                // Show no business state
                _buildNoBusinessState(isDark)
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 200.ms),
                const SizedBox(height: 24),
              ],

              // Quick Actions
              if (business != null && _filteredItems.isNotEmpty) ...[
                Text(
                  'Quick Actions',
                  style: AppTextStyles.heading5.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
                const SizedBox(height: 12),
                
                // Build quick actions, allow dynamic insertion for Gas businesses
                Builder(builder: (ctx) {
                  final bp = ctx.watch<BusinessProvider>();
                  final current = bp.currentBusiness;
                  final actions = List<_QuickActionItem>.from(_filteredItems);

                  // Add industry-specific quick actions based on business type
                  if (current != null) {
                    final businessType = current.businessType.toLowerCase();

                    if (businessType.contains('gas')) {
                      // Prepend Pump Sale action for Gas businesses
                      actions.insert(
                        0,
                        _QuickActionItem(
                          title: 'Pump Sale',
                          subtitle: 'Quick fuel sale',
                          icon: Icons.local_gas_station,
                          color: Colors.amber,
                          route: Routes.gasPump,
                        ),
                      );
                    } else if (businessType.contains('pharmacy')) {
                      // Pharmacy specific actions
                      actions.insert(
                        0,
                        _QuickActionItem(
                          title: 'New Prescription',
                          subtitle: 'Add patient prescription',
                          icon: Icons.medical_services,
                          color: AppColors.pharmacy,
                          route: Routes.pharmacyAddPrescription,
                        ),
                      );
                      actions.insert(
                        1,
                        _QuickActionItem(
                          title: 'Drug Inventory',
                          subtitle: 'Manage medications',
                          icon: Icons.inventory_2,
                          color: AppColors.pharmacy,
                          route: Routes.pharmacyDrugInventory,
                        ),
                      );
                    } else if (businessType.contains('retail')) {
                      // Retail specific actions
                      actions.insert(
                        0,
                        _QuickActionItem(
                          title: 'Quick Sale',
                          subtitle: 'Fast checkout',
                          icon: Icons.point_of_sale,
                          color: AppColors.retail,
                          route: Routes.retailPos,
                        ),
                      );
                      actions.insert(
                        1,
                        _QuickActionItem(
                          title: 'Product Catalog',
                          subtitle: 'Manage products',
                          icon: Icons.inventory,
                          color: AppColors.retail,
                          route: Routes.retailCatalog,
                        ),
                      );
                    } else if (businessType.contains('wholesale')) {
                      // Wholesale specific actions
                      actions.insert(
                        0,
                        _QuickActionItem(
                          title: 'Purchase Order',
                          subtitle: 'Create bulk order',
                          icon: Icons.shopping_cart,
                          color: AppColors.primary,
                          route: Routes.wholesalePurchaseOrders,
                        ),
                      );
                      actions.insert(
                        1,
                        _QuickActionItem(
                          title: 'Stock Transfer',
                          subtitle: 'Move inventory',
                          icon: Icons.swap_horiz,
                          color: AppColors.primary,
                          route: Routes.wholesaleTransfers,
                        ),
                      );
                    } else if (businessType.contains('agri') || businessType.contains('agriculture')) {
                      // Agriculture specific actions
                      actions.insert(
                        0,
                        _QuickActionItem(
                          title: 'Add Livestock',
                          subtitle: 'Record new animal',
                          icon: Icons.pets,
                          color: AppColors.agri,
                          route: Routes.agriAddLivestock,
                        ),
                      );
                      actions.insert(
                        1,
                        _QuickActionItem(
                          title: 'Farm Overview',
                          subtitle: 'View all farms',
                          icon: Icons.agriculture,
                          color: AppColors.agri,
                          route: Routes.agriFarms,
                        ),
                      );
                    } else if (businessType.contains('auto')) {
                      // Auto service specific actions
                      actions.insert(
                        0,
                        _QuickActionItem(
                          title: 'New Service',
                          subtitle: 'Create service order',
                          icon: Icons.build,
                          color: AppColors.auto,
                          route: Routes.autoCreateServiceOrder,
                        ),
                      );
                      actions.insert(
                        1,
                        _QuickActionItem(
                          title: 'Parts Inventory',
                          subtitle: 'Manage auto parts',
                          icon: Icons.settings,
                          color: AppColors.auto,
                          route: Routes.autoPartsInventory,
                        ),
                      );
                    } else if (businessType.contains('salon')) {
                      // Salon specific actions
                      actions.insert(
                        0,
                        _QuickActionItem(
                          title: 'Book Appointment',
                          subtitle: 'Schedule service',
                          icon: Icons.calendar_today,
                          color: AppColors.salon,
                          route: Routes.salonBookAppointment,
                        ),
                      );
                      actions.insert(
                        1,
                        _QuickActionItem(
                          title: 'Services',
                          subtitle: 'Manage offerings',
                          icon: Icons.spa,
                          color: AppColors.salon,
                          route: Routes.salonServices,
                        ),
                      );
                    } else if (businessType.contains('barber')) {
                      // Barbershop specific actions
                      actions.insert(
                        0,
                        _QuickActionItem(
                          title: 'New Appointment',
                          subtitle: 'Book haircut',
                          icon: Icons.content_cut,
                          color: AppColors.salon,
                          route: Routes.barberShopAppointments,
                        ),
                      );
                      actions.insert(
                        1,
                        _QuickActionItem(
                          title: 'Services',
                          subtitle: 'Manage styles',
                          icon: Icons.style,
                          color: AppColors.salon,
                          route: Routes.barberShopServices,
                        ),
                      );
                    } else if (businessType.contains('hotel')) {
                      // Hotel specific actions
                      actions.insert(
                        0,
                        _QuickActionItem(
                          title: 'Check-in Guest',
                          subtitle: 'Room assignment',
                          icon: Icons.hotel,
                          color: AppColors.hotel,
                          route: Routes.hotelCheckIn,
                        ),
                      );
                      actions.insert(
                        1,
                        _QuickActionItem(
                          title: 'New Booking',
                          subtitle: 'Reserve room',
                          icon: Icons.calendar_month,
                          color: AppColors.hotel,
                          route: Routes.hotelCreateBooking,
                        ),
                      );
                    } else if (businessType.contains('restaurant')) {
                      // Restaurant specific actions
                      actions.insert(
                        0,
                        _QuickActionItem(
                          title: 'New Order',
                          subtitle: 'Take customer order',
                          icon: Icons.restaurant_menu,
                          color: AppColors.restaurant,
                          route: Routes.restaurantOrders,
                        ),
                      );
                      actions.insert(
                        1,
                        _QuickActionItem(
                          title: 'Table Management',
                          subtitle: 'Manage seating',
                          icon: Icons.table_restaurant,
                          color: AppColors.restaurant,
                          route: Routes.restaurantTables,
                        ),
                      );
                    } else if (businessType.contains('drink') || businessType.contains('bar')) {
                      // Bar/Drink specific actions
                      actions.insert(
                        0,
                        _QuickActionItem(
                          title: 'Bar Order',
                          subtitle: 'Quick drink sale',
                          icon: Icons.local_bar,
                          color: AppColors.drink,
                          route: Routes.drinkPos,
                        ),
                      );
                      actions.insert(
                        1,
                        _QuickActionItem(
                          title: 'Bottle Tracking',
                          subtitle: 'Monitor inventory',
                          icon: Icons.liquor,
                          color: AppColors.drink,
                          route: Routes.drinkBottleTracking,
                        ),
                      );
                    } else if (businessType.contains('real') && businessType.contains('estate')) {
                      // Real Estate specific actions
                      actions.insert(
                        0,
                        _QuickActionItem(
                          title: 'Add Property',
                          subtitle: 'List new property',
                          icon: Icons.add_home,
                          color: AppColors.realEstate,
                          route: Routes.realEstateAddProperty,
                        ),
                      );
                      actions.insert(
                        1,
                        _QuickActionItem(
                          title: 'Rent Collection',
                          subtitle: 'Collect payments',
                          icon: Icons.payments,
                          color: AppColors.realEstate,
                          route: Routes.realEstateRentCollection,
                        ),
                      );
                    } else if (businessType.contains('apartment')) {
                      // Apartment specific actions
                      actions.insert(
                        0,
                        _QuickActionItem(
                          title: 'New Booking',
                          subtitle: 'Reserve unit',
                          icon: Icons.home,
                          color: AppColors.realEstate,
                          route: Routes.ownerDashboard, // Navigate to main dashboard which will show apartment dashboard
                        ),
                      );
                      actions.insert(
                        1,
                        _QuickActionItem(
                          title: 'Unit Management',
                          subtitle: 'Manage properties',
                          icon: Icons.business,
                          color: AppColors.realEstate,
                          route: Routes.ownerDashboard, // Navigate to main dashboard which will show apartment dashboard
                        ),
                      );
                    } else if (businessType.contains('gym')) {
                      // Gym specific actions
                      actions.insert(
                        0,
                        _QuickActionItem(
                          title: 'New Member',
                          subtitle: 'Register client',
                          icon: Icons.person_add,
                          color: AppColors.primary,
                          route: Routes.gymMembers,
                        ),
                      );
                      actions.insert(
                        1,
                        _QuickActionItem(
                          title: 'Class Schedule',
                          subtitle: 'Manage sessions',
                          icon: Icons.schedule,
                          color: AppColors.primary,
                          route: Routes.gymClasses,
                        ),
                      );
                    }
                  }

                  return _buildQuickActionsGrid(isDark, actions)
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 450.ms);
                }),
              ],
            ],
          ),
        ));
  }

  Widget _buildBusinessSwitcher(List<BusinessModel> businesses, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select a Business',
          style: AppTextStyles.heading5.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...businesses.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  context.read<BusinessProvider>().setCurrentBusinessAndSave(
                        context.read<AuthProvider>().currentUser!.id,
                        b,
                      );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        BusinessTypes.getColor(b.businessType),
                        BusinessTypes.getColor(b.businessType)
                            .withAlpha((0.8 * 255).toInt()),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha((0.2 * 255).toInt()),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha((0.2 * 255).toInt()),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          BusinessTypes.getIcon(b.businessType),
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.name,
                              style: AppTextStyles.heading5.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              BusinessTypes.getName(b.businessType),
                              style: AppTextStyles.caption.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withAlpha((0.8 * 255).toInt()),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha((0.7 * 255).toInt()),
                      ),
                    ],
                  ),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildNoBusinessState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.business_center_rounded,
            size: 64,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No Business Selected',
            style: AppTextStyles.heading4.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create or select a business to get started',
            style: AppTextStyles.body2.copyWith(
              color: isDark ? Colors.grey[400] : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              Routes.businessDetails,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Create Business'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader(user, bool isDark) {
    // Prefer explicit user photo; if missing, fall back to business-level
    // profilePhotoUrl (settings) so updates from Settings are reflected.
    final settingsProvider = context.read<SettingsProvider>();
    final fallbackPhoto = settingsProvider.profilePhotoUrl;
    final resolvedPhoto = (user?.photoUrl != null && user!.photoUrl!.isNotEmpty)
        ? user.photoUrl
        : fallbackPhoto;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary,
              width: 2,
            ),
          ),
          child: ProfileAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withAlpha((0.15 * 255).toInt()),
            photoUrl: resolvedPhoto,
            initials: user?.initials ?? 'U',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome back 👋',
                style: AppTextStyles.body2Secondary.copyWith(
                  color: isDark ? Colors.grey[400] : AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                user?.fullName ?? 'User',
                style: AppTextStyles.heading4.copyWith(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // Current business display with quick switch dropdown
              Builder(builder: (ctx) {
                final bp = ctx.watch<BusinessProvider>();
                final current = bp.currentBusiness;
                return Row(
                  children: [
                    Icon(Icons.storefront_rounded,
                        size: 14, color: AppColors.primary.withOpacity(0.8)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        current?.name ?? 'No business selected',
                        style: AppTextStyles.body2.copyWith(
                          color: isDark
                              ? Colors.grey[300]
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const BusinessSwitcher(),
                  ],
                );
              }),
            ],
          ),
        ),
        // Add Business quick action button (owner convenience)
        IconButton(
          tooltip: 'Add Business',
          onPressed: () async {
            final chosen = await _showBusinessTypeChooser(context);
            if (chosen != null) {
              Navigator.pushNamed(
                context,
                Routes.businessDetails,
                arguments: {'businessType': chosen},
              );
            }
          },
          icon: const Icon(Icons.add_business_rounded, color: AppColors.primary),
        ),

        // Notifications (moved to top-right)
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => Navigator.pushNamed(context, Routes.notifications),
          icon: const Icon(
            Icons.notifications_rounded,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Future<String?> _showBusinessTypeChooser(BuildContext ctx) async {
    return showDialog<String>(
      context: ctx,
      builder: (context) => SimpleDialog(
        title: const Text('Select Business Type'),
        children: BusinessTypes.all.map((t) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, t.id),
            child: Row(
              children: [
                Icon(t.icon, color: t.color),
                const SizedBox(width: 12),
                Expanded(child: Text(t.name)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withAlpha((0.15 * 255).toInt()),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha((0.05 * 255).toInt()),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: AppTextStyles.body1.copyWith(
          color: isDark ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search actions, features...',
          hintStyle: AppTextStyles.body2.copyWith(
            color: isDark ? Colors.grey[500] : AppColors.textTertiary,
            fontStyle: FontStyle.italic,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.primary.withAlpha((0.5 * 255).toInt()),
            size: 22,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? GestureDetector(
                  onTap: () => _searchController.clear(),
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary.withAlpha((0.5 * 255).toInt()),
                    size: 20,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          filled: false,
        ),
        cursorColor: AppColors.primary,
      ),
    );
  }

  Widget _buildBusinessCard(BusinessModel business, bool isDark) {
    final baseColor = BusinessTypes.getColor(business.businessType);
    final secondary = baseColor.withAlpha((0.85 * 255).toInt());
    final logoUrl = business.photoUrl ?? business.logoUrl;

    return GestureDetector(
      onTap: () {
        widget.onOpenWorkTab?.call();
      },
      onLongPress: () async {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) {
            return DraggableScrollableSheet(
              expand: false,
              builder: (_, controller) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    controller: controller,
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 6),
                        Text('Switch Business', style: AppTextStyles.heading5),
                        SizedBox(height: 12),
                        BusinessSwitcher(),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              baseColor.withAlpha((0.95 * 255).toInt()),
              secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: baseColor.withAlpha((0.25 * 255).toInt()),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Row: Logo + Business Info + Action Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo/Avatar
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.15 * 255).toInt()),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withAlpha((0.2 * 255).toInt()),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: logoUrl != null && logoUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: logoUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                                color: Colors.white.withAlpha((0.06 * 255).toInt())),
                            errorWidget: (context, url, error) => Center(
                              child: Text(
                                business.name.isNotEmpty
                                    ? business.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              business.name.isNotEmpty
                                  ? business.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                // Business Info Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Business Name + Tier Badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              business.name,
                              style: AppTextStyles.heading4.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              business.subscriptionTier.toUpperCase(),
                              style: AppTextStyles.caption.copyWith(
                                color: baseColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Business Type
                      Row(
                        children: [
                          Icon(
                            Icons.storefront,
                            size: 13,
                            color: Colors.white.withAlpha((0.9 * 255).toInt()),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              BusinessTypes.getName(business.businessType),
                              style: AppTextStyles.body2.copyWith(
                                color: Colors.white.withAlpha((0.95 * 255).toInt()),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      // Subscription end date badge (if available)
                      if (business.subscriptionEndDate != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha((0.15 * 255).toInt()),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withAlpha((0.25 * 255).toInt()),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 11,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${(business.subscriptionEndDate!.difference(DateTime.now()).inDays).clamp(0, 999)}d left',
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Action Button (strategically placed)
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    onPressed: () => _navigateToIndustryDashboard(business),
                    icon: const Icon(Icons.dashboard, color: Colors.white),
                    tooltip: 'Open Industry Dashboard',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha((0.06 * 255).toInt()),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Location & Contact Row (Full Width)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.08 * 255).toInt()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withAlpha((0.12 * 255).toInt()),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Address Line (Full Width)
                  if (business.city != null && business.city!.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: Colors.white.withAlpha((0.9 * 255).toInt()),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            business.city ?? 'N/A',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white.withAlpha((0.95 * 255).toInt()),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (business.city != null &&
                      business.city!.isNotEmpty &&
                      business.phone != null &&
                      business.phone!.isNotEmpty)
                    const SizedBox(height: 6),
                  // Phone Line (Full Width)
                  if (business.phone != null && business.phone!.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.phone,
                          size: 13,
                          color: Colors.white.withAlpha((0.9 * 255).toInt()),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            business.phone!,
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white.withAlpha((0.95 * 255).toInt()),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _smallStatChip(
                      '${business.totalProducts ?? 0}', 'Products'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _smallStatChip(
                      '${business.totalCustomers ?? 0}', 'Customers'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _smallStatChip(
                      _loadingCounts ? '...' : '${_workersCount > 0 ? _workersCount : (business.totalWorkers ?? 0)}',
                      'Staff'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Action Buttons Row (Bottom)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>   widget.onOpenWorkTab?.call(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: baseColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                         Icon(Icons.work, size: 18),
                        SizedBox(width: 8),
                        Text('Open'),
                      ],
                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    onPressed: () {
                      widget.onOpenWorkTab?.call();
                    },
                    icon: const Icon(Icons.work, color: Colors.white),
                    tooltip: 'Open',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha((0.15 * 255).toInt()),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, Routes.reports),
                    icon: const Icon(Icons.analytics, color: Colors.white),
                    tooltip: 'Analytics',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha((0.15 * 255).toInt()),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (business.website != null &&
                    business.website!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      onPressed: () async {
                        final uri = Uri.tryParse(business.website!);
                        if (uri != null) {
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to open website'),
                                ),
                              );
                            }
                          }
                        }
                      },
                      icon: const Icon(Icons.public, color: Colors.white),
                      tooltip: 'Visit Website',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withAlpha((0.15 * 255).toInt()),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMetrics(
    bool isDark, {
    double sales = 0.0,
    int transactions = 0,
    double revenue = 0.0,
    bool isLoading = false,
    int customersCount = 0,
    int workersCount = 0,
    bool isLoadingCounts = false,
  }) {
    final averageTicket =
        transactions > 0 ? revenue / transactions : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withAlpha((0.5 * 255).toInt()),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).toInt()),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 560;
          final cardWidth = isCompact
              ? (constraints.maxWidth - 12) / 2
              : (constraints.maxWidth - 24) / 3;

          final cards = [
            _buildMetricTile(
              'Sales',
              isLoading ? '...' : formatCurrency(sales),
              Icons.shopping_bag_rounded,
              AppColors.primary,
              isDark,
              route: Routes.salesHistory,
            ),
            _buildMetricTile(
              'Orders',
              isLoading ? '...' : transactions.toString(),
              Icons.receipt_rounded,
              Colors.green,
              isDark,
              route: Routes.salesReport,
            ),
            _buildMetricTile(
              'Customers',
              isLoadingCounts ? '...' : customersCount.toString(),
              Icons.people_rounded,
              Colors.orange,
              isDark,
              route: Routes.customers,
            ),
            _buildMetricTile(
              'Workers',
              isLoadingCounts ? '...' : workersCount.toString(),
              Icons.badge_rounded,
              Colors.purple,
              isDark,
              route: Routes.workers,
            ),
            _buildMetricTile(
              'Avg Ticket',
              isLoading ? '...' : formatCurrency(averageTicket),
              Icons.query_stats_rounded,
              Colors.blue,
              isDark,
              route: Routes.advancedAnalytics,
            ),
          ];

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards
                .map((card) => SizedBox(width: cardWidth, child: card))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildMetricTile(
      String label, String value, IconData icon, Color color, bool isDark,
      {String? route}) {
    return InkWell(
      onTap: route != null ? () => Navigator.pushNamed(context, route) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: color.withAlpha((0.08 * 255).toInt()),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withAlpha((0.18 * 255).toInt()),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha((0.14 * 255).toInt()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: AppTextStyles.subtitle2.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: isDark ? Colors.grey[400] : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallStatChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.12 * 255).toInt()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha((0.06 * 255).toInt())),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: AppTextStyles.caption
                  .copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: Colors.white.withAlpha((0.9 * 255).toInt()))),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(bool isDark, [List<_QuickActionItem>? actions]) {
    final list = actions ?? _filteredItems;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        return _buildActionCard(list[index], index, isDark);
      },
    );
  }

  Widget _buildActionCard(_QuickActionItem item, int index, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, item.route),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, item.route),
            borderRadius: BorderRadius.circular(16),
            splashColor: item.color.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.icon,
                      color: item.color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle2.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: isDark ? Colors.grey[500] : AppColors.textSecondary,
                      fontSize: 10,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .scale(
          duration: 400.ms,
          delay: Duration(milliseconds: 200 + (index * 30)),
        )
        .fadeIn(duration: 500.ms);
  }

  void _navigateToIndustryDashboard(BusinessModel business) {
    final businessType = business.businessType.toLowerCase();
    Widget? screen;

    switch (businessType) {
      case 'pharmacy':
        screen = const PharmacyDashboard();
        break;
      case 'retail':
        screen = const RetailDashboard();
        break;
      case 'restaurant':
        screen = const RestaurantDashboardScreen();
        break;
      case 'hotel':
        screen = const HotelDashboardScreen();
        break;
      case 'salon':
        screen = const SalonDashboardScreen();
        break;
      case 'gym':
        screen = const GymDashboardScreen();
        break;
      case 'auto':
      case 'auto repair':
      case 'autorepair':
        screen = const AutoDashboardScreen();
        break;
      case 'agriculture':
      case 'agri':
        screen = const AgriDashboardScreen();
        break;
      case 'drink':
      case 'bar':
        screen = const DrinkDashboardScreen();
        break;
      case 'gas':
        screen = const GasDashboardScreen();
        break;
      case 'apartment':
        screen = const ApartmentDashboardScreen();
        break;
      case 'real estate':
      case 'realestate':
        screen = const re.RealestateDashboardScreen();
        break;
    }

    if (screen != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => screen!),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Industry dashboard not yet available'),
        ),
      );
    }
  }

  static List<_QuickActionItem> _getQuickActionItems() {
    return [
      _QuickActionItem(
        title: 'New Sale',
        subtitle: 'Create transaction',
        icon: Icons.point_of_sale_rounded,
        color: Colors.green,
        route: Routes.sales,
      ),
      _QuickActionItem(
        title: 'Inventory',
        subtitle: 'Manage products',
        icon: Icons.inventory_2_rounded,
        color: Colors.blue,
        route: Routes.inventory,
      ),
      _QuickActionItem(
        title: 'Low Stock',
        subtitle: 'View alerts',
        icon: Icons.warning_rounded,
        color: Colors.orange,
        route: Routes.lowStockProducts,
      ),
       _QuickActionItem(
        title: 'Procurement',
        subtitle: 'Manage inventory',
        icon: Icons.shopping_cart_rounded,
        color: Colors.teal,
        route: Routes.procurement,
      ),
       _QuickActionItem(
        title: 'Procurement History',
        subtitle: 'View procurement logs',
        icon: Icons.history_rounded,
        color: const Color.fromARGB(255, 0, 60, 150),
        route: Routes.procurementHistory,
      ),
       _QuickActionItem(
        title: 'Reports',
        subtitle: 'View analytics',
        icon: Icons.analytics_rounded,
        color: Colors.cyan,
        route: Routes.reports,
      ),
        _QuickActionItem(
        title: 'Expenses',
        subtitle: 'Document expenses',
        icon: Icons.shop_rounded,
        color: Colors.brown,
        route: Routes.expenseReport,
      ),
      _QuickActionItem(
        title: 'Advanced Analytics',
        subtitle: 'KPIs & trends',
        icon: Icons.trending_up_rounded,
        color: AppColors.primary,
        route: Routes.advancedAnalytics,
      ),
      _QuickActionItem(
        title: 'Customers',
        subtitle: 'View & manage',
        icon: Icons.people_rounded,
        color: Colors.purple,
        route: Routes.customers,
      ),
      _QuickActionItem(
        title: 'Workers',
        subtitle: 'Manage team',
        icon: Icons.people_alt_rounded,
        color: Colors.orange,
        route: Routes.workers,
      ),
      _QuickActionItem(
        title: 'Printer Settings',
        subtitle: 'Configure printers',
        icon: Icons.print_rounded,
        color: Colors.teal,
        route: Routes.printerSettings,
      ),
      _QuickActionItem(
        title: 'Settings',
        subtitle: 'Configure',
        icon: Icons.settings_rounded,
        color: Colors.grey,
        route: Routes.settings,
      ),
      _QuickActionItem(
        title: 'Profile',
        subtitle: 'Manage account',
        icon: Icons.account_circle_rounded,
        color: Colors.indigo,
        route: Routes.profile,
      ),
      _QuickActionItem(
        title: 'Notifications',
        subtitle: 'Check updates',
        icon: Icons.notifications_rounded,
        color: Colors.red,
        route: Routes.notifications,
      ),
      _QuickActionItem(
        title: 'Installation',
        subtitle: 'Request product installation',
        icon: Icons.build_rounded,
        color: Colors.deepPurple,
        route: Routes.productInstallation,
      ),
      _QuickActionItem(
        title: 'Upload Receipt',
        subtitle: 'Attach installation payment',
        icon: Icons.upload_file_rounded,
        color: Colors.teal,
        route: Routes.installationReceiptUpload,
      ),
      _QuickActionItem(
        title: 'My Installations',
        subtitle: 'View your requests',
        icon: Icons.history_rounded,
        color: Colors.indigo,
        route: Routes.installationRequestsMy,
      ),
    ];
  }
}

// ============================================================================
// REPORTS TAB
// ============================================================================

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    return const ReportsDashboardScreen();
  }
}

// ============================================================================
// WORK/MENU TAB
// ============================================================================

class _MenuTab extends StatefulWidget {
  const _MenuTab();

  @override
  State<_MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<_MenuTab> {
  @override
  void initState() {
    super.initState();
    // Reload businesses when this tab is first viewed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureBusinessLoaded();
    });
  }

  void _ensureBusinessLoaded() {
    final authProvider = context.read<AuthProvider>();
    final businessProvider = context.read<BusinessProvider>();

    print('[MenuTab] Ensuring business is loaded');
    print('[MenuTab] Current user: ${authProvider.currentUser?.id}');
    print(
        '[MenuTab] Current business: ${businessProvider.currentBusiness?.id}');

    // If no businesses loaded yet, load them
    if (businessProvider.userBusinesses.isEmpty &&
        authProvider.currentUser != null) {
      print('[MenuTab] No businesses loaded, loading now...');
      final userId = authProvider.currentUser!.id;
      final preferredBusinessId = authProvider.currentUser?.preferredBusinessId;
      businessProvider.loadUserBusinesses(
        userId,
        preferredBusinessId: preferredBusinessId,
      );
    } else if (businessProvider.currentBusiness == null &&
        businessProvider.userBusinesses.isNotEmpty) {
      print('[MenuTab] Has businesses but no current business, setting first');
      businessProvider
          .setCurrentBusiness(businessProvider.userBusinesses.first);
    } else if (businessProvider.currentBusiness != null &&
        businessProvider.userBusinesses.isEmpty) {
      // Edge case: currentBusiness is set but userBusinesses is empty
      // This means the business wasn't returned by the query (possibly inactive or wrong owner)
      print(
          '[MenuTab] WARNING: currentBusiness exists but userBusinesses is empty');
      print(
          '[MenuTab] This may indicate the business is inactive or has wrong owner ID');
      // Try to load the specific business by ID
      final businessId = businessProvider.currentBusiness!.id;
      print('[MenuTab] Attempting to load business by ID: $businessId');
      businessProvider.loadBusinessById(businessId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessProvider = context.watch<BusinessProvider>();
    final business = businessProvider.currentBusiness;

    print('[MenuTab] Building menu - Loading: ${businessProvider.isLoading}');
    print(
        '[MenuTab] Current Business: ${business?.id} (${business?.businessType})');
    print(
        '[MenuTab] User Businesses Count: ${businessProvider.userBusinesses.length}');
    print(
        '[MenuTab] Businesses: ${businessProvider.userBusinesses.map((b) => '${b.id}(${b.businessType})').join(', ')}');

    // Show loading state while businesses are being loaded
    if (businessProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (business == null) {
      print('[MenuTab] No business selected, showing no business screen');
      return _buildNoBusiness(businessProvider);
    }

    // Extract the primary business type (handle composite types like 'bar/drink')
    final businessTypeStr = business.businessType.toLowerCase();
    final primaryType = businessTypeStr.contains('/')
        ? businessTypeStr.split('/').last
        : businessTypeStr;

    print('[MenuTab] Business type: $businessTypeStr, Primary: $primaryType');

    Widget? screen;
    switch (primaryType) {
      case 'drink':
      case 'bar':
        print('[MenuTab] Loading DrinkDashboardScreen');
        screen = const DrinkDashboardScreen();
        break;
      case 'restaurant':
        print('[MenuTab] Loading RestaurantOwnerDashboard');
        screen = const RestaurantDashboardScreen();
        break;
      case 'hotel':
        print('[MenuTab] Loading HotelDashboardScreen');
        screen = const HotelDashboardScreen();
        break;
      case 'agri':
      case 'agriculture':
        print('[MenuTab] Loading AgriDashboardScreen');
        screen = const AgriDashboardScreen();
        break;
      case 'salon':
        print('[MenuTab] Loading SalonDashboardScreen');
        screen = const SalonDashboardScreen();
        break;
      case 'barber':
      case 'barbershop':
        print('[MenuTab] Loading BarberShopDashboardScreen');
        screen = const BarberShopDashboardScreen();
        break;
      case 'wholesale':
        print('[MenuTab] Loading WarehouseDashboardScreen');
        screen = const WarehouseDashboardScreen();
        break;
      case 'gym':
        print('[MenuTab] Loading GymDashboardScreen');
        screen = const GymDashboardScreen();
        break;
      case 'auto':
      case 'auto repair':
        print('[MenuTab] Loading AutoDashboardScreen');
        screen = const AutoDashboardScreen();
        break;
      case 'realestate':
      case 'real estate':
        print('[MenuTab] Loading RealestateDashboardScreen');
        screen = const re.RealestateDashboardScreen();
        break;
      case 'apartment':
        print('[MenuTab] Loading ApartmentDashboardScreen');
        screen = const ApartmentDashboardScreen();
        break;
      case 'pharmacy':
        print('[MenuTab] Loading PharmacyDashboard');
        screen = const PharmacyDashboard();
        break;
      case 'retail':
        print('[MenuTab] Loading RetailDashboard');
        screen = const RetailDashboard();
        break;
      case 'gas':
        print('[MenuTab] Loading GasDashboardScreen');
        screen = const GasDashboardScreen();
        break;

    }

    if (screen == null) {
      print('[MenuTab] Unknown business type: ${business.businessType}');
      return _buildNoBusiness(businessProvider);
    }

    print('[MenuTab] Rendering business dashboard');
    return screen;
  }

  Widget _buildNoBusiness(BusinessProvider businessProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business_center_rounded,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            businessProvider.errorMessage ?? 'No business found',
            style: AppTextStyles.heading5,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Create or select a business to get started',
            style: AppTextStyles.body2Secondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PROFILE TAB
// ============================================================================

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return const ProfileScreen();
  }
}

// ============================================================================
// MODELS & HELPERS
// ============================================================================

class _BottomNavItem {
  final IconData icon;
  final String label;
  final int index;

  _BottomNavItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}

class _QuickActionItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  _QuickActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}
