import 'package:business_manager/shared_features/plans/plan_journey_view.dart';
import 'package:business_manager/shared_features/plans/plan_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PlanChoice _c(String tier, String label, int days, double price) => PlanChoice(
    planId: '${tier}_$label', tierId: tier, durationLabel: label, days: days, price: price, features: const ['700 products']);

final _plans = [
  _c('tier2', '12 months', 365, 100000),
  _c('tier1', '3 months', 90, 30000),
  _c('tier1', '12 months', 365, 99000),
  _c('tier2', '3 months', 90, 40000),
];

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  test('groups by tier, shortest length first', () {
    final g = groupTiers(_plans);
    expect(g.map((e) => e.tierId), ['tier1', 'tier2']);
    expect(g.first.name, 'Tier 1');
    expect(g.first.choices.map((c) => c.days), [90, 365]);
  });

  test('saving compares per-month price of longest with shortest', () {
    final g = groupTiers(_plans).first; // 30000/3mo vs 99000/12mo
    expect(g.bestSavingPercent, 19);
    expect(TierGroup(tierId: 't', name: 't', choices: [_plans.first]).bestSavingPercent, 0);
  });

  testWidgets('choose, confirm, pay reports the selected plan', (tester) async {
    PlanChoice? paid;
    await tester.pumpWidget(_app(PlanJourneyView(
      tiers: groupTiers(_plans),
      accent: Colors.teal,
      currentTierId: 'tier1',
      recommendedTierId: 'tier2',
      onConfirm: (c) => paid = c,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);

    await tester.tap(find.text('12 months').last); // pick tier 2 yearly
    await tester.pump();
    await tester.tap(find.text('Choose Tier 2'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm plan'), findsOneWidget);
    await tester.tap(find.textContaining('Pay'));
    await tester.pumpAndSettle();
    expect(paid?.planId, 'tier2_12 months');
  });

  testWidgets('expired plan says Renew on the current tier', (tester) async {
    await tester.pumpWidget(_app(PlanJourneyView(
      tiers: groupTiers(_plans),
      accent: Colors.teal,
      currentTierId: 'tier1',
      expired: true,
      onConfirm: (_) {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('Renew'), findsOneWidget);
  });

  testWidgets('empty list shows a message', (tester) async {
    await tester.pumpWidget(_app(PlanJourneyView(tiers: const [], accent: Colors.teal, onConfirm: (_) {})));
    expect(find.textContaining('No plans'), findsOneWidget);
  });
}
