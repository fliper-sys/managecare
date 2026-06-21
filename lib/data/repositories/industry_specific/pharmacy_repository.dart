import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/industry_specific/pharmacy/drug_model.dart';
import '../../models/industry_specific/pharmacy/patient_model.dart';
import '../../models/industry_specific/pharmacy/prescription_model.dart';
import 'pharmacy_repository_impl.dart';

/// Compatibility adapter for older callers that still import the legacy
/// pharmacy repository path.
///
/// The active implementation lives in `pharmacy_repository_impl.dart`. This
/// wrapper keeps the old API surface available while delegating to the newer
/// Firestore-backed repository.
class PharmacyRepository {
  final PharmacyRepositoryImpl _impl;
  final String? _businessId;

  PharmacyRepository({FirebaseFirestore? firestore, String? businessId})
      : _impl = PharmacyRepositoryImpl(firestore: firestore),
        _businessId = businessId;

  Future<List<PrescriptionModel>> fetchPrescriptions() async {
    return _impl.fetchPrescriptions(businessId: _businessId);
  }

  Future<List<DrugModel>> fetchDrugs() async {
    return _impl.fetchDrugs(businessId: _businessId);
  }

  Future<List<PatientModel>> fetchPatients() async {
    return _impl.fetchPatients(businessId: _businessId);
  }

  Future<void> addPrescription(PrescriptionModel prescription) async {
    await _impl.addPrescription(prescription, businessId: _businessId);
  }
}
