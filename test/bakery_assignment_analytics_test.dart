import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/presentation/inventory/utils/bakery_assignment_analytics.dart';

void main() {
  group('BakeryAssignmentAnalytics', () {
    test('summarizes expected vs actual production accurately', () {
      final analytics = BakeryAssignmentAnalytics.summarize([
        {
          'inventoryName': 'Flour',
          'expectedProductionAmount': 120,
          'actualProductionAmount': 100,
          'createdAt': DateTime(2024, 1, 2),
        },
        {
          'inventoryName': 'Sugar',
          'expectedProductionAmount': 80,
          'actualProductionAmount': 90,
          'createdAt': DateTime(2024, 1, 3),
        },
      ]);

      expect(analytics.assignmentCount, 2);
      expect(analytics.expectedTotal, 200);
      expect(analytics.actualTotal, 190);
      expect(analytics.variance, -10);
      expect(analytics.completionRate, 95);
    });
  });
}
