import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../motion.dart';

/// Tilts [child] toward the pointer and moves a soft light sheen across it (the
/// demo's holographic hero card). Does nothing when motion is reduced.
class HoloTilt extends StatefulWidget {
  const HoloTilt({
    super.key,
    required this.child,
    this.borderRadius = AppTokens.rHero,
    this.maxTiltDegrees = 9,
  });

  final Widget child;
  final double borderRadius;
  final double maxTiltDegrees;

  @override
  State<HoloTilt> createState() => _HoloTiltState();
}

class _HoloTiltState extends State<HoloTilt> {
  Offset _p = const Offset(0.5, 0.5);
  bool _active = false;

  void _set(Offset local) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || Motion.reduced(context)) return;
    final s = box.size;
    setState(() {
      _active = true;
      _p = Offset((local.dx / s.width).clamp(0.0, 1.0), (local.dy / s.height).clamp(0.0, 1.0));
    });
  }

  void _reset() {
    if (!_active) return;
    setState(() {
      _active = false;
      _p = const Offset(0.5, 0.5);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final k = math.pi / 180 * widget.maxTiltDegrees;
    final radius = BorderRadius.circular(widget.borderRadius);
    final duration = Motion.scaled(context, const Duration(milliseconds: 160));
    return MouseRegion(
      onHover: (e) => _set(e.localPosition),
      onExit: (_) => _reset(),
      child: Listener(
        onPointerDown: (e) => _set(e.localPosition),
        onPointerMove: (e) => _set(e.localPosition),
        onPointerUp: (_) => _reset(),
        onPointerCancel: (_) => _reset(),
        child: AnimatedContainer(
          duration: duration,
          curve: Motion.smooth,
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.00125)
            ..rotateY((_p.dx - 0.5) * 2 * k)
            ..rotateX((0.5 - _p.dy) * 2 * k),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                widget.child,
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: duration,
                      opacity: _active ? 1 : 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(_p.dx * 2 - 1, _p.dy * 2 - 1),
                            radius: 0.9,
                            colors: [t.onAccent.withOpacity(0.26), t.onAccent.withOpacity(0)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
