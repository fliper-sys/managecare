import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../business_profiles/business_profiles.dart';
import '../../../design/ambient_background.dart';
import '../../../design/app_tokens.dart';
import '../../../design/app_type.dart';
import '../../../design/components/components.dart';
import '../../../design/format.dart';
import '../../../presentation/sales/screens/receipt_detail_screen.dart';
import '../../../presentation/sales/screens/return_refund_screen.dart';
import '../../../presentation/shared/printing_action_sheet.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/retail_provider.dart';
import '../../../providers/sync_provider.dart';
import '../../../services/thermal_printing_service.dart';
import '../../../shared_features/session/tenant_scope.dart';
import 'sale_summary.dart';
import 'sales_pager.dart';

/// Retail sales history on v2. Reached only through `UiV2.enabledFor('retail')`.
///
/// Same data calls as the old `SalesHistoryScreen` (history pages, device-only
/// offline sales, period totals, delete, refund, print). Sale detail and the
/// refund form are still the existing screens.
class RetailHistoryScreen extends StatelessWidget {
  const RetailHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final id = context.select<BusinessProvider, String?>((p) => p.currentBusiness?.id);
    if (id == null) return const SizedBox.shrink();
    return TenantScope(tenantId: id, child: const _HistoryBody());
  }
}

class _HistoryBody extends StatefulWidget {
  const _HistoryBody();
  @override
  State<_HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<_HistoryBody> {
  static const _filters = [('all', 'All'), ('completed', 'Completed'), ('pending', 'Pending'), ('refunded', 'Refunded')];

  String _filter = 'all';
  DateTimeRange? _range;
  String _query = '';
  late SalesPager _pager = _makePager();
  final _scroll = ScrollController();

  bool _statsLoading = true;
  double _today = 0, _week = 0, _month = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 400) {
        _pager.more(start: _range?.start, end: _range?.end);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id = context.read<BusinessProvider>().currentBusiness?.id;
      if (id != null) {
        try {
          await context.read<RetailProvider>().initialize(id);
        } catch (_) {}
      }
      if (!mounted) return;
      _reload();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _pager.dispose();
    super.dispose();
  }

  SalesPager _makePager() {
    final retail = context.read<RetailProvider>();
    return SalesPager(
      filter: _filter,
      fetchPage: ({required limit, start, end, status, page}) =>
          retail.getSalesHistoryPage(limit: limit, start: start, end: end, status: status, page: page),
      fetchLocalPending: retail.getLocalPendingSales,
    );
  }

  void _reload() {
    _pager.reset(start: _range?.start, end: _range?.end);
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    try {
      final retail = context.read<RetailProvider>();
      final now = DateTime.now();
      if (_range != null) {
        final total = await retail.getTotalSalesForPeriod(startDate: _range!.start, endDate: _range!.end);
        if (!mounted) return;
        setState(() {
          _today = total;
          _week = 0;
          _month = 0;
          _statsLoading = false;
        });
        return;
      }
      final r = await Future.wait<double>([
        retail.getTotalSalesForPeriod(startDate: DateTime(now.year, now.month, now.day), endDate: now),
        retail.getTotalSalesForPeriod(startDate: now.subtract(const Duration(days: 6)), endDate: now),
        retail.getTotalSalesForPeriod(startDate: DateTime(now.year, now.month, 1), endDate: now),
      ]);
      if (!mounted) return;
      setState(() {
        _today = r[0];
        _week = r[1];
        _month = r[2];
        _statsLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _today = _week = _month = 0;
          _statsLoading = false;
        });
      }
    }
  }

  void _setFilter(String f) {
    if (f == _filter) return;
    final old = _pager;
    setState(() {
      _filter = f;
      _pager = _makePager();
    });
    old.dispose();
    _pager.reset(start: _range?.start, end: _range?.end);
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked == null || !mounted) return;
    setState(() => _range = picked);
    _reload();
  }

  Future<void> _syncNow() async {
    final sync = context.read<SyncProvider>();
    final retail = context.read<RetailProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await sync.syncNow();
    var pump = 0;
    try {
      pump = await retail.syncPendingPumpSales();
    } catch (_) {}
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(pump > 0 ? '$result; $pump pump sale${pump == 1 ? '' : 's'} synced' : result)));
    _reload();
  }

  Future<void> _refund(SaleSummary s) async {
    final result = await Navigator.of(context).push(MaterialPageRoute<dynamic>(builder: (_) => ReturnRefundScreen(sale: s.raw)));
    if (result != null && mounted) _reload();
  }

  Future<void> _delete(SaleSummary s) async {
    if (s.id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete sale?'),
        content: const Text('This will remove the sale from history and restore the sold stock.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<RetailProvider>().deleteSale(s.id, reason: 'Deleted from sales history');
      if (!mounted) return;
      _pager.removeById(s.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale deleted')));
      _loadStats();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete sale: $e')));
    }
  }

  Future<void> _print(SaleSummary s) async {
    final business = context.read<BusinessProvider>().currentBusiness;
    final items = [
      for (final raw in (s.raw['items'] as List?) ?? const [])
        if (raw is Map)
          {
            'name': raw['productName'] ?? raw['product_name'] ?? raw['name'] ?? 'Item',
            'quantity': raw['quantity'] ?? raw['qty'] ?? 1,
            'price': raw['price'] ?? raw['unitPrice'] ?? raw['unit_price'] ?? 0,
            'unit': raw['unit'] ?? raw['saleUnit'] ?? 'pcs',
            'pricingMode': raw['pricingMode'] ?? raw['priceType'],
          },
    ];
    final ref = s.raw['referenceId']?.toString() ?? s.raw['id']?.toString();
    final text = ThermalPrintingService.createCompleteReceipt(
      businessName: business?.name ?? 'My Business',
      paperWidth: 58,
      items: items,
      totalAmount: s.amount,
      paymentMethod: s.raw['paymentMethod'] ?? s.raw['payment_method'] ?? 'Cash',
      orderId: ref,
      customerName: s.raw['customerName']?.toString() ?? s.raw['customer']?.toString(),
    );
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.88,
        child: PrintingActionSheet(receiptText: text, businessName: business?.name ?? 'My Business', orderId: ref, saleData: s.raw),
      ),
    );
  }

  void _actions(SaleSummary s) {
    showManageSheet<void>(
      context,
      title: s.title,
      builder: (ctx) {
        final t = AppTokens.of(ctx);
        Widget action(IconData icon, String label, VoidCallback? run, {bool danger = false}) => TactilePressable(
              onTap: run == null
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      run();
                    },
              semanticLabel: label,
              child: Opacity(
                opacity: run == null ? 0.4 : 1,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
                  child: Row(children: [
                    Icon(icon, size: 22, color: danger ? t.danger : t.ink),
                    const SizedBox(width: AppTokens.s12),
                    Text(label, style: AppType.sans(size: 15, weight: FontWeight.w700, color: danger ? t.danger : t.ink)),
                  ]),
                ),
              ),
            );
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTokens.s16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            action(Icons.print_outlined, 'Print or share', () => _print(s)),
            // A sale can be refunded in parts, so only a fully refunded or
            // not-yet-uploaded sale is blocked, as in the old screen.
            action(Icons.undo_rounded, 'Refund or return', (s.isRefunded || s.pendingSync) ? null : () => _refund(s)),
            action(Icons.delete_outline_rounded, 'Delete sale', s.pendingSync ? null : () => _delete(s), danger: true),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final profile = BusinessProfiles.forType('retail')!;
    final retail = context.read<RetailProvider>();

    return Scaffold(
      body: AmbientBackground(
        accent: profile.accent,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTokens.s4, AppTokens.s4, AppTokens.s8, 0),
              child: Row(children: [
                IconButton(tooltip: 'Back', icon: Icon(Icons.arrow_back_rounded, color: t.ink), onPressed: () => Navigator.of(context).maybePop()),
                Expanded(child: Text('Sales history', style: AppType.sans(size: 20, weight: FontWeight.w800, color: t.ink))),
                Consumer<SyncProvider>(
                  builder: (context, sync, _) => IconButton(
                    tooltip: sync.hasPendingItems ? 'Upload ${sync.pendingItems} offline sales' : 'Sync',
                    onPressed: sync.isSyncing ? null : _syncNow,
                    icon: sync.isSyncing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Badge(
                            isLabelVisible: sync.hasPendingItems,
                            label: Text('${sync.pendingItems}'),
                            child: Icon(Icons.cloud_upload_outlined, color: t.ink),
                          ),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTokens.s16, AppTokens.s8, AppTokens.s16, AppTokens.s8),
              child: Row(children: [
                Expanded(child: _Stat(label: _range == null ? 'Today' : 'Range', value: _today, loading: _statsLoading)),
                if (_range == null) ...[
                  const SizedBox(width: AppTokens.s8),
                  Expanded(child: _Stat(label: '7 days', value: _week, loading: _statsLoading)),
                  const SizedBox(width: AppTokens.s8),
                  Expanded(child: _Stat(label: 'Month', value: _month, loading: _statsLoading)),
                ],
              ]),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
                children: [
                  for (final f in _filters) _Chip(label: f.$2, on: _filter == f.$1, accent: profile.accent, onTap: () => _setFilter(f.$1)),
                  _Chip(
                    label: _range == null ? 'Dates' : '${_range!.start.day}/${_range!.start.month} - ${_range!.end.day}/${_range!.end.month}',
                    on: _range != null,
                    accent: profile.accent,
                    icon: Icons.date_range_rounded,
                    onTap: _pickRange,
                  ),
                  if (_range != null)
                    _Chip(
                      label: 'Clear dates',
                      on: false,
                      accent: profile.accent,
                      onTap: () {
                        setState(() => _range = null);
                        _reload();
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTokens.s16, AppTokens.s4, AppTokens.s16, AppTokens.s8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: AppType.sans(size: 15, color: t.ink),
                decoration: InputDecoration(
                  hintText: 'Search reference, customer or product',
                  hintStyle: AppType.sans(size: 15, color: t.inkFaint),
                  prefixIcon: Icon(Icons.search_rounded, color: t.inkMuted),
                  filled: true,
                  fillColor: t.raised,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.rControl), borderSide: BorderSide(color: t.line)),
                ),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _pager,
                builder: (context, _) => _list(context, retail),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, RetailProvider retail) {
    final t = AppTokens.of(context);
    final p = _pager;
    if (p.loading) {
      return ListView.separated(
        padding: const EdgeInsets.all(AppTokens.s16),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: AppTokens.s8),
        itemBuilder: (_, __) => const SkeletonBlock(height: 92, radius: AppTokens.rCard),
      );
    }
    if (p.error != null && p.items.isEmpty) {
      return _Message(title: p.error!, action: 'Try again', onAction: _reload);
    }
    final rows = <SaleSummary>[];
    for (var i = 0; i < p.items.length; i++) {
      final s = SaleSummary.fromMap(p.items[i], index: i, nameForProduct: (id) {
        for (final pr in retail.products) {
          if (pr.id == id) return pr.name;
        }
        return null;
      });
      if (s.matches(_query)) rows.add(s);
    }
    if (rows.isEmpty) {
      return _Message(
        title: _query.isEmpty ? 'No sales found' : 'Nothing matches',
        body: _query.isEmpty ? 'Your ${_filter == 'all' ? '' : '$_filter '}sales will appear here.' : 'Try another search.',
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppTokens.s16, AppTokens.s4, AppTokens.s16, AppTokens.s32),
        itemCount: rows.length + (p.loadingMore || (p.error != null) ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: AppTokens.s8),
        itemBuilder: (context, i) {
          if (i >= rows.length) {
            return p.error != null
                ? _Message(title: p.error!, action: 'Try again', onAction: () => p.more(start: _range?.start, end: _range?.end))
                : Padding(padding: const EdgeInsets.all(AppTokens.s16), child: Center(child: CircularProgressIndicator(color: t.brand)));
          }
          final s = rows[i];
          return StaggerIn(index: i < 8 ? i : 0, child: _SaleRow(sale: s, onMore: () => _actions(s)));
        },
      ),
    );
  }
}

class _SaleRow extends StatelessWidget {
  const _SaleRow({required this.sale, required this.onMore});
  final SaleSummary sale;
  final VoidCallback onMore;

  StatusTone get _tone {
    switch (sale.status.toLowerCase()) {
      case 'completed':
        return StatusTone.success;
      case 'pending':
      case 'partially_refunded':
        return StatusTone.warning;
      case 'refunded':
        return StatusTone.danger;
      default:
        return StatusTone.neutral;
    }
  }

  String get _statusLabel => sale.isPartiallyRefunded ? 'Partly refunded' : (sale.status.isEmpty ? '' : sale.status[0].toUpperCase() + sale.status.substring(1));

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return ManageCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReceiptDetailScreen(saleData: sale.raw))),
      semanticLabel: '${sale.title}, ${formatNairaPrecise(sale.amount)}, ${sale.status}',
      padding: const EdgeInsets.fromLTRB(AppTokens.s16, AppTokens.s12, AppTokens.s4, AppTokens.s12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(sale.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.sans(size: 15, weight: FontWeight.w800, color: t.ink))),
              const SizedBox(width: AppTokens.s8),
              StatusChip(label: _statusLabel, tone: _tone),
            ]),
            const SizedBox(height: 2),
            Text(sale.customer, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.sans(size: 13, weight: FontWeight.w600, color: t.inkMuted)),
            Text(sale.itemsText, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.sans(size: 12, color: t.inkFaint)),
            const SizedBox(height: 4),
            Row(children: [
              Text(formatNairaPrecise(sale.amount), style: AppType.mono(size: 16, weight: FontWeight.w700, color: t.ink)),
              const SizedBox(width: AppTokens.s8),
              Flexible(
                child: Text('${sale.paymentMethod} · ${relativeTime(sale.createdAt)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.sans(size: 12, color: t.inkMuted)),
              ),
              if (sale.pendingSync) ...[
                const SizedBox(width: AppTokens.s8),
                const StatusChip(label: 'Not uploaded', tone: StatusTone.warning),
              ],
            ]),
          ]),
        ),
        IconButton(tooltip: 'Actions for ${sale.title}', icon: Icon(Icons.more_vert_rounded, color: t.inkMuted), onPressed: onMore),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.loading});
  final String label;
  final double value;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return ManageCard(
      padding: const EdgeInsets.all(AppTokens.s12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppType.sans(size: 12, weight: FontWeight.w600, color: t.inkMuted)),
        const SizedBox(height: 4),
        if (loading)
          const SkeletonBlock(height: 18, width: 70)
        else
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(formatNaira(value), style: AppType.mono(size: 16, weight: FontWeight.w700, color: t.ink))),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.accent, required this.onTap, this.icon});
  final String label;
  final bool on;
  final Color accent;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: AppTokens.s8),
      child: TactilePressable(
        onTap: onTap,
        semanticLabel: label,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppTokens.tint(accent) : t.raised,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? accent : t.line),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 16, color: t.inkMuted), const SizedBox(width: 6)],
            Text(label, style: AppType.sans(size: 13, weight: FontWeight.w700, color: on ? t.ink : t.inkMuted)),
          ]),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, this.body, this.action, this.onAction});
  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, textAlign: TextAlign.center, style: AppType.sans(size: 16, weight: FontWeight.w700, color: t.ink)),
          if (body != null) ...[
            const SizedBox(height: AppTokens.s8),
            Text(body!, textAlign: TextAlign.center, style: AppType.sans(size: 13, color: t.inkMuted)),
          ],
          if (action != null) ...[
            const SizedBox(height: AppTokens.s16),
            TactilePressable(
              onTap: onAction,
              semanticLabel: action,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 140),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: AppTokens.s24),
                decoration: BoxDecoration(color: t.brand, borderRadius: BorderRadius.circular(AppTokens.rControl)),
                child: Text(action!, style: AppType.sans(size: 14, weight: FontWeight.w700, color: t.onBrand)),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
