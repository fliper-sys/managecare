import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';

/// Self-hosted push notification service.
///
/// Replaces Firebase Cloud Messaging (FCM) with a fully self-hosted stack:
///   • Socket.io (on the Express backend) for real-time delivery
///   • Postgres `notifications` table for persistence
///   • Periodic polling (60 s) as a fallback when the socket disconnects
///   • Local Flutter notifications for the display layer
///
/// Architecture:
///   Flutter App ──Socket.io──> Express Server ──> Postgres (notifications)
///        │                          │
///        └── HTTP polling (60s) ────┘ (fallback)
///
class SelfHostedPushService {
  SelfHostedPushService._internal();
  static final SelfHostedPushService instance = SelfHostedPushService._internal();

  // ── Dependencies ──────────────────────────────────────────
  final Dio _dio = Dio(BaseOptions(
    baseUrl: SupabaseConfig.url,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── State ─────────────────────────────────────────────────
  io.Socket? _socket;
  Timer? _pollingTimer;
  bool _isInitialized = false;
  String? _deviceId;
  String? _userId;
  final List<Map<String, dynamic>> _localNotifications = [];

  // Events stream for the UI layer
  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotification =>
      _notificationController.stream;

  // ── Initialization ────────────────────────────────────────
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _getOrCreateDeviceId();
      _userId = _supabase.auth.currentUser?.id;

      if (_userId != null) {
        await _registerDevice();
        await _connectSocket();
        _startPolling();
      }

      _isInitialized = true;
      debugPrint('[SelfHostedPush] Initialized (device: $_deviceId, user: $_userId)');
    } catch (e) {
      debugPrint('[SelfHostedPush] Init error: $e');
    }
  }

  // ── Device ID management ──────────────────────────────────
  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('push_device_id');

    if (_deviceId == null) {
      // Generate a UUID-like device id
      _deviceId = 'dev_${DateTime.now().millisecondsSinceEpoch}_${_randomString(12)}';
      await prefs.setString('push_device_id', _deviceId!);
    }

    return _deviceId!;
  }

  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final result = StringBuffer();
    for (int i = 0; i < length; i++) {
      result.write(chars[DateTime.now().microsecondsSinceEpoch % chars.length]);
    }
    return result.toString();
  }

  // ── Socket.io connection ──────────────────────────────────
  Future<void> _connectSocket() async {
    try {
      final accessToken = _supabase.auth.currentSession?.accessToken;

      _socket = io.io(
        SupabaseConfig.url,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': accessToken})
            .disableAutoConnect()
            .build(),
      );

      _socket!.onConnect((_) {
        debugPrint('[SelfHostedPush] Socket connected: ${_socket!.id}');

        // Join user-specific room for targeted notifications
        if (_userId != null) {
          _socket!.emit('join_user', _userId);
        }

        // Listen for real-time notifications
        _socket!.on('notification', (data) {
          _handleIncomingNotification(data as Map<String, dynamic>);
        });
      });

      _socket!.onDisconnect((_) {
        debugPrint('[SelfHostedPush] Socket disconnected');
      });

      _socket!.onConnectError((error) {
        debugPrint('[SelfHostedPush] Socket connect error: $error');
      });

      _socket!.connect();
    } catch (e) {
      debugPrint('[SelfHostedPush] Socket init error: $e');
    }
  }

  // ── Device registration (POST /api/push/register) ─────────
  Future<void> _registerDevice() async {
    try {
      final accessToken = _supabase.auth.currentSession?.accessToken;
      if (accessToken == null) return;

      await _dio.post(
        '/api/push/register',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        data: {
          'device_id': _deviceId,
          'user_id': _userId,
          'platform': defaultTargetPlatform.name,
          'device_name': defaultTargetPlatform.name,
        },
      );

      debugPrint('[SelfHostedPush] Device registered');
    } catch (e) {
      debugPrint('[SelfHostedPush] Device registration error: $e');
    }
  }

  // ── Polling fallback (60s interval) ───────────────────────
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _fetchUnreadNotifications();
    });
  }

  Future<void> _fetchUnreadNotifications() async {
    if (_userId == null) return;

    try {
      final accessToken = _supabase.auth.currentSession?.accessToken;
      if (accessToken == null) return;

      final response = await _dio.get(
        '/api/notifications/unread/$_userId',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      final notifications = response.data as List<dynamic>;
      for (final raw in notifications) {
        final notif = raw as Map<String, dynamic>;
        // Only process if not already present locally
        final alreadyExists = _localNotifications.any(
          (n) => n['id'] == notif['id'],
        );
        if (!alreadyExists) {
          _handleIncomingNotification(notif);
        }
      }
    } catch (e) {
      debugPrint('[SelfHostedPush] Poll fetch error: $e');
    }
  }

  // ── Handle incoming notification───────────────────────────
  void _handleIncomingNotification(Map<String, dynamic> notif) {
    _persistNotification(notif);
    _notificationController.add(notif);
    debugPrint('[SelfHostedPush] Notification received: ${notif['title']}');
  }

  void _persistNotification(Map<String, dynamic> notif) {
    // Deduplicate by id
    _localNotifications.removeWhere((n) => n['id'] == notif['id']);
    _localNotifications.insert(0, notif);

    // Keep max 200 notifications in memory
    if (_localNotifications.length > 200) {
      _localNotifications.removeRange(200, _localNotifications.length);
    }
  }

  // ── Public API ────────────────────────────────────────────
  List<Map<String, dynamic>> getLocalNotifications() =>
      List.unmodifiable(_localNotifications);

  Future<void> markAsRead(int notificationId) async {
    try {
      final accessToken = _supabase.auth.currentSession?.accessToken;
      if (accessToken == null) return;

      await _dio.put(
        '/api/notifications/$notificationId/read',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      // Update local state
      final idx = _localNotifications.indexWhere((n) => n['id'] == notificationId);
      if (idx != -1) {
        _localNotifications[idx]['is_read'] = true;
      }
    } catch (e) {
      debugPrint('[SelfHostedPush] Mark read error: $e');
    }
  }

  Future<void> unregisterDevice() async {
    try {
      final accessToken = _supabase.auth.currentSession?.accessToken;
      if (accessToken == null || _deviceId == null) return;

      await _dio.delete(
        '/api/push/device/$_deviceId',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      debugPrint('[SelfHostedPush] Device unregistered');
    } catch (e) {
      debugPrint('[SelfHostedPush] Unregister error: $e');
    }
  }

  Future<void> dispose() async {
    _pollingTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    await _notificationController.close();
    _isInitialized = false;
    debugPrint('[SelfHostedPush] Disposed');
  }
}
