import 'package:flutter/material.dart';

import '../motion.dart';

/// Counts up to [value] (and from the old value when it changes), as the demo's
/// hero figure does. Shows the final value at once when motion is reduced.
class OdometerText extends StatelessWidget {
  const OdometerText({
    super.key,
    required this.value,
    required this.format,
    required this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  final double value;
  final String Function(double) format;
  final TextStyle style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: Motion.scaled(context, duration),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        format(v),
        maxLines: 1,
        style: style,
        semanticsLabel: format(value),
      ),
    );
  }
}
