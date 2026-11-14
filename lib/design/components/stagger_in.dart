import 'package:flutter/material.dart';

import '../motion.dart';

/// Fades, lifts and settles [child] into place, delayed by [index] steps of
/// [step] (42 ms in the demo). Shows immediately when motion is reduced.
class StaggerIn extends StatefulWidget {
  const StaggerIn({
    super.key,
    required this.index,
    required this.child,
    this.step = const Duration(milliseconds: 42),
  });

  final int index;
  final Duration step;
  final Widget child;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _t;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final delay = widget.step * widget.index;
    final total = Motion.enter + delay;
    _c = AnimationController(vsync: this, duration: total);
    _t = CurvedAnimation(
      parent: _c,
      curve: Interval(
        delay.inMilliseconds / total.inMilliseconds,
        1,
        curve: Motion.smooth,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _t,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(_t),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.985, end: 1).animate(_t),
          child: widget.child,
        ),
      ),
    );
  }
}
