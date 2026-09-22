import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/whatsapp_utils.dart';

import '../../../../core/constants/routes.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/hotel_provider.dart';
import '../../../../providers/drink_provider.dart';
import '../../../industry_specific/restaurant/providers/restaurant_provider.dart';

class HotelDashboardScreen extends StatefulWidget {
  const HotelDashboardScreen({super.key});

  @override
  State<HotelDashboardScreen> createState() => _HotelDashboardScreenState();
}

class _HotelNavigationItem {
  final String label;
  final String category;
  final IconData icon;
  final Color color;
  final String? route;
  final String? permission;

  const _HotelNavigationItem({
    required this.label,
    required this.category,
    required this.icon,
    required this.color,
    this.route,
    this.permission,
  });
}

class _HotelDashboardScreenState extends State<HotelDashboardScreen> {
  String? _loadedBusinessId;
  String _selectedCategory = 'General';
  String _searchQuery = '';
  String _selectedRevenuePeriod = 'Daily';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshDashboard() async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id;
    if (businessId == null || businessId.isEmpty) return;
    await context.read<HotelProvider>().refresh();
    await context.read<RestaurantProvider>().initializeOrders(
          businessId: businessId,
        );
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final businessId = context.watch<BusinessProvider>().currentBusiness?.id;
    if (businessId == null ||
        businessId.isEmpty ||
        businessId == _loadedBusinessId) {
      return;
    }
    _loadedBusinessId = businessId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HotelProvider>().setBusinessId(businessId);
    });
  }

    // --- SUMMARY HEADER (Revenue, Active Rooms, Customers) ---
    Widget _buildSummaryHeader(HotelProvider provider) {
      return FutureBuilder<double>(
        future: provider.getTodaysSalesTotal(),
        builder: (context, snapshot) {
          final todaysRevenue = snapshot.data ?? 0.0;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withOpacity(0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 5))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryTile(
                  icon: Icons.payments_outlined,
                  label: 'Revenue (Today)',
                  value: formatCurrency(todaysRevenue, decimalDigits: 0),
                  color: Colors.greenAccent.shade100,
                ),
                _buildSummaryTile(
                  icon: Icons.hotel_outlined,
                  label: 'Active Occupancy',
                  value: '${provider.occupiedRooms}/${provider.totalRooms}',
                  color: Colors.blue.shade100,
                ),
                _buildSummaryTile(
                  icon: Icons.people_alt_outlined,
                  label: 'Customers',
                  value: '${provider.guestProfiles.length}',
                  color: Colors.amber.shade100,
                ),
                _buildSummaryTile(
                  icon: Icons.badge_outlined,
                  label: 'Workers',
                  value:
                      '${Provider.of<BusinessProvider>(context, listen: false).currentBusiness?.totalWorkers ?? 0}',
                  color: Colors.purple.shade100,
                ),
              ],
            ),
          );
        },
      );
    }

    Widget _buildSummaryTile({
      required IconData icon,
      required String label,
      required String value,
      required Color color,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.black87, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      );
    }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final role = user?.role ?? '';
    final permissions = user?.permissions ?? const <String>[];
    bool canOpen(_HotelNavigationItem item) =>
        item.permission == null ||
        WorkerPermissions.hasEffectivePermission(
          role,
          permissions,
          item.permission!,
        );
    final items = _navigationItems
        .where((item) => item.category == _selectedCategory)
        .where((item) => _searchQuery.isEmpty ||
            item.label.toLowerCase().contains(_searchQuery))
        .toList();
    final hotelProvider = context.watch<HotelProvider>();
    final restaurantProvider = context.watch<RestaurantProvider>();
    final drinkProvider = context.watch<DrinkProvider>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshDashboard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHotelHero(context, auth),
                const SizedBox(height: 16),
                _buildHospitalitySummary(hotelProvider),
                const SizedBox(height: 16),
                _buildHotelStats(context, hotelProvider),
                const SizedBox(height: 22),
                _buildRevenueBreakdown(
                  context,
                  hotelProvider,
                  restaurantProvider,
                  drinkProvider,
                ),
                const SizedBox(height: 26),
                Text(
                  'Workspace',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(
                    () => _searchQuery = value.trim().toLowerCase(),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search navigation or features',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildCategoryTabs(colorScheme),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  _buildEmptyNavigationState()
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.25,
                    ),
                    itemBuilder: (context, index) => _buildNavigationCard(
                      context,
                      items[index],
                      canOpen(items[index]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  static const _navigationItems = <_HotelNavigationItem>[
    _HotelNavigationItem(
      label: 'Reports', category: 'General', icon: Icons.analytics_outlined,
      color: Colors.blue, route: Routes.reports, permission: 'view_reports',
    ),
    _HotelNavigationItem(
      label: 'Advanced Analytics', category: 'General', icon: Icons.insights_outlined,
      color: Colors.indigo, route: Routes.advancedAnalytics,
      permission: 'access_analytics_dashboard',
    ),
    _HotelNavigationItem(
      label: 'Billing', category: 'General', icon: Icons.receipt_long_outlined,
      color: Colors.deepOrange, route: Routes.hotelBilling, permission: 'billing',
    ),
    _HotelNavigationItem(
      label: 'Expenses', category: 'General', icon: Icons.trending_down,
      color: Colors.red, route: Routes.expenseReport, permission: 'access_expenses_screen',
    ),
    _HotelNavigationItem(
      label: 'Printer Settings', category: 'General', icon: Icons.print_outlined,
      color: Colors.teal, route: Routes.printerSettings,
    ),
    _HotelNavigationItem(
      label: 'Check-In & Guests', category: 'Frontdesk', icon: Icons.login,
      color: Colors.blue, route: Routes.hotelCheckIn, permission: 'bookings',
    ),
    _HotelNavigationItem(
      label: 'Bookings', category: 'Frontdesk', icon: Icons.event_available,
      color: Colors.cyan, route: Routes.hotelBookings, permission: 'bookings',
    ),
    _HotelNavigationItem(
      label: 'Check-Out', category: 'Frontdesk', icon: Icons.logout,
      color: Colors.orange, route: Routes.hotelCheckOut, permission: 'guest_checkout',
    ),
    _HotelNavigationItem(
      label: 'Rooms', category: 'Frontdesk', icon: Icons.bed_outlined,
      color: Colors.purple, route: Routes.hotelRooms, permission: 'manage_rooms',
    ),
    _HotelNavigationItem(
      label: 'Housekeeping', category: 'Frontdesk', icon: Icons.cleaning_services_outlined,
      color: Colors.teal, route: Routes.hotelHousekeeping, permission: 'room_service',
    ),
    _HotelNavigationItem(
      label: 'Hall Bookings', category: 'Frontdesk', icon: Icons.apartment_outlined,
      color: Colors.blueGrey, route: Routes.hotelHallBookings, permission: 'bookings',
    ),
    _HotelNavigationItem(
      label: 'Pool Bookings', category: 'Frontdesk', icon: Icons.pool_outlined,
      color: Colors.lightBlue, route: Routes.hotelPoolBookings,
      permission: 'manage_pool_bookings',
    ),
    _HotelNavigationItem(
      label: 'Restaurant POS', category: 'Restaurant', icon: Icons.restaurant_menu,
      color: Colors.redAccent, route: Routes.hotelRestaurant, permission: 'sales',
    ),
    _HotelNavigationItem(
      label: 'Orders & Kitchen', category: 'Restaurant', icon: Icons.kitchen_outlined,
      color: Colors.deepOrange, route: Routes.restaurantKitchen, permission: 'view_orders',
    ),
    _HotelNavigationItem(
      label: 'Manage Menu', category: 'Restaurant', icon: Icons.menu_book_outlined,
      color: Colors.green, route: Routes.restaurantManageMenu, permission: 'manage_menu',
    ),
    _HotelNavigationItem(
      label: 'Tables', category: 'Restaurant', icon: Icons.table_restaurant_outlined,
      color: Colors.amber, route: Routes.restaurantTables, permission: 'table_management',
    ),
    _HotelNavigationItem(
      label: 'Restaurant Stock', category: 'Restaurant', icon: Icons.inventory_2_outlined,
      color: Colors.brown, route: Routes.restaurantStock, permission: 'view_inventory',
    ),
    _HotelNavigationItem(
      label: 'Bar POS', category: 'Bar', icon: Icons.local_bar_outlined,
      color: Colors.indigo, route: Routes.hotelBar, permission: 'sales',
    ),
    _HotelNavigationItem(
      label: 'Bar Orders & Invoices', category: 'Bar', icon: Icons.receipt_long_outlined,
      color: Colors.blueGrey, route: Routes.drinkTabs, permission: 'view_orders',
    ),
    _HotelNavigationItem(
      label: 'Bar Inventory', category: 'Bar', icon: Icons.wine_bar_outlined,
      color: Colors.pink, route: Routes.drinkInventory, permission: 'view_inventory',
    ),
  ];

  Widget _buildHotelHero(BuildContext context, AuthProvider auth) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.18), colorScheme.surfaceContainerHighest],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: colorScheme.surface, shape: BoxShape.circle),
            child: const Icon(Icons.hotel_outlined, color: AppColors.primary, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hospitality workspace', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                Text('Hotel Operations', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                Text(auth.currentUser?.fullName ?? 'Team member', maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh dashboard',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDashboard,
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) Navigator.of(context).pushReplacementNamed(Routes.login);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHotelStats(BuildContext context, HotelProvider provider) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Active rooms', '${provider.occupiedRooms}/${provider.totalRooms}', Icons.bed_outlined, Colors.purple)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Check-ins', '${provider.getUpcomingCheckIns(const Duration(hours: 24)).length}', Icons.login, Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Check-outs', '${provider.getTodayCheckOuts().length}', Icons.logout, Colors.orange)),
      ],
    );
  }

  Widget _buildRevenueBreakdown(
    BuildContext context,
    HotelProvider hotelProvider,
    RestaurantProvider restaurantProvider,
    DrinkProvider drinkProvider,
  ) {
    final now = DateTime.now();
    final start = _selectedRevenuePeriod == 'Daily'
        ? DateTime(now.year, now.month, now.day)
        : _selectedRevenuePeriod == 'Weekly'
            ? DateTime(now.year, now.month, now.day)
                .subtract(Duration(days: now.weekday - 1))
            : DateTime(now.year, now.month, 1);

    final restaurantRevenue = restaurantProvider.orders
        .where((order) =>
            order.createdAt.isAfter(start) &&
            order.status == 'completed' &&
            (order.paymentStatus == 'paid' ||
                order.paymentStatus == 'room_charge'))
        .fold<double>(0, (total, order) => total + order.total);
    final barRevenue = drinkProvider.orders
        .where((order) =>
            order.createdAt.isAfter(start) && order.status == 'paid')
        .fold<double>(0, (total, order) => total + order.total());
    final roomRevenue = hotelProvider.reservations
        .where((reservation) =>
            reservation.createdAt.isAfter(start) &&
            reservation.status != 'cancelled')
        .fold<double>(0, (total, reservation) => total + reservation.totalPrice);

    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Revenue breakdown',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              'Income by service',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Daily', label: Text('Daily')),
            ButtonSegment(value: 'Weekly', label: Text('Weekly')),
            ButtonSegment(value: 'Monthly', label: Text('Monthly')),
          ],
          selected: {_selectedRevenuePeriod},
          onSelectionChanged: (selection) => setState(
            () => _selectedRevenuePeriod = selection.first,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildRevenueRow('Rooms', roomRevenue, Icons.bed_outlined, Colors.purple),
              const Divider(height: 20),
              _buildRevenueRow('Restaurant', restaurantRevenue, Icons.restaurant_outlined, Colors.redAccent),
              const Divider(height: 20),
              _buildRevenueRow('Bar', barRevenue, Icons.local_bar_outlined, Colors.indigo),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueRow(
    String label,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Text(
          formatCurrency(amount, decimalDigits: 0),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color),
        const SizedBox(height: 10),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
      ]),
    );
  }

  Widget _buildCategoryTabs(ColorScheme colorScheme) {
    const categories = ['General', 'Frontdesk', 'Restaurant', 'Bar'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final selected = category == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(
                category == 'General' ? Icons.dashboard_outlined :
                    category == 'Frontdesk' ? Icons.desk_outlined :
                    category == 'Restaurant' ? Icons.restaurant_outlined : Icons.local_bar_outlined,
                size: 18,
              ),
              label: Text(category),
              selected: selected,
              onSelected: (_) => setState(() => _selectedCategory = category),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(color: selected ? Colors.white : colorScheme.onSurface),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNavigationCard(BuildContext context, _HotelNavigationItem item, bool canOpen) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: canOpen ? 1 : 0.48,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: canOpen
              ? () => item.route == null
                  ? WhatsAppUtils.openCustomerSupport(context)
                  : Navigator.pushNamed(context, item.route!)
              : () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Permission required for this feature')),
                  ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: item.color.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
                child: Icon(item.icon, color: item.color),
              ),
              const Spacer(),
              Text(item.label, style: const TextStyle(fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(canOpen ? 'Open' : 'Restricted', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyNavigationState() {
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Center(child: Text(
        _searchQuery.isEmpty ? 'No features in this section' : 'No matching features',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      )),
    );
  }

  Widget _buildHospitalitySummary(HotelProvider hotelProvider) {
    final now = DateTime.now();
    final since = now.subtract(const Duration(hours: 24));
    final restaurantProvider = context.read<RestaurantProvider>();
    final drinkProvider = context.read<DrinkProvider>();
    final restaurantSales = restaurantProvider.orders
        .where((order) =>
            order.createdAt.isAfter(since) && order.status != 'cancelled')
        .fold<double>(0, (sum, order) => sum + order.total);
    final barSales = drinkProvider.orders
        .where((order) => order.createdAt.isAfter(since) && order.status != 'cancelled')
        .fold<double>(0, (sum, order) => sum + order.total());
    final roomBookings = hotelProvider.reservations
        .where((reservation) => reservation.createdAt.isAfter(since))
        .length;

    return Row(
      children: [
        Expanded(child: _buildSummaryPill('Restaurant (24h)', formatCurrency(restaurantSales, decimalDigits: 0), Colors.red)),
        const SizedBox(width: 10),
        Expanded(child: _buildSummaryPill('Bar (24h)', formatCurrency(barSales, decimalDigits: 0), Colors.indigo)),
        const SizedBox(width: 10),
        Expanded(child: _buildSummaryPill('Room bookings (24h)', roomBookings.toString(), Colors.blue)),
      ],
    );
  }

  Widget _buildRevenueHeader(HotelProvider provider) {
    return FutureBuilder<double>(
      future: provider.getTodaysSalesTotal(),
      builder: (context, snapshot) {
        final todaysRevenue = snapshot.data ?? 0.0;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Revenue (Today)',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.9), fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                    formatCurrency(todaysRevenue, decimalDigits: 0),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle),
                child: const Icon(Icons.attach_money,
                    color: Colors.white, size: 30),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
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
          Text(title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              )),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        ],
      ),
    );
  }

  Widget _buildRoomStatusBar(BuildContext context, HotelProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final dist = provider.getRoomStatusDistribution();


    // Calculate Flex values
    final availFlex = dist['available'] ?? 0;
    final occFlex = dist['occupied'] ?? 0;
    final maintFlex = dist['maintenance'] ?? 0;
    final resFlex = dist['reserved'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // Visual Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (availFlex > 0)
                    Expanded(
                        flex: availFlex,
                        child: Container(color: Colors.green)),
                  if (occFlex > 0)
                    Expanded(
                        flex: occFlex,
                        child: Container(color: Colors.blue)),
                  if (resFlex > 0)
                    Expanded(
                        flex: resFlex,
                        child: Container(color: Colors.orange)),
                  if (maintFlex > 0)
                    Expanded(
                        flex: maintFlex,
                        child: Container(color: Colors.red)),
                  // Fallback if empty to prevent error
                  if (availFlex + occFlex + resFlex + maintFlex == 0)
                    Expanded(
                        child: Container(color: colorScheme.outlineVariant)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem(context, 'Available', availFlex, Colors.green),
              _buildLegendItem(context, 'Occupied', occFlex, Colors.blue),
              _buildLegendItem(context, 'Reserved', resFlex, Colors.orange),
              _buildLegendItem(context, 'Maint.', maintFlex, Colors.red),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, int count, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(count.toString(),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        Text(label,
            style:
                TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10)),
      ],
    );
  }

  Widget _buildTodaysSummaryRow(HotelProvider provider) {
    final checkOuts = provider.getTodayCheckOuts().length;
    final checkIns =
        provider.getUpcomingCheckIns(const Duration(hours: 24)).length;
    final pending =
        provider.serviceOrders.where((s) => s.status == 'pending').length;

    return Row(
      children: [
        Expanded(
            child: _buildSummaryPill(
                'Check-ins', checkIns.toString(), Colors.blue)),
        const SizedBox(width: 10),
        Expanded(
            child: _buildSummaryPill(
                'Check-outs', checkOuts.toString(), Colors.orange)),
        const SizedBox(width: 10),
        Expanded(
            child: _buildSummaryPill(
                'Services', pending.toString(), Colors.purple)),
      ],
    );
  }

  Widget _buildSummaryPill(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(count,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(color: color, fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildActionGrid(
    BuildContext context,
    bool canBook,
    bool canAccessOperations,
  ) {
    List<Widget> actions = [];

    if (canBook) {
      actions.add(_buildActionCard(
        context,
        icon: Icons.login,
        label: 'Check-In / Guests',
        color: Colors.blue,
        // Routes to the new CheckInHubScreen (Available / Reserved /
        // Checked-In tabs with New Booking + Reserve Room FABs + history).
        // Replaces the old bookings screen as the single reception hub.
        onTap: () => Navigator.pushNamed(context, Routes.hotelCheckIn),
      ));
    }

    // Room, guest, and housekeeping management moved to work page (removed from home)

    if (canAccessOperations) {
      actions.add(_buildActionCard(
        context,
        icon: Icons.restaurant_menu,
        label: 'Restaurant',
        color: Colors.redAccent,
        onTap: () => Navigator.pushNamed(context, Routes.hotelRestaurant),
      ));

      actions.add(_buildActionCard(
        context,
        icon: Icons.local_bar_outlined,
        label: 'Bar POS',
        color: Colors.indigo,
        onTap: () => Navigator.pushNamed(context, Routes.drinkPos),
      ));

      actions.add(_buildActionCard(
        context,
        icon: Icons.receipt_long_outlined,
        label: 'Tabs & Invoices',
        color: Colors.blueGrey,
        onTap: () => Navigator.pushNamed(context, Routes.drinkTabs),
      ));
      actions.add(_buildActionCard(
        context,
        icon: Icons.receipt_long,
        label: 'Billing',
        color: Colors.deepOrange,
        onTap: () => Navigator.pushNamed(context, Routes.hotelBilling),
      ));

      actions.add(_buildActionCard(
        context,
        icon: Icons.trending_down,
        label: 'Expenses',
        color: Colors.red,
        onTap: () => Navigator.pushNamed(context, Routes.expenseReport),
      ));

      actions.add(_buildActionCard(
        context,
        icon: Icons.insights_outlined,
        label: 'Analytics',
        color: Colors.indigo,
        onTap: () => Navigator.pushNamed(context, Routes.advancedAnalytics),
      ));

      actions.add(_buildActionCard(
        context,
        icon: Icons.apartment_outlined,
        label: 'Hall Bookings',
        color: Colors.blueGrey,
        onTap: () => Navigator.pushNamed(context, Routes.hotelHallBookings),
      ));

      actions.add(_buildActionCard(
        context,
        icon: Icons.pool_outlined,
        label: 'Pool Bookings',
        color: Colors.lightBlue,
        onTap: () => Navigator.pushNamed(context, Routes.hotelPoolBookings),
      ));

      // Add Printer Settings quick action
      actions.add(_buildActionCard(
        context,
        icon: Icons.print,
        label: 'Printer Settings',
        color: Colors.teal,
        onTap: () => Navigator.pushNamed(context, Routes.printerSettings),
      ));

    }

    actions.add(_buildActionCard(
      context,
      icon: Icons.support_agent_rounded,
      label: 'Customer Care',
      color: Colors.green,
      onTap: () => WhatsAppUtils.openCustomerSupport(context),
    ));

    // Use GridView for cleaner layout
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.5, // Makes them rectangular buttons
      children: actions,
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
