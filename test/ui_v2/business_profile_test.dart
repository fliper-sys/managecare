import 'package:business_manager/business_profiles/business_profiles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retail profile matches the blueprint', () {
    final p = BusinessProfiles.forType('retail')!;
    expect(p.id, 'retail');
    expect(p.template, ScreenTemplate.catalogueCart);
    expect(p.planFamily, PlanFamily.standard);
    expect(p.wave, 1);
    expect(p.quickActions.length, 4);
    expect(p.workFilters.length, 3);
    expect(p.can(Capability.wholesalePricing), isTrue);
    expect(p.can(Capability.expiryTracking), isFalse);
  });

  test('quick action ids are unique', () {
    final ids = retailProfile.quickActions.map((a) => a.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('lookup ignores case and spaces, and unknown types return null', () {
    expect(BusinessProfiles.forType('  RETAIL '), isNotNull);
    expect(BusinessProfiles.forType('pharmacy'), isNull);
    expect(BusinessProfiles.forType(''), isNull);
  });

  test('registry holds only profiles keyed by their own id', () {
    for (final p in BusinessProfiles.all) {
      expect(BusinessProfiles.forType(p.id), same(p));
    }
  });
}
