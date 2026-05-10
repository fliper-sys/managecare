import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/industry_specific/pharmacy/drug_model.dart';
import '../../models/industry_specific/pharmacy/prescription_model.dart';
import '../../models/industry_specific/pharmacy/patient_model.dart';

/// Firestore implementation for pharmacy repository
class PharmacyRepositoryImpl {
  final FirebaseFirestore _firestore;

  /// Indicates whether the last `fetchPrescriptions` call used a local fallback
  /// because a Firestore composite index was required.
  bool lastPrescriptionsFetchUsedFallback = false;

  PharmacyRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try {
      // Firestore Timestamp
      if (v is Timestamp) return v.toDate();
      // ISO string
      if (v is String) return DateTime.tryParse(v);
      // milliseconds since epoch
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    } catch (_) {}
    return null;
  }

  Future<List<PrescriptionModel>> fetchPrescriptions(
      {String? businessId}) async {
    try {
      var query = _firestore.collection('pharmacy_prescriptions') as Query;
      if (businessId != null) {
        query = query.where('businessId', isEqualTo: businessId);
      }

      try {
        // Preferred: server-side ordering for efficiency
        final snapshot = await query.orderBy('issuedAt', descending: true).get();
        // Reset fallback flag on success
        lastPrescriptionsFetchUsedFallback = false;
        return snapshot.docs
            .map((d) => PrescriptionModel.fromJson(
                {...(d.data() as Map<String, dynamic>? ?? {}), 'id': d.id}))
            .toList();
      } on FirebaseException catch (e) {
        // Firestore may require a composite index for where + orderBy.
        final msg = e.message ?? '';
        if (e.code == 'failed-precondition' || msg.contains('requires an index')) {
          // Fallback: fetch without server-side order and sort locally
          // This keeps the app usable while an index is created in Firebase Console.
          final snapshot = await query.get();
          final list = snapshot.docs
              .map((d) => PrescriptionModel.fromJson(
                  {...(d.data() as Map<String, dynamic>? ?? {}), 'id': d.id}))
              .toList();
          list.sort((a, b) {
            final da = _parseDate(a.issuedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
            final db = _parseDate(b.issuedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
            return db.compareTo(da); // descending
          });

          // Mark that fallback was used so caller (provider) can show a UI hint
          lastPrescriptionsFetchUsedFallback = true;
          return list;
        }
        rethrow;
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<DrugModel>> fetchDrugs({String? businessId}) async {
    try {
      if (businessId == null) {
        return [];
      }
      final query = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('inventory');
      final snapshot = await query.get();

      // Debug: log inventory size and a sample document to help diagnose missing fields
      if (snapshot.docs.isNotEmpty) {
        try {
          if (snapshot.docs.length > 0) {
            if (snapshot.docs.length > 5) {
              // avoid too verbose in large collections
              // ignore: avoid_print
              print('[PharmacyRepositoryImpl] fetchDrugs: ${snapshot.docs.length} items (sample id: ${snapshot.docs.first.id})');
            } else {
              // ignore: avoid_print
              print('[PharmacyRepositoryImpl] fetchDrugs: ${snapshot.docs.length} items');
            }
          }
        } catch (_) {}
      } else {
        // ignore: avoid_print
        print('[PharmacyRepositoryImpl] fetchDrugs: 0 items for businessId=$businessId');
      }

      return snapshot.docs
          .map((d) => DrugModel.fromJson({...(d.data() as Map<String, dynamic>? ?? {}), 'id': d.id}))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<PatientModel>> fetchPatients({String? businessId}) async {
    try {
      var query = _firestore.collection('pharmacy_patients') as Query;
      if (businessId != null) {
        query = query.where('businessId', isEqualTo: businessId);
      }
      final snapshot = await query.get();
      return snapshot.docs
          .map((d) => PatientModel.fromJson(
              {...(d.data() as Map<String, dynamic>? ?? {}), 'id': d.id}))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Add a new patient record; if `id` present it will be used as document id
  Future<void> addPatient(Map<String, dynamic> patient, {String? businessId}) async {
    try {
      final data = Map<String, dynamic>.from(patient);
      if (businessId != null) data['businessId'] = businessId;
      data['createdAt'] = DateTime.now().toIso8601String();
      final id = (data['id'] as String?) ?? '';
      if (id.isNotEmpty) {
        await _firestore.collection('pharmacy_patients').doc(id).set(data, SetOptions(merge: true));
      } else {
        await _firestore.collection('pharmacy_patients').add(data);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing patient document
  Future<void> updatePatient(String patientId, Map<String, dynamic> updates) async {
    try {
      if (patientId.isEmpty) return;
      updates['updatedAt'] = DateTime.now().toIso8601String();
      await _firestore.collection('pharmacy_patients').doc(patientId).set(updates, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  /// Add a prescription. Returns the created document id when persisted.
  Future<String?> addPrescription(PrescriptionModel prescription,
      {String? businessId, Map<String, dynamic>? extraData}) async {
    try {
      final data = prescription.toJson();
      if (businessId != null) data['businessId'] = businessId;
      if (extraData != null) data.addAll(extraData);

      // Try to resolve prescriber user name when a user id is provided
      final prescriberId = data['prescriber'] as String?;
      if (prescriberId != null && prescriberId.isNotEmpty) {
        try {
          final userDoc = await _firestore.collection('users').doc(prescriberId).get();
          if (userDoc.exists) {
            final udata = userDoc.data();
            if (udata != null) {
              final name = udata['name'] ?? udata['displayName'] ?? udata['fullName'];
              if (name != null) data['prescriberName'] = name;
            }
          }
        } catch (_) {
          // ignore resolution failures, still save prescriber id
        }
      }

      // If the prescription already has an id, use it as the document id to enable updates
      final givenId = prescription.id;
      if (givenId.isNotEmpty) {
        await _firestore.collection('pharmacy_prescriptions').doc(givenId).set(data, SetOptions(merge: true));
        return givenId;
      } else {
        final docRef = await _firestore.collection('pharmacy_prescriptions').add(data);
        return docRef.id;
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing prescription document (partial update)
  Future<void> updatePrescription(String prescriptionId, Map<String, dynamic> updates) async {
    try {
      if (prescriptionId.isEmpty) return;
      updates['updatedAt'] = DateTime.now().toIso8601String();
      await _firestore.collection('pharmacy_prescriptions').doc(prescriptionId).set(updates, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  /// Search inventory items by name for a business (simple prefix search)
  Future<List<DrugModel>> searchDrugs({String? businessId, required String query}) async {
    try {
      if (businessId == null) return [];
      if (query.trim().isEmpty) return [];
      final start = query;
      final end = query + '\uf8ff';
      final coll = _firestore.collection('businesses').doc(businessId).collection('inventory');
      final snapshot = await coll
          .where('name', isGreaterThanOrEqualTo: start)
          .where('name', isLessThanOrEqualTo: end)
          .get();
      return snapshot.docs.map((d) => DrugModel.fromJson({...(d.data() as Map<String, dynamic>? ?? {}), 'id': d.id})).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> syncDrug(DrugModel drug,
      {String? businessId, Map<String, dynamic>? extraData}) async {
    try {
      if (businessId == null) {
        return;
      }
      final data = drug.toJson();
      if (extraData != null) data.addAll(extraData);
      // Map to inventory collection format
      data['category'] = 'Pharmacy';
      data['emoji'] = data['emoji'] ?? '💊';
      data['sku'] = drug.id;
      data['cost'] = extraData?['cost'] ?? 0.0;
      data['price'] = extraData?['price'] ?? 0.0;
      data['quantity'] = extraData?['quantity'] ?? 0;
      data['unit'] = 'unit';
      data['minStock'] = 10;
      data['trackExpiry'] = true;
      data['createdAt'] = DateTime.now().toIso8601String();
      data['updatedAt'] = DateTime.now().toIso8601String();

      if (drug.id.isNotEmpty) {
        await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('inventory')
            .doc(drug.id)
            .set(data, SetOptions(merge: true));
      } else {
        await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('inventory')
            .add(data);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<DrugModel>> getExpiringDrugs(
      String businessId, DateTime before) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('inventory')
          .where('expiryDate', isLessThan: before)
          .get();
      return snapshot.docs
          .map((d) => DrugModel.fromJson({...(d.data() as Map<String, dynamic>? ?? {}), 'id': d.id}))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<DrugModel>> getLowStockDrugs(String businessId,
      {int threshold = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('inventory')
          .where('quantity', isLessThan: threshold)
          .get();
      return snapshot.docs
          .map((d) => DrugModel.fromJson({...(d.data() as Map<String, dynamic>? ?? {}), 'id': d.id}))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a drug/inventory document for a business
  Future<void> deleteDrug({required String businessId, required String drugId}) async {
    try {
      if (businessId.isEmpty || drugId.isEmpty) return;
      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('inventory')
          .doc(drugId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logAudit(Map<String, dynamic> auditData) async {
    try {
      auditData['timestamp'] = DateTime.now().toIso8601String();
      await _firestore.collection('pharmacy_audit').add(auditData);
    } catch (e) {
      rethrow;
    }
  }

  /// Add a new treatment record
  Future<void> addTreatment(Map<String, dynamic> treatment, {String? businessId}) async {
    try {
      if (businessId == null) return;
      
      final data = {
        ...treatment,
        'businessId': businessId,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      
      final treatmentId = treatment['id'] as String?;
      if (treatmentId != null && treatmentId.isNotEmpty) {
        await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('treatments')
            .doc(treatmentId)
            .set(data, SetOptions(merge: true));
      } else {
        await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('treatments')
            .add(data);
      }
    } catch (e) {
      rethrow;
    }
  }
}

