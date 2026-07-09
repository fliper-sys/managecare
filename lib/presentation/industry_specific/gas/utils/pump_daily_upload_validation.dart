class PumpDailyUploadValidation {
  static bool matchesShiftDifferenceAndCashPos({
    required double shiftDifference,
    required double cash,
    required double pos,
    double tolerancePercent = 0.25,
  }) {
    final totalPaid = cash + pos;
    final difference = (shiftDifference - totalPaid).abs();
    final maxReference = shiftDifference.abs().clamp(0.0, double.infinity).compareTo(totalPaid.abs()) >= 0
        ? shiftDifference.abs()
        : totalPaid.abs();

    if (maxReference == 0) {
      return true;
    }

    final allowedDifference = maxReference * (tolerancePercent / 100.0);
    return difference <= allowedDifference;
  }
}

bool validateShiftDifferenceAgainstCashAndPos({
  required double shiftDifference,
  required double cash,
  required double pos,
  double tolerancePercent = 0.25,
}) {
  return PumpDailyUploadValidation.matchesShiftDifferenceAndCashPos(
    shiftDifference: shiftDifference,
    cash: cash,
    pos: pos,
    tolerancePercent: tolerancePercent,
  );
}
