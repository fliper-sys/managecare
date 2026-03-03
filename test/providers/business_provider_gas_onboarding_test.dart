import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:business_manager/data/repositories/business_repository_impl.dart';
import 'package:business_manager/providers/business_provider.dart';
import 'package:business_manager/data/models/business_model.dart';

void main() {
  group('BusinessProvider Gas onboarding', () {
    late FakeFirebaseFirestore firestore;
    late BusinessRepository repo;
    late BusinessProvider provider;

    setUp(() async {
      // Ensure shared preferences mock is initialized so LocalBusinessStorage.create() works
      SharedPreferences.setMockInitialValues({});
      firestore = FakeFirebaseFirestore();
      repo = BusinessRepository(firestore: firestore);
      provider = BusinessProvider(repository: repo);
    });

    test('createBusiness automatically adds default fuel products and marks business configured', () async {
      final business = BusinessModel(
        id: 'gas_biz_1',
        name: 'Test Gas Station',
        businessType: 'gas',
        ownerId: 'owner1',
        createdAt: DateTime.now(),
        industrySpecificSettings: {
          'fuelUnit': 'L',
          'defaultFuelProductsConfigured': false,
        },
      );

      final success = await provider.createBusiness(business);
      expect(success, isTrue);

      // Verify inventory docs exist
      final petrol = await firestore.collection('businesses').doc(business.id).collection('inventory').doc('petrol').get();
      final diesel = await firestore.collection('businesses').doc(business.id).collection('inventory').doc('diesel').get();
      final kero = await firestore.collection('businesses').doc(business.id).collection('inventory').doc('kerosene').get();
      final cooking = await firestore.collection('businesses').doc(business.id).collection('inventory').doc('cooking_gas').get();

      expect(petrol.exists, isTrue);
      expect(diesel.exists, isTrue);
      expect(kero.exists, isTrue);
      expect(cooking.exists, isTrue);

      // Verify business doc was updated to mark configuration
      final bdoc = await firestore.collection('businesses').doc(business.id).get();
      final data = bdoc.data()!;
      expect(data['industrySpecificSettings'], isNotNull);
      expect((data['industrySpecificSettings']['defaultFuelProductsConfigured']), isTrue);
    });
  });
}
