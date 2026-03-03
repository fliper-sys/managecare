import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:business_manager/presentation/industry_specific/realestate/providers/real_estate_provider.dart';
import '../data/repositories/industry_specific/real_estate_repository_impl.dart';

/// Compatibility wrapper so existing code that expects `RealestateProvider`
/// continues to work while we provide the richer `RealEstateProvider`.
class RealestateProvider extends RealEstateProvider {
  RealestateProvider()
      : super(
            businessId: 'demo',
            repository: RealEstateRepositoryImpl(
                firestore: FirebaseFirestore.instance));
}

