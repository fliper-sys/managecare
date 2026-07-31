import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../models/industry_specific/pharmacy/drug_model.dart';
import '../../models/industry_specific/pharmacy/prescription_model.dart';
import '../../models/industry_specific/pharmacy/patient_model.dart';

/// Supabase/Postgres-backed implementation of the pharmacy repository.
/// Replaces the Firestore version. Drugs are just inventory items (the
/// `/api/inventory` routes, already used by every other vertical) with
/// pharmacy-only fields (manufacturer/dosageForm/strength/prescriptions)
/// folded into inventory's generic `metadata` JSONB column. Patients,
/// prescriptions, treatments and the audit log are genuinely pharmacy-only
/// and live under `/api/pharmacy`.
class PharmacyRepositoryImpl {
  final Dio _http;
  final SupabaseClient _supabase;

  /// Kept for API-compatibility with the old Firestore implementation
  /// (PharmacyProvider reads this after fetchPrescriptions). The REST API
  /// has no query-index limitations, so this is always false now.
  bool lastPrescriptionsFetchUsedFallback = false;

  PharmacyRepositoryImpl({Dio? http, SupabaseClient? supabase})
      : _http = http ??
            Dio(BaseOptions(
              baseUrl: '${SupabaseConfig.url}/api',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            )),
        _supabase = supabase ?? Supabase.instance.client;

  String? get _accessToken => _supabase.auth.currentSession?.accessToken;
  Map<String, dynamic> get _headers => {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      };

  String _extractError(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) return data['error'].toString();
      if (data is String) return data;
    } catch (_) {}
    return e.message ?? 'Unknown error';
  }

  // ---------- Drugs (inventory-backed) ----------

  Map<String, dynamic> _drugJsonFromRow(Map<String, dynamic> row) {
    final metadata = (row['metadata'] is Map)
        ? Map<String, dynamic>.from(row['metadata'] as Map)
        : <String, dynamic>{};
    return {
      'id': row['id'],
      'name': row['name'],
      'manufacturer': metadata['manufacturer'],
      'dosageForm': metadata['dosageForm'],
      'strength': metadata['strength'],
      'expiryDate': row['expiry_date'],
      'quantity': row['quantity'],
      'price': row['unit_price'],
      'cost': row['cost_price'],
      'prescriptions': metadata['prescriptions'],
    };
  }

  Map<String, dynamic> _buildDrugPayload(DrugModel drug, {Map<String, dynamic>? extraData}) {
    final resolvedCost = extraData?['cost'] ?? extraData?['costPrice'] ?? drug.costPrice;
    final resolvedPrice = extraData?['price'] ?? drug.price;
    final resolvedQuantity = extraData?['quantity'] ?? drug.quantity;
    final resolvedPrescriptions = extraData?['prescriptions'] ?? drug.prescriptions;
    return {
      if (drug.id.isNotEmpty) 'id': drug.id,
      'name': drug.name,
      'category': 'Pharmacy',
      'unit_price': resolvedPrice,
      'cost_price': resolvedCost,
      'quantity': resolvedQuantity,
      'unit': 'unit',
      'min_stock_level': 10,
      'expiry_date': drug.expiryDate.toIso8601String(),
      'metadata': {
        'manufacturer': drug.manufacturer,
        'dosageForm': drug.dosageForm,
        'strength': drug.strength,
        'prescriptions': resolvedPrescriptions,
      },
    };
  }

  Future<List<DrugModel>> fetchDrugs({String? businessId}) async {
    if (businessId == null || businessId.isEmpty) return [];
    try {
      final response = await _http.get(
        '/inventory/$businessId',
        options: Options(headers: _headers),
      );
      final rows = (response.data['data'] as List?) ?? [];
      return rows
          .map((r) => DrugModel.fromJson(_drugJsonFromRow(Map<String, dynamic>.from(r as Map))))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to fetch drugs: ${_extractError(e)}');
    }
  }

  Future<List<DrugModel>> searchDrugs({String? businessId, required String query}) async {
    if (businessId == null || businessId.isEmpty || query.trim().isEmpty) return [];
    try {
      final response = await _http.get(
        '/inventory/$businessId',
        queryParameters: {'search': query},
        options: Options(headers: _headers),
      );
      final rows = (response.data['data'] as List?) ?? [];
      return rows
          .map((r) => DrugModel.fromJson(_drugJsonFromRow(Map<String, dynamic>.from(r as Map))))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to search drugs: ${_extractError(e)}');
    }
  }

  /// Create-or-update a drug. The inventory create route upserts on the
  /// client-supplied id, so one POST covers both cases.
  Future<void> syncDrug(DrugModel drug, {String? businessId, Map<String, dynamic>? extraData}) async {
    if (businessId == null || businessId.isEmpty) return;
    try {
      await _http.post(
        '/inventory/$businessId',
        data: _buildDrugPayload(drug, extraData: extraData),
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to sync drug: ${_extractError(e)}');
    }
  }

  Future<List<DrugModel>> getExpiringDrugs(String businessId, DateTime before) async {
    final drugs = await fetchDrugs(businessId: businessId);
    return drugs.where((d) => d.expiryDate.isBefore(before)).toList();
  }

  Future<List<DrugModel>> getLowStockDrugs(String businessId, {int threshold = 10}) async {
    final drugs = await fetchDrugs(businessId: businessId);
    return drugs.where((d) => d.quantity < threshold).toList();
  }

  Future<void> deleteDrug({required String businessId, required String drugId}) async {
    if (businessId.isEmpty || drugId.isEmpty) return;
    try {
      await _http.delete(
        '/inventory/$businessId/$drugId',
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to delete drug: ${_extractError(e)}');
    }
  }

  // ---------- Patients ----------

  Map<String, dynamic> _patientJsonFromRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'name': row['name'],
      'phone': row['phone'],
      'email': row['email'],
      'address': row['address'],
      'dateOfBirth': row['date_of_birth'],
      'allergies': row['allergies'],
      'bloodType': row['blood_type'],
      'additionalNotes': row['additional_notes'],
    };
  }

  Future<List<PatientModel>> fetchPatients({String? businessId}) async {
    if (businessId == null || businessId.isEmpty) return [];
    try {
      final response = await _http.get(
        '/pharmacy/$businessId/patients',
        options: Options(headers: _headers),
      );
      final rows = (response.data['data'] as List?) ?? [];
      return rows
          .map((r) => PatientModel.fromJson(_patientJsonFromRow(Map<String, dynamic>.from(r as Map))))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to fetch patients: ${_extractError(e)}');
    }
  }

  Future<void> addPatient(Map<String, dynamic> patient, {String? businessId}) async {
    if (businessId == null || businessId.isEmpty) return;
    try {
      await _http.post(
        '/pharmacy/$businessId/patients',
        data: {
          'id': patient['id'],
          'name': patient['name'],
          'phone': patient['phone'],
          'email': patient['email'],
          'address': patient['address'],
          'date_of_birth': patient['dateOfBirth'],
          'allergies': patient['allergies'],
          'blood_type': patient['bloodType'],
          'additional_notes': patient['additionalNotes'],
        },
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to add patient: ${_extractError(e)}');
    }
  }

  /// businessId travels inside [updates] (as `updates['businessId']`) to
  /// match PharmacyProvider's existing call shape.
  Future<void> updatePatient(String patientId, Map<String, dynamic> updates) async {
    if (patientId.isEmpty) return;
    final businessId = updates['businessId']?.toString();
    if (businessId == null || businessId.isEmpty) return;
    try {
      await _http.put(
        '/pharmacy/$businessId/patients/$patientId',
        data: {
          if (updates.containsKey('name')) 'name': updates['name'],
          if (updates.containsKey('phone')) 'phone': updates['phone'],
          if (updates.containsKey('email')) 'email': updates['email'],
          if (updates.containsKey('address')) 'address': updates['address'],
          if (updates.containsKey('dateOfBirth')) 'date_of_birth': updates['dateOfBirth'],
          if (updates.containsKey('allergies')) 'allergies': updates['allergies'],
          if (updates.containsKey('bloodType')) 'blood_type': updates['bloodType'],
          if (updates.containsKey('additionalNotes')) 'additional_notes': updates['additionalNotes'],
        },
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to update patient: ${_extractError(e)}');
    }
  }

  // ---------- Prescriptions ----------

  Map<String, dynamic> _prescriptionJsonFromRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'patientId': row['patient_id'],
      'patientName': row['patient_name'],
      'items': row['items'],
      'issuedAt': row['issued_at'],
      'prescriber': row['prescriber_id'],
      'prescriberName': row['prescriber_name'],
      'status': row['status'],
      'notes': row['notes'],
      'attachmentReference': row['attachment_reference'],
      'attachmentRequired': row['attachment_required'],
      'patientDateOfBirth': row['patient_date_of_birth'],
    };
  }

  Future<List<PrescriptionModel>> fetchPrescriptions({String? businessId}) async {
    if (businessId == null || businessId.isEmpty) return [];
    try {
      final response = await _http.get(
        '/pharmacy/$businessId/prescriptions',
        options: Options(headers: _headers),
      );
      final rows = (response.data['data'] as List?) ?? [];
      lastPrescriptionsFetchUsedFallback = false;
      return rows
          .map((r) => PrescriptionModel.fromJson(_prescriptionJsonFromRow(Map<String, dynamic>.from(r as Map))))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to fetch prescriptions: ${_extractError(e)}');
    }
  }

  Future<String?> addPrescription(
    PrescriptionModel prescription, {
    String? businessId,
    Map<String, dynamic>? extraData,
  }) async {
    if (businessId == null || businessId.isEmpty) return null;
    try {
      final data = prescription.toJson();
      if (extraData != null) data.addAll(extraData);
      final response = await _http.post(
        '/pharmacy/$businessId/prescriptions',
        data: {
          'id': data['id'],
          'patient_id': data['patientId'],
          'patient_name': data['patientName'],
          'items': data['items'],
          'status': data['status'],
          'prescriber_id': data['prescriber'],
          'prescriber_name': data['prescriberName'],
          'notes': data['notes'],
          'attachment_reference': data['attachmentReference'],
          'attachment_required': data['attachmentRequired'],
          'patient_date_of_birth': data['patientDateOfBirth'],
          'issued_at': data['issuedAt'],
        },
        options: Options(headers: _headers),
      );
      return response.data['id']?.toString();
    } on DioException catch (e) {
      throw Exception('Failed to add prescription: ${_extractError(e)}');
    }
  }

  /// [businessId] is optional for backward compatibility but must be passed
  /// by every real caller - the route is business-scoped and returns 400
  /// without it.
  Future<void> updatePrescription(
    String prescriptionId,
    Map<String, dynamic> updates, {
    String? businessId,
  }) async {
    if (prescriptionId.isEmpty || businessId == null || businessId.isEmpty) return;
    try {
      await _http.put(
        '/pharmacy/$businessId/prescriptions/$prescriptionId',
        data: {
          if (updates.containsKey('patientId')) 'patient_id': updates['patientId'],
          if (updates.containsKey('patientName')) 'patient_name': updates['patientName'],
          if (updates.containsKey('items')) 'items': updates['items'],
          if (updates.containsKey('status')) 'status': updates['status'],
          if (updates.containsKey('notes')) 'notes': updates['notes'],
        },
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to update prescription: ${_extractError(e)}');
    }
  }

  // ---------- Treatments ----------

  Map<String, dynamic> _treatmentJsonFromRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'patientId': row['patient_id'],
      'name': row['name'],
      'drugName': row['drug_name'],
      'dosage': row['dosage'],
      'frequencyPerDay': row['frequency_per_day'],
      'durationDays': row['duration_days'],
      'startDate': row['start_date'],
      'endDate': row['end_date'],
      'isActive': row['is_active'],
      'administeredLog': row['administered_log'],
    };
  }

  Future<List<Map<String, dynamic>>> fetchTreatments({String? businessId}) async {
    if (businessId == null || businessId.isEmpty) return [];
    try {
      final response = await _http.get(
        '/pharmacy/$businessId/treatments',
        options: Options(headers: _headers),
      );
      final rows = (response.data['data'] as List?) ?? [];
      return rows.map((r) => _treatmentJsonFromRow(Map<String, dynamic>.from(r as Map))).toList();
    } on DioException catch (e) {
      throw Exception('Failed to fetch treatments: ${_extractError(e)}');
    }
  }

  Future<void> addTreatment(Map<String, dynamic> treatment, {String? businessId}) async {
    if (businessId == null || businessId.isEmpty) return;
    try {
      await _http.post(
        '/pharmacy/$businessId/treatments',
        data: {
          'id': treatment['id'],
          'patient_id': treatment['patientId'],
          'name': treatment['name'],
          'drug_name': treatment['drugName'],
          'dosage': treatment['dosage'],
          'frequency_per_day': treatment['frequencyPerDay'],
          'duration_days': treatment['durationDays'],
          'start_date': treatment['startDate'],
          'end_date': treatment['endDate'],
          'is_active': treatment['isActive'],
          'administered_log': treatment['administeredLog'],
        },
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to add treatment: ${_extractError(e)}');
    }
  }

  Future<void> updateTreatment(
    String treatmentId,
    Map<String, dynamic> updates, {
    required String businessId,
  }) async {
    if (businessId.isEmpty || treatmentId.isEmpty) return;
    try {
      await _http.put(
        '/pharmacy/$businessId/treatments/$treatmentId',
        data: {
          if (updates.containsKey('patientId')) 'patient_id': updates['patientId'],
          if (updates.containsKey('name')) 'name': updates['name'],
          if (updates.containsKey('drugName')) 'drug_name': updates['drugName'],
          if (updates.containsKey('dosage')) 'dosage': updates['dosage'],
          if (updates.containsKey('frequencyPerDay')) 'frequency_per_day': updates['frequencyPerDay'],
          if (updates.containsKey('durationDays')) 'duration_days': updates['durationDays'],
          if (updates.containsKey('startDate')) 'start_date': updates['startDate'],
          if (updates.containsKey('endDate')) 'end_date': updates['endDate'],
          if (updates.containsKey('isActive')) 'is_active': updates['isActive'],
          if (updates.containsKey('administeredLog')) 'administered_log': updates['administeredLog'],
        },
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to update treatment: ${_extractError(e)}');
    }
  }

  // ---------- Audit log ----------

  /// businessId travels inside [auditData] (as `auditData['businessId']`) to
  /// match PharmacyProvider's existing call shape.
  Future<void> logAudit(Map<String, dynamic> auditData) async {
    final businessId = auditData['businessId']?.toString();
    if (businessId == null || businessId.isEmpty) return;
    try {
      final payload = Map<String, dynamic>.from(auditData)..remove('businessId');
      final actorId = payload.remove('userId');
      payload['actor_id'] = actorId;
      await _http.post(
        '/pharmacy/$businessId/audit',
        data: payload,
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to log audit: ${_extractError(e)}');
    }
  }
}
