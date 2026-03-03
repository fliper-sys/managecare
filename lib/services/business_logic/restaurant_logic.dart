import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/datetime_utils.dart';

/// Restaurant & Bar-specific business logic
class RestaurantBusinessLogic {
  final FirebaseFirestore _firestore;

  RestaurantBusinessLogic({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get current queue status
  Future<QueueStatus> getCurrentQueueStatus(String businessId) async {
    try {
      final snap = await _firestore
          .collection('restaurant')
          .doc(businessId)
          .collection('queue')
          .where('status', isNotEqualTo: 'completed')
          .orderBy('arrivalTime')
          .get();

      int estimatedWaitTime = 0;
      final queue = <QueueEntry>[];

      for (var i = 0; i < snap.docs.length; i++) {
        final doc = snap.docs[i];
        final data = doc.data();
        queue.add(QueueEntry.fromMap({...data, 'id': doc.id}));
        estimatedWaitTime += (data['avgServiceTime'] as num?)?.toInt() ?? 15;
      }

      return QueueStatus(
        totalInQueue: queue.length,
        estimatedWaitTimeMinutes: estimatedWaitTime,
        queue: queue,
        isOpen: await _isBusinessOpen(businessId),
      );
    } catch (e) {
      print('Error getting queue status: $e');
      return QueueStatus(
        totalInQueue: 0,
        estimatedWaitTimeMinutes: 0,
        queue: [],
        isOpen: false,
      );
    }
  }

  /// Recommend menu items based on popularity and ratings
  Future<List<MenuRecommendation>> getMenuRecommendations(
      String businessId, String customerId) async {
    try {
      final snap = await _firestore
          .collection('restaurant')
          .doc(businessId)
          .collection('menuItems')
          .orderBy('orderCount', descending: true)
          .orderBy('rating', descending: true)
          .limit(10)
          .get();

      return snap.docs
          .map((doc) =>
              MenuRecommendation.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting menu recommendations: $e');
      return [];
    }
  }

  /// Calculate peak hours
  Future<PeakHoursAnalysis> analyzePeakHours(
      String businessId, DateTime startDate, DateTime endDate) async {
    try {
      final snap = await _firestore
          .collection('restaurant')
          .doc(businessId)
          .collection('sales')
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThanOrEqualTo: endDate)
          .get();

      final hourlyStats = <int, HourlyData>{};

      for (var doc in snap.docs) {
        final data = doc.data();
        final timestamp = parseTimestamp(data['createdAt']);

        final hour = timestamp.hour;
        if (hourlyStats[hour] == null) {
          hourlyStats[hour] = HourlyData(
            hour: hour,
            orderCount: 0,
            totalRevenue: 0,
            avgOrderValue: 0,
          );
        }
        hourlyStats[hour]!.orderCount++;
        hourlyStats[hour]!.totalRevenue += (data['total'] as num?)?.toDouble() ?? 0;
      }

      // Calculate averages
      for (var data in hourlyStats.values) {
        data.avgOrderValue =
            data.orderCount > 0 ? data.totalRevenue / data.orderCount : 0;
      }

      final sortedHours = hourlyStats.values.toList()
        ..sort((a, b) => b.orderCount.compareTo(a.orderCount));

      return PeakHoursAnalysis(
        peakHours: sortedHours.take(3).toList(),
        slowHours: sortedHours.reversed.take(2).toList().reversed.toList(),
        averageOrdersPerHour:
            sortedHours.fold(0, (sum, h) => sum + h.orderCount) ~/ 24,
      );
    } catch (e) {
      print('Error analyzing peak hours: $e');
      return PeakHoursAnalysis(
        peakHours: [],
        slowHours: [],
        averageOrdersPerHour: 0,
      );
    }
  }

  /// Manage table reservations
  Future<List<TableReservation>> getTableReservations(
      String businessId, DateTime date) async {
    try {
      final nextDay = date.add(const Duration(days: 1));
      final snap = await _firestore
          .collection('restaurant')
          .doc(businessId)
          .collection('reservations')
          .where('reservationDate', isGreaterThanOrEqualTo: date)
          .where('reservationDate', isLessThan: nextDay)
          .orderBy('reservationDate')
          .get();

      return snap.docs
          .map((doc) => TableReservation.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting table reservations: $e');
      return [];
    }
  }

  Future<bool> _isBusinessOpen(String businessId) async {
    try {
      final doc = await _firestore.collection('business').doc(businessId).get();
      return doc.data()?['isOpen'] ?? false;
    } catch (e) {
      return false;
    }
  }
}

class QueueEntry {
  final String id;
  final String guestName;
  final int partySize;
  final DateTime arrivalTime;
  final String status;
  final int avgServiceTime;

  QueueEntry({
    required this.id,
    required this.guestName,
    required this.partySize,
    required this.arrivalTime,
    required this.status,
    required this.avgServiceTime,
  });

  factory QueueEntry.fromMap(Map<String, dynamic> map) {
    return QueueEntry(
      id: map['id'] ?? '',
      guestName: map['guestName'] ?? 'Guest',
      partySize: map['partySize'] ?? 1,
        arrivalTime: parseTimestamp(map['arrivalTime']),
      status: map['status'] ?? 'waiting',
      avgServiceTime: map['avgServiceTime'] ?? 15,
    );
  }
}

class QueueStatus {
  final int totalInQueue;
  final int estimatedWaitTimeMinutes;
  final List<QueueEntry> queue;
  final bool isOpen;

  QueueStatus({
    required this.totalInQueue,
    required this.estimatedWaitTimeMinutes,
    required this.queue,
    required this.isOpen,
  });
}

class MenuRecommendation {
  final String id;
  final String name;
  final double price;
  final double rating;
  final int orderCount;

  MenuRecommendation({
    required this.id,
    required this.name,
    required this.price,
    required this.rating,
    required this.orderCount,
  });

  factory MenuRecommendation.fromMap(Map<String, dynamic> map) {
    return MenuRecommendation(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      orderCount: map['orderCount'] ?? 0,
    );
  }
}

class PeakHoursAnalysis {
  final List<HourlyData> peakHours;
  final List<HourlyData> slowHours;
  final int averageOrdersPerHour;

  PeakHoursAnalysis({
    required this.peakHours,
    required this.slowHours,
    required this.averageOrdersPerHour,
  });
}

class HourlyData {
  final int hour;
  int orderCount;
  double totalRevenue;
  double avgOrderValue;

  HourlyData({
    required this.hour,
    required this.orderCount,
    required this.totalRevenue,
    required this.avgOrderValue,
  });
}

class TableReservation {
  final String id;
  final String guestName;
  final String guestPhone;
  final DateTime reservationDate;
  final int partySize;
  final String? specialRequests;
  final String status;

  TableReservation({
    required this.id,
    required this.guestName,
    required this.guestPhone,
    required this.reservationDate,
    required this.partySize,
    this.specialRequests,
    required this.status,
  });

  factory TableReservation.fromMap(Map<String, dynamic> map) {
    return TableReservation(
      id: map['id'] ?? '',
      guestName: map['guestName'] ?? 'Guest',
      guestPhone: map['guestPhone'] ?? '',
        reservationDate: parseTimestamp(map['reservationDate']),
      partySize: map['partySize'] ?? 1,
      specialRequests: map['specialRequests'],
      status: map['status'] ?? 'pending',
    );
  }
}

