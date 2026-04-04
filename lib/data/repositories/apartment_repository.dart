import '../models/apartment_model.dart';
import '../models/unit_model.dart';

abstract class ApartmentRepository {
  Future<List<Apartment>> fetchApartments({required String businessId});
  Future<String> createApartment({required String businessId, required Apartment apartment});
  Future<void> updateApartment({
    required String businessId,
    required String apartmentId,
    required Map<String, dynamic> update,
  });
  Future<void> deleteApartment({
    required String businessId,
    required String apartmentId,
  });

  Future<List<Unit>> fetchUnits({required String businessId, required String apartmentId});
  Future<String> createUnit({required String businessId, required String apartmentId, required Unit unit});
  Future<void> updateUnit({required String businessId, required String apartmentId, required String unitId, required Map<String, dynamic> update});
  Future<void> deleteUnit({required String businessId, required String apartmentId, required String unitId});
}
