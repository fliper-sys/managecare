import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../design/app_type.dart';
import '../../design/components/components.dart';
import 'business_session.dart';
import 'tenant_scope.dart';

/// Chooses what fills the screen for the current session state.
///
/// Stateless and builder-driven, so the router passes the real screens in and
/// tests pass stubs. Every business screen is built inside a [TenantScope].
class SessionGate extends StatelessWidget {
  const SessionGate({
    super.key,
    required this.state,
    required this.v2Builder,
    required this.legacyBuilder,
    required this.expiredBuilder,
    required this.unknownTypeBuilder,
    this.onRetry,
    this.onAddBusiness,
    this.now,
  });

  final BusinessSessionState state;

  /// Builders receive the business they render.
  final Widget Function(BuildContext, BusinessRef, ResolvedProfile) v2Builder;
  final Widget Function(BuildContext, BusinessRef) legacyBuilder;
  final Widget Function(BuildContext, BusinessRef, ResolvedProfile) expiredBuilder;
  final Widget Function(BuildContext, BusinessRef) unknownTypeBuilder;
  final VoidCallback? onRetry;
  final VoidCallback? onAddBusiness;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    switch (state.phase) {
      case SessionPhase.loadingList:
        return const SessionSkeleton();
      case SessionPhase.switching:
        final target = state.pending;
        return SessionSkeleton(
          title: target?.name,
          accent: target == null ? null : resolveProfile(target, now: now).profile?.accent,
        );
      case SessionPhase.error:
        return _Centered(
          title: 'Could not load your business',
          body: state.errorMessage ?? 'Check your connection and try again.',
          action: onRetry == null ? null : 'Try again',
          onAction: onRetry,
        );
      case SessionPhase.noBusinesses:
        return _Centered(
          title: 'No business yet',
          body: 'Create your first business to get started.',
          action: onAddBusiness == null ? null : 'Add a business',
          onAction: onAddBusiness,
        );
      case SessionPhase.ready:
        final b = state.current!;
        final r = resolveProfile(b, now: now);
        final Widget child;
        switch (r.state) {
          case ProfileState.v2:
            child = v2Builder(context, b, r);
          case ProfileState.legacy:
            child = legacyBuilder(context, b);
          case ProfileState.planExpired:
            child = expiredBuilder(context, b, r);
          case ProfileState.unknownType:
            child = unknownTypeBuilder(context, b);
        }
        return TenantScope(tenantId: b.id, child: child);
    }
  }
}

/// Placeholder shown while the list loads or a switch is in flight. Shows the
/// target business name once it is known, so a switch feels immediate.
class SessionSkeleton extends StatelessWidget {
  const SessionSkeleton({super.key, this.title, this.accent});
  final String? title;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Semantics(
      liveRegion: true,
      label: title == null ? 'Loading' : 'Switching to $title',
      child: ColoredBox(
        color: t.page,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: accent ?? t.line, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: AppTokens.s8),
                  if (title != null)
                    Expanded(
                      child: Text(title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.sans(size: 18, weight: FontWeight.w800, color: t.ink)),
                    )
                  else
                    const SkeletonBlock(width: 160, height: 20),
                ]),
                const SizedBox(height: AppTokens.s24),
                const SkeletonBlock(height: 168, radius: AppTokens.rHero),
                const SizedBox(height: AppTokens.s16),
                const Row(children: [
                  Expanded(child: SkeletonBlock(height: 84, radius: AppTokens.rCard)),
                  SizedBox(width: AppTokens.s12),
                  Expanded(child: SkeletonBlock(height: 84, radius: AppTokens.rCard)),
                ]),
                const SizedBox(height: AppTokens.s16),
                const SkeletonBlock(height: 64, radius: AppTokens.rRow),
                const SizedBox(height: AppTokens.s8),
                const SkeletonBlock(height: 64, radius: AppTokens.rRow),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.title, required this.body, this.action, this.onAction});
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return ColoredBox(
      color: t.page,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title, textAlign: TextAlign.center, style: AppType.sans(size: 18, weight: FontWeight.w800, color: t.ink)),
            const SizedBox(height: AppTokens.s8),
            Text(body, textAlign: TextAlign.center, style: AppType.sans(size: 14, color: t.inkMuted)),
            if (action != null) ...[
              const SizedBox(height: AppTokens.s24),
              TactilePressable(
                onTap: onAction,
                semanticLabel: action,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48, minWidth: 180),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: AppTokens.s24),
                  decoration: BoxDecoration(color: t.brand, borderRadius: BorderRadius.circular(AppTokens.rControl)),
                  child: Text(action!, style: AppType.sans(size: 14, weight: FontWeight.w700, color: t.onBrand)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
