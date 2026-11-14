import 'package:business_manager/design/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool dark = false}) => MaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('ManageCard renders its child ($mode)', (tester) async {
      await tester.pumpWidget(_app(const ManageCard(child: Text('Hello')), dark: dark));
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('StatusChip shows its label for every tone ($mode)', (tester) async {
      await tester.pumpWidget(_app(
        Column(children: [
          for (final t in StatusTone.values) StatusChip(label: t.name, tone: t),
        ]),
        dark: dark,
      ));
      for (final t in StatusTone.values) {
        expect(find.text(t.name), findsOneWidget);
      }
    });

    testWidgets('SkeletonBlock pulses without error ($mode)', (tester) async {
      await tester.pumpWidget(_app(const SkeletonBlock(width: 120, height: 20), dark: dark));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('TactilePressable calls onTap and scales while pressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(
      TactilePressable(onTap: () => taps++, child: const SizedBox(width: 80, height: 40)),
    ));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(TactilePressable)));
    await tester.pump(const Duration(milliseconds: 300));
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    expect(scale, lessThan(1));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(taps, 1);
  });

  testWidgets('TactilePressable without onTap is disabled', (tester) async {
    await tester.pumpWidget(_app(const TactilePressable(child: SizedBox(width: 80, height: 40))));
    await tester.tap(find.byType(TactilePressable));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ManageCard with onTap is pressable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(ManageCard(onTap: () => taps++, child: const Text('Tap me'))));
    await tester.tap(find.text('Tap me'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(taps, 1);
  });

  testWidgets('showManageSheet shows the title and closes from the close button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showManageSheet<void>(
                context,
                title: 'Review sale',
                builder: (_) => const Text('Sheet body'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Review sale'), findsOneWidget);
    expect(find.text('Sheet body'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Review sale'), findsNothing);
  });
}
