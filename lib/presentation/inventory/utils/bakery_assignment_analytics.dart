class BakeryAssignmentAnalytics {
  const BakeryAssignmentAnalytics({
    required this.assignmentCount,
    required this.expectedTotal,
    required this.actualTotal,
    required this.variance,
    required this.completionRate,
  });

  final int assignmentCount;
  final double expectedTotal;
  final double actualTotal;
  final double variance;
  final double completionRate;

  factory BakeryAssignmentAnalytics.summarize(List<Map<String, dynamic>> assignments) {
    if (assignments.isEmpty) {
      return const BakeryAssignmentAnalytics(
        assignmentCount: 0,
        expectedTotal: 0,
        actualTotal: 0,
        variance: 0,
        completionRate: 0,
      );
    }

    final expectedTotal = assignments.fold<double>(0, (sum, item) {
      final value = item['expectedProductionAmount'];
      return sum + _toDouble(value);
    });

    final actualTotal = assignments.fold<double>(0, (sum, item) {
      final value = item['actualProductionAmount'];
      return sum + _toDouble(value);
    });

    final variance = actualTotal - expectedTotal;
    final completionRate = expectedTotal > 0 ? (actualTotal / expectedTotal) * 100 : 0.0;

    return BakeryAssignmentAnalytics(
      assignmentCount: assignments.length,
      expectedTotal: expectedTotal,
      actualTotal: actualTotal,
      variance: variance,
      completionRate: completionRate,
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(',', '').trim());
      return parsed ?? 0;
    }
    return 0;
  }
}
