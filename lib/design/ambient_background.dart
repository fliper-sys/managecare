import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// The page ground from the flagship demo: the page colour, a soft glow of the
/// business accent at the top, and a very fine grain over everything.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    required this.child,
    this.accent,
    this.grain = true,
  });

  final Widget child;
  final Color? accent;
  final bool grain;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final dark = t.brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: t.page),
        if (accent != null)
          Positioned(
            top: -90,
            left: 0,
            right: 0,
            height: 280,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 0.95,
                    colors: [
                      accent!.withOpacity(dark ? 0.22 : 0.14),
                      accent!.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        child,
        if (grain) const Positioned.fill(child: GrainOverlay()),
      ],
    );
  }
}

/// A fixed, very faint noise layer (the demo's micro-grain). It paints once and
/// is cached by a RepaintBoundary.
class GrainOverlay extends StatelessWidget {
  const GrainOverlay({super.key, this.opacity = 0.028});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _GrainPainter(t.ink.withOpacity(opacity)),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rnd = math.Random(7);
    final n = (size.width * size.height / 90).clamp(0, 9000).toInt();
    final pts = List<Offset>.generate(
      n,
      (_) => Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
    );
    canvas.drawPoints(
      PointMode.points,
      pts,
      Paint()
        ..color = color
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.color != color;
}
