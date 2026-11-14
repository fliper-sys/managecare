import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../motion.dart';

/// A pulsing placeholder that holds the layout while data loads. Static when
/// the device asks for reduced motion.
class SkeletonBlock extends StatefulWidget {
  const SkeletonBlock({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppTokens.rControl,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Motion.pulse);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
      _started = false;
    } else if (!_started) {
      _c.repeat(reverse: true);
      _started = true;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Opacity(
        opacity: Motion.reduced(context) ? 0.8 : 0.55 + 0.45 * _c.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: t.line,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}
