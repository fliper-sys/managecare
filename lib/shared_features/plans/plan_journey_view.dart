import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../design/app_type.dart';
import '../../design/components/components.dart';
import '../../design/format.dart';
import 'plan_models.dart';

/// Tier cards with a billing-length picker, then a confirm sheet. Shared by
/// every business type; the accent and the plan list are the only inputs that
/// differ. Stateless about money: it reports the chosen plan id and the caller
/// runs payment.
class PlanJourneyView extends StatefulWidget {
  const PlanJourneyView({
    super.key,
    required this.tiers,
    required this.accent,
    required this.onConfirm,
    this.currentTierId,
    this.recommendedTierId,
    this.expired = false,
  });

  final List<TierGroup> tiers;
  final Color accent;
  final String? currentTierId;
  final String? recommendedTierId;

  /// True when the plan has lapsed: the copy says renew, not upgrade.
  final bool expired;
  final ValueChanged<PlanChoice> onConfirm;

  @override
  State<PlanJourneyView> createState() => _PlanJourneyViewState();
}

class _PlanJourneyViewState extends State<PlanJourneyView> {
  final Map<String, int> _picked = {}; // tierId -> choice index

  PlanChoice _choice(TierGroup g) => g.choices[(_picked[g.tierId] ?? 0).clamp(0, g.choices.length - 1)];

  Future<void> _confirm(TierGroup g) async {
    final c = _choice(g);
    final ok = await showManageSheet<bool>(
      context,
      title: widget.expired ? 'Renew plan' : 'Confirm plan',
      builder: (ctx) => _ConfirmBody(group: g, choice: c, accent: widget.accent),
    );
    if (ok == true) widget.onConfirm(c);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    if (widget.tiers.isEmpty) {
      return Center(
        child: Text('No plans available for this business.',
            style: AppType.sans(size: 14, color: t.inkMuted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppTokens.s16, AppTokens.s8, AppTokens.s16, AppTokens.s32),
      itemCount: widget.tiers.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppTokens.s12),
      itemBuilder: (context, i) {
        final g = widget.tiers[i];
        final isCurrent = g.tierId == widget.currentTierId;
        final isRec = g.tierId == widget.recommendedTierId;
        return StaggerIn(
          index: i,
          child: _TierCard(
            group: g,
            accent: widget.accent,
            isCurrent: isCurrent,
            isRecommended: isRec,
            expired: widget.expired,
            selected: _picked[g.tierId] ?? 0,
            onPick: (n) => setState(() => _picked[g.tierId] = n),
            onChoose: () => _confirm(g),
          ),
        );
      },
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.group,
    required this.accent,
    required this.isCurrent,
    required this.isRecommended,
    required this.expired,
    required this.selected,
    required this.onPick,
    required this.onChoose,
  });

  final TierGroup group;
  final Color accent;
  final bool isCurrent;
  final bool isRecommended;
  final bool expired;
  final int selected;
  final ValueChanged<int> onPick;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final c = group.choices[selected.clamp(0, group.choices.length - 1)];
    final saving = group.bestSavingPercent;
    final cta = isCurrent ? (expired ? 'Renew' : 'Extend') : 'Choose ${group.name}';

    return Container(
      padding: const EdgeInsets.all(AppTokens.s16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppTokens.rCard),
        border: Border.all(color: isRecommended ? accent : t.line, width: isRecommended ? 1.5 : 1),
        boxShadow: t.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(group.name, style: AppType.sans(size: 18, weight: FontWeight.w800, color: t.ink)),
            const SizedBox(width: AppTokens.s8),
            if (isCurrent) const StatusChip(label: 'Current', tone: StatusTone.info),
            if (!isCurrent && isRecommended) const StatusChip(label: 'Popular', tone: StatusTone.success),
          ]),
          const SizedBox(height: AppTokens.s12),
          Text(formatNaira(c.price), style: AppType.mono(size: 26, weight: FontWeight.w700, color: t.ink)),
          Text('${c.durationLabel} · ${formatNaira(c.perMonth)} a month',
              style: AppType.sans(size: 12, color: t.inkMuted)),
          if (group.choices.length > 1) ...[
            const SizedBox(height: AppTokens.s12),
            Wrap(spacing: AppTokens.s8, runSpacing: AppTokens.s8, children: [
              for (var i = 0; i < group.choices.length; i++)
                _LengthChip(
                  label: group.choices[i].durationLabel,
                  selected: i == selected,
                  accent: accent,
                  onTap: () => onPick(i),
                ),
            ]),
            if (saving > 0) ...[
              const SizedBox(height: AppTokens.s8),
              Text('Longest plan saves $saving%', style: AppType.sans(size: 12, weight: FontWeight.w600, color: t.success)),
            ],
          ],
          const SizedBox(height: AppTokens.s12),
          for (final f in group.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Icon(Icons.check_rounded, size: 16, color: accent),
                const SizedBox(width: AppTokens.s8),
                Expanded(child: Text(f, style: AppType.sans(size: 13, color: t.ink))),
              ]),
            ),
          const SizedBox(height: AppTokens.s12),
          TactilePressable(
            onTap: onChoose,
            semanticLabel: '$cta, ${group.name}',
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(AppTokens.rControl)),
              child: Text(cta, style: AppType.sans(size: 14, weight: FontWeight.w700, color: t.onAccent)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LengthChip extends StatelessWidget {
  const _LengthChip({required this.label, required this.selected, required this.accent, required this.onTap});
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return TactilePressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40, minWidth: 64),
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.s12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTokens.tint(accent) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.rControl),
          border: Border.all(color: selected ? accent : t.line),
        ),
        child: Text(label, style: AppType.sans(size: 13, weight: FontWeight.w700, color: selected ? t.ink : t.inkMuted)),
      ),
    );
  }
}

class _ConfirmBody extends StatelessWidget {
  const _ConfirmBody({required this.group, required this.choice, required this.accent});
  final TierGroup group;
  final PlanChoice choice;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    Widget line(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text(k, style: AppType.sans(size: 13, color: t.inkMuted))),
            Text(v, style: AppType.sans(size: 14, weight: FontWeight.w700, color: t.ink)),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTokens.s16, AppTokens.s8, AppTokens.s16, AppTokens.s16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        line('Plan', group.name),
        line('Length', '${choice.durationLabel} (${choice.days} days)'),
        Divider(color: t.line),
        Row(children: [
          Expanded(child: Text('Total', style: AppType.sans(size: 14, weight: FontWeight.w700, color: t.ink))),
          Text(formatNaira(choice.price), style: AppType.mono(size: 20, weight: FontWeight.w700, color: t.ink)),
        ]),
        const SizedBox(height: AppTokens.s16),
        TactilePressable(
          onTap: () => Navigator.of(context).pop(true),
          semanticLabel: 'Pay ${formatNaira(choice.price)}',
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(AppTokens.rControl)),
            child: Text('Pay ${formatNaira(choice.price)}',
                style: AppType.sans(size: 15, weight: FontWeight.w800, color: t.onAccent)),
          ),
        ),
      ]),
    );
  }
}
