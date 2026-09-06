import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/retail_provider.dart';
import '../../../../services/managecare_api_client.dart';
import '../utils/fuel_station_scope.dart';

class GasDashboardScreen extends StatefulWidget {
  const GasDashboardScreen({
    super.key,
    this.mode = FuelStationMode.gas,
  });

  final FuelStationMode mode;

  @override
  State<GasDashboardScreen> createState() => _GasDashboardScreenState();
}

class _GasDashboardScreenState extends State<GasDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  double _totalAmount = 0.0;
  double _totalVolume = 0.0;
  int _transactions = 0;
  double _fuelStock = 0.0;
  int _fuelProductCount = 0;
  int _pendingReviewCount = 0;
  int _declinedUploadCount = 0;
  List<Map<String, dynamic>> _recentSales = [];
  DateTime _selectedDate = DateTime.now();
  StreamSubscription<Map<String, dynamic>>? _metricsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _historySubscription;

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.tryParse(value?.toString() ?? '');
  }

  double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _shortSaleId(dynamic value) {
    final id = value?.toString() ?? '';
    if (id.isEmpty) return 'PENDING';
    return id.length <= 6 ? id : id.substring(0, 6);
  }

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMetrics();
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _metricsSubscription?.cancel();
    _historySubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    setState(() => _loading = true);
    final retail = context.read<RetailProvider>();
    final business = context.read<BusinessProvider>().currentBusiness;
    final user = context.read<AuthProvider>().currentUser;

    // Ensure products are loaded for price display
    if (retail.products.isEmpty) {
      await retail.loadProducts();
    }

    final start =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final end = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    final metrics = await retail.getFuelMetrics(start: start, end: end);
    final history =
        await retail.getFuelSalesHistory(start: start, end: end, limit: 5);
    await _loadUploadCounts(
      businessId: business?.id,
      workerId: user?.id,
    );

    final fuelProducts = retail.products.where((p) {
      final cat = p.category.toLowerCase();
      return cat.contains('fuel') ||
          cat.contains('petroleum') ||
          cat.contains('petrol') ||
          cat.contains('diesel') ||
          cat.contains('kerosene') ||
          cat.contains('gas');
    }).toList();

    if (mounted) {
      setState(() {
        _totalAmount = metrics['totalAmount'] ?? 0.0;
        _totalVolume = metrics['totalVolume'] ?? 0.0;
        _transactions = metrics['transactions'] ?? 0;
        _fuelStock = fuelProducts.fold(0.0, (sum, p) => sum + p.stock);
        _fuelProductCount = fuelProducts.length;
        _recentSales = history;
        _loading = false;
      });
    }

    _metricsSubscription?.cancel();
    _historySubscription?.cancel();
    _metricsSubscription =
        retail.watchFuelMetrics(start: start, end: end).listen((metrics) {
      if (!mounted) return;
      setState(() {
        _totalAmount = metrics['totalAmount'] ?? 0.0;
        _totalVolume = metrics['totalVolume'] ?? 0.0;
        _transactions = metrics['transactions'] ?? 0;
        _loading = false;
      });
    });
    _historySubscription = retail
        .watchFuelSalesHistory(start: start, end: end, limit: 5)
        .listen((history) {
      if (!mounted) return;
      setState(() {
        _recentSales = history;
        _loading = false;
      });
    });
  }

  Future<void> _loadUploadCounts({
    required String? businessId,
    required String? workerId,
  }) async {
    if (businessId == null || businessId.isEmpty) return;
    try {
      final response = await ManagecareApiClient.instance.get(
        '/api/pumps/$businessId/uploads/counts',
        query: {
          if (workerId != null && workerId.isNotEmpty) 'workerId': workerId,
        },
      );
      if (!mounted || response is! Map) return;
      setState(() {
        _pendingReviewCount =
            (response['pending_review_count'] as num?)?.toInt() ?? 0;
        _declinedUploadCount =
            (response['declined_count'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {
      // Counts are dashboard decoration; core fuel metrics should still load.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final businessType =
        context.watch<BusinessProvider>().currentBusiness?.businessType.toLowerCase() ?? 'gas';
    if (!FuelStationScope.matches(widget.mode, businessType)) {
      return FuelStationScope.mismatchScaffold(
        mode: widget.mode,
        businessType: businessType,
      );
    }
    final isPetroleumStation = widget.mode == FuelStationMode.petroleum;
    final dashboardLabel = widget.mode.label;
    final pumpRoute = isPetroleumStation ? Routes.petroleumPump : Routes.gasPump;
    final stockRoute = isPetroleumStation ? Routes.petroleumStock : Routes.gasStock;
    final historyRoute =
        isPetroleumStation ? Routes.petroleumSalesHistory : Routes.gasSalesHistory;
    final pumpUploadRoute =
        isPetroleumStation ? Routes.petroleumPumpUpload : Routes.gasPumpUpload;
    final pumpUploadHistoryRoute = isPetroleumStation
        ? Routes.petroleumPumpUploadHistory
        : Routes.gasPumpUploadHistory;
    final pumpConfigurationRoute = isPetroleumStation
        ? Routes.petroleumPumpConfiguration
        : Routes.gasPumpConfiguration;
    final auth = context.watch<AuthProvider>();
    final role = auth.currentUser?.role ?? '';
    final permissions = auth.currentUser?.permissions ?? [];
    final stationRole = WorkerPermissions.normalizeRole(role);
    final isPumpOperator =
        isPetroleumStation && stationRole == 'pump_operator';
    final isMiniMartSeller = isPetroleumStation &&
        (stationRole == 'sales_rep' || stationRole == 'cashier');
    final isStationStaff = isPetroleumStation && stationRole == 'staff';
    final hasFullStationAccess = auth.currentUser?.isOwner == true ||
        ['owner', 'admin', 'sub_admin', 'manager', 'fuel_manager']
            .contains(stationRole);
    final showAllOperations = !isPetroleumStation || hasFullStationAccess;
    final canAccessFuelStock = hasFullStationAccess ||
        WorkerPermissions.canAccessFuelStockForUser(role, permissions);
    final canAccessPumpConfig = hasFullStationAccess ||
        WorkerPermissions.canAccessPumpConfigurationForUser(
          role,
          permissions,
        );
    final canAccessProcurement = hasFullStationAccess ||
        WorkerPermissions.canAccessProcurementForUser(role, permissions);
    final canAccessExpenses = hasFullStationAccess ||
        WorkerPermissions.canAccessExpensesForUser(role, permissions);
    final operationCards = <Widget>[
      if (showAllOperations || isPumpOperator || isStationStaff)
        _OperationCard(
            title: 'Pump Sale',
            icon: Icons.local_gas_station,
            color: Colors.purple,
            onTap: () => Navigator.pushNamed(context, pumpRoute)
                .then((_) => _loadMetrics())),
      if (canAccessFuelStock)
        _OperationCard(
            title: 'Fuel Stock',
            icon: Icons.inventory_2,
            color: Colors.brown,
            onTap: () => Navigator.pushNamed(context, stockRoute)
                .then((_) => _loadMetrics())),
      if (showAllOperations || isPumpOperator || isStationStaff)
        _OperationCard(
            title: 'Pump Upload',
            icon: Icons.cloud_upload_outlined,
            color: Colors.deepPurple,
            onTap: () => Navigator.pushNamed(context, pumpUploadRoute)
                .then((_) => _loadMetrics())),
      if (showAllOperations || isPumpOperator || isStationStaff)
        _OperationCard(
            title: 'Upload History',
            icon: Icons.fact_check_outlined,
            color: Colors.blueGrey,
            badge: isPumpOperator && _declinedUploadCount > 0
                ? _declinedUploadCount
                : null,
            onTap: () => Navigator.pushNamed(context, pumpUploadHistoryRoute)),
      if (isPetroleumStation && hasFullStationAccess)
        _OperationCard(
            title: 'Upload Review',
            icon: Icons.pending_actions_outlined,
            color: Colors.red.shade700,
            badge: _pendingReviewCount > 0 ? _pendingReviewCount : null,
            onTap: () =>
                Navigator.pushNamed(context, Routes.petroleumPumpUploadReview)),
      if (isPetroleumStation && isPumpOperator)
        _OperationCard(
            title: 'Upload Status',
            icon: Icons.assignment_return_outlined,
            color: Colors.red.shade700,
            badge: _declinedUploadCount > 0 ? _declinedUploadCount : null,
            onTap: () => Navigator.pushNamed(
                context, Routes.petroleumDeclinedPumpUploads)),
      if (canAccessPumpConfig)
        _OperationCard(
            title: 'Pump Config',
            icon: Icons.tune_outlined,
            color: Colors.cyan,
            onTap: () => Navigator.pushNamed(context, pumpConfigurationRoute)),
      if (showAllOperations || isMiniMartSeller || isStationStaff)
        _OperationCard(
            title: 'Shop POS',
            icon: Icons.point_of_sale,
            color: Colors.indigo,
            onTap: () => Navigator.pushNamed(context, Routes.retailPos)
                .then((_) => _loadMetrics())),
      if (canAccessProcurement)
        _OperationCard(
            title: 'Procurement',
            icon: Icons.shopping_bag_outlined,
            color: Colors.orange,
            onTap: () => Navigator.pushNamed(context, Routes.procurement)
                .then((_) => _loadMetrics())),
      if (canAccessExpenses)
        _OperationCard(
            title: 'Expenses',
            icon: Icons.receipt_long_outlined,
            color: Colors.brown,
            onTap: () => Navigator.pushNamed(context, Routes.expenseReport)),
      if (isPetroleumStation && hasFullStationAccess)
        _OperationCard(
            title: 'Bank Deposits',
            icon: Icons.account_balance_outlined,
            color: Colors.green.shade700,
            onTap: () =>
                Navigator.pushNamed(context, Routes.petroleumBankDeposits)),
      if (isPetroleumStation && hasFullStationAccess)
        _OperationCard(
            title: 'Cash Tracking',
            icon: Icons.payments_outlined,
            color: Colors.green.shade800,
            onTap: () =>
                Navigator.pushNamed(context, Routes.petroleumCashTracking)),
      if (showAllOperations)
        _OperationCard(
            title: 'Printer settings',
            icon: Icons.print,
            color: Colors.teal,
            onTap: () => Navigator.pushNamed(context, Routes.printerSettings)),
      if (showAllOperations)
        _OperationCard(
            title: 'Customer Care',
            icon: Icons.support_agent_rounded,
            color: Colors.green,
            onTap: () => WhatsAppUtils.openCustomerSupport(context)),
      if (showAllOperations || isMiniMartSeller || isStationStaff)
        _OperationCard(
            title: 'History',
            icon: Icons.history,
            color: Colors.teal,
            onTap: () => Navigator.pushNamed(context, historyRoute)),
    ];
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Top gradient header
          Container(
            height: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.8),
                  Colors.blueAccent.shade700,
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dashboardLabel,
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.85),
                                      fontSize: 14)),
                              const Text('Overview',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle),
                                child: IconButton(
                                    icon: const Icon(
                                        Icons.notifications_outlined,
                                        color: Colors.white),
                                    onPressed: () {}),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle),
                                child: IconButton(
                                    icon: const Icon(Icons.logout,
                                        color: Colors.white),
                                    onPressed: () async {
                                      try {
                                        await context
                                            .read<AuthProvider>()
                                            .logout();
                                        if (context.mounted)
                                          Navigator.of(context)
                                              .pushReplacementNamed(
                                                  Routes.login);
                                      } catch (e) {
                                        if (context.mounted)
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: Text(
                                                      'Logout failed: $e')));
                                      }
                                    }),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Hero card
                      _HeroValueCard(value: _totalAmount),

                      const SizedBox(height: 24),

                      // Stats row
                      Row(children: [
                        Expanded(
                            child: _CompactStatCard(
                                label: 'Revenue',
                                value: NumberFormat.currency(
                                        locale: 'en_NG', symbol: '₦')
                                    .format(_totalAmount),
                                icon: Icons.attach_money,
                                color: Colors.green)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _CompactStatCard(
                                label: 'Volume',
                                value: '${_totalVolume.toStringAsFixed(1)} L',
                                icon: Icons.local_gas_station,
                                color: Colors.orange)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _CompactStatCard(
                                label: 'Txns',
                                value: '$_transactions',
                                icon: Icons.receipt_long,
                                color: Colors.blue)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: _CompactStatCard(
                                label: 'Fuel Stock',
                                value: '${_fuelStock.toStringAsFixed(1)}',
                                icon: Icons.warehouse,
                                color: AppColors.warning)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _CompactStatCard(
                                label: 'Fuel Products',
                                value: '$_fuelProductCount',
                                icon: Icons.inventory_2,
                                color: Colors.purple)),
                      ]),

                      const SizedBox(height: 24),

                      // Operations
                      Text('Operations',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          )),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.4,
                        children: operationCards,
                      ),

                      const SizedBox(height: 24),

                      // Recent Transactions
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Recent Transactions',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                )),
                            TextButton(
                                onPressed: () =>
                                    Navigator.pushNamed(context, historyRoute),
                                child: const Text('View All'))
                          ]),

                      _loading
                          ? const SizedBox(
                              height: 80,
                              child: Center(child: CircularProgressIndicator()))
                          : _recentSales.isEmpty
                              ? _EmptyState()
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _recentSales.length,
                                  itemBuilder: (context, index) {
                                    final s = _recentSales[index];
                                    final created = _readDate(s['createdAt']);
                                    final dateStr = created != null
                                        ? DateFormat.jm().format(created)
                                        : '';
                                    final saleId = _shortSaleId(s['id']);
                                    final totalAmount =
                                        _readDouble(s['totalAmount']);
                                    final fuelVolume =
                                        _readDouble(s['fuelVolume']);
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          color: colorScheme.surfaceContainerHighest,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: colorScheme.outlineVariant)),
                                      child: Row(
                                        children: [
                                          Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                  color: colorScheme.surfaceContainer,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                              child: Icon(
                                                  Icons.local_gas_station,
                                                  color: colorScheme
                                                      .onSurfaceVariant)),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                      'Sale #$saleId...',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                  Text(
                                                    dateStr,
                                                    style: theme.textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                                ]),
                                          ),
                                          Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                    '₦${totalAmount.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${fuelVolume.toStringAsFixed(2)} L',
                                                  style: theme.textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ])
                                        ],
                                      ),
                                    );
                                  },
                                ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// -- Helper widgets (moved to bottom of file) --

class _HeroValueCard extends StatelessWidget {
  final double value;

  const _HeroValueCard({required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_gas_station,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Revenue (Today)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            NumberFormat.currency(locale: 'en_NG', symbol: '₦').format(value),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.arrow_upward, size: 16, color: Colors.green),
            const SizedBox(width: 4),
            Text(
              'Updated just now',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _CompactStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _CompactStatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center)
      ]),
    );
  }
}

class _OperationCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int? badge;
  final VoidCallback onTap;

  const _OperationCard(
      {required this.title,
      required this.icon,
      required this.color,
      this.badge,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 5))
            ]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 28)),
              if (badge != null && badge! > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: colorScheme.surface, width: 2),
                    ),
                    child: Text(
                      badge! > 99 ? '99+' : badge.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          )
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(children: [
              Icon(Icons.inbox_outlined,
                  size: 48, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(
                'No recent activity',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              )
            ])));
  }
}
