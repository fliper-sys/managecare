import 'hotel_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;

/// Firestore-backed implementation of `HotelRepository`.
/// Implements basic fetch/write operations and small aggregations client-side.
class HotelRepositoryImpl implements HotelRepository {
  final fs.FirebaseFirestore firestore;

  HotelRepositoryImpl({fs.FirebaseFirestore? firestoreInstance})
      : firestore = firestoreInstance ?? fs.FirebaseFirestore.instance;

  @override
  Future<List<Map<String, dynamic>>> fetchRooms(String businessId) async {
    try {
      final snap = await firestore
          .collection('businesses')
          .doc(businessId)
          .collection('rooms')
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      // Log and return empty list so provider can use sample data
      // ignore: avoid_print
      print('Error fetching rooms: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> createRoom(Map<String, dynamic> room) async {
    try {
      final businessId = room['businessId'] as String?;
      final col = businessId != null
          ? firestore
              .collection('businesses')
              .doc(businessId)
              .collection('rooms')
          : firestore.collection('rooms');
      final docRef = col.doc();
      final data = Map<String, dynamic>.from(room);
      data['createdAt'] = fs.Timestamp.now();
      await docRef.set(data);
      return {'id': docRef.id, ...data};
    } catch (e) {
      // ignore: avoid_print
      print('Error creating room: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> createBooking(
      Map<String, dynamic> booking) async {
    try {
      final businessId = booking['businessId'] as String?;
      final col = businessId != null
          ? firestore
              .collection('businesses')
              .doc(businessId)
              .collection('reservations')
          : firestore.collection('bookings');
      final docRef = col.doc();
      final data = Map<String, dynamic>.from(booking);
      data['createdAt'] = fs.Timestamp.now();
      await docRef.set(data);
      return {'id': docRef.id, ...data};
    } catch (e) {
      // ignore: avoid_print
      print('Error creating booking: $e');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchGuests(String businessId) async {
    try {
      final snap = await firestore
          .collection('businesses')
          .doc(businessId)
          .collection('guests')
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching guests: $e');
      return [];
    }
  }

  /// Batch write reservations to Firestore (overwrites docs with provided ids or creates new)
  @override
  Future<void> syncReservations(
      String businessId, List<Map<String, dynamic>> reservations) async {
    if (reservations.isEmpty) return;
    final batch = firestore.batch();
    final col = firestore
        .collection('businesses')
        .doc(businessId)
        .collection('reservations');
    for (final res in reservations) {
      final id = res['id'] as String? ?? col.doc().id;
      final docRef = col.doc(id);
      final data = Map<String, dynamic>.from(res)
        ..removeWhere((k, v) => v == null);
      batch.set(docRef, data, fs.SetOptions(merge: true));
    }
    try {
      await batch.commit();
    } catch (e) {
      // ignore: avoid_print
      print('Error syncing reservations: $e');
      rethrow;
    }
  }

  /// Fetch reservations (maps Firestore docs to simple maps)
  @override
  Future<List<Map<String, dynamic>>> fetchReservations(
      String businessId) async {
    try {
      final snap = await firestore
          .collection('businesses')
          .doc(businessId)
          .collection('reservations')
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching reservations: $e');
      return [];
    }
  }

  @override
  Future<void> updateReservation(String businessId, String reservationId,
      Map<String, dynamic> updates) async {
    try {
      final doc = firestore
          .collection('businesses')
          .doc(businessId)
          .collection('reservations')
          .doc(reservationId);
      await doc.set(updates, fs.SetOptions(merge: true));
    } catch (e) {
      // ignore: avoid_print
      print('Error updating reservation: $e');
      rethrow;
    }
  }

  @override
  Future<void> cancelReservation(String businessId, String reservationId,
      {String? reason}) async {
    try {
      final doc = firestore
          .collection('businesses')
          .doc(businessId)
          .collection('reservations')
          .doc(reservationId);
      final payload = {'status': 'cancelled'};
      if (reason != null && reason.isNotEmpty) {
        payload['cancelReason'] = reason;
      }
      await doc.set(payload, fs.SetOptions(merge: true));
    } catch (e) {
      // ignore: avoid_print
      print('Error cancelling reservation: $e');
      rethrow;
    }
  }

  /// Batch update rooms collection (expects each room map to include 'id')
  Future<void> syncRoomUpdates(
      String businessId, List<Map<String, dynamic>> rooms) async {
    if (rooms.isEmpty) return;
    final batch = firestore.batch();
    final col =
        firestore.collection('businesses').doc(businessId).collection('rooms');
    for (final r in rooms) {
      final id = r['id'] as String?;
      if (id == null) continue;
      final docRef = col.doc(id);
      final data = Map<String, dynamic>.from(r)..remove('id');
      batch.set(docRef, data, fs.SetOptions(merge: true));
    }
    try {
      await batch.commit();
    } catch (e) {
      // ignore: avoid_print
      print('Error syncing room updates: $e');
      rethrow;
    }
  }

  /// Compute simple occupancy metrics by fetching room documents and counting statuses.
  Future<Map<String, dynamic>> getOccupancyMetrics(String businessId) async {
    try {
      final snap = await firestore
          .collection('businesses')
          .doc(businessId)
          .collection('rooms')
          .get();
      final total = snap.size;
      final occupied = snap.docs
          .where((d) => (d.data()['status'] ?? '') == 'occupied')
          .length;
      final occupancy = total == 0 ? 0 : (occupied / total) * 100;
      return {
        'occupancy': occupancy,
        'totalRooms': total,
        'occupiedRooms': occupied
      };
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching occupancy metrics: $e');
      return {'occupancy': 0, 'totalRooms': 0, 'occupiedRooms': 0};
    }
  }

  /// Sum revenue from reservations marked paid or partial
  Future<double> getRevenueData(String businessId) async {
    try {
      final snap = await firestore
          .collection('businesses')
          .doc(businessId)
          .collection('reservations')
          .get();
      double sum = 0.0;
      for (final d in snap.docs) {
        final data = d.data();
        final paymentStatus = data['paymentStatus'] as String? ?? '';
        if (paymentStatus == 'paid' || paymentStatus == 'partial') {
          final p = data['totalPrice'];
          if (p is num) sum += p.toDouble();
        }
      }
      return sum;
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching revenue data: $e');
      return 0.0;
    }
  }
}
