import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/datetime_utils.dart';

/// Agriculture-specific business logic
class AgricultureBusinessLogic {
  final FirebaseFirestore _firestore;

  AgricultureBusinessLogic({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get crop health status
  Future<List<CropHealth>> getCropHealthStatus(
    String businessId,
    String farmId,
  ) async {
    try {
      final snap = await _firestore
          .collection('agriculture')
          .doc(businessId)
          .collection('crops')
          .where('farmId', isEqualTo: farmId)
          .get();

      return snap.docs
          .map((doc) => CropHealth.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting crop health: $e');
      return [];
    }
  }

  /// Predict harvest time
  Future<HarvestPrediction> predictHarvestTime(
    String businessId,
    String cropId,
  ) async {
    try {
      final doc = await _firestore
          .collection('agriculture')
          .doc(businessId)
          .collection('crops')
          .doc(cropId)
          .get();

      final data = doc.data();
      final plantedDate = parseTimestamp(data?['plantedDate']);
      final growthDays = data?['averageGrowthDays'] ?? 90;

      final harvestDate = plantedDate.add(Duration(days: growthDays));
      final daysUntilHarvest =
          harvestDate.difference(DateTime.now()).inDays;
      final readiness =
          ((100 - (daysUntilHarvest / growthDays * 100))).clamp(0, 100).toInt();

      return HarvestPrediction(
        cropId: cropId,
        harvestDate: harvestDate,
        daysUntilHarvest: daysUntilHarvest,
        readiness: readiness,
        recommendedAction:
            readiness > 90 ? 'Ready to harvest' : 'Continue monitoring',
      );
    } catch (e) {
      print('Error predicting harvest: $e');
      return HarvestPrediction(
        cropId: cropId,
        harvestDate: DateTime.now(),
        daysUntilHarvest: 0,
        readiness: 0,
        recommendedAction: 'Error',
      );
    }
  }

  /// Track livestock health
  Future<List<LivestockRecord>> getLivestockHealthRecords(
    String businessId,
    String livestockId,
  ) async {
    try {
      final snap = await _firestore
          .collection('agriculture')
          .doc(businessId)
          .collection('livestock')
          .doc(livestockId)
          .collection('health')
          .orderBy('date', descending: true)
          .limit(10)
          .get();

      return snap.docs
          .map((doc) => LivestockRecord.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting livestock records: $e');
      return [];
    }
  }

  /// Calculate yield projection
  Future<YieldProjection> calculateYieldProjection(
    String businessId,
    String farmId,
    String cropType,
  ) async {
    try {
      final snap = await _firestore
          .collection('agriculture')
          .doc(businessId)
          .collection('crops')
          .where('farmId', isEqualTo: farmId)
          .where('type', isEqualTo: cropType)
          .get();

      double totalExpectedYield = 0;
      int cropCount = 0;

      for (var doc in snap.docs) {
        final data = doc.data();
        final expectedYield =
            (data['expectedYieldPerUnit'] as num?)?.toDouble() ?? 0;
        final unitsPlanted = data['unitsPlanted'] ?? 1;
        totalExpectedYield += expectedYield * unitsPlanted;
        cropCount++;
      }

      return YieldProjection(
        cropType: cropType,
        totalExpectedYield: totalExpectedYield,
        cropCount: cropCount,
        avgYieldPerCrop: cropCount > 0 ? totalExpectedYield / cropCount : 0,
        projectionDate: DateTime.now(),
      );
    } catch (e) {
      print('Error calculating yield: $e');
      return YieldProjection(
        cropType: cropType,
        totalExpectedYield: 0,
        cropCount: 0,
        avgYieldPerCrop: 0,
        projectionDate: DateTime.now(),
      );
    }
  }

  /// Get weather-based recommendations
  Future<List<String>> getWeatherRecommendations(
    String businessId,
    String farmId,
  ) async {
    try {
      // This would integrate with weather API
      final recommendations = <String>[
        'Check soil moisture levels regularly',
        'Monitor for pest activity',
        'Ensure proper drainage during rainy season',
        'Apply fertilizer as per schedule',
        'Check for crop diseases',
      ];

      return recommendations;
    } catch (e) {
      print('Error getting recommendations: $e');
      return [];
    }
  }
}

class CropHealth {
  final String id;
  final String type;
  final String healthStatus; // healthy, at-risk, diseased
  final int healthScore; // 0-100
  final String lastInspection;
  final List<String> issues;

  CropHealth({
    required this.id,
    required this.type,
    required this.healthStatus,
    required this.healthScore,
    required this.lastInspection,
    required this.issues,
  });

  factory CropHealth.fromMap(Map<String, dynamic> map) {
    return CropHealth(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      healthStatus: map['healthStatus'] ?? 'unknown',
      healthScore: map['healthScore'] ?? 50,
      lastInspection: map['lastInspection'] ?? 'Never',
      issues: List<String>.from(map['issues'] ?? []),
    );
  }
}

class HarvestPrediction {
  final String cropId;
  final DateTime harvestDate;
  final int daysUntilHarvest;
  final int readiness; // 0-100
  final String recommendedAction;

  HarvestPrediction({
    required this.cropId,
    required this.harvestDate,
    required this.daysUntilHarvest,
    required this.readiness,
    required this.recommendedAction,
  });
}

class LivestockRecord {
  final String id;
  final DateTime date;
  final String healthStatus;
  final double weight;
  final String notes;

  LivestockRecord({
    required this.id,
    required this.date,
    required this.healthStatus,
    required this.weight,
    required this.notes,
  });

  factory LivestockRecord.fromMap(Map<String, dynamic> map) {
      return LivestockRecord(
      id: map['id'] ?? '',
      date: parseTimestamp(map['date']),
      healthStatus: map['healthStatus'] ?? 'unknown',
      weight: (map['weight'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] ?? '',
    );
  }
}

class YieldProjection {
  final String cropType;
  final double totalExpectedYield;
  final int cropCount;
  final double avgYieldPerCrop;
  final DateTime projectionDate;

  YieldProjection({
    required this.cropType,
    required this.totalExpectedYield,
    required this.cropCount,
    required this.avgYieldPerCrop,
    required this.projectionDate,
  });
}

