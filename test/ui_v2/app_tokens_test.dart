import 'package:business_manager/design/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final entry in {'light': AppTokens.light, 'dark': AppTokens.dark}.entries) {
    final t = entry.value;
    group('contrast (${entry.key})', () {
      test('ink on page and surface is at least 7:1', () {
        expect(_contrast(t.ink, t.page), greaterThanOrEqualTo(7));
        expect(_contrast(t.ink, t.surface), greaterThanOrEqualTo(7));
      });
      test('muted and faint text on surface meet AA (4.5:1)', () {
        expect(_contrast(t.inkMuted, t.surface), greaterThanOrEqualTo(4.5));
        expect(_contrast(t.inkFaint, t.surface), greaterThanOrEqualTo(4.5));
        expect(_contrast(t.inkMuted, t.page), greaterThanOrEqualTo(4.5));
      });
      test('brand text on surface and onBrand on brand meet AA', () {
        expect(_contrast(t.brand, t.surface), greaterThanOrEqualTo(4.5));
        expect(_contrast(t.onBrand, t.brand), greaterThanOrEqualTo(4.5));
      });
      test('every status pair meets AA', () {
        expect(_contrast(t.success, t.successBg), greaterThanOrEqualTo(4.5));
        expect(_contrast(t.warning, t.warningBg), greaterThanOrEqualTo(4.5));
        expect(_contrast(t.danger, t.dangerBg), greaterThanOrEqualTo(4.5));
        expect(_contrast(t.info, t.infoBg), greaterThanOrEqualTo(4.5));
      });
    });
  }

  testWidgets('AppTokens.of follows the theme brightness', (tester) async {
    late AppTokens seen;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Builder(builder: (c) {
        seen = AppTokens.of(c);
        return const SizedBox();
      }),
    ));
    expect(seen.brightness, Brightness.dark);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.light(),
      home: Builder(builder: (c) {
        seen = AppTokens.of(c);
        return const SizedBox();
      }),
    ));
    expect(seen.brightness, Brightness.light);
  });
}
