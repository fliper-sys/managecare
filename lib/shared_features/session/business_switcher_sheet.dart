import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../design/app_type.dart';
import '../../design/components/components.dart';
import 'business_session.dart';

/// Opens the v2 switcher. [onSelect] receives the chosen business; the caller
/// runs the provider switch and the sheet closes itself straight away so the
/// shell can show the switching skeleton.
Future<void> showBusinessSwitcher(
  BuildContext context, {
  required BusinessSessionState state,
  required ValueChanged<BusinessRef> onSelect,
  VoidCallback? onAddBusiness,
  VoidCallback? onRetry,
}) {
  return showManageSheet<void>(
    context,
    title: 'Your businesses',
    builder: (ctx) => BusinessSwitcherView(
      state: state,
      onSelect: (b) {
        Navigator.of(ctx).pop();
        onSelect(b);
      },
      onAddBusiness: onAddBusiness,
      onRetry: onRetry,
    ),
  );
}

/// Sheet body. Stateless: every state comes from [state].
class BusinessSwitcherView extends StatelessWidget {
  const BusinessSwitcherView({
    super.key,
    required this.state,
    required this.onSelect,
    this.onAddBusiness,
    this.onRetry,
    DateTime? now,
  }) : _now = now;

  final BusinessSessionState state;
  final ValueChanged<BusinessRef> onSelect;
  final VoidCallback? onAddBusiness;
  final VoidCallback? onRetry;
  final DateTime? _now;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final children = <Widget>[];

    if (state.usingCache) {
      children.add(_Banner(
        icon: Icons.cloud_off_rounded,
        text: 'Offline. Showing saved businesses.',
        bg: t.warningBg,
        fg: t.warning,
      ));
    }

    switch (state.phase) {
      case SessionPhase.loadingList:
        children.addAll(List.generate(3, (i) => const _SkeletonRow()));
      case SessionPhase.error:
        children.add(_Message(
          title: 'Could not load your businesses',
          body: state.errorMessage ?? 'Check your connection and try again.',
          action: onRetry == null ? null : 'Try again',
          onAction: onRetry,
        ));
      case SessionPhase.noBusinesses:
        children.add(_Message(
          title: 'No business yet',
          body: 'Create your first business to start.',
          action: onAddBusiness == null ? null : 'Add a business',
          onAction: onAddBusiness,
        ));
      case SessionPhase.ready:
      case SessionPhase.switching:
        final locked = state.phase == SessionPhase.switching;
        for (var i = 0; i < state.businesses.length; i++) {
          final b = state.businesses[i];
          children.add(StaggerIn(
            index: i,
            child: _BusinessRow(
              business: b,
              resolved: resolveProfile(b, now: _now),
              isCurrent: b.id == state.currentId,
              isPending: b.id == state.pendingId,
              locked: locked,
              onTap: () => onSelect(b),
            ),
          ));
        }
        if (onAddBusiness != null) {
          children.add(const SizedBox(height: AppTokens.s8));
          children.add(_AddRow(onTap: locked ? null : onAddBusiness!));
        }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTokens.s16, AppTokens.s8, AppTokens.s16, AppTokens.s16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _BusinessRow extends StatelessWidget {
  const _BusinessRow({
    required this.business,
    required this.resolved,
    required this.isCurrent,
    required this.isPending,
    required this.locked,
    required this.onTap,
  });

  final BusinessRef business;
  final ResolvedProfile resolved;
  final bool isCurrent;
  final bool isPending;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final accent = resolved.profile?.accent ?? t.brand;
    final typeLabel = resolved.profile?.label ?? _title(business.type);
    final enabled = !locked && !isCurrent;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.s8),
      child: Opacity(
        opacity: locked && !isPending ? 0.5 : 1,
        child: TactilePressable(
          onTap: enabled ? onTap : null,
          semanticLabel: '${business.name}, $typeLabel${isCurrent ? ', current' : ''}',
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.s12, vertical: AppTokens.s12),
            decoration: BoxDecoration(
              color: isCurrent ? AppTokens.tint(accent) : t.raised,
              borderRadius: BorderRadius.circular(AppTokens.rRow),
              border: Border.all(color: isCurrent ? accent : t.line),
            ),
            child: Row(
              children: [
                _Monogram(name: business.name, accent: accent),
                const SizedBox(width: AppTokens.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(business.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.sans(size: 15, weight: FontWeight.w700, color: t.ink)),
                      const SizedBox(height: 2),
                      Text(typeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.sans(size: 12, color: t.inkMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: AppTokens.s8),
                if (isPending)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                else
                  _trailing(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _trailing() {
    if (isCurrent) return const StatusChip(label: 'Current', tone: StatusTone.info);
    switch (resolved.state) {
      case ProfileState.planExpired:
        return const StatusChip(label: 'Plan expired', tone: StatusTone.warning);
      case ProfileState.unknownType:
        return const StatusChip(label: 'Set type', tone: StatusTone.neutral);
      case ProfileState.v2:
      case ProfileState.legacy:
        return const SizedBox.shrink();
    }
  }

  static String _title(String s) =>
      s.isEmpty ? 'Business' : s[0].toUpperCase() + s.substring(1);
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.name, required this.accent});
  final String name;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(AppTokens.rControl)),
      child: Text(letter, style: AppType.sans(size: 16, weight: FontWeight.w800, color: t.onAccent)),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return TactilePressable(
      onTap: onTap,
      semanticLabel: 'Add a business',
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.rRow),
          border: Border.all(color: t.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 20, color: t.inkMuted),
            const SizedBox(width: AppTokens.s8),
            Text('Add a business',
                style: AppType.sans(size: 14, weight: FontWeight.w700, color: t.inkMuted)),
          ],
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(bottom: AppTokens.s8),
        child: SkeletonBlock(height: 64, radius: AppTokens.rRow),
      );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, required this.bg, required this.fg});
  final IconData icon;
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: AppTokens.s12),
        padding: const EdgeInsets.all(AppTokens.s12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppTokens.rControl)),
        child: Row(children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: AppTokens.s8),
          Expanded(child: Text(text, style: AppType.sans(size: 13, weight: FontWeight.w600, color: fg))),
        ]),
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body, this.action, this.onAction});
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.s24),
      child: Column(children: [
        Text(title, textAlign: TextAlign.center, style: AppType.sans(size: 16, weight: FontWeight.w700, color: t.ink)),
        const SizedBox(height: AppTokens.s8),
        Text(body, textAlign: TextAlign.center, style: AppType.sans(size: 13, color: t.inkMuted)),
        if (action != null) ...[
          const SizedBox(height: AppTokens.s16),
          TactilePressable(
            onTap: onAction,
            semanticLabel: action,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 160),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.s24),
              decoration: BoxDecoration(color: t.brand, borderRadius: BorderRadius.circular(AppTokens.rControl)),
              child: Text(action!, style: AppType.sans(size: 14, weight: FontWeight.w700, color: t.onBrand)),
            ),
          ),
        ],
      ]),
    );
  }
}
