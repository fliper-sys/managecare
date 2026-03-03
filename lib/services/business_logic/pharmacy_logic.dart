import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/datetime_utils.dart';

/// Pharmacy-specific business logic
class PharmacyBusinessLogic {
  final FirebaseFirestore _firestore;

  PharmacyBusinessLogic({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Check for drug interactions
  Future<List<DrugInteraction>> checkDrugInteractions(
      List<String> drugIds, List<String> drugNames) async {
    try {
      final interactions = <DrugInteraction>[];
      for (int i = 0; i < drugIds.length; i++) {
        for (int j = i + 1; j < drugIds.length; j++) {
          // Check interactions database
          final doc = await _firestore
              .collection('drugInteractions')
              .doc('${drugIds[i]}_${drugIds[j]}')
              .get();

          if (doc.exists) {
            interactions.add(DrugInteraction.fromMap(doc.data()!));
          }
        }
      }
      return interactions;
    } catch (e) {
      print('Error checking drug interactions: $e');
      return [];
    }
  }

  /// Track medication expiry
  Future<List<ExpiringMedication>> getExpiringMedications(
      String businessId, int daysThreshold) async {
    try {
      final threshold = DateTime.now().add(Duration(days: daysThreshold));
      final snap = await _firestore
          .collection('pharmacy')
          .doc(businessId)
          .collection('inventory')
          .where('expiryDate', isLessThanOrEqualTo: threshold)
          .where('expiryDate', isGreaterThan: DateTime.now())
          .orderBy('expiryDate')
          .get();

      return snap.docs
          .map((doc) =>
              ExpiringMedication.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching expiring medications: $e');
      return [];
    }
  }

  /// Generate prescription report
  Future<PrescriptionReport> generatePrescriptionReport(
      String businessId, DateTime startDate, DateTime endDate) async {
    try {
      final snap = await _firestore
          .collection('pharmacy')
          .doc(businessId)
          .collection('prescriptions')
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThanOrEqualTo: endDate)
          .get();

      double totalRevenue = 0;
      int totalPrescriptions = 0;
      final frequentDrugs = <String, int>{};

      for (var doc in snap.docs) {
        final data = doc.data();
        totalRevenue += (data['amount'] as num?)?.toDouble() ?? 0;
        totalPrescriptions++;

        final items = data['items'] as List?;
        if (items != null) {
          for (var item in items) {
            final drugId = item['drugId'] as String?;
            if (drugId != null) {
              frequentDrugs[drugId] = (frequentDrugs[drugId] ?? 0) + 1;
            }
          }
        }
      }

      return PrescriptionReport(
        totalPrescriptions: totalPrescriptions,
        totalRevenue: totalRevenue,
        frequentDrugs: frequentDrugs,
        period: 'Custom Period',
      );
    } catch (e) {
      print('Error generating prescription report: $e');
      return PrescriptionReport(
        totalPrescriptions: 0,
        totalRevenue: 0,
        frequentDrugs: {},
        period: 'Error',
      );
    }
  }
}

class DrugInteraction {
  final String drug1Id;
  final String drug2Id;
  final String severity; // mild, moderate, severe
  final String description;

  DrugInteraction({
    required this.drug1Id,
    required this.drug2Id,
    required this.severity,
    required this.description,
  });

  factory DrugInteraction.fromMap(Map<String, dynamic> map) {
    return DrugInteraction(
      drug1Id: map['drug1Id'] ?? '',
      drug2Id: map['drug2Id'] ?? '',
      severity: map['severity'] ?? 'mild',
      description: map['description'] ?? '',
    );
  }
}

class ExpiringMedication {
  final String id;
  final String name;
  final DateTime expiryDate;
  final int daysUntilExpiry;
  final int stock;

  ExpiringMedication({
    required this.id,
    required this.name,
    required this.expiryDate,
    required this.daysUntilExpiry,
    required this.stock,
  });

  factory ExpiringMedication.fromMap(Map<String, dynamic> map) {
    final expiryDate = map['expiryDate'] != null ? parseTimestamp(map['expiryDate']) : null;
    final daysUntilExpiry = expiryDate != null ? expiryDate.difference(DateTime.now()).inDays : 0;

    return ExpiringMedication(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      expiryDate: expiryDate ?? DateTime.now(),
      daysUntilExpiry: daysUntilExpiry,
      stock: map['stock'] ?? 0,
    );
  }
}

class PrescriptionReport {
  final int totalPrescriptions;
  final double totalRevenue;
  final Map<String, int> frequentDrugs;
  final String period;

  PrescriptionReport({
    required this.totalPrescriptions,
    required this.totalRevenue,
    required this.frequentDrugs,
    required this.period,
  });
}

