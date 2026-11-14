import 'package:business_manager/shared_features/ui_v2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('is off by default', () {
    expect(UiV2.enabledFor('retail', buildFlag: '', overrideSet: {}), isFalse);
  });

  test('turns on for a listed, migrated business', () {
    expect(UiV2.enabledFor('retail', buildFlag: 'retail', overrideSet: {}), isTrue);
    expect(UiV2.enabledFor(' Retail ', buildFlag: 'RETAIL', overrideSet: {}), isTrue);
  });

  test('all never enables a business that is not migrated', () {
    expect(UiV2.enabledFor('retail', buildFlag: 'all', overrideSet: {}), isTrue);
    expect(UiV2.enabledFor('pharmacy', buildFlag: 'all', overrideSet: {}), isFalse);
  });

  test('a listed business without a profile stays off', () {
    expect(UiV2.enabledFor('pharmacy', buildFlag: 'pharmacy', overrideSet: {}), isFalse);
  });

  test('runtime override enables a migrated business', () {
    expect(UiV2.enabledFor('retail', buildFlag: '', overrideSet: {'retail'}), isTrue);
  });

  test('empty business type is off', () {
    expect(UiV2.enabledFor('', buildFlag: 'all', overrideSet: {}), isFalse);
  });
}
