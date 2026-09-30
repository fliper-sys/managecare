import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/core/utils/worker_permissions.dart';

void main() {
  group('Hospitality table management', () {
    test('allows managers and administrator roles only', () {
      for (final role in ['owner', 'admin', 'sub_admin', 'manager']) {
        expect(WorkerPermissions.canManageHospitalityTables(role), isTrue);
      }

      for (final role in ['staff', 'cashier', 'waiter', 'chef', 'bartender']) {
        expect(WorkerPermissions.canManageHospitalityTables(role), isFalse);
      }
    });
  });
}