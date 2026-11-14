import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../app_type.dart';
import 'manage_card.dart';

@immutable
class PlanSummary {
  const PlanSummary({
    required this.familyLabel,
    required this.tierName,
    required this.daysLeft,
    required this.periodDays,
    required this.usageLabel,
    required this.used,
    required this.limit,
  });

  final String familyLabel;
  final String tierName;
  final int daysLeft;
  final int periodDays;
  final String usageLabel;
  final int used;
  final int limit;

  double get usedShare => limit <= 0 ? 0 : used / limit;
  bool get nearLimit => usedShare >= 0.8;
}

/// The plan card from the demo's home: a ring of days left, the plan name and a
/// usage line that turns amber from 80%.
class PlanSummaryCard extends StatelessWidget {
  const PlanSummaryCard({super.key, required this.plan, required this.accent, required this.onTap});

  final PlanSummary plan;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final share = plan.periodDays <= 0 ? 0.0 : (plan.daysLeft / plan.periodDays).clamp(0.0, 1.0);
    return ManageCard(
      onTap: onTap,
      semanticLabel: 'Your plan, ${plan.familyLabel} ${plan.tierName}, ${plan.daysLeft} days left',
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CustomPaint(
              painter: _RingPainter(progress: share, track: t.line, color: accent),
              child: Center(
                child: Text('${plan.daysLeft}d', style: AppType.mono(size: 11, weight: FontWeight.w800, color: t.ink)),
              ),
            ),
          ),
          const SizedBox(width: AppTokens.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR PLAN', style: AppType.micro(color: t.inkFaint)),
                Text('${plan.familyLabel} · ${plan.tierName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sans(size: 14, weight: FontWeight.w800, color: t.ink)),
                Text(
                  '${plan.usageLabel} ${plan.used} of ${plan.limit}${plan.nearLimit ? ' · upgrade soon' : ''}',
                  style: AppType.sans(
                    size: 11,
                    weight: plan.nearLimit ? FontWeight.w800 : FontWeight.w500,
                    color: plan.nearLimit ? t.warning : t.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward, size: 16, color: t.inkFaint),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.track, required this.color});

  final double progress;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const w = 5.0;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - w / 2);
    canvas.drawArc(rect, 0, math.pi * 2, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = track);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.color != color;
}
