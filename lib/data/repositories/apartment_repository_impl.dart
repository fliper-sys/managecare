import '../../services/managecare_api_client.dart';
import 'apartment_repository.dart';
import '../models/apartment_model.dart';
import '../models/unit_model.dart';

class ApartmentRepositoryImpl implements ApartmentRepository {
  final ManagecareApiClient _api;
  ApartmentRepositoryImpl({ManagecareApiClient? api})
      : _api = api ?? ManagecareApiClient.instance;

  @override
  Future<List<Apartment>> fetchApartments({required String businessId}) async {
    final response = await _api.get('/api/apartments/$businessId');
    return ((response['data'] as List?) ?? [])
        .map((row) => Apartment.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<String> createApartment({required String businessId, required Apartment apartment}) async {
    final response = await _api.post(
      '/api/apartments/$businessId',
      body: apartment.toApi(),
    );
    return response['id'].toString();
  }

  @override
  Future<void> updateApartment({
    required String businessId,
    required String apartmentId,
    required Map<String, dynamic> update,
  }) async {
    await _api.patch(
      '/api/apartments/$businessId/$apartmentId',
      body: update,
    );
  }

  @override
  Future<void> deleteApartment({
    required String businessId,
    required String apartmentId,
  }) async {
    await _api.delete('/api/apartments/$businessId/$apartmentId');
  }

  @override
  Future<List<Unit>> fetchUnits({required String businessId, required String apartmentId}) async {
    final response =
        await _api.get('/api/apartments/$businessId/$apartmentId/units');
    return ((response['data'] as List?) ?? [])
        .map((row) => Unit.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<String> createUnit({required String businessId, required String apartmentId, required Unit unit}) async {
    final response = await _api.post(
      '/api/apartments/$businessId/$apartmentId/units',
      body: unit.toApi(),
    );
    return response['id'].toString();
  }

  @override
  Future<void> updateUnit({required String businessId, required String apartmentId, required String unitId, required Map<String, dynamic> update}) async {
    await _api.patch(
      '/api/apartments/$businessId/$apartmentId/units/$unitId',
      body: update,
    );
  }

  @override
  Future<void> deleteUnit({required String businessId, required String apartmentId, required String unitId}) async {
    await _api.delete('/api/apartments/$businessId/$apartmentId/units/$unitId');
  }
}
