import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notification_interface.dart';

/// Notification service for local scheduled notifications and broadcasts.
class NotificationService implements INotificationService {
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  static const String _channelId = 'managecare_general';
  static const String _channelName = 'Manage Care Alerts';
  static const String _channelDescription = 'General business alerts and push notifications';

  static final AndroidNotificationChannel _defaultChannel =
      AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDescription,
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    tz.local.name;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    // Windows notifications: appName is required for toast notifications
    const windows = WindowsInitializationSettings(
      appName: 'Manage Care', appUserModelId: '', guid: '',
    );
    const settings = InitializationSettings(
      android: android,
      iOS: ios,
      windows: windows,
      macOS: DarwinInitializationSettings(),
      linux: LinuxInitializationSettings(defaultActionName: 'Manage Care'),
    );

    await _plugin.initialize(settings: settings);
    await _configureAndroidChannel();
    await _requestPermissions();

    // Windows release builds crash the AOT compiler (gen_snapshot) with
    // "Unexpected object (Class with illegal cid, full-aot)" referencing
    // NativeLaunchDetails unless something actually calls this method —
    // see https://github.com/MaikuB/flutter_local_notifications/issues/2615.
    // The plugin author confirmed this call is the fix; the return value
    // isn't otherwise needed here.
    await _plugin.getNotificationAppLaunchDetails();

    _initialized = true;
  }

  Future<void> _configureAndroidChannel() async {
    if (!Platform.isAndroid) return;

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_defaultChannel);
  }

  Future<void> _requestPermissions() async {
    try {
      if (Platform.isIOS) {
        final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      } else if (Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.requestNotificationsPermission();

        if (await Permission.notification.isDenied) {
          await Permission.notification.request();
        }
      }
    } catch (_) {
      // Permission failures should not crash app startup.
    }
  }

  @override
  Future<void> requestPermissions() async => _requestPermissions();

  @override
  Future<void> sendNotification(String title, String body, {int id = 0}) async {
    await initialize();

    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  @override
  Future<void> scheduleNotificationAt({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    await initialize();

    final tzDate = tz.TZDateTime.from(at, tz.local);
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Schedule an expiry alert for a member. `daysBefore` defaults to 1.
  @override
  Future<void> scheduleExpiryAlert({
    required String businessId,
    required String memberId,
    required String memberName,
    required DateTime expiry,
    int daysBefore = 1,
  }) async {
    final notifyAt = expiry.subtract(Duration(days: daysBefore));

    if (notifyAt.isBefore(DateTime.now())) {
      await sendNotification(
        'Membership expiring',
        '$memberName membership is expiring soon',
      );
      return;
    }

    final id = _computeNotificationId(businessId, memberId);
    await scheduleNotificationAt(
      id: id,
      title: 'Membership expiring',
      body:
          '$memberName membership expires on ${expiry.toLocal().toIso8601String().split('T').first}',
      at: notifyAt,
    );
    await _recordScheduledAlertMetadata(
      businessId,
      id,
      memberId,
      memberName,
      notifyAt,
    );
  }

  /// Broadcast a notification for a business (local device only).
  Future<void> broadcastForBusiness(
    String businessId,
    String title,
    String body,
  ) async {
    await sendNotification(title, body);
  }

  int _computeNotificationId(String businessId, String entityId) {
    return businessId.hashCode ^ entityId.hashCode;
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    await initialize();
    return _plugin.pendingNotificationRequests();
  }

  @override
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id: id);
    await _removeScheduledAlertMetadata(id);
  }

  static const _prefsKeyThresholds = 'notification_days_before_thresholds';
  static const _prefsKeyScheduledAlerts = 'notification_scheduled_alerts';

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

  Future<void> _recordScheduledAlertMetadata(
    String businessId,
    int id,
    String memberId,
    String memberName,
    DateTime notifyAt,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_prefsKeyScheduledAlerts) ?? [];
      final entry =
          '$businessId|$id|$memberId|${memberName.replaceAll('|', '_')}|${notifyAt.toUtc().toIso8601String()}';

      existing.removeWhere(
        (item) =>
            item.split('|').length >= 2 &&
            int.tryParse(item.split('|')[1]) == id,
      );
      existing.add(entry);

      await prefs.setStringList(_prefsKeyScheduledAlerts, existing);
    } catch (_) {
      // Metadata persistence is best-effort.
    }
  }

  Future<void> _removeScheduledAlertMetadata(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_prefsKeyScheduledAlerts) ?? [];
      existing.removeWhere(
        (item) =>
            item.split('|').length >= 2 &&
            int.tryParse(item.split('|')[1]) == id,
      );
      await prefs.setStringList(_prefsKeyScheduledAlerts, existing);
    } catch (_) {
      // Metadata cleanup is best-effort.
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getScheduledAlertMetadata({
    String? businessId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_prefsKeyScheduledAlerts) ?? [];
    final results = <Map<String, dynamic>>[];

    for (final item in existing) {
      final parts = item.split('|');
      if (parts.length < 5) continue;

      final bid = parts[0];
      final nid = int.tryParse(parts[1]) ?? 0;
      final mid = parts[2];
      final mname = parts[3];
      final at = DateTime.tryParse(parts[4])?.toLocal();

      if (at == null) continue;
      if (businessId != null && businessId != bid) continue;

      results.add({
        'businessId': bid,
        'id': nid,
        'memberId': mid,
        'memberName': mname,
        'notifyAt': at,
      });
    }

    results.sort(
      (a, b) =>
          (a['notifyAt'] as DateTime).compareTo(b['notifyAt'] as DateTime),
    );
    return results;
  }

  Future<void> cancelAllNotifications() async {
    try {
      final pending = await getPendingNotifications();
      for (final request in pending) {
        await cancelNotification(request.id);
      }
    } catch (_) {
      // Ignore cleanup failures.
    }
  }
}
