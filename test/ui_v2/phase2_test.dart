import 'package:business_manager/design/ambient_background.dart';
import 'package:business_manager/design/app_type.dart';
import 'package:business_manager/design/components/components.dart';
import 'package:business_manager/design/glass_surface.dart';
import 'package:business_manager/design/status_island.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool dark = false, bool reduceMotion = false}) => MaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      builder: (context, w) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: w!,
      ),
      home: Scaffold(body: child),
    );

const _items = [
  PillTabItem(label: 'Home', icon: Icons.home_outlined),
  PillTabItem(label: 'Stock', icon: Icons.inventory_2_outlined),
  PillTabItem(label: 'Reports', icon: Icons.bar_chart),
  PillTabItem(label: 'Plan', icon: Icons.sell_outlined),
];

void main() {
  group('AppType', () {
    test('sans uses Plus Jakarta Sans with a matching wght variation', () {
      final s = AppType.sans(weight: FontWeight.w800);
      expect(s.fontFamily, 'PlusJakartaSans');
      expect(s.fontVariations!.single.axis, 'wght');
      expect(s.fontVariations!.single.value, 800);
    });

    test('mono uses JetBrains Mono with tabular figures', () {
      final s = AppType.mono();
      expect(s.fontFamily, 'JetBrainsMono');
      expect(s.fontFeatures, isNotEmpty);
    });
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('AmbientBackground shows its child and grain ($mode)', (tester) async {
      await tester.pumpWidget(_app(
        const AmbientBackground(accent: Color(0xFF2563EB), child: Center(child: Text('Home'))),
        dark: dark,
      ));
      expect(find.text('Home'), findsOneWidget);
      expect(find.byType(GrainOverlay), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GlassSurface shows its child ($mode)', (tester) async {
      await tester.pumpWidget(_app(const Center(child: GlassSurface(child: Text('Glass'))), dark: dark));
      expect(find.text('Glass'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  }

  testWidgets('GlassSurface falls back to a solid fill when motion is reduced', (tester) async {
    await tester.pumpWidget(_app(const Center(child: GlassSurface(child: Text('Glass'))), reduceMotion: true));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('Glass'), findsOneWidget);
  });

  testWidgets('StaggerIn fades its child in', (tester) async {
    await tester.pumpWidget(_app(const StaggerIn(index: 3, child: Text('Row'))));
    await tester.pump();
    expect(find.text('Row'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    final fade = tester.widget<FadeTransition>(find.byType(FadeTransition).first);
    expect(fade.opacity.value, closeTo(1, 0.001));
  });

  testWidgets('StaggerIn is immediately visible when motion is reduced', (tester) async {
    await tester.pumpWidget(_app(const StaggerIn(index: 5, child: Text('Row')), reduceMotion: true));
    await tester.pump();
    final fade = tester.widget<FadeTransition>(find.byType(FadeTransition).first);
    expect(fade.opacity.value, 1);
  });

  testWidgets('PillTabBar selects tabs, moves the pill and fires the centre action', (tester) async {
    var selected = 0;
    var centre = 0;
    await tester.pumpWidget(StatefulBuilder(
      builder: (context, setState) => _app(
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: PillTabBar(
              items: _items,
              selectedIndex: selected,
              accent: const Color(0xFF2563EB),
              onSelected: (i) => setState(() => selected = i),
              onCenterTap: () => centre++,
              centerLabel: 'New sale',
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    final before = tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned)).left!;

    await tester.tap(find.text('Reports'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(selected, 2);
    final after = tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned)).left!;
    expect(after, greaterThan(before));

    await tester.tap(find.bySemanticsLabel('New sale'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(centre, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('StatusIsland shows a confirmation, then goes away', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(_app(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    StatusIsland.show(ctx, title: 'Sale recorded', subtitle: '₦12,500', badge: 'SAVED');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Sale recorded'), findsOneWidget);
    expect(find.text('SAVED'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Sale recorded'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
