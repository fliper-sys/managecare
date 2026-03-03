import 'package:firebase_analytics/firebase_analytics.dart';

/// Analytics service for tracking business events
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  late FirebaseAnalytics _analytics;

  factory AnalyticsService() {
    return _instance;
  }

  AnalyticsService._internal();

  /// Initialize Firebase Analytics
  Future<void> initialize() async {
    _analytics = FirebaseAnalytics.instance;
  }

  /// Log custom event
  Future<void> logEvent(
    String eventName,
    Map<String, dynamic> parameters,
  ) async {
    try {
      // Convert all values to proper types for Firebase
      final cleanParams = <String, Object>{}..addAll(
          parameters.map(
            (key, value) => MapEntry(
              key,
              _convertToFirebaseType(value),
            ),
          ),
        );

      await _analytics.logEvent(
        name: eventName,
        parameters: cleanParams,
      );
    } catch (e) {
      print('Analytics logEvent error: $e');
    }
  }

  /// Log screen view
  Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenName,
      );
    } catch (e) {
      print('Analytics logScreenView error: $e');
    }
  }

  /// Set user properties
  Future<void> setUserProperties(Map<String, dynamic> properties) async {
    try {
      for (final entry in properties.entries) {
        final value = entry.value.toString();
        // Firebase limits user property keys to 24 chars and values to 36 chars
        final key =
            entry.key.length <= 24 ? entry.key : entry.key.substring(0, 24);
        final cleanValue = value.length <= 36 ? value : value.substring(0, 36);

        await _analytics.setUserProperty(
          name: key,
          value: cleanValue,
        );
      }
    } catch (e) {
      print('Analytics setUserProperties error: $e');
    }
  }

  /// Set user ID
  Future<void> setUserId(String userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      print('Analytics setUserId error: $e');
    }
  }

  /// Log purchase event
  Future<void> logPurchase({
    required String itemId,
    required String itemName,
    required double value,
    String? currency,
  }) async {
    try {
      await logEvent('purchase', {
        'item_id': itemId,
        'item_name': itemName,
        'value': value,
        'currency': currency ?? 'USD',
      });
    } catch (e) {
      print('Analytics logPurchase error: $e');
    }
  }

  /// Helper to convert values to Firebase-compatible types
  Object _convertToFirebaseType(dynamic value) {
    if (value is String) return value;
    if (value is int) return value;
    if (value is double) return value;
    if (value is bool) return value;
    return value.toString();
  }
}

