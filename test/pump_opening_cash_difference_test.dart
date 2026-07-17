import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/presentation/industry_specific/gas/utils/pump_opening_cash_utils.dart';

void main() {
  group('pump opening cash difference', () {
    test('calculates previous close minus current opening cash', () {
      expect(
        calculateOpeningCashDifference(previousShiftClosingCash: 1200, shiftOpeningCash: 950),
        250,
      );
    });

    test('returns null when required values are missing', () {
      expect(
        calculateOpeningCashDifference(previousShiftClosingCash: null, shiftOpeningCash: 950),
        isNull,
      );
    });
  });
}
