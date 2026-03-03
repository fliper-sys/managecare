import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/datetime_utils.dart';

/// Auto Repair Shop-specific business logic
class AutoRepairBusinessLogic {
  final FirebaseFirestore _firestore;

  AutoRepairBusinessLogic({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get vehicle service history
  Future<List<ServiceRecord>> getVehicleServiceHistory(
    String businessId,
    String vehicleId,
  ) async {
    try {
      final snap = await _firestore
          .collection('autoRepair')
          .doc(businessId)
          .collection('serviceRecords')
          .where('vehicleId', isEqualTo: vehicleId)
          .orderBy('date', descending: true)
          .get();

      return snap.docs
          .map((doc) => ServiceRecord.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting service history: $e');
      return [];
    }
  }

  /// Calculate maintenance schedule
  Future<MaintenanceSchedule> calculateMaintenanceSchedule(
    String businessId,
    String vehicleId,
  ) async {
    try {
      final history = await getVehicleServiceHistory(businessId, vehicleId);

      final lastOilChange =
          history.firstWhere((r) => r.serviceType == 'oil_change').date;
      final nextOilChangeDue = lastOilChange.add(const Duration(days: 180));

      final daysUntilOilChange =
          nextOilChangeDue.difference(DateTime.now()).inDays;

      return MaintenanceSchedule(
        vehicleId: vehicleId,
        nextOilChangeDue: nextOilChangeDue,
        daysUntilOilChange: daysUntilOilChange,
        maintenanceItems: [
          MaintenanceItem(
            name: 'Oil Change',
            daysUntilDue: daysUntilOilChange,
            estimatedCost: 45.0,
            priority: daysUntilOilChange < 30 ? 'high' : 'normal',
          ),
        ],
      );
    } catch (e) {
      print('Error calculating maintenance schedule: $e');
      return MaintenanceSchedule(
        vehicleId: vehicleId,
        nextOilChangeDue: DateTime.now(),
        daysUntilOilChange: 180,
        maintenanceItems: [],
      );
    }
  }

  /// Estimate repair cost
  Future<RepairEstimate> estimateRepairCost(
    String businessId,
    List<String> repairTypes,
  ) async {
    try {
      double laborCost = 0;
      double partsCost = 0;

      for (var repairType in repairTypes) {
        final doc = await _firestore
            .collection('autoRepair')
            .doc(businessId)
            .collection('repairTypes')
            .doc(repairType)
            .get();

        if (doc.exists) {
          laborCost += (doc.data()?['laborCost'] as num?)?.toDouble() ?? 0;
          partsCost += (doc.data()?['partsCost'] as num?)?.toDouble() ?? 0;
        }
      }

      final totalCost = laborCost + partsCost;
      final tax = totalCost * 0.1; // 10% tax
      final total = totalCost + tax;

      return RepairEstimate(
        laborCost: laborCost,
        partsCost: partsCost,
        tax: tax,
        totalEstimate: total,
        estimateValidDays: 30,
      );
    } catch (e) {
      print('Error estimating repair cost: $e');
      return RepairEstimate(
        laborCost: 0,
        partsCost: 0,
        tax: 0,
        totalEstimate: 0,
        estimateValidDays: 30,
      );
    }
  }

  /// Track job progress
  Future<List<JobStatus>> getActiveJobs(String businessId) async {
    try {
      final snap = await _firestore
          .collection('autoRepair')
          .doc(businessId)
          .collection('jobs')
          .where('status', isNotEqualTo: 'completed')
          .orderBy('priority', descending: true)
          .orderBy('createdAt', descending: true)
          .get();

      return snap.docs
          .map((doc) => JobStatus.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting active jobs: $e');
      return [];
    }
  }
}

class ServiceRecord {
  final String id;
  final String vehicleId;
  final DateTime date;
  final String serviceType;
  final String description;
  final double cost;
  final int mileage;

  ServiceRecord({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.serviceType,
    required this.description,
    required this.cost,
    required this.mileage,
  });

  factory ServiceRecord.fromMap(Map<String, dynamic> map) {
    return ServiceRecord(
      id: map['id'] ?? '',
      vehicleId: map['vehicleId'] ?? '',
      date: parseTimestamp(map['date']),
      serviceType: map['serviceType'] ?? '',
      description: map['description'] ?? '',
      cost: (map['cost'] as num?)?.toDouble() ?? 0,
      mileage: map['mileage'] ?? 0,
    );
  }
}

class MaintenanceSchedule {
  final String vehicleId;
  final DateTime nextOilChangeDue;
  final int daysUntilOilChange;
  final List<MaintenanceItem> maintenanceItems;

  MaintenanceSchedule({
    required this.vehicleId,
    required this.nextOilChangeDue,
    required this.daysUntilOilChange,
    required this.maintenanceItems,
  });
}

class MaintenanceItem {
  final String name;
  final int daysUntilDue;
  final double estimatedCost;
  final String priority;

  MaintenanceItem({
    required this.name,
    required this.daysUntilDue,
    required this.estimatedCost,
    required this.priority,
  });
}

class RepairEstimate {
  final double laborCost;
  final double partsCost;
  final double tax;
  final double totalEstimate;
  final int estimateValidDays;

  RepairEstimate({
    required this.laborCost,
    required this.partsCost,
    required this.tax,
    required this.totalEstimate,
    required this.estimateValidDays,
  });
}

class JobStatus {
  final String id;
  final String vehicleId;
  final String description;
  final String status; // pending, in-progress, completed, on-hold
  final String priority; // low, normal, high, urgent
  final DateTime createdAt;
  final DateTime? completedAt;
  final double estimatedCost;

  JobStatus({
    required this.id,
    required this.vehicleId,
    required this.description,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.completedAt,
    required this.estimatedCost,
  });

  factory JobStatus.fromMap(Map<String, dynamic> map) {
    return JobStatus(
      id: map['id'] ?? '',
      vehicleId: map['vehicleId'] ?? '',
      description: map['description'] ?? '',
      status: map['status'] ?? 'pending',
      priority: map['priority'] ?? 'normal',
      createdAt: parseTimestamp(map['createdAt']),
      completedAt: map['completedAt'] != null ? parseTimestamp(map['completedAt']) : null,
      estimatedCost: (map['estimatedCost'] as num?)?.toDouble() ?? 0,
    );
  }
}

