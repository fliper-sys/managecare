import 'package:flutter/material.dart';

import '../app_tokens.dart';
import 'tactile_pressable.dart';

/// The standard v2 card: flat surface, 1 px border, radius 16. Pass [onTap] to
/// make it pressable.
class ManageCard extends StatelessWidget {
  const ManageCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppTokens.s16),
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppTokens.rCard),
        border: Border.all(color: t.line),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return TactilePressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      pressedScale: 0.975,
      child: card,
    );
  }
}
