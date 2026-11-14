import 'package:flutter/material.dart';

import '../app_tokens.dart';

enum StatusTone { neutral, success, warning, danger, info }

/// A small status pill. The label always carries the meaning; colour only
/// reinforces it.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.tone = StatusTone.neutral});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    late final Color fg;
    late final Color bg;
    switch (tone) {
      case StatusTone.success:
        fg = t.success;
        bg = t.successBg;
        break;
      case StatusTone.warning:
        fg = t.warning;
        bg = t.warningBg;
        break;
      case StatusTone.danger:
        fg = t.danger;
        bg = t.dangerBg;
        break;
      case StatusTone.info:
        fg = t.info;
        bg = t.infoBg;
        break;
      case StatusTone.neutral:
        fg = t.inkMuted;
        bg = t.page;
        break;
    }
    return DecoratedBox(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800, height: 1.2),
        ),
      ),
    );
  }
}
