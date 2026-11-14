import 'package:flutter/material.dart';

import '../../../business_profiles/business_profiles.dart';
import '../../../design/app_tokens.dart';
import '../../../design/app_type.dart';
import '../../../design/components/components.dart';
import '../../../design/format.dart';
import 'retail_home_data.dart';

/// The v2 Retail home, built to the flagship demo. Pure presentation: it reads
/// no providers. Data comes in as [RetailHomeData]; taps go out as callbacks.
class RetailHomeView extends StatelessWidget {
  const RetailHomeView({
    super.key,
    required this.profile,
    required this.data,
    required this.onQuickAction,
    required this.onOpenPlan,
    required this.onSearch,
    required this.onNotifications,
    required this.onRowDone,
  });

  final BusinessProfile profile;
  final RetailHomeData data;
  final void Function(QuickAction action) onQuickAction;
  final VoidCallback onOpenPlan;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final void Function(String rowId) onRowDone;

  String _delta() {
    final d = data.deltaPercent;
    final sign = d >= 0 ? '+' : '−';
    return '$sign${d.abs().toStringAsFixed(1)}% ${profile.kpiDeltaLabel}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final accent = profile.accent;
    final plan = data.plan;
    var i = 0;
    Widget stag(Widget w) => StaggerIn(index: i++, child: w);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppTokens.s16, AppTokens.s8, AppTokens.s16, 120),
      children: [
        stag(_Header(name: data.businessName, title: profile.label, onSearch: onSearch, onNotifications: onNotifications)),
        const SizedBox(height: AppTokens.s12),
        stag(HeroKpiCard(
          accent: accent,
          label: profile.kpiLabel,
          amount: data.salesToday,
          format: (v) => formatNaira(v),
          deltaLabel: _delta(),
          subline: '${data.salesCount} ${data.salesCount == 1 ? 'sale' : 'sales'}',
          spark: data.spark,
          footerLeft: '${plan.familyLabel} · ${plan.tierName}',
          footerRight: '${plan.daysLeft} days left',
        )),
        const SizedBox(height: AppTokens.s12),
        stag(QuickActionsGrid(
          accent: accent,
          actions: [for (final a in profile.quickActions) QuickActionTileData(id: a.id, label: a.label, icon: a.icon)],
          onTap: (tile) => onQuickAction(profile.quickActions.firstWhere((a) => a.id == tile.id)),
        )),
        const SizedBox(height: AppTokens.s12),
        stag(PlanSummaryCard(plan: plan, accent: accent, onTap: onOpenPlan)),
        if (data.lowStock.isNotEmpty) ...[
          const SizedBox(height: AppTokens.s12),
          stag(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(child: Text('Low stock', style: AppType.sans(size: 13, weight: FontWeight.w800, color: t.ink))),
                Text('swipe or tap', style: AppType.sans(size: 10, color: t.inkFaint)),
              ],
            ),
          )),
          const SizedBox(height: AppTokens.s8),
          for (final row in data.lowStock) ...[
            stag(SwipeRow(
              key: ValueKey(row.id),
              accent: accent,
              actionLabel: 'Reorder',
              onAction: () => onRowDone(row.id),
              child: _AttentionTile(row: row, accent: accent, onDone: () => onRowDone(row.id)),
            )),
            const SizedBox(height: AppTokens.s8),
          ],
        ],
        if (data.pending.isNotEmpty) ...[
          const SizedBox(height: AppTokens.s4),
          stag(ManageCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Needs a look', style: AppType.sans(size: 13, weight: FontWeight.w800, color: t.ink)),
                const SizedBox(height: AppTokens.s8),
                for (final p in data.pending)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(p.label, style: AppType.sans(size: 12, color: t.inkMuted))),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppTokens.tint(accent),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            child: Text('${p.count}', style: AppType.mono(size: 12, weight: FontWeight.w800, color: accent)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          )),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.title, required this.onSearch, required this.onNotifications});

  final String name;
  final String title;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    Widget round(IconData icon, String label, VoidCallback onTap) => SizedBox(
          width: 48,
          height: 48,
          child: ManageCard(
            padding: EdgeInsets.zero,
            onTap: onTap,
            semanticLabel: label,
            child: Center(child: Icon(icon, size: 20, color: t.ink)),
          ),
        );
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.sans(size: 11, weight: FontWeight.w700, color: t.inkMuted)),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.sans(size: 20, weight: FontWeight.w800, color: t.ink)),
            ],
          ),
        ),
        round(Icons.search, 'Search', onSearch),
        const SizedBox(width: AppTokens.s8),
        round(Icons.notifications_none, 'Notifications', onNotifications),
      ],
    );
  }
}

class _AttentionTile extends StatelessWidget {
  const _AttentionTile({required this.row, required this.accent, required this.onDone});

  final AttentionRow row;
  final Color accent;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppTokens.rRow),
        border: Border.all(color: t.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.sans(size: 13, weight: FontWeight.w700, color: t.ink)),
                  Text(row.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.sans(size: 11, color: t.inkMuted)),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.s8),
            TactilePressable(
              onTap: onDone,
              semanticLabel: 'Reorder ${row.title}',
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 40),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTokens.tint(accent),
                    borderRadius: BorderRadius.circular(AppTokens.rControl),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('Reorder', style: AppType.sans(size: 10, weight: FontWeight.w800, color: accent)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
