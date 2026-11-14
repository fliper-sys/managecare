import 'package:business_manager/business_profiles/business_profiles.dart';
import 'package:business_manager/design/components/components.dart';
import 'package:business_manager/design/format.dart';
import 'package:business_manager/features/retail/home/retail_home_data.dart';
import 'package:business_manager/features/retail/home/retail_home_view.dart';
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

const _plan = PlanSummary(
  familyLabel: 'Standard',
  tierName: 'Tier 2',
  daysLeft: 41,
  periodDays: 90,
  usageLabel: 'Products',
  used: 520,
  limit: 700,
);

const _data = RetailHomeData(
  businessName: 'Mama Ngozi Stores',
  greetingName: 'Ngozi',
  salesToday: 1284500,
  deltaPercent: 12.4,
  salesCount: 64,
  spark: [4, 6, 5, 8, 7, 10, 9, 12, 11, 14],
  plan: _plan,
  lowStock: [
    AttentionRow(id: 'a', title: 'Peak Milk 400g', subtitle: '4 left'),
    AttentionRow(id: 'b', title: 'Indomie carton', subtitle: '2 left'),
  ],
  pending: [CountRow(label: 'Unpaid invoices', count: 3), CountRow(label: 'Transfers to receive', count: 1)],
);

void main() {
  group('formatNaira', () {
    test('groups thousands', () {
      expect(formatNaira(0), '₦0');
      expect(formatNaira(950), '₦950');
      expect(formatNaira(1234567), '₦1,234,567');
      expect(formatNaira(1000), '₦1,000');
    });
    test('rounds and handles negatives', () {
      expect(formatNaira(1999.6), '₦2,000');
      expect(formatNaira(-12500), '-₦12,500');
    });
  });

  testWidgets('OdometerText counts up to the value', (tester) async {
    await tester.pumpWidget(_app(OdometerText(value: 5000, format: formatNaira, style: const TextStyle())));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('₦5,000'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('₦5,000'), findsOneWidget);
  });

  testWidgets('OdometerText shows the value at once when motion is reduced', (tester) async {
    await tester.pumpWidget(_app(
      OdometerText(value: 5000, format: formatNaira, style: const TextStyle()),
      reduceMotion: true,
    ));
    await tester.pump();
    expect(find.text('₦5,000'), findsOneWidget);
  });

  testWidgets('SparklineDraw paints, and tolerates too little data', (tester) async {
    await tester.pumpWidget(_app(Column(children: const [
      SparklineDraw(data: [1, 3, 2, 5], color: Colors.blue),
      SparklineDraw(data: [1], color: Colors.blue),
      SparklineDraw(data: [2, 2, 2], color: Colors.blue),
    ])));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  group('SwipeRow', () {
    Future<void> pumpRow(WidgetTester tester, void Function() onAction) async {
      await tester.pumpWidget(_app(SwipeRow(
        accent: Colors.blue,
        actionLabel: 'Reorder',
        onAction: onAction,
        child: const SizedBox(height: 60, width: double.infinity, child: Text('Row')),
      )));
    }

    testWidgets('runs the action past the threshold', (tester) async {
      var done = 0;
      await pumpRow(tester, () => done++);
      await tester.drag(find.text('Row'), const Offset(-110, 0));
      await tester.pump(const Duration(milliseconds: 500));
      expect(done, 1);
    });

    testWidgets('springs back when the swipe is short', (tester) async {
      var done = 0;
      await pumpRow(tester, () => done++);
      await tester.drag(find.text('Row'), const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 500));
      expect(done, 0);
    });

    testWidgets('does not move right', (tester) async {
      var done = 0;
      await pumpRow(tester, () => done++);
      await tester.drag(find.text('Row'), const Offset(120, 0));
      await tester.pump(const Duration(milliseconds: 500));
      expect(done, 0);
    });
  });

  testWidgets('HeroKpiCard shows its figure, delta and footer', (tester) async {
    await tester.pumpWidget(_app(Padding(
      padding: const EdgeInsets.all(16),
      child: HeroKpiCard(
        accent: const Color(0xFF2563EB),
        label: 'Today’s sales',
        amount: 1284500,
        format: formatNaira,
        deltaLabel: '+12.4% vs yesterday',
        subline: '64 sales',
        spark: const [1, 3, 2, 5],
        footerLeft: 'Standard · Tier 2',
        footerRight: '41 days left',
      ),
    )));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('₦1,284,500'), findsOneWidget);
    expect(find.text('+12.4% vs yesterday'), findsOneWidget);
    expect(find.text('41 days left'), findsOneWidget);
  });

  testWidgets('PlanSummaryCard turns to a warning from 80% usage', (tester) async {
    await tester.pumpWidget(_app(Padding(
      padding: const EdgeInsets.all(16),
      child: PlanSummaryCard(
        accent: const Color(0xFF2563EB),
        onTap: () {},
        plan: const PlanSummary(
          familyLabel: 'Standard',
          tierName: 'Tier 1',
          daysLeft: 5,
          periodDays: 30,
          usageLabel: 'Products',
          used: 90,
          limit: 100,
        ),
      ),
    )));
    expect(find.textContaining('upgrade soon'), findsOneWidget);
    expect(_plan.nearLimit, isFalse);
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('RetailHomeView shows every section on a 360 px phone ($mode)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      QuickAction? tapped;
      String? done;
      await tester.pumpWidget(_app(
        RetailHomeView(
          profile: retailProfile,
          data: _data,
          onQuickAction: (a) => tapped = a,
          onOpenPlan: () {},
          onSearch: () {},
          onNotifications: () {},
          onRowDone: (id) => done = id,
        ),
        dark: dark,
      ));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      expect(find.text('Retail Store'), findsOneWidget);
      expect(find.text('+12.4% vs yesterday'), findsOneWidget);
      expect(find.text('₦1,284,500'), findsOneWidget);
      expect(find.text('Quick sale'), findsOneWidget);
      expect(find.text('Peak Milk 400g'), findsOneWidget);
      expect(find.text('Unpaid invoices'), findsOneWidget);

      await tester.tap(find.text('Quick sale'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tapped?.target, QuickActionTarget.newSale);

      await tester.tap(find.widgetWithText(TactilePressable, 'Reorder').first);
      await tester.pump(const Duration(milliseconds: 400));
      expect(done, 'a');
    });
  }

  testWidgets('RetailHomeView shows a decline in sales with a minus sign', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const down = RetailHomeData(
      businessName: 'x',
      greetingName: 'x',
      salesToday: 100,
      deltaPercent: -3.2,
      salesCount: 1,
      spark: [3, 2, 1],
      plan: _plan,
      lowStock: [],
      pending: [],
    );
    await tester.pumpWidget(_app(RetailHomeView(
      profile: retailProfile,
      data: down,
      onQuickAction: (_) {},
      onOpenPlan: () {},
      onSearch: () {},
      onNotifications: () {},
      onRowDone: (_) {},
    )));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('−3.2% vs yesterday'), findsOneWidget);
    expect(find.text('1 sale'), findsOneWidget);
    expect(find.text('Low stock'), findsNothing);
  });
}
