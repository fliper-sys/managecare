import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'notification_interface.dart';

/// Notification service for local scheduled notifications and broadcasts.
class NotificationService implements INotificationService {
  static final NotificationService _instance = NotificationService._internal();

  NotificationService._internal();

  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Initialize timezone data
    tzdata.initializeTimeZones();
    // Ensure local timezone is initialized
    tz.local.name;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings);
    // Request permissions on supported platforms
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    try {
      if (Platform.isIOS) {
        final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        await iosPlugin?.requestPermissions(
            alert: true, badge: true, sound: true);
      } else if (Platform.isAndroid) {
        // On Android 13+ POST_NOTIFICATIONS permission is required at runtime
        if (await Permission.notification.isDenied) {
          await Permission.notification.request();
        }
      }
    } catch (e) {
      // Ignore permission request failures but log if needed
    }
  }

  /// Public wrapper to request platform notification permissions.
  @override
  Future<void> requestPermissions() async => _requestPermissions();

  Future<void> sendNotification(String title, String body, {int id = 0}) async {
    const android = AndroidNotificationDetails('default_channel', 'General',
        channelDescription: 'General notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority);
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);
    await _plugin.show(id, title, body, details);
  }

  Future<void> scheduleNotificationAt(
      {required int id,
      required String title,
      required String body,
      required DateTime at}) async {
    final tzDate = tz.TZDateTime.from(at, tz.local);
    const android = AndroidNotificationDetails('scheduled_channel', 'Scheduled',
        channelDescription: 'Scheduled notifications',
        importance: Importance.high,
        priority: Priority.high);
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      details,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
    );
  }

  /// Schedule an expiry alert for a member. `daysBefore` defaults to 1 (one day before expiry).
  @override
  Future<void> scheduleExpiryAlert(
      {required String businessId,
      required String memberId,
      required String memberName,
      required DateTime expiry,
      int daysBefore = 1}) async {
    final notifyAt = expiry.subtract(Duration(days: daysBefore));
    if (notifyAt.isBefore(DateTime.now())) {
      // If scheduled time already passed, send immediately
      await sendNotification(
          'Membership expiring', '$memberName membership is expiring soon');
      return;
    }
    final id = _computeNotificationId(businessId, memberId);
    await scheduleNotificationAt(
        id: id,
        title: 'Membership expiring',
        body:
            '$memberName membership expires on ${expiry.toLocal().toIso8601String().split('T').first}',
        at: notifyAt);
    // Persist that we scheduled this expiry so admin UI can show thresholds
    await _recordScheduledAlertMetadata(
        businessId, id, memberId, memberName, notifyAt);
  }

  /// Broadcast a notification for a business (local device only).
  Future<void> broadcastForBusiness(
      String businessId, String title, String body) async {
    // For now, broadcast is same as local send; in multi-device scenario, server-side push is needed.
    await sendNotification(title, body);
  }

  int _computeNotificationId(String businessId, String entityId) {
    // Simple hashed id generation (not cryptographically unique but OK for local ids)
    return businessId.hashCode ^ entityId.hashCode;
  }

  // --- Admin helpers ---
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending;
  }

  @override
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
    // Optionally remove persisted metadata for this id
    await _removeScheduledAlertMetadata(id);
  }

  static const _prefsKeyThresholds = 'notification_days_before_thresholds';

  /// Save days-before thresholds for expiry alerts per business (comma separated ints)
  Future<void> setDaysBeforeThresholds(List<int> days) async {
    final prefs = await SharedPreferences.getInstance();
    final value = days.map((d) => d.toString()).join(',');
    await prefs.setString(_prefsKeyThresholds, value);
  }

  @override
  Future<List<int>> getDaysBeforeThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefsKeyThresholds) ?? '7,1';
    return value.split(',').map((s) => int.tryParse(s) ?? 1).toList();
  }

  // Persist a small metadata map for scheduled alerts so the admin UI can show friendly items
  static const _prefsKeyScheduledAlerts = 'notification_scheduled_alerts';

  Future<void> _recordScheduledAlertMetadata(String businessId, int id,
      String memberId, String memberName, DateTime notifyAt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_prefsKeyScheduledAlerts) ?? [];
      final entry =
          '$businessId|$id|$memberId|${memberName.replaceAll('|', '_')}|${notifyAt.toUtc().toIso8601String()}';
      existing.removeWhere((e) =>
          e.split('|').length >= 2 && int.tryParse(e.split('|')[1]) == id);
      existing.add(entry);
      await prefs.setStringList(_prefsKeyScheduledAlerts, existing);
    } catch (_) {}
  }

  Future<void> _removeScheduledAlertMetadata(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_prefsKeyScheduledAlerts) ?? [];
      existing.removeWhere((e) =>
          e.split('|').length >= 2 && int.tryParse(e.split('|')[1]) == id);
      await prefs.setStringList(_prefsKeyScheduledAlerts, existing);
    } catch (_) {}
  }

  @override
  Future<List<Map<String, dynamic>>> getScheduledAlertMetadata(
      {String? businessId}) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_prefsKeyScheduledAlerts) ?? [];
    final results = <Map<String, dynamic>>[];
    for (final e in existing) {
      final parts = e.split('|');
      if (parts.length < 5) continue;
      final bid = parts[0];
      final nid = int.tryParse(parts[1]) ?? 0;
      final mid = parts[2];
      final mname = parts[3];
      final at = DateTime.tryParse(parts[4])?.toLocal();
      if (businessId != null && businessId != bid) continue;
      results.add({
        'businessId': bid,
        'id': nid,
        'memberId': mid,
        'memberName': mname,
        'notifyAt': at,
      });
    }
    results.sort((a, b) =>
        (a['notifyAt'] as DateTime).compareTo(b['notifyAt'] as DateTime));
    return results;
  }

  /// Cancel all pending notifications
  Future<void> cancelAllNotifications() async {
    try {
      final pending = await getPendingNotifications();
      for (final request in pending) {
        await cancelNotification(request.id);
      }
    } catch (e) {
      // Ignore errors
    }
  }
}

