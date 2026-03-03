import 'package:cloud_firestore/cloud_firestore.dart';
import 'apartment_repository.dart';
import '../models/apartment_model.dart';
import '../models/unit_model.dart';

class ApartmentRepositoryImpl implements ApartmentRepository {
  final FirebaseFirestore _firestore;
  ApartmentRepositoryImpl({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference _apartmentsRef(String businessId) => _firestore.collection('businesses').doc(businessId).collection('apartments');

  @override
  Future<List<Apartment>> fetchApartments({required String businessId}) async {
    final snap = await _apartmentsRef(businessId).orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => Apartment.fromFirestore(d)).toList();
  }

  @override
  Future<String> createApartment({required String businessId, required Apartment apartment}) async {
    final ref = await _apartmentsRef(businessId).add(apartment.toFirestore());
    return ref.id;
  }

  @override
  Future<List<Unit>> fetchUnits({required String businessId, required String apartmentId}) async {
    final snap = await _apartmentsRef(businessId).doc(apartmentId).collection('units').orderBy('name').get();
    return snap.docs.map((d) => Unit.fromFirestore(d)).toList();
  }

  @override
  Future<String> createUnit({required String businessId, required String apartmentId, required Unit unit}) async {
    final ref = await _apartmentsRef(businessId).doc(apartmentId).collection('units').add(unit.toFirestore());
    return ref.id;
  }

  @override
  Future<void> updateUnit({required String businessId, required String apartmentId, required String unitId, required Map<String, dynamic> update}) async {
    await _apartmentsRef(businessId).doc(apartmentId).collection('units').doc(unitId).update(update);
  }

  @override
  Future<void> deleteUnit({required String businessId, required String apartmentId, required String unitId}) async {
    await _apartmentsRef(businessId).doc(apartmentId).collection('units').doc(unitId).delete();
  }
}
