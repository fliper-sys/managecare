import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'notification_service.dart';

/// Top-level background handler for FCM messages.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Firebase may already be initialized for this isolate.
  }

  try {
    final data = message.data;
    final title =
        message.notification?.title ?? data['title'] ?? 'Notification';
    final body = message.notification?.body ?? data['body'] ?? '';
    final targetUser = data['targetUserId'] ?? data['userId'];

    if (targetUser == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(targetUser.toString())
        .collection('notifications')
        .add({
      'title': title,
      'body': body,
      'data': data,
      'messageId': message.messageId,
      'createdAt': FieldValue.serverTimestamp(),
      'delivered': true,
      'isRead': false,
      'channel': 'push',
      'type': data['type'] ?? data['alertType'] ?? 'general',
      'source': 'background_push',
    });
  } catch (_) {
    // Background delivery should remain best-effort.
  }
}

class PushService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void>? _initializeFuture;
  static StreamSubscription<User?>? _authSubscription;
  static bool _foregroundHandlersAttached = false;

  static bool get _supportsRemotePush =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Initialize push handlers. Call once on app startup.
  static Future<void> initialize() {
    if (!_supportsRemotePush) return Future.value();
    return _initializeFuture ??= _initializeInternal();
  }

  static Future<void> _initializeInternal() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _fcm.setAutoInitEnabled(true);
    await _configureForegroundPresentation();
    await _requestPermissions();
    await _saveCurrentTokenIfAvailable();

    _fcm.onTokenRefresh.listen((token) async {
      await _saveTokenForCurrentUser(token);
    });

    if (!_foregroundHandlersAttached) {
      _foregroundHandlersAttached = true;

      FirebaseMessaging.onMessage.listen((message) {
        final title =
            message.notification?.title ?? message.data['title'] ?? 'Notification';
        final body = message.notification?.body ?? message.data['body'] ?? '';

        unawaited(NotificationService.instance.sendNotification(title, body));
        unawaited(_saveNotificationRecordToFirestore(message, source: 'foreground_push'));
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        unawaited(
          _saveNotificationRecordToFirestore(
            message,
            source: 'opened_push',
          ),
        );
      });
    }

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      await _saveNotificationRecordToFirestore(
        initialMessage,
        source: 'launch_push',
      );
    }

    _authSubscription ??= _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _saveCurrentTokenIfAvailable();
      }
    });
  }

  static Future<void> enableCurrentDevicePush() async {
    if (!_supportsRemotePush) return;

    await initialize();
    await _fcm.setAutoInitEnabled(true);
    await _requestPermissions();
    await _saveCurrentTokenIfAvailable();
  }

  static Future<void> disableCurrentDevicePush() async {
    if (!_supportsRemotePush) return;

    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await removeTokenForCurrentUser(token);
      }

      await _fcm.setAutoInitEnabled(false);
      await _fcm.deleteToken();
    } catch (e) {
      debugPrint('[PushService] Failed to disable push: $e');
    }
  }

  static Future<void> _configureForegroundPresentation() async {
    try {
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      // Safe to ignore on unsupported platforms.
    }
  }

  static Future<void> _requestPermissions() async {
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
    } catch (_) {
      // Permission prompts are best-effort.
    }
  }

  static Future<void> _saveCurrentTokenIfAvailable() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final token = await _fcm.getToken();
    if (token != null) {
      await _saveTokenForCurrentUser(token);
    }
  }

  /// Save the FCM token under the current user document.
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
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore.collection('users').doc(user.uid).set({
        'hasFcm': true,
        'lastFcmRegisteredAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[PushService] Failed to save token: $e');
    }
  }

  static Future<void> _saveNotificationRecordToFirestore(
    RemoteMessage message, {
    required String source,
  }) async {
    try {
      final data = message.data;
      final title =
          message.notification?.title ?? data['title'] ?? 'Notification';
      final body = message.notification?.body ?? data['body'] ?? '';
      final uid = _auth.currentUser?.uid ??
          data['targetUserId']?.toString() ??
          data['userId']?.toString();

      if (uid == null || uid.isEmpty) return;

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'data': data,
        'messageId': message.messageId,
        'createdAt': FieldValue.serverTimestamp(),
        'delivered': true,
        'isRead': false,
        'channel': 'push',
        'type': data['type'] ?? data['alertType'] ?? 'general',
        'source': source,
      });
    } catch (_) {
      // Notification feed persistence is non-blocking.
    }
  }

  /// Remove a token for the current user (call on logout).
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
      debugPrint('[PushService] Failed to remove token: $e');
    }
  }
}
