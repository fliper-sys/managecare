import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../../../../providers/drink_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../services/analytics_service.dart';
import 'worker_onboarding_screen.dart';

class DrinkDashboardScreen extends StatefulWidget {
  const DrinkDashboardScreen({super.key});

  @override
  State<DrinkDashboardScreen> createState() => _DrinkDashboardScreenState();
}

class _DrinkDashboardScreenState extends State<DrinkDashboardScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 2;
  late AnimationController _pulseController;
  @override
  void initState() {
    super.initState();
    // Ensure drink provider is initialized when this screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureDrinkProviderInitialized();
    });
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
  }

  Widget _buildWorkPlaceholder() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset('assets/lottie/website-building-of-shopping-sale.json',
                  width: 160, height: 160, repeat: true),
              const SizedBox(height: 12),
              Text('Work Hub',
                  style: AppTextStyles.heading4
                      .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  'Quick tools for floor staff: open sales, manage orders and start shifts.',
                  style: AppTextStyles.body2Secondary,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
                ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, Routes.sales),
                    icon: const Icon(Icons.point_of_sale),
                    label: const Text('New Sale')),
                OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, Routes.drinkOrders),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Open Orders')),
                OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, Routes.drinkTabs),
                    icon: const Icon(Icons.tab),
                    label: const Text('Open Tabs')),
              ])
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _ensureDrinkProviderInitialized() {
    final businessProvider = context.read<BusinessProvider>();
    final drinkProvider = context.read<DrinkProvider>();
    final businessId = businessProvider.currentBusiness?.id;

    if (kDebugMode) debugPrint('[DrinkDashboard] Initializing provider');
    if (kDebugMode) debugPrint('[DrinkDashboard] Business ID: $businessId');
    if (kDebugMode)
      debugPrint(
          '[DrinkDashboard] Current drinks count: ${drinkProvider.drinks.length}');

    if (businessId != null && businessId.isNotEmpty) {
      // Set the business ID for Firestore queries
      drinkProvider.setBusinessId(businessId);
      if (kDebugMode)
        debugPrint('[DrinkDashboard] Business ID set for Firestore');

      // The provider should already be initialized via ProxyProvider,
      // but we can trigger a refresh here if needed
      if (drinkProvider.drinks.isEmpty) {
        if (kDebugMode)
          debugPrint(
              '[DrinkDashboard] No drinks loaded, initializing provider');
      }
    }
  }

  bool _canManageBarInventory(AuthProvider authProvider) {
    final role = authProvider.currentUser?.role ?? '';
    return authProvider.isOwnerUser ||
        WorkerPermissions.canManageInventory(role);
  }

  bool _canManageBarProcurement(AuthProvider authProvider) {
    final role = authProvider.currentUser?.role ?? '';
    return authProvider.isOwnerUser ||
        WorkerPermissions.hasPermission(role, 'procurement_management');
  }

  void _showPermissionDenied(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ignore: unused_element
  Future<void> _handleRefresh() async {
    final auth = context.read<AuthProvider>();
    final businessProv = context.read<BusinessProvider>();
    final drinkProv = context.read<DrinkProvider>();
    // Ensure we have the latest user doc before using business info
    try {
      await auth.refresh();
    } catch (_) {}

    final userId = auth.currentUser?.id ?? '';
    try {
      if (userId.isNotEmpty) {
        // Reload user's businesses and ensure the preferred/current business is set
        await businessProv.loadUserBusinesses(userId,
            preferredBusinessId: auth.currentUser?.preferredBusinessId,
            userBusinessIds: auth.currentUser?.businessIds);
      }

      final businessId = businessProv.currentBusiness?.id ??
          auth.currentUser?.businessId ??
          '';
      if (businessId.isNotEmpty) {
        // Ensure drink provider queries the right business
        drinkProv.setBusinessId(businessId);

        // Trigger some reads to ensure UI data refreshes from the backend
        await drinkProv.getTotalSalesFromRemote();
        await drinkProv.getTodaysSalesTotal();
      }

      // Update analytics with the current user and business
      try {
        final analytics = AnalyticsService();
        if (auth.currentUser?.id != null && auth.currentUser!.id.isNotEmpty) {
          await analytics.setUserId(auth.currentUser!.id);
        }
        if (businessId.isNotEmpty) {
          await analytics.setUserProperties({'businessId': businessId});
        }
      } catch (_) {}
    } catch (e) {
      if (kDebugMode) debugPrint('[DrinkDashboard] Refresh failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Refresh failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final canManageInventory = _canManageBarInventory(authProvider);
    final canManageProcurement = _canManageBarProcurement(authProvider);
    final isRestrictedWorker =
        !authProvider.isOwnerUser && !canManageInventory && !canManageProcurement;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Bar Management'),
        backgroundColor: Colors.brown.shade700,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.school_outlined),
            tooltip: 'Worker Training',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkerOnboardingScreen(
                  workerName: authProvider.currentUser?.fullName ?? 'Worker',
                  workerId: authProvider.currentUser?.id ?? '',
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Manage Workers',
            onPressed: authProvider.isOwnerUser ||
                    WorkerPermissions.canManageStaff(
                      authProvider.currentUser?.role ?? '',
                    )
                ? () => Navigator.pushNamed(context, Routes.workers)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              try {
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed(Routes.login);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logout failed: $e')));
                }
              }
            },
          ),
        ],
      ),
      body: _selectedIndex == 2
          ? _buildWorkPlaceholder()
          : Consumer<DrinkProvider>(
              builder: (context, drinkProvider, _) {
                if (kDebugMode)
                  debugPrint(
                      '[DrinkDashboard] Building body, drinks: ${drinkProvider.drinks.length}');

                final openOrders = drinkProvider.getOpenOrders();
                final lowStock = drinkProvider.getLowStockDrinks();

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Worker Quick Actions (if worker role)
                      if (isRestrictedWorker)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: _buildWorkerQuickActions(context),
                        ),

                      // Hero header
                      _buildHeader(
                        context,
                        drinkProvider,
                        canManageProcurement: canManageProcurement,
                      ),
                      const SizedBox(height: 16),

                      // Stats row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                icon: '💰',
                                label: 'Today\'s Sales',
                                valueFuture:
                                    drinkProvider.getTodaysSalesTotal(),
                                color: const Color(0xFF66BB6A),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                icon: '📋',
                                label: 'Open Orders',
                                value: '${openOrders.length}',
                                color: const Color(0xFF42A5F5),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Animated Low Stock Alert
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildAlertCard(lowStock.length),
                      ),

                      const SizedBox(height: 20),

                      // Quick Actions (for all users)
                      if (!isRestrictedWorker)
                        _buildAdminQuickActions(
                          context,
                          canManageInventory: canManageInventory,
                          canManageProcurement: canManageProcurement,
                        ),

                      // Stock Overview
                      Text(
                        'Stock Overview',
                        style: AppTextStyles.heading5.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (drinkProvider.drinks.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 32, horizontal: 16),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.local_bar_outlined,
                                  size: 48,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Products Added',
                                  style: AppTextStyles.heading5.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Add products from the inventory section to see them here',
                                  style: AppTextStyles.body2Secondary,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: Text(
                                    canManageProcurement
                                        ? 'Add Product'
                                        : 'Open Sales',
                                  ),
                                  onPressed: () {
                                    if (canManageProcurement) {
                                      Navigator.pushNamed(
                                        context,
                                        Routes.procurement,
                                      );
                                      return;
                                    }
                                    Navigator.pushNamed(context, Routes.drinkPos);
                                  },
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: drinkProvider.drinks.length,
                          itemBuilder: (context, index) {
                            final drink = drinkProvider.drinks[index];
                            final stock = drinkProvider.getStock(drink.id);
                            final total =
                                drinkProvider.getTotalBottles(drink.id);
                            final isLow = total <= 6;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 12),
                                child: Row(
                                  children: [
                                    // Avatar / image
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: colorScheme.surfaceContainer,
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.03),
                                              blurRadius: 6)
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: drink.imageUrl != null
                                            ? CachedNetworkImage(
                                                imageUrl: drink.imageUrl!,
                                                fit: BoxFit.cover)
                                            : Center(
                                                child: Text(drink.emoji,
                                                    style: const TextStyle(
                                                        fontSize: 28))),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Name and details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                  child: Text(drink.name,
                                                      style: AppTextStyles.body2
                                                          .copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold))),
                                              const SizedBox(width: 8),
                                              if (canManageInventory)
                                                PopupMenuButton<String>(
                                                  padding: EdgeInsets.zero,
                                                  itemBuilder: (_) => const [
                                                    PopupMenuItem(
                                                      value: 'edit',
                                                      child: Text('Edit'),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'stock',
                                                      child: Text('Adjust Stock'),
                                                    ),
                                                  ],
                                                  onSelected: (v) {
                                                    if (v == 'edit') {
                                                      Navigator.pushNamed(
                                                        context,
                                                        Routes.drinkManage,
                                                        arguments: {
                                                          'drinkId': drink.id,
                                                        },
                                                      );
                                                    } else if (v == 'stock') {
                                                      Navigator.pushNamed(
                                                        context,
                                                        Routes.drinkInventory,
                                                      );
                                                    }
                                                  },
                                                  child: Icon(
                                                    Icons.more_vert,
                                                    size: 18,
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                              'Price: ₦${drink.pricePerBottle.toStringAsFixed(2)} · Qty: ${stock?.bottles ?? 0}',
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                      color: AppColors
                                                          .textSecondary)),
                                          const SizedBox(height: 8),

                                          // Progress bar showing fullness of stock relative to a soft cap
                                          Builder(builder: (ctx) {
                                            // Soft capacity: two cartons worth of bottles
                                            final cap =
                                                (drink.bottlesPerCarton * 2)
                                                    .toDouble();
                                            final avail = ((stock?.bottles ??
                                                        0) +
                                                    ((stock?.cartons ?? 0) *
                                                        drink.bottlesPerCarton))
                                                .toDouble();
                                            final pct = cap <= 0
                                                ? 1.0
                                                : (avail / cap).clamp(0.0, 1.0);
                                            return Column(children: [
                                              LinearProgressIndicator(
                                                  value: pct,
                                                  color: isLow
                                                      ? Colors.orange
                                                      : Colors.green,
                                                  backgroundColor:
                                                      colorScheme
                                                          .surfaceContainerHighest,
                                                  minHeight: 6),
                                              const SizedBox(height: 6),
                                              Row(children: [
                                                Text(
                                                    isLow
                                                        ? 'Low stock'
                                                        : 'In stock',
                                                    style: AppTextStyles.caption
                                                        .copyWith(
                                                            color: isLow
                                                                ? Colors.orange
                                                                    .shade700
                                                                : Colors.green
                                                                    .shade700,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                const SizedBox(width: 8),
                                                Text(
                                                    '${(pct * 100).toStringAsFixed(0)}%',
                                                    style: AppTextStyles.caption
                                                        .copyWith(
                                                            color: AppColors
                                                                .textSecondary))
                                              ])
                                            ]);
                                          })
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    DrinkProvider drinkProvider, {
    required bool canManageProcurement,
  }) {
    return Container(
      height: 160,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
            colors: [Colors.brown.shade700, Colors.brown.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Bar Management',
                        style: AppTextStyles.heading4.copyWith(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    FutureBuilder<double>(
                        future: drinkProvider.getTodaysSalesTotal(),
                        builder: (context, snapshot) {
                          final todaysSales = snapshot.data ?? 0.0;
                          return Text(
                              'Today: ₦${todaysSales.toStringAsFixed(2)}',
                              style: AppTextStyles.subtitle1
                                  .copyWith(color: Colors.white));
                        }),
                    const SizedBox(height: 12),
                    Row(children: [
                      ElevatedButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, Routes.sales),
                          icon: const Icon(Icons.point_of_sale_outlined),
                          label: const Text('New Sale'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.brown.shade700)),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24)),
                        onPressed: () {
                          if (!canManageProcurement) {
                            _showPermissionDenied(
                              'You do not have permission to manage procurement.',
                            );
                            return;
                          }
                          Navigator.pushNamed(context, Routes.procurement);
                        },
                        child: const Text('Procurement'),
                      ),
                    ])
                  ]),
            ),
          ),
          Expanded(
              flex: 3,
              child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                          width: 80,
                          height: 80,
                          child: Lottie.asset('assets/lottie/onboard2.json',
                              repeat: true))))),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      {required String icon,
      required String label,
      String? value,
      Future<double>? valueFuture,
      required Color color}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Text(icon, style: const TextStyle(fontSize: 28))),
        const SizedBox(height: 16),
        valueFuture != null
            ? FutureBuilder<double>(
                future: valueFuture,
                builder: (context, s) {
                  final val = s.data ?? 0.0;
                  return Text('₦${val.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color));
                })
            : Text(value ?? '-',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 13,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ]),
    );
  }

  Widget _buildAlertCard(int lowStockCount) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(const Color(0xFFFFB74D), const Color(0xFFFFA726),
                      _pulseController.value)!,
                  const Color(0xFFFFA726)
                ]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.orange
                      .withOpacity(0.3 + _pulseController.value * 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 28)),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Low Stock Alert',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$lowStockCount items need restocking',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12))
                ])),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20)),
                child: Text('$lowStockCount',
                    style: const TextStyle(
                        color: Color(0xFFFFA726),
                        fontSize: 16,
                        fontWeight: FontWeight.bold))),
          ]),
        );
      },
    );
  }

  Widget _buildBottomNavBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration:
          BoxDecoration(color: colorScheme.surfaceContainerHighest, boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5))
      ]),
      child: SafeArea(
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(Icons.home_outlined, 'Home', 0),
                    _buildNavItem(Icons.bar_chart_outlined, 'Reports', 1),
                    _buildNavItem(Icons.grid_view_rounded, 'Work', 2),
                    _buildNavItem(Icons.person_outline, 'Profile', 3),
                  ]))),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedIndex == index;
    return InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF5D4037).withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon,
                  color:
                      isSelected
                          ? const Color(0xFF5D4037)
                          : colorScheme.onSurfaceVariant,
                  size: 24),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? const Color(0xFF5D4037)
                          : colorScheme.onSurfaceVariant))
            ])));
  }

  Widget _buildWorkerQuickActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_bar, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Ready to take orders?',
                style: AppTextStyles.subtitle1.copyWith(
                  color: Colors.blue.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, Routes.drinkPos),
              icon: const Icon(Icons.point_of_sale),
              label: const Text('New Sale'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminQuickActions(
    BuildContext context, {
    required bool canManageInventory,
    required bool canManageProcurement,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: AppTextStyles.heading5.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _ActionTile(
                icon: Icons.point_of_sale,
                label: 'New Sale',
                color: Colors.blue,
                onTap: () => Navigator.pushNamed(context, Routes.drinkPos),
              ),
             
              _ActionTile(
                icon: Icons.receipt_long,
                label: 'Orders',
                color: Colors.purple,
                onTap: () => Navigator.pushNamed(context, Routes.drinkOrders),
              ),
              _ActionTile(
                icon: Icons.tab,
                label: 'Tabs & Invoices',
                color: Colors.orange,
                onTap: () => Navigator.pushNamed(context, Routes.drinkTabs),
              ),
              _ActionTile(
                icon: Icons.print,
                label: 'Printer Settings',
                color: Colors.teal,
                onTap: () => Navigator.pushNamed(context, Routes.printerSettings),
              ),
              if (canManageProcurement)
                _ActionTile(
                  icon: Icons.receipt_long,
                  label: 'Procurement',
                  color: Colors.deepPurple,
                  onTap: () => Navigator.pushNamed(context, Routes.procurement),
                ),
              if (canManageInventory)
                _ActionTile(
                  icon: Icons.inventory_2_outlined,
                  label: 'Inventory',
                  color: Colors.indigo,
                  onTap: () => Navigator.pushNamed(context, Routes.drinkInventory),
                ),
              _ActionTile(
                icon: Icons.support_agent_rounded,
                label: 'Customer Care',
                color: Colors.green,
                onTap: () => WhatsAppUtils.openCustomerSupport(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.body2.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

