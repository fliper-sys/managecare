import 'package:business_manager/shared_features/session/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _retail = BusinessRef(id: 'b1', name: 'Mama Ngozi Stores', type: 'retail');
const _salon = BusinessRef(id: 'b2', name: 'Glow Salon', type: 'salon');
final _expired = BusinessRef(
    id: 'b3', name: 'Old Pharmacy', type: 'retail', planEnd: DateTime(2020));
const _blank = BusinessRef(id: 'b4', name: 'No Type', type: '');
final _now = DateTime(2026, 11, 14);

BusinessSessionState _s({
  List<BusinessRef> list = const [_retail, _salon],
  String? current = 'b1',
  bool loading = false,
  bool switching = false,
  String? pending,
  bool cache = false,
  String? error,
}) =>
    BusinessSessionState.derive(
      businesses: list,
      currentId: current,
      isLoading: loading,
      isSwitching: switching,
      pendingId: pending,
      usingCache: cache,
      errorMessage: error,
    );

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('phase', () {
    test('ready, switching, loading, error, empty', () {
      expect(_s().phase, SessionPhase.ready);
      expect(_s(switching: true, pending: 'b2').phase, SessionPhase.switching);
      expect(_s(list: [], current: null, loading: true).phase, SessionPhase.loadingList);
      expect(_s(list: [], current: null, error: 'x').phase, SessionPhase.error);
      expect(_s(list: [], current: null).phase, SessionPhase.noBusinesses);
    });

    test('cached list with an error still shows the business', () {
      final s = _s(cache: true, error: 'offline');
      expect(s.phase, SessionPhase.ready);
      expect(s.usingCache, isTrue);
    });

    test('businesses but no selection shows loading, not blank', () {
      expect(_s(current: null).phase, SessionPhase.loadingList);
    });

    test('tenantKey is the target while switching', () {
      expect(_s().tenantKey, 'b1');
      expect(_s(switching: true, pending: 'b2').tenantKey, 'b2');
    });

    test('canSwitch needs two businesses and no switch in flight', () {
      expect(_s().canSwitch, isTrue);
      expect(_s(list: [_retail]).canSwitch, isFalse);
      expect(_s(switching: true, pending: 'b2').canSwitch, isFalse);
    });
  });

  group('resolveProfile', () {
    test('retail is v2 only when flagged', () {
      expect(resolveProfile(_retail, now: _now, buildFlag: 'retail').state, ProfileState.v2);
      expect(resolveProfile(_retail, now: _now, buildFlag: '').state, ProfileState.legacy);
    });

    test('unmigrated type stays legacy even with UI_V2=all', () {
      expect(resolveProfile(_salon, now: _now, buildFlag: 'all').state, ProfileState.legacy);
    });

    test('expired plan wins over v2 and keeps the accent', () {
      final r = resolveProfile(_expired, now: _now, buildFlag: 'all');
      expect(r.state, ProfileState.planExpired);
      expect(r.profile, isNotNull);
    });

    test('inactive plan counts as expired', () {
      const b = BusinessRef(id: 'x', name: 'X', type: 'retail', planActive: false);
      expect(resolveProfile(b, now: _now).state, ProfileState.planExpired);
    });

    test('empty type is unknown', () {
      expect(resolveProfile(_blank, now: _now, buildFlag: 'all').state, ProfileState.unknownType);
    });
  });

  group('TenantScope', () {
    testWidgets('state resets when the tenant changes', (tester) async {
      Widget build(String id) => _app(TenantScope(tenantId: id, child: const _Counter()));
      await tester.pumpWidget(build('b1'));
      await tester.tap(find.byType(_Counter));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);

      await tester.pumpWidget(build('b2'));
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('state survives a rebuild for the same tenant', (tester) async {
      Widget build() => _app(const TenantScope(tenantId: 'b1', child: _Counter()));
      await tester.pumpWidget(build());
      await tester.tap(find.byType(_Counter));
      await tester.pump();
      await tester.pumpWidget(build());
      expect(find.text('1'), findsOneWidget);
    });
  });

  group('SessionGate', () {
    Widget gate(BusinessSessionState s) => _app(SessionGate(
          state: s,
          now: _now,
          v2Builder: (_, b, __) => Text('v2:${b.id}'),
          legacyBuilder: (_, b) => Text('legacy:${b.id}'),
          expiredBuilder: (_, b, __) => Text('expired:${b.id}'),
          unknownTypeBuilder: (_, b) => Text('unknown:${b.id}'),
          onRetry: () {},
          onAddBusiness: () {},
        ));

    testWidgets('routes by profile state', (tester) async {
      // The build flag is empty in tests, so retail resolves to legacy.
      await tester.pumpWidget(gate(_s()));
      expect(find.text('legacy:b1'), findsOneWidget);

      await tester.pumpWidget(gate(_s(list: [_expired], current: 'b3')));
      expect(find.text('expired:b3'), findsOneWidget);

      await tester.pumpWidget(gate(_s(list: [_blank], current: 'b4')));
      expect(find.text('unknown:b4'), findsOneWidget);
    });

    testWidgets('v2 route when the override set enables retail', (tester) async {
      UiV2.overrides.value = {'retail'};
      addTearDown(() => UiV2.overrides.value = <String>{});
      await tester.pumpWidget(gate(_s()));
      expect(find.text('v2:b1'), findsOneWidget);
    });

    testWidgets('switching shows the target name in a skeleton', (tester) async {
      await tester.pumpWidget(gate(_s(switching: true, pending: 'b2')));
      expect(find.text('Glow Salon'), findsOneWidget);
      expect(find.textContaining('legacy'), findsNothing);
    });

    testWidgets('error and empty offer an action', (tester) async {
      await tester.pumpWidget(gate(_s(list: [], current: null, error: 'boom')));
      expect(find.text('Try again'), findsOneWidget);
      await tester.pumpWidget(gate(_s(list: [], current: null)));
      expect(find.text('Add a business'), findsOneWidget);
    });
  });

  group('BusinessSwitcherView', () {
    testWidgets('lists businesses, marks current and expired', (tester) async {
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: BusinessSwitcherView(
          state: _s(list: [_retail, _salon, _expired]),
          now: _now,
          onSelect: (_) {},
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Mama Ngozi Stores'), findsOneWidget);
      expect(find.text('Current'), findsOneWidget);
      expect(find.text('Plan expired'), findsOneWidget);
    });

    testWidgets('tapping another business calls onSelect, current is inert', (tester) async {
      BusinessRef? picked;
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: BusinessSwitcherView(state: _s(), now: _now, onSelect: (b) => picked = b),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mama Ngozi Stores'));
      await tester.pump();
      expect(picked, isNull);
      await tester.tap(find.text('Glow Salon'));
      await tester.pump();
      expect(picked?.id, 'b2');
    });

    testWidgets('rows are locked while a switch is in flight', (tester) async {
      BusinessRef? picked;
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: BusinessSwitcherView(
          state: _s(switching: true, pending: 'b2'),
          now: _now,
          onSelect: (b) => picked = b,
        ),
      )));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Mama Ngozi Stores'));
      expect(picked, isNull);
    });

    testWidgets('offline banner shows with cached data', (tester) async {
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: BusinessSwitcherView(state: _s(cache: true), now: _now, onSelect: (_) {}),
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('Offline'), findsOneWidget);
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => setState(() => n++),
        child: Text('$n'),
      );
}
