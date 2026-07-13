import 'package:business_manager/core/utils/amount_formatter.dart';
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

    test('parses formatted opening cash values with commas', () {
      expect(parseAmountInput('1,200.50'), 1200.50);
      expect(parseAmountInput('0'), 0.0);
    });
  });
}
