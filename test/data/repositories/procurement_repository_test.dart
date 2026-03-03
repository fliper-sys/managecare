import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/data/repositories/procurement_repository.dart';

void main() {
  group('ProcurementRepository', () {
    late FakeFirebaseFirestore firestore;
    late ProcurementRepository repo;
    const businessId = 'biz_123';

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      repo = ProcurementRepository(firestore: firestore);

      // Create two inventory products
      await firestore.collection('businesses').doc(businessId).collection('inventory').doc('p1').set({
        'name': 'Product 1',
        'quantity': 5,
        'cost': 10.0,
      });

      await firestore.collection('businesses').doc(businessId).collection('inventory').doc('p2').set({
        'name': 'Product 2',
        'quantity': 2,
        'cost': 5.0,
      });

      // Add a supplier doc for testing
      await firestore.collection('businesses').doc(businessId).collection('suppliers').doc('s1').set({
        'name': 'Supplier One',
        'contact': '123',
        'email': 'supplier@example.com',
      });
    });

    test('createBatchProcurement writes master doc, increments inventory and creates product procurements', () async {
      final items = [
        {'productId': 'p1', 'name': 'Product 1', 'quantity': 3, 'cost': 50.0},
        {'productId': 'p2', 'name': 'Product 2', 'quantity': 2, 'cost': 20.0},
      ];

      final id = await repo.createBatchProcurement(businessId: businessId, items: items, supplierId: 's1', supplierName: 'Supplier One', invoiceRef: 'INV-1001');

      // Validate procurement master
      final masterSnap = await firestore.collection('businesses').doc(businessId).collection('procurements').doc(id).get();
      expect(masterSnap.exists, isTrue);
      final masterData = masterSnap.data()!;
      expect(masterData['totalQuantity'], 5);
      expect((masterData['totalCost'] as num).toDouble(), 190.0);
      expect((masterData['itemsCount'] as num).toInt(), 2);

      // supplier/invoice present
      expect(masterData['supplierId'], 's1');
      expect(masterData['supplierName'], 'Supplier One');
      expect(masterData['invoiceRef'], 'INV-1001');

      // Validate inventory increments
      final p1 = await firestore.collection('businesses').doc(businessId).collection('inventory').doc('p1').get();
      final p2 = await firestore.collection('businesses').doc(businessId).collection('inventory').doc('p2').get();
      expect((p1.get('quantity') as num).toInt(), 8); // 5 + 3
      expect((p2.get('quantity') as num).toInt(), 4); // 2 + 2

      // Validate product procurements
      final p1Procs = await firestore.collection('businesses').doc(businessId).collection('inventory').doc('p1').collection('procurements').get();
      final p2Procs = await firestore.collection('businesses').doc(businessId).collection('inventory').doc('p2').collection('procurements').get();
      expect(p1Procs.docs.length, greaterThanOrEqualTo(1));
      expect(p2Procs.docs.length, greaterThanOrEqualTo(1));

      final foundP1 = p1Procs.docs.firstWhere((d) => d.get('procurementId') == id);
      expect(foundP1.get('quantity'), 3);
      expect((foundP1.get('cost') as num).toDouble(), 50.0);

      // CSV formatting (should include supplier and invoice)
      final allDocs = (await firestore.collection('businesses').doc(businessId).collection('procurements').get()).docs;
      final csv = repo.procurementsToCsv(allDocs);
      expect(csv.contains(id), isTrue);
      expect(csv.contains('Product 1'), isTrue);
      expect(csv.contains('Product 2'), isTrue);
      expect(csv.contains('Supplier One'), isTrue);
      expect(csv.contains('INV-1001'), isTrue);
    });
  });
}
