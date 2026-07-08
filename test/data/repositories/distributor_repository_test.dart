import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/data/repositories/distributor_repository.dart';

void main() {
  group('DistributorRepository', () {
    late FakeFirebaseFirestore firestore;
    late DistributorRepository repository;
    const businessId = 'biz_123';

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      repository = DistributorRepository(firestore: firestore);

      await firestore.collection('businesses').doc(businessId).collection('inventory').doc('p1').set({
        'name': 'Bread Loaf',
        'quantity': 10,
        'price': 50.0,
      });
    });

    test('records a discounted distributor sale and updates stock', () async {
      await repository.recordDistributorSale(
        businessId: businessId,
        distributorId: 'dist_1',
        distributorName: 'City Distributors',
        productId: 'p1',
        productName: 'Bread Loaf',
        quantity: 2,
        unitPrice: 50.0,
        discountPercent: 10.0,
      );

      final saleDocs = await firestore.collection('businesses').doc(businessId).collection('distributor_sales').get();
      expect(saleDocs.docs.length, 1);
      final saleData = saleDocs.docs.first.data();
      expect(saleData['distributorName'], 'City Distributors');
      expect(saleData['discountPercent'], 10.0);
      expect(saleData['discountedUnitPrice'], 45.0);

      final distributorSaleDocs = await firestore.collection('businesses').doc(businessId).collection('distributors').doc('dist_1').collection('sales').get();
      expect(distributorSaleDocs.docs.length, 1);

      final businessSaleDocs = await firestore.collection('businesses').doc(businessId).collection('sales').get();
      expect(businessSaleDocs.docs.length, 1);
      expect(businessSaleDocs.docs.first.data()['saleType'], 'distributor');

      final historyDocs = await firestore.collection('businesses').doc(businessId).collection('inventory').doc('p1').collection('history').get();
      expect(historyDocs.docs.length, 1);
      expect(historyDocs.docs.first.data()['action'], 'distributor_sale');

      final itemSnap = await firestore.collection('businesses').doc(businessId).collection('inventory').doc('p1').get();
      expect((itemSnap.get('quantity') as num).toInt(), 8);
    });

    test('rejects distributor sales that exceed available stock', () async {
      await expectLater(
        repository.recordDistributorSale(
          businessId: businessId,
          distributorId: 'dist_1',
          distributorName: 'City Distributors',
          productId: 'p1',
          productName: 'Bread Loaf',
          quantity: 11,
          unitPrice: 50.0,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
