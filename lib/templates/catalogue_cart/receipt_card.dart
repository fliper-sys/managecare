import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../design/app_type.dart';
import '../../design/format.dart';
import '../../design/motion.dart';
import 'cart_models.dart';

/// A tick that draws itself. Settles at once when motion is reduced.
class DrawnTick extends StatefulWidget {
  const DrawnTick({super.key, required this.color, this.size = 64});
  final Color color;
  final double size;

  @override
  State<DrawnTick> createState() => _DrawnTickState();
}

class _DrawnTickState extends State<DrawnTick> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 620));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Done',
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            size: Size.square(widget.size),
            painter: _TickPainter(Motion.smooth.transform(_c.value), widget.color),
          ),
        ),
      );
}

class _TickPainter extends CustomPainter {
  _TickPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.06
      ..strokeCap = StrokeCap.round;
    final rect = Offset.zero & s;
    final ringT = (t / 0.6).clamp(0.0, 1.0);
    canvas.drawArc(rect.deflate(ring.strokeWidth), -1.5708, 6.2832 * ringT, false, ring);

    final tickT = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
    if (tickT <= 0) return;
    final p1 = Offset(s.width * 0.28, s.height * 0.52);
    final p2 = Offset(s.width * 0.44, s.height * 0.68);
    final p3 = Offset(s.width * 0.73, s.height * 0.36);
    final path = Path()..moveTo(p1.dx, p1.dy);
    final first = (tickT / 0.4).clamp(0.0, 1.0);
    path.lineTo(p1.dx + (p2.dx - p1.dx) * first, p1.dy + (p2.dy - p1.dy) * first);
    if (tickT > 0.4) {
      final second = ((tickT - 0.4) / 0.6).clamp(0.0, 1.0);
      path.lineTo(p2.dx + (p3.dx - p2.dx) * second, p2.dy + (p3.dy - p2.dy) * second);
    }
    canvas.drawPath(path, ring..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.t != t || old.color != color;
}

/// Receipt with notched sides and a zigzag tear edge.
class ReceiptCard extends StatelessWidget {
  const ReceiptCard({super.key, required this.receipt, required this.title, required this.accent});
  final SaleReceipt receipt;
  final String title;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return ClipPath(
      clipper: const _PerforatedClipper(),
      child: Container(
        color: t.raised,
        padding: const EdgeInsets.fromLTRB(AppTokens.s24, AppTokens.s24, AppTokens.s24, AppTokens.s32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: DrawnTick(color: t.success)),
          const SizedBox(height: AppTokens.s12),
          Text(title, textAlign: TextAlign.center, style: AppType.sans(size: 18, weight: FontWeight.w800, color: t.ink)),
          const SizedBox(height: 2),
          Text('Ref ${receipt.reference}', textAlign: TextAlign.center, style: AppType.mono(size: 12, color: t.inkMuted)),
          const SizedBox(height: AppTokens.s16),
          for (final l in receipt.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text('${l.qty} × ${l.item.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.sans(size: 13, color: t.ink))),
                Text(formatNairaPrecise(l.total), style: AppType.mono(size: 13, color: t.ink)),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.s12),
            child: Row(children: [
              for (var i = 0; i < 28; i++) Expanded(child: Container(height: 1.5, margin: const EdgeInsets.symmetric(horizontal: 1.5), color: i.isEven ? t.line : Colors.transparent)),
            ]),
          ),
          if (receipt.tax > 0 || receipt.discount > 0) ...[
            if (receipt.tax > 0) _row(t, 'Tax', formatNairaPrecise(receipt.tax)),
            if (receipt.discount > 0) _row(t, 'Discount', '-${formatNairaPrecise(receipt.discount)}'),
            const SizedBox(height: 6),
          ],
          Row(children: [
            Expanded(child: Text(_paidBy(receipt), style: AppType.sans(size: 13, color: t.inkMuted))),
            Text(formatNairaPrecise(receipt.total), style: AppType.mono(size: 20, weight: FontWeight.w700, color: t.ink)),
          ]),
        ]),
      ),
    );
  }
}

Widget _row(AppTokens t, String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(child: Text(k, style: AppType.sans(size: 12, color: t.inkMuted))),
        Text(v, style: AppType.mono(size: 12, color: t.inkMuted)),
      ]),
    );

String _paidBy(SaleReceipt r) {
  if (r.method != null) return 'Paid by ${r.method!.label}';
  if (r.splits.isEmpty) return 'Paid';
  return 'Paid: ${r.splits.map((s) => '${s.method.label} ${formatNairaPrecise(s.amount)}').join(', ')}';
}

class _PerforatedClipper extends CustomClipper<Path> {
  const _PerforatedClipper();
  static const double _tooth = 10;
  static const double _notch = 9;

  @override
  Path getClip(Size s) {
    final p = Path()..moveTo(0, 0)..lineTo(s.width, 0);
    // Right side down to the notch, with one half-circle notch.
    final notchY = s.height * 0.62;
    p.lineTo(s.width, notchY - _notch);
    p.arcToPoint(Offset(s.width, notchY + _notch), radius: const Radius.circular(_notch), clockwise: false);
    p.lineTo(s.width, s.height - _tooth);
    // Zigzag tear edge along the bottom, right to left.
    final n = (s.width / (_tooth * 2)).floor().clamp(1, 1000);
    final step = s.width / n;
    for (var i = 0; i < n; i++) {
      final x = s.width - i * step;
      p.lineTo(x - step / 2, s.height);
      p.lineTo(x - step, s.height - _tooth);
    }
    p.lineTo(0, notchY + _notch);
    p.arcToPoint(Offset(0, notchY - _notch), radius: const Radius.circular(_notch), clockwise: false);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(_PerforatedClipper old) => false;
}
