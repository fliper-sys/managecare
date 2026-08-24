import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../core/utils/datetime_utils.dart';
import '../../../core/constants/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../widgets/animated_lottie.dart';
import '../../../providers/retail_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/sync_provider.dart';
import 'receipt_detail_screen.dart';
import 'return_refund_screen.dart';
import '../../shared/printing_action_sheet.dart';
import '../../../services/thermal_printing_service.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  DateTimeRange? _selectedDateRange;

  // Quick stats state
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
  double _todayTotal = 0.0;
  double _weekTotal = 0.0;
  double _monthTotal = 0.0;
  bool _statsLoading = true;

  BusinessProvider? _bpListenerRef;
  int _refreshTick = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  Future<void> _pushToFirebase() async {
    final syncProvider = context.read<SyncProvider>();
    final retailProvider = context.read<RetailProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await syncProvider.syncNow();
    // Fuel/gas pump sales are queued separately (not in the generic sales
    // table SyncProvider watches) so they need an explicit push too.
    int pumpSynced = 0;
    try {
      pumpSynced = await retailProvider.syncPendingPumpSales();
    } catch (_) {}
    if (!mounted) return;
    final message = pumpSynced > 0
        ? '$result; $pumpSynced pump sale${pumpSynced == 1 ? '' : 's'} synced'
        : result;
    messenger.showSnackBar(SnackBar(content: Text(message)));
    setState(() => _refreshTick++);
    _loadQuickStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final bp = Provider.of<BusinessProvider>(context);
    if (_bpListenerRef != bp) {
      try {
        _bpListenerRef?.removeListener(_onBusinessChanged);
      } catch (_) {}
      _bpListenerRef = bp;
      try {
        _bpListenerRef?.addListener(_onBusinessChanged);
      } catch (_) {}
    }

    // Load stats after build to avoid calling setState during build (prevents setState() during build errors)
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuickStats());
  }

  @override
  void dispose() {
    try {
      _bpListenerRef?.removeListener(_onBusinessChanged);
    } catch (_) {}

    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onBusinessChanged() {
    // Reload stats when the current business changes
    _loadQuickStats();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      // If user sets a custom range, we can show totals for that range as well
      _loadQuickStats(customRange: picked);
    }
  }

  Future<void> _loadQuickStats({DateTimeRange? customRange}) async {
    setState(() {
      _statsLoading = true;
    });

    try {
      final bp = Provider.of<BusinessProvider>(context, listen: false);
      if (bp.currentBusiness == null) {
        setState(() {
          _todayTotal = 0.0;
          _weekTotal = 0.0;
          _monthTotal = 0.0;
          _statsLoading = false;
        });
        return;
      }

      final businessId = bp.currentBusiness!.id;
      final retailProvider =
          Provider.of<RetailProvider>(context, listen: false);
      try {
        await retailProvider.initialize(businessId);
      } catch (_) {}

      // Use provider-level, server-side aggregation for totals to avoid fetching many documents
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = now.subtract(const Duration(days: 6)); // last 7 days
      final monthStart = DateTime(now.year, now.month, 1);

      if (customRange != null) {
        // Single call for custom range
        final total = await retailProvider.getTotalSalesForPeriod(
            startDate: customRange.start, endDate: customRange.end);
        setState(() {
          _todayTotal = total;
          _weekTotal = 0.0;
          _monthTotal = 0.0;
          _statsLoading = false;
        });
        return;
      }

      // Parallelize the three queries
      final futures = await Future.wait<double>([
        retailProvider.getTotalSalesForPeriod(
            startDate: todayStart, endDate: now),
        retailProvider.getTotalSalesForPeriod(
            startDate: weekStart, endDate: now),
        retailProvider.getTotalSalesForPeriod(
            startDate: monthStart, endDate: now),
      ]);

      setState(() {
        _todayTotal = futures[0];
        _weekTotal = futures[1];
        _monthTotal = futures[2];
        _statsLoading = false;
      });
    } catch (e) {
      setState(() {
        _todayTotal = 0.0;
        _weekTotal = 0.0;
        _monthTotal = 0.0;
        _statsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Sales History'),
        elevation: 0,
        actions: [
          Consumer<SyncProvider>(
            builder: (context, sync, _) {
              return IconButton(
                icon: sync.isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Badge(
                        isLabelVisible: sync.hasPendingItems,
                        label: Text('${sync.pendingItems}'),
                        child: const Icon(Icons.cloud_upload_outlined),
                      ),
                tooltip: 'Push offline sales to Firebase',
                onPressed: sync.isSyncing ? null : _pushToFirebase,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () {
              // Export sales
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter
          Container(
            color: theme.colorScheme.primary,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: TextStyle(color: theme.colorScheme.onPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search by order ID, customer...',
                    hintStyle: TextStyle(
                        color: theme.colorScheme.onPrimary.withOpacity(0.72)),
                    prefixIcon:
                        Icon(Icons.search, color: theme.colorScheme.onPrimary),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.calendar_today,
                          color: theme.colorScheme.onPrimary),
                      onPressed: _selectDateRange,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.onPrimary.withOpacity(0.18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_selectedDateRange != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onPrimary.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.date_range,
                            color: theme.colorScheme.onPrimary, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}',
                          style: AppTextStyles.body2.copyWith(
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() => _selectedDateRange = null);
                          },
                          child: Icon(
                            Icons.close,
                            color: theme.colorScheme.onPrimary,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _QuickStat(
                        label: 'Today',
                        value: _statsLoading
                            ? 'Loading...'
                            : _currencyFormat.format(_todayTotal),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickStat(
                        label: 'This Week',
                        value: _statsLoading
                            ? 'Loading...'
                            : _currencyFormat.format(_weekTotal),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickStat(
                        label: 'This Month',
                        value: _statsLoading
                            ? 'Loading...'
                            : _currencyFormat.format(_monthTotal),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: theme.cardColor,
            child: TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor:
                  theme.colorScheme.onSurface.withOpacity(0.7),
              indicatorColor: theme.colorScheme.primary,
              isScrollable: true,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Completed'),
                Tab(text: 'Pending'),
                Tab(text: 'Refunded'),
              ],
            ),
          ),

          // Sales List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _SalesList(
                    filter: 'all',
                    dateRange: _selectedDateRange,
                    refreshTick: _refreshTick),
                _SalesList(
                    filter: 'completed',
                    dateRange: _selectedDateRange,
                    refreshTick: _refreshTick),
                _SalesList(
                    filter: 'pending',
                    dateRange: _selectedDateRange,
                    refreshTick: _refreshTick),
                _SalesList(
                    filter: 'refunded',
                    dateRange: _selectedDateRange,
                    refreshTick: _refreshTick),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushNamed(Routes.refundHistory);
        },
        child: const Icon(Icons.assignment_return_rounded),
        tooltip: 'Refund History',
        backgroundColor: theme.colorScheme.error,
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;

  const _QuickStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.22),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.heading5.copyWith(
              color: theme.colorScheme.onPrimary,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color:
                  theme.colorScheme.onPrimary.withOpacity(isDark ? 0.88 : 0.92),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesList extends StatefulWidget {
  final String filter;
  final DateTimeRange? dateRange;
  final int refreshTick;

  const _SalesList(
      {required this.filter, this.dateRange, this.refreshTick = 0});

  @override
  State<_SalesList> createState() => _SalesListState();
}

class _SalesListState extends State<_SalesList> {
  // No repository needed; we use RetailProvider.getSalesHistoryPage for paging and range filtering
  List<Map<String, dynamic>> _sales = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int? _nextPage;
  final ScrollController _scrollController = ScrollController();
  final int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Automatically load sales when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSales(reset: true); // initial load
    });
  }

  @override
  void didUpdateWidget(covariant _SalesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If date range or filter changed, reload from scratch. refreshTick is
    // bumped by the parent after a manual "Push to Firebase" sync so this
    // picks up sales that just left the pending-sync state.
    if (oldWidget.dateRange != widget.dateRange ||
        oldWidget.filter != widget.filter ||
        oldWidget.refreshTick != widget.refreshTick) {
      _loadSales(reset: true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadSales({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _sales = [];
        _nextPage = null;
      });
    } else if (_isLoadingMore || !_mountedOrAlive()) {
      return;
    }

    try {
      final businessProvider = context.read<BusinessProvider>();
      if (businessProvider.currentBusiness == null) {
        setState(() {
          _error = 'No business selected';
          _isLoading = false;
          _isLoadingMore = false;
        });
        return;
      }

      final businessId = businessProvider.currentBusiness!.id;
      final retailProvider = context.read<RetailProvider>();
      try {
        await retailProvider.initialize(businessId);
      } catch (_) {}

      final start = widget.dateRange?.start;
      final end = widget.dateRange?.end;

      final page = await retailProvider.getSalesHistoryPage(
        limit: _pageSize,
        start: start,
        end: end,
        status: widget.filter != 'all' ? widget.filter : null,
        page: reset ? null : _nextPage,
      );

      final newSales = (page['sales'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final nextPage = page['nextPage'] as int?;

      // Offline sales live only in the local DB until they sync — without
      // this merge they're invisible here even though the sale itself (and
      // its stock deduction) was recorded. Only done on the first page of
      // the "All" tab so pagination cursors stay simple.
      List<Map<String, dynamic>> combinedSales = newSales;
      if (reset && (widget.filter == 'all' || widget.filter == 'completed')) {
        try {
          final localPending = await retailProvider.getLocalPendingSales();
          final existingIds = newSales.map((s) => s['id']).toSet();
          final filteredLocal = localPending.where((s) {
            if (existingIds.contains(s['id'])) return false;
            final createdAtRaw = s['createdAt'];
            final dt =
                createdAtRaw is String ? DateTime.tryParse(createdAtRaw) : null;
            if (dt == null) return true;
            if (start != null && dt.isBefore(start)) return false;
            if (end != null && dt.isAfter(end)) return false;
            return true;
          }).toList();

          if (filteredLocal.isNotEmpty) {
            combinedSales = [...filteredLocal, ...newSales];
            int millis(dynamic v) {
              if (v is String)
                return DateTime.tryParse(v)?.millisecondsSinceEpoch ?? 0;
              return 0;
            }

            combinedSales.sort((a, b) =>
                millis(b['createdAt']).compareTo(millis(a['createdAt'])));
          }
        } catch (_) {}
      }

      setState(() {
        if (reset) {
          _sales = combinedSales;
        } else {
          _sales.addAll(newSales);
        }
        _nextPage = nextPage;
        _isLoading = false;
        _isLoadingMore = false;
      });

      // refresh quick stats in parent (lightweight)
      try {
        final parentState =
            context.findAncestorStateOfType<_SalesHistoryScreenState>();
        parentState?._loadQuickStats();
      } catch (_) {}
    } catch (e) {
      setState(() {
        _error = 'Error loading sales: $e';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  bool _mountedOrAlive() => mounted;

  Future<void> _loadMore() async {
    if (_isLoadingMore || _nextPage == null) return;
    setState(() => _isLoadingMore = true);
    await _loadSales(reset: false);
  }

  Future<void> _openRefund(Map<String, dynamic> sale) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReturnRefundScreen(sale: sale),
      ),
    );

    if (result != null && mounted) {
      _loadSales(reset: true);
      try {
        final parentState =
            context.findAncestorStateOfType<_SalesHistoryScreenState>();
        parentState?._loadQuickStats();
      } catch (_) {}
    }
  }

  Future<void> _deleteSale(Map<String, dynamic> sale) async {
    final saleId = sale['id']?.toString() ?? '';
    if (saleId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete sale?'),
        content: const Text(
          'This will remove the sale from history and restore the sold stock.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<RetailProvider>().deleteSale(
            saleId,
            reason: 'Deleted from sales history',
          );
      if (!mounted) return;
      setState(() {
        _sales.removeWhere((item) => item['id']?.toString() == saleId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale deleted')),
      );
      try {
        final parentState =
            context.findAncestorStateOfType<_SalesHistoryScreenState>();
        parentState?._loadQuickStats();
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete sale: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _printSale(Map<String, dynamic> sale) async {
    final business = context.read<BusinessProvider>().currentBusiness;
    final rawItems = (sale['items'] as List?) ?? const [];
    final items = rawItems.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      return <String, dynamic>{
        'name': item['productName'] ??
            item['product_name'] ??
            item['name'] ??
            'Item',
        'quantity': item['quantity'] ?? item['qty'] ?? 1,
        'price': item['price'] ?? item['unitPrice'] ?? item['unit_price'] ?? 0,
        'unit': item['unit'] ?? item['saleUnit'] ?? 'pcs',
        'pricingMode': item['pricingMode'] ?? item['priceType'],
      };
    }).toList();
    final receiptText = ThermalPrintingService.createCompleteReceipt(
      businessName: business?.name ?? 'My Business',
      paperWidth: 58,
      items: items,
      totalAmount: _calculateSaleAmount(sale),
      paymentMethod: sale['paymentMethod'] ?? sale['payment_method'] ?? 'Cash',
      orderId: sale['referenceId']?.toString() ?? sale['id']?.toString(),
      customerName:
          sale['customerName']?.toString() ?? sale['customer']?.toString(),
    );

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.88,
        child: PrintingActionSheet(
          receiptText: receiptText,
          businessName: business?.name ?? 'My Business',
          orderId: sale['referenceId']?.toString() ?? sale['id']?.toString(),
          saleData: sale,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: AppTextStyles.body1),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSales,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_sales.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AnimatedLottie(
              asset: 'assets/lottie/loop.json',
              width: 160,
              height: 160,
              repeat: true,
            ),
            const SizedBox(height: 12),
            const Text('No sales found', style: AppTextStyles.subtitle1),
            const SizedBox(height: 6),
            Text('Your ${widget.filter} sales will appear here',
                style: AppTextStyles.body2Secondary),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: _sales.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index >= _sales.length) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(),
          ));
        }

        final sale = _sales[index];
        // Ensure we have all required data for display
        final items = (sale['items'] as List?)?.length ??
            (sale['cartItems'] as List?)?.length ??
            1;
        final rawOrderId = (sale['id'] ?? '').toString();
        // The raw id is a full UUID (36 chars) - showing it in full made
        // this card's title wrap/overflow. Reference numbers elsewhere in
        // the app use the same "last 8 chars" shorthand for a sale with no
        // dedicated short referenceId.
        final orderId = sale['referenceId'] != null
            ? 'Sale #${sale['referenceId']}'
            : rawOrderId.isEmpty
                ? 'SALE-${index + 1}'
                : 'Sale #${rawOrderId.length > 8 ? rawOrderId.substring(rawOrderId.length - 8) : rawOrderId}';
        final customer = sale['customer'] ??
            sale['customerName'] ??
            sale['buyerName'] ??
            'Walk-in Customer';
        final amount = _calculateSaleAmount(sale);

        return _SaleCard(
          orderId: orderId,
          customer: customer,
          items: items,
          amount: amount,
          paymentMethod: sale['paymentMethod'] ?? 'Cash',
          status: sale['status'] ?? 'completed',
          time: _formatTime(sale['createdAt']),
          saleData: sale,
          // Sales can be refunded incrementally (multiple partial refunds),
          // so only hide the action once the sale is fully refunded —
          // ReturnRefundScreen itself fetches accurate remaining
          // quantities per item, rather than this list's possibly-stale copy.
          onRefund:
              (sale['status'] == 'refunded' || sale['pendingSync'] == true)
                  ? null
                  : () => _openRefund(sale),
          onDelete:
              sale['pendingSync'] == true ? null : () => _deleteSale(sale),
          onPrint: () => _printSale(sale),
        );
      },
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'Just now';

    final dateTime = parseTimestamp(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  double _calculateSaleAmount(Map<String, dynamic> sale) {
    double parseAmount(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    final itemAmount = parseAmount(sale['totalAmount']) > 0
        ? parseAmount(sale['totalAmount'])
        : parseAmount(sale['finalAmount']);
    if (itemAmount > 0) return itemAmount;

    final fallbackAmount = parseAmount(sale['total']) > 0
        ? parseAmount(sale['total'])
        : parseAmount(sale['amount']);
    if (fallbackAmount > 0) return fallbackAmount;

    final computedSubtotal = parseAmount(sale['subtotal']);
    if (computedSubtotal > 0) return computedSubtotal;

    // If the line items exist, sum them as a last resort. This is useful for
    // pending or offline sales where the sale object may omit a simple total
    // field but still has valid item totals.
    final items = sale['items'] as List?;
    if (items != null && items.isNotEmpty) {
      return items.fold<double>(0.0, (sum, rawItem) {
        if (rawItem is Map<String, dynamic>) {
          final total = parseAmount(rawItem['total']);
          final quantity = parseAmount(rawItem['quantity']);
          if (total > 0) return sum + total;
          if (quantity > 0) {
            final unitPrice = parseAmount(rawItem['unitPrice']) > 0
                ? parseAmount(rawItem['unitPrice'])
                : parseAmount(rawItem['price']);
            return sum + (unitPrice * quantity);
          }
        }
        return sum;
      });
    }

    return 0.0;
  }
}

class _SaleCard extends StatelessWidget {
  final String orderId;
  final String customer;
  final int items;
  final double amount;
  final String paymentMethod;
  final String status;
  final String time;
  final Map<String, dynamic> saleData;
  final VoidCallback? onRefund;
  final VoidCallback? onDelete;
  final VoidCallback? onPrint;

  const _SaleCard({
    required this.orderId,
    required this.customer,
    required this.items,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.time,
    required this.saleData,
    this.onRefund,
    this.onDelete,
    this.onPrint,
  });

  Color get _statusColor {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'partially_refunded':
        return AppColors.warning;
      case 'refunded':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String get _statusLabel {
    switch (status.toLowerCase()) {
      case 'partially_refunded':
        return 'Partially Refunded';
      default:
        return status;
    }
  }

  IconData get _paymentIcon {
    switch (paymentMethod.toLowerCase()) {
      case 'cash':
        return Icons.payments_outlined;
      case 'card':
        return Icons.credit_card_outlined;
      case 'transfer':
        return Icons.account_balance_outlined;
      default:
        return Icons.payment_outlined;
    }
  }

  String _getProductNames(BuildContext context, Map<String, dynamic> sale) {
    final items = sale['items'] as List?;
    if (items == null || items.isEmpty) {
      return 'No items';
    }

    List<String> productNames = [];
    final retailProvider = context.read<RetailProvider>();

    Map<String, dynamic>? tryParseItem(dynamic raw) {
      if (raw == null) return null;
      if (raw is Map<String, dynamic>) return raw;
      if (raw is String) {
        try {
          final parsed = json.decode(raw);
          if (parsed is Map<String, dynamic>) return parsed;
        } catch (_) {
          // not JSON, fall through
        }
      }
      return null;
    }

    int resolveQty(Map<String, dynamic> it) {
      final q = it['quantity'] ?? it['qty'] ?? it['count'] ?? it['q'] ?? 1;
      if (q is num) return q.toInt();
      final parsed = int.tryParse(q?.toString() ?? '');
      return parsed ?? 1;
    }

    for (var rawItem in items) {
      final item = tryParseItem(rawItem);
      if (item == null) {
        // Fallback to string representation
        final text = rawItem?.toString() ?? 'Unknown Item';
        productNames.add(text);
        continue;
      }

      String? name;

      // Direct name fields
      if (item['productName'] is String &&
          (item['productName'] as String).isNotEmpty) {
        name = item['productName'];
      } else if (item['product_name'] is String &&
          (item['product_name'] as String).isNotEmpty) {
        name = item['product_name'];
      } else if (item['name'] is String &&
          (item['name'] as String).isNotEmpty) {
        name = item['name'];
      }

      // product field may be a stringified json or a map
      if (name == null && item['product'] != null) {
        final prod = item['product'];
        if (prod is Map && prod['name'] is String) {
          name = prod['name'];
        } else if (prod is String) {
          try {
            final parsed = json.decode(prod);
            if (parsed is Map && parsed['name'] != null) {
              name = parsed['name'].toString();
            }
          } catch (_) {}
        }
      }

      // productId lookup
      if ((name == null || name.isEmpty) &&
          (item['productId'] ?? item['product_id']) != null) {
        final pid = (item['productId'] ?? item['product_id']).toString();
        final p = retailProvider.products.firstWhere(
          (prod) => prod.id == pid,
          orElse: () => Product(
              id: pid,
              name: 'Unknown Product',
              price: 0,
              stock: 0,
              category: 'Unknown'),
        );
        name = p.name;
      }

      final productName = (name ?? 'Unknown Product').toString();
      final qty = resolveQty(item);
      if (qty > 1) {
        productNames.add('$productName × $qty');
      } else {
        productNames.add(productName);
      }
    }

    if (productNames.isEmpty) {
      return 'No items';
    }

    return productNames.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final secondaryTextColor = theme.colorScheme.onSurface.withOpacity(0.72);

    return GestureDetector(
      onTap: () {
        // Navigate to receipt detail screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ReceiptDetailScreen(saleData: saleData),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    color: _statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(orderId,
                          style: AppTextStyles.subtitle1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(customer, style: AppTextStyles.caption),
                      if (saleData['workerName'] != null &&
                          saleData['workerName'].toString().isNotEmpty)
                        Text('Served by: ${saleData['workerName']}',
                            style: AppTextStyles.caption),
                      // Display product names
                      SizedBox(
                        width: 200,
                        child: Text(
                          _getProductNames(context, saleData),
                          style: AppTextStyles.body2Secondary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₦${amount.toStringAsFixed(0)}',
                      style: AppTextStyles.heading5.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _statusLabel,
                        style: AppTextStyles.caption.copyWith(
                          color: _statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(_paymentIcon, size: 16, color: secondaryTextColor),
                const SizedBox(width: 4),
                Text(paymentMethod,
                    style: AppTextStyles.body2
                        .copyWith(color: secondaryTextColor)),
                const SizedBox(width: 16),
                Icon(
                  Icons.shopping_cart,
                  size: 16,
                  color: secondaryTextColor,
                ),
                const SizedBox(width: 4),
                Text('$items items', style: AppTextStyles.body2),
                const Spacer(),
                Text(time, style: AppTextStyles.caption),
              ],
            ),
            if (saleData['pendingSync'] == true) ...[
              const SizedBox(height: 8),
              Builder(builder: (context) {
                final isError = saleData['syncError'] == true;
                final color = isError ? AppColors.error : AppColors.warning;
                final attempts =
                    (saleData['syncAttempts'] as num?)?.toInt() ?? 0;
                final label = isError
                    ? 'Sync error${attempts > 0 ? ' (tried $attempts×)' : ''} — tap Push to Firebase to retry'
                    : 'Pending sync';
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isError ? Icons.error_outline : Icons.cloud_off,
                          size: 14, color: color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          label,
                          style: AppTextStyles.caption.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (onRefund != null || onDelete != null || onPrint != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (onPrint != null)
                      TextButton.icon(
                        onPressed: onPrint,
                        icon: const Icon(Icons.print_outlined, size: 16),
                        label: const Text('Print'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    if (onRefund != null)
                      TextButton.icon(
                        onPressed: onRefund,
                        icon: const Icon(
                          Icons.assignment_return_outlined,
                          size: 16,
                        ),
                        label: const Text('Refund'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    if (onDelete != null)
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
