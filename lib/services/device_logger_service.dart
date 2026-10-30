import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for capturing detailed device and platform logs
class DeviceLoggerService {
  static const platform = MethodChannel('com.manage_care.app/device_logs');
  static const int _maxEntries = 500;
  static final ValueNotifier<List<String>> entries =
      ValueNotifier<List<String>>(const []);
  static final ValueNotifier<String?> recoveryNotice =
      ValueNotifier<String?>(null);
  static bool _debugCaptureInitialized = false;

  static void initializeErrorCapture() {
    if (_debugCaptureInitialized) return;
    _debugCaptureInitialized = true;

    final previousErrorHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      capture('$error\n$stack', severity: 'ERROR');
      return previousErrorHandler?.call(error, stack) ?? false;
    };
  }

  static void capture(String message, {String severity = 'INFO'}) {
    final entry = '[${DateTime.now().toIso8601String()}] [$severity] $message';
    final updated = [...entries.value, entry];
    if (updated.length > _maxEntries) {
      updated.removeRange(0, updated.length - _maxEntries);
    }
    entries.value = List.unmodifiable(updated);
  }

  static void clear() {
    entries.value = const [];
  }

  static void setRecoveryNotice(String? message) {
    recoveryNotice.value = message;
    if (message != null) {
      capture('Sign-in recovery notice: $message', severity: 'WARNING');
    }
  }

  /// Log a message with timestamp and severity
  static void logDetailed(String tag, String message,
      {String severity = 'INFO'}) {
    final fullMessage = '[$tag] [$severity] $message';
    print(fullMessage);
  }

  /// Capture system information
  static Future<Map<String, dynamic>> getSystemInfo() async {
    try {
      final info = <String, dynamic>{
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        'operatingSystemVersion':
            kIsWeb ? 'web' : Platform.operatingSystemVersion,
        'isAndroid': kIsWeb ? false : Platform.isAndroid,
        'isIOS': kIsWeb ? false : Platform.isIOS,
        'isWeb': kIsWeb,
      };
      logDetailed('DeviceLogger', 'System Info: $info');
      return info;
    } catch (e) {
      logDetailed('DeviceLogger', 'Error getting system info: $e',
          severity: 'ERROR');
      return {};
    }
  }

  /// Request native logs from Android
  static Future<String> getNativeAndroidLogs() async {
    if (!Platform.isAndroid) {
      return 'Not on Android platform';
    }

    try {
      final result = await platform.invokeMethod<String>('getLogcatLogs');
      return result ?? 'No logs available';
    } catch (e) {
      logDetailed('DeviceLogger', 'Error getting Android logs: $e',
          severity: 'ERROR');
      return 'Error: ${e.toString()}';
    }
  }

  /// Log Flutterwave-specific information
  static void logFlutterwaveInitiation({
    required String publicKey,
    required String currency,
    required String amount,
    required String email,
    required String txRef,
    required bool isTestMode,
  }) {
    logDetailed('FlutterwaveLogger', 'Initiation Details:');
    logDetailed(
        'FlutterwaveLogger', '  Public Key: ${publicKey.substring(0, 20)}...');
    logDetailed('FlutterwaveLogger', '  Currency: $currency');
    logDetailed('FlutterwaveLogger', '  Amount: $amount');
    logDetailed('FlutterwaveLogger', '  Email: $email');
    logDetailed('FlutterwaveLogger', '  TxRef: $txRef');
    logDetailed('FlutterwaveLogger', '  Test Mode: $isTestMode');
  }

  /// Log network connectivity status
  static Future<void> logNetworkStatus() async {
    try {
      // Test connectivity to Flutterwave
      final result = await InternetAddress.lookup('api.flutterwave.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        logDetailed('NetworkLogger', 'Flutterwave API reachable',
            severity: 'SUCCESS');
      }
    } catch (e) {
      logDetailed('NetworkLogger', 'Cannot reach Flutterwave API: $e',
          severity: 'ERROR');
    }
  }

  /// Capture and return all debug information
  static Future<String> getFullDebugReport() async {
    final buffer = StringBuffer();

    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('FULL DEBUG REPORT');
    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('Timestamp: ${DateTime.now()}');
    buffer.writeln('');

    // System info
    buffer.writeln('━━━━━━━ SYSTEM INFO ━━━━━━━');
    final sysInfo = await getSystemInfo();
    sysInfo.forEach((key, value) {
      buffer.writeln('$key: $value');
    });
    buffer.writeln('');

    // Network status
    buffer.writeln('━━━━━━━ NETWORK STATUS ━━━━━━━');
    await logNetworkStatus();
    buffer.writeln('Network test completed (see console logs above)');
    buffer.writeln('');

    // Native logs (Android only)
    if (Platform.isAndroid) {
      buffer.writeln('━━━━━━━ ANDROID NATIVE LOGS ━━━━━━━');
      final nativeLogs = await getNativeAndroidLogs();
      buffer.writeln(nativeLogs);
      buffer.writeln('');
    }

    buffer.writeln('═══════════════════════════════════════════════════════');

    return buffer.toString();
  }
}

const bool kIsWeb = bool.fromEnvironment('kIsWeb', defaultValue: false);
