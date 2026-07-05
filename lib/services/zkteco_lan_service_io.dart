import 'package:flutter_zkteco/flutter_zkteco.dart';

import 'zkteco_lan_models.dart';

class ZktecoLanService {
  ZKTeco _device({
    required String ipAddress,
    required int port,
    required Duration timeout,
    String? password,
  }) {
    final trimmedPassword = password?.trim();
    return ZKTeco(
      ipAddress,
      port: port,
      timeout: timeout,
      tcp: true,
      debug: false,
      password:
          trimmedPassword == null || trimmedPassword.isEmpty ? null : trimmedPassword,
    );
  }

  Future<ZktecoLanConnectionResult> testConnection({
    required String ipAddress,
    required int port,
    String? password,
    Duration timeout = const Duration(seconds: 8),
    bool omitPing = true,
  }) async {
    final device = _device(
      ipAddress: ipAddress,
      port: port,
      timeout: timeout,
      password: password,
    );

    try {
      final connected = await device.connect(ommitPing: omitPing);
      if (!connected) {
        return ZktecoLanConnectionResult(
          connected: false,
          message: 'Could not connect to $ipAddress:$port.',
        );
      }

      final serial = await _safeString(device.serialNumber);
      final name = await _safeString(device.getDeviceName);
      final os = await _safeString(device.getOS);
      final version = await _safeString(device.version);
      DateTime? time;
      try {
        time = await device.getTime();
      } catch (_) {
        time = null;
      }

      return ZktecoLanConnectionResult(
        connected: true,
        message: 'Connected to $ipAddress:$port.',
        serialNumber: serial,
        deviceName: name,
        deviceTime: time,
        os: os,
        version: version,
      );
    } catch (error) {
      return ZktecoLanConnectionResult(
        connected: false,
        message: 'Connection failed: $error',
      );
    } finally {
      await _disconnectQuietly(device);
    }
  }

  Future<List<ZktecoLanUser>> getUsers({
    required String ipAddress,
    required int port,
    String? password,
    Duration timeout = const Duration(seconds: 12),
    bool omitPing = true,
  }) async {
    final device = _device(
      ipAddress: ipAddress,
      port: port,
      timeout: timeout,
      password: password,
    );

    try {
      final connected = await device.connect(ommitPing: omitPing);
      if (!connected) return const <ZktecoLanUser>[];
      final users = await device.getUsers();
      return users.map(_mapUser).toList();
    } finally {
      await _disconnectQuietly(device);
    }
  }

  Future<List<ZktecoLanAttendanceLog>> getAttendanceLogs({
    required String ipAddress,
    required int port,
    String? password,
    Duration timeout = const Duration(seconds: 20),
    bool omitPing = true,
  }) async {
    final device = _device(
      ipAddress: ipAddress,
      port: port,
      timeout: timeout,
      password: password,
    );

    try {
      final connected = await device.connect(ommitPing: omitPing);
      if (!connected) return const <ZktecoLanAttendanceLog>[];
      final logs = await device.getAttendanceLogs();
      return logs.map(_mapAttendanceLog).toList();
    } finally {
      await _disconnectQuietly(device);
    }
  }

  ZktecoLanUser _mapUser(UserInfo user) {
    final dynamic raw = user;
    return ZktecoLanUser(
      uid: _tryInt(() => raw.uid),
      userId: _tryString(() => raw.userId) ?? '',
      name: _tryString(() => raw.name) ?? '',
      role: _tryString(() => raw.role) ?? 'user',
      password: _tryString(() => raw.password),
      cardNo: _tryInt(() => raw.cardNo),
    );
  }

  ZktecoLanAttendanceLog _mapAttendanceLog(AttendanceLog log) {
    final dynamic raw = log;
    return ZktecoLanAttendanceLog(
      uid: _tryInt(() => raw.uid),
      userId: _tryString(() => raw.id) ?? '',
      timestamp: _tryDateTime(() => raw.timestamp),
      state: _tryInt(() => raw.state),
      type: _tryInt(() => raw.type),
    );
  }

  Future<String?> _safeString(Future<dynamic> Function() call) async {
    try {
      final value = await call();
      return value?.toString();
    } catch (_) {
      return null;
    }
  }

  String? _tryString(dynamic Function() read) {
    try {
      final value = read();
      return value?.toString();
    } catch (_) {
      return null;
    }
  }

  int? _tryInt(dynamic Function() read) {
    try {
      final value = read();
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  DateTime? _tryDateTime(dynamic Function() read) {
    try {
      final value = read();
      if (value is DateTime) return value;
      return DateTime.tryParse(value?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<void> _disconnectQuietly(ZKTeco device) async {
    try {
      await device.disconnect();
    } catch (_) {
      // Best effort cleanup after a LAN operation.
    }
  }
}

