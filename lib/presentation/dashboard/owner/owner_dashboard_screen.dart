import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/routes.dart';
import '../../../core/config.dart';
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
import '../../../services/business_restriction_service.dart';
import '../../../data/models/business_model.dart';
import '../../../data/repositories/analytics_repository_impl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../../industry_specific/gas/utils/fuel_station_scope.dart';
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
    final authProvider = context.watch<AuthProvider>();
    const backgroundGradient = LinearGradient(
      colors: [
        Color(0xFF020817),
        Color(0xFF071226),
        Color(0xFF020817),
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
          backgroundColor: const Color(0xFF020817),
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 390;
    final horizontalPadding = screenWidth < 420 ? 12.0 : 24.0;
    final navigationItems = [
      _BottomNavItem(icon: Icons.home_rounded, label: 'Home', index: 0),
      _BottomNavItem(icon: Icons.analytics_rounded, label: 'Reports', index: 1),
      _BottomNavItem(icon: Icons.apps_rounded, label: 'Work', index: 2),
      _BottomNavItem(icon: Icons.person_rounded, label: 'Profile', index: 3),
    ];

    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(
        horizontalPadding,
        6,
        horizontalPadding,
        isCompact ? 10 : 14,
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 8 : 10,
          vertical: isCompact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF101A30).withOpacity(0.96),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.34),
              blurRadius: 28,
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
                    true,
                    isCompact: isCompact,
                  ),
                ),
              )
              .toList(),
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
    final inactiveColor = Colors.white.withOpacity(0.72);

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
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: isCompact ? 34 : 38,
            height: isCompact ? 34 : 38,
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withOpacity(0.18)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: activeColor.withOpacity(0.34),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              item.icon,
              color: isSelected ? activeColor : inactiveColor,
              size: isCompact ? 18 : 20,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: isSelected ? activeColor : inactiveColor,
              fontWeight: FontWeight.w700,
              fontSize: isCompact ? 10 : 10.5,
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
  bool _loadingCounts = true;

  // Date range state
  late DateTimeRange _selectedDateRange;
  String _selectedMetricRangeLabel = 'Today';
  String _actionFilter = 'all';
  String? _lastBusinessId;
  String? _lastBusinessType;
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

    _selectedDateRange = _rangeForMetricLabel(_selectedMetricRangeLabel);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSalesMetrics();
    });
    // Capture current business id and type to detect changes later
    _lastBusinessId = businessProvider.currentBusiness?.id;
    _lastBusinessType =
        businessProvider.currentBusiness?.businessType.toLowerCase();
  }

  Future<void> _openSupportWhatsApp() async {
    final businessProvider = context.read<BusinessProvider>();
    final authProvider = context.read<AuthProvider>();
    final business = businessProvider.currentBusiness;

    final restrictionService = BusinessRestrictionService();
    final restrictionState = await restrictionService.getRestrictionState(
      userId: authProvider.currentUser?.id,
      businessId: business?.id,
    );

    final supportWhatsapp = (restrictionState?.customerCareWhatsapp ?? '')
            .trim()
            .isNotEmpty
        ? restrictionState!.customerCareWhatsapp ?? AppConfig.ownerWhatsappNumber
        : AppConfig.ownerWhatsappNumber;
    if (supportWhatsapp.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer support contact is not available right now.'),
        ),
      );
      return;
    }

    final url = restrictionService.buildWhatsAppUrl(
      supportWhatsapp,
      message:
          'Hello, I need support for ${business?.name ?? 'my business'} on Manage Care.',
    );
    final uri = Uri.tryParse(url);

    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open WhatsApp right now.')),
    );
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
    });
    _filterItems();
  }

  void _filterItems() {
    setState(() {
      _filteredItems = _allItems.where(_matchesActionVisibility).toList();
    });
  }

  bool _matchesActionVisibility(_QuickActionItem item) {
    final query = _searchController.text.toLowerCase();
    final matchesQuery = query.isEmpty ||
        item.title.toLowerCase().contains(query) ||
        item.subtitle.toLowerCase().contains(query);
    return matchesQuery && _matchesActionFilter(item);
  }

  bool _matchesActionFilter(_QuickActionItem item) {
    if (_actionFilter == 'all') return true;
    final text = '${item.title} ${item.subtitle} ${item.route ?? ''}'
        .toLowerCase();
    switch (_actionFilter) {
      case 'sales':
        return text.contains('sale') ||
            text.contains('pos') ||
            text.contains('order') ||
            text.contains('checkout');
      case 'inventory':
        return text.contains('inventory') ||
            text.contains('stock') ||
            text.contains('product') ||
            text.contains('procurement') ||
            text.contains('supplier');
      case 'people':
        return text.contains('customer') ||
            text.contains('worker') ||
            text.contains('staff') ||
            text.contains('tenant') ||
            text.contains('guest');
      case 'reports':
        return text.contains('report') ||
            text.contains('analytics') ||
            text.contains('history') ||
            text.contains('trend');
      case 'settings':
        return text.contains('setting') ||
            text.contains('profile') ||
            text.contains('notification') ||
            text.contains('support');
    }
    return true;
  }

  DateTimeRange _rangeForMetricLabel(String label) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (label) {
      case 'This Week':
        return DateTimeRange(
          start: today.subtract(Duration(days: today.weekday - 1)),
          end: now.add(const Duration(days: 1)),
        );
      case 'This Month':
        return DateTimeRange(
          start: DateTime(now.year, now.month),
          end: DateTime(now.year, now.month + 1),
        );
      case 'This Year':
        return DateTimeRange(
          start: DateTime(now.year),
          end: DateTime(now.year + 1),
        );
      case 'Today':
      default:
        return DateTimeRange(
          start: today,
          end: now.add(const Duration(days: 1)),
        );
    }
  }

  Future<void> _selectMetricRange() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        const labels = ['Today', 'This Week', 'This Month', 'This Year'];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final label in labels)
                RadioListTile<String>(
                  title: Text(label),
                  value: label,
                  groupValue: _selectedMetricRangeLabel,
                  onChanged: (value) => Navigator.pop(context, value),
                ),
            ],
          ),
        );
      },
    );

    if (selected == null || selected == _selectedMetricRangeLabel) return;
    setState(() {
      _selectedMetricRangeLabel = selected;
      _selectedDateRange = _rangeForMetricLabel(selected);
      _loadingSalesMetrics = true;
      _loadingRealEstateMetrics = true;
    });
    await _loadSalesMetrics();
  }

  Future<void> _showActionFilterSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        const filters = <String, String>{
          'all': 'All',
          'sales': 'Sales',
          'inventory': 'Inventory',
          'people': 'People',
          'reports': 'Reports',
          'settings': 'Settings',
        };
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in filters.entries)
                RadioListTile<String>(
                  title: Text(entry.value),
                  value: entry.key,
                  groupValue: _actionFilter,
                  onChanged: (value) => Navigator.pop(context, value),
                ),
            ],
          ),
        );
      },
    );

    if (selected == null || selected == _actionFilter) return;
    _actionFilter = selected;
    _filterItems();
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
      final currentBusiness = context.read<BusinessProvider>().currentBusiness;
      final businessType = currentBusiness?.businessType?.toLowerCase() ?? 'retail';

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
          .fold<double>(0.0, (total, payment) => total + payment.amount);

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
    final liveWorkersCount = context.watch<WorkersProvider>().workers.length;
    final user = authProvider.currentUser;
    final business = businessProvider.currentBusiness;
    final userBusinesses = businessProvider.userBusinesses;
    final isSwitchingBusiness = businessProvider.isSwitchingBusiness;

    // 🔥 OPTIMIZATION: If business selection changed, debounce metrics reload
    // This prevents excessive queries when switching businesses quickly
    final currentBusinessId = business?.id;
    final currentBusinessType = business?.businessType.toLowerCase();
    if (_lastBusinessId != currentBusinessId && currentBusinessId != null) {
      _lastBusinessId = currentBusinessId;
      _lastBusinessType = currentBusinessType;
      print(
          '[Dashboard] Business changed to $currentBusinessId, scheduling metrics reload and quick action refresh');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _debouncedLoadSalesMetrics();
        if (mounted) {
          _updateQuickActionItems();
        }
      });
    } else if (business != null && _lastBusinessType != currentBusinessType) {
      _lastBusinessType = currentBusinessType;
      print(
          '[Dashboard] Business type changed to $currentBusinessType, refreshing quick actions');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateQuickActionItems();
        }
      });
    }

    return RefreshIndicator(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 118),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserHeader(user, isDark),
              const SizedBox(height: 26),

              // Search Bar
              _buildSearchBar(isDark)
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 100.ms)
                  .slideY(begin: -0.1),
              const SizedBox(height: 16),

              // Business Info Card or Switcher
              if (business != null) ...[
                _buildBusinessCard(business, isDark)
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 200.ms)
                    .scale(begin: const Offset(0.5, 0.5)),
                const SizedBox(height: 14),

                _buildQuickMetrics(
                  isDark,
                  businessType: business.businessType,
                  sales: _todaySales,
                  transactions: _todayTransactions,
                  revenue: _todayRevenue,
                  isLoading: _loadingSalesMetrics || isSwitchingBusiness,
                  customersCount: isSwitchingBusiness ? 0 : _customersCount,
                  workersCount: isSwitchingBusiness ? 0 : liveWorkersCount,
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
                const SizedBox(height: 28),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Quick Actions',
                        style: AppTextStyles.heading5.copyWith(
                          color: isDark
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onOpenWorkTab,
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.white.withOpacity(0.70)
                            : Theme.of(context).colorScheme.primary,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(74, 36),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('View all'),
                          SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded, size: 18),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
                const SizedBox(height: 10),

                // Build quick actions, allow dynamic insertion for Gas businesses
                Builder(builder: (ctx) {
                  final bp = ctx.watch<BusinessProvider>();
                  final current = bp.currentBusiness;
                  final actions = List<_QuickActionItem>.from(_filteredItems);

                  // Add industry-specific quick actions based on business type
                  if (current != null) {
                    final businessType = current.businessType.toLowerCase();

                    if (businessType.contains('pharmacy')) {
                      // Pharmacy specific actions - lead with New Sale,
                      // matching every other business type's POS-first
                      // quick action. "Drug Inventory" is intentionally not
                      // re-inserted here since it's already included in
                      // the base pharmacy quick-actions list below,
                      // avoiding a duplicate entry.
                      actions.insert(
                        0,
                        _QuickActionItem(
                          title: 'New Sale',
                          subtitle: 'Start a sale',
                          icon: Icons.point_of_sale,
                          color: AppColors.pharmacy,
                          route: Routes.pharmacyPos,
                        ),
                      );
                    }  else if (businessType.contains('wholesale')) {
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
                          route: Routes.restaurantMenu,
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

                  final visibleActions = actions
                      .where(_matchesActionVisibility)
                      .fold<List<_QuickActionItem>>(
                    <_QuickActionItem>[],
                    (unique, item) {
                      final key = '${item.title}|${item.route}|${item.subtitle}';
                      final exists = unique.any((existing) =>
                          '${existing.title}|${existing.route}|${existing.subtitle}' ==
                          key);
                      if (!exists) unique.add(item);
                      return unique;
                    },
                  );

                  return _buildQuickActionsGrid(isDark, visibleActions)
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
    final settingsProvider = context.read<SettingsProvider>();
    final fallbackPhoto = settingsProvider.profilePhotoUrl;
    final resolvedPhoto = (user?.photoUrl != null && user!.photoUrl!.isNotEmpty)
        ? user.photoUrl
        : fallbackPhoto;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF2B6BFF), Color(0xFF7C4DFF)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.32),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ProfileAvatar(
            radius: 33,
            backgroundColor: const Color(0xFF111A30),
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
                'Welcome back',
                style: AppTextStyles.body2Secondary.copyWith(
                  color: Colors.white.withOpacity(0.62),
                  fontSize: 13,
                ),
              ),
              Text(
                user?.fullName ?? 'User',
                style: AppTextStyles.heading4.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Builder(builder: (ctx) {
                final bp = ctx.watch<BusinessProvider>();
                final current = bp.currentBusiness;
                return Row(
                  children: [
                    Icon(
                      Icons.storefront_rounded,
                      size: 15,
                      color: Colors.white.withOpacity(0.72),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        bp.isSwitchingBusiness
                            ? 'Syncing workspace...'
                            : current?.name ?? 'No business selected',
                        style: AppTextStyles.body2.copyWith(
                          color: Colors.white.withOpacity(0.72),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const BusinessSwitcher(),
                  ],
                );
              }),
            ],
          ),
        ),
        _headerIconButton(
          tooltip: 'Add Business',
          icon: Icons.add_business_rounded,
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
        ),
        const SizedBox(width: 8),
        _headerIconButton(
          tooltip: 'Notifications',
          icon: Icons.notifications_rounded,
          onPressed: () => Navigator.pushNamed(context, Routes.notifications),
          showDot: true,
        ),
      ],
    );
  }

  Widget _headerIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    bool showDot = false,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: 21),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF111A30),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        if (showDot)
          Positioned(
            top: 6,
            right: 7,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF2F6BFF),
                shape: BoxShape.circle,
              ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final fieldColor = isDark ? const Color(0xFF091224) : colorScheme.surface;
    final textColor = isDark ? Colors.white : colorScheme.onSurface;
    final borderColor =
        isDark ? Colors.white.withOpacity(0.08) : colorScheme.outlineVariant;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: fieldColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: AppTextStyles.body1.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search actions, features...',
          hintStyle: AppTextStyles.body2.copyWith(
            color: textColor.withOpacity(0.42),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: textColor.withOpacity(0.48),
            size: 24,
          ),
          suffixIcon: Container(
            width: 42,
            height: 42,
            margin: const EdgeInsets.only(right: 7),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(21),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: IconButton(
              tooltip: _searchController.text.isEmpty ? 'Filter' : 'Clear search',
              onPressed: () {
                if (_searchController.text.isNotEmpty) {
                  _searchController.clear();
                } else {
                  _showActionFilterSheet();
                }
              },
              icon: Icon(
                _searchController.text.isEmpty
                    ? Icons.tune_rounded
                    : Icons.close_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          filled: false,
        ),
        cursorColor: AppColors.primary,
      ),
    );
  }

  Widget _buildBusinessCard(BusinessModel business, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    final businessProvider = context.watch<BusinessProvider>();
    final isSyncingThisBusiness = businessProvider.isSwitchingBusiness &&
        businessProvider.pendingBusinessId == business.id;
    final logoUrl = business.photoUrl ?? business.logoUrl;
    final daysLeft = business.subscriptionEndDate == null
        ? null
        : (business.subscriptionEndDate!.difference(DateTime.now()).inDays)
            .clamp(0, 999);
    final businessInitial = business.name.isNotEmpty
        ? business.name.trim()[0].toUpperCase()
        : '?';
    final cardGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF24366E), Color(0xFF182A59), Color(0xFF222D65)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [
              colorScheme.primaryContainer.withOpacity(0.92),
              colorScheme.surface,
              colorScheme.secondaryContainer.withOpacity(0.72),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final cardText = isDark ? Colors.white : colorScheme.onSurface;
    final mutedCardText =
        isDark ? Colors.white.withOpacity(0.78) : colorScheme.onSurfaceVariant;
    final softOverlay =
        isDark ? Colors.white.withOpacity(0.10) : colorScheme.surface;

    return GestureDetector(
      onTap: () => widget.onOpenWorkTab?.call(),
      onLongPress: _showBusinessSwitcherSheet,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: cardGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? const Color(0xFF5F6EFF).withOpacity(0.34)
                : colorScheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? const Color(0xFF1C2D73).withOpacity(0.40)
                  : Colors.black.withOpacity(0.07),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: softOverlay,
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.10)
                              : colorScheme.outlineVariant,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: logoUrl != null && logoUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: logoUrl,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Center(
                                  child: Text(
                                    businessInitial,
                                    style: TextStyle(
                                      color: cardText,
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  businessInitial,
                                  style: TextStyle(
                                    color: cardText,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      right: 7,
                      bottom: 7,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF27D35F),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF24366E)
                                : colorScheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.10)
                              : colorScheme.surface.withOpacity(0.82),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF27D35F),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isSyncingThisBusiness ? 'Syncing business' : 'Active business',
                              style: AppTextStyles.caption.copyWith(
                                color: cardText,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        business.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.heading4.copyWith(
                          color: cardText,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        BusinessTypes.getName(business.businessType),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body2.copyWith(
                          color: mutedCardText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0B1428).withOpacity(0.48)
                              : colorScheme.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          business.subscriptionTier.toUpperCase(),
                          style: AppTextStyles.caption.copyWith(
                            color: isDark ? Colors.white : colorScheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildBusinessActionButton(
                  icon: Icons.swap_horiz_rounded,
                  tooltip: 'Switch Business',
                  onPressed: _showBusinessSwitcherSheet,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
                _buildBusinessMetaPill(
                  icon: Icons.inventory_2_outlined,
                  label: '${business.totalProducts ?? 0} Products',
                ),
                _buildBusinessMetaPill(
                  icon: Icons.people_alt_outlined,
                  label: '${business.totalCustomers ?? 0} Customers',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => widget.onOpenWorkTab?.call(),
                      icon: const Icon(Icons.business_center_outlined, size: 19),
                      label: const Text('Open Workspace'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.white.withOpacity(0.08)
                            : colorScheme.primary,
                        foregroundColor:
                            isDark ? Colors.white : colorScheme.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest.withOpacity(0.92)
            : colorScheme.surface.withOpacity(0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? colorScheme.outlineVariant.withOpacity(0.82)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark ? colorScheme.onSurfaceVariant : colorScheme.primary,
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: colorScheme.onSurface,
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    return SizedBox(
      width: 50,
      height: 50,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: colorScheme.onSurface),
        style: IconButton.styleFrom(
          backgroundColor: isDark
              ? colorScheme.surfaceContainerHighest.withOpacity(0.9)
              : colorScheme.surface.withOpacity(0.82),
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
    int totalProperties = 0,
    int occupiedUnits = 0,
    int vacantUnits = 0,
    int overdueRents = 0,
    double monthlyRentCollection = 0.0,
    bool isLoadingRealEstate = false,
  }) {
    final type = businessType.toLowerCase().replaceAll(' ', '');
    final isRealEstate = type == 'realestate';
    final averageTicket = transactions > 0 ? revenue / transactions : 0.0;

    final metrics = isRealEstate
        ? [
            _MetricView('Properties', isLoadingRealEstate ? '...' : totalProperties.toString(), Icons.apartment_rounded, const Color(0xFF169BFF), Routes.realEstateProperties),
            _MetricView('Occupied', isLoadingRealEstate ? '...' : occupiedUnits.toString(), Icons.home_rounded, const Color(0xFF28C76F), Routes.realEstateProperties),
            _MetricView('Vacant', isLoadingRealEstate ? '...' : vacantUnits.toString(), Icons.home_work_rounded, const Color(0xFFFFB020), Routes.realEstateProperties),
            _MetricView('Overdue', isLoadingRealEstate ? '...' : overdueRents.toString(), Icons.warning_rounded, const Color(0xFF9B5CFF), Routes.realEstateRentCollection),
            _MetricView('Monthly Rent', isLoadingRealEstate ? '...' : formatCurrency(monthlyRentCollection), Icons.query_stats_rounded, const Color(0xFF10C6FF), Routes.realEstateRentCollection),
          ]
        : [
            _MetricView('Sales', isLoading ? '...' : formatCurrency(sales), Icons.shopping_bag_rounded, const Color(0xFF169BFF), Routes.salesHistory),
            _MetricView('Orders', isLoading ? '...' : transactions.toString(), Icons.receipt_rounded, const Color(0xFF28C76F), Routes.salesReport),
            _MetricView('Customers', isLoadingCounts ? '...' : customersCount.toString(), Icons.people_rounded, const Color(0xFFFFB020), Routes.customers),
            _MetricView('Workers', isLoadingCounts ? '...' : workersCount.toString(), Icons.badge_rounded, const Color(0xFF9B5CFF), Routes.workers),
            _MetricView('Avg Ticket', isLoading ? '...' : formatCurrency(averageTicket), Icons.query_stats_rounded, const Color(0xFF10C6FF), Routes.advancedAnalytics),
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF101A2F).withOpacity(0.96)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.24 : 0.07),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = (constraints.maxWidth - 2) / 3;
          return Wrap(
            spacing: 1,
            runSpacing: 1,
            children: [
              for (final metric in metrics.take(5))
                SizedBox(
                  width: cellWidth,
                  height: 72,
                  child: _buildMetricTile(metric),
                ),
              SizedBox(
                width: cellWidth,
                height: 72,
                child: _buildMiniChartTile(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricTile(_MetricView metric) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    return InkWell(
      onTap: metric.route != null ? () => Navigator.pushNamed(context, metric.route!) : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: metric.color.withOpacity(0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(metric.icon, color: metric.color, size: 17),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subtitle2.copyWith(
                      color: isDark ? Colors.white : colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    metric.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: isDark
                          ? Colors.white.withOpacity(0.56)
                          : colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniChartTile() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _selectMetricRange,
      child: Padding(
        padding: const EdgeInsets.only(left: 6, right: 2, top: 6, bottom: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: CustomPaint(
                painter: _MiniChartPainter(),
                child: const SizedBox.expand(),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0B1428).withOpacity(0.72)
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedMetricRangeLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: isDark ? Colors.white : colorScheme.onSurface,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.white : colorScheme.onSurface,
                    size: 13,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallStatChip(String value, String label, {VoidCallback? onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(isDark ? 0.92 : 1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(isDark ? 0.85 : 0.75),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Text(
                value,
                style: AppTextStyles.caption.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(bool isDark,
      [List<_QuickActionItem>? actions]) {
    final list = (actions ?? _filteredItems).take(12).toList();
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 84,
            child: _buildActionCard(list[index], index, isDark),
          );
        },
      ),
    );
  }

  Widget _buildActionCard(_QuickActionItem item, int index, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor =
        isDark ? const Color(0xFF111A30) : colorScheme.surface;
    final textColor = isDark ? Colors.white : colorScheme.onSurface;
    final handleTap = () {
      if (item.opensSupportWhatsapp) {
        _openSupportWhatsApp();
        return;
      }
      if (item.route != null) {
        Navigator.pushNamed(context, item.route!);
      }
    };

    return GestureDetector(
      onTap: handleTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.07)
                : colorScheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.20 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: item.color, size: 23),
            ),
            const Spacer(),
            Text(
              item.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.subtitle,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: isDark
                    ? Colors.white.withOpacity(0.52)
                    : colorScheme.onSurfaceVariant,
                fontSize: 9,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .scale(
          duration: 400.ms,
          delay: Duration(milliseconds: 120 + (index * 25)),
        )
        .fadeIn(duration: 450.ms);
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
      case 'bakery':
        screen = const RetailDashboard.bakery();
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
        screen = GasDashboardScreen(
          mode: FuelStationScope.isPetroleumBusiness(businessType)
              ? FuelStationMode.petroleum
              : FuelStationMode.gas,
        );
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

  List<_QuickActionItem> _getQuickActionItems([String? businessType]) {
    final type = (businessType?.toLowerCase() ?? 'retail')
        .replaceAll('_', '') // Remove underscores
        .replaceAll(' ', ''); // Remove spaces

    // Common items for all business types
    final commonItems = [
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
        title: 'Support',
        subtitle: 'Contact care',
        icon: Icons.support_agent_rounded,
        color: Colors.green,
        opensSupportWhatsapp: true,
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
            title: 'Inventory',
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
          _QuickActionItem(
            title: 'New Sale',
            subtitle: 'Create transaction',
            icon: Icons.point_of_sale_rounded,
            color: Colors.green,
            route: Routes.sales,
          ),
          _QuickActionItem(
            title: 'Low Stock',
            subtitle: 'View alerts',
            icon: Icons.warning_rounded,
            color: Colors.orange,
            route: Routes.lowStockProducts,
          ),
          _QuickActionItem(
            title: 'Expiry Tracker',
            subtitle: 'Track expiring stock',
            icon: Icons.event_busy_rounded,
            color: Colors.red,
            route: Routes.expiryTracker,
          ),
          _QuickActionItem(
            title: 'Procurement',
            subtitle: 'Manage inventory',
            icon: Icons.shopping_cart_rounded,
            color: Colors.teal,
            route: Routes.procurement,
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
            title: 'Mechanic Schedule',
            subtitle: 'Staff schedules',
            icon: Icons.schedule_rounded,
            color: Colors.purple,
            route: Routes.autoMechanicSchedule,
          ),
          _QuickActionItem(
            title: 'Services',
            subtitle: 'Manage service presets',
            icon: Icons.build_circle_outlined,
            color: Colors.indigo,
            route: Routes.autoServices,
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
          _QuickActionItem(
            title: 'New Sale',
            subtitle: 'Create transaction',
            icon: Icons.point_of_sale_rounded,
            color: Colors.green,
            route: Routes.sales,
          ),
          _QuickActionItem(
            title: 'Low Stock',
            subtitle: 'View alerts',
            icon: Icons.warning_rounded,
            color: Colors.orange,
            route: Routes.lowStockProducts,
          ),
          _QuickActionItem(
            title: 'Expiry Tracker',
            subtitle: 'Track expiring stock',
            icon: Icons.event_busy_rounded,
            color: Colors.red,
            route: Routes.expiryTracker,
          ),
          _QuickActionItem(
            title: 'Procurement',
            subtitle: 'Manage inventory',
            icon: Icons.shopping_cart_rounded,
            color: Colors.teal,
            route: Routes.procurement,
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
          _QuickActionItem(
            title: 'New Order',
            subtitle: 'Take restaurant orders',
            icon: Icons.post_add_rounded,
            color: Colors.green,
            route: Routes.restaurantMenu,
          ),
          _QuickActionItem(
            title: 'Orders History',
            subtitle: 'Track service and checkout',
            icon: Icons.receipt_long_rounded,
            color: Colors.green,
            route: Routes.restaurantOrders,
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
            title: 'New Sale',
            subtitle: 'Create transaction',
            icon: Icons.point_of_sale_rounded,
            color: Colors.green,
            route: Routes.sales,
          ),
          _QuickActionItem(
            title: 'Inventory',
            subtitle: 'Beverage stock',
            icon: Icons.inventory_2_rounded,
            color: Colors.green,
            route: Routes.inventory,
          ),
          _QuickActionItem(
            title: 'Tabs',
            subtitle: 'Customer tabs',
            icon: Icons.account_balance_wallet_rounded,
            color: Colors.teal,
            route: Routes.drinkTabs,
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
            title: 'Pump Upload',
            subtitle: 'Daily total sales',
            icon: Icons.cloud_upload_rounded,
            color: Colors.indigo,
            route: Routes.gasPumpUpload,
          ),
          _QuickActionItem(
            title: 'Pump Upload History',
            subtitle: 'Pump daily uploads',
            icon: Icons.fact_check_rounded,
            color: Colors.deepPurple,
            route: Routes.gasPumpUploadHistory,
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
            subtitle: 'Pump and minimart sales',
            icon: Icons.history_rounded,
            color: Colors.orange,
            route: Routes.gasSalesHistory,
          ),
           _QuickActionItem(
            title: 'Mini Mart Sale',
            subtitle: 'Sell retail station items',
            icon: Icons.point_of_sale_rounded,
            color: Colors.green,
            route: Routes.retailPos,
          ),
          _QuickActionItem(
            title: 'Inventory',
            subtitle: 'Beverage stock',
            icon: Icons.inventory_2_rounded,
            color: Colors.green,
            route: Routes.inventory,
          ),
          _QuickActionItem(
            title: 'Expenses',
            subtitle: 'Record expenses',
            icon: Icons.receipt_long_rounded,
            color: Colors.brown,
            route: Routes.expenseReport,
          ),
          _QuickActionItem(
            title: 'Attendance',
            subtitle: 'Schedules and check-ins',
            icon: Icons.fingerprint_rounded,
            color: Colors.teal,
            route: Routes.attendance,
          ),
          ...commonItems,
        ];

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
        return [
          _QuickActionItem(
            title: 'Pump',
            subtitle: 'Fuel dispensing',
            icon: Icons.local_gas_station_rounded,
            color: Colors.blue,
            route: Routes.petroleumPump,
          ),
          _QuickActionItem(
            title: 'Pump Upload',
            subtitle: 'Daily total sales',
            icon: Icons.cloud_upload_rounded,
            color: Colors.indigo,
            route: Routes.petroleumPumpUpload,
          ),
          _QuickActionItem(
            title: 'Pump Upload History',
            subtitle: 'Pump daily uploads',
            icon: Icons.fact_check_rounded,
            color: Colors.deepPurple,
            route: Routes.petroleumPumpUploadHistory,
          ),
          _QuickActionItem(
            title: 'Stock',
            subtitle: 'Fuel inventory',
            icon: Icons.inventory_2_rounded,
            color: Colors.green,
            route: Routes.petroleumStock,
          ),
          _QuickActionItem(
            title: 'Sales History',
            subtitle: 'Pump and minimart sales',
            icon: Icons.history_rounded,
            color: Colors.orange,
            route: Routes.petroleumSalesHistory,
          ),
          _QuickActionItem(
            title: 'Mini Mart Sale',
            subtitle: 'Sell retail station items',
            icon: Icons.point_of_sale_rounded,
            color: Colors.green,
            route: Routes.retailPos,
          ),
          _QuickActionItem(
            title: 'Inventory',
            subtitle: 'Station shop stock',
            icon: Icons.inventory_2_rounded,
            color: Colors.green,
            route: Routes.inventory,
          ),
          _QuickActionItem(
            title: 'Expenses',
            subtitle: 'Record expenses',
            icon: Icons.receipt_long_rounded,
            color: Colors.brown,
            route: Routes.expenseReport,
          ),
          _QuickActionItem(
            title: 'Attendance',
            subtitle: 'Schedules and check-ins',
            icon: Icons.fingerprint_rounded,
            color: Colors.teal,
            route: Routes.attendance,
          ),
          ...commonItems,
        ];

      case 'bakery':
      case 'bakeryshop':
      case 'bakeshop':
        return [
          _QuickActionItem(
            title: 'Bakery POS',
            subtitle: 'Sell bread and pastries',
            icon: Icons.bakery_dining_rounded,
            color: const Color(0xFFD97706),
            route: Routes.retailPos,
          ),
          _QuickActionItem(
            title: 'Bakery Items',
            subtitle: 'Manage baked goods',
            icon: Icons.inventory_2_rounded,
            color: Colors.blue,
            route: Routes.inventory,
          ),
          _QuickActionItem(
            title: 'Freshness Tracker',
            subtitle: 'Monitor expiry and batches',
            icon: Icons.event_busy_rounded,
            color: Colors.red,
            route: Routes.expiryTracker,
          ),
          _QuickActionItem(
            title: 'Low Stock',
            subtitle: 'Ingredients and products',
            icon: Icons.warning_rounded,
            color: Colors.orange,
            route: Routes.lowStockProducts,
          ),
          _QuickActionItem(
            title: 'Procurement',
            subtitle: 'Buy ingredients and stock',
            icon: Icons.shopping_cart_rounded,
            color: Colors.teal,
            route: Routes.procurement,
          ),
          _QuickActionItem(
            title: 'Suppliers',
            subtitle: 'Ingredient vendors',
            icon: Icons.local_shipping_rounded,
            color: Colors.brown,
            route: Routes.retailSuppliers,
          ),
          _QuickActionItem(
            title: 'Sales History',
            subtitle: 'Daily bakery sales',
            icon: Icons.history_rounded,
            color: Colors.green,
            route: Routes.salesHistory,
          ),
          _QuickActionItem(
            title: 'Reports',
            subtitle: 'Bakery performance',
            icon: Icons.bar_chart_rounded,
            color: Colors.indigo,
            route: Routes.retailStoreReports,
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
      case 'bakery':
        print('[MenuTab] Loading BakeryDashboard');
        screen = const RetailDashboard.bakery();
        break;
      case 'gas':
      case 'petroleum':
      case 'petrolstation':
      case 'petroleumstation':
      case 'fillingstation':
        print('[MenuTab] Loading GasDashboardScreen');
        screen = GasDashboardScreen(
          mode: FuelStationScope.isPetroleumBusiness(primaryType)
              ? FuelStationMode.petroleum
              : FuelStationMode.gas,
        );
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

class _MetricView {
  const _MetricView(
    this.label,
    this.value,
    this.icon,
    this.color,
    this.route,
  );

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? route;
}

class _MiniChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.72)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.44,
        size.width * 0.28,
        size.height * 0.56,
        size.width * 0.42,
        size.height * 0.36,
      )
      ..cubicTo(
        size.width * 0.56,
        size.height * 0.18,
        size.width * 0.68,
        size.height * 0.54,
        size.width * 0.82,
        size.height * 0.28,
      )
      ..cubicTo(
        size.width * 0.92,
        size.height * 0.38,
        size.width,
        size.height * 0.24,
        size.width,
        size.height * 0.48,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF9B5CFF), Color(0xFF3A6DFF), Color(0xFF11D6FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);

    canvas.drawPath(path, paint);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0xFFB78BFF), Color(0xFF72A1FF)],
      ).createShader(Offset.zero & size);

    final line = Path()
      ..moveTo(0, size.height * 0.72)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.44,
        size.width * 0.28,
        size.height * 0.56,
        size.width * 0.42,
        size.height * 0.36,
      )
      ..cubicTo(
        size.width * 0.56,
        size.height * 0.18,
        size.width * 0.68,
        size.height * 0.54,
        size.width * 0.82,
        size.height * 0.28,
      )
      ..cubicTo(
        size.width * 0.92,
        size.height * 0.38,
        size.width,
        size.height * 0.24,
        size.width,
        size.height * 0.48,
      );

    canvas.drawPath(line, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
  final String? route;
  final bool opensSupportWhatsapp;

  _QuickActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.route,
    this.opensSupportWhatsapp = false,
  });
}
