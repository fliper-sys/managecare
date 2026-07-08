import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:business_manager/data/repositories/worker_repository_impl.dart';
import 'package:business_manager/providers/workers_provider.dart';

void main() {
  group('WorkersProvider', () {
    test('accepts an injected Firestore instance even when the repository is omitted', () async {
      final firestore = FakeFirebaseFirestore();
      final provider = WorkersProvider(
        businessId: 'business-1',
        firestore: firestore,
      );

      await provider.updateWorker(
        'worker-1',
        {
          'role': 'manager',
          'roles': ['manager'],
        },
        businessId: 'business-1',
        roles: ['manager'],
      );

      expect(provider.isLoading, isFalse);
    });

    test('syncs role updates to the users document', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = WorkerRepositoryImpl(firestore: firestore);
      final provider = WorkersProvider(
        businessId: '',
        repository: repository,
        firestore: firestore,
      );

      await provider.updateWorker(
        'worker-1',
        {
          'role': 'manager',
          'roles': ['manager'],
          'customPermissions': ['view_inventory'],
        },
        businessId: 'business-1',
        roles: ['manager'],
      );

      final userDoc = await firestore.collection('users').doc('worker-1').get();
      expect(userDoc.exists, isTrue);
      expect(userDoc.data()?['role'], 'manager');
      expect(userDoc.data()?['roles'], ['manager']);
      expect(userDoc.data()?['permissions'], ['view_inventory']);
    });
  });
}
