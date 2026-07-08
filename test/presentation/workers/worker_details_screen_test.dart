import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/presentation/workers/screens/worker_details_screen.dart';

void main() {
  group('WorkerDetailsScreen bakery activity', () {
    test('summarizes bakery output from procurement items', () {
      final summary = summarizeBakeryActivity(
        {
          'items': [
            {'name': 'Bread', 'quantity': 12},
            {'name': 'Cake', 'quantity': 4},
          ],
          'totalQuantity': 16,
        },
        isOutput: true,
      );

      expect(summary, contains('Bread'));
      expect(summary, contains('Cake'));
      expect(summary, contains('12'));
    });

    test('falls back to notes for input entries', () {
      final summary = summarizeBakeryActivity(
        {
          'notes': 'Morning ingredients',
        },
        isOutput: false,
      );

      expect(summary, 'Morning ingredients');
    });
  });
}
