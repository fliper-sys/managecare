import '../../models/industry_specific/pharmacy/prescription_model.dart';
import '../../models/industry_specific/pharmacy/drug_model.dart';
import '../../models/industry_specific/pharmacy/patient_model.dart';

/// Minimal repository stub for pharmacy operations.
class PharmacyRepository {
  Future<List<PrescriptionModel>> fetchPrescriptions() async {
    // TODO: implement data fetching (API / local DB)
    return [];
  }

  Future<List<DrugModel>> fetchDrugs() async {
    return [];
  }

  Future<List<PatientModel>> fetchPatients() async {
    return [];
  }

  Future<void> addPrescription(PrescriptionModel prescription) async {
    // TODO: persist
  }
}

