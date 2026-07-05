import 'zkteco_lan_models.dart';

class ZktecoLanService {
  Future<ZktecoLanConnectionResult> testConnection({
    required String ipAddress,
    required int port,
    String? password,
    Duration timeout = const Duration(seconds: 8),
    bool omitPing = true,
  }) async {
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
    throw UnsupportedError(
      'ZKTeco LAN tools are only available on native platforms.',
    );
  }
}

