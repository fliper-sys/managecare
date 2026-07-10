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

  static List<String> buildDiscrepancyNotes({
    required double opening,
    required double closing,
    required double analogClosing,
    required double shiftOpeningCash,
    required double shiftCloseCash,
    required double cash,
    required double pos,
    required double digitalVolume,
    required double shiftCashDifference,
    required double price,
    required double expectedAmount,
    required double totalPaid,
    required bool hasShiftCashEntry,
    required bool hasAnalogEntry,
    required double? previousClosingVolume,
    required double? previousAnalogClosingVolume,
    required String? productId,
    required String? shiftOpeningCashPhotoUrl,
    required String? shiftCloseCashPhotoUrl,
    required String? openingPhotoUrl,
    required String? closingPhotoUrl,
  }) {
    final issues = <String>[];

    if (closing <= opening) {
      issues.add('Closing ≤ opening');
    }

    if (previousClosingVolume != null &&
        (opening - previousClosingVolume).abs() > 0.001) {
      issues.add('Opening mismatch');
    }

    if (!hasShiftCashEntry) {
      issues.add('Missing shift cash');
    } else {
      if (shiftOpeningCash <= 0 || shiftCloseCash <= 0) {
        issues.add('Shift cash invalid');
      }
      if (shiftCashDifference <= 0) {
        issues.add('Shift cash drop');
      }
    }

    final volumeFromPumpCash = digitalVolume * price;
    final cashReconciliationDifference =
        (shiftCashDifference - volumeFromPumpCash).abs();
    const maxCashReconciliationDifference = 500.0;
    if (cashReconciliationDifference > maxCashReconciliationDifference) {
      issues.add('Cash/volume gap');
    }

    if (hasAnalogEntry && previousAnalogClosingVolume != null) {
      final analogVolume = analogClosing - previousAnalogClosingVolume;
      const maxAnalogDifference = 1.0;
      if ((analogVolume - digitalVolume).abs() > maxAnalogDifference) {
        issues.add('Analog mismatch');
      }
    }

    if (!matchesShiftDifferenceAndCashPos(
      shiftDifference: shiftCashDifference,
      cash: cash,
      pos: pos,
      tolerancePercent: 0.25,
    )) {
      issues.add('Cash+POS mismatch');
    }

    if (totalPaid > 0 && (totalPaid - expectedAmount).abs() > 0.01) {
      issues.add('Total paid mismatch');
    }

    if (productId == null || productId.isEmpty) {
      issues.add('Product not set');
    }

    if (shiftOpeningCashPhotoUrl == null || shiftOpeningCashPhotoUrl.isEmpty) {
      issues.add('Missing shift cash photo');
    }
    if (shiftCloseCashPhotoUrl == null || shiftCloseCashPhotoUrl.isEmpty) {
      issues.add('Missing close cash photo');
    }
    if (openingPhotoUrl == null || openingPhotoUrl.isEmpty) {
      issues.add('Missing opening photo');
    }
    if (closingPhotoUrl == null || closingPhotoUrl.isEmpty) {
      issues.add('Missing closing photo');
    }

    return issues;
  }

  static String formatDiscrepancySummary(List<String> notes) {
    if (notes.isEmpty) return '';
    if (notes.length <= 3) {
      return notes.join(' • ');
    }
    return '${notes.take(3).join(' • ')} • +${notes.length - 3} more';
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

List<String> buildDiscrepancyNotes({
  required double opening,
  required double closing,
  required double analogClosing,
  required double shiftOpeningCash,
  required double shiftCloseCash,
  required double cash,
  required double pos,
  required double digitalVolume,
  required double shiftCashDifference,
  required double price,
  required double expectedAmount,
  required double totalPaid,
  required bool hasShiftCashEntry,
  required bool hasAnalogEntry,
  required double? previousClosingVolume,
  required double? previousAnalogClosingVolume,
  required String? productId,
  required String? shiftOpeningCashPhotoUrl,
  required String? shiftCloseCashPhotoUrl,
  required String? openingPhotoUrl,
  required String? closingPhotoUrl,
}) {
  return PumpDailyUploadValidation.buildDiscrepancyNotes(
    opening: opening,
    closing: closing,
    analogClosing: analogClosing,
    shiftOpeningCash: shiftOpeningCash,
    shiftCloseCash: shiftCloseCash,
    cash: cash,
    pos: pos,
    digitalVolume: digitalVolume,
    shiftCashDifference: shiftCashDifference,
    price: price,
    expectedAmount: expectedAmount,
    totalPaid: totalPaid,
    hasShiftCashEntry: hasShiftCashEntry,
    hasAnalogEntry: hasAnalogEntry,
    previousClosingVolume: previousClosingVolume,
    previousAnalogClosingVolume: previousAnalogClosingVolume,
    productId: productId,
    shiftOpeningCashPhotoUrl: shiftOpeningCashPhotoUrl,
    shiftCloseCashPhotoUrl: shiftCloseCashPhotoUrl,
    openingPhotoUrl: openingPhotoUrl,
    closingPhotoUrl: closingPhotoUrl,
  );
}

String formatDiscrepancySummary(List<String> notes) {
  return PumpDailyUploadValidation.formatDiscrepancySummary(notes);
}
