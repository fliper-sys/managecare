import 'package:cloud_firestore/cloud_firestore.dart';
import 'booking_repository.dart';
import '../models/booking_model.dart';

class BookingRepositoryImpl implements BookingRepository {
  final FirebaseFirestore _firestore;

  BookingRepositoryImpl({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference _bookingsRef(String businessId) => _firestore.collection('businesses').doc(businessId).collection('bookings');

  @override
  Future<String> createBooking({
    required String businessId,
    required Booking booking,
    bool requirePayment = false,
  }) async {
    // Requires a transaction to check for overlaps and then create booking atomically
    final bookingsRef = _bookingsRef(businessId);

    return await _firestore.runTransaction((tx) async {
      // Query existing bookings for the same unit with conflicting statuses
      final snapshot = await bookingsRef.where('unitId', isEqualTo: booking.unitId).get();

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final existingCheckIn = data['checkInDate'] as Timestamp?;
        final existingCheckOut = data['checkOutDate'] as Timestamp?;
        final status = (data['status'] ?? 'pending') as String;
        if (existingCheckIn == null || existingCheckOut == null) continue;
        if (['pending', 'confirmed', 'checkedIn'].contains(status)) {
          final a = existingCheckIn.toDate();
          final b = existingCheckOut.toDate();
          final requestedStart = booking.checkInDate.toUtc();
          final requestedEnd = booking.checkOutDate.toUtc();
          final overlaps = requestedStart.isBefore(b) && requestedEnd.isAfter(a);
          if (overlaps) {
            throw Exception('Requested dates overlap with an existing booking');
          }
        }
      }

      // Add booking doc with initial status based on payment
      final docRef = bookingsRef.doc();
      final bookingData = booking.toFirestore();

      // If requirePayment is true and depositAmount>0 set payment status to pending and keep booking as pending
      if (requirePayment && booking.depositAmount > 0) {
        bookingData['paymentStatus'] = 'pending';
        bookingData['status'] = 'pending';
      } else if (requirePayment && booking.total > 0) {
        bookingData['paymentStatus'] = 'pending';
        bookingData['status'] = 'pending';
      } else {
        bookingData['paymentStatus'] = booking.paymentStatus.toString().split('.').last;
        bookingData['status'] = booking.status.toString().split('.').last;
      }

      tx.set(docRef, bookingData);

      return docRef.id;
    });
  }

  @override
  Future<bool> checkAvailability({required String businessId, required String unitId, required DateTime checkIn, required DateTime checkOut}) async {
    final bookingsRef = _bookingsRef(businessId);
    final snapshot = await bookingsRef.where('unitId', isEqualTo: unitId).get();

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final existingCheckIn = (data['checkInDate'] as Timestamp?)?.toDate();
      final existingCheckOut = (data['checkOutDate'] as Timestamp?)?.toDate();
      final status = (data['status'] ?? 'pending') as String;
      if (existingCheckIn == null || existingCheckOut == null) continue;
      if (['pending', 'confirmed', 'checkedIn'].contains(status)) {
        final overlaps = checkIn.isBefore(existingCheckOut) && checkOut.isAfter(existingCheckIn);
        if (overlaps) return false;
      }
    }

    return true;
  }

  @override
  Future<void> cancelBooking({required String businessId, required String bookingId, String? reason}) async {
    final bookingRef = _bookingsRef(businessId).doc(bookingId);
    await bookingRef.update({
      'status': 'cancelled',
      'cancelReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<Booking>> fetchBookings({required String businessId, String? apartmentId, String? unitId, int limit = 100}) async {
    Query q = _bookingsRef(businessId).orderBy('createdAt', descending: true).limit(limit);
    if (apartmentId != null) q = q.where('apartmentId', isEqualTo: apartmentId);
    if (unitId != null) q = q.where('unitId', isEqualTo: unitId);

    final snapshot = await q.get();
    return snapshot.docs.map((d) => Booking.fromFirestore(d)).toList();
  }

  @override
  Future<Booking?> getBooking({required String businessId, required String bookingId}) async {
    final doc = await _bookingsRef(businessId).doc(bookingId).get();
    if (!doc.exists) return null;
    return Booking.fromFirestore(doc);
  }

  @override
  Future<void> updateBookingStatus({required String businessId, required String bookingId, required String status, Map<String, dynamic>? updates}) async {
    final bookingRef = _bookingsRef(businessId).doc(bookingId);
    final payload = {'status': status, 'updatedAt': FieldValue.serverTimestamp()};
    if (updates != null) {
      updates.forEach((k, v) {
        payload[k] = v;
      });
    }
    await bookingRef.update(payload);
  }
}
