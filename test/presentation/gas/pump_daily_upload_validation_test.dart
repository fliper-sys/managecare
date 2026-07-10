import 'package:business_manager/presentation/industry_specific/gas/utils/pump_daily_upload_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pump daily upload reconciliation', () {
    test('accepts matching digit counts', () {
      expect(
        validateShiftDifferenceAgainstCashAndPos(
          shiftDifference: 1000,
          cash: 999,
          pos: 0.5,
        ),
        isTrue,
      );
    });

    test('rejects different digit counts', () {
      expect(
        validateShiftDifferenceAgainstCashAndPos(
          shiftDifference: 1000,
          cash: 98,
          pos: 0.5,
        ),
        isFalse,
      );
    });
  });
}
