double? calculateOpeningCashDifference({
  required double? previousShiftClosingCash,
  required Object? shiftOpeningCash,
}) {
  if (previousShiftClosingCash == null || shiftOpeningCash == null) {
    return null;
  }

  final currentOpeningCash = double.tryParse(shiftOpeningCash.toString().replaceAll(',', '')) ?? 0.0;
  return previousShiftClosingCash - currentOpeningCash;
}
