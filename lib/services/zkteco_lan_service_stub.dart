import 'package:flutter/foundation.dart';

import 'zkteco_lan_models.dart';

class ZktecoLanService {
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[ZKTecoLAN] $message');
    }
  }

  Future<ZktecoLanConnectionResult> testConnection({
    required String ipAddress,
    required int port,
    String? password,
    Duration timeout = const Duration(seconds: 8),
    bool omitPing = true,
  }) async {
    _log(
      'testConnection unsupported platform ip=$ipAddress port=$port. Use Android/Windows/native, not Flutter web.',
    );
    return const ZktecoLanConnectionResult(
      connected: false,
      message: 'ZKTeco LAN tools are only available on native platforms.',
    );
  }

  Future<List<ZktecoLanUser>> getUsers({
    required String ipAddress,
    required int port,
    String? password,
    Duration timeout = const Duration(seconds: 12),
    bool omitPing = true,
  }) async {
    _log(
      'getUsers unsupported platform ip=$ipAddress port=$port. Use Android/Windows/native, not Flutter web.',
    );
    throw UnsupportedError(
      'ZKTeco LAN tools are only available on native platforms.',
    );
  }

  Future<List<ZktecoLanAttendanceLog>> getAttendanceLogs({
    required String ipAddress,
    required int port,
    String? password,
    Duration timeout = const Duration(seconds: 20),
    bool omitPing = true,
  }) async {
    _log(
      'getAttendanceLogs unsupported platform ip=$ipAddress port=$port. Use Android/Windows/native, not Flutter web.',
    );
    throw UnsupportedError(
      'ZKTeco LAN tools are only available on native platforms.',
    );
  }
}
