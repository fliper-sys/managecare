import 'package:flutter/material.dart';

import 'app_type.dart';
import 'motion.dart';

enum IslandTone { ok, info, warn }

/// The demo's Dynamic Island status pill. It grows from a small pill under the
/// system status bar, shows a short confirmation, then shrinks away.
///
///   StatusIsland.show(context, title: 'Sale recorded', subtitle: '₦12,500', badge: 'SAVED');
class StatusIsland {
  const StatusIsland._();

  static OverlayEntry? _entry;

  static void show(
    BuildContext context, {
    required String title,
    String subtitle = '',
    String badge = 'OK',
    IslandTone tone = IslandTone.ok,
    Duration hold = const Duration(milliseconds: 3300),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _entry?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _IslandView(
        title: title,
        subtitle: subtitle,
        badge: badge,
        tone: tone,
        hold: hold,
        onDone: () {
          if (identical(_entry, entry)) _entry = null;
          entry.remove();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }
}

class _IslandView extends StatefulWidget {
  const _IslandView({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.tone,
    required this.hold,
    required this.onDone,
  });

  final String title;
  final String subtitle;
  final String badge;
  final IslandTone tone;
  final Duration hold;
  final VoidCallback onDone;

  @override
  State<_IslandView> createState() => _IslandViewState();
}

class _IslandViewState extends State<_IslandView> {
  static const _small = Size(114, 30);
  static const _large = Size(248, 42);
  bool _open = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _open = true);
      Future<void>.delayed(widget.hold, () {
        if (!mounted) return;
        setState(() => _open = false);
        Future<void>.delayed(Motion.sheet, () {
          if (mounted && !_gone) {
            _gone = true;
            widget.onDone();
          }
        });
      });
    });
  }

  @override
  void dispose() {
    _gone = true;
    super.dispose();
  }

  (Color, Color, String) get _look {
    switch (widget.tone) {
      case IslandTone.info:
        return (const Color(0xFF7DD3FC), const Color(0xFFBAE6FD), 'i');
      case IslandTone.warn:
        return (const Color(0xFFFCD34D), const Color(0xFFFDE68A), '!');
      case IslandTone.ok:
        return (const Color(0xFF34D399), const Color(0xFF6EE7B7), '✓');
    }
  }

  @override
  Widget build(BuildContext context) {
    final look = _look;
    final size = _open ? _large : _small;
    final duration = Motion.scaled(context, Motion.sheet);
    return Positioned(
      top: MediaQuery.of(context).padding.top + 4,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: widget.subtitle.isEmpty ? widget.title : '${widget.title}. ${widget.subtitle}',
            child: AnimatedContainer(
              duration: duration,
              curve: Motion.bounce,
              width: size.width,
              height: size.height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF000000),
                borderRadius: BorderRadius.circular(_open ? 24 : 20),
                border: Border.all(color: const Color(0x26FFFFFF)),
              ),
              child: OverflowBox(
                minWidth: 0,
                maxWidth: _large.width,
                minHeight: 0,
                maxHeight: _large.height,
                child: AnimatedOpacity(
                  duration: duration,
                  opacity: _open ? 1 : 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: look.$1.withOpacity(0.2),
                          ),
                          child: Text(look.$3, style: AppType.sans(size: 11, weight: FontWeight.w800, color: look.$1)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.sans(size: 11, weight: FontWeight.w800, color: const Color(0xFFFFFFFF), height: 1.1)),
                              if (widget.subtitle.isNotEmpty)
                                Text(widget.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppType.sans(size: 9, weight: FontWeight.w500, color: const Color(0xFF94A3B8), height: 1.1)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: look.$1.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(widget.badge, style: AppType.mono(size: 9, weight: FontWeight.w800, color: look.$2)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
