import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../app_type.dart';
import 'manage_card.dart';

@immutable
class QuickActionTileData {
  const QuickActionTileData({required this.id, required this.label, required this.icon});

  final String id;
  final String label;
  final IconData icon;
}

/// A row of quick-action tiles: a tinted icon well over a short label.
class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({
    super.key,
    required this.actions,
    required this.accent,
    required this.onTap,
  });

  final List<QuickActionTileData> actions;
  final Color accent;
  final ValueChanged<QuickActionTileData> onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: AppTokens.s8),
          Expanded(
            child: ManageCard(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.s12, horizontal: AppTokens.s4),
              semanticLabel: actions[i].label,
              onTap: () => onTap(actions[i]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTokens.tint(accent),
                      borderRadius: BorderRadius.circular(AppTokens.rControl),
                    ),
                    child: Icon(actions[i].icon, size: 20, color: accent),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    actions[i].label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sans(size: 10, weight: FontWeight.w700, color: t.ink, height: 1.15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
