import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/push_service.dart';

class NotificationProvider extends ChangeNotifier {
  static const List<String> _notificationPreferenceKeys = [
    'push_enabled',
    'email_enabled',
    'sms_enabled',
    'in_app_enabled',
    'sales_alerts',
    'inventory_alerts',
    'payment_alerts',
    'customer_alerts',
    'system_alerts',
    'quiet_hours_enabled',
    'quiet_hours_start',
    'quiet_hours_end',
    'frequency',
  ];

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // Notification Channels
  bool _isPushEnabled = true;
  bool _isEmailEnabled = true;
  bool _isSmsEnabled = false;
  bool _isInAppEnabled = true;

  // Notification Types
  bool _salesAlertsEnabled = true;
  bool _inventoryAlertsEnabled = true;
  bool _paymentAlertsEnabled = true;
  bool _customerAlertsEnabled = true;
  bool _systemAlertsEnabled = true;

  // Quiet Hours
  bool _isQuietHoursEnabled = false;
  TimeOfDay _quietHoursStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietHoursEnd = const TimeOfDay(hour: 8, minute: 0);

  // Notification Frequency
  NotificationFrequency _frequency = NotificationFrequency.realTime;

  // Getters
  bool get isPushEnabled => _isPushEnabled;
  bool get isEmailEnabled => _isEmailEnabled;
  bool get isSmsEnabled => _isSmsEnabled;
  bool get isInAppEnabled => _isInAppEnabled;

  bool get salesAlertsEnabled => _salesAlertsEnabled;
  bool get inventoryAlertsEnabled => _inventoryAlertsEnabled;
  bool get paymentAlertsEnabled => _paymentAlertsEnabled;
  bool get customerAlertsEnabled => _customerAlertsEnabled;
  bool get systemAlertsEnabled => _systemAlertsEnabled;

  bool get isQuietHoursEnabled => _isQuietHoursEnabled;
  TimeOfDay get quietHoursStart => _quietHoursStart;
  TimeOfDay get quietHoursEnd => _quietHoursEnd;

  NotificationFrequency get frequency => _frequency;
  bool get isInitialized => _isInitialized;

  // Initialize provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _loadPreferences();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('Error initializing NotificationProvider: $e');
    }
  }

  // Load preferences from SharedPreferences
  void _loadPreferences() {
    _isPushEnabled = _prefs.getBool('push_enabled') ?? true;
    _isEmailEnabled = _prefs.getBool('email_enabled') ?? true;
    _isSmsEnabled = _prefs.getBool('sms_enabled') ?? false;
    _isInAppEnabled = _prefs.getBool('in_app_enabled') ?? true;

    _salesAlertsEnabled = _prefs.getBool('sales_alerts') ?? true;
    _inventoryAlertsEnabled = _prefs.getBool('inventory_alerts') ?? true;
    _paymentAlertsEnabled = _prefs.getBool('payment_alerts') ?? true;
    _customerAlertsEnabled = _prefs.getBool('customer_alerts') ?? true;
    _systemAlertsEnabled = _prefs.getBool('system_alerts') ?? true;

    _isQuietHoursEnabled = _prefs.getBool('quiet_hours_enabled') ?? false;

    final startStr = _prefs.getString('quiet_hours_start');
    if (startStr != null) {
      final parts = startStr.split(':');
      if (parts.length == 2) {
        _quietHoursStart = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 22,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    final endStr = _prefs.getString('quiet_hours_end');
    if (endStr != null) {
      final parts = endStr.split(':');
      if (parts.length == 2) {
        _quietHoursEnd = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 8,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    final freqStr = _prefs.getString('frequency') ?? 'realTime';
    _frequency = NotificationFrequency.values.firstWhere(
      (f) => f.toString().split('.').last == freqStr,
      orElse: () => NotificationFrequency.realTime,
    );
  }

  // Channel Setters
  Future<void> setPushNotifications(bool enabled) async {
    _isPushEnabled = enabled;
    await _prefs.setBool('push_enabled', enabled);

    try {
      if (enabled) {
        await PushService.enableCurrentDevicePush();
      } else {
        await PushService.disableCurrentDevicePush();
      }
    } catch (e) {
      print('Error updating local push registration: $e');
    }

    // Persist preference to Firestore for server-side filtering
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'pushEnabled': enabled,
          'pushPreferencesUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      // Non-fatal
    }

    notifyListeners();
  }

  Future<void> setEmailNotifications(bool enabled) async {
    _isEmailEnabled = enabled;
    await _prefs.setBool('email_enabled', enabled);
    notifyListeners();
  }

  Future<void> setSmsNotifications(bool enabled) async {
    _isSmsEnabled = enabled;
    await _prefs.setBool('sms_enabled', enabled);
    notifyListeners();
  }

  Future<void> setInAppNotifications(bool enabled) async {
    _isInAppEnabled = enabled;
    await _prefs.setBool('in_app_enabled', enabled);
    notifyListeners();
  }

  // Alert Type Setters
  Future<void> setSalesAlerts(bool enabled) async {
    _salesAlertsEnabled = enabled;
    await _prefs.setBool('sales_alerts', enabled);
    notifyListeners();
  }

  Future<void> setInventoryAlerts(bool enabled) async {
    _inventoryAlertsEnabled = enabled;
    await _prefs.setBool('inventory_alerts', enabled);
    notifyListeners();
  }

  Future<void> setPaymentAlerts(bool enabled) async {
    _paymentAlertsEnabled = enabled;
    await _prefs.setBool('payment_alerts', enabled);
    notifyListeners();
  }

  Future<void> setCustomerAlerts(bool enabled) async {
    _customerAlertsEnabled = enabled;
    await _prefs.setBool('customer_alerts', enabled);
    notifyListeners();
  }

  Future<void> setSystemAlerts(bool enabled) async {
    _systemAlertsEnabled = enabled;
    await _prefs.setBool('system_alerts', enabled);
    notifyListeners();
  }

  // Quiet Hours Setters
  Future<void> setQuietHoursEnabled(bool enabled) async {
    _isQuietHoursEnabled = enabled;
    await _prefs.setBool('quiet_hours_enabled', enabled);
    notifyListeners();
  }

  Future<void> setQuietHoursStart(TimeOfDay time) async {
    _quietHoursStart = time;
    await _prefs.setString('quiet_hours_start', '${time.hour}:${time.minute}');
    notifyListeners();
  }

  Future<void> setQuietHoursEnd(TimeOfDay time) async {
    _quietHoursEnd = time;
    await _prefs.setString('quiet_hours_end', '${time.hour}:${time.minute}');
    notifyListeners();
  }

  // Frequency Setter
  Future<void> setFrequency(NotificationFrequency freq) async {
    _frequency = freq;
    final freqStr = freq.toString().split('.').last;
    await _prefs.setString('frequency', freqStr);
    notifyListeners();
  }

  // Reset to defaults
  Future<void> resetToDefaults() async {
    _isPushEnabled = true;
    _isEmailEnabled = true;
    _isSmsEnabled = false;
    _isInAppEnabled = true;
    _salesAlertsEnabled = true;
    _inventoryAlertsEnabled = true;
    _paymentAlertsEnabled = true;
    _customerAlertsEnabled = true;
    _systemAlertsEnabled = true;
    _isQuietHoursEnabled = false;
    _quietHoursStart = const TimeOfDay(hour: 22, minute: 0);
    _quietHoursEnd = const TimeOfDay(hour: 8, minute: 0);
    _frequency = NotificationFrequency.realTime;

    for (final key in _notificationPreferenceKeys) {
      await _prefs.remove(key);
    }

    try {
      await PushService.enableCurrentDevicePush();

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'pushEnabled': true,
          'pushPreferencesUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error restoring default push registration: $e');
    }

    notifyListeners();
  }

  // Check if notification should be shown
  bool shouldShowNotification(String alertType) {
    // Check if quiet hours are active
    if (_isQuietHoursEnabled) {
      final now = TimeOfDay.now();
      final inQuietHours =
          _isTimeInRange(now, _quietHoursStart, _quietHoursEnd);
      if (inQuietHours) return false;
    }

    // Check if channel is enabled
    if (!_isInAppEnabled &&
        !_isPushEnabled &&
        !_isEmailEnabled &&
        !_isSmsEnabled) {
      return false;
    }

    // Check specific alert type
    switch (alertType) {
      case 'sales':
        return _salesAlertsEnabled;
      case 'inventory':
        return _inventoryAlertsEnabled;
      case 'payment':
        return _paymentAlertsEnabled;
      case 'customer':
        return _customerAlertsEnabled;
      case 'system':
        return _systemAlertsEnabled;
      default:
        return true;
    }
  }

  // Helper method to check if time is within range
  bool _isTimeInRange(TimeOfDay time, TimeOfDay start, TimeOfDay end) {
    final timeInMinutes = time.hour * 60 + time.minute;
    final startInMinutes = start.hour * 60 + start.minute;
    final endInMinutes = end.hour * 60 + end.minute;

    if (startInMinutes < endInMinutes) {
      return timeInMinutes >= startInMinutes && timeInMinutes <= endInMinutes;
    } else {
      // Range crosses midnight
      return timeInMinutes >= startInMinutes || timeInMinutes <= endInMinutes;
    }
  }
}

enum NotificationFrequency {
  realTime,
  hourly,
  daily,
}

