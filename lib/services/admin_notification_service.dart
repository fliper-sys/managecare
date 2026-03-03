import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/admin_notification_model.dart';

class AdminNotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _notificationsCollection = 'admin_notifications';

  Future<void> createPaymentNotification({
    required String businessName,
    required String amount,
    required String tier,
    required Map<String, dynamic> paymentData,
  }) async {
    try {
      final notification = AdminNotification(
        id: '',
        type: 'payment',
        title: 'New Subscription Payment',
        message: '$businessName subscribed to $tier (₦$amount)',
        data: {
          'businessName': businessName,
          'amount': amount,
          'tier': tier,
          ...paymentData,
        },
        createdAt: DateTime.now(),
      );

      await _db.collection(_notificationsCollection).add(notification.toMap());
    } catch (e) {
      print('Error creating payment notification: $e');
    }
  }

  Future<void> createBusinessNotification({
    required String businessName,
    required String type, // 'created', 'updated', 'suspended'
    required Map<String, dynamic> businessData,
  }) async {
    try {
      final messages = {
        'created': '$businessName has been registered',
        'updated': '$businessName information was updated',
        'suspended': '$businessName account has been suspended',
      };

      final notification = AdminNotification(
        id: '',
        type: 'business',
        title: 'Business ${type.replaceAll('_', ' ').toUpperCase()}',
        message: messages[type] ?? 'Business event occurred',
        data: {
          'businessName': businessName,
          'eventType': type,
          ...businessData,
        },
        createdAt: DateTime.now(),
      );

      await _db.collection(_notificationsCollection).add(notification.toMap());
    } catch (e) {
      print('Error creating business notification: $e');
    }
  }

  Stream<List<AdminNotification>> getNotificationsStream() {
    return _db
        .collection(_notificationsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AdminNotification.fromFirestore(doc))
          .toList();
    });
  }

  Stream<List<AdminNotification>> getUnreadNotificationsStream() {
    return _db
        .collection(_notificationsCollection)
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AdminNotification.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _db
          .collection(_notificationsCollection)
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final snapshot = await _db
          .collection(_notificationsCollection)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _db
          .collection(_notificationsCollection)
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }
}

