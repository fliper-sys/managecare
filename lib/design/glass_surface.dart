import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'motion.dart';

/// A frosted-glass bar or panel with the demo's specular 1 px hairline.
///
/// Backdrop blur is expensive on low-end phones. When [blur] is 0, or the
/// device asks for reduced motion, the surface falls back to a solid fill.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 28,
    this.blur = 24,
    this.padding = EdgeInsets.zero,
    this.shadow = true,
  });

  final Widget child;
  final double radius;
  final double blur;
  final EdgeInsetsGeometry padding;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final dark = t.brightness == Brightness.dark;
    final solid = blur <= 0 || Motion.reduced(context);
    final r = BorderRadius.circular(radius);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: dark ? const Color(0x80000000) : const Color(0x590F172A),
                  blurRadius: 30,
                  spreadRadius: -10,
                  offset: const Offset(0, 10),
                ),
              ]
            : const [],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: CustomPaint(
          foregroundPainter: _HairlinePainter(radius: radius, dark: dark),
          child: Stack(
            children: [
              if (!solid)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: const SizedBox.expand(),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(color: solid ? t.surface : t.glass),
                child: Padding(padding: padding, child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HairlinePainter extends CustomPainter {
  _HairlinePainter({required this.radius, required this.dark});

  final double radius;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect.deflate(0.5), Radius.circular(radius));
    final colors = dark
        ? const [Color(0x38FFFFFF), Color(0x08FFFFFF), Color(0x2960A5FA)]
        : const [Color(0xADFFFFFF), Color(0x14FFFFFF), Color(0x2E0F172A)];
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_HairlinePainter old) => old.radius != radius || old.dark != dark;
}
