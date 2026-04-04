import 'package:flutter/material.dart';
import '../data/models/apartment_model.dart';
import '../data/models/unit_model.dart';
import '../data/repositories/apartment_repository.dart';
import '../data/repositories/apartment_repository_impl.dart';

class ApartmentProvider extends ChangeNotifier {
  final ApartmentRepository _repo;

  ApartmentProvider({ApartmentRepository? repository}) : _repo = repository ?? ApartmentRepositoryImpl();

  List<Apartment> apartments = [];
  Map<String, List<Unit>> units = {}; // apartmentId -> units
  bool isLoading = false;

  Future<void> loadApartments(String businessId) async {
    isLoading = true;
    notifyListeners();
    try {
      apartments = await _repo.fetchApartments(businessId: businessId);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUnits(String businessId, String apartmentId) async {
    final list = await _repo.fetchUnits(businessId: businessId, apartmentId: apartmentId);
    units[apartmentId] = list;
    notifyListeners();
  }

  Future<void> addUnit(String businessId, String apartmentId, Unit unit) async {
    await _repo.createUnit(businessId: businessId, apartmentId: apartmentId, unit: unit);
    await loadUnits(businessId, apartmentId);
  }

  /// Create a new apartment and refresh list
  Future<String> createApartment({required String businessId, required Apartment apartment}) async {
    final id = await _repo.createApartment(businessId: businessId, apartment: apartment);
    await loadApartments(businessId);
    return id;
  }

  Future<void> updateApartment(
    String businessId,
    String apartmentId,
    Map<String, dynamic> update,
  ) async {
    await _repo.updateApartment(
      businessId: businessId,
      apartmentId: apartmentId,
      update: update,
    );
    await loadApartments(businessId);
  }

  Future<void> deleteApartment(String businessId, String apartmentId) async {
    await _repo.deleteApartment(
      businessId: businessId,
      apartmentId: apartmentId,
    );
    units.remove(apartmentId);
    await loadApartments(businessId);
  }

  Future<void> updateUnit(String businessId, String apartmentId, String unitId, Map<String, dynamic> update) async {
    await _repo.updateUnit(businessId: businessId, apartmentId: apartmentId, unitId: unitId, update: update);
    await loadUnits(businessId, apartmentId);
  }

  Future<void> deleteUnit(String businessId, String apartmentId, String unitId) async {
    await _repo.deleteUnit(businessId: businessId, apartmentId: apartmentId, unitId: unitId);
    await loadUnits(businessId, apartmentId);
  }

  /// Reset provider state - called during logout to clear all cached data
  void reset() {
    apartments.clear();
    units.clear();
    isLoading = false;
    notifyListeners();
  }
}
