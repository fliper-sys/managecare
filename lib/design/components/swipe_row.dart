import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../app_type.dart';
import '../motion.dart';

/// A list row that can be swiped left to run an action: the action runs once
/// the row passes [threshold] and the drag is clamped at [maxDrag], as in the
/// demo. Always give the row a visible button for the same action so it is
/// usable without swiping.
class SwipeRow extends StatefulWidget {
  const SwipeRow({
    super.key,
    required this.child,
    required this.actionLabel,
    required this.onAction,
    required this.accent,
    this.threshold = 56,
    this.maxDrag = 96,
  });

  final Widget child;
  final String actionLabel;
  final VoidCallback onAction;
  final Color accent;
  final double threshold;
  final double maxDrag;

  @override
  State<SwipeRow> createState() => _SwipeRowState();
}

class _SwipeRowState extends State<SwipeRow> {
  double _dx = 0;
  bool _dragging = false;
  bool _gone = false;

  void _end(double width) {
    if (_gone) return;
    final commit = _dx <= -widget.threshold;
    setState(() {
      _dragging = false;
      _dx = commit ? -width : 0;
      _gone = commit;
    });
    if (commit) {
      Future<void>.delayed(Motion.scaled(context, Motion.press), () {
        if (mounted) widget.onAction();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return LayoutBuilder(builder: (context, box) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.rRow),
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: widget.accent,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Text(widget.actionLabel,
                        style: AppType.sans(size: 12, weight: FontWeight.w800, color: t.onAccent)),
                  ),
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (_) => setState(() => _dragging = true),
              onHorizontalDragUpdate: (d) {
                if (_gone) return;
                setState(() => _dx = (_dx + d.delta.dx).clamp(-widget.maxDrag, 0.0));
              },
              onHorizontalDragEnd: (_) => _end(box.maxWidth),
              onHorizontalDragCancel: () => _end(box.maxWidth),
              child: AnimatedContainer(
                duration: _dragging ? Duration.zero : Motion.scaled(context, Motion.press),
                curve: Motion.smooth,
                transform: Matrix4.translationValues(_dx, 0, 0),
                child: widget.child,
              ),
            ),
          ],
        ),
      );
    });
  }
}
