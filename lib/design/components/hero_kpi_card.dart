import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../app_type.dart';
import 'holo_tilt.dart';
import 'odometer_text.dart';
import 'sparkline_draw.dart';

/// The demo's hero card: accent gradient, tilt and sheen, a counting figure, a
/// self-drawing trend line and a footer.
class HeroKpiCard extends StatelessWidget {
  const HeroKpiCard({
    super.key,
    required this.accent,
    required this.label,
    required this.amount,
    required this.format,
    required this.deltaLabel,
    required this.subline,
    required this.spark,
    required this.footerLeft,
    required this.footerRight,
  });

  final Color accent;
  final String label;
  final double amount;
  final String Function(double) format;
  final String deltaLabel;
  final String subline;
  final List<double> spark;
  final String footerLeft;
  final String footerRight;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final on = t.onAccent;
    final deep = AppTokens.deepen(accent, 0.45);
    final chipBg = AppTokens.deepen(accent, 0.85).withOpacity(0.35);
    return Semantics(
      container: true,
      label: '$label ${format(amount)}. $deltaLabel. $subline',
      child: HoloTilt(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, deep],
            ),
            borderRadius: BorderRadius.circular(AppTokens.rHero),
            boxShadow: [
              BoxShadow(color: accent.withOpacity(0.5), blurRadius: 40, spreadRadius: -12, offset: const Offset(0, 20)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.sans(size: 11, weight: FontWeight.w700, color: on.withOpacity(0.88))),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(color: on.withOpacity(0.2), borderRadius: BorderRadius.circular(999)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(deltaLabel, style: AppType.sans(size: 10, weight: FontWeight.w800, color: on)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.s4),
                OdometerText(
                  value: amount,
                  format: format,
                  style: AppType.mono(size: 32, weight: FontWeight.w800, color: on, height: 1.1),
                ),
                const SizedBox(height: 2),
                Text(subline, style: AppType.sans(size: 11, color: on.withOpacity(0.88))),
                const SizedBox(height: AppTokens.s12),
                SparklineDraw(data: spark, color: on),
                const SizedBox(height: AppTokens.s8),
                Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(999)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(footerLeft, style: AppType.sans(size: 10, weight: FontWeight.w700, color: on)),
                      ),
                    ),
                    const Spacer(),
                    Text(footerRight, style: AppType.sans(size: 10, weight: FontWeight.w700, color: on.withOpacity(0.92))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
