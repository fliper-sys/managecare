import 'package:business_manager/presentation/industry_specific/gas/utils/pump_daily_upload_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pump daily upload reconciliation', () {
    test('accepts values within 0.25% relative tolerance', () {
      expect(
        validateShiftDifferenceAgainstCashAndPos(
          shiftDifference: 1000,
          cash: 999,
          pos: 0.5,
          tolerancePercent: 0.25,
        ),
        isTrue,
      );
    });

    test('rejects values outside 0.25% relative tolerance', () {
      expect(
        validateShiftDifferenceAgainstCashAndPos(
          shiftDifference: 1000,
          cash: 998,
          pos: 0.5,
          tolerancePercent: 0.25,
        ),
        isFalse,
      );
    });
  });
}
