import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/data/repositories/inventory_repository_impl.dart';

void main() {
  group('InventoryRepository bakery resupply', () {
    late FakeFirebaseFirestore firestore;
    late InventoryRepositoryImpl repository;
    const businessId = 'biz_123';
    const inventoryId = 'item_1';

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      repository = InventoryRepositoryImpl(firestore: firestore);

      await firestore.collection('businesses').doc(businessId).collection('inventory').doc(inventoryId).set({
        'name': 'Bread Loaf',
        'quantity': 10,
        'unit': 'pcs',
        'cost': 25.0,
      });
    });

    test('records baker resupply, decrements stock, and writes history', () async {
      await repository.recordBakeryResupply(
        businessId: businessId,
        inventoryId: inventoryId,
        quantity: 3,
        bakerId: 'baker_1',
        bakerName: 'Amina',
        notes: 'Morning production batch',
      );

      final itemSnap = await firestore.collection('businesses').doc(businessId).collection('inventory').doc(inventoryId).get();
      expect((itemSnap.get('quantity') as num).toInt(), 7);
      expect((itemSnap.get('stock') as num).toInt(), 7);

      final resupplyDocs = await firestore.collection('businesses').doc(businessId).collection('bakery_resupplies').get();
      expect(resupplyDocs.docs.length, 1);
      final resupplyData = resupplyDocs.docs.first.data();
      expect(resupplyData['inventoryId'], inventoryId);
      expect(resupplyData['bakerId'], 'baker_1');
      expect(resupplyData['bakerName'], 'Amina');
      expect((resupplyData['quantity'] as num).toInt(), 3);

      final historyDocs = await firestore.collection('businesses').doc(businessId).collection('inventory').doc(inventoryId).collection('history').get();
      expect(historyDocs.docs.length, 1);
      final historyData = historyDocs.docs.first.data();
      expect(historyData['action'], 'bakery_resupply');
      expect(historyData['details']['quantity'], 3);
      expect(historyData['details']['bakerName'], 'Amina');
    });
  });
}
