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
    final backgroundGradient = LinearGradient(
      colors: isDark
          ? const [
              Color(0xFF0E1628),
              Color(0xFF111E33),
              Color(0xFF0B1322),
            ]
          : const [
              Color(0xFFF5F8FF),
              Color(0xFFFDFEFF),
              Color(0xFFF3F6FB),
            ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

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
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: SafeArea(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: backgroundGradient),
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
          ),
          bottomNavigationBar: _buildBottomNavBar(context),
        ));
  }

  Widget _buildBottomNavBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 390;
    final horizontalPadding = screenWidth < 420 ? 12.0 : 24.0;
    final navigationItems = [
      _BottomNavItem(icon: Icons.home_rounded, label: 'Home', index: 0),
      _BottomNavItem(icon: Icons.analytics_rounded, label: 'Reports', index: 1),
      _BottomNavItem(icon: Icons.apps_rounded, label: 'Work', index: 2),
      _BottomNavItem(icon: Icons.person_rounded, label: 'Profile', index: 3),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF101B2F), Color(0xFF0B1322)]
              : const [Color(0xFFF7FAFF), Color(0xFFF1F5FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.fromLTRB(
          horizontalPadding,
          6,
          horizontalPadding,
          isCompact ? 12 : 18,
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 6 : 8,
            vertical: isCompact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF182538), Color(0xFF101B2C)]
                  : const [Colors.white, Color(0xFFF5F8FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(isCompact ? 28 : 32),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.10)
                  : AppColors.border.withOpacity(0.65),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.30 : 0.10),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: navigationItems
                .map(
                  (item) => Expanded(
                    child: _buildNavBarItem(
                      item,
                      isDark,
                      isCompact: isCompact,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBarItem(
    _BottomNavItem item,
    bool isDark, {
    required bool isCompact,
  }) {
    final isSelected = item.index == _selectedTabIndex;
    final activeColor = AppColors.primary;
    final inactiveColor = isDark ? Colors.grey[400] : Colors.grey[500];
    final showInlineLabel = isSelected && !isCompact;

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
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.symmetric(horizontal: isCompact ? 2 : 4),
            padding: EdgeInsets.symmetric(
              horizontal: showInlineLabel ? 12 : 0,
              vertical: isCompact ? 6 : 8,
            ),
            decoration: BoxDecoration(
              gradient: showInlineLabel
                  ? LinearGradient(
                      colors: [
                        activeColor,
                        activeColor.withOpacity(0.82),
                      ],
                    )
                  : null,
              color: isSelected
                  ? (isCompact ? activeColor.withOpacity(0.14) : null)
                  : (isDark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isCompact ? 32 : 34,
                  height: isCompact ? 32 : 34,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isCompact
                            ? activeColor.withOpacity(0.16)
                            : Colors.white.withOpacity(0.18))
                        : (isDark
                            ? Colors.white.withOpacity(0.05)
                            : activeColor.withOpacity(0.10)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    item.icon,
                    color: isSelected && !isCompact
                        ? Colors.white
                        : (isSelected ? activeColor : inactiveColor),
                    size: isCompact ? 18 : 19,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      child: child,
                    ),
                  ),
                  child: showInlineLabel
                      ? Padding(
                          key: ValueKey(item.label),
                          padding: const EdgeInsets.only(left: 10, right: 4),
                          child: Text(
                            item.label,
                            style: AppTextStyles.body2.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 4 : 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: AppTextStyles.caption.copyWith(
              color: isSelected
                  ? (isCompact ? activeColor : Colors.transparent)
                  : inactiveColor,
              fontWeight: FontWeight.w600,
              fontSize: isCompact ? 10 : 10.5,
            ),
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
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
  late List<_QuickActionItem> _allItems;
  late List<_QuickActionItem> _filteredItems;

  // Saved provider references (for safe use in async callbacks)
  late WorkersProvider _workersProvider;
  late CustomerProvider _customerProvider;

  // Sales metrics state
  double _todaySales = 0.0;
  int _todayTransactions = 0;
  double _todayRevenue = 0.0;
  bool _loadingSalesMetrics = true;

  // Real estate metrics state
  int _totalProperties = 0;
  int _occupiedUnits = 0;
  int _vacantUnits = 0;
  int _overdueRents = 0;
  double _monthlyRentCollection = 0.0;
  bool _loadingRealEstateMetrics = true;

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

    // Initialize quick action items based on current business type
    final businessProvider = context.read<BusinessProvider>();
    final businessType =
        businessProvider.currentBusiness?.businessType ?? 'retail';
    _allItems = _getQuickActionItems(businessType);
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
    _lastBusinessId = businessProvider.currentBusiness?.id;
  }

  @override
  void dispose() {
    _metricsDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _switchBusinessFromCard(BusinessModel business) async {
    final authProvider = context.read<AuthProvider>();
    final businessProvider = context.read<BusinessProvider>();
    final userId = authProvider.currentUser?.id;

    if (userId == null || businessProvider.isSwitchingBusiness) return;

    try {
      final switched = await authProvider.switchBusiness(business.id);
      if (!switched) {
        throw Exception('Unable to switch business context');
      }

      businessProvider.markUserSelection(userId);
      await businessProvider.switchToBusinessAndSync(
        userId: userId,
        selectedBusiness: business,
      );
      await _handleRefresh();

      // Update quick action items for the new business type
      _updateQuickActionItems();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Now managing ${business.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not switch business: $e')),
      );
    }
  }

  void _updateQuickActionItems() {
    final businessProvider = context.read<BusinessProvider>();
    final businessType =
        businessProvider.currentBusiness?.businessType ?? 'retail';
    setState(() {
      _allItems = _getQuickActionItems(businessType);
      _filteredItems = _allItems;
    });
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = _allItems;
      } else {
        _filteredItems = _allItems.where((item) {
          return item.title.toLowerCase().contains(query) ||
              item.subtitle.toLowerCase().contains(query);
        }).toList();
      }
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
      final businessType = context
              .read<BusinessProvider>()
              .currentBusiness
              ?.businessType
              ?.toLowerCase() ??
          'retail';

      if (businessId == null) {
        print('[Dashboard] No business ID found');
        return;
      }

      // Check if this is a real estate business
      if (businessType == 'realestate' || businessType == 'real estate') {
        await _loadRealEstateMetrics(businessId);
      } else {
        await _loadRetailMetrics(businessId);
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
      print('[Dashboard] Error loading metrics: $e');
      if (mounted) {
        setState(() {
          _loadingSalesMetrics = false;
          _loadingRealEstateMetrics = false;
        });
      }
    } finally {
      _isLoadingMetrics = false;
    }
  }

  Future<void> _loadRetailMetrics(String businessId) async {
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
        print(
            '[Dashboard] Retail metrics loaded for range ${_selectedDateRange.start} - ${_selectedDateRange.end}: ₦$_todaySales, Transactions: $_todayTransactions');
      });
    }
  }

  Future<void> _loadRealEstateMetrics(String businessId) async {
    try {
      final realEstateProvider = context.read<RealEstateProvider>();

      // Load real estate data
      await realEstateProvider.loadAll();

      final properties = realEstateProvider.properties;
      final rentPayments = realEstateProvider.rentPayments;
      final leases = realEstateProvider.leases;

      // Calculate metrics
      final totalProperties = properties.length;
      final occupiedUnits = properties
          .where((p) => p.status == 'rented' || p.status == 'sold')
          .length;
      final vacantUnits =
          properties.where((p) => p.status == 'available').length;

      // Calculate overdue rents (payments that are past due)
      final now = DateTime.now();
      final overdueRents = leases.where((lease) {
        // Check if lease is active and payment is overdue
        // Since paymentFrequency is not in the model, we check if current date is past endDate
        // or if there are pending payments in rentPayments for this lease that are past due
        final hasPendingOverdue = rentPayments.any((p) =>
            p.leaseId == lease.id &&
            p.status != 'paid' &&
            p.dueDate.isBefore(now));
        return lease.status == 'active' &&
            (lease.endDate.isBefore(now) || hasPendingOverdue);
      }).length;

      // Calculate monthly rent collection (sum of payments in current month)
      final currentMonth = DateTime(now.year, now.month);
      final nextMonth = DateTime(now.year, now.month + 1);
      final monthlyRentCollection = rentPayments
          .where((payment) =>
              (payment.paidDate ?? payment.createdAt).isAfter(currentMonth) &&
              (payment.paidDate ?? payment.createdAt).isBefore(nextMonth))
          .fold<double>(0.0, (sum, payment) => sum + payment.amount);

      if (mounted) {
        setState(() {
          _totalProperties = totalProperties;
          _occupiedUnits = occupiedUnits;
          _vacantUnits = vacantUnits;
          _overdueRents = overdueRents;
          _monthlyRentCollection = monthlyRentCollection;
          _loadingRealEstateMetrics = false;
          print(
              '[Dashboard] Real estate metrics loaded: Properties: $totalProperties, Occupied: $occupiedUnits, Vacant: $vacantUnits, Overdue: $overdueRents, Monthly Collection: ₦$monthlyRentCollection');
        });
      }
    } catch (e) {
      print('[Dashboard] Error loading real estate metrics: $e');
      if (mounted) {
        setState(() {
          _loadingRealEstateMetrics = false;
        });
      }
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
          print(
              '[Dashboard] Business changed from $_lastBusinessId to $businessId, updating providers');
          _lastBusinessId = businessId;

          // Update domain-specific providers ONLY on business change
          final setters = [
            () => Future.sync(
                () => context.read<DrinkProvider>().setBusinessId(businessId)),
            () => Future.sync(
                () => context.read<AgriProvider>().setBusinessId(businessId)),
            () => Future.sync(
                () => context.read<AutoProvider>().setBusinessId(businessId)),
            () => Future.sync(
                () => context.read<GymProvider>().setBusinessId(businessId)),
            () => Future.sync(
                () => context.read<HotelProvider>().setBusinessId(businessId)),
            () => Future.sync(() =>
                context.read<PharmacyProvider>().setBusinessId(businessId)),
            () => Future.sync(
                () => context.read<RetailProvider>().setBusinessId(businessId)),
            () => Future.sync(
                () => context.read<SalonProvider>().setBusinessId(businessId)),
            () => context.read<RealEstateProvider>().setBusinessId(businessId),
            () => Future.sync(() =>
                context.read<CustomerProvider>().setBusinessId(businessId)),
            () => Future.sync(() =>
                context.read<AnalyticsProvider>().setBusinessId(businessId)),
          ];

          for (final s in setters) {
            try {
              s();
            } catch (_) {}
          }
        } else {
          print(
              '[Dashboard] Business unchanged ($businessId), skipping provider updates');
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
    final isSwitchingBusiness = businessProvider.isSwitchingBusiness;

    // 🔥 OPTIMIZATION: If business selection changed, debounce metrics reload
    // This prevents excessive queries when switching businesses quickly
    final currentBusinessId = business?.id;
    if (_lastBusinessId != currentBusinessId && currentBusinessId != null) {
      _lastBusinessId = currentBusinessId;
      print(
          '[Dashboard] Business changed to $currentBusinessId, scheduling metrics reload');
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
                  initialRange: _selectedDateRange,
                  backgroundColor: const Color.fromARGB(255, 31, 54, 104),
                ).animate().fadeIn(duration: 500.ms, delay: 250.ms),
                const SizedBox(height: 20),

                // Quick Metrics
                _buildQuickMetrics(
                  isDark,
                  businessType: business.businessType,
                  sales: _todaySales,
                  transactions: _todayTransactions,
                  revenue: _todayRevenue,
                  isLoading: _loadingSalesMetrics || isSwitchingBusiness,
                  customersCount: isSwitchingBusiness ? 0 : _customersCount,
                  workersCount: isSwitchingBusiness ? 0 : _workersCount,
                  isLoadingCounts: _loadingCounts || isSwitchingBusiness,
                  // Real estate metrics
                  totalProperties: _totalProperties,
                  occupiedUnits: _occupiedUnits,
                  vacantUnits: _vacantUnits,
                  overdueRents: _overdueRents,
                  monthlyRentCollection: _monthlyRentCollection,
                  isLoadingRealEstate:
                      _loadingRealEstateMetrics || isSwitchingBusiness,
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
                    } else if (businessType.contains('agri') ||
                        businessType.contains('agriculture')) {
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
                    } else if (businessType.contains('drink') ||
                        businessType.contains('bar')) {
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
                    } else if (businessType.contains('real') &&
                        businessType.contains('estate')) {
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
                          route: Routes
                              .ownerDashboard, // Navigate to main dashboard which will show apartment dashboard
                        ),
                      );
                      actions.insert(
                        1,
                        _QuickActionItem(
                          title: 'Unit Management',
                          subtitle: 'Manage properties',
                          icon: Icons.business,
                          color: AppColors.realEstate,
                          route: Routes
                              .ownerDashboard, // Navigate to main dashboard which will show apartment dashboard
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
    final businessProvider = context.watch<BusinessProvider>();
    final isSwitching = businessProvider.isSwitchingBusiness;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : AppColors.border.withOpacity(0.80),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.16 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.business_center_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose a business',
                      style: AppTextStyles.heading5.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSwitching
                          ? 'Updating your workspace and syncing the latest business context.'
                          : 'Switch into the workspace you want to manage right now.',
                      style: AppTextStyles.body2.copyWith(
                        color:
                            isDark ? Colors.grey[400] : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...businesses.map((b) {
            final color = BusinessTypes.getColor(b.businessType);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: isSwitching ? null : () => _switchBusinessFromCard(b),
                  child: Ink(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          color.withOpacity(isDark ? 0.95 : 0.90),
                          color.withOpacity(isDark ? 0.74 : 0.76),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.20),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            BusinessTypes.getIcon(b.businessType),
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.name,
                                style: AppTextStyles.heading5.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                BusinessTypes.getName(b.businessType),
                                style: AppTextStyles.body2.copyWith(
                                  color: Colors.white.withOpacity(0.82),
                                ),
                              ),
                              if (b.subscriptionTier.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    b.subscriptionTier.toUpperCase(),
                                    style: AppTextStyles.caption.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: isSwitching &&
                                  businessProvider.pendingBusinessId == b.id
                              ? Container(
                                  key: ValueKey('loading-${b.id}'),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  key: ValueKey('open-${b.id}'),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNoBusinessState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF10223F), const Color(0xFF16325C)]
              : [const Color(0xFFF8FBFF), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : AppColors.border.withOpacity(0.85),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.16 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.add_business_rounded,
              size: 38,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Create Your First Business',
            style: AppTextStyles.heading4.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Set up a business profile to unlock the dashboard, switch between businesses, and start tracking real activity.',
            style: AppTextStyles.body2.copyWith(
              color: isDark ? Colors.grey[400] : AppColors.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  Routes.businessSelection,
                ),
                icon: const Icon(Icons.storefront_rounded),
                label: const Text('Choose Business Type'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  Routes.businessDetails,
                ),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Quick Create'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      isDark ? Colors.white : Theme.of(context).primaryColor,
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.18)
                        : AppColors.border,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
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
                'Welcome back👋',
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
                        bp.isSwitchingBusiness
                            ? 'Syncing workspace...'
                            : current?.name ?? 'No business selected',
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
                    if (bp.isSwitchingBusiness) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Updating',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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
          icon:
              const Icon(Icons.add_business_rounded, color: AppColors.primary),
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
                    color:
                        AppColors.textSecondary.withAlpha((0.5 * 255).toInt()),
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
    final businessProvider = context.watch<BusinessProvider>();
    final isSyncingThisBusiness = businessProvider.isSwitchingBusiness &&
        businessProvider.pendingBusinessId == business.id;
    final baseColor = BusinessTypes.getColor(business.businessType);
    final secondary = baseColor.withOpacity(0.78);
    final logoUrl = business.photoUrl ?? business.logoUrl;
    final surfaceOverlay = isDark ? 0.10 : 0.08;
    final daysLeft = business.subscriptionEndDate == null
        ? null
        : (business.subscriptionEndDate!.difference(DateTime.now()).inDays)
            .clamp(0, 999);

    return GestureDetector(
      onTap: () {
        widget.onOpenWorkTab?.call();
      },
      onLongPress: () async {
        await _showBusinessSwitcherSheet();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              baseColor.withOpacity(0.96),
              secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: baseColor.withOpacity(0.25),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -48,
              right: -24,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(surfaceOverlay),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -22,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(surfaceOverlay / 2),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.16)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: logoUrl != null && logoUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: logoUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.white.withOpacity(0.08),
                                ),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  isSyncingThisBusiness
                                      ? 'Syncing workspace'
                                      : 'Active business',
                                  style: AppTextStyles.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  business.subscriptionTier.toUpperCase(),
                                  style: AppTextStyles.caption.copyWith(
                                    color: baseColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (isSyncingThisBusiness)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Refreshing',
                                        style: AppTextStyles.caption.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            business.name,
                            style: AppTextStyles.heading4.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            BusinessTypes.getName(business.businessType),
                            style: AppTextStyles.body2.copyWith(
                              color: Colors.white.withOpacity(0.86),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildBusinessActionButton(
                      icon: Icons.swap_horiz_rounded,
                      tooltip: 'Switch Business',
                      onPressed: _showBusinessSwitcherSheet,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildBusinessMetaPill(
                      icon: Icons.storefront_rounded,
                      label: BusinessTypes.getName(business.businessType),
                    ),
                    if (business.city != null && business.city!.isNotEmpty)
                      _buildBusinessMetaPill(
                        icon: Icons.location_on_outlined,
                        label: business.city!,
                      ),
                    if (business.phone != null && business.phone!.isNotEmpty)
                      _buildBusinessMetaPill(
                        icon: Icons.phone_outlined,
                        label: business.phone!,
                      ),
                    if (daysLeft != null)
                      _buildBusinessMetaPill(
                        icon: Icons.schedule_rounded,
                        label: '$daysLeft day${daysLeft == 1 ? '' : 's'} left',
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _smallStatChip(
                        '${business.totalProducts ?? 0}',
                        'Products',
                        onTap: () =>
                            Navigator.pushNamed(context, Routes.inventory),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _smallStatChip(
                        '${business.totalCustomers ?? 0}',
                        'Customers',
                        onTap: () =>
                            Navigator.pushNamed(context, Routes.customers),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _smallStatChip(
                        _loadingCounts
                            ? '...'
                            : '${_workersCount > 0 ? _workersCount : (business.totalWorkers ?? 0)}',
                        'Staff',
                        onTap: () =>
                            Navigator.pushNamed(context, Routes.workers),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => widget.onOpenWorkTab?.call(),
                        icon: const Icon(Icons.work_outline_rounded),
                        label: const Text('Open Workspace'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: baseColor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildBusinessActionButton(
                      icon: Icons.dashboard_customize_rounded,
                      tooltip: 'Open Industry Dashboard',
                      onPressed: () => _navigateToIndustryDashboard(business),
                    ),
                    const SizedBox(width: 10),
                    _buildBusinessActionButton(
                      icon: Icons.analytics_outlined,
                      tooltip: 'Analytics',
                      onPressed: () =>
                          Navigator.pushNamed(context, Routes.reports),
                    ),
                    if (business.website != null &&
                        business.website!.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      _buildBusinessActionButton(
                        icon: Icons.public_rounded,
                        tooltip: 'Visit Website',
                        onPressed: () =>
                            _launchBusinessWebsite(business.website!),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBusinessSwitcherSheet() async {
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
                    const BorderRadius.vertical(top: Radius.circular(24)),
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
  }

  Widget _buildBusinessMetaPill({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withOpacity(0.92)),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 50,
      height: 50,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Future<void> _launchBusinessWebsite(String website) async {
    final trimmed = website.trim();
    final normalized =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
            ? trimmed
            : 'https://$trimmed';
    final uri = Uri.tryParse(normalized);

    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to open website')),
    );
  }

  Widget _buildQuickMetrics(
    bool isDark, {
    required String businessType,
    double sales = 0.0,
    int transactions = 0,
    double revenue = 0.0,
    bool isLoading = false,
    int customersCount = 0,
    int workersCount = 0,
    bool isLoadingCounts = false,
    // Real estate metrics
    int totalProperties = 0,
    int occupiedUnits = 0,
    int vacantUnits = 0,
    int overdueRents = 0,
    double monthlyRentCollection = 0.0,
    bool isLoadingRealEstate = false,
  }) {
    final type = businessType.toLowerCase().replaceAll(' ', '');

    if (type == 'realestate') {
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
                'Properties',
                isLoadingRealEstate ? '...' : totalProperties.toString(),
                Icons.apartment_rounded,
                Colors.blue,
                isDark,
                route: Routes.realEstateProperties,
              ),
              _buildMetricTile(
                'Occupied',
                isLoadingRealEstate ? '...' : occupiedUnits.toString(),
                Icons.home_rounded,
                Colors.green,
                isDark,
                route: Routes.realEstateProperties,
              ),
              _buildMetricTile(
                'Vacant',
                isLoadingRealEstate ? '...' : vacantUnits.toString(),
                Icons.home_work_rounded,
                Colors.orange,
                isDark,
                route: Routes.realEstateProperties,
              ),
              _buildMetricTile(
                'Overdue',
                isLoadingRealEstate ? '...' : overdueRents.toString(),
                Icons.warning_rounded,
                Colors.red,
                isDark,
                route: Routes.realEstateRentCollection,
              ),
              _buildMetricTile(
                'Monthly Rent',
                isLoadingRealEstate
                    ? '...'
                    : formatCurrency(monthlyRentCollection),
                Icons.attach_money_rounded,
                Colors.teal,
                isDark,
                route: Routes.realEstateRentCollection,
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

    // Default retail metrics
    final averageTicket = transactions > 0 ? revenue / transactions : 0.0;

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

  Widget _smallStatChip(String value, String label, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.12 * 255).toInt()),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: Colors.white.withAlpha((0.06 * 255).toInt())),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Text(value,
                  style: AppTextStyles.caption.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withAlpha((0.9 * 255).toInt()))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(bool isDark,
      [List<_QuickActionItem>? actions]) {
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
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.15),
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
            splashColor: item.color.withOpacity(isDark ? 0.2 : 0.1),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(isDark ? 0.15 : 0.1),
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
                      color:
                          isDark ? Colors.grey[500] : AppColors.textSecondary,
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

  static List<_QuickActionItem> _getQuickActionItems([String? businessType]) {
    final type = (businessType?.toLowerCase() ?? 'retail')
        .replaceAll('_', '') // Remove underscores
        .replaceAll(' ', ''); // Remove spaces

    // Common items for all business types
    final commonItems = [
      _QuickActionItem(
        title: 'Reports',
        subtitle: 'View analytics',
        icon: Icons.analytics_rounded,
        color: Colors.cyan,
        route: Routes.reports,
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
    ];

    // Business-specific items
    switch (type) {
      case 'realestate':
        return [
          _QuickActionItem(
            title: 'Properties',
            subtitle: 'Manage properties',
            icon: Icons.apartment_rounded,
            color: Colors.blue,
            route: Routes.realEstateProperties,
          ),
          _QuickActionItem(
            title: 'Tenants',
            subtitle: 'Manage tenants',
            icon: Icons.people_rounded,
            color: Colors.green,
            route: Routes.realEstateTenants,
          ),
          _QuickActionItem(
            title: 'Leases',
            subtitle: 'Lease management',
            icon: Icons.description_rounded,
            color: Colors.orange,
            route: Routes.realEstateLeases,
          ),
          _QuickActionItem(
            title: 'Rent Collection',
            subtitle: 'Collect payments',
            icon: Icons.attach_money_rounded,
            color: Colors.teal,
            route: Routes.realEstateRentCollection,
          ),
          _QuickActionItem(
            title: 'Maintenance',
            subtitle: 'Manage tickets',
            icon: Icons.build_rounded,
            color: Colors.red,
            route: Routes.realEstateMaintenance,
          ),
          _QuickActionItem(
            title: 'Documents',
            subtitle: 'Property documents',
            icon: Icons.folder_rounded,
            color: Colors.purple,
            route: Routes.realEstateDocuments,
          ),
          ...commonItems,
        ];

      case 'apartment':
        return [
          _QuickActionItem(
            title: 'Units',
            subtitle: 'Manage units',
            icon: Icons.home_rounded,
            color: Colors.blue,
            route: Routes.apartmentUnits,
          ),
          _QuickActionItem(
            title: 'Bookings',
            subtitle: 'Unit bookings',
            icon: Icons.calendar_today_rounded,
            color: Colors.green,
            route: Routes.apartmentBookings,
          ),
          _QuickActionItem(
            title: 'Create Booking',
            subtitle: 'New reservation',
            icon: Icons.add_rounded,
            color: Colors.orange,
            route: Routes.apartmentCreateBooking,
          ),
          ...commonItems,
        ];

      case 'pharmacy':
        return [
          _QuickActionItem(
            title: 'Prescriptions',
            subtitle: 'Manage prescriptions',
            icon: Icons.medical_services_rounded,
            color: Colors.blue,
            route: Routes.pharmacyPrescriptions,
          ),
          _QuickActionItem(
            title: 'Drug Inventory',
            subtitle: 'Manage drugs',
            icon: Icons.inventory_2_rounded,
            color: Colors.green,
            route: Routes.pharmacyDrugInventory,
          ),
          _QuickActionItem(
            title: 'Patients',
            subtitle: 'Patient records',
            icon: Icons.people_rounded,
            color: Colors.purple,
            route: Routes.pharmacyPatients,
          ),
          _QuickActionItem(
            title: 'POS',
            subtitle: 'Point of sale',
            icon: Icons.point_of_sale_rounded,
            color: Colors.teal,
            route: Routes.pharmacyPos,
          ),
          _QuickActionItem(
            title: 'Expiry Tracker',
            subtitle: 'Track expiries',
            icon: Icons.schedule_rounded,
            color: Colors.red,
            route: Routes.pharmacyExpiryTracker,
          ),
          ...commonItems,
        ];

      case 'agri':
      case 'agriculture':
        return [
          _QuickActionItem(
            title: 'Farms',
            subtitle: 'Manage farms',
            icon: Icons.agriculture_rounded,
            color: Colors.green,
            route: Routes.agriFarms,
          ),
          _QuickActionItem(
            title: 'Livestock',
            subtitle: 'Animal management',
            icon: Icons.pets_rounded,
            color: Colors.brown,
            route: Routes.agriLivestock,
          ),
          _QuickActionItem(
            title: 'Crops',
            subtitle: 'Crop tracking',
            icon: Icons.grass_rounded,
            color: Colors.orange,
            route: Routes.agriCrops,
          ),
          _QuickActionItem(
            title: 'Harvest',
            subtitle: 'Harvest records',
            icon: Icons.celebration_rounded,
            color: Colors.amber,
            route: Routes.agriHarvest,
          ),
          _QuickActionItem(
            title: 'Inputs',
            subtitle: 'Farm supplies',
            icon: Icons.shopping_cart_rounded,
            color: Colors.teal,
            route: Routes.agriInputs,
          ),
          _QuickActionItem(
            title: 'Weather',
            subtitle: 'Weather data',
            icon: Icons.wb_sunny_rounded,
            color: Colors.blue,
            route: Routes.agriWeather,
          ),
          ...commonItems,
        ];

      case 'auto':
      case 'autorepair':
        return [
          _QuickActionItem(
            title: 'Service Orders',
            subtitle: 'Manage orders',
            icon: Icons.build_rounded,
            color: Colors.blue,
            route: Routes.autoServiceOrders,
          ),
          _QuickActionItem(
            title: 'Job Cards',
            subtitle: 'Service jobs',
            icon: Icons.assignment_rounded,
            color: Colors.orange,
            route: Routes.autoJobCards,
          ),
          _QuickActionItem(
            title: 'Vehicle History',
            subtitle: 'Vehicle records',
            icon: Icons.directions_car_rounded,
            color: Colors.green,
            route: Routes.autoVehicleHistory,
          ),
          _QuickActionItem(
            title: 'Parts Inventory',
            subtitle: 'Manage parts',
            icon: Icons.inventory_2_rounded,
            color: Colors.teal,
            route: Routes.autoPartsInventory,
          ),
          _QuickActionItem(
            title: 'Mechanic Schedule',
            subtitle: 'Staff schedules',
            icon: Icons.schedule_rounded,
            color: Colors.purple,
            route: Routes.autoMechanicSchedule,
          ),
          ...commonItems,
        ];

      case 'salon':
        return [
          _QuickActionItem(
            title: 'Appointments',
            subtitle: 'Manage bookings',
            icon: Icons.calendar_today_rounded,
            color: Colors.pink,
            route: Routes.salonAppointments,
          ),
          _QuickActionItem(
            title: 'Book Appointment',
            subtitle: 'New booking',
            icon: Icons.add_rounded,
            color: Colors.green,
            route: Routes.salonBookAppointment,
          ),
          _QuickActionItem(
            title: 'Services',
            subtitle: 'Service catalog',
            icon: Icons.content_cut_rounded,
            color: Colors.blue,
            route: Routes.salonServices,
          ),
          _QuickActionItem(
            title: 'Stylists',
            subtitle: 'Manage staff',
            icon: Icons.people_rounded,
            color: Colors.purple,
            route: Routes.salonStylists,
          ),
          _QuickActionItem(
            title: 'Calendar',
            subtitle: 'View schedule',
            icon: Icons.calendar_view_month_rounded,
            color: Colors.orange,
            route: Routes.salonCalendar,
          ),
          _QuickActionItem(
            title: 'Commission',
            subtitle: 'Track earnings',
            icon: Icons.attach_money_rounded,
            color: Colors.teal,
            route: Routes.salonCommission,
          ),
          ...commonItems,
        ];

      case 'barbershop':
        return [
          _QuickActionItem(
            title: 'Appointments',
            subtitle: 'Manage bookings',
            icon: Icons.calendar_today_rounded,
            color: Colors.blue,
            route: Routes.barberShopAppointments,
          ),
          _QuickActionItem(
            title: 'Services',
            subtitle: 'Service catalog',
            icon: Icons.content_cut_rounded,
            color: Colors.green,
            route: Routes.barberShopServices,
          ),
          _QuickActionItem(
            title: 'Barbers',
            subtitle: 'Manage staff',
            icon: Icons.people_rounded,
            color: Colors.purple,
            route: Routes.barberShopBarbers,
          ),
          _QuickActionItem(
            title: 'Commission',
            subtitle: 'Track earnings',
            icon: Icons.attach_money_rounded,
            color: Colors.teal,
            route: Routes.barberCommission,
          ),
          _QuickActionItem(
            title: 'Payments',
            subtitle: 'Payment history',
            icon: Icons.payment_rounded,
            color: Colors.orange,
            route: Routes.barberShopPayments,
          ),
          ...commonItems,
        ];

      case 'hotel':
        return [
          _QuickActionItem(
            title: 'Front Desk',
            subtitle: 'Check-in/out',
            icon: Icons.hotel_rounded,
            color: Colors.blue,
            route: Routes.hotelFrontDesk,
          ),
          _QuickActionItem(
            title: 'Rooms',
            subtitle: 'Room management',
            icon: Icons.meeting_room_rounded,
            color: Colors.green,
            route: Routes.hotelRooms,
          ),
          _QuickActionItem(
            title: 'Bookings',
            subtitle: 'Manage reservations',
            icon: Icons.calendar_today_rounded,
            color: Colors.orange,
            route: Routes.hotelBookings,
          ),
          _QuickActionItem(
            title: 'Check-in',
            subtitle: 'Guest arrival',
            icon: Icons.login_rounded,
            color: Colors.teal,
            route: Routes.hotelCheckIn,
          ),
          _QuickActionItem(
            title: 'Guests',
            subtitle: 'Guest management',
            icon: Icons.people_rounded,
            color: Colors.purple,
            route: Routes.hotelGuests,
          ),
          _QuickActionItem(
            title: 'Housekeeping',
            subtitle: 'Room cleaning',
            icon: Icons.cleaning_services_rounded,
            color: Colors.red,
            route: Routes.hotelHousekeeping,
          ),
          ...commonItems,
        ];

      case 'restaurant':
        return [
          _QuickActionItem(
            title: 'Tables',
            subtitle: 'Table management',
            icon: Icons.table_restaurant_rounded,
            color: Colors.blue,
            route: Routes.restaurantTables,
          ),
          _QuickActionItem(
            title: 'Orders',
            subtitle: 'Order management',
            icon: Icons.restaurant_menu_rounded,
            color: Colors.green,
            route: Routes.restaurantOrders,
          ),
          _QuickActionItem(
            title: 'Kitchen',
            subtitle: 'Kitchen display',
            icon: Icons.kitchen_rounded,
            color: Colors.orange,
            route: Routes.restaurantKitchen,
          ),
          _QuickActionItem(
            title: 'Menu',
            subtitle: 'Menu management',
            icon: Icons.menu_book_rounded,
            color: Colors.teal,
            route: Routes.restaurantMenu,
          ),
          _QuickActionItem(
            title: 'Reservations',
            subtitle: 'Table bookings',
            icon: Icons.calendar_today_rounded,
            color: Colors.purple,
            route: Routes.restaurantReservations,
          ),
          _QuickActionItem(
            title: 'Waiters',
            subtitle: 'Staff management',
            icon: Icons.people_rounded,
            color: Colors.red,
            route: Routes.restaurantWaiters,
          ),
          ...commonItems,
        ];

      case 'drink':
      case 'bar':
        return [
          _QuickActionItem(
            title: 'POS',
            subtitle: 'Point of sale',
            icon: Icons.local_bar_rounded,
            color: Colors.blue,
            route: Routes.drinkPos,
          ),
          _QuickActionItem(
            title: 'Inventory',
            subtitle: 'Beverage stock',
            icon: Icons.inventory_2_rounded,
            color: Colors.green,
            route: Routes.drinkInventory,
          ),
          _QuickActionItem(
            title: 'Bottle Tracking',
            subtitle: 'Track bottles',
            icon: Icons.liquor_rounded,
            color: Colors.orange,
            route: Routes.drinkBottleTracking,
          ),
          _QuickActionItem(
            title: 'Tabs',
            subtitle: 'Customer tabs',
            icon: Icons.account_balance_wallet_rounded,
            color: Colors.teal,
            route: Routes.drinkTabs,
          ),
          _QuickActionItem(
            title: 'Menu',
            subtitle: 'Cocktail menu',
            icon: Icons.menu_book_rounded,
            color: Colors.purple,
            route: Routes.drinkMenu,
          ),
          ...commonItems,
        ];

      case 'gym':
        return [
          _QuickActionItem(
            title: 'Members',
            subtitle: 'Member management',
            icon: Icons.fitness_center_rounded,
            color: Colors.blue,
            route: Routes.gymMembers,
          ),
          _QuickActionItem(
            title: 'Trainers',
            subtitle: 'Staff management',
            icon: Icons.sports_rounded,
            color: Colors.green,
            route: Routes.gymTrainers,
          ),
          _QuickActionItem(
            title: 'Memberships',
            subtitle: 'Membership plans',
            icon: Icons.card_membership_rounded,
            color: Colors.orange,
            route: Routes.gymMemberships,
          ),
          _QuickActionItem(
            title: 'Classes',
            subtitle: 'Class schedules',
            icon: Icons.schedule_rounded,
            color: Colors.teal,
            route: Routes.gymClasses,
          ),
          _QuickActionItem(
            title: 'Calendar',
            subtitle: 'View schedule',
            icon: Icons.calendar_view_month_rounded,
            color: Colors.purple,
            route: Routes.gymCalendar,
          ),
          _QuickActionItem(
            title: 'Attendance',
            subtitle: 'Track attendance',
            icon: Icons.check_circle_rounded,
            color: Colors.red,
            route: Routes.gymAttendance,
          ),
          ...commonItems,
        ];

      case 'gas':
        return [
          _QuickActionItem(
            title: 'Pump',
            subtitle: 'Fuel dispensing',
            icon: Icons.local_gas_station_rounded,
            color: Colors.blue,
            route: Routes.gasPump,
          ),
          _QuickActionItem(
            title: 'Stock',
            subtitle: 'Fuel inventory',
            icon: Icons.inventory_2_rounded,
            color: Colors.green,
            route: Routes.gasStock,
          ),
          _QuickActionItem(
            title: 'Sales History',
            subtitle: 'Fuel sales',
            icon: Icons.history_rounded,
            color: Colors.orange,
            route: Routes.gasSalesHistory,
          ),
          ...commonItems,
        ];

      case 'wholesale':
        return [
          _QuickActionItem(
            title: 'Purchase Orders',
            subtitle: 'Manage orders',
            icon: Icons.shopping_cart_rounded,
            color: Colors.blue,
            route: Routes.wholesalePurchaseOrders,
          ),
          _QuickActionItem(
            title: 'Transfers',
            subtitle: 'Stock transfers',
            icon: Icons.swap_horiz_rounded,
            color: Colors.green,
            route: Routes.wholesaleTransfers,
          ),
          _QuickActionItem(
            title: 'Warehouses',
            subtitle: 'Warehouse management',
            icon: Icons.warehouse_rounded,
            color: Colors.orange,
            route: Routes.wholesaleWarehouses,
          ),
          _QuickActionItem(
            title: 'POS',
            subtitle: 'Point of sale',
            icon: Icons.point_of_sale_rounded,
            color: Colors.teal,
            route: Routes.wholesalePos,
          ),
          ...commonItems,
        ];

      default: // retail and other businesses
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
            title: 'Expenses',
            subtitle: 'Document expenses',
            icon: Icons.shop_rounded,
            color: Colors.brown,
            route: Routes.expenseReport,
          ),
          ...commonItems,
        ];
    }
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
