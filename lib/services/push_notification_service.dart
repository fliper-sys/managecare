import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Service for sending push notifications to specific users via Firebase Cloud Messaging
class PushNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send push notification to business owners
  Future<void> sendNotificationToBusinessOwners({
    required String businessId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get business document to find owner
      final businessDoc = await _firestore.collection('businesses').doc(businessId).get();
      if (!businessDoc.exists) {
        print('[PushNotificationService] Business not found: $businessId');
        return;
      }

      final businessData = businessDoc.data() as Map<String, dynamic>;
      final ownerId = businessData['ownerId'] as String?;

      if (ownerId == null || ownerId.isEmpty) {
        print('[PushNotificationService] No owner found for business: $businessId');
        return;
      }

      await sendNotificationToUser(
        userId: ownerId,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      print('[PushNotificationService] Error sending notification to business owners: $e');
    }
  }

  /// Send push notification to a specific user
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM tokens
      final tokensSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('fcmTokens')
          .get();

      if (tokensSnapshot.docs.isEmpty) {
        print('[PushNotificationService] No FCM tokens found for user: $userId');
        return;
      }

      // Send notification to each token
      final tokens = tokensSnapshot.docs.map((doc) => doc.id).toList();

      for (final token in tokens) {
        await _sendFCMNotification(
          token: token,
          title: title,
          body: body,
          data: data,
        );
      }

      // Also save to user's notifications collection for in-app display
      await _saveNotificationToUserCollection(
        userId: userId,
        title: title,
        body: body,
        data: data,
      );

    } catch (e) {
      print('[PushNotificationService] Error sending notification to user $userId: $e');
    }
  }

  /// Send FCM notification to a specific token
  Future<void> _sendFCMNotification({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Note: In a production app, you would send this via your backend server
      // or Firebase Cloud Functions, not directly from the client app.
      // This is a simplified implementation for demonstration.

      // For now, we'll use Firebase Admin SDK via Cloud Functions
      // Create a document in a collection that triggers a Cloud Function
      await _firestore.collection('notification_requests').add({
        'token': token,
        'title': title,
        'body': body,
        'data': data ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'push_notification',
      });

    } catch (e) {
      print('[PushNotificationService] Error sending FCM notification: $e');
    }
  }

  /// Save notification to user's in-app notifications collection
  Future<void> _saveNotificationToUserCollection({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).collection('notifications').add({
        'title': title,
        'body': body,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'delivered': false, // Will be marked as delivered when read
        'type': 'push',
      });
    } catch (e) {
      print('[PushNotificationService] Error saving notification to user collection: $e');
    }
  }

  /// Send notification to all users with a specific role in a business
  Future<void> sendNotificationToBusinessUsers({
    required String businessId,
    required String userRole, // 'owner', 'worker', 'manager', etc.
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get all users associated with the business
      final usersQuery = await _firestore
          .collection('users')
          .where('businesses', arrayContains: businessId)
          .where('role', isEqualTo: userRole)
          .get();

      for (final userDoc in usersQuery.docs) {
        final userId = userDoc.id;
        await sendNotificationToUser(
          userId: userId,
          title: title,
          body: body,
          data: data,
        );
      }
    } catch (e) {
      print('[PushNotificationService] Error sending notification to business users: $e');
    }
  }

  /// Send broadcast notification to all users
  Future<void> sendBroadcastNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // This would typically be handled by a Cloud Function
      // For now, we'll create a broadcast request
      await _firestore.collection('notification_requests').add({
        'type': 'broadcast',
        'title': title,
        'body': body,
        'data': data ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[PushNotificationService] Error sending broadcast notification: $e');
    }
  }
}