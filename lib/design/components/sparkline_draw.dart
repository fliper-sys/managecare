import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../motion.dart';

/// A trend line that draws itself, with a soft fill under it (the demo's
/// self-drawing sparkline).
class SparklineDraw extends StatelessWidget {
  const SparklineDraw({
    super.key,
    required this.data,
    required this.color,
    this.height = 56,
    this.strokeWidth = 2.2,
    this.duration = const Duration(milliseconds: 1200),
  });

  final List<double> data;
  final Color color;
  final double height;
  final double strokeWidth;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) return SizedBox(height: height);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: Motion.scaled(context, duration),
        curve: Curves.easeOutCubic,
        builder: (context, p, _) => CustomPaint(
          painter: _SparkPainter(data: data, color: color, progress: p, strokeWidth: strokeWidth),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.data, required this.color, required this.progress, required this.strokeWidth});

  final List<double> data;
  final Color color;
  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    var mn = data.first, mx = data.first;
    for (final v in data) {
      if (v < mn) mn = v;
      if (v > mx) mx = v;
    }
    final span = (mx - mn) == 0 ? 1.0 : (mx - mn);
    final n = data.length;
    final pts = <Offset>[
      for (var i = 0; i < n; i++)
        Offset(i * size.width / (n - 1), size.height - 4 - ((data[i] - mn) / span) * (size.height - 10)),
    ];
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.38 * progress), color.withOpacity(0)],
        ).createShader(Offset.zero & size),
    );

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final PathMetric m in line.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * progress), stroke);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.progress != progress || old.color != color || old.data != data;
}
