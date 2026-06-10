import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/retail_provider.dart';

class GasDashboardScreen extends StatefulWidget {
  const GasDashboardScreen({super.key});

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
  List<Map<String, dynamic>> _recentSales = [];
  DateTime _selectedDate = DateTime.now();

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
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    setState(() => _loading = true);
    final retail = context.read<RetailProvider>();

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

    final fuelProducts = retail.products.where((p) {
      final cat = p.category.toLowerCase();
      return cat.contains('fuel') ||
          cat.contains('petrol') ||
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                              Text('Gas',
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
                        children: [
                          _OperationCard(
                              title: 'Pump Sale',
                              icon: Icons.local_gas_station,
                              color: Colors.purple,
                              onTap: () =>
                                  Navigator.pushNamed(context, Routes.gasPump)
                                      .then((_) => _loadMetrics())),
                          _OperationCard(
                              title: 'Gas Stock',
                              icon: Icons.inventory_2,
                              color: Colors.brown,
                              onTap: () => Navigator.pushNamed(
                                      context, Routes.gasStock)
                                  .then((_) => _loadMetrics())),
                          _OperationCard(
                              title: 'Shop POS',
                              icon: Icons.point_of_sale,
                              color: Colors.indigo,
                              onTap: () => Navigator.pushNamed(
                                      context, Routes.sales)
                                  .then((_) => _loadMetrics())),
                          _OperationCard(
                              title: 'Procurement',
                              icon: Icons.shopping_bag_outlined,
                              color: Colors.orange,
                              onTap: () => Navigator.pushNamed(
                                      context, Routes.procurement)
                                  .then((_) => _loadMetrics())),
                          _OperationCard(
                              title: 'Printer settings',
                              icon: Icons.print,
                              color: Colors.teal,
                              onTap: () => Navigator.pushNamed(
                                  context, Routes.printerSettings)),
                          _OperationCard(
                              title: 'Customer Care',
                              icon: Icons.support_agent_rounded,
                              color: Colors.green,
                              onTap: () => WhatsAppUtils.openCustomerSupport(context)),
                          _OperationCard(
                              title: 'History',
                              icon: Icons.history,
                              color: Colors.teal,
                              onTap: () => Navigator.pushNamed(
                                  context, Routes.gasSalesHistory)),
                        ],
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
                                onPressed: () => Navigator.pushNamed(
                                    context, Routes.gasSalesHistory),
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
                                    final created = s['createdAt'] as DateTime?;
                                    final dateStr = created != null
                                        ? DateFormat.jm().format(created)
                                        : '';
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
                                                      'Sale #${(s['id'] ?? '').toString().substring(0, 6)}...',
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
                                                    '₦${(s['totalAmount'] ?? 0.0).toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${(s['fuelVolume'] ?? 0.0).toStringAsFixed(2)} L',
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
  final VoidCallback onTap;

  const _OperationCard(
      {required this.title,
      required this.icon,
      required this.color,
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
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28)),
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
