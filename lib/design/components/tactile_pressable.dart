import 'package:flutter/material.dart';

import '../motion.dart';

/// Wraps [child] with a short spring press (scale to 0.945) and button
/// semantics. Honours the device's reduce-motion setting.
class TactilePressable extends StatefulWidget {
  const TactilePressable({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.pressedScale = 0.945,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double pressedScale;

  @override
  State<TactilePressable> createState() => _TactilePressableState();
}

class _TactilePressableState extends State<TactilePressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? widget.pressedScale : 1,
          duration: Motion.scaled(context, Motion.press),
          curve: Motion.bounce,
          child: widget.child,
        ),
      ),
    );
  }
}
