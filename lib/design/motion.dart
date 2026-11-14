import 'package:flutter/widgets.dart';

/// Motion tokens for UI v2: short springs and a reduce-motion switch.
class Motion {
  const Motion._();

  static const Curve smooth = Cubic(0.22, 1, 0.36, 1);
  static const Curve snappy = Cubic(0.2, 0.85, 0.25, 1);
  static const Curve bounce = Cubic(0.32, 1.56, 0.64, 1);

  static const Duration press = Duration(milliseconds: 280);
  static const Duration enter = Duration(milliseconds: 480);
  static const Duration sheet = Duration(milliseconds: 420);
  static const Duration pulse = Duration(milliseconds: 1100);

  /// True when the device asks for reduced motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// [d], or zero when the device asks for reduced motion.
  static Duration scaled(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}
