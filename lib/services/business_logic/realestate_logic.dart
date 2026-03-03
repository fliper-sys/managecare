import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/datetime_utils.dart';

/// Real Estate-specific business logic
class RealEstateBusinessLogic {
  final FirebaseFirestore _firestore;

  RealEstateBusinessLogic({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get property lease status
  Future<LeaseStatus> getLeaseStatus(
    String businessId,
    String propertyId,
  ) async {
    try {
      final leaseSnap = await _firestore
          .collection('realEstate')
          .doc(businessId)
          .collection('leases')
          .where('propertyId', isEqualTo: propertyId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (leaseSnap.docs.isEmpty) {
        return LeaseStatus(
          status: 'vacant',
          daysUntilExpiry: null,
          monthlyRent: 0,
          nextPaymentDate: null,
        );
      }

      final leaseData = leaseSnap.docs.first.data();
        final expiryDate = leaseData['expiryDate'] != null ? parseTimestamp(leaseData['expiryDate']) : null;
        final daysUntilExpiry = expiryDate != null ? expiryDate.difference(DateTime.now()).inDays : 0;

      return LeaseStatus(
        status: 'occupied',
        daysUntilExpiry: daysUntilExpiry,
        monthlyRent: (leaseData['monthlyRent'] as num?)?.toDouble() ?? 0,
        nextPaymentDate: leaseData['nextPaymentDate'] != null ? parseTimestamp(leaseData['nextPaymentDate']) : null,
      );
    } catch (e) {
      print('Error getting lease status: $e');
      return LeaseStatus(
        status: 'error',
        daysUntilExpiry: null,
        monthlyRent: 0,
        nextPaymentDate: null,
      );
    }
  }

  /// Get maintenance requests for property
  Future<List<MaintenanceRequest>> getMaintenanceRequests(
    String businessId,
    String propertyId,
  ) async {
    try {
      final snap = await _firestore
          .collection('realEstate')
          .doc(businessId)
          .collection('maintenance')
          .where('propertyId', isEqualTo: propertyId)
          .where('status', isNotEqualTo: 'completed')
          .orderBy('priority', descending: true)
          .orderBy('createdAt', descending: true)
          .get();

      return snap.docs
          .map((doc) =>
              MaintenanceRequest.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting maintenance requests: $e');
      return [];
    }
  }

  /// Create a maintenance request
  Future<MaintenanceRequest?> createMaintenanceRequest(
      String businessId, String propertyId, String description,
      {String priority = 'medium', String? assignedProviderId, String? assignedProviderName}) async {
    try {
      final collection = _firestore
          .collection('realEstate')
          .doc(businessId)
          .collection('maintenance');
      final docRef = collection.doc();
      final now = DateTime.now();
      final data = {
        'propertyId': propertyId,
        'description': description,
        'priority': priority,
        'status': 'pending',
        'createdAt': now,
        'assignedProviderId': assignedProviderId,
        'assignedProviderName': assignedProviderName,
      };
      await docRef.set(data);
      final created = MaintenanceRequest.fromMap({...data, 'id': docRef.id});
      return created;
    } catch (e) {
      print('Error creating maintenance request: $e');
      return null;
    }
  }

  /// Get registered service providers for the business
  Future<List<ServiceProvider>> getServiceProviders(
    String businessId,
  ) async {
    try {
      final snap = await _firestore
          .collection('realEstate')
          .doc(businessId)
          .collection('serviceProviders')
          .orderBy('name')
          .get();

      return snap.docs
          .map((doc) => ServiceProvider.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting service providers: $e');
      return [];
    }
  }

  /// Calculate occupancy rates and revenue projections
  Future<PropertyAnalytics> getPropertyAnalytics(
    String businessId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final propertiesSnap = await _firestore
          .collection('realEstate')
          .doc(businessId)
          .collection('properties')
          .get();

      int occupiedCount = 0;
      int totalProperties = propertiesSnap.docs.length;
      double totalMonthlyRevenue = 0;

      for (var propertyDoc in propertiesSnap.docs) {
        final leaseSnap = await _firestore
            .collection('realEstate')
            .doc(businessId)
            .collection('leases')
            .where('propertyId', isEqualTo: propertyDoc.id)
            .where('status', isEqualTo: 'active')
            .limit(1)
            .get();

        if (leaseSnap.docs.isNotEmpty) {
          occupiedCount++;
          final rent = (leaseSnap.docs.first.data()['monthlyRent'] as num?)
                  ?.toDouble() ??
              0;
          totalMonthlyRevenue += rent;
        }
      }

      final occupancyRate = totalProperties > 0
          ? ((occupiedCount / totalProperties) * 100).toStringAsFixed(1)
          : '0';

      // Get payment history
      final paymentsSnap = await _firestore
          .collection('realEstate')
          .doc(businessId)
          .collection('payments')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .get();

      double collectedRevenue = 0;
      for (var paymentDoc in paymentsSnap.docs) {
        collectedRevenue +=
            (paymentDoc.data()['amount'] as num?)?.toDouble() ?? 0;
      }

      return PropertyAnalytics(
        totalProperties: totalProperties,
        occupiedProperties: occupiedCount,
        occupancyRate: occupancyRate,
        projectedMonthlyRevenue: totalMonthlyRevenue,
        collectedRevenue: collectedRevenue,
        outstandingPayments: totalMonthlyRevenue - collectedRevenue,
      );
    } catch (e) {
      print('Error calculating property analytics: $e');
      return PropertyAnalytics(
        totalProperties: 0,
        occupiedProperties: 0,
        occupancyRate: '0',
        projectedMonthlyRevenue: 0,
        collectedRevenue: 0,
        outstandingPayments: 0,
      );
    }
  }

  /// Track tenant payment history
  Future<TenantPaymentHistory> getTenantPaymentHistory(
    String businessId,
    String tenantId,
  ) async {
    try {
      final paymentsSnap = await _firestore
          .collection('realEstate')
          .doc(businessId)
          .collection('payments')
          .where('tenantId', isEqualTo: tenantId)
          .orderBy('date', descending: true)
          .limit(12)
          .get();

      double totalPaid = 0;
      double totalOverdue = 0;
      int missedPayments = 0;

      final payments = <PaymentRecord>[];
      for (var doc in paymentsSnap.docs) {
        final data = doc.data();
        final payment = PaymentRecord.fromMap(data);
        payments.add(payment);
        totalPaid += payment.amount;

        if (payment.status == 'overdue') {
          totalOverdue += payment.amount;
          missedPayments++;
        }
      }

      return TenantPaymentHistory(
        tenantId: tenantId,
        totalPaid: totalPaid,
        totalOverdue: totalOverdue,
        missedPayments: missedPayments,
        paymentRecords: payments,
        lastPaymentDate: payments.isNotEmpty ? payments.first.date : null,
      );
    } catch (e) {
      print('Error getting tenant payment history: $e');
      return TenantPaymentHistory(
        tenantId: tenantId,
        totalPaid: 0,
        totalOverdue: 0,
        missedPayments: 0,
        paymentRecords: [],
      );
    }
  }
}

class LeaseStatus {
  final String status; // active, vacant, expiring_soon
  final int? daysUntilExpiry;
  final double monthlyRent;
  final DateTime? nextPaymentDate;

  LeaseStatus({
    required this.status,
    this.daysUntilExpiry,
    required this.monthlyRent,
    this.nextPaymentDate,
  });
}

class MaintenanceRequest {
  final String id;
  final String propertyId;
  final String description;
  final String priority; // low, medium, high, urgent
  final String status; // pending, in-progress, completed
  final DateTime createdAt;
  final DateTime? completedAt;
  final double? estimatedCost;
  final String? assignedProviderId;
  final String? assignedProviderName;

  MaintenanceRequest({
    required this.id,
    required this.propertyId,
    required this.description,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.estimatedCost,
    this.assignedProviderId,
    this.assignedProviderName,
  });

  factory MaintenanceRequest.fromMap(Map<String, dynamic> map) {
    return MaintenanceRequest(
      id: map['id'] ?? '',
      propertyId: map['propertyId'] ?? '',
      description: map['description'] ?? '',
      priority: map['priority'] ?? 'medium',
      status: map['status'] ?? 'pending',
      createdAt: parseTimestamp(map['createdAt']),
      completedAt: map['completedAt'] != null ? parseTimestamp(map['completedAt']) : null,
      estimatedCost: (map['estimatedCost'] as num?)?.toDouble(),
      assignedProviderId: (map['assignedProviderId'] as String?)?.toString(),
      assignedProviderName: (map['assignedProviderName'] as String?)?.toString(),
    );
  }
}

/// Basic representation of a service provider/vendor for maintenance
class ServiceProvider {
  final String id;
  final String name;
  final String? contact;
  final String? phone;
  final List<String>? services;

  ServiceProvider({
    required this.id,
    required this.name,
    this.contact,
    this.phone,
    this.services,
  });

  factory ServiceProvider.fromMap(Map<String, dynamic> map) {
    return ServiceProvider(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      contact: map['contact'] as String?,
      phone: map['phone'] as String?,
      services: (map['services'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }
}

  

class PropertyAnalytics {
  final int totalProperties;
  final int occupiedProperties;
  final String occupancyRate;
  final double projectedMonthlyRevenue;
  final double collectedRevenue;
  final double outstandingPayments;

  PropertyAnalytics({
    required this.totalProperties,
    required this.occupiedProperties,
    required this.occupancyRate,
    required this.projectedMonthlyRevenue,
    required this.collectedRevenue,
    required this.outstandingPayments,
  });
}

class TenantPaymentHistory {
  final String tenantId;
  final double totalPaid;
  final double totalOverdue;
  final int missedPayments;
  final List<PaymentRecord> paymentRecords;
  final DateTime? lastPaymentDate;

  TenantPaymentHistory({
    required this.tenantId,
    required this.totalPaid,
    required this.totalOverdue,
    required this.missedPayments,
    required this.paymentRecords,
    this.lastPaymentDate,
  });
}

class PaymentRecord {
  final DateTime date;
  final double amount;
  final String status; // completed, pending, overdue
  final String method;

  PaymentRecord({
    required this.date,
    required this.amount,
    required this.status,
    required this.method,
  });

  factory PaymentRecord.fromMap(Map<String, dynamic> map) {
    return PaymentRecord(
      date: parseTimestamp(map['date']),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      status: map['status'] ?? 'pending',
      method: map['method'] ?? 'unknown',
    );
  }
}
