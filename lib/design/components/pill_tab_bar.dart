import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../app_type.dart';
import '../glass_surface.dart';
import '../motion.dart';
import 'tactile_pressable.dart';

@immutable
class PillTabItem {
  const PillTabItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// The demo's tab bar: a frosted bar, a pill that slides under the selected
/// tab, and a raised centre action. [items] are the tabs without the centre
/// action; the action sits after the first [centerAfter] items.
class PillTabBar extends StatelessWidget {
  const PillTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.accent,
    required this.onCenterTap,
    this.centerLabel = 'New',
    this.centerIcon = Icons.add,
    this.centerAfter = 2,
  });

  final List<PillTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color accent;
  final VoidCallback onCenterTap;
  final String centerLabel;
  final IconData centerIcon;
  final int centerAfter;

  static const double _pad = 6;
  static const double _cell = 52;
  static const double _button = 56;

  int _cellOf(int item) => item < centerAfter ? item : item + 1;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final cells = items.length + 1;
    return SizedBox(
      height: _cell + _pad * 2,
      child: LayoutBuilder(builder: (context, box) {
        final cellW = (box.maxWidth - _pad * 2) / cells;
        final pillLeft = _pad + _cellOf(selectedIndex) * cellW;
        final centerLeft = _pad + centerAfter * cellW + (cellW - _button) / 2;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GlassSurface(
                radius: 28,
                padding: const EdgeInsets.all(_pad),
                child: const SizedBox.expand(),
              ),
            ),
            AnimatedPositioned(
              duration: Motion.scaled(context, Motion.sheet),
              curve: Motion.bounce,
              left: pillLeft,
              top: _pad,
              width: cellW,
              height: _cell,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTokens.tint(accent, amount: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            for (var i = 0; i < items.length; i++)
              Positioned(
                left: _pad + _cellOf(i) * cellW,
                top: _pad,
                width: cellW,
                height: _cell,
                child: _Tab(
                  item: items[i],
                  selected: i == selectedIndex,
                  color: i == selectedIndex ? accent : t.inkMuted,
                  onTap: () => onSelected(i),
                ),
              ),
            Positioned(
              left: centerLeft,
              top: _pad - 24,
              width: _button,
              height: _button,
              child: TactilePressable(
                onTap: onCenterTap,
                semanticLabel: centerLabel,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent, AppTokens.deepen(accent, 0.4)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.55),
                        blurRadius: 24,
                        spreadRadius: -6,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Icon(centerIcon, color: t.onAccent, size: 26),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.item,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final PillTabItem item;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: TactilePressable(
        onTap: onTap,
        semanticLabel: item.label,
        pressedScale: 0.92,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 18, color: color),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.micro(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
