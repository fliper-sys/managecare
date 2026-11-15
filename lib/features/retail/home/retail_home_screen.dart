import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../business_profiles/business_profiles.dart';
import '../../../core/constants/routes.dart' show Routes;
import '../../../design/ambient_background.dart';
import '../../../design/components/plan_summary_card.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/retail_provider.dart';
import '../../../shared_features/session/tenant_scope.dart';
import 'retail_home_data.dart';
import 'retail_home_view.dart';

/// Retail home on v2. The only retail v2 file that reads providers.
///
/// Built inside a [TenantScope] so a business switch discards its state.
/// Reached only through `UiV2.enabledFor('retail')` in the router.
class RetailHomeScreen extends StatelessWidget {
  const RetailHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final id = context.select<BusinessProvider, String?>((p) => p.currentBusiness?.id);
    if (id == null) return const SizedBox.shrink();
    return TenantScope(tenantId: id, child: const _RetailHomeBody());
  }
}

class _RetailHomeBody extends StatefulWidget {
  const _RetailHomeBody();
  @override
  State<_RetailHomeBody> createState() => _RetailHomeBodyState();
}

class _RetailHomeBodyState extends State<_RetailHomeBody> {
  double _salesToday = 0;
  final Set<String> _done = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final retail = context.read<RetailProvider>();
      final id = context.read<BusinessProvider>().currentBusiness?.id;
      if (id == null) return;
      await retail.initialize(id);
      final total = await retail.getTodaysSalesTotal();
      if (mounted) setState(() => _salesToday = total);
    });
  }

  RetailHomeData _data(BusinessProvider bp, RetailProvider retail, String greeting) {
    final b = bp.currentBusiness!;
    final end = b.subscriptionEndDate;
    final daysLeft = end == null ? 0 : end.difference(DateTime.now()).inDays.clamp(0, 9999);
    final limit = bp.getLimitFor('products') ?? 0;
    final low = retail.products.where((p) => p.stock < 10 && !_done.contains(p.id)).toList();
    return RetailHomeData(
      businessName: b.name,
      greetingName: greeting,
      salesToday: _salesToday,
      // Yesterday and the 7-day trend need a sales-summary call that does
      // not exist for retail yet; shown as flat until it is added.
      deltaPercent: 0,
      salesCount: 0,
      spark: const [0, 0],
      plan: PlanSummary(
        familyLabel: 'Standard',
        tierName: bp.normalizedSubscriptionTier,
        daysLeft: daysLeft,
        periodDays: 90,
        usageLabel: 'Products',
        used: retail.products.length,
        limit: limit,
      ),
      lowStock: [
        for (final p in low.take(5))
          AttentionRow(id: p.id, title: p.name, subtitle: '${p.stock.toStringAsFixed(0)} left'),
      ],
      pending: [CountRow(label: 'Low stock items', count: low.length)],
    );
  }

  void _go(String route) => Navigator.of(context).pushNamed(route);

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BusinessProvider>();
    final retail = context.watch<RetailProvider>();
    final name = context.watch<AuthProvider>().currentUser?.name ?? '';
    if (bp.currentBusiness == null) return const SizedBox.shrink();
    final profile = BusinessProfiles.forType('retail')!;

    return Scaffold(
      body: AmbientBackground(
        accent: profile.accent,
        child: SafeArea(
          child: RetailHomeView(
            profile: profile,
            data: _data(bp, retail, name.split(' ').first),
            onQuickAction: (a) {
              switch (a.target) {
                case QuickActionTarget.newSale:
                  _go(Routes.retailPos);
                case QuickActionTarget.addItem:
                  _go(Routes.retailAddProduct);
                case QuickActionTarget.stockCount:
                case QuickActionTarget.workFeed:
                  _go(Routes.retailProducts);
                case QuickActionTarget.reports:
                  _go(Routes.retailStoreReports);
              }
            },
            onOpenPlan: () => _go(Routes.subscription),
            onSearch: () => _go(Routes.retailProducts),
            onNotifications: () => _go(Routes.notifications),
            onRowDone: (id) => setState(() => _done.add(id)),
          ),
        ),
      ),
    );
  }
}
