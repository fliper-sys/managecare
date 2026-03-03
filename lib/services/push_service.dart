import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';


import 'notification_service.dart';

/// Top-level background handler for FCM messages. This runs in a background
/// isolate on Android/iOS and should be a top-level function.
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Best-effort: write a notification doc to Firestore so the UI can pick it up
  try {
    final data = message.data;
    final title = message.notification?.title ?? data['title'] ?? 'Notification';
    final body = message.notification?.body ?? data['body'] ?? '';

    // If a target user id is present, write to their notifications subcollection
    final targetUser = data['targetUserId'] ?? data['userId'];
    if (targetUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUser)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
        'delivered': true,
      });
    }
  } catch (e) {
    // ignore errors in background handler
  }
}

class PushService {
  static final _fcm = FirebaseMessaging.instance;
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Initialize push handlers. Call once on app startup.
  static Future<void> initialize() async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permissions (iOS & Android 13+)
    try {
      await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // Optionally, you can log settings.authorizationStatus
    } catch (_) {}

    // Handle the token lifecycle
    _fcm.getToken().then((token) async {
      if (token != null) await _saveTokenForCurrentUser(token);
    });

    _fcm.onTokenRefresh.listen((token) async {
      await _saveTokenForCurrentUser(token);
    });

    // Foreground message handling: show a local notification via NotificationService
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? message.data['title'] ?? 'Notification';
      final body = message.notification?.body ?? message.data['body'] ?? '';
      // Use the existing NotificationService (local notifications)
      NotificationService.instance.sendNotification(title, body);
    });

    // When user taps notification to open the app
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // You can navigate/deep-link here. Keep this lightweight; app's routing should handle.
      // For now, write a record to the user's notifications collection (so in-app UI can show it)
      final data = message.data;
      final title = message.notification?.title ?? data['title'] ?? 'Notification';
      final body = message.notification?.body ?? data['body'] ?? '';
      _saveNotificationRecordToFirestore(title: title, body: body, data: data);
    });

    // Handle when app is opened from terminated state via a message
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      final data = initialMessage.data;
      final title = initialMessage.notification?.title ?? data['title'] ?? 'Notification';
      final body = initialMessage.notification?.body ?? data['body'] ?? '';
      _saveNotificationRecordToFirestore(title: title, body: body, data: data);
    }

    // If a user is already authenticated, ensure token is saved
    if (_auth.currentUser != null) {
      final token = await _fcm.getToken();
      if (token != null) await _saveTokenForCurrentUser(token);
    }

    // Listen for auth changes to register/unregister tokens
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        final token = await _fcm.getToken();
        if (token != null) await _saveTokenForCurrentUser(token);
      }
    });
  }

  /// Save the FCM token under the current user document (users/{uid}/fcmTokens/{token}
  /// or as a merged map field). This is used by Cloud Functions to target devices.
  static Future<void> _saveTokenForCurrentUser(String token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final tokenDoc = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .doc(token);

      await tokenDoc.set({
        'token': token,
        'platform': Platform.operatingSystem,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });

      // optional: add a small flag in the user doc
      await _firestore.collection('users').doc(user.uid).set({
        'hasFcm': true,
        'lastFcmRegisteredAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Ignore failures but log if needed
      print('[PushService] Failed to save token: $e');
    }
  }

  static Future<void> _saveNotificationRecordToFirestore({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      await _firestore.collection('users').doc(uid).collection('notifications').add({
        'title': title,
        'body': body,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'delivered': true,
      });
    } catch (_) {}
  }

  /// Remove a token for the current user (call on logout)
  static Future<void> removeTokenForCurrentUser(String token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .doc(token)
          .delete();
    } catch (e) {
      print('[PushService] Failed to remove token: $e');
    }
  }
}
