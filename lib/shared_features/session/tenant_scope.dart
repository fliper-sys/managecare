import 'package:flutter/widgets.dart';

/// Scopes everything below it to one business.
///
/// Changing [tenantId] rebuilds the subtree with a fresh element tree, so
/// cart contents, filters, search text, scroll offsets and dismissed rows of
/// the previous business cannot leak into the next one.
class TenantScope extends StatelessWidget {
  const TenantScope({super.key, required this.tenantId, required this.child});

  final String tenantId;
  final Widget child;

  /// The business id of the nearest scope. Throws in debug if there is none,
  /// because a screen reading business data without a scope is a bug.
  static String idOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_TenantInherited>();
    assert(scope != null, 'No TenantScope above this widget');
    return scope!.tenantId;
  }

  static String? maybeIdOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TenantInherited>()?.tenantId;

  @override
  Widget build(BuildContext context) => _TenantInherited(
        tenantId: tenantId,
        child: KeyedSubtree(key: ValueKey<String>('tenant:$tenantId'), child: child),
      );
}

class _TenantInherited extends InheritedWidget {
  const _TenantInherited({required this.tenantId, required super.child});
  final String tenantId;

  @override
  bool updateShouldNotify(_TenantInherited old) => old.tenantId != tenantId;
}
