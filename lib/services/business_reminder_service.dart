import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

class BusinessReminderService {
  BusinessReminderService._internal();

  static final BusinessReminderService instance =
      BusinessReminderService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService.instance;

  static const List<_ReminderOffset> _appointmentReminderOffsets = [
    _ReminderOffset(key: '24h', duration: Duration(hours: 24)),
    _ReminderOffset(key: '3h', duration: Duration(hours: 3)),
    _ReminderOffset(key: '30m', duration: Duration(minutes: 30)),
  ];

  Future<void> scheduleSalonBookingReminders({
    required String businessId,
    required String appointmentId,
    required String clientName,
    required String serviceName,
    required String stylistName,
    required DateTime appointmentTime,
  }) async {
    await _scheduleTimedLocalReminders(
      businessId: businessId,
      entityId: appointmentId,
      when: appointmentTime,
      title: 'Salon Booking Reminder',
      bodyBuilder: (offset) {
        if (offset.key == '24h') {
          return '$clientName has $serviceName with $stylistName tomorrow.';
        }
        if (offset.key == '3h') {
          return '$clientName has $serviceName with $stylistName in about 3 hours.';
        }
        return '$clientName is due for $serviceName with $stylistName soon.';
      },
      offsets: _appointmentReminderOffsets,
    );
  }

  Future<void> scheduleBarberBookingReminders({
    required String businessId,
    required String appointmentId,
    required String clientName,
    required String serviceName,
    required String barberName,
    required DateTime appointmentTime,
  }) async {
    await _scheduleTimedLocalReminders(
      businessId: businessId,
      entityId: appointmentId,
      when: appointmentTime,
      title: 'Barber Booking Reminder',
      bodyBuilder: (offset) {
        if (offset.key == '24h') {
          return '$clientName has $serviceName with $barberName tomorrow.';
        }
        if (offset.key == '3h') {
          return '$clientName has $serviceName with $barberName in about 3 hours.';
        }
        return '$clientName is due for $serviceName with $barberName soon.';
      },
      offsets: _appointmentReminderOffsets,
    );
  }

  Future<void> scheduleHotelReservationReminders({
    required String businessId,
    required String reservationId,
    required String guestName,
    required String roomLabel,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    await _scheduleTimedLocalReminders(
      businessId: businessId,
      entityId: reservationId,
      when: checkIn,
      title: 'Hotel Arrival Reminder',
      bodyBuilder: (_) =>
          '$guestName is expected to arrive tomorrow for room $roomLabel.',
      offsets: const [
        _ReminderOffset(key: 'arrival_24h', duration: Duration(hours: 24)),
      ],
    );

    await _scheduleTimedLocalReminders(
      businessId: businessId,
      entityId: reservationId,
      when: checkOut,
      title: 'Checkout Reminder',
      bodyBuilder: (_) =>
          '$guestName in room $roomLabel should be ready for checkout in about 3 hours.',
      offsets: const [
        _ReminderOffset(key: 'checkout_3h', duration: Duration(hours: 3)),
      ],
    );

    final overdueTime = checkOut.add(const Duration(minutes: 15));
    if (overdueTime.isAfter(DateTime.now())) {
      try {
        await _notificationService.scheduleNotificationAt(
          id: _stableNotificationId(
            'hotel_overdue',
            businessId,
            reservationId,
            '15m',
          ),
          title: 'Checkout Overdue',
          body: '$guestName in room $roomLabel has passed checkout time.',
          at: overdueTime,
        );
      } catch (e) {
        debugPrint('[BusinessReminderService] overdue schedule failed: $e');
      }
    }
  }

  Future<void> syncBusinessReminders({
    required String businessId,
    required String businessName,
    required String businessType,
    required String currentUserId,
    String? ownerUserId,
  }) async {
    final normalizedType = businessType.trim().toLowerCase();

    try {
      if (normalizedType == 'salon') {
        await _syncSalonReminders(
          businessId: businessId,
          businessName: businessName,
          currentUserId: currentUserId,
          ownerUserId: ownerUserId,
        );
      } else if (normalizedType == 'barbershop' ||
          normalizedType == 'barber') {
        await _syncBarberReminders(
          businessId: businessId,
          businessName: businessName,
          currentUserId: currentUserId,
          ownerUserId: ownerUserId,
        );
      } else if (normalizedType == 'hotel') {
        await _syncHotelReminders(
          businessId: businessId,
          businessName: businessName,
          currentUserId: currentUserId,
          ownerUserId: ownerUserId,
        );
      }
    } catch (e) {
      debugPrint('[BusinessReminderService] sync failed: $e');
    }
  }

  Future<void> _syncSalonReminders({
    required String businessId,
    required String businessName,
    required String currentUserId,
    String? ownerUserId,
  }) async {
    final snapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('appointments')
        .get();

    final now = DateTime.now();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().toLowerCase();
      if (status != 'pending' && status != 'confirmed') continue;

      final appointmentTime = _parseDate(data['appointmentTime']);
      if (appointmentTime == null) continue;

      final clientName = (data['clientName'] ?? 'Client').toString();
      final serviceName = (data['serviceName'] ?? 'service').toString();
      final stylistName = (data['stylistName'] ?? 'assigned stylist').toString();

      await _evaluateAppointmentReminderWindows(
        businessId: businessId,
        businessName: businessName,
        currentUserId: currentUserId,
        ownerUserId: ownerUserId,
        entityId: doc.id,
        clientName: clientName,
        serviceName: serviceName,
        staffName: stylistName,
        appointmentTime: appointmentTime,
        staffLabel: 'stylist',
        businessLabel: 'salon',
        now: now,
      );
    }
  }

  Future<void> _syncBarberReminders({
    required String businessId,
    required String businessName,
    required String currentUserId,
    String? ownerUserId,
  }) async {
    final snapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('appointments')
        .get();

    final now = DateTime.now();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().toLowerCase();
      if (status != 'pending' && status != 'confirmed') continue;

      final appointmentTime = _parseDate(data['appointmentTime']);
      if (appointmentTime == null) continue;

      final clientName = (data['clientName'] ?? 'Client').toString();
      final serviceName = (data['serviceName'] ?? 'service').toString();
      final barberName = (data['barberName'] ?? 'assigned barber').toString();

      await _evaluateAppointmentReminderWindows(
        businessId: businessId,
        businessName: businessName,
        currentUserId: currentUserId,
        ownerUserId: ownerUserId,
        entityId: doc.id,
        clientName: clientName,
        serviceName: serviceName,
        staffName: barberName,
        appointmentTime: appointmentTime,
        staffLabel: 'barber',
        businessLabel: 'barbershop',
        now: now,
      );
    }
  }

  Future<void> _syncHotelReminders({
    required String businessId,
    required String businessName,
    required String currentUserId,
    String? ownerUserId,
  }) async {
    final snapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('reservations')
        .get();

    final now = DateTime.now();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().toLowerCase();
      final guestName = (data['guestName'] ?? 'Guest').toString();
      final roomLabel = (data['roomNumber'] ??
              data['roomLabel'] ??
              data['roomId'] ??
              'assigned room')
          .toString();

      final checkIn = _parseDate(data['checkIn']);
      final checkOut = _parseDate(data['checkOut']);
      if (checkIn == null || checkOut == null) continue;

      final arrivalRemaining = checkIn.difference(now);
      if (status == 'confirmed' &&
          arrivalRemaining <= const Duration(hours: 26) &&
          arrivalRemaining > const Duration(hours: 18)) {
        await _deliverReminderToRelevantUsers(
          eventId: 'hotel_arrival_${doc.id}_24h',
          currentUserId: currentUserId,
          ownerUserId: ownerUserId,
          title: 'Arrival Tomorrow',
          body:
              '$guestName is expected tomorrow for room $roomLabel at $businessName.',
          data: {
            'type': 'hotel_arrival_reminder',
            'businessId': businessId,
            'reservationId': doc.id,
            'businessType': 'hotel',
          },
        );
      }

      if (status == 'checked-in') {
        final checkoutRemaining = checkOut.difference(now);

        if (checkoutRemaining <= const Duration(hours: 3) &&
            checkoutRemaining > Duration.zero) {
          await _deliverReminderToRelevantUsers(
            eventId: 'hotel_checkout_due_${doc.id}_3h',
            currentUserId: currentUserId,
            ownerUserId: ownerUserId,
            title: 'Checkout Approaching',
            body:
                '$guestName in room $roomLabel should be prepared for checkout soon.',
            data: {
              'type': 'hotel_checkout_due',
              'businessId': businessId,
              'reservationId': doc.id,
              'businessType': 'hotel',
            },
          );
        }

        if (now.isAfter(checkOut)) {
          await _deliverReminderToRelevantUsers(
            eventId: 'hotel_checkout_overdue_${doc.id}',
            currentUserId: currentUserId,
            ownerUserId: ownerUserId,
            title: 'Checkout Time Elapsed',
            body:
                '$guestName in room $roomLabel has passed the expected checkout time.',
            data: {
              'type': 'hotel_checkout_overdue',
              'businessId': businessId,
              'reservationId': doc.id,
              'businessType': 'hotel',
            },
          );
        }
      }
    }
  }

  Future<void> _evaluateAppointmentReminderWindows({
    required String businessId,
    required String businessName,
    required String currentUserId,
    required String entityId,
    required String clientName,
    required String serviceName,
    required String staffName,
    required String staffLabel,
    required String businessLabel,
    required DateTime appointmentTime,
    required DateTime now,
    String? ownerUserId,
  }) async {
    final remaining = appointmentTime.difference(now);
    final label = businessLabel == 'salon' ? 'Salon' : 'Barbershop';

    if (remaining <= const Duration(hours: 26) &&
        remaining > const Duration(hours: 18)) {
      await _deliverReminderToRelevantUsers(
        eventId: '${businessLabel}_booking_${entityId}_24h',
        currentUserId: currentUserId,
        ownerUserId: ownerUserId,
        title: '$label Booking Tomorrow',
        body:
            '$clientName is booked for $serviceName with $staffName tomorrow at $businessName.',
        data: {
          'type': '${businessLabel}_booking_reminder',
          'businessId': businessId,
          'appointmentId': entityId,
          'businessType': businessLabel,
        },
      );
    }

    if (remaining <= const Duration(hours: 4) &&
        remaining > const Duration(minutes: 45)) {
      await _deliverReminderToRelevantUsers(
        eventId: '${businessLabel}_booking_${entityId}_3h',
        currentUserId: currentUserId,
        ownerUserId: ownerUserId,
        title: '$label Booking Ahead',
        body:
            '$clientName has $serviceName with $staffLabel $staffName in the next few hours.',
        data: {
          'type': '${businessLabel}_booking_reminder',
          'businessId': businessId,
          'appointmentId': entityId,
          'businessType': businessLabel,
        },
      );
    }

    if (remaining <= const Duration(minutes: 45) &&
        remaining > const Duration(minutes: -20)) {
      await _deliverReminderToRelevantUsers(
        eventId: '${businessLabel}_booking_${entityId}_30m',
        currentUserId: currentUserId,
        ownerUserId: ownerUserId,
        title: '$label Booking Starting Soon',
        body:
            '$clientName is almost due for $serviceName with $staffName at $businessName.',
        data: {
          'type': '${businessLabel}_booking_reminder',
          'businessId': businessId,
          'appointmentId': entityId,
          'businessType': businessLabel,
        },
      );
    }
  }

  Future<void> _scheduleTimedLocalReminders({
    required String businessId,
    required String entityId,
    required DateTime when,
    required String title,
    required String Function(_ReminderOffset offset) bodyBuilder,
    required List<_ReminderOffset> offsets,
  }) async {
    final now = DateTime.now();
    for (final offset in offsets) {
      final scheduleAt = when.subtract(offset.duration);
      if (!scheduleAt.isAfter(now)) continue;

      try {
        await _notificationService.scheduleNotificationAt(
          id: _stableNotificationId(title, businessId, entityId, offset.key),
          title: title,
          body: bodyBuilder(offset),
          at: scheduleAt,
        );
      } catch (e) {
        debugPrint(
          '[BusinessReminderService] local schedule failed for $title: $e',
        );
      }
    }
  }

  Future<void> _deliverReminderToRelevantUsers({
    required String eventId,
    required String currentUserId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
    String? ownerUserId,
  }) async {
    final recipients = <String>{currentUserId};
    if (ownerUserId != null && ownerUserId.trim().isNotEmpty) {
      recipients.add(ownerUserId.trim());
    }

    for (final userId in recipients) {
      await _deliverToUser(
        userId: userId,
        eventId: eventId,
        title: title,
        body: body,
        data: data,
        sendLocal: userId == currentUserId,
      );
    }
  }

  Future<void> _deliverToUser({
    required String userId,
    required String eventId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
    required bool sendLocal,
  }) async {
    final notificationRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(eventId);

    final existing = await notificationRef.get();
    if (existing.exists) return;

    await notificationRef.set({
      'title': title,
      'body': body,
      'data': data,
      'createdAt': FieldValue.serverTimestamp(),
      'delivered': sendLocal,
      'isRead': false,
      'channel': sendLocal ? 'local' : 'push',
      'type': data['type'] ?? 'business_reminder',
      'source': 'business_reminder_service',
    }, SetOptions(merge: true));

    if (sendLocal) {
      try {
        await _notificationService.sendNotification(
          title,
          body,
          id: _stableNotificationId(userId, eventId, title, 'local'),
        );
      } catch (e) {
        debugPrint('[BusinessReminderService] local delivery failed: $e');
      }
    }

    await _queuePushIfEnabled(
      userId: userId,
      title: title,
      body: body,
      data: {
        ...data,
        'targetUserId': userId,
        'eventId': eventId,
      },
    );
  }

  Future<void> _queuePushIfEnabled({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final pushEnabled = userDoc.data()?['pushEnabled'];
      if (pushEnabled == false) return;

      final tokensSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('fcmTokens')
          .get();

      for (final tokenDoc in tokensSnapshot.docs) {
        await _firestore.collection('notification_requests').add({
          'token': tokenDoc.id,
          'title': title,
          'body': body,
          'data': data,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'push_notification',
        });
      }
    } catch (e) {
      debugPrint('[BusinessReminderService] push queue failed: $e');
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  int _stableNotificationId(
    String a,
    String b,
    String c,
    String d,
  ) {
    return Object.hash(a, b, c, d) & 0x7fffffff;
  }
}

class _ReminderOffset {
  final String key;
  final Duration duration;

  const _ReminderOffset({
    required this.key,
    required this.duration,
  });
}
